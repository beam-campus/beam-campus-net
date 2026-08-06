defmodule BeamCampusWeb.DronexMap do
  @moduledoc """
  The archipelago, with its raids drawn on it.

  ## The arc is the thing this map has that no sibling map had

  `Biotope.Archipelago`'s own docs say the sea between islands holds nothing, and
  that what would make a map say something true about connectedness is the
  migration arcs — which arrive with migration itself.

  **A raid is that arc**, and here it is the subject rather than a promise. An
  island under attack is *visibly* under attack, and the direction the
  archipelago's genetic traffic flows is something you watch rather than a
  statistic you read.

  ## An island is a volume, not a disc

  The sibling draws a hex disc because its world is a hex disc. This one draws
  **airspace**: a footprint with a faint vertical extent above it, and a ring
  showing how much roster is left. An island ground down by attention visibly
  thins, which is the price of being popular made visual rather than tabular.

  ## What this page must never do

  It holds no engine and interpolates nothing. Positions are a hash of a name, so
  any two viewers holding the same islands draw the same world; nothing is
  claimed and nothing is granted. Everything about how a mark looks is decided
  here, in Elixir, where it is documented and tested — the hook interprets
  nothing and is told only where to put things.

  ⚠ **Drawing a signal is not measuring one.** This map may show a raid, its
  direction and its cost. It may not say the swarm coordinated: that sentence
  needs the ablation delta, which is published as a number and shown as a number.
  """
  use Phoenix.Component

  # Room for an island's footprint plus the sea around it. The pitch is what
  # `Dronex.Archipelago` multiplies its grid by.
  @size 132
  @sea 44
  @open_sea 30

  # The same deep blue-black the biotope map settled on, and for the same reason:
  # the water colour would claim a sea that is not simulated and holds nothing.
  #
  # ⚠ A FUNCTION, NOT A MODULE ATTRIBUTE. Inside a `~H` sigil `@backdrop` means
  # `assigns.backdrop`, not the attribute, so the attribute version compiles to a
  # missing assign and the only signal is the compiler saying it was "set but
  # never used". The biotope map made this exact mistake first; the compiler
  # caught it there too.
  defp backdrop, do: "bg-[#0a1220]"

  @doc """
  Every island on one map, with any raid it is part of drawn as an arc.

  `islands` are board rows; `raids` are the raid rows the board holds.
  """
  attr :islands, :list, required: true
  attr :raids, :list, required: true
  attr :class, :string, default: ""
  attr :focus, :string, default: nil

  def archipelago(assigns) do
    names = Enum.map(assigns.islands, & &1.id)
    placed = Dronex.Archipelago.place(names)
    pitch = @size + @sea
    at = Dronex.Archipelago.pixels(placed, pitch, @open_sea)
    {cols, rows} = Dronex.Archipelago.extent(placed)

    assigns =
      assign(assigns,
        isles: Jason.encode!(Enum.map(assigns.islands, &isle(&1, at))),
        arcs: Jason.encode!(arcs(assigns.raids, at, names)),
        focus: assigns[:focus],
        width: cols * pitch,
        height: rows * pitch,
        count: length(names)
      )

    ~H"""
    <figure :if={@count > 0} class={["relative", @class]}>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".Archipelago">
        // THE WHOLE ARCHIPELAGO ON ONE CANVAS.
        //
        // Everything about how a mark looks was decided in Elixir, where it is
        // documented and tested. Nothing here interprets anything: it is told
        // where things are and what colour they are, and it draws them.
        const css = (rgb) => "#" + rgb.toString(16).padStart(6, "0")

        export default {
          mounted() {
            this.ctx = this.el.getContext("2d")
            // THE CAMERA. A world that grows without limit stays readable only
            // if the VIEWER moves; the alternative is shrinking every island as
            // nodes join, so that adding land makes everything smaller.
            this.cam = {x: 0, y: 0, k: 1}
            this.drag = null
            this.phase = 0

            this.el.addEventListener("pointerdown", (e) => {
              this.down = {x: e.clientX, y: e.clientY}
              this.drag = {x: e.clientX, y: e.clientY, cx: this.cam.x, cy: this.cam.y}
              this.el.setPointerCapture(e.pointerId)
              this.el.style.cursor = "grabbing"
            })
            this.el.addEventListener("pointermove", (e) => {
              if (!this.drag) return
              this.cam.x = this.drag.cx + (e.clientX - this.drag.x) / this.cam.k
              this.cam.y = this.drag.cy + (e.clientY - this.drag.y) / this.cam.k
              this.paint()
            })
            // ⚠ A CLICK IS A POINTERUP THAT DID NOT TRAVEL. The map is
            // draggable, so a naive click handler would fire at the end of every
            // pan and the filter would change whenever somebody moved the view.
            // Five pixels of slack, because a finger is never still.
            const release = (e) => {
              if (this.down && Math.hypot(e.clientX - this.down.x, e.clientY - this.down.y) < 5) {
                this.tap(e)
              }
              this.down = null
              this.drag = null
              this.el.style.cursor = "grab"
              if (e.pointerId !== undefined && this.el.hasPointerCapture(e.pointerId)) {
                this.el.releasePointerCapture(e.pointerId)
              }
            }
            this.el.addEventListener("pointerup", release)
            this.el.addEventListener("pointercancel", release)

            // Zoom about the POINTER, not the centre, so the thing under the
            // cursor stays under it. Zooming about the middle makes a map feel
            // like it is fighting back.
            this.el.addEventListener("wheel", (e) => {
              e.preventDefault()
              const r = this.el.getBoundingClientRect()
              const px = e.clientX - r.left, py = e.clientY - r.top
              const before = this.at(px, py)
              this.cam.k = Math.min(4, Math.max(0.1, this.cam.k * (e.deltaY < 0 ? 1.15 : 1 / 1.15)))
              const after = this.at(px, py)
              this.cam.x += after.x - before.x
              this.cam.y += after.y - before.y
              this.paint()
            }, {passive: false})

            this.el.addEventListener("dblclick", () => { this.fitWorld(); this.paint() })
            this.resize = () => { this.fit(); this.fitWorld(); this.paint() }
            window.addEventListener("resize", this.resize)

            this.fit()
            this.read()
            this.fitWorld()
            this.animate()
          },

          destroyed() {
            window.removeEventListener("resize", this.resize)
            if (this.raf) cancelAnimationFrame(this.raf)
          },

          updated() {
            const was = this.world
            this.fit()
            // Re-frame only when the world changed SIZE. Doing it on every
            // update would yank the camera back mid-drag on every tick.
            if (!was || was.w !== this.world.w || was.h !== this.world.h) this.fitWorld()
            this.read()
          },

          // ⚠ ONE LOOP, ALWAYS RUNNING, BECAUSE A RAID IN FLIGHT MOVES. The
          // marks travelling an arc are the only animated thing here and they
          // are not driven by server updates: a raid arrives once and then
          // takes a minute to resolve.
          animate() {
            this.phase = (this.phase + 0.004) % 1
            this.paint()
            this.raf = requestAnimationFrame(() => this.animate())
          },

          fit() {
            const p = window.devicePixelRatio || 1
            const r = this.el.getBoundingClientRect()
            this.dpr = p
            this.w = Math.max(1, Math.round(r.width))
            this.h = Math.max(1, Math.round(r.height))
            this.el.width = this.w * p
            this.el.height = this.h * p
            this.world = {
              w: parseInt(this.el.dataset.worldWidth) || this.w,
              h: parseInt(this.el.dataset.worldHeight) || this.h
            }
          },

          // Which island was tapped, if any. Told to the LiveView rather than
          // acted on here: what a click MEANS is a page decision, and this hook
          // has no opinion about fights.
          tap(e) {
            const r = this.el.getBoundingClientRect()
            const w = this.at(e.clientX - r.left, e.clientY - r.top)
            // Generous, and it has to be: the marks are small at this size and a
            // hit box the size of the drawing is a hit box nobody can hit.
            const hit = this.isles.find(
              (i) => Math.hypot(w.x - i.x, (w.y - i.y) / 0.5) < i.r * 1.6
            )
            this.pushEvent("focus_island", {id: hit ? hit.id : null})
          },

          // screen = (world + cam.xy) * cam.k, and this is its inverse.
          at(px, py) {
            return {x: px / this.cam.k - this.cam.x, y: py / this.cam.k - this.cam.y}
          },

          fitWorld() {
            const k = Math.min(this.w / this.world.w, this.h / this.world.h)
            this.cam.k = Math.min(4, Math.max(0.1, k))
            this.cam.x = (this.w / this.cam.k - this.world.w) / 2
            this.cam.y = (this.h / this.cam.k - this.world.h) / 2
          },

          read() {
            this.isles = JSON.parse(this.el.dataset.isles || "[]")
            this.arcs = JSON.parse(this.el.dataset.arcs || "[]")
            this.focus = this.el.dataset.focus || null
          },

          paint() {
            const c = this.ctx, p = this.dpr, k = this.cam.k
            // Cleared under the identity transform: clearing under the camera
            // would clear whatever rectangle the camera happens to look at.
            c.setTransform(p, 0, 0, p, 0, 0)
            c.clearRect(0, 0, this.w, this.h)
            c.setTransform(p * k, 0, 0, p * k, p * k * this.cam.x, p * k * this.cam.y)

            for (const a of this.arcs) this.arc(a)
            for (const i of this.isles) this.island(i)

            // The selection, on top of everything, so it survives an island
            // being drawn over by a neighbour's column.
            const sel = this.isles.find((i) => i.id === this.focus)
            if (sel) {
              c.strokeStyle = "rgba(255,255,255,0.75)"
              c.lineWidth = 2 / k
              c.beginPath()
              c.ellipse(sel.x, sel.y, sel.r * 1.5, sel.r * 0.62, 0, 0, 6.284)
              c.stroke()
            }

            c.setTransform(p, 0, 0, p, 0, 0)
          },

          // An island is a VOLUME. A footprint on the sea, a faint vertical
          // extent above it, and a ring of however much roster is left.
          island(i) {
            const c = this.ctx

            // The volume: a soft column above the footprint, so the thing being
            // defended reads as airspace rather than as ground.
            const g = c.createLinearGradient(0, i.y - i.r * 2.2, 0, i.y)
            g.addColorStop(0, "rgba(120,160,220,0)")
            g.addColorStop(1, "rgba(120,160,220,0.10)")
            c.fillStyle = g
            c.fillRect(i.x - i.r, i.y - i.r * 2.2, i.r * 2, i.r * 2.2)

            // Altitude bands. A READING AID ONLY: the physics is continuous and
            // obeys nothing here.
            c.strokeStyle = "rgba(255,255,255,0.05)"
            c.lineWidth = 1
            for (let b = 1; b <= 3; b++) {
              const y = i.y - (i.r * 2.2 * b) / 4
              c.beginPath(); c.moveTo(i.x - i.r, y); c.lineTo(i.x + i.r, y); c.stroke()
            }

            // The footprint.
            c.fillStyle = "rgba(120,160,220,0.10)"
            c.strokeStyle = i.open ? "rgba(120,220,170,0.55)" : "rgba(255,255,255,0.16)"
            c.lineWidth = i.open ? 2 : 1
            c.beginPath(); c.ellipse(i.x, i.y, i.r, i.r * 0.34, 0, 0, 6.284)
            c.fill(); c.stroke()

            // ⚠ THE ROSTER RING IS THE PRICE OF BEING POPULAR, DRAWN. An island
            // ground down by attention visibly thins, which is the whole reason
            // a raid costs airframes.
            c.strokeStyle = css(i.colour)
            c.lineWidth = 3
            c.beginPath()
            c.arc(i.x, i.y, i.r * 1.18, -1.5708, -1.5708 + 6.2832 * i.fill)
            c.stroke()

            c.fillStyle = "rgba(255,255,255,0.75)"
            c.font = "12px ui-monospace, monospace"
            c.textAlign = "center"
            c.fillText(i.name, i.x, i.y + i.r * 0.34 + 18)
          },

          // A raid is an arc from attacker to defender, with marks travelling
          // it. In flight it is bright and moving; fought, it is a faint trace
          // of where the traffic went.
          arc(a) {
            const c = this.ctx
            const mx = (a.x1 + a.x2) / 2, my = (a.y1 + a.y2) / 2 - a.lift

            // Thickness is traffic. A route flown once is a hairline; one flown
            // a dozen times is a rope, and the difference is the thing the list
            // under this map used to spell out in words.
            const n = a.count || 1
            c.strokeStyle = a.live ? "rgba(232,120,140,0.55)" : "rgba(160,180,220,0.22)"
            c.lineWidth = a.live ? 2 : Math.min(7, 1 + Math.log2(n) * 2)
            c.beginPath()
            c.moveTo(a.x1, a.y1)
            c.quadraticCurveTo(mx, my, a.x2, a.y2)
            c.stroke()

            if (!a.live) {
              // The count, once it is worth saying. A "1" on every hairline
              // would be noise on a map whose whole job is now to be glanceable.
              if (n > 1) {
                const bx = (a.x1 + 2 * mx + a.x2) / 4, by = (a.y1 + 2 * my + a.y2) / 4
                c.fillStyle = "rgba(200,215,240,0.55)"
                c.font = "11px ui-monospace, monospace"
                c.textAlign = "center"
                c.fillText(String(n), bx, by - 3)
              }
              return
            }

            // As many marks as the sortie, spaced along the curve.
            for (let n = 0; n < a.marks; n++) {
              const t = (this.phase + n / a.marks) % 1
              const u = 1 - t
              const x = u * u * a.x1 + 2 * u * t * mx + t * t * a.x2
              const y = u * u * a.y1 + 2 * u * t * my + t * t * a.y2
              c.fillStyle = "#E8788C"
              c.beginPath(); c.arc(x, y, 2.5, 0, 6.284); c.fill()
            }
          }
        }
      </script>

      <div class="relative">
        <%!-- ⚠ A STRIP, NOT A HERO. At 16/9 this was the biggest thing on the
              page and the least informative: four blobs at hash-derived
              positions carrying nothing the table below did not. Small and
              clickable it becomes the page's NAVIGATION, which is a job. It
              stays navigable — drag to pan, wheel to zoom, double-click to
              refit — so shrinking it costs nothing that was being used. --%>
        <canvas
          id="dronex-archipelago"
          phx-hook=".Archipelago"
          phx-update="ignore"
          class={["w-full rounded cursor-grab touch-none", backdrop()]}
          style="aspect-ratio: 4 / 1; max-height: 200px"
          data-world-width={@width}
          data-world-height={@height}
          data-isles={@isles}
          data-arcs={@arcs}
          data-focus={@focus}
          role="img"
          aria-label={
            "the archipelago, #{@count} islands. Click an island to see only its fights."
          }
        >
        </canvas>
        <div class="pointer-events-none absolute bottom-2 right-2 rounded bg-black/50 px-2 py-1 text-[10px] opacity-60">
          drag to move &middot; scroll to zoom &middot; double-click to fit
        </div>
      </div>

      <figcaption class="mt-2 text-xs opacity-40">
        Every island on one map, placed by a hash of its name, so nothing is
        claimed and nothing is granted: any two viewers holding the same islands
        draw the same world. The ring is how much roster is left — an island
        ground down by attention visibly thins. A green rim means open for
        battle. An arc is a raid, and a moving one is a raid in flight.
      </figcaption>
    </figure>
    """
  end

  # ── What a mark looks like is decided HERE ──────────────────────

  defp isle(row, at) do
    {x, y} = Map.get(at, row.id, {0, 0})
    v = Dronex.fact(row, :vitals) || %{}
    depth = num(v, "roster")
    capacity = max(1, num(v, "capacity"))

    %{
      # ⚠ THE 128-BIT IDENTITY AND NOT THE NAME. Two islands may call themselves
      # the same thing; the filter has to select one of them.
      id: row.id,
      name: Dronex.label(row),
      x: x,
      y: y,
      r: @size / 2.6,
      fill: min(1.0, depth / capacity),
      open: v["open"] == true,
      colour: ring_colour(depth / capacity)
    }
  end

  # Green while it has room to fight, amber as it is worn down, red at the floor.
  # The thresholds are a reading aid and nothing depends on them.
  defp ring_colour(f) when f > 0.6, do: 0x2F7D52
  defp ring_colour(f) when f > 0.3, do: 0xC08A2E
  defp ring_colour(_low), do: 0xC2557A

  # ⚠ AN ARC NEEDS BOTH ENDS, AND A COMMITMENT NAMES THEM BOTH. One side's
  # commitment carries its own id and its opponent's, so a single arriving fact
  # is enough to draw the arc — which matters, because the two commitments travel
  # separately and one of them may never come.
  # ⚠ ONE ARC PER PAIR, WEIGHTED, RATHER THAN ONE PER RAID. Twenty-four
  # overlapping identical curves said nothing about which route is busy, and the
  # list underneath the map existed to say it in words. An arc that thickens with
  # traffic carries it where the traffic is drawn, and the list goes.
  #
  # Raids still in flight stay SEPARATE and unaggregated: their marks travel the
  # curve, and merging them into a weighted line would stop the one animated
  # thing on this map from animating.
  defp arcs(raids, at, known) do
    {live, done} =
      raids
      |> Enum.flat_map(&arc(&1, at, known))
      |> Enum.split_with(& &1.live)

    (live ++ weighted(done)) |> Enum.take(24)
  end

  defp weighted(arcs) do
    arcs
    |> Enum.group_by(&{&1.x1, &1.y1, &1.x2, &1.y2})
    |> Enum.map(fn {_route, flown} ->
      %{hd(flown) | marks: 0} |> Map.put(:count, length(flown))
    end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  defp arc(raid, at, known) do
    {att, def_} = Dronex.sides(raid)
    ends(att || def_, at, known, Dronex.finished?(raid))
  end

  defp ends(nil, _at, _known, _finished), do: []

  defp ends(commitment, at, known, finished) do
    {from, to} = from_to(commitment)

    case {Map.get(at, from), Map.get(at, to)} do
      {{x1, y1}, {x2, y2}} ->
        [
          %{
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            lift: 70,
            live: not finished,
            marks: max(1, commitment["airframes"] || 1)
          }
        ]

      _one_end_unknown ->
        # An island we have never heard vitals from has no place on the map, so
        # there is nothing to draw an arc to. Dropped rather than guessed at.
        _ = known
        []
    end
  end

  # The arc always points attacker → defender, whichever side's commitment
  # happened to arrive.
  defp from_to(%{"role" => "attacker"} = c), do: {c["island_id"], c["opponent_id"]}
  defp from_to(c), do: {c["opponent_id"], c["island_id"]}

  defp num(v, key) when is_map(v) do
    case Map.get(v, key) do
      n when is_integer(n) -> n
      _other -> 0
    end
  end
end
