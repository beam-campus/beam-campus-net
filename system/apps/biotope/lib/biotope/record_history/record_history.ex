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

  @pubsub BeamCampus.PubSub
  # ITS OWN CHANNEL, not the one the live page listens on. Facts arrive twice a
  # second and a row is written at most every thirty, so sharing a channel would
  # make each page redraw for the other's events: the live islands repainting for
  # a database write, and the chart repainting for a frame it does not plot.
  @channel "biotope_history"

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Subscribe the calling process to history being written.

  A page listens for this instead of polling. The writer knows exactly when a row
  appears, so the chart can be exactly as fresh as the data and repaint only when
  there is something new to draw. Polling meant two unsynchronised thirty-second
  clocks and a chart that could be a minute behind the world.
  """
  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @channel)

  @doc """
  The most recent samples for one island, oldest first, under its current rules.

  Ordered by tick rather than by insertion time: the tick is the world's own
  clock, and it is the axis a population curve is actually drawn against.

  FILTERED TO ONE FINGERPRINT, WHICH IS NOT A DETAIL. Two islands sharing an
  `econ_id` are comparable and two that do not are playing different games, and
  the same is true of one island before and after its rules change. Without this
  a deploy that alters the economy bends the existing curve instead of starting a
  new one, and the discontinuity reads as something the world did.

  So a rules change shortens the chart rather than corrupting it. A short line is
  an honest answer to "what has happened under these rules"; a long one spliced
  from two rulebooks is not an answer at all.
  """
  def history(island, limit \\ 240) do
    case current_rules(island) do
      nil -> []
      econ_id -> history(island, econ_id, limit)
    end
  end

  defp history(island, econ_id, limit) do
    Sample
    |> where([s], s.island == ^island and s.econ_id == ^econ_id)
    |> order_by([s], desc: s.tick)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  # The rulebook of this island's most recent sample. Read from the table rather
  # than from the live board, so a chart of what was recorded is answered by what
  # was recorded and an island that has gone quiet still draws its own history.
  defp current_rules(island) do
    Sample
    |> where([s], s.island == ^island)
    |> order_by([s], desc: s.tick)
    |> limit(1)
    |> select([s], s.econ_id)
    |> Repo.one()
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
    before = s.written
    s1 = s |> record_all() |> maybe_prune()
    announce(s1.written > before)
    {:noreply, s1}
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
      %{stats: %{"tick" => tick} = fact} ->
        advanced(tick != Map.get(s.seen, name), fact, name, tick, s)

      _no_stats_yet ->
        s
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
    Keyword.has_key?(errors, :island) or
      Logger.warning("[Biotope] sample rejected: #{inspect(cs.errors)}")

    %{s | seen: Map.put(s.seen, name, tick)}
  end

  # ── Pruning ─────────────────────────────────────────────────────

  defp maybe_prune(%{wakes: n} = s) when rem(n, @prune_every) != 0, do: s

  defp maybe_prune(s) do
    cutoff = DateTime.add(DateTime.utc_now(), -retention_days() * 86_400, :second)
    {deleted, _} = Repo.delete_all(from(x in Sample, where: x.inserted_at < ^cutoff))

    deleted > 0 &&
      Logger.info("[Biotope] pruned #{deleted} samples older than #{retention_days()}d")

    s
  end

  # ── Config ──────────────────────────────────────────────────────

  # Only when something was actually written. A wake that recorded nothing, which
  # is every wake for a frozen island, must not tell a page to redraw an
  # unchanged chart.
  defp announce(false), do: :ok

  defp announce(true),
    do: Phoenix.PubSub.broadcast(@pubsub, @channel, {:biotope_history, :written})

  defp schedule, do: Process.send_after(self(), :sample, sample_ms())

  defp sample_ms, do: Application.get_env(:biotope, :sample_ms, @default_sample_ms)

  defp retention_days,
    do: Application.get_env(:biotope, :retention_days, @default_retention_days)
end
