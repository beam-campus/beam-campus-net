defmodule ASociety.WatchIslands.Board do
  @moduledoc """
  One ETS row per island, holding the last thing it said.

  ## Filed under identity, never under name

  An island's name is an environment variable falling back to a hostname, and two
  islands can carry the same one. `hecate-society` mints 128 bits into its data
  directory precisely so that a reader has something to file under that nobody
  types.

  Two islands sharing a name would otherwise overwrite each other here and the
  page would show one island flickering between two populations. The predecessor
  shipped that bug and fixed it by adding `island_id` to every fact.

  ⚠ **Identity defeats accident and not impersonation.** Nothing signs the id, so
  a node could copy another's. This board is a reader: it shows what arrived and
  attributes it to whoever claimed it, which is the honest limit.

  ## Bounded, and it says when it refuses

  A public realm is writable by anyone who can reach a station, so an unbounded
  table is an unbounded memory leak with a stranger holding the tap. The board
  caps the islands it will hold and counts what it turned away, and the page shows
  a non-zero count rather than quietly lying about how many islands exist.
  """

  @table :asociety_board
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

  @doc """
  File one fact against an island.

  `key` is the island's 128-bit identity as it arrived. `kind` says which topic it
  came in on, so a later fact of one kind does not erase another kind's payload.
  """
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

  defp room_for?(key) do
    existing(key) != nil or map_size(rows()) < @max_islands
  end

  defp fresh(key) do
    %{id: key, name: nil, facts: %{}, last_seen: nil}
  end

  defp existing(key) do
    case :ets.lookup(@table, key) do
      [{^key, row}] -> row
      _none -> nil
    end
  end

  @doc "Every island heard from, keyed by identity."
  @spec rows() :: %{binary() => map()}
  def rows do
    @table
    |> :ets.tab2list()
    |> Enum.reject(fn {k, _v} -> k == :refused end)
    |> Map.new()
  rescue
    ArgumentError -> %{}
  end

  @doc "Islands heard from, sorted by what they call themselves."
  @spec islands() :: [map()]
  def islands do
    rows()
    |> Map.values()
    |> Enum.sort_by(&label/1)
  end

  @doc "Whether anything has arrived yet."
  @spec empty?() :: boolean()
  def empty?, do: rows() == %{}

  @doc "Islands refused because the board is full. Non-zero means a page is lying."
  @spec refused() :: non_neg_integer()
  def refused do
    case :ets.lookup(@table, :refused) do
      [{:refused, n}] -> n
      _none -> 0
    end
  rescue
    ArgumentError -> 0
  end

  @doc """
  What to call an island.

  Falls back to a short prefix of its identity, because an island that has not
  said its name yet is still an island and showing nothing would be worse than
  showing the only thing it did say.
  """
  @spec label(map()) :: String.t()
  def label(%{name: name}) when is_binary(name) and name != "", do: name
  def label(%{id: id}) when is_binary(id), do: String.slice(id, 0, 8)
  def label(_row), do: "unknown"

  @doc "Milliseconds since this island last said anything, or `nil`."
  @spec quiet_for(map()) :: non_neg_integer() | nil
  def quiet_for(%{last_seen: nil}), do: nil
  def quiet_for(%{last_seen: at}), do: System.system_time(:millisecond) - at
end
