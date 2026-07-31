defmodule Biotope do
  @moduledoc """
  Read-only view onto the islands this node has heard from.

  An island is a `hecate-biotope` service running somewhere on the mesh: plants
  grow, creatures forage, breed and starve, and it says what happened. This app
  subscribes and renders. **It never publishes, never runs a world, and takes no
  dependency on the island's code.**

  That last point is the one worth defending. The contract is the published fact
  and its `fact_version`. The rumble did it the other way, sharing an engine
  library between the service and the site, and the two ended up pinned to
  different commits with a fingerprint that drifted and nothing comparing them.

  ## What arrives

  Two facts, on two topics, both carrying `island`, `tick` and `fact_version`:

    * `world_advanced` — counts and totals. Small enough to keep forever.
    * `world_charted` — where everything is. Ephemeral by nature.

  Kept separate by the island so a statistics reader does not pay for a hundred
  and seventy coordinates it will never draw.

  ## Coordinates

  Positions arrive as flat integer lists with a stride of two,
  `[q1, r1, q2, r2 | ...]`, because a pair would be a tuple and tuples do not
  survive the encoder. `points/1` turns that back into `{q, r}` pairs and
  `to_pixel/2` places them, using axial hex geometry: pointy-top, so a step in
  any of the six directions is the same distance.
  """

  alias Biotope.WatchIslands
  alias Biotope.WatchIslands.Board

  @doc "Island names heard from, sorted."
  defdelegate islands(), to: Board

  @doc "Latest facts for one island, or `nil`."
  defdelegate island(name), to: Board

  @doc "Whether anything has arrived yet."
  defdelegate empty?(), to: Board

  @doc "Subscribe the calling process to board changes."
  defdelegate subscribe(), to: WatchIslands

  @doc "Whether the site is configured to read islands at all."
  def configured?, do: Biotope.Mesh.configured?()

  @doc """
  Whether a mesh handle actually exists right now.

  Distinct from `configured?/0` on purpose: configured-and-dark and
  never-configured look identical on a page unless it is told them apart, and
  they need different responses from whoever is reading.
  """
  def watching? do
    match?({:ok, _pool, _realm}, Biotope.Mesh.handle())
  end

  @doc """
  Flat coordinate list to `{q, r}` pairs.

  A trailing odd element is dropped rather than raising: this is network input,
  and a truncated frame should cost one creature on one redraw, not the page.
  """
  @spec points(list()) :: [{integer(), integer()}]
  def points(flat) when is_list(flat) do
    flat
    |> Enum.chunk_every(2, 2, :discard)
    |> Enum.map(fn [q, r] -> {q, r} end)
  end

  def points(_other), do: []

  @doc """
  Axial hex to pixel, pointy-top, centred on the middle of a `size`-wide box.

  The board is sized from the fact's own `radius`, so a viewer never has to be
  configured to agree with a world it cannot see.
  """
  @spec to_pixel({integer(), integer()}, %{radius: number(), size: number()}) ::
          {float(), float()}
  def to_pixel({q, r}, %{radius: radius, size: size}) do
    cell = size / (2 * (radius + 1) * :math.sqrt(3))
    centre = size / 2
    {centre + cell * :math.sqrt(3) * (q + r / 2), centre + cell * 1.5 * r}
  end

  @doc "The drawing radius of one cell, for the same box."
  def cell_radius(%{radius: radius, size: size}), do: size / (2 * (radius + 1) * :math.sqrt(3))
end
