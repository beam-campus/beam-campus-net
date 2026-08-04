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

  @doc """
  What to CALL an island, given the key it is filed under.

  The key is a digest and no one wants to read one. This is the name the island
  publishes for itself, which is a nickname and may be shared: a page showing two
  islands called `beam01` is telling the truth, and they are two rows rather than
  one because they are filed apart.

  Falls back to the key, so an island that has sent an id and no name still
  appears rather than vanishing into a blank cell.
  """
  def label(key) do
    case island(key) do
      %{stats: %{"island" => name}} when is_binary(name) -> name
      %{chart: %{"island" => name}} when is_binary(name) -> name
      _nothing -> key
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
  def put_stats(%{"island" => _} = fact), do: merge(key_of(fact), :stats, fact)
  def put_stats(_fact), do: :ignored

  @doc "File a `world_charted` fact under its island."
  def put_chart(%{"island" => _} = fact), do: merge(key_of(fact), :chart, fact)
  def put_chart(_fact), do: :ignored

  # ⚠ FILED UNDER THE IDENTITY, NEVER THE NAME.
  #
  # `island` is a LABEL: an environment variable on the island, falling back to
  # its hostname, changeable at runtime from its own web form. Two islands can
  # carry the same one by accident, and in a world of nodes run by strangers,
  # on purpose. Filed under the name, two islands called `beam01` overwrite each
  # other and this table shows ONE PLACE FLICKERING BETWEEN TWO WORLDS, with
  # nothing anywhere reporting a problem.
  #
  # `island_id` is 128 bits the island minted for itself and nobody typed.
  #
  # The fallback to the name is for an island on an older build, which sends no
  # id. It keeps a fleet readable through a rollout, and it is the only reason
  # this is not simply a required key.
  defp key_of(%{"island_id" => id}) when is_binary(id) and byte_size(id) > 0, do: id
  defp key_of(%{"island" => name}), do: name

  @doc """
  File a `world_narrated` fact: what a model said about an island's numbers.

  KEPT LIKE A FRAME AND NOT LIKE A STATISTIC. Only the latest is held, because a
  remark is about a moment and a spectator wants the current one. The history of
  what was said belongs in a read model if it ever matters, and it probably does
  not: the FIGURES are the record and the sentence is a reading of them.
  """
  def put_narration(%{"island" => _} = fact), do: merge(key_of(fact), :narration, fact)
  def put_narration(_fact), do: :ignored

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
    store(name, %{stats: nil, chart: nil, narration: nil, seen_at: now()}
                |> Map.put(key, fact))
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
