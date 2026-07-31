defmodule BeamCampusWeb.BiotopeComponents do
  @moduledoc """
  Shared chrome and shared drawing for the biotope pages.

  Three pages now, one feature: the islands as a set, one island in detail, and
  where they have all been. The switch below is what keeps them findable from
  each other; before it existed the history linked back and nothing linked
  forward, so a page was reachable only by someone who already knew the URL.

  Lives here rather than in a generic components module because it belongs to
  this feature and nothing else uses it.
  """
  use Phoenix.Component
  use Phoenix.VerifiedRoutes, endpoint: BeamCampusWeb.Endpoint, router: BeamCampusWeb.Router

  @doc """
  The faces of this feature, and the way back up.

  `current` is `:now` or `:history`. The active tab is still a link rather than
  a dead span, so the page can be re-entered to force a refresh, and it carries
  `aria-current` so a screen reader is told which one it is on rather than
  having to infer it from styling.
  """
  attr :current, :atom, required: true

  def switch(assigns) do
    ~H"""
    <nav class="mt-6 flex flex-wrap items-center justify-between gap-3" aria-label="Biotope views">
      <div class="join">
        <.link
          navigate={~p"/research/workbench/biotope"}
          class={["btn btn-sm join-item", @current == :now && "btn-active"]}
          aria-current={@current == :now && "page"}
        >
          Now
        </.link>
        <.link
          navigate={~p"/research/workbench/biotope/history"}
          class={["btn btn-sm join-item", @current == :history && "btn-active"]}
          aria-current={@current == :history && "page"}
        >
          History
        </.link>
      </div>

      <.link navigate={~p"/research/workbench"} class="link link-hover text-sm opacity-60">
        ← All experiments
      </.link>
    </nav>
    """
  end

  @doc """
  What state an island is in.

  FOUR STATES, AND EACH WANTS A DIFFERENT RESPONSE. Never heard from is a
  configuration question. Quiet is a transport question: the island may be fine
  and merely unreachable. Extinct is neither, and it is the one that would
  otherwise hide, because a dead island publishes perfectly well. Live is the
  boring one.

  The elapsed time and the tick are always shown next to the verdict, so the
  judgement each constant makes is visible rather than buried.
  """
  attr :liveness, :any, required: true

  def liveness(%{liveness: :live} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 text-xs">
      <span class="inline-block h-1.5 w-1.5 rounded-full bg-success"></span>
      <span class="opacity-60">live</span>
    </span>
    """
  end

  # AN EXTINCT ISLAND PUBLISHES PERFECTLY WELL. Its plants regrow, its tick
  # advances, every fact arrives on time, and it reads as healthy unless someone
  # notices the population is zero. Named here so nobody has to.
  def liveness(%{liveness: {:extinct, tick}} = assigns) do
    assigns = assign(assigns, tick: tick)

    ~H"""
    <span
      class="inline-flex items-center gap-1.5 text-xs"
      title="Every creature died. Nothing reseeds a world, so this is permanent."
    >
      <span class="inline-block h-1.5 w-1.5 rounded-full bg-error"></span>
      <span class="text-error">extinct at tick {@tick}</span>
    </span>
    """
  end

  def liveness(%{liveness: {:quiet, ms}} = assigns) do
    assigns = assign(assigns, since: Biotope.since(ms))

    ~H"""
    <span class="inline-flex items-center gap-1.5 text-xs" title="No fact has arrived for this long">
      <span class="inline-block h-1.5 w-1.5 rounded-full bg-warning"></span>
      <span class="text-warning">quiet {@since}</span>
    </span>
    """
  end

  def liveness(assigns) do
    ~H"""
    <span class="text-xs opacity-40">never heard from</span>
    """
  end

  @doc """
  The board is capped, and a page that has silently stopped admitting islands
  looks exactly like a fleet that has stopped growing.
  """
  attr :refused, :integer, required: true

  def refused_notice(%{refused: n} = assigns) when n > 0 do
    ~H"""
    <p class="mt-4 rounded border border-warning/40 bg-warning/10 p-3 text-sm text-warning">
      {@refused} islands were refused because this node's board is full. What you
      are looking at is a subset, not the fleet.
    </p>
    """
  end

  def refused_notice(assigns), do: ~H""

  @doc """
  A hex disc: trails, plants, creatures, and the rim.

  Sized from the chart's own radius, so a viewer never has to be configured to
  agree with a world it cannot see.

  THREE LAYERS, BOTTOM TO TOP, AND THE ORDER IS THE POINT. Trails go under
  everything because they are the past and should not obscure the present.
  Creatures go on top because they are the only thing that decides anything.

  A CREATURE IS DRAWN THE SIZE OF ITS ENERGY, which is not decoration. In this
  world the stronger consumes the weaker on contact, so energy IS armour and how
  big a dot is is the most informative thing about it. Drawn against an absolute
  scale rather than the largest in the frame: a creature twice the size of
  another must always look twice the size, or a frame in which everything is
  starving would silently rescale itself to look ordinary.

  AND THE COLOUR OF ITS LINEAGE. A creature carries a heritable eight-bit scent
  signature, and reads a trail by how unlike itself it smells, so relatedness is
  already what the signature is. Colouring by it turns the disc into a family
  map: kin share a colour, long-separated lineages do not, and whether the
  population is one family or several becomes something you see rather than a
  number you read. When migration exists, a foreigner will simply be the wrong
  colour, with no further machinery.
  """
  attr :chart, :map, required: true
  attr :size, :integer, default: 320

  # The energy at which a creature is drawn at full size. Above it they stop
  # growing, because past a point the only question is who is larger.
  @energy_full 300
  # A mark at the island's ceiling. Anything fresher is simply as strong as
  # ground gets.
  @scent_full 30

  def disc(assigns) do
    box = %{radius: assigns.chart["radius"] || 20, size: assigns.size}
    cell = Biotope.cell_radius(box)

    assigns =
      assign(assigns,
        cell: cell,
        plants: place(assigns.chart["plants"], box),
        creatures: creatures(assigns.chart, box, cell),
        trails: trails(assigns.chart, box)
      )

    ~H"""
    <svg
      viewBox={"0 0 #{@size} #{@size}"}
      class="w-full h-auto rounded bg-black/40"
      role="img"
      aria-label={"#{length(@creatures)} creatures coloured by lineage, #{length(@plants)} plants and #{length(@trails)} scent marks"}
    >
      <circle
        cx={@size / 2}
        cy={@size / 2}
        r={@size / 2 - @cell}
        fill="none"
        stroke="currentColor"
        stroke-width="1"
        opacity="0.12"
      />
      <circle
        :for={{x, y, strength} <- @trails}
        cx={x}
        cy={y}
        r={@cell * 1.2}
        fill="#8B7CE8"
        opacity={strength}
      />
      <circle :for={{x, y} <- @plants} cx={x} cy={y} r={@cell * 0.55} fill="#3FBF7F" opacity="0.85" />
      <circle :for={{x, y, r, colour} <- @creatures} cx={x} cy={y} r={r} fill={colour} />
    </svg>
    """
  end

  @doc """
  Population and standing crop over time.

  Each series is scaled to its OWN maximum, because they are different
  quantities in different units and one axis would say something false about
  their relative size. What the pair is for is the shape: grazing pressure
  against regrowth.
  """
  attr :samples, :list, required: true
  attr :w, :integer, default: 640
  attr :h, :integer, default: 120
  attr :class, :string, default: ""

  def sparkline(%{samples: []} = assigns) do
    ~H"""
    <p class={["text-xs opacity-40", @class]}>no history yet</p>
    """
  end

  def sparkline(assigns) do
    assigns =
      assign(assigns,
        population: polyline(assigns.samples, & &1.population, assigns.w, assigns.h),
        plants: polyline(assigns.samples, & &1.plants, assigns.w, assigns.h)
      )

    ~H"""
    <svg
      viewBox={"0 0 #{@w} #{@h}"}
      class={["w-full h-auto rounded bg-black/40", @class]}
      role="img"
      aria-label={"Population and plants over #{length(@samples)} samples"}
    >
      <polyline points={@plants} fill="none" stroke="#3FBF7F" stroke-width="1.5" opacity="0.8" />
      <polyline points={@population} fill="none" stroke="#F2B142" stroke-width="1.5" />
    </svg>
    """
  end

  @doc """
  What the population BECAME, over time.

  Two evolved quantities rather than two counts. Amber is the share of eaten
  energy that came from other creatures; blue is how much measuring a creature
  carries. Neither is a rule and neither is read by the island's physics: they
  are counted from what happened.

  Each is scaled to its own maximum, because they are different quantities in
  different units and one axis would say something false about their relative
  size. What the pair is for is the SHAPE: whether a world that eats itself is
  also a world that stops bothering to look.
  """
  attr :samples, :list, required: true
  attr :w, :integer, default: 640
  attr :h, :integer, default: 120
  attr :class, :string, default: ""

  def trends(%{samples: []} = assigns) do
    ~H"""
    <p class={["text-xs opacity-40", @class]}>no history yet</p>
    """
  end

  def trends(assigns) do
    assigns =
      assign(assigns,
        meat: polyline(assigns.samples, & &1.from_creatures_pct, assigns.w, assigns.h),
        sensors: polyline(assigns.samples, & &1.sensor_mean, assigns.w, assigns.h)
      )

    ~H"""
    <svg
      viewBox={"0 0 #{@w} #{@h}"}
      class={["w-full h-auto rounded bg-black/40", @class]}
      role="img"
      aria-label={"Share of energy from creatures, and sensors carried, over #{length(@samples)} samples"}
    >
      <polyline points={@sensors} fill="none" stroke="#6C9BD5" stroke-width="1.5" opacity="0.9" />
      <polyline points={@meat} fill="none" stroke="#F2B142" stroke-width="1.5" />
    </svg>
    """
  end

  @doc """
  Whether the body plan is still moving.

  The census says what the population is built from NOW. These say whether that
  is settled or still churning, which a census on its own cannot distinguish: a
  lineage steadily gaining and losing sensors and one that has not changed in a
  thousand ticks can show the identical census.

  Totals since the world began, never reset, so a reader who looks twice can
  recover the rate and a reader who looks once cannot be misled by one.
  """
  attr :stats, :map, required: true

  def churn(assigns) do
    ~H"""
    <div>
      <h3 class="text-xs uppercase tracking-wide opacity-50">body plans, since the start</h3>
      <dl class="mt-2 grid grid-cols-2 gap-3 text-sm">
        <.stat label="sensors gained" value={@stats["sensors_gained"]} />
        <.stat label="sensors lost" value={@stats["sensors_lost"]} />
      </dl>
    </div>
    """
  end

  @doc "One number with its label."
  attr :label, :string, required: true
  attr :value, :any, required: true

  def stat(assigns) do
    ~H"""
    <div>
      <dt class="text-xs uppercase tracking-wide opacity-50">{@label}</dt>
      <dd class="font-mono">{number(@value)}</dd>
    </div>
    """
  end

  @doc """
  Which rules an island runs.

  Two islands sharing a fingerprint are comparable; two that do not are
  different games, and their populations must not be read against each other.
  Shown on every island for that reason, not as decoration.
  """
  attr :stats, :map, required: true

  def econ(%{stats: nil} = assigns), do: ~H""

  def econ(assigns) do
    assigns = assign(assigns, id: assigns.stats["econ_id"], econ: assigns.stats["econ"] || %{})

    ~H"""
    <details class="mt-3 text-xs">
      <summary class="cursor-pointer opacity-60">
        rules <code class="font-mono">{@id}</code>
      </summary>
      <dl class="mt-2 grid grid-cols-2 gap-x-4 gap-y-1 sm:grid-cols-3">
        <div :for={{k, v} <- Enum.sort(@econ)} class="flex justify-between gap-2">
          <dt class="opacity-50">{k}</dt>
          <dd class="font-mono">{v}</dd>
        </div>
      </dl>
    </details>
    """
  end

  @doc """
  How much of what this island eats is other creatures.

  THE HEADLINE NUMBER OF THIS WORLD AND THE ONE THAT USED TO BE INVISIBLE. There
  is no herbivore field and no carnivore flag anywhere in the island: this is
  counted from where energy actually came from, afterwards, and nothing in the
  rules ever reads it.

  Green is what came from plants and amber what came from creatures, matching the
  disc above, so the bar and the picture are speaking the same language.
  """
  attr :stats, :map, required: true

  def share(assigns) do
    assigns = assign(assigns, pct: assigns.stats["from_creatures_pct"] || 0)

    ~H"""
    <div>
      <dt class="text-xs uppercase tracking-wide opacity-50">energy from creatures</dt>
      <dd class="mt-1 font-mono text-lg leading-none">{@pct}%</dd>
      <div
        class="mt-2 h-1.5 w-full overflow-hidden rounded bg-success/40"
        role="img"
        aria-label={"#{@pct} percent of eaten energy came from other creatures"}
      >
        <div class="h-full bg-warning" style={"width: #{@pct}%"}></div>
      </div>
    </div>
    """
  end

  @doc """
  What the population is built from, per measurable field.

  A CENSUS AND NOT A VERDICT: it says what survived, not what was useful, and
  those are only the same thing after enough generations that drift has been
  outvoted. A field at zero carriers has been selected out of this island
  entirely, which is a finding worth being able to see at a glance.

  There is no eye and no nose. A sensor is a field and a reach, and which fields
  exist is a fact about what there is to measure rather than a menu of senses.
  """
  attr :stats, :map, required: true

  def census(assigns) do
    assigns =
      assign(assigns,
        rows: census_rows(assigns.stats),
        per_creature: (assigns.stats["sensor_mean"] || 0) / 100
      )

    ~H"""
    <div>
      <div class="flex items-baseline justify-between">
        <h3 class="text-xs uppercase tracking-wide opacity-50">what they measure</h3>
        <span class="font-mono text-xs opacity-60">{@per_creature} per creature</span>
      </div>
      <p class="mt-1 text-xs opacity-40">
        carriers, then how hard the brain acts on it. A sensor that is carried and
        ignored is an organ being paid for and changing nothing.
      </p>
      <dl class="mt-2 space-y-1.5">
        <div :for={{field, carriers, pct, acted} <- @rows} class="flex items-center gap-2 text-xs">
          <dt class="w-20 shrink-0 opacity-60">{field}</dt>
          <div class="h-1.5 flex-1 overflow-hidden rounded bg-base-content/10">
            <div class="h-full bg-info" style={"width: #{pct}%"}></div>
          </div>
          <dd class="w-10 shrink-0 text-right font-mono opacity-70">{carriers}</dd>
          <dd
            class={["w-10 shrink-0 text-right font-mono", acted == "0.0" && "opacity-30"]}
            title="Mean weight the brain puts on this measurement. Zero is an organ that is carried, paid for, and ignored."
          >
            {acted}
          </dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Deaths by cause, never summed.

  "The population crashed" is not a finding. Starvation, predation and old age
  are three different stories and one total cannot tell them apart, so the island
  counts them separately and so does this.
  """
  attr :stats, :map, required: true

  def deaths(assigns) do
    ~H"""
    <div>
      <h3 class="text-xs uppercase tracking-wide opacity-50">deaths, by cause</h3>
      <dl class="mt-2 grid grid-cols-3 gap-3 text-sm">
        <.stat label="eaten" value={@stats["consumed"]} />
        <.stat label="starved" value={@stats["starved"]} />
        <.stat label="of old age" value={@stats["aged_out"]} />
      </dl>
    </div>
    """
  end

  @doc """
  How distinguishable the population smells.

  A property of the SIGNAL and not of anything evolved to use it. A creature
  reads a trail by how unlike itself it smells, so one signature everywhere means
  mutual kin and a nose with nothing to discriminate. Two unrelated signatures
  differ in half their components, which is why 50 rather than 100 is the
  interesting mark.
  """
  attr :stats, :map, required: true

  def signature(assigns) do
    ~H"""
    <div>
      <h3 class="text-xs uppercase tracking-wide opacity-50">signatures</h3>
      <dl class="mt-2 grid grid-cols-2 gap-3 text-sm">
        <.stat label="distinct" value={@stats["scent_tags"]} />
        <.stat label="spread" value={@stats["scent_spread"]} />
      </dl>
    </div>
    """
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp place(flat, box) do
    flat
    |> Biotope.points()
    |> Enum.map(&Biotope.to_pixel(&1, box))
  end

  # Energies run PARALLEL to creatures rather than interleaved, so they are
  # zipped here. Padded rather than assumed equal: a truncated frame, or an
  # island still publishing the older chart with no energies at all, should cost
  # accurate sizing and not the page.
  defp creatures(chart, box, cell) do
    points = Biotope.points(chart["creatures"])
    energies = pad(chart["energies"] || [], length(points), 0)
    signatures = pad(chart["signatures"] || [], length(points), nil)

    [points, energies, signatures]
    |> Enum.zip()
    |> Enum.map(fn {point, energy, tag} ->
      {x, y} = Biotope.to_pixel(point, box)
      {x, y, radius_for(cell, energy), lineage_colour(tag)}
    end)
  end

  defp pad(values, wanted, filler) do
    values ++ List.duplicate(filler, max(0, wanted - length(values)))
  end

  # A floor as well as a scale, because a creature about to starve is still
  # there and a dot of radius zero is a creature the picture has lost.
  defp radius_for(cell, energy) when is_integer(energy) and energy > 0 do
    cell * (0.35 + 0.65 * min(1.0, energy / @energy_full))
  end

  defp radius_for(cell, _energy), do: cell * 0.35

  # EACH BIT GROUP DRIVES ONE CHANNEL, which is the whole reason this is not a
  # hue. Mapping the byte onto a colour wheel would put tags 127 and 128 side by
  # side though they differ in every single component, and split kin one flip
  # apart across half the spectrum. Here a single mutation moves exactly one
  # channel by one step, so how alike two creatures look is how related they
  # actually are.
  #
  # Kept bright: the disc is dark, and a lineage that happened to inherit a low
  # byte should not be invisible.
  defp lineage_colour(tag) when is_integer(tag) and tag >= 0 do
    r = 90 + Bitwise.band(tag, 0x07) * 22
    g = 90 + Bitwise.band(Bitwise.bsr(tag, 3), 0x07) * 22
    b = 90 + Bitwise.band(Bitwise.bsr(tag, 6), 0x03) * 50
    "rgb(#{r},#{g},#{b})"
  end

  # An island still publishing the older chart sends no signatures. Amber is what
  # every creature used to be, so an unlabelled one keeps that rather than
  # pretending to a lineage it did not declare.
  defp lineage_colour(_absent), do: "#F2B142"

  # Faint on purpose. A trail is evidence that something passed, and at full
  # strength it would read as a wall.
  defp trails(chart, box) do
    chart["scent"]
    |> Biotope.marks()
    |> Enum.map(fn {q, r, strength} ->
      {x, y} = Biotope.to_pixel({q, r}, box)
      {x, y, Float.round(min(1.0, strength / @scent_full) * 0.30, 3)}
    end)
  end

  # NOT called `path`: Phoenix.VerifiedRoutes imports path/2, and shadowing it
  # fails at compile time inside ~p with a message about a path string that
  # names neither this function nor the collision.
  defp polyline([], _get, _w, _h), do: ""

  defp polyline(samples, get, w, h) do
    values = Enum.map(samples, get)
    top = max(Enum.max(values), 1)
    span = max(length(values) - 1, 1)

    values
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {v, i} ->
      x = i / span * w
      y = h - v / top * (h - 4) - 2
      "#{Float.round(x, 1)},#{Float.round(y, 1)}"
    end)
  end

  # Ordered as the island orders its fields, so two islands read the same way.
  defp census_rows(stats) do
    census = stats["sensors"] || %{}
    population = max(stats["population"] || 0, 1)

    for field <- ~w(plants creatures scent) do
      carriers = get_in(census, [field, "carriers"]) || 0
      attention = (get_in(census, [field, "attention"]) || 0) / 100

      {field, carriers, min(100, round(carriers * 100 / population)),
       :erlang.float_to_binary(attention, decimals: 1)}
    end
  end

  defp number(nil), do: "–"
  defp number(n) when is_integer(n), do: Integer.to_string(n)
  defp number(other), do: to_string(other)
end
