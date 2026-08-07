defmodule Dronex.RememberRaids do
  @moduledoc """
  Writes settled raids down, and puts them back after a restart.

  ## Why this exists

  Everything /dronex knows lived in ETS and nowhere else. Every restart of the
  site emptied the board, and since the site redeploys whenever anything is
  pushed, the whole raid record was lost several times in a single afternoon.

  For the biotope that would be a gap in a curve. Here it is the entire dataset:
  raids are rare, a handful an hour across five islands, and the duration
  histogram, the ledger matrix, the experience plot and the loss ledger all read
  the same few dozen rows. They reset together, and a board filling up again from
  nothing looks exactly like a board that was never empty, which is the same
  thing that let `roster_log` lose every lineage on the island side for weeks.

  ## Off the hot path, deliberately

  This does not write a row per fact. It wakes on a slow timer, reads the ETS
  board the subscriber already maintains, and inserts what is new. The subscriber
  never touches the database and never waits for it, so a slow disk cannot back
  up the mesh reader. That is the house rule about database I/O never blocking
  event flow, applied to the smallest possible case, and it is copied from
  `Biotope.RecordHistory` rather than extracted, because two consumers is a copy.

  ## ⚠ REHYDRATION GOES INTO THE BOARD, NOT INTO THE INSTRUMENTS

  On boot the stored rows are put back into the same ETS board the mesh writes
  to. `ReadTheLedger`, `TimeTheFights` and `WeighTheExperience` are therefore
  unchanged and none of them learns that a database exists. The alternative,
  teaching every instrument to read a second source and merge, is how a pure
  function of its input becomes something that needs a database to test.

  ## ⚠⚠ ONLY SETTLED RAIDS, AND ONLY ONCE

  A raid with no recording is still in flight; it has no outcome and writing it
  would mean carrying a row that has to be updated later. Both sides also publish
  a commitment and the defender publishes the recording, so the same raid arrives
  repeatedly. The unique index on `raid_id` plus `on_conflict: :nothing` makes a
  second sighting free.

  ## Pruning, because a read model that only grows is a leak

  Rows older than the retention window are deleted on the same timer. This is a
  projection of facts that happened to arrive; it is not the archive, the islands
  are.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias BeamCampus.Repo
  alias Dronex.RememberRaids.Raid
  alias Dronex.WatchBouts.Board

  @default_write_ms 30_000
  @default_retention_days 90
  # Pruning is far cheaper than writing and needs no urgency.
  @prune_every 120

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Write down every settled raid on the board that is not stored yet.

  ⚠ PUBLIC, AND CALLED BY THE TIMER RATHER THAN BEING THE TIMER. A test that has
  to start a second copy of this GenServer fights the one the application already
  supervises, and a test that has to `sleep' for a tick is a test that fails on a
  loaded machine. Both were true of the first version.
  """
  @spec remember() :: non_neg_integer()
  def remember do
    Dronex.raids() |> Enum.flat_map(&settled/1) |> Enum.count(&insert/1)
  rescue
    error ->
      Logger.warning("[dronex] raids not written: #{inspect(error)}")
      0
  end

  @doc "Put every stored raid back on the board. Returns how many were restored."
  @spec recall() :: non_neg_integer()
  def recall do
    rows = stored()
    Enum.count(rows, &(restore(&1) == :ok))
  rescue
    error ->
      Logger.warning("[dronex] raids not restored: #{inspect(error)}")
      0
  end

  @doc "Rows currently stored, newest first. For a caller that wants the table itself."
  @spec stored(pos_integer()) :: [Raid.t()]
  def stored(limit \\ 500) do
    Repo.all(from r in Raid, order_by: [desc: r.inserted_at], limit: ^limit)
  end

  @doc "How many raids are on disk. Nil when the database cannot be reached."
  @spec counted() :: non_neg_integer() | nil
  def counted do
    Repo.aggregate(Raid, :count)
  rescue
    _unreachable -> nil
  end

  @impl true
  def init(opts) do
    # ⚠ REHYDRATE BEFORE THE FIRST TIMER, so a page rendered one second after
    # boot already has its history. Doing it on the first tick would leave a
    # thirty second window where the site looks exactly like the empty one this
    # module exists to prevent.
    {:ok, %{ticks: 0, write_ms: write_ms(opts)}, {:continue, :rehydrate}}
  end

  @impl true
  def handle_continue(:rehydrate, state) do
    Logger.info("[dronex] #{recall()} raids restored from the read model")
    schedule(state.write_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:write, state) do
    written = remember()
    written > 0 && Logger.info("[dronex] #{written} raids written to the read model")
    maybe_prune(state.ticks)
    schedule(state.write_ms)
    {:noreply, %{state | ticks: state.ticks + 1}}
  end

  def handle_info(_other, state), do: {:noreply, state}

  # ⚠ A DATABASE THAT IS NOT THERE MUST NOT TAKE THE PAGE WITH IT. The site
  # renders without a database by design, so the public calls above are wrapped:
  # the worst outcome of a missing Repo is that history stops being kept, which
  # is exactly where this started, and it is still better than a crash loop.
  defp restore(row) do
    {raid_id, fact, readings} = Raid.to_fact(row)
    Board.put_remembered(raid_id, fact, readings)
  end

  # A raid with no recording is still out. It has no outcome to record and
  # writing one would mean a row that has to be corrected later.
  defp settled(%{id: id, parts: %{raid: [fact | _]}} = row),
    do: [{id, fact, Map.get(row, :readings, %{})}]

  defp settled(_unsettled), do: []

  defp insert({raid_id, fact, readings}) do
    {count, _} =
      Repo.insert_all(
        Raid,
        [row_for(raid_id, fact, readings)],
        on_conflict: :nothing,
        conflict_target: :raid_id
      )

    count == 1
  end

  # `insert_all` skips changesets, so the cast happens here and the values are
  # taken from it. That keeps one definition of what a row is.
  defp row_for(raid_id, fact, readings) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    raid_id
    |> Raid.from_fact(fact, readings)
    |> Map.fetch!(:changes)
    |> Map.put(:inserted_at, now)
    |> Map.put(:updated_at, now)
  end

  defp maybe_prune(ticks) when rem(ticks, @prune_every) == 0 do
    cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-retention_days() * 86_400, :second)
    Repo.delete_all(from r in Raid, where: r.inserted_at < ^cutoff)
  rescue
    _unreachable -> :ok
  end

  defp maybe_prune(_ticks), do: :ok

  defp schedule(ms), do: Process.send_after(self(), :write, ms)

  defp write_ms(opts), do: Keyword.get(opts, :write_ms, @default_write_ms)

  defp retention_days do
    Application.get_env(:dronex, :raid_retention_days, @default_retention_days)
  end
end
