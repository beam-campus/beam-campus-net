defmodule Biotope.WatchIslands.Board do
  @moduledoc """
  What the site knows about the islands, held in ETS and nowhere else.

  ## One row per island, and the latest of each fact

  An island publishes two things: counts, and a picture. Both are kept as the
  latest only.

  **Frames are ephemeral and statistics are durable**, and this table holds the
  ephemeral half. Nobody wants last Tuesday's frame, and keeping a history of
  them would be writing a video into memory. The durable half, population over
  hours, belongs in a read model with a schema and is not this.

  ## No store, on purpose

  The site is a reader. The island is the thing that is actually alive; this is a
  window onto whatever arrived while this node happened to be up. Restart it and
  it is empty until the next fact lands, which for a spectator is correct: nothing
  here is a source of truth, so nothing here needs to survive.

  ## Why ETS rather than the subscriber's state

  A hundred spectators must not queue behind one gen_server to read a page. The
  table is public and read-optimised, so a LiveView mount reads it directly and
  the subscriber is only ever on the write path.

  ## Bounded by island count

  An island count is naturally small, but "naturally" is doing a lot of work
  there: anything can publish onto a public realm. The cap stops a flood filling
  this node's memory, and refusals are counted rather than silent, because a
  spectator that has quietly stopped showing new islands looks identical to a
  fleet that has stopped growing.
  """

  @table :biotope_board
  @max_islands 50

  @doc "Create the table. Called by the subscriber, which owns it."
  def init do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
  end

  @doc "Island names this node has heard from, sorted."
  def islands do
    @table
    |> :ets.select([{{{:island, :"$1"}, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end

  @doc """
  Everything known about one island: `%{stats: fact | nil, chart: fact | nil}`.

  Returns `nil` for an island that has never been heard from, which a page
  renders as an empty slot rather than as an error.
  """
  def island(name) do
    case :ets.lookup(@table, {:island, name}) do
      [{_key, row}] -> row
      [] -> nil
    end
  end

  @doc "Whether anything at all has arrived yet."
  def empty?, do: islands() == []

  @doc "Islands refused because the cap was reached. Non-zero means the view lies."
  def refused, do: counter(:refused)

  @doc """
  Milliseconds since anything was last heard from this island.

  WITHOUT THIS A DEAD ISLAND IS INVISIBLE. The board keeps the last fact
  forever, so an island whose world stopped, or whose transport did, goes on
  showing its final frame with a tick that never advances. At one island you
  would notice. At six you would not, and the page would be quietly lying about
  five of them.

  `nil` for an island never heard from.
  """
  def quiet_for(name) do
    case island(name) do
      %{seen_at: at} when is_integer(at) -> System.system_time(:millisecond) - at
      _never -> nil
    end
  end

  # ── Writes. Subscriber only. ────────────────────────────────────

  @doc "File a `world_advanced` fact under its island."
  def put_stats(%{"island" => name} = fact), do: merge(name, :stats, fact)
  def put_stats(_fact), do: :ignored

  @doc "File a `world_charted` fact under its island."
  def put_chart(%{"island" => name} = fact), do: merge(name, :chart, fact)
  def put_chart(_fact), do: :ignored

  defp merge(name, key, fact) do
    existing = island(name)
    write(existing, name, key, fact)
  end

  # Stamped on every write, from either fact, because either one arriving is
  # proof the island is still talking.
  defp now, do: System.system_time(:millisecond)

  # A known island is always updated, cap or no cap: the cap is about admitting
  # NEW islands, and applying it to updates would freeze the ones already shown.
  defp write(nil, name, key, fact), do: admit(length(islands()) < @max_islands, name, key, fact)

  defp write(row, name, key, fact),
    do: store(name, row |> Map.put(key, fact) |> Map.put(:seen_at, now()))

  defp admit(false, _name, _key, _fact), do: bump(:refused)

  # A new island starts with both slots present and empty, so a page can tell
  # "has not sent a picture yet" from "is not an island I know about".
  defp admit(true, name, key, fact) do
    store(name, %{stats: nil, chart: nil, seen_at: now()} |> Map.put(key, fact))
  end

  defp store(name, row), do: :ets.insert(@table, {{:island, name}, row})

  defp bump(key), do: :ets.update_counter(@table, key, {2, 1}, {key, 0})

  defp counter(key) do
    case :ets.lookup(@table, key) do
      [{_k, n}] -> n
      [] -> 0
    end
  end
end
