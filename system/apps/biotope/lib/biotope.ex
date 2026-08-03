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

  @doc "Islands refused because the board is full. Non-zero means a page is lying."
  defdelegate refused(), to: Board

  @doc "Milliseconds since this island last said anything, or `nil`."
  defdelegate quiet_for(name), to: Board

  # An island publishes counts about once a second. Fifteen is fifteen missed
  # beats: long enough that a slow tick or a dropped frame does not cry wolf,
  # short enough that a dead island is called dead while someone is still
  # looking at it. The elapsed time is always shown alongside, so the judgement
  # this constant makes is visible rather than hidden.
  @quiet_after_ms 15_000

  @doc """
  `:live`, `{:extinct, tick}`, `{:quiet, ms}`, or `:never_heard`.

  FOUR STATES, AND EACH WANTS A DIFFERENT RESPONSE FROM WHOEVER IS READING.
  Never heard from is a configuration question. Quiet is a transport question:
  the island may be fine and unreachable. Extinct is neither, and it is the one
  that would otherwise hide: an island whose last creature died goes on
  publishing perfectly, on time, with a tick that keeps advancing, so it reads
  as healthy unless someone happens to notice the population is zero.

  Extinction is checked FIRST, because a dead island that is also unreachable is
  still dead, and that is the more important fact about it.
  """
  @spec liveness(String.t()) ::
          :live | {:extinct, non_neg_integer()} | {:quiet, non_neg_integer()} | :never_heard
  def liveness(name), do: judge(island(name), quiet_for(name))

  defp judge(nil, _ms), do: :never_heard

  defp judge(%{stats: %{"extinct_at" => tick}}, _ms) when is_integer(tick),
    do: {:extinct, tick}

  defp judge(_row, ms) when is_integer(ms) and ms < @quiet_after_ms, do: :live
  defp judge(_row, ms) when is_integer(ms), do: {:quiet, ms}
  defp judge(_row, _ms), do: :never_heard

  @doc "Human-readable elapsed time, for a page to show next to a quiet island."
  def since(ms) when ms < 60_000, do: "#{div(ms, 1000)}s"
  def since(ms) when ms < 3_600_000, do: "#{div(ms, 60_000)}m"
  def since(ms), do: "#{div(ms, 3_600_000)}h"

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
  Flat `[q, r, strength, ...]` to `{q, r, strength}` triples.

  A SEPARATE STRIDE FROM `points/1`, AND THAT IS DELIBERATE ON THE ISLAND'S SIDE
  TOO. A scent mark is a position and a strength with no list to run parallel to,
  while creature energies do have one and are sent alongside rather than woven
  in. Mixing the two conventions is how a reader draws a plausible and completely
  wrong picture instead of failing, so the island publishes `scent_stride` with
  the data rather than leaving it to be assumed.

  A trailing partial mark is dropped rather than raising: this is network input,
  and a truncated frame should cost one smudge on one redraw, not the page.
  """
  @spec marks(list()) :: [{integer(), integer(), integer()}]
  def marks(flat) when is_list(flat) do
    flat
    |> Enum.chunk_every(3, 3, :discard)
    |> Enum.map(fn [q, r, s] -> {q, r, s} end)
  end

  def marks(_other), do: []

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

  # ══════════════════════════════════════════════════════════════════════
  # WHAT EACH CREATURE IS BUILT LIKE, WHICH IS THE POINT OF THE EXPERIMENT
  # ══════════════════════════════════════════════════════════════════════
  #
  # Fourteen fact versions carried where every creature was, how big it was and
  # how fast it fed, and not one carried what any of them was. This site drew an
  # ecology and the islands are running a neuroevolution experiment.
  #
  # A KIND IS A BODY PLAN AND A BRAIN: which of the four measurable fields it has
  # sensors for and at what reach, how many hidden nodes it computes with, and
  # which of the four possible acts it can perform at all. Nothing assigns these.
  # A founder is drawn at random and every birth may add a sensor, drop one,
  # widen its reach, grow a node, or gain and lose a purpose.
  #
  # THE ARCHITECTURES ARRIVE ONCE AND THE CREATURES POINT AT THEM. `kind_table`
  # holds each architecture present, once; `kind_of` is one index into it per
  # creature, parallel to `ids`. A hundred creatures share a couple of dozen
  # structures, so a genome per head would send the same twenty twenty times.

  # ⚠ THE WIRE SENDS INDEXES AND THESE ARE WHAT THEY MEAN. The island holds the
  # same two lists and pins their order with a test, because reordering either
  # would silently change the meaning of every kind table ever published: a
  # reader would draw a scent sensor where a ground sensor is and nothing would
  # look wrong.
  #
  # This site deliberately takes no dependency on the island's code, so it
  # mirrors the lists rather than importing them, and the mirror is the risk.
  # **These are the `fact_version` 14 orders.** A test pins them here too, which
  # is the most a reader can do: it cannot detect a change on the island, only
  # refuse to drift on its own.
  @fields [:creatures, :ground, :scent, :self]
  @purposes [:move, :breed, :grow, :eat]

  @doc "The four measurable fields, in wire order."
  def fields, do: @fields

  @doc "The four possible acts, in wire order."
  def purposes, do: @purposes

  @doc """
  Decode `kind_table` into the architectures it describes.

  Each is `%{sensors: [{field, reach}], hidden: n, purposes: [atom], raw: [int]}`.
  `raw` is kept because it is what the colour is derived from.

  A MALFORMED TABLE COSTS THE REST OF THE TABLE AND NOT THE PAGE. This is network
  input from a service on someone else's machine, possibly a version ahead. A
  truncated or nonsensical record stops the decode and returns what was read
  cleanly up to that point, which draws fewer kinds rather than crashing a
  spectator's tab.
  """
  @spec kinds(list()) :: [map()]
  def kinds(flat) when is_list(flat), do: decode_kinds(flat, [])
  def kinds(_other), do: []

  defp decode_kinds([], acc), do: Enum.reverse(acc)

  defp decode_kinds([n | rest], acc) when is_integer(n) and n >= 0 do
    take_kind(n, rest, Enum.split(rest, n * 2), acc)
  end

  defp decode_kinds(_malformed, acc), do: Enum.reverse(acc)

  defp take_kind(n, _rest, {sensors, [hidden, count | tail]}, acc)
       when is_integer(hidden) and is_integer(count) and count >= 0 and
              length(sensors) == n * 2 do
    {purposes, remainder} = Enum.split(tail, count)
    finish_kind(purposes, count, [n | sensors] ++ [hidden | purposes], remainder, acc)
  end

  defp take_kind(_n, _rest, _split, acc), do: Enum.reverse(acc)

  defp finish_kind(purposes, count, raw, remainder, acc) when length(purposes) == count do
    [n | body] = raw
    {sensors, [hidden | acts]} = Enum.split(body, n * 2)

    kind = %{
      sensors: sensor_pairs(sensors),
      hidden: hidden,
      purposes: Enum.map(acts, &purpose_name/1),
      raw: raw
    }

    decode_kinds(remainder, [kind | acc])
  end

  defp finish_kind(_purposes, _count, _raw, _remainder, acc), do: Enum.reverse(acc)

  defp sensor_pairs(flat) do
    flat
    |> Enum.chunk_every(2, 2, :discard)
    |> Enum.map(fn [field, reach] -> {field_name(field), reach} end)
  end

  # An index this reader does not recognise is shown as itself rather than
  # guessed at, because an island a version ahead is a normal thing to meet on a
  # fleet mid-rollout and inventing a name for its new field would be worse than
  # admitting the number.
  defp field_name(i) when is_integer(i) and i >= 0 and i < length(@fields),
    do: Enum.at(@fields, i)

  defp field_name(other), do: other

  defp purpose_name(i) when is_integer(i) and i >= 0 and i < length(@purposes),
    do: Enum.at(@purposes, i)

  defp purpose_name(other), do: other

  @doc """
  How many creatures hold each kind, keyed by index into the table.
  """
  @spec kind_tally(list()) :: %{integer() => integer()}
  def kind_tally(kind_of) when is_list(kind_of),
    do: Enum.frequencies(Enum.filter(kind_of, &is_integer/1))

  def kind_tally(_other), do: %{}

  @doc """
  A kind as `0xRRGGBB`.

  ⚠ DERIVED FROM THE ARCHITECTURE AND NOT FROM ITS INDEX IN THE TABLE. The table
  holds the kinds present, sorted, so the moment one appears or dies every index
  above it shifts. A colour taken from the index would repaint the whole board
  for a change to one creature, and a viewer would read that as the population
  turning over.

  IT ALSO MATCHES THE ISLAND'S OWN PAGE, EXACTLY. `:erlang.phash2/2` is portable
  across nodes and ERTS versions, and the island hashes this same flat integer
  list, so a kind wears one colour whether you are watching from the island's
  local page or from here. That is worth more than it looks: it is the only way
  to compare two drawings of one world by eye.
  """
  @spec kind_rgb([integer()]) :: non_neg_integer()
  def kind_rgb(raw) when is_list(raw), do: hsl(:erlang.phash2(raw, 360), 62, 56)
  def kind_rgb(_other), do: 0x888888

  # Integer HSL, mirroring the island's arithmetic step for step. Saturation and
  # lightness are fixed so every kind reads at the same weight against the ground
  # and the eye sorts them by hue alone.
  defp hsl(h, s, l) do
    c = (100 - abs(2 * l - 100)) * s
    x = div(c * (100 - abs(rem(div(h * 100, 60), 200) - 100)), 10_000)
    m = l * 100 - div(c, 2)
    rgb(div(h, 60), div(c, 100), x, div(m, 100))
  end

  defp rgb(0, c, x, m), do: pack(c + m, x + m, m)
  defp rgb(1, c, x, m), do: pack(x + m, c + m, m)
  defp rgb(2, c, x, m), do: pack(m, c + m, x + m)
  defp rgb(3, c, x, m), do: pack(m, x + m, c + m)
  defp rgb(4, c, x, m), do: pack(x + m, m, c + m)
  defp rgb(_5, c, x, m), do: pack(c + m, m, x + m)

  defp pack(r, g, b), do: clamp(r) * 0x10000 + clamp(g) * 0x100 + clamp(b)

  defp clamp(v), do: max(0, min(255, div(v * 255, 100)))

  @doc """
  A kind in words: "3 senses, 1 node, 4 acts".

  Short on purpose. The full body plan goes in a table beside the board; this is
  what fits under a swatch.
  """
  @spec kind_label(map()) :: String.t()
  def kind_label(%{sensors: sensors, hidden: hidden, purposes: purposes}) do
    "#{count(length(sensors), "sense", "senses")}, " <>
      "#{count(hidden, "node", "nodes")}, " <>
      "#{count(length(purposes), "act", "acts")}"
  end

  defp count(1, singular, _plural), do: "1 #{singular}"
  defp count(n, _singular, plural), do: "#{n} #{plural}"
end
