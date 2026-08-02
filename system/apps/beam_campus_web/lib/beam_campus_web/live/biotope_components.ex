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

  # ROOM FOR THE AXES, which is the whole reason these charts have margins at
  # all. The left gutter holds the y labels and the bottom band holds the ticks;
  # sizing a plot without them is how a chart ends up with its own little scroll
  # bar or with the numbers clipped off.
  @pad %{left: 46, right: 12, top: 10, bottom: 20}

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

  A CREATURE IS DRAWN THE SIZE OF ITS BODY, which is not decoration: the island
  decides every contest on structure alone, so the body is what says who wins one.
  It used to be drawn the size of its STORE, which was right until world 6 split
  the two and wrong for three worlds after.

  Drawn against an absolute scale rather than the largest in the frame, so a
  board where everything has shrunk looks shrunken instead of quietly rescaling
  itself to look ordinary. Area carries the quantity, not radius.

  AND THE COLOUR OF HOW FAST IT FEEDS. Pale is gentle and deep is voracious.
  Feeding slower than the ground comes back holds a cell indefinitely; feeding
  harder strips it and forces a move. So the colour is the prudent-to-greedy
  axis, and a patch of one shade is a patch of creatures making a living the same
  way.
  """
  attr :chart, :map, required: true
  attr :id, :string, required: true
  attr :size, :integer, default: 320
  attr :ceiling, :integer, default: 400
  attr :class, :string, default: ""

  # The body at which a creature is drawn at full size, well above the 400 a
  # founder starts with, because world 9's populations build past 4,000 and the
  # whole story there is the range between them.
  @frame_full 2500
  # A mark at the island's ceiling. Anything fresher is simply as strong as
  # ground gets.
  @scent_full 30

  def disc(assigns) do
    box = %{radius: assigns.chart["radius"] || 20, size: assigns.size}
    cell = Biotope.cell_radius(box)
    ground = soil(assigns.chart, box, assigns.ceiling)
    creatures = creatures(assigns.chart, box, cell, assigns.ceiling)
    trails = trails(assigns.chart, box)

    assigns =
      assign(assigns,
        cell: cell,
        counts: {length(creatures), length(ground), length(trails)},
        ground: pack(ground),
        creatures: pack(creatures),
        trails: pack(trails),
        rim: pack_rim(assigns.size, cell, assigns.chart["radius"] || 20)
      )

    ~H"""
    <figure class={["relative", @class]}>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".Disc">
        // THE BOARD, PAINTED RATHER THAN BUILT.
        //
        // This used to be 5,781 SVG circles, 85% of a 711 KB document, rebuilt
        // and re-diffed on every fact. Nothing was wrong with LiveView's
        // diffing: on a board where every mark moves every tick, almost nothing
        // is unchanged, so the diff was nearly the whole page. The fix is not a
        // smaller diff, it is to stop sending markup for a particle field.
        //
        // WHAT ARRIVES IS NUMBERS AND NOTHING ELSE. Elixir has already decided
        // where every mark goes, how big it is and what colour it is, because
        // those are statements about the physics and they are documented and
        // tested there. Nothing here interprets anything; it only paints.
        //
        // No library. A hex board of about 1,300 cells and 800 creatures is not
        // a job that needs one, and the things that make it look like a place
        // rather than a scatter plot are all plain canvas: hexagons that tile
        // with no gaps, a glow on the living, and motion carried between frames
        // instead of teleporting twice a second.
        const nums = (el, key) => JSON.parse(el.dataset[key] || "[]")
        const css = (rgb) => "#" + rgb.toString(16).padStart(6, "0")

        export default {
          mounted() {
            this.ctx = this.el.getContext("2d")
            this.was = new Map()
            this.now = new Map()
            // How long a step takes to play out. Matches the page's redraw
            // interval, so a tween finishes exactly as the next frame lands.
            this.span = 500
            this.fit()
            this.read()
            this.paint(1)
          },

          // A FACT ARRIVES TWICE A SECOND AND A CREATURE MOVES ONE CELL, so
          // without this the board is a slideshow: everything teleports, and
          // nothing about which way anything was going survives the jump.
          //
          // Keeping the previous positions BY ID is what makes it possible at
          // all. Matching by position in the list would slide marks across the
          // board that never moved, because births and deaths reshuffle it every
          // tick and the mean creature here lives about two of them.
          updated() {
            this.was = this.now || new Map()
            this.read()
            this.now = new Map()
            for (let i = 0; i < this.creatures.length; i += 5) {
              this.now.set(this.creatures[i], [this.creatures[i + 1], this.creatures[i + 2]])
            }
            this.started = performance.now()
            this.animate()
          },

          animate() {
            cancelAnimationFrame(this.frame)
            const step = () => {
              const ease = Math.min(1, (performance.now() - this.started) / this.span)
              this.paint(ease)
              if (ease < 1) this.frame = requestAnimationFrame(step)
            }
            this.frame = requestAnimationFrame(step)
          },

          destroyed() {
            cancelAnimationFrame(this.frame)
          },

          // RETINA, or the whole thing looks soft. A canvas has real pixels
          // where an svg had none, so it has to be told how many.
          fit() {
            const dpr = window.devicePixelRatio || 1
            const size = parseInt(this.el.dataset.size, 10)
            this.el.width = size * dpr
            this.el.height = size * dpr
            this.ctx.scale(dpr, dpr)
            this.size = size
          },

          read() {
            this.cell = parseFloat(this.el.dataset.cell)
            this.rim = nums(this.el, "rim")
            this.ground = nums(this.el, "ground")
            this.trails = nums(this.el, "trails")
            this.creatures = nums(this.el, "creatures")
          },

          paint(ease) {
            const c = this.ctx
            c.clearRect(0, 0, this.size, this.size)

            // THE GROUND IS A FIELD AND GETS A FIELD'S PRIMITIVE. Circles left
            // gaps between cells and read as a dot screen; hexagons tile the
            // disc exactly, so grazed ground reads as bare terrain rather than
            // as holes in something.
            for (let i = 0; i < this.ground.length; i += 4) {
              c.globalAlpha = this.ground[i + 3] / 100
              c.fillStyle = css(this.ground[i + 2])
              this.hex(this.ground[i], this.ground[i + 1])
              c.fill()
            }

            // A trail is evidence something passed. Faint on purpose: at full
            // strength it reads as a wall.
            c.fillStyle = "#8B7CE8"
            for (let i = 0; i < this.trails.length; i += 3) {
              c.globalAlpha = this.trails[i + 2] / 100
              c.beginPath()
              c.arc(this.trails[i], this.trails[i + 1], this.cell * 1.2, 0, 6.284)
              c.fill()
            }

            // The living, on top, because they are the only thing that decides
            // anything. The glow is not decoration: it separates objects from
            // the field they stand on, which was the one thing a single shared
            // primitive could never do.
            c.globalAlpha = 1
            for (let i = 0; i < this.creatures.length; i += 5) {
              const id = this.creatures[i]
              const colour = css(this.creatures[i + 4])
              const r = this.creatures[i + 3]
              const to = [this.creatures[i + 1], this.creatures[i + 2]]
              const from = this.was.get(id)

              // A STREAK IS THE TWEEN PATH DRAWN, so movement and its history
              // are one thing rather than two. Only for a mark that was here
              // last frame: something just born has no past and must not be
              // given one.
              if (from && ease < 1) {
                c.globalAlpha = 0.35 * (1 - ease)
                c.strokeStyle = colour
                c.lineWidth = Math.max(1, r * 0.8)
                c.lineCap = "round"
                c.beginPath()
                c.moveTo(from[0], from[1])
                c.lineTo(from[0] + (to[0] - from[0]) * ease, from[1] + (to[1] - from[1]) * ease)
                c.stroke()
              }

              const x = from ? from[0] + (to[0] - from[0]) * ease : to[0]
              const y = from ? from[1] + (to[1] - from[1]) * ease : to[1]

              // Something newly born fades in rather than appearing, which is
              // the difference between a world and a slideshow.
              c.globalAlpha = from ? 1 : ease
              c.shadowColor = colour
              c.shadowBlur = Math.max(2, r)
              c.fillStyle = colour
              c.beginPath()
              c.arc(x, y, r, 0, 6.284)
              c.fill()
            }
            c.shadowBlur = 0

            // The rim last, over everything, so the board reads as an object
            // with an edge rather than as a drawing that happens to stop.
            c.globalAlpha = 0.35
            c.strokeStyle = "currentColor"
            c.strokeStyle = getComputedStyle(this.el).color
            c.lineWidth = 1
            c.beginPath()
            for (let i = 0; i < this.rim.length; i += 2) {
              i === 0 ? c.moveTo(this.rim[0], this.rim[1]) : c.lineTo(this.rim[i], this.rim[i + 1])
            }
            c.closePath()
            c.stroke()
            c.globalAlpha = 1
          },

          // Pointy-top, which is what the island's own axial-to-pixel mapping
          // produces: corners at 60 degree steps offset by 30.
          hex(x, y) {
            const c = this.ctx
            c.beginPath()
            for (let i = 0; i < 6; i++) {
              const a = (Math.PI / 180) * (60 * i - 30)
              const px = x + this.cell * Math.cos(a)
              const py = y + this.cell * Math.sin(a)
              i === 0 ? c.moveTo(px, py) : c.lineTo(px, py)
            }
            c.closePath()
          }
        }
      </script>
      <canvas
        id={@id}
        phx-hook=".Disc"
        phx-update="ignore"
        width={@size}
        height={@size}
        class="w-full h-auto rounded bg-black/40"
        data-size={@size}
        data-cell={Float.round(@cell, 2)}
        data-rim={@rim}
        data-ground={@ground}
        data-trails={@trails}
        data-creatures={@creatures}
        role="img"
        aria-label={summary(@counts)}
      >
      </canvas>
    </figure>
    """
  end

  defp summary({creatures, ground, trails}) do
    "#{creatures} creatures coloured by how fast they feed, " <>
      "#{ground} cells holding energy and #{trails} scent marks"
  end

  # FLAT INTEGERS, which is the same discipline the island uses on the wire and
  # for the same reason: a list of numbers is small, and anything richer costs
  # more to carry than it is worth.
  #
  # Colours arrive as 0xRRGGBB and alpha in hundredths, so every value in every
  # one of these arrays is a plain integer and the hook reconstructs what it
  # needs. Coordinates are rounded to whole pixels because the canvas is drawing
  # to whole pixels anyway.
  defp pack(marks) do
    marks |> Enum.flat_map(&Tuple.to_list/1) |> Enum.map(&round/1) |> Jason.encode!()
  end

  defp pack_rim(size, cell, radius) do
    centre = size / 2
    reach = :math.sqrt(3) * radius * cell + cell

    0..5
    |> Enum.flat_map(fn i ->
      angle = :math.pi() / 3 * i
      [round(centre + reach * :math.cos(angle)), round(centre + reach * :math.sin(angle))]
    end)
    |> Jason.encode!()
  end

  @doc """
  The colours every chart on these pages draws from, as CSS custom properties.

  ## Three slots, and three is the limit rather than a preference

  Both modes were checked with the data-viz validator rather than by eye. Six
  hues, one per quantity, FAILED the normal-vision floor in light mode and both
  the colourblind and normal-vision floors in dark: the magenta and the red sat
  7.8 apart against a floor of 15, which is two lines a reader with ordinary
  colour vision cannot tell apart. Three passes every check in both modes, worst
  colourblind pair 9.2 light and 9.4 dark against a target of 8.

  So colour carries identity only for the two things the DISC also shows, the
  ground and the creatures, and every derived quantity shares one accent. Each
  chart is titled and holds one series, so the title carries the identity and the
  colour reinforces it. That is also why there is no legend on any of them: a
  legend for one series repeats its own title.

  ## Two modes, both selected

  The dark values are the same three hues stepped for a dark surface, not an
  automatic flip. Declared under the media query AND the theme attribute, because
  this site's toggle writes `data-theme` and that must beat the operating system
  in both directions.

  One light-mode step, the green, sits at 2.74:1 against the light surface where
  3:1 is the bar. That obligates relief rather than a different colour: every
  plot below carries visible axis labels, a direct endpoint value, and a table.
  """
  def viz_tokens(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".KeepOpen">
      // A DISCLOSURE THAT SURVIVES A PATCH.
      //
      // `details/summary' keeps its open state in the DOM, and the server never
      // knows it was opened, so every re-render sends markup without `open' and
      // morphdom faithfully closes it again. On these pages a fact arrives twice
      // a second, so a pane opened by hand shut before it could be read.
      //
      // The state therefore lives here, keyed by element id, and is put back
      // after every update. It is deliberately NOT server state: which panes a
      // reader has open is not something the island should be told, and pushing
      // it up would put a round trip in the way of a triangle.
      const open = new Map()

      export default {
        mounted() {
          this.el.open = open.get(this.el.id) === true
          this.el.addEventListener("toggle", () => open.set(this.el.id, this.el.open))
        },
        updated() {
          this.el.open = open.get(this.el.id) === true
        }
      }
    </script>
    <style>
      .viz {
        --viz-grid: rgba(11,11,11,0.14);
        --viz-ink: #52514e;
        --viz-ground: #1baf7a;
        --viz-creatures: #eb6834;
        --viz-derived: #2a78d6;
      }
      @media (prefers-color-scheme: dark) {
        :root:where(:not([data-theme="light"])) .viz {
          --viz-grid: rgba(255,255,255,0.16);
          --viz-ink: #c3c2b7;
          --viz-ground: #199e70;
          --viz-creatures: #d95926;
          --viz-derived: #3987e5;
        }
      }
      :root[data-theme="dark"] .viz {
        --viz-grid: rgba(255,255,255,0.16);
        --viz-ink: #c3c2b7;
        --viz-ground: #199e70;
        --viz-creatures: #d95926;
        --viz-derived: #3987e5;
      }
    </style>
    """
  end

  @doc """
  One quantity against the world's own clock, with both axes labelled.

  ## Why one series and never two

  This replaced a pair of charts that each drew two quantities on one canvas,
  every series scaled to its own maximum and no axis drawn at all. That is a
  dual-axis chart with the axes left off: where the two lines cross is decided by
  the ratio of two maxima nobody chose and nobody could see, so the picture
  invented a relationship that is not in the data. A population of 900 and a
  population of 9 drew identically.

  Two quantities in different units get two charts, side by side, sharing the
  tick along the bottom. That is the only honest way to put them together.

  ## The axes

  Y runs from zero to a rounded number above the data, so a line's height means
  something absolute and two islands can be read against each other. **Zero is
  always on the axis**: a population chart cropped to its own range turns a
  wobble of three creatures into a mountain range.

  X is the world's own tick, never wall clock. An island runs at whatever pace it
  was configured for, so the two drift apart, and a chart against wall clock
  stretches or compresses depending on how fast the world happened to be running.

  ## A gap is drawn as a gap

  A sample with nothing for this quantity breaks the line rather than being
  bridged. That happens for real during a rollout: fact version 5 added the
  entropy and descent fields, so an island not yet upgraded records a row with
  those columns empty, and joining across it would draw a straight line through
  time the island never reported.
  """
  attr :samples, :list, required: true
  attr :get, :any, required: true
  attr :label, :string, required: true
  attr :role, :string, default: "derived"
  attr :hint, :string, default: nil
  attr :suffix, :string, default: ""
  attr :w, :integer, default: 320
  attr :h, :integer, default: 150
  attr :class, :string, default: ""
  # A STABLE ID, because the disclosure below has to be recognisable across a
  # patch to be put back open. Derived from the label when not given, which is
  # unique on a page holding one plot per measure; `compare/1' passes its own,
  # since there every panel is labelled with an island and the measure is the row.
  attr :id, :string, default: nil
  # A CEILING IMPOSED FROM OUTSIDE, so several islands can be read against each
  # other. Left alone, every plot picks its own and two charts of populations
  # 1,000 apart draw the same picture. See `compare/1'.
  attr :top, :any, default: nil

  def plot(%{samples: []} = assigns) do
    ~H"""
    <figure class={["viz", @class]}>
      <.caption label={@label} />
      <p class="mt-2 text-xs opacity-40">no history yet</p>
    </figure>
    """
  end

  def plot(assigns) do
    values = Enum.map(assigns.samples, assigns.get)
    present = Enum.reject(values, &is_nil/1)

    assigns
    |> assign(values: values, present: present, id: assigns.id || slug(assigns.label))
    |> drawn()
  end

  # NOT PUBLISHED BY THIS ISLAND is a different answer from NOTHING HAPPENED, and
  # a chart that cannot tell them apart will be read as the second. An island on
  # an older fact version genuinely has no entropy column, and drawing a flat line
  # at zero would claim its entropy is nothing, which is a statement about physics
  # rather than about a rollout.
  defp drawn(%{present: []} = assigns) do
    ~H"""
    <figure class={["viz", @class]}>
      <.caption label={@label} />
      <p class="mt-2 text-xs opacity-40">
        this island does not publish it yet
      </p>
    </figure>
    """
  end

  defp drawn(assigns) do
    top = assigns.top || nice(Enum.max(assigns.present))
    ticks = Enum.map(assigns.samples, & &1.tick)
    span = %{lo: Enum.min(ticks), hi: Enum.max(ticks), top: top, w: assigns.w, h: assigns.h}

    assigns =
      assign(assigns,
        top: top,
        span: span,
        line: line(assigns.samples, assigns.values, span),
        last: List.last(assigns.present),
        low: Enum.min(assigns.present),
        first_tick: span.lo,
        last_tick: span.hi,
        mid_tick: div(span.lo + span.hi, 2),
        plot_left: @pad.left,
        plot_right: assigns.w - @pad.right,
        plot_top: @pad.top,
        plot_bottom: assigns.h - @pad.bottom
      )

    ~H"""
    <figure class={["viz", @class]}>
      <.caption label={@label} />
      <p :if={@hint} class="text-xs opacity-40">{@hint}</p>
      <svg
        viewBox={"0 0 #{@w} #{@h}"}
        class="mt-2 h-auto w-full"
        role="img"
        aria-label={"#{@label}: #{@low}#{@suffix} to #{@top}#{@suffix} over ticks #{@first_tick} to #{@last_tick}, ending at #{@last}#{@suffix}"}
      >
        <g stroke="var(--viz-grid)" stroke-width="1">
          <line
            :for={f <- [0, 0.5, 1]}
            x1={@plot_left}
            x2={@plot_right}
            y1={@plot_bottom - f * (@plot_bottom - @plot_top)}
            y2={@plot_bottom - f * (@plot_bottom - @plot_top)}
          />
          <line x1={@plot_left} x2={@plot_left} y1={@plot_top} y2={@plot_bottom} />
        </g>

        <g fill="var(--viz-ink)" font-size="10" style="font-variant-numeric: tabular-nums">
          <text
            :for={f <- [0, 0.5, 1]}
            x={@plot_left - 6}
            y={@plot_bottom - f * (@plot_bottom - @plot_top) + 3}
            text-anchor="end"
          >
            {short(axis_value(@top, f))}
          </text>
          <text x={@plot_left} y={@h - 6} text-anchor="start">{short(@first_tick)}</text>
          <text x={(@plot_left + @plot_right) / 2} y={@h - 6} text-anchor="middle">
            {short(@mid_tick)}
          </text>
          <text x={@plot_right} y={@h - 6} text-anchor="end">{short(@last_tick)}</text>
        </g>

        <path
          d={@line}
          fill="none"
          stroke={"var(--viz-#{@role})"}
          stroke-width="2"
          stroke-linejoin="round"
          stroke-linecap="round"
        />
      </svg>

      <figcaption class="mt-1 flex items-baseline justify-between gap-2 text-xs">
        <span class="opacity-50">tick</span>
        <span class="font-mono opacity-80">now {short(@last)}{@suffix}</span>
      </figcaption>

      <details id={"vals-" <> @id} phx-hook=".KeepOpen" class="mt-1 text-xs">
        <summary class="cursor-pointer opacity-40">values</summary>
        <table class="mt-1 w-full">
          <tbody class="font-mono">
            <tr>
              <td class="opacity-50">lowest</td>
              <td class="text-right">{@low}{@suffix}</td>
            </tr>
            <tr>
              <td class="opacity-50">highest</td>
              <td class="text-right">{@top}{@suffix}</td>
            </tr>
            <tr>
              <td class="opacity-50">latest</td>
              <td class="text-right">{@last}{@suffix}</td>
            </tr>
            <tr>
              <td class="opacity-50">ticks</td>
              <td class="text-right">{@first_tick} to {@last_tick}</td>
            </tr>
          </tbody>
        </table>
      </details>
    </figure>
    """
  end

  @doc """
  ONE MEASURE, EVERY ISLAND, ONE SCALE.

  ## The transposition, and why it is the whole point

  The fleet page used to be island-major: a card per island holding every
  measure. That reads one island well and compares none of them, because each
  chart picks its own rounded ceiling, so a population of 1,000 and a population
  of 1 draw the identical picture. Putting the cards side by side would not have
  fixed it. **Sharing the axis is what fixes it.**

  Measure-major instead: a row per quantity, a panel per island, one ceiling
  across the row. The fleet's own pre-registered question is whether seeds
  diverge, and on a shared axis divergence is the gap between the panels.

  ## The scale is shared ONLY when the islands are comparable

  Two islands with different `econ_id`s are playing different games and their
  numbers must not be read against each other. When they disagree the row falls
  back to a ceiling per panel and says so, rather than quietly inviting a
  comparison the fingerprints forbid.

  ## What it does for a dead island, for free

  An extinct island used to get its own axis running nought to one, which looks
  exactly like a working chart of a working world. Against the fleet's ceiling it
  is a flat line along the bottom, which is what being extinct looks like.
  """
  attr :series, :list, required: true
  attr :get, :any, required: true
  attr :label, :string, required: true
  attr :role, :string, default: "derived"
  attr :hint, :string, default: nil
  attr :suffix, :string, default: ""
  attr :shared, :boolean, default: true
  attr :h, :integer, default: 150

  def compare(assigns) do
    assigns = assign(assigns, top: assigns.shared && ceiling(assigns.series, assigns.get))

    ~H"""
    <section>
      <div class="flex items-baseline justify-between gap-2">
        <h3 class="text-sm font-semibold opacity-80">{@label}</h3>
        <span :if={@hint} class="text-xs opacity-40">{@hint}</span>
      </div>
      <div class={["mt-2 grid gap-4", columns_for(length(@series))]}>
        <.plot
          :for={{name, samples} <- @series}
          samples={samples}
          get={@get}
          label={name}
          id={slug(@label) <> "-" <> slug(name)}
          role={@role}
          suffix={@suffix}
          top={@top}
          w={320}
          h={@h}
        />
      </div>
    </section>
    """
  end

  # The tallest value anywhere in the row, rounded up the same way a lone plot
  # rounds its own. `false` when the islands are not comparable, which `plot/1`
  # reads as "pick your own".
  defp ceiling(series, get) do
    values =
      series
      |> Enum.flat_map(fn {_name, samples} -> Enum.map(samples, get) end)
      |> Enum.reject(&is_nil/1)

    values != [] && nice(Enum.max(values))
  end

  # An id a browser can hold on to. Labels are prose, and prose with spaces in it
  # is not a DOM id.
  defp slug(text) do
    text |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
  end

  defp columns_for(n) when n <= 1, do: "sm:grid-cols-1"
  defp columns_for(2), do: "sm:grid-cols-2"
  defp columns_for(_many), do: "sm:grid-cols-2 lg:grid-cols-3"

  @doc """
  What the columns mean, in words, on the page most people land on.

  ALWAYS VISIBLE AND NOT A TOOLTIP. Half of these are terms this project made up
  and the other half mean something narrower here than they do in ordinary use.
  A `title` attribute is invisible on a touch screen and invisible to anyone who
  does not think to hover, which makes it a poor place for the only explanation
  of a number.

  `founder lines` gets the longest entry because it is the one that actively
  misleads. It reads as a count of KINDS and it is a count of ANCESTORS, and the
  two come apart almost immediately: after a few hundred generations two
  creatures in one line are far more different from each other than any two lines
  were at the start.
  """
  def legend(assigns) do
    ~H"""
    <dl class="mt-4 grid gap-x-6 gap-y-2 text-xs sm:grid-cols-2">
      <div>
        <dt class="font-medium opacity-70">tick</dt>
        <dd class="opacity-50">
          The world's own clock, not ours. One tick is one step of the physics, and
          these islands run about two a second.
        </dd>
      </div>
      <div>
        <dt class="font-medium opacity-70">generations</dt>
        <dd class="opacity-50">
          How many births separate the oldest living creature from the founding.
          Zero would mean every creature alive is one of the originals, so the
          world has selected nothing yet.
        </dd>
      </div>
      <div>
        <dt class="font-medium opacity-70">founder lines</dt>
        <dd class="opacity-50">
          How many of the forty starting creatures still have living descendants. <span class="opacity-90">Ancestry, not kind</span>: two creatures in one
          line can be far less alike than two in different ones, a line can never
          split, and the number can only fall. Reaching one is what an asexual
          population does, not a fault.
        </dd>
      </div>
      <div>
        <dt class="font-medium opacity-70">door</dt>
        <dd class="opacity-50">
          The station this island reaches the mesh through, and whether that link
          is up. The three islands dial <span class="opacity-90">three different stations</span>
          and publish to one topic, and this page receives all of them on a single
          subscription without knowing which carried which, because routing is the
          mesh's job and not the reader's. The names are mesh identities and <span class="opacity-90">not locations</span>: stations are virtual, there
          are hundreds of these names over a handful of machines, and one of them
          spent a long while pointing at a box in a different country from the one
          in its name.
        </dd>
      </div>
      <div>
        <dt class="font-medium opacity-70">meat</dt>
        <dd class="opacity-50">
          The share of what the living have eaten that came from other creatures
          rather than from the ground. Counted afterwards from where the energy
          actually came from; nothing in the rules names a predator, and there is
          no carnivore flag to set.
        </dd>
      </div>
    </dl>
    """
  end

  @doc """
  The fleet in one glance: a row per island, and no scrolling to find out whether
  something has died.

  A TABLE BECAUSE IT IS A TABLE. Islands down, attributes across, which is what
  the data is, and it means a screen reader announces "beam03, extinct at tick
  630" instead of reading a card's worth of prose to get there.
  """
  attr :names, :list, required: true
  attr :rows, :map, required: true
  attr :liveness, :map, required: true

  def fleet(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="text-xs uppercase tracking-wide opacity-50">
          <tr class="border-b border-base-content/10">
            <th class="py-2 pr-4 text-left font-normal">island</th>
            <th class="py-2 pr-4 text-left font-normal">state</th>
            <th class="py-2 pr-4 text-left font-normal">door</th>
            <th class="py-2 pr-4 text-right font-normal">world</th>
            <th class="py-2 pr-4 text-right font-normal">tick</th>
            <th class="py-2 pr-4 text-right font-normal">creatures</th>
            <th class="py-2 pr-4 text-right font-normal">generations</th>
            <th class="py-2 pr-4 text-right font-normal">founder lines</th>
            <th class="py-2 text-right font-normal">meat</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={name <- @names} class="border-b border-base-content/5">
            <td class="py-2 pr-4">
              <.link
                navigate={~p"/research/workbench/biotope/#{name}"}
                class="link link-hover font-medium"
              >
                {name}
              </.link>
            </td>
            <td class="py-2 pr-4"><.liveness liveness={@liveness[name]} /></td>
            <td class="py-2 pr-4"><.door stats={stats(@rows[name])} /></td>
            <td class="py-2 pr-4 text-right font-mono">{cell(@rows[name], "world")}</td>
            <td class="py-2 pr-4 text-right font-mono">{cell(@rows[name], "tick")}</td>
            <td class="py-2 pr-4 text-right font-mono">{cell(@rows[name], "population")}</td>
            <td class="py-2 pr-4 text-right font-mono">{cell(@rows[name], "depth")}</td>
            <td class="py-2 pr-4 text-right font-mono">{cell(@rows[name], "lineages")}</td>
            <td class="py-2 text-right font-mono">{cell(@rows[name], "from_creatures_pct")}%</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp cell(nil, _key), do: "–"
  defp cell(%{stats: nil}, _key), do: "–"
  defp cell(%{stats: stats}, key), do: number(stats[key])
  defp cell(_row, _key), do: "–"

  defp stats(%{stats: stats}) when is_map(stats), do: stats
  defp stats(_row), do: nil

  @doc """
  Which station this island reaches the mesh through.

  THE POINT OF THREE ISLANDS IS THREE DOORS. They publish to one topic on one
  realm and a reader receives all of them on a single subscription, without
  knowing or caring which station carried which, because routing is the mesh's
  job and not the reader's. That is the whole architectural claim and it was
  invisible on this page until the islands started saying so.

  A NAME IS NOT A PLACE AND THIS RENDERS NO CITY. `station-de-frankfurt` was for
  a long time physically the Nuremberg box, left misnamed because renaming
  breaks seeds, and it resolves onto a different network again today. Stations
  are virtual: hundreds of these names over a handful of machines. What is shown
  is the identity on the mesh, and the `de-frankfurt` in it is part of a name
  rather than a claim about Germany.

  ABSENT IS NOT DOWN. An island that cannot read its own link publishes no door
  at all, and that shows as a dash rather than as an outage: it means the island
  cannot see, not that nobody answered. An island on a version older than fact 9
  reads the same way, which is what a rollout looks like.
  """
  attr :stats, :map, default: nil

  def door(assigns) do
    ~H"""
    <span :if={is_nil(@stats) or is_nil(@stats["station_host"])} class="opacity-40">
      –
    </span>
    <span :if={@stats && @stats["station_host"]} class="inline-flex items-center gap-1.5">
      <span
        class={[
          "inline-block h-1.5 w-1.5 rounded-full",
          @stats["station_connected"] && "bg-success",
          !@stats["station_connected"] && "bg-error"
        ]}
        aria-hidden="true"
      />
      <span
        class="font-mono text-xs"
        title={"key #{String.slice(to_string(@stats["station_id"]), 0, 16)}…"}
      >
        {short_station(@stats["station_host"])}
      </span>
      <span class="sr-only">
        {if @stats["station_connected"], do: "connected", else: "not connected"}
      </span>
    </span>
    """
  end

  # The mesh identity without the zone that every one of them shares. Dropping
  # `.macula.io` is shortening a name, not translating it into a location.
  defp short_station(host) when is_binary(host),
    do: String.replace_suffix(host, ".macula.io", "")

  defp short_station(host), do: to_string(host)

  @doc """
  Every island's board, side by side and the same size.

  THE ONE THING THAT GENUINELY WANTS TO BE PER-ISLAND, and the reason the fleet
  page is worth loading at all. They compare honestly because nothing here is
  scaled to its own frame: a body maps to a radius by the same absolute rule on
  every disc and the ground uses one ramp, so a grazed board really does look
  grazed beside a rich one.
  """
  attr :names, :list, required: true
  attr :rows, :map, required: true
  attr :size, :integer, default: 240
  attr :class, :string, default: ""

  def boards(assigns) do
    ~H"""
    <div class={["grid gap-5 sm:grid-cols-2 lg:grid-cols-3", @class]}>
      <figure :for={name <- @names}>
        <.disc
          :if={chart_of(@rows[name])}
          id={"disc-" <> name}
          chart={chart_of(@rows[name])}
          size={@size}
        />
        <p :if={is_nil(chart_of(@rows[name]))} class="rounded bg-base-300 p-4 text-xs opacity-60">
          Counts but no picture. This island may have its chart turned off, which
          is what a headless run does.
        </p>
        <figcaption class="mt-1 flex items-baseline justify-between gap-2 text-xs">
          <span class="font-medium">{name}</span>
          <span class="font-mono opacity-60">{cell(@rows[name], "population")} creatures</span>
        </figcaption>
      </figure>
    </div>
    """
  end

  defp chart_of(nil), do: nil
  defp chart_of(row), do: row[:chart]

  @doc """
  The two halves of the energy books, over time, as two charts sharing a clock.

  Grazing pressure against regrowth, which is what the pair was always for. They
  are drawn apart rather than together because they are counts of different
  things: one is creatures and one is units of energy, and a crossing point
  between them would mean nothing at all.
  """
  attr :samples, :list, required: true
  attr :w, :integer, default: 320
  attr :h, :integer, default: 150
  attr :class, :string, default: ""

  def stocks(assigns) do
    ~H"""
    <div class={["grid gap-4 sm:grid-cols-2", @class]}>
      <.plot
        samples={@samples}
        get={& &1.population}
        label="creatures"
        role="creatures"
        w={@w}
        h={@h}
      />
      <.plot
        samples={@samples}
        get={& &1.ground_total}
        label="energy in the ground"
        role="ground"
        w={@w}
        h={@h}
      />
    </div>
    """
  end

  @doc """
  What the population BECAME, as two charts rather than two lines.

  Neither is a rule and neither is read by the island's physics. There is no
  herbivore field and no carnivore flag anywhere: the share of energy taken from
  other creatures is counted afterwards from where it actually came from.
  """
  attr :samples, :list, required: true
  attr :w, :integer, default: 320
  attr :h, :integer, default: 150
  attr :class, :string, default: ""

  def becoming(assigns) do
    ~H"""
    <div class={["grid gap-4 sm:grid-cols-2", @class]}>
      <.plot
        samples={@samples}
        get={& &1.from_creatures_pct}
        label="energy from creatures"
        hint="counted afterwards, never declared"
        suffix="%"
        w={@w}
        h={@h}
      />
      <.plot
        samples={@samples}
        get={&((&1.sensor_mean || 0) / 100)}
        label="sensors per creature"
        hint="what they pay to measure with"
        w={@w}
        h={@h}
      />
    </div>
    """
  end

  @doc """
  The entropy account, which is the one line here that cannot fall.

  Every unit ever spent on living leaves as heat, and at one temperature that IS
  this world's entropy. So the Second Law is not an assertion on this page, it is
  the shape of this line: it rises and never returns.

  It is also the third term of the books. Energy is in the ground, in a creature,
  or already burnt, and the three together change only by what the sun adds.
  """
  attr :samples, :list, required: true
  attr :w, :integer, default: 320
  attr :h, :integer, default: 150
  attr :class, :string, default: ""

  def entropy(assigns) do
    ~H"""
    <.plot
      samples={@samples}
      get={& &1.dissipated}
      label="burnt as heat"
      hint="the Second Law: this can only rise"
      w={@w}
      h={@h}
      class={@class}
    />
    """
  end

  @doc """
  Where every unit of energy in this world currently is.

  Three terms and they are exhaustive: in the ground, inside something alive, or
  already spent. The first two are the world as it stands and the third is
  everything it has ever done, which is why the third is so much the largest.
  """
  attr :stats, :map, required: true
  attr :class, :string, default: ""

  def ledger(assigns) do
    ~H"""
    <div class={@class}>
      <h3 class="text-xs uppercase tracking-wide opacity-50">where the energy is</h3>
      <p class="mt-1 text-xs opacity-40">
        exhaustive: in the ground, in something alive, or already burnt
      </p>
      <dl class="mt-2 grid grid-cols-3 gap-3 text-sm">
        <.stat label="in the ground" value={@stats["ground_total"]} />
        <.stat label="in creatures" value={@stats["energy_total"]} />
        <.stat label="burnt" value={@stats["dissipated"]} />
      </dl>
    </div>
    """
  end

  @doc """
  Whether this population can still change, which is not the same as how it is
  doing.

  THE NUMBER WORLD 8 WAS MISSING. It ended with creatures carrying four hundred
  times what they were founded with, and it ended because nothing had been born
  since tick 15. Every other number on this page described that population
  perfectly and not one of them could tell it from a living one.

  Zero generations means every creature alive is a founder, so the world has
  selected nothing: it filtered its founding once and stopped.
  """
  attr :stats, :map, required: true

  def descent(assigns) do
    assigns = assign(assigns, depth: assigns.stats["depth"], lines: assigns.stats["lineages"])

    ~H"""
    <div :if={@depth}>
      <h3 class="text-xs uppercase tracking-wide opacity-50">descent</h3>
      <p class="mt-1 font-mono text-lg leading-none">
        {@depth} <span class="text-xs opacity-60">generations deep</span>
      </p>
      <p class="mt-1 text-xs opacity-50">
        {if @depth == 0,
          do: "every creature alive is a founder: nothing has been selected yet",
          else: "the oldest living line is #{@depth} births from the founding"}
      </p>
      <dl class="mt-2 grid grid-cols-2 gap-3 text-sm">
        <.stat label="founder lines" value={@lines} />
        <.stat label="largest body" value={@stats["structure_max"]} />
      </dl>
    </div>
    """
  end

  @doc """
  How much of this population has become sessile.

  THE HEADLINE OF THIS WORLD, AND IT IS NOT A CATEGORY ANYONE ASSIGNED. There are
  no plants in these rules: energy gathers in the ground and a creature absorbs
  what has gathered where it stands, so staying put and living off that simply IS
  being a plant. This counts the ones that did not move, and nothing anywhere
  calls them anything.
  """
  attr :stats, :map, required: true

  def sessile(assigns) do
    assigns = assign(assigns, pct: assigns.stats["still_pct"] || 0)

    ~H"""
    <div>
      <dt class="text-xs uppercase tracking-wide opacity-50">stayed put</dt>
      <dd class="mt-1 font-mono text-lg leading-none">{@pct}%</dd>
      <div
        class="mt-2 h-1.5 w-full overflow-hidden rounded bg-base-content/10"
        role="img"
        aria-label={"#{@pct} percent of creatures did not move this tick"}
      >
        <div class="h-full bg-success" style={"width: #{@pct}%"}></div>
      </div>
    </div>
    """
  end

  @doc """
  The ground, and whether places have come to differ from one another.

  Ten percent in the richest tenth of cells is flat. Above that, the landscape
  has structure, and since no terrain was ever installed, whatever structure
  exists was made by things dying: a corpse is added on top of the ceiling, and
  no amount of sunlight can carry a cell that high.
  """
  attr :stats, :map, required: true

  def landscape(assigns) do
    ~H"""
    <div>
      <h3 class="text-xs uppercase tracking-wide opacity-50">the ground</h3>
      <dl class="mt-2 grid grid-cols-2 gap-3 text-sm">
        <.stat label="energy in it" value={@stats["ground_total"]} />
        <.stat label="in richest 10%" value={pct(@stats["ground_spread"])} />
      </dl>
    </div>
    """
  end

  @doc """
  What these creatures can do at all.

  AN ABSENT OUTPUT IS NOT A WEAK ONE. A creature with no move output never moves,
  which in this world is a living rather than a death sentence. One with no breed
  output leaves no descendants, so its lineage ends there. Both are things that
  mutation takes away and gives back.
  """
  attr :stats, :map, required: true

  def capable(assigns) do
    ~H"""
    <div>
      <h3 class="text-xs uppercase tracking-wide opacity-50">what they can do</h3>
      <dl class="mt-2 grid grid-cols-3 gap-3 text-sm">
        <.stat label="can move" value={@stats["movers"]} />
        <.stat label="can breed" value={@stats["breeders"]} />
        <.stat label="hidden nodes" value={hundredths(@stats["hidden_mean"])} />
      </dl>
    </div>
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

  @doc """
  A caption for a chart, and what its colours mean.

  EVERY CHART HERE NEEDS ONE. A line, a bar and a haze of dots are all perfectly
  legible once you know what they are counting and completely opaque until then,
  and a reader who has to infer it from a paragraph somewhere else will infer it
  wrong. The colour swatches carry more than the words do: they are the only
  thing that says WHICH line is the population.
  """
  attr :label, :string, required: true
  attr :keys, :list, default: []

  def caption(assigns) do
    ~H"""
    <div class="flex items-baseline justify-between gap-2">
      <h3 class="text-xs uppercase tracking-wide opacity-50">{@label}</h3>
      <span :if={@keys != []} class="flex shrink-0 items-center gap-2 text-xs opacity-60">
        <span :for={{colour, name} <- @keys} class="flex items-center gap-1">
          <span class="inline-block h-1.5 w-1.5 rounded-full" style={"background: #{colour}"}></span>
          {name}
        </span>
      </span>
    </div>
    """
  end

  @doc """
  How many creatures sit at each value: the SHAPE of a population, not its
  average.

  A mean of 0.01 sensors per creature reads as "nearly none" without saying
  whether that is one creature in a hundred carrying one or something else
  entirely, and the difference matters. One is an apparatus being selected away;
  the other is one being maintained rarely. **A chart pinned wholly at the first
  bar says the first, and cannot be skimmed past.**

  Scaled to its own tallest bar, because the question a shape answers is where
  the population sits and not how large it is, which the creature count already
  gives.
  """
  attr :bars, :list, required: true
  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :colour, :string, default: "#6C9BD5"
  attr :ramp, :boolean, default: false

  def shape(%{bars: bars} = assigns) when bars in [nil, []] do
    ~H"""
    <p class="text-xs opacity-40">{@label}: nothing yet</p>
    """
  end

  def shape(assigns) do
    assigns = assign(assigns, columns: columns(assigns.bars))

    ~H"""
    <div>
      <.caption label={@label} />
      <p :if={@hint} class="text-xs opacity-40">{@hint}</p>
      <div
        class="mt-2 flex h-16 items-end gap-px"
        role="img"
        aria-label={"#{@label}: #{Enum.join(@bars, ", ")}"}
      >
        <div
          :for={{count, share, index} <- @columns}
          class="flex-1 rounded-t"
          style={"height: #{max(share, 2)}%; background: #{bar_colour(@ramp, index, length(@bars), @colour)}"}
          title={"#{count} at #{index}"}
        >
        </div>
      </div>
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
  Which world an island is running, and one sentence saying what that means.

  THE `econ_id` BESIDE IT ANSWERS A DIFFERENT QUESTION. That says whether two
  islands are COMPARABLE; this says what either of them IS. Two islands can
  share every constant and still be running different physics, because the
  rules live in code and the constants do not.

  A fleet is redeployed one node at a time, so during a rollout the cards
  genuinely disagree. That is the moment this is for.

  An island running a build from before this existed sends no world number and
  gets nothing rather than a guess.
  """
  attr :stats, :map, required: true
  attr :class, :string, default: ""

  def ruleset(%{stats: nil} = assigns), do: ~H""

  def ruleset(assigns) do
    assigns =
      assign(assigns, number: assigns.stats["world"], line: assigns.stats["world_line"])

    ~H"""
    <p :if={@number} class={["text-xs leading-snug", @class]}>
      <span class="font-mono text-primary">world {@number}</span>
      <span :if={@line} class="opacity-50">{@line}</span>
    </p>
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
    assigns =
      assign(assigns,
        id: assigns.stats["econ_id"] || "unknown",
        econ: assigns.stats["econ"] || %{}
      )

    ~H"""
    <details id={"rules-" <> @id} phx-hook=".KeepOpen" class="mt-3 text-xs">
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

  # THE GROUND IS A FIELD, NOT A SET OF OBJECTS, and that is the whole reason
  # this replaced a scatter of plant dots. There are no plants: energy gathers in
  # every cell and a creature takes what has gathered where it stands. A cell
  # holds an AMOUNT, so the honest picture is a tinted surface.
  #
  # It also makes three things visible that were only ever numbers. Grazing shows
  # as depletion, in the dark trail a population leaves behind it. Death shows as
  # ENRICHMENT, because a corpse is added on top of the ceiling and no untouched
  # cell can reach that. And whether the landscape has come to differ from itself
  # stops being a statistic and becomes something you can see.
  #
  # An empty cell is drawn as nothing rather than as black: the island does not
  # send it, and on a grazed board most cells are empty.
  defp soil(chart, box, ceiling) do
    chart["ground"]
    |> Biotope.marks()
    |> Enum.map(fn {q, r, amount} ->
      {x, y} = Biotope.to_pixel({q, r}, box)
      {x, y, soil_colour(amount, ceiling), soil_alpha(amount, ceiling)}
    end)
  end

  # ABOVE THE CEILING MEANS SOMETHING DIED HERE. Ambient supply stops at the
  # ceiling, so no amount of sunlight reaches this; only a corpse does. Worth its
  # own colour, because "places became different because things died there" is
  # the one claim this rendering can settle at a glance.
  #
  # ROSE RATHER THAN GOLD, and the old gold was a real mistake. It was #C9A227
  # against creatures at #F2B142, two ambers a page apart in hue, and the only
  # reason nobody noticed is that this branch had NEVER ONCE FIRED: it needs a
  # cell above 400 and the richest cell on the board held about 18. World 9 makes
  # it fire constantly, with 86 percent of all ground energy sitting in a tenth of
  # the cells, so a colour that was safely invisible is about to be everywhere.
  #
  # Rose is the free hue here: the ground is green, the creatures run cream to
  # red-orange and the scent is violet.
  defp soil_colour(amount, ceiling) when amount > ceiling, do: 0xC2557A
  defp soil_colour(_amount, _ceiling), do: 0x2F7D52

  # THE SQUARE ROOT AGAIN, and for a plainer reason than the creatures.
  #
  # Grazing is the story this surface tells, and grazing happens down at the
  # bottom of the range: a cell at 40 and a cell at 4 are a fed creature and a
  # starved one, and on a straight ramp they differed by four percent of an alpha
  # channel. A root spends the visible range where the population actually lives.
  #
  # A corpse cell is scaled against a much higher mark than the ceiling, because
  # a body returns its whole store and world 9's bodies carry tens of thousands.
  # Without that every enriched cell pins at full and the graveyards all look
  # identical.
  defp soil_alpha(amount, ceiling) when amount > ceiling do
    round(100 * (0.30 + 0.50 * :math.sqrt(min(1.0, amount / max(ceiling * 20, 1)))))
  end

  defp soil_alpha(amount, ceiling) do
    round(100 * (0.10 + 0.55 * :math.sqrt(min(1.0, amount / max(ceiling, 1)))))
  end

  # A CREATURE IS DRAWN THE SIZE OF ITS BODY, AND IT USED TO BE DRAWN THE SIZE OF
  # ITS LUNCHBOX.
  #
  # The old rule sized a dot by `energy` and explained that energy is armour
  # because the stronger consumes the weaker. That was true until world 6 split
  # the store from the structure, and the island has decided contests on
  # STRUCTURE ALONE ever since: "a fat small creature loses to a lean large one",
  # in its own words. So the picture was drawing the one quantity that does not
  # decide anything, and world 9 makes it worse, because a standing spread of
  # BODY sizes is the thing that world's whole result rests on.
  #
  # Structures have been on the wire the entire time and nothing read them.
  defp creatures(chart, box, cell, ceiling) do
    points = Biotope.points(chart["creatures"])
    frames = pad(chart["structures"] || chart["energies"] || [], length(points), 0)
    rates = pad(chart["uptakes"] || [], length(points), nil)
    # WHO EACH MARK IS. Without it a viewer can draw a frame and cannot animate
    # between two, because births and deaths reshuffle the list every tick. An
    # island on an older build sends none, and then the index is the best
    # identity available and the drawing simply does not move.
    ids = pad(chart["ids"] || [], length(points), 0)

    [ids, points, frames, rates]
    |> Enum.zip()
    |> Enum.map(fn {id, point, frame, rate} ->
      {x, y} = Biotope.to_pixel(point, box)
      {id, x, y, radius_for(cell, frame), feeding_rgb(rate, ceiling)}
    end)
  end

  defp pad(values, wanted, filler) do
    values ++ List.duplicate(filler, max(0, wanted - length(values)))
  end

  # THE RADIUS GOES AS THE SQUARE ROOT, so the AREA is proportional to the body
  # and not the radius. A circle is read by how much of it there is; making the
  # radius proportional squares the quantity, so a creature twice the size of
  # another looked four times it.
  #
  # It also keeps the spread visible. World 9 runs founders at 400 and its
  # largest bodies past 4,000, and a linear scale would saturate everything above
  # the founding into one flat maximum, hiding exactly the range that matters.
  #
  # A floor as well as a scale, because a creature about to starve is still there
  # and a dot of radius zero is a creature the picture has lost. Absolute rather
  # than relative to the frame: a board where everything has shrunk must LOOK
  # shrunken rather than quietly rescaling itself to look ordinary.
  defp radius_for(cell, frame) when is_integer(frame) and frame > 0 do
    cell * (0.25 + 0.75 * :math.sqrt(min(1.0, frame / @frame_full)))
  end

  defp radius_for(cell, _frame), do: cell * 0.25

  # COLOURED BY HOW FAST IT FEEDS, which is a quantity rather than a label.
  #
  # PALE IS GENTLE AND DEEP IS VORACIOUS. Feed slower than the ground comes back
  # and a cell holds a standing stock you can draw on for good; feed harder and
  # you strip it, your income collapses to the bare floor, and you move or
  # starve. So the colour is the prudent-to-greedy axis, read straight off a
  # scale, and a patch of one shade is a patch of creatures making a living the
  # same way.
  #
  # This is what the signature colouring could not be. A signature is a name, and
  # names only mean something when there are families to name; a feeding rate is
  # a number, and it means the same thing on every island whether or not anything
  # has clustered.
  defp feeding_rgb(rate, ceiling) when is_integer(rate) and rate >= 0 do
    t = min(1.0, rate / max(ceiling, 1))

    round(245 - 13 * t) * 0x10000 + round(230 - 146 * t) * 0x100 +
      round(163 - 116 * t)
  end

  # An island still publishing the older chart sends no feeding rates. Amber is
  # what every creature used to be.
  defp feeding_rgb(_absent, _ceiling), do: 0xF2B142

  # The same ramp as a CSS colour, for the one place that needs a string: the
  # feeding histogram, whose bars are coloured to match the creatures they count.
  defp feeding_colour(rate, ceiling) do
    rgb = feeding_rgb(rate, ceiling)
    "#" <> String.pad_leading(Integer.to_string(rgb, 16), 6, "0")
  end

  # THE SIGNATURE COLOURING IS GONE, AND THE CONFETTI WAS THE DATA. Creatures
  # were tinted by their heritable scent signature, one bit group per channel, so
  # kin shared a colour. The mapping was right and the picture was unreadable:
  # at the mutation rate these islands run, signatures scramble across most of
  # the 256 available within a few hundred births and the measured spread sits at
  # 44-49 against a baseline of 50 for wholly unrelated tags. There are no
  # families, so a colouring that showed families was inventing them.
  #
  # A name only means something when there are families to name. A feeding rate
  # is a number and means the same thing everywhere, which is why it took over.

  # Faint on purpose. A trail is evidence that something passed, and at full
  # strength it would read as a wall.
  defp trails(chart, box) do
    chart["scent"]
    |> Biotope.marks()
    |> Enum.map(fn {q, r, strength} ->
      {x, y} = Biotope.to_pixel({q, r}, box)
      {x, y, round(100 * min(1.0, strength / @scent_full) * 0.30)}
    end)
  end

  # A PATH RATHER THAN A POLYLINE, because a polyline cannot have a hole in it.
  # A sample with nothing for this quantity starts a new segment instead of being
  # joined across, so a gap in what an island reported is drawn as a gap.
  #
  # NOT called `path`: Phoenix.VerifiedRoutes imports path/2, and shadowing it
  # fails at compile time inside ~p with a message about a path string that names
  # neither this function nor the collision.
  # `M` starts a segment and `L` continues one, so a missing value simply resets
  # to `M` and the next drawn point begins a new stroke rather than being joined
  # back across the hole.
  defp line(samples, values, span) do
    samples
    |> Enum.zip(values)
    |> Enum.reduce({[], false}, fn
      {_sample, nil}, {acc, _drawing} ->
        {acc, false}

      {sample, value}, {acc, drawing} ->
        {[((drawing && "L") || "M") <> at(sample, value, span) | acc], true}
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp at(sample, value, span) do
    width = span.w - @pad.left - @pad.right
    height = span.h - @pad.top - @pad.bottom
    across = max(span.hi - span.lo, 1)
    x = @pad.left + (sample.tick - span.lo) / across * width
    y = span.h - @pad.bottom - min(1.0, value / max(span.top, 1)) * height
    "#{Float.round(x, 1)},#{Float.round(y, 1)}"
  end

  # A ROUND NUMBER ABOVE THE DATA, so the top of the axis is a value a reader can
  # hold in their head and two islands drawn on 1,000 can be compared at a glance.
  # An axis topped at 806 because that is what the maximum happened to be makes
  # every chart a different chart.
  defp nice(max) when max <= 0, do: 1

  defp nice(max) do
    power = :math.pow(10, floor(:math.log10(max * 1.0)))
    step = Enum.find([1, 2, 2.5, 5, 10], &(max <= &1 * power)) * power
    whole_or_fraction(step)
  end

  # SENSORS PER CREATURE RUNS AT 0.22, so rounding every axis top to a whole
  # number would put that chart's ceiling at 1 and flatten the only line on it.
  # Anything from ten up is a count and stays whole.
  defp whole_or_fraction(step) when step >= 10, do: round(step)
  defp whole_or_fraction(step), do: Float.round(step, 2)

  defp axis_value(top, fraction) when is_integer(top), do: round(top * fraction)
  defp axis_value(top, fraction), do: Float.round(top * fraction, 2)

  # THOUSANDS AND MILLIONS, because the entropy account runs to tens of millions
  # within an hour and a y axis reading 27920812 is an axis nobody reads.
  defp short(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)

  defp short(n) when is_integer(n) and abs(n) >= 1_000_000,
    do: "#{Float.round(n / 1_000_000, 1)}M"

  defp short(n) when is_integer(n) and abs(n) >= 10_000, do: "#{Float.round(n / 1000, 1)}k"
  defp short(n) when is_integer(n), do: Integer.to_string(n)
  defp short(other), do: to_string(other)

  # Ordered as the island orders its fields, so two islands read the same way.
  defp census_rows(stats) do
    census = stats["sensors"] || %{}
    population = max(stats["population"] || 0, 1)

    for field <- ~w(ground creatures scent self) do
      carriers = get_in(census, [field, "carriers"]) || 0
      attention = (get_in(census, [field, "attention"]) || 0) / 100

      {field, carriers, min(100, round(carriers * 100 / population)),
       :erlang.float_to_binary(attention, decimals: 1)}
    end
  end

  # Scaled to the tallest bar rather than to the population, because the question
  # is where the creatures sit and not how many there are.
  defp columns(bars) do
    tallest = max(Enum.max(bars, fn -> 0 end), 1)

    bars
    |> Enum.with_index()
    |> Enum.map(fn {count, index} -> {count, round(count * 100 / tallest), index} end)
  end

  # A feeding-rate chart colours its own buckets on the same pale-to-deep ramp
  # the creatures use, so the axis needs no labelling: the bar IS the colour of
  # the creatures it counts.
  defp bar_colour(true, index, count, _flat) do
    feeding_colour(round(index * 400 / max(count - 1, 1)), 400)
  end

  defp bar_colour(false, _index, _count, flat), do: flat

  defp pct(nil), do: "–"
  defp pct(n), do: "#{n}%"

  defp hundredths(nil), do: "–"
  defp hundredths(n), do: :erlang.float_to_binary(n / 100, decimals: 2)

  defp number(nil), do: "–"
  defp number(n) when is_integer(n), do: Integer.to_string(n)
  defp number(other), do: to_string(other)
end
