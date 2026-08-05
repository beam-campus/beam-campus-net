defmodule Dronex.WatchBouts.Board do
  @moduledoc """
  One ETS row per island: its vitals, and the last bout it published.

  ## Filed under identity, never under name

  An island's name is an environment variable falling back to a hostname, and two
  islands can carry the same one. `hecate-dronex` mints 128 bits into its data
  directory precisely so that a reader has something to file under that nobody
  types. Filed under the name, two islands called `beam01` would overwrite each
  other and the page would show one place flickering between two rosters.

  ⚠ **Identity defeats accident and not impersonation.** Nothing signs the id, so
  a node could copy another's. This board is a reader: it shows what arrived and
  attributes it to whoever claimed it, which is the honest limit.

  ## The last bout only, and that is not a shortcut

  A bout is a RECORDING of a whole engagement, tens of kilobytes, and it is about
  a moment. Keeping a history of them in memory would be writing a video into
  ETS. What is worth keeping over time is the vitals, and those belong in a read
  model with a schema if they are ever wanted, which is not this.

  ## Bounded, and it says when it refuses

  A public realm is writable by anyone who can reach a station, so an unbounded
  table is an unbounded memory leak with a stranger holding the tap. The board
  caps the islands it will hold and counts what it turned away, and the page
  shows a non-zero count rather than quietly lying about how many islands exist.
  """

  @table :dronex_board
  @max_islands 64

  @doc "Create the table. Idempotent, so a subscriber restart does not lose the board."
  def init do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
        :ets.insert(@table, {:refused, 0})
        :ok

      _ref ->
        :ok
    end
  end

  @doc "File one fact against an island, keyed by the kind of topic it arrived on."
  @spec put(binary(), atom(), map()) :: :ok
  def put(key, kind, fact) when is_binary(key) and is_atom(kind) and is_map(fact) do
    row = existing(key) || fresh(key)
    accept(room_for?(key), key, kind, fact, row)
  end

  defp accept(false, _key, _kind, _fact, _row), do: refuse()

  defp accept(true, key, kind, fact, row) do
    updated = %{
      row
      | name: Map.get(fact, "island", row.name),
        facts: Map.put(row.facts, kind, fact),
        last_seen: System.system_time(:millisecond)
    }

    :ets.insert(@table, {key, updated})
    :ok
  end

  defp refuse do
    :ets.update_counter(@table, :refused, {2, 1}, {:refused, 0})
    :ok
  end

  defp room_for?(key), do: existing(key) != nil or map_size(rows()) < @max_islands

  defp fresh(key), do: %{id: key, name: nil, facts: %{}, last_seen: nil}

  defp existing(key) do
    case :ets.lookup(@table, key) do
      [{^key, row}] -> row
      _otherwise -> nil
    end
  end

  @doc "Every island heard from, sorted by what it calls itself."
  def islands, do: rows() |> Map.values() |> Enum.sort_by(&label/1)

  @doc "What to call an island. The key is a digest and nobody wants to read one."
  def label(%{name: name}) when is_binary(name), do: name
  def label(%{id: id}), do: id

  @doc "One island's row, or nil."
  def island(key), do: existing(key)

  @doc "Islands refused because the cap was reached. Non-zero means the view lies."
  def refused do
    case :ets.lookup(@table, :refused) do
      [{:refused, n}] -> n
      [] -> 0
    end
  end

  @doc """
  Milliseconds since anything was last heard from this island.

  ⚠ WITHOUT THIS A DEAD ISLAND IS INVISIBLE. The board keeps the last fact
  forever, so an island whose trainer stopped, or whose transport did, goes on
  showing its final bout with a tick that never advances. At one island you would
  notice. At six you would not.
  """
  def quiet_for(%{last_seen: at}) when is_integer(at),
    do: System.system_time(:millisecond) - at

  def quiet_for(_never), do: nil

  defp rows do
    @table
    |> :ets.tab2list()
    |> Enum.reject(fn {k, _v} -> is_atom(k) end)
    |> Map.new()
  end
end
