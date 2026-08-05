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

  ## Raids are filed under the RAID, not under an island

  A raid is the only fact here that is about **two** islands. Both sides publish
  a commitment naming the same `raid_id`, and the defender publishes the
  recording. Filed under the publisher, the attacker's half of the story would
  have no home and a raid in flight would look like two unrelated events.

  So raids live under `{:raid, raid_id}` and carry whatever has arrived so far:
  one commitment, then usually the other, then the recording when the fight ends.
  A raid with one commitment and no recording is one in flight — or one whose
  defender went dark, which is the same shape, and is exactly why both sides
  emit one.

  Islands are few and long-lived; raids are many and are moments, so they are
  capped separately and the oldest go first.
  """

  @table :dronex_board
  @max_islands 64
  @max_raids 64

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

  @doc """
  File a commitment or a recording against the raid it names.

  Merged rather than replaced: the attacker's commitment, the defender's
  commitment and the recording arrive separately and none of them is complete on
  its own.
  """
  @spec put_raid(binary(), atom(), map()) :: :ok
  def put_raid(raid_id, kind, fact) when is_binary(raid_id) and is_atom(kind) do
    key = {:raid, raid_id}
    row = existing(key) || %{id: raid_id, parts: %{}, last_seen: nil}

    :ets.insert(
      @table,
      {key,
       %{
         row
         | parts: Map.update(row.parts, kind, [fact], &[fact | &1]),
           last_seen: System.system_time(:millisecond)
       }}
    )

    evict_oldest_raids()
    :ok
  end

  @doc "Raids the board is holding, newest first."
  def raids do
    @table
    |> :ets.tab2list()
    |> Enum.flat_map(fn
      {{:raid, _id}, row} -> [row]
      _other -> []
    end)
    |> Enum.sort_by(& &1.last_seen, :desc)
  end

  # Oldest first, because a raid from an hour ago is not what anybody is looking
  # at, and a public realm is writable by anyone who can reach a station.
  defp evict_oldest_raids do
    case raids() do
      rows when length(rows) > @max_raids ->
        rows
        |> Enum.drop(@max_raids)
        |> Enum.each(&:ets.delete(@table, {:raid, &1.id}))

      _within ->
        :ok
    end
  end

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

  # ⚠ ISLANDS ONLY. One table holds three shapes now — the `:refused` counter
  # under an atom, islands under a binary id, and raids under `{:raid, id}` — and
  # an island row has `:facts` while a raid row has `:parts`. Letting a raid
  # through here raised `key :facts not found` from inside the page, which is the
  # right kind of loud, but the filter belongs where the keys are known.
  defp rows do
    @table
    |> :ets.tab2list()
    |> Enum.filter(fn {k, _v} -> is_binary(k) end)
    |> Map.new()
  end
end
