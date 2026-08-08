defmodule Dronex.FollowTheChampions do
  @moduledoc """
  Which controllers have held which islands, and which of them crossed the mesh.

  ## Why this is the panel the exhibit was missing

  `CHARTER.md` makes a raid the way opponent diversity crosses the mesh, so
  "where did this controller come from" is the archipelago's central question.
  Until the islands began naming their champion it was answerable only as a
  number: captures went up, and nobody could watch one genome travel.

  A genome id is the sha256 of its packed form, so the SAME id holding two
  different islands IS the crossing. No matching heuristics, no inference.

  ## ⚠ A REIGN IS A SPAN, NOT A SIGHTING

  The champion is republished every second. A row per sighting would be a million
  rows saying one thing. Each row is one genome on one island, its window widened
  as it keeps holding, so tenure is a subtraction and a displaced champion simply
  stops being extended.

  ## ⚠⚠ AND IT RANKS ON WHAT CANNOT BE GAMED BY A BROKEN MEASURE

  Not the frozen exam. That is saturated at 47 or 48 of 48 for four of five
  islands and `REGISTER D.15` says it swings a hundred points in a day. A genome
  leaderboard sorted on it would inherit every one of those faults.

  Islands held, then total tenure, then sorties survived: three structural facts
  about what a controller actually did.
  """

  use GenServer

  require Logger

  import Ecto.Query

  alias BeamCampus.Repo
  alias Dronex.FollowTheChampions.Reign

  @default_write_ms 60_000
  @default_retention_days 60
  @prune_every 60

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Record every island's current champion. Returns how many reigns moved."
  @spec remember() :: non_neg_integer()
  def remember do
    now = System.system_time(:millisecond)
    Enum.count(Dronex.islands(), &record(&1, now))
  rescue
    error ->
      Logger.warning("[dronex] champions not written: #{inspect(error)}")
      0
  end

  @doc """
  Every controller that has held an island, best first.

  `%{genome_id, islands, held_ms, sorties, generation, crossed?, reigns}`.
  """
  @spec ranked(pos_integer()) :: [map()]
  def ranked(limit \\ 12) do
    Reign
    |> Repo.all()
    |> Enum.group_by(& &1.genome_id)
    |> Enum.map(&counted/1)
    |> Enum.sort_by(&{-&1.islands, -&1.held_ms, -&1.sorties})
    |> Enum.take(limit)
  rescue
    _unreachable -> []
  end

  @doc "Reigns that name where the controller came from: the crossings, newest first."
  @spec crossings(pos_integer()) :: [Reign.t()]
  def crossings(limit \\ 20) do
    Repo.all(
      from r in Reign,
        where: not is_nil(r.taken_from),
        order_by: [desc: r.last_seen],
        limit: ^limit
    )
  rescue
    _unreachable -> []
  end

  @doc """
  How many distinct controllers have crossed, over EVERY reign on disk.

  ⚠ **NOT COUNTED WITHIN THE RANKED TOP TEN, WHICH IS WHERE IT WAS COUNTED AND
  WHY IT ALWAYS SAID ZERO.** `ranked/1` orders on islands held, then tenure, and
  a controller that has just crossed has by definition just arrived: it holds one
  island and has held it for seconds. So the one event this panel exists to
  report was ranked last and then cut off by the limit, and the headline read
  "0 of 10 crossed the mesh" while two crossings sat in the table it was counting
  over. `REGISTER I.25` is why there were none before that; this is why they were
  invisible afterwards.
  """
  @spec crossed() :: non_neg_integer()
  def crossed do
    Reign
    |> Repo.all()
    |> Enum.group_by(& &1.genome_id)
    |> Enum.map(&counted/1)
    |> Enum.count(& &1.crossed?)
  rescue
    _unreachable -> 0
  end

  @doc "How many reigns are on disk. Nil when the database cannot be reached."
  @spec counted() :: non_neg_integer() | nil
  def counted do
    Repo.aggregate(Reign, :count)
  rescue
    _unreachable -> nil
  end

  defp counted({genome_id, reigns}) do
    %{
      genome_id: genome_id,
      islands: reigns |> Enum.map(& &1.island_id) |> Enum.uniq() |> length(),
      held_ms: Enum.sum(Enum.map(reigns, &(&1.last_seen - &1.first_seen))),
      sorties: reigns |> Enum.map(&(&1.sorties || 0)) |> Enum.max(fn -> 0 end),
      generation: reigns |> Enum.map(&(&1.generation || 0)) |> Enum.max(fn -> 0 end),
      # ⚠ THE CLAIM ITSELF. Held by more than one island, or taken from
      # somewhere: either way this controller left the machine that made it.
      crossed?: length(Enum.uniq(Enum.map(reigns, & &1.island_id))) > 1 or
                  Enum.any?(reigns, &(&1.taken_from != nil)),
      reigns: Enum.sort_by(reigns, & &1.first_seen)
    }
  end

  defp record(row, now) do
    vitals = Dronex.fact(row, :vitals) || %{}
    written(Reign.from_vitals(vitals, now))
  end

  defp written(nil), do: false

  defp written(changeset) do
    row = Map.fetch!(changeset, :changes)

    # ⚠ A REIGN IS WIDENED, NEVER DUPLICATED. On conflict only `last_seen` moves,
    # so `first_seen` remains the moment this genome took this island however
    # many times it is republished.
    # ⚠ `Map.get`, NOT DOT ACCESS. A changeset's `changes` omits any field that
    # cast to nil, so `row.sorties` raises `KeyError` on an island that has not
    # flown its champion yet — and `remember/0`'s rescue turned that into a
    # silent zero. Six tests failed with an empty table and no reason on screen.
    {count, _} =
      Repo.insert_all(
        Reign,
        [stamped(row)],
        on_conflict: [
          set: [
            last_seen: Map.get(row, :last_seen),
            sorties: Map.get(row, :sorties),
            score: Map.get(row, :score)
          ]
        ],
        conflict_target: [:genome_id, :island_id]
      )

    count == 1
  end

  defp stamped(row) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    row |> Map.put(:inserted_at, now) |> Map.put(:updated_at, now)
  end

  @impl true
  def init(opts) do
    {:ok, %{ticks: 0, write_ms: Keyword.get(opts, :write_ms, @default_write_ms)}, {:continue, :go}}
  end

  @impl true
  def handle_continue(:go, state) do
    schedule(state.write_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:write, state) do
    moved = remember()
    moved > 0 && Logger.info("[dronex] #{moved} champion reigns recorded")
    maybe_prune(state.ticks)
    schedule(state.write_ms)
    {:noreply, %{state | ticks: state.ticks + 1}}
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp maybe_prune(ticks) when rem(ticks, @prune_every) == 0 do
    cutoff = System.system_time(:millisecond) - @default_retention_days * 86_400_000
    Repo.delete_all(from r in Reign, where: r.last_seen < ^cutoff)
  rescue
    _unreachable -> :ok
  end

  defp maybe_prune(_ticks), do: :ok

  defp schedule(ms), do: Process.send_after(self(), :write, ms)
end
