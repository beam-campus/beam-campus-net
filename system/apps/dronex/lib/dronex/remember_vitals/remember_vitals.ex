defmodule Dronex.RememberVitals do
  @moduledoc """
  Writes island trajectories down, and puts them back after a restart.

  ## Why this exists

  The board samples every island every 30 seconds and keeps 240 in ETS. That is
  two hours, and a restart empties it. Every trend on /dronex therefore began
  again on each of today's deploys, which is why they looked like flat lines
  drawn through two points.

  ⚠ AND THE ANOMALY IT MATTERS MOST FOR IS A DAY-SCALE THING BEING WATCHED
  THROUGH A TWO-HOUR HOLE. `REGISTER D.15` is an exam score swinging a hundred
  points in a DAY. The per-rung vector that could say what kind of swing it is
  now survives sampling, and this is what lets it survive a deploy.

  Copied from `Dronex.RememberRaids` rather than extracted, because two consumers
  is a copy, and that one was copied from `Biotope.RecordHistory` for the same
  reason.

  ## Off the hot path

  A slow timer reads the ETS the subscriber already maintains and writes what is
  new. The subscriber never touches the database.

  ## ⚠⚠ ONLY WHAT IS NEWER THAN WHAT IS STORED

  Writing all 240 samples every tick would be 239 conflicts a time. The newest
  stored instant per island is read once and only samples past it are written.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias BeamCampus.Repo
  alias Dronex.RememberVitals.Sample
  alias Dronex.WatchBouts.Board

  @default_write_ms 60_000
  @default_retention_days 30
  @prune_every 60

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Write every sample newer than what is stored. Returns how many were written."
  @spec remember() :: non_neg_integer()
  def remember do
    Enum.sum(for row <- Dronex.islands(), do: written(row.id))
  rescue
    error ->
      Logger.warning("[dronex] vitals not written: #{inspect(error)}")
      0
  end

  @doc "Put every stored trajectory back on the board. Returns how many samples."
  @spec recall() :: non_neg_integer()
  def recall do
    Enum.sum(for {id, points} <- stored_by_island(), do: restore(id, points))
  rescue
    error ->
      Logger.warning("[dronex] vitals not restored: #{inspect(error)}")
      0
  end

  @doc "How many samples are on disk. Nil when the database cannot be reached."
  @spec counted() :: non_neg_integer() | nil
  def counted do
    Repo.aggregate(Sample, :count)
  rescue
    _unreachable -> nil
  end

  @impl true
  def init(opts) do
    {:ok, %{ticks: 0, write_ms: Keyword.get(opts, :write_ms, @default_write_ms)},
     {:continue, :rehydrate}}
  end

  @impl true
  def handle_continue(:rehydrate, state) do
    Logger.info("[dronex] #{recall()} vitals samples restored from the read model")
    schedule(state.write_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:write, state) do
    written = remember()
    written > 0 && Logger.info("[dronex] #{written} vitals samples written")
    maybe_prune(state.ticks)
    schedule(state.write_ms)
    {:noreply, %{state | ticks: state.ticks + 1}}
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp written(id) do
    since = newest_stored(id)

    id
    |> Dronex.history()
    |> Enum.filter(&(&1.at > since))
    |> insert_all(id)
  end

  defp insert_all([], _id), do: 0

  defp insert_all(points, id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    rows =
      for p <- points do
        id
        |> Sample.from_point(p)
        |> Map.fetch!(:changes)
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)
      end

    {count, _} =
      Repo.insert_all(Sample, rows, on_conflict: :nothing, conflict_target: [:island_id, :at])

    count
  end

  defp newest_stored(id) do
    Repo.one(from s in Sample, where: s.island_id == ^id, select: max(s.at)) || 0
  end

  # ⚠ THE MOST RECENT PER ISLAND, CAPPED AT WHAT THE BOARD HOLDS. Loading a
  # month of samples into an ETS table that keeps 240 would churn for nothing.
  defp stored_by_island do
    Repo.all(
      from s in Sample,
        order_by: [desc: s.at],
        select: {s.island_id, s}
    )
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {id, rows} -> {id, Enum.take(rows, Board.max_samples())} end)
  end

  defp restore(id, rows) do
    Board.remember_samples(id, Enum.map(rows, &Sample.to_point/1))
    length(rows)
  end

  defp maybe_prune(ticks) when rem(ticks, @prune_every) == 0 do
    cutoff =
      System.system_time(:millisecond) - retention_days() * 86_400_000

    Repo.delete_all(from s in Sample, where: s.at < ^cutoff)
  rescue
    _unreachable -> :ok
  end

  defp maybe_prune(_ticks), do: :ok

  defp schedule(ms), do: Process.send_after(self(), :write, ms)

  defp retention_days do
    Application.get_env(:dronex, :sample_retention_days, @default_retention_days)
  end
end
