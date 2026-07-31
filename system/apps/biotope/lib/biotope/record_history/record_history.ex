defmodule Biotope.RecordHistory do
  @moduledoc """
  Writes a row every so often, so a population curve outlives a deploy.

  ## Off the hot path, deliberately

  Facts arrive as often as an island publishes them. This does not write one row
  per fact: it wakes on a slow timer, reads the ETS board the subscriber already
  maintains, and inserts. The subscriber never touches the database and never
  waits for it, so a slow disk cannot back up the mesh reader.

  That split is the house rule about database I/O never blocking event flow,
  applied to the smallest possible case.

  ## A frozen island stops producing rows

  A row is written only when the island's `tick` has advanced since the last one
  recorded for it. An island that has died, or whose transport has, otherwise
  leaves its last fact sitting on the board and would be re-recorded forever: the
  disk fills with a number that is not changing, and the chart shows a flat line
  that looks like a stable population rather than a stopped one.

  Stopping instead makes the gap visible, which is the truth. The unique index on
  `(island, tick)` enforces it in the table as well, so a restart that forgets
  what it has seen cannot duplicate history.

  ## Pruning, because a read model that only grows is a leak

  Rows older than the retention window are deleted on the same timer. This is a
  projection of facts that happened to arrive, rebuildable from nothing; keeping
  it forever buys nothing and costs a disk.
  """

  use GenServer
  require Logger

  import Ecto.Query

  alias BeamCampus.Repo
  alias Biotope.RecordHistory.Sample
  alias Biotope.WatchIslands.Board

  @default_sample_ms 30_000
  @default_retention_days 30
  # Pruning is far cheaper than sampling and needs no urgency, so it happens on
  # every Nth wake rather than on a second timer.
  @prune_every 120

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  The most recent samples for one island, oldest first.

  Ordered by tick rather than by insertion time: the tick is the world's own
  clock, and it is the axis a population curve is actually drawn against.
  """
  def history(island, limit \\ 240) do
    Sample
    |> where([s], s.island == ^island)
    |> order_by([s], desc: s.tick)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc "Islands that have any recorded history, sorted."
  def recorded_islands do
    Sample
    |> select([s], s.island)
    |> distinct(true)
    |> Repo.all()
    |> Enum.sort()
  end

  @doc "How many rows are held, for the page to be honest about its own depth."
  def count, do: Repo.aggregate(Sample, :count)

  # ── GenServer ───────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    schedule()
    {:ok, %{seen: %{}, wakes: 0, written: 0}}
  end

  @impl true
  def handle_info(:sample, s) do
    schedule()
    {:noreply, s |> record_all() |> maybe_prune()}
  end

  def handle_info(_msg, s), do: {:noreply, s}

  @impl true
  def handle_call(:stats, _from, s), do: {:reply, Map.take(s, [:written, :wakes]), s}

  # ── Recording ───────────────────────────────────────────────────

  defp record_all(s) do
    Board.islands()
    |> Enum.reduce(%{s | wakes: s.wakes + 1}, &record_one/2)
  end

  defp record_one(name, s) do
    case Board.island(name) do
      %{stats: %{"tick" => tick} = fact} -> advanced(tick != Map.get(s.seen, name), fact, name, tick, s)
      _no_stats_yet -> s
    end
  end

  defp advanced(false, _fact, _name, _tick, s), do: s

  defp advanced(true, fact, name, tick, s) do
    fact
    |> Sample.changeset()
    |> Repo.insert()
    |> recorded(name, tick, s)
  end

  defp recorded({:ok, _row}, name, tick, s) do
    %{s | seen: Map.put(s.seen, name, tick), written: s.written + 1}
  end

  # A constraint violation means this tick is already recorded, which is the
  # normal outcome after a restart and not worth a log line. Anything else is.
  defp recorded({:error, %Ecto.Changeset{errors: errors} = cs}, name, tick, s) do
    Keyword.has_key?(errors, :island) or Logger.warning("[Biotope] sample rejected: #{inspect(cs.errors)}")
    %{s | seen: Map.put(s.seen, name, tick)}
  end

  # ── Pruning ─────────────────────────────────────────────────────

  defp maybe_prune(%{wakes: n} = s) when rem(n, @prune_every) != 0, do: s

  defp maybe_prune(s) do
    cutoff = DateTime.add(DateTime.utc_now(), -retention_days() * 86_400, :second)
    {deleted, _} = Repo.delete_all(from(x in Sample, where: x.inserted_at < ^cutoff))
    deleted > 0 && Logger.info("[Biotope] pruned #{deleted} samples older than #{retention_days()}d")
    s
  end

  # ── Config ──────────────────────────────────────────────────────

  defp schedule, do: Process.send_after(self(), :sample, sample_ms())

  defp sample_ms, do: Application.get_env(:biotope, :sample_ms, @default_sample_ms)

  defp retention_days,
    do: Application.get_env(:biotope, :retention_days, @default_retention_days)
end
