defmodule Biotope.Archipelago do
  @moduledoc """
  Where each island sits, in one world made of all of them.

  ## The world is the sum of the nodes, and this is where that becomes visible

  Every island has run as its own private world and been drawn as its own disc,
  so three nodes read as three unrelated experiments side by side. They are one
  world, and adding a node adds land to it. This module decides where the land
  goes.

  ## Positions are DERIVED, never claimed

  The obvious design is for an island to announce its coordinates when it comes
  online. That needs conflict resolution, an authority to arbitrate, and a story
  for what happens when two nodes claim the same ground.

  None of that is necessary. **A position is a hash of the island's name**, so
  the layout is a pure function of the set of islands, and any two viewers that
  know the same islands independently compute the same map. Nobody grants
  anybody anything. An island arriving simply lands where its identity puts it.

  Macula already places things by hash. This is the same trick applied to
  cartography.

  ## The grid is FIXED, and that is what makes a new node ADD land

  The grid is `#{16}` by `#{16}` whatever the island count, so an island lands in
  the same cell whether it has two neighbours or twenty. A grid sized to the
  population would reshuffle every existing island each time one arrived, which
  is the opposite of the thing being shown.

  What changes with the count is the **occupied bounding box**, which the viewer
  fits to. So two islands fill the view, and a third genuinely enlarges the
  world rather than shrinking the others.

  ## Physics never asks this module anything

  A creature's position is `{island, q, r}`, in that island's own hex disc, and
  nothing in the simulation needs to know where an island sits relative to
  another. Islands are a GRAPH connected by migration, not a plane, so there is
  no shared coordinate system to agree on and no seam to keep in step.

  **This is a rendering concern and only a rendering concern**, which is exactly
  why a viewer may settle it unilaterally.
  """

  # 256 cells. Comfortably more than any fleet this will run on, so collisions
  # are rare, and fixed so that positions do not move when the fleet does.
  @side 16

  @typedoc "A cell in the layout grid, not a pixel and not a hex."
  @type at :: {non_neg_integer(), non_neg_integer()}

  @doc "How many cells across the world grid is."
  @spec side() :: pos_integer()
  def side, do: @side

  @doc """
  Every island placed, as `%{name => {col, row}}`.

  ## Deterministic to the last detail, including collisions

  Two islands can hash to one cell. The loser probes forward until it finds free
  ground, which means the outcome depends on who probes first, so **the names
  are sorted before placing**. Without that, two viewers holding the same
  islands in different orders would draw different maps and the layout would
  stop being a pure function of the set.
  """
  @spec place([String.t()]) :: %{String.t() => at()}
  def place(names) when is_list(names) do
    names
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reduce({%{}, MapSet.new()}, &settle/2)
    |> elem(0)
  end

  defp settle(name, {placed, taken}) do
    cell = free_from(:erlang.phash2(name, @side * @side), taken)
    {Map.put(placed, name, to_at(cell)), MapSet.put(taken, cell)}
  end

  # Linear probing, wrapping. The grid holds 256 and a fleet holds a handful, so
  # this walks one step in practice and terminates by construction: a full grid
  # is not a case this can reach without 256 islands.
  defp free_from(cell, taken) do
    case MapSet.member?(taken, cell) do
      true -> free_from(rem(cell + 1, @side * @side), taken)
      false -> cell
    end
  end

  defp to_at(cell), do: {rem(cell, @side), div(cell, @side)}

  @doc """
  How big the drawn world is, in islands: `{cols, rows}`.

  Counts OCCUPIED columns and rows rather than the span between them, because
  the empty ones are squeezed out. Four islands are at most a 4 by 4 box however
  far apart the hash threw them.
  """
  @spec extent(%{String.t() => at()}) :: {pos_integer(), pos_integer()}
  def extent(placed) when map_size(placed) == 0, do: {1, 1}

  def extent(placed), do: {length(ranks(placed, 0)), length(ranks(placed, 1))}

  @doc """
  Each island's top-left pixel, given a pitch: one island's width plus the sea
  around it.

  ## The squeeze happens here

  An island's drawn column is its RANK among the occupied columns, not its raw
  grid column. Columns 4, 7, 11 and 13 become 0, 1, 2 and 3, the ocean between
  them disappears, and the picture is the size of the world instead of the size
  of the grid it was placed on.

  **Order survives exactly**, because ranking is monotone: an island left of
  another stays left of it, whoever arrives or leaves.
  """
  @spec pixels(%{String.t() => at()}, pos_integer()) :: %{String.t() => {integer(), integer()}}
  def pixels(placed, pitch) do
    cols = ranks(placed, 0)
    rows = ranks(placed, 1)

    Map.new(placed, fn {name, {col, row}} ->
      {name, {rank_of(cols, col) * pitch, rank_of(rows, row) * pitch}}
    end)
  end

  # The occupied values on one axis, in order. 0 is the column, 1 the row.
  defp ranks(placed, axis) do
    placed |> Map.values() |> Enum.map(&elem(&1, axis)) |> Enum.uniq() |> Enum.sort()
  end

  defp rank_of(values, value), do: Enum.find_index(values, &(&1 == value))
end
