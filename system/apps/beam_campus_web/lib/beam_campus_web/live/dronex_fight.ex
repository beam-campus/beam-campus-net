defmodule BeamCampusWeb.DronexFight do
  @moduledoc """
  The player, its loss ledger, and the recording player's hook.

  ## Its own module because the LiveView had grown to 1,883 lines

  ⚠ **AND NOT A LiveComponent.** Those exist for STATEFUL scoping — their own
  assigns, their own diff, events targeted with `@myself` — and nothing here has
  state. Every function below is a pure function of the parent's assigns, so
  making them stateful would buy an `id`, an `update/2` and a second diff tree in
  exchange for nothing. `BeamCampusWeb.DronexMap` was already this shape and this
  follows it.

  ## It carries its own `backdrop/0` and nothing else

  Copied rather than shared, and `Dronex.Archipelago` states the house position
  on exactly this: "Two consumers is a copy... a shared library here would make
  one track's map a reason not to change the other's." A `utils` module holding
  four formatters would be the junk drawer the architecture rules name outright.
  """

  use BeamCampusWeb, :html

  @doc """
  The most recent fight, played big.

  ⚠ **A RAID IS SIX AGAINST SIX AND A TRAINING BOUT IS ONE AGAINST A SCRIPT.**
  Both arrive in the same shape, so the same player draws either; what differs is
  that a raid is the only one where both sides are alive, evolved, and bred on
  different machines. It is shown whenever there is one.
  """
  attr :fight, :any, required: true
  attr :payload, :string, required: true
  attr :frame_count, :integer, required: true

  def fight(%{fight: %{kind: kind, fact: b}} = assigns) do
    assigns = assign(assigns, bout: b, raid?: kind == :raid)

    ~H"""
    <section>
      <.replay bout={@bout} payload={@payload} count={@frame_count} big={@raid?} />
    </section>
    """
  end

  def fight(assigns), do: ~H""

  @doc """
  What destroyed the drones in the fight above, read back off its frames.

  ⚠ **NOT A CHART OF WHO WON.** The winner of these engagements is close to a
  coin flip and a picture of it would decorate that. This is about the MECHANISM:
  weapon damage is quantised at 25 and 50 points because `HIT_DAMAGE` and
  `INTERCEPTOR_DAMAGE` are exact multiples of 100 of a 10000 start, and a ram is
  continuous — so the part of a health drop that is not a multiple of 25 cannot
  have come from a gun.
  """
  attr :readings, :map, required: true

  def losses(assigns) do
    assigns = assign(assigns, losses: assigns.readings.damage, n: assigns.readings.n)

    ~H"""
    <div class="instrument mt-4 p-3">
      <div class="flex items-baseline justify-between gap-2">
        <span class="text-xs font-semibold opacity-70">What destroys them</span>
        <%!-- ⚠ THE `n` IS NOT OPTIONAL. These raids are whatever arrived and
              survived the row cap — a rolling window, not a sample anybody
              chose — so a share without a count invites a trust it has not
              earned. --%>
        <span class="font-mono text-xs opacity-50">
          {@n} raids · {@losses.deaths} lost · {@losses.total} points
        </span>
      </div>

      <%!-- ⚠ ONE BAR, TWO PARTS, AND A 2px GAP so the boundary is a boundary and
            not a colour change. --%>
      <div class="mt-2 flex h-3 w-full gap-0.5 overflow-hidden rounded">
        <div
          style={"width: #{@losses.weapon_share}%; background: var(--chart-cat-2)"}
          title={"#{@losses.weapon_share}% of damage fell in exact 25 or 50 point steps — weapons"}
        >
        </div>
        <div
          style={"width: #{@losses.other_share}%; background: var(--chart-cat-3)"}
          title={"#{@losses.other_share}% could not have come from a weapon — collisions or the arena edge"}
        >
        </div>
      </div>

      <div class="mt-1 flex flex-wrap justify-between gap-x-4 text-xs">
        <%!-- ⚠ ORANGE AND GREEN, NEVER THE BLUE/ROSE PAIR THIS USED TO USE.
              A visitor learns red=raider, blue=island from the player a few
              hundred pixels above. In that pair this bar reads as "40% of the
              damage was done by the attackers", which is not what it measures:
              both swarms shoot and both swarms ram. Damage TYPE is not a side. --%>
        <span><span style="color: var(--chart-cat-2)">■</span> weapons {@losses.weapon_share}%</span>
        <span>
          <span style="color: var(--chart-cat-3)">■</span> not weapons {@losses.other_share}%
        </span>
      </div>

      <details class="mt-2">
        <summary class="cursor-pointer text-xs opacity-40">
          How this is known, and what it cannot say
        </summary>
        <p class="mt-2 text-xs opacity-50">
          A weapon takes exactly 25 or 50 points, always, because the constants are
          exact multiples of 100 of a 10000 start and the quantum survives
          fractional health. A collision takes a continuous amount. So the part of
          a fall that is not a multiple of 25 <strong>cannot</strong>
          be a gun. Munitions never hit a friendly — the engine filters same-side
          before any geometry — but collisions ignore sides entirely, so a swarm
          can shred itself by flying tight.
          <span class="mt-2 block">
            ⚠ It cannot separate a ram from the ground. Confirming a collision
            means finding another drone within one metre, and the frames publish
            whole metres, so "touching" and "two metres apart" read the same. And
            a collision that happens to take exactly 25 points is counted as a
            weapon, which makes the second bar a floor rather than a ceiling.
          </span>
        </p>
      </details>
    </div>
    """
  end

  attr :bout, :map, required: true
  attr :payload, :string, required: true
  attr :count, :integer, required: true
  attr :big, :boolean, default: false

  defp replay(assigns) do
    b = assigns.bout

    assigns =
      assign(assigns,
        winner: Map.get(b, "winner", "draw"),
        ticks: Map.get(b, "ticks", 0),
        kind: Map.get(b, "kind", "training"),
        # ⚠ WHAT THE ISLAND SAID IT SENT, against what is still held. The board
        # keeps recordings to a byte budget, so a fight can be ranked and no
        # longer playable; drawn as an empty canvas that would read as a broken
        # page rather than as an old one.
        published: Map.get(b, "frame_count", 0)
      )

    ~H"""
    <figure class="mt-6">
      <script :type={Phoenix.LiveView.ColocatedHook} name=".Replay">
        // A RECORDING PLAYER. Every position here was computed by the island that
        // ran the fight; nothing is simulated, interpolated or guessed. That is
        // the whole architecture: the site aggregates and visualises, it does not
        // regenerate.
        export default {
          mounted() {
            this.ctx = this.el.getContext("2d")
            // Read once: a canvas cannot use a custom property, and resolving
            // one per drone per frame would do it thousands of times a second.
            this.palette = this.readPalette()
            this.i = 0
            this.playing = true
            this.read()
            this.fit()
            this.resize = () => { this.fit(); this.paint() }
            window.addEventListener("resize", this.resize)
            this.timer = setInterval(() => this.step(), 100)
            this.paint()
          },

          updated() { this.i = 0; this.read(); this.fit(); this.paint() },

          destroyed() {
            clearInterval(this.timer)
            window.removeEventListener("resize", this.resize)
          },

          // ⚠ EVERY COLOUR THE CANVAS PAINTS, READ ONCE. A canvas cannot use a
          // custom property, so each one has to be resolved to a string; doing
          // that per drone per frame would run getComputedStyle thousands of
          // times a second. The fallbacks are the values these had while they
          // were literals, so a stylesheet that fails to load degrades to the
          // picture that shipped rather than to black on black.
          readPalette() {
            const css = getComputedStyle(document.documentElement)
            const get = (name, fallback) =>
              css.getPropertyValue(name).trim() || fallback

            return {
              attacker: get("--side-attacker", "#e2556e"),
              defender: get("--side-defender", "#4c8dff"),
              ground: get("--arena-ground", "#45c8d8"),
              sensor: get("--arena-sensor", "#9ae9f2"),
              guided: get("--munition-guided", "#e8a33d"),
              ballistic: get("--munition-ballistic", "#9aa3af"),
              withdrawn: get("--drone-withdrawn", "#7bc47f")
            }
          },

          read() {
            const d = JSON.parse(this.el.dataset.bout || "{}")
            this.arena = d.arena || [1000, 1000, 300]
            this.frames = d.frames || []
            this.ground = d.ground || []
            this.groundRange = d.ground_range || 0
            this.stride = d.stride || 7
            this.mstride = d.mstride || 5
            this.scrub = document.getElementById(this.el.id + "-scrub")
            if (this.scrub) {
              this.scrub.max = Math.max(0, this.frames.length - 1)
              this.scrub.oninput = (e) => {
                this.playing = false
                this.i = parseInt(e.target.value)
                this.paint()
              }
            }
            const play = document.getElementById(this.el.id + "-play")
            if (play) play.onclick = () => { this.playing = !this.playing }
          },

          step() {
            if (!this.playing || this.frames.length === 0) return
            this.i = (this.i + 1) % this.frames.length
            this.paint()
          },

          fit() {
            const p = window.devicePixelRatio || 1
            const r = this.el.getBoundingClientRect()
            this.w = r.width
            this.h = r.width * 0.6
            this.el.width = this.w * p
            this.el.height = this.h * p
            this.ctx.setTransform(p, 0, 0, p, 0, 0)
            // How far the ground plane is sheared and squashed, and how much of
            // the canvas the 300 m column is allowed. Chosen so a drone at the
            // ceiling clears the far edge of the floor rather than sitting on it.
            this.SHEAR = 0.42
            this.TILT = 0.62
            this.LIFT = 0.42
            this.TRAIL = 10
            this.pad = 10
          },

          // ⚠ AN OBLIQUE PROJECTION, BECAUSE THE FIGHT IS THREE-DIMENSIONAL AND
          // THE DRAWING WAS NOT. The physics has always been 3D — x, y, z, a
          // vertical thrust axis and a 300 m ceiling — and this drew a flat plan
          // with altitude encoded as mark SIZE. The design said that was so
          // "height reads without a second view". It did not read at all: a
          // swarm climbing over another looked like a swarm sitting on it.
          //
          // So the ground plane is sheared and foreshortened, altitude becomes a
          // real vertical offset, and every drone is joined to its own shadow by
          // a stalk. Nothing is invented — it is the same three numbers the
          // island computed, projected differently.
          project(x, y, z) {
            const [ax, ay, az] = this.arena
            const nx = x / ax, ny = y / ay, nz = z / az
            const sx = (nx + ny * this.SHEAR) / (1 + this.SHEAR)
            const sy = (this.LIFT + ny * this.TILT - nz * this.LIFT) / (this.TILT + this.LIFT)
            return [this.pad + sx * (this.w - 2 * this.pad),
                    this.pad + sy * (this.h - 2 * this.pad)]
          },

          // The floor, drawn as the quad it projects to, with altitude rules
          // above it. THE RULES ARE A READING AID ONLY: the physics is
          // continuous and obeys nothing here.
          floor() {
            const c = this.ctx
            const corners = [[0, 0], [this.arena[0], 0],
                             [this.arena[0], this.arena[1]], [0, this.arena[1]]]
            c.strokeStyle = "rgba(255,255,255,0.10)"
            c.lineWidth = 1
            c.beginPath()
            corners.forEach(([x, y], n) => {
              const [px, py] = this.project(x, y, 0)
              n ? c.lineTo(px, py) : c.moveTo(px, py)
            })
            c.closePath()
            c.stroke()

            c.strokeStyle = "rgba(255,255,255,0.045)"
            for (let b = 1; b <= 3; b++) {
              const z = (this.arena[2] * b) / 4
              c.beginPath()
              const a = this.project(0, this.arena[1], z)
              const d = this.project(this.arena[0], this.arena[1], z)
              c.moveTo(a[0], a[1]); c.lineTo(d[0], d[1]); c.stroke()
            }
          },

          // ⚠ THE DEFENDER'S GROUND STATIONS, AND THE HOLES BETWEEN THEM.
          //
          // Terrain, drawn under everything else: they cannot be shot at, they
          // do not move, and they have no health. What they do is watch, and say
          // what they saw on the same channel the drones use.
          //
          // ⚠⚠ A TOWER MUST NOT BE DRAWN IN THE DRONES' VOCABULARY, and the
          // first version was. It was a thin vertical stalk with a dot on top —
          // which is EXACTLY the mark this page already uses for a drone joined
          // to its shadow. Five of them sat in the middle of the fight and read
          // as five more aircraft, so the honest answer to "where are the
          // towers" was "nowhere": nothing on the canvas said tower.
          //
          // So: a splayed lattice mast with cross-braces and a base pad, in a
          // colour no aircraft uses. Silhouette first, colour second — a
          // recolour alone would still have been a drone.
          // A lattice tower: two legs splayed from a base, tied by braces, with
          // a sensor head. The height and the splay are drawing choices — the
          // island publishes a position on the ground and nothing else — but the
          // SHAPE is the whole point, because it is what a viewer reads before
          // any colour or caption reaches them.
          mast(x, y, z) {
            const c = this.ctx
            const top = this.arena[2] * 0.17
            const leg = this.arena[0] * 0.022
            const [lx, ly] = this.project(x - leg, y, z)
            const [rx, ry] = this.project(x + leg, y, z)
            const [tx, ty] = this.project(x, y, top)

            c.globalAlpha = 1
            c.strokeStyle = this.palette.ground
            c.lineWidth = 2
            c.beginPath()
            c.moveTo(lx, ly); c.lineTo(tx, ty); c.lineTo(rx, ry)
            c.stroke()

            // Braces. Two ties across the legs say "structure" in a way a bare
            // V does not, and they cost four line segments.
            c.lineWidth = 1
            c.globalAlpha = 0.75
            for (const f of [0.34, 0.64]) {
              c.beginPath()
              c.moveTo(lx + (tx - lx) * f, ly + (ty - ly) * f)
              c.lineTo(rx + (tx - rx) * f, ry + (ty - ry) * f)
              c.stroke()
            }

            // The head that does the looking.
            c.globalAlpha = 1
            c.fillStyle = this.palette.sensor
            c.beginPath(); c.arc(tx, ty, 3.5, 0, 6.284); c.fill()

            // A pad on the floor, so the tower is planted rather than hovering.
            const [bx, by] = this.project(x, y, z)
            c.fillStyle = this.palette.ground
            c.globalAlpha = 0.55
            c.beginPath()
            c.moveTo(bx - 6, by); c.lineTo(bx, by - 2.4)
            c.lineTo(bx + 6, by); c.lineTo(bx, by + 2.4)
            c.closePath(); c.fill()
            c.globalAlpha = 1
          },

          // ⚠ COVERAGE IS A DOME, NOT A DISC, and the disc was a lie about the
          // geometry rather than a simplification of it.
          //
          // A station tests SLANT range: the straight line from a mast standing
          // on the ground to a drone in the air. Its detection volume is a
          // hemisphere, so its radius at altitude z is sqrt(R² - z²) — 350 m on
          // the floor and 180 m at the 300 m ceiling. A floor disc claims the
          // coverage a drone meets at the ceiling is the same as at ground
          // level, and it is barely half of it.
          //
          // Measured over the published placement, five stations, 1000 m arena:
          //
          //   on the floor    84% of the arena covered, 46% by two or more
          //   at the ceiling  42% covered,               8% by two or more
          //
          // ⚠⚠ SO THE COUNTERPLAY IS ALTITUDE, and the disc said the opposite.
          // Climbing roughly halves the chance of being seen at all and very
          // nearly removes the chance of being seen by two stations at once —
          // which matters more than it looks, because agreement across stations
          // confirms a target in about half the ticks one station needs, and the
          // network is silent until a track is confirmed. Flying high does not
          // just delay detection, it delays CONFIRMATION.
          //
          // ⚠⚠⚠ FIVE WIREFRAME DOMES ARE UNREADABLE. Four rendered attempts said
          // so: ceiling rings, meridian cages and stacked shells all turn into
          // spaghetti, because the domes are 350 m across on a 1000 m arena and
          // there are five of them. What works is a SLICE — the footprint on the
          // floor, faint, plus the dome cut at the height the attackers are
          // actually flying. As they climb, those rings shrink and lift, which
          // shows the shape by moving through it rather than by drawing it.
          // ⚠ THE TOWERS PING. THEY DO NOT SIT INSIDE A WIREFRAME.
          //
          // Coverage is a DOME: a station tests slant range from the ground, so
          // its radius at altitude z is sqrt(R² - z²), 350 m on the floor and
          // 180 m at the 300 m ceiling. That shape was drawn statically four
          // ways — ceiling rings, meridian cages, stacked shells, a live slice at
          // the raiders' altitude — and every one turned to spaghetti, because
          // the domes are 350 m across on a 1000 m arena and there are five.
          //
          // ⚠⚠ AND THE STATIC VERSION BURIED THE MASTS IN THEIR OWN COLOUR. The
          // network's confirmed picture is teal too, and there are up to
          // TWENTY-SIX tracks against five masts. "Where are the towers" kept
          // the same answer for the third time running.
          //
          // ⚠⚠⚠ SO: A PULSE. An expanding ring costs nothing on a still frame,
          // cannot accumulate into clutter, and MOVES — which is the one thing
          // that pulls an eye across a canvas of twenty-four moving drones.
          // Everything else here translates ballistically; nothing else pulses
          // in place, and a stationary pulse is separable from any amount of
          // moving clutter without being brighter than it. It also says what the
          // thing IS: something that senses, rather than furniture with a circle
          // round it.
          //
          // The ring expands to the station's real reach, so the animation
          // teaches the coverage the wireframe was trying to state, and stations
          // are phase-offset so the archipelago breathes rather than metronomes.
          //
          // ⚠⚠⚠⚠ AND IT IS SILENT WHEN THE NETWORK IS. A mast pings only while
          // the ground holds something CONFIRMED, because the network says
          // nothing until then. A quiet floor is the truth and not a gap in the
          // drawing. REGISTER D.13 says that at the shipped settings it is never
          // quiet, which is itself worth being able to see.
          pings(loud) {
            if (this.groundRange <= 0 || !loud) return
            const c = this.ctx
            const period = 44
            this.stations().forEach(([x, y], n) => {
              for (const offset of [0, 22]) {
                const phase = (((this.i + n * 11 + offset) % period) + period) % period / period
                if (phase < 0.02) continue
                c.globalAlpha = 1
                c.strokeStyle = "rgba(69,200,216," + (0.55 * (1 - phase)).toFixed(3) + ")"
                c.lineWidth = 1.3
                this.ring(x, y, this.groundRange * phase)
                c.stroke()
              }
            })
          },

          // The full footprint, faint, so a PAUSED frame still says how far a
          // station reaches. Without it the extent is knowable only by watching,
          // and a scrubbed-to frame would show masts standing in nothing.
          reach() {
            if (this.groundRange <= 0) return
            const c = this.ctx
            c.globalAlpha = 1
            c.strokeStyle = "rgba(69,200,216,0.12)"
            c.lineWidth = 1
            for (const [x, y] of this.stations()) {
              this.ring(x, y, this.groundRange)
              c.stroke()
            }
          },

          // Under the fight: the ground the fight is being fought over.
          terrain(loud) {
            this.reach()
            this.pings(loud)
          },

          // ⚠ OVER THE FIGHT, AND THAT IS A REVERSAL. Terrain belongs underneath
          // everything on principle — a mast cannot be shot at and does not move
          // — and underneath is where twenty-four full-alpha drones, their
          // trails, their altitude stalks and their heading lines painted over
          // it. Principle lost to arithmetic: a thing that cannot be seen is not
          // drawn. The pulses and the footprint stay below, so only the five
          // small solid marks come through.
          masts() {
            for (const [x, y, z] of this.stations()) this.mast(x, y, z)
          },

          stations() {
            const out = []
            for (let k = 0; k + 3 <= this.ground.length; k += 3) {
              out.push([this.ground[k], this.ground[k + 1], this.ground[k + 2]])
            }
            return out
          },

          // A horizontal circle on the floor, as the polygon it projects to.
          // `project` shears and foreshortens, so a circle on the ground is not
          // a circle on screen, and an ellipse fitted by eye would be wrong at
          // the edges of the arena — which is exactly where the gaps are.
          ring(x, y, r) {
            const c = this.ctx
            c.beginPath()
            for (let n = 0; n <= 40; n++) {
              const a = (n / 40) * 6.283185
              const [px, py] = this.project(x + Math.cos(a) * r, y + Math.sin(a) * r, 0)
              n ? c.lineTo(px, py) : c.moveTo(px, py)
            }
            c.closePath()
          },

          // ⚠ WHAT THE GROUND THINKS IS THERE, WHICH IS NOT WHAT IS THERE.
          //
          // ⚠⚠ THIS FUNCTION WAS DELETED BY AN EDIT AND SHIPPED MISSING FOR A
          // DAY, while the caption underneath went on telling visitors to hunt
          // for rings that no code drew. The test that was supposed to protect
          // it asserted the CAPTION. `dronex_live_test` now asserts that this
          // hook consumes `f.k`, because a promise in prose and a mark on a
          // canvas are different artifacts and only one of them was checked.
          //
          // Small and dim on purpose. These were once the same weight and colour
          // as the masts, and there are up to twenty-six of them against five
          // towers, which is how the towers stayed invisible after being redrawn
          // to be visible. A track is a secondary mark: the ground itself has to
          // be findable first.
          //
          // ⚠⚠⚠ NEVER JOINED TO A DRONE. A non-cooperative sensor never learns
          // whose aircraft it is looking at, so the wire carries three numbers
          // per track and no identity. Drawing the join would show a
          // correspondence the network does not have.
          believed(f) {
            const c = this.ctx
            const k = (f && f.k) || []
            for (let n = 0; n + this.kstride <= k.length; n += this.kstride) {
              const [px, py] = this.project(k[n], k[n + 1], k[n + 2])
              c.globalAlpha = 0.32
              c.strokeStyle = this.palette.ground
              c.lineWidth = 1
              c.beginPath(); c.arc(px, py, 3, 0, 6.284); c.stroke()
            }
            c.globalAlpha = 1
          },

          // ⚠ A TRAIL IS THE FRAMES THAT ACTUALLY HAPPENED, NOT A SMOOTHED CURVE.
          // Every point is a position the island computed and published; the
          // page joins them and fades them. Interpolating between frames would
          // be the site inventing motion it was never told about, which is the
          // one thing this player must never do.
          trail(id) {
            const back = []
            for (let n = Math.max(0, this.i - this.TRAIL); n < this.i; n++) {
              const f = this.frames[n]
              if (!f) continue
              for (let k = 0; k + this.stride <= f.d.length; k += this.stride) {
                if (f.d[k] === id) { back.push([f.d[k + 1], f.d[k + 2], f.d[k + 3]]); break }
              }
            }
            return back
          },

          paint() {
            const c = this.ctx
            const f = this.frames[this.i]
            c.clearRect(0, 0, this.w, this.h)
            this.floor()
            this.terrain(!!(f && f.k && f.k.length))
            if (!f) {
              this.masts()
              return
            }

            for (let k = 0; k + this.mstride <= f.m.length; k += this.mstride) {
              const [px, py] = this.project(f.m[k + 1], f.m[k + 2], f.m[k + 3])
              c.globalAlpha = 1
              c.fillStyle = f.m[k + 4] ? this.palette.guided : this.palette.ballistic
              c.beginPath()
              c.arc(px, py, f.m[k + 4] ? 2.5 : 1.5, 0, 6.284)
              c.fill()
            }

            for (let k = 0; k + this.stride <= f.d.length; k += this.stride) {
              const id = f.d[k]
              const x = f.d[k + 1], y = f.d[k + 2], z = f.d[k + 3]
              const yaw = f.d[k + 4], health = f.d[k + 5], state = f.d[k + 6]
              const attacker = id % 2 === 0
              // ⚠ RED IS THE RAIDER AND BLUE IS THE ISLAND HOLDING THE GROUND,
              // which is the way round every air-defence display has drawn it
              // for as long as there have been air-defence displays: blue is
              // us, red is what is coming at us. It was the other way round
              // until Raf pointed at it.
              //
              // "Us" is not arbitrary here. THE DEFENDER PUBLISHES THE
              // RECORDING — it hosted the fight, it settled it, and the
              // spectator is watching its airspace. So the island whose ground
              // this is gets the friendly colour, and it lands in the same
              // family as the teal masts standing on that ground, which reads
              // correctly: the swarm and the towers are one defence.
              // ⚠ FROM THE STYLESHEET, NOT FROM HERE. These were two hex
              // literals in this file, which is why nothing else could follow
              // the convention and the duration histogram contradicted it.
              const colour = attacker ? this.palette.attacker : this.palette.defender
              const [px, py] = this.project(x, y, z)
              const [gx, gy] = this.project(x, y, 0)

              // Where it has been. Velocity is invisible on a still frame
              // without this, and a swarm that is manoeuvring looks like a
              // swarm that is hovering.
              const back = this.trail(id)
              c.strokeStyle = colour
              c.lineWidth = 1.5
              back.forEach((p, n) => {
                const [tx, ty] = this.project(p[0], p[1], p[2])
                const next = n + 1 < back.length ? back[n + 1] : [x, y, z]
                const [nx2, ny2] = this.project(next[0], next[1], next[2])
                c.globalAlpha = 0.05 + 0.30 * (n / Math.max(1, back.length))
                c.beginPath(); c.moveTo(tx, ty); c.lineTo(nx2, ny2); c.stroke()
              })

              // ⚠ A GROUND MARK, NOT A SHADOW, AND THE DIFFERENCE IS THAT ONE OF
              // THEM IS VISIBLE. This drew black at alpha 0.16 — on `--arena-floor'
              // floor, which is near enough black that it painted nothing at
              // all. It was inherited from a canvas with a lighter background
              // and was probably never visible there either.
              //
              // On a dark floor the thing under a drone has to be LIGHTER than
              // the floor, not darker. It carries the drone's own colour, which
              // also says whose it is when a dozen of them overlap.
              c.globalAlpha = 0.30
              c.fillStyle = colour
              c.beginPath(); c.ellipse(gx, gy, 4.5, 1.8, 0, 0, 6.284); c.fill()

              // The stalk is how high. Altitude and distance share a screen axis
              // in any oblique view, so this is the only thing that tells a
              // drone overhead from one far across the arena.
              c.strokeStyle = colour
              c.globalAlpha = 0.35
              c.lineWidth = 1
              c.beginPath(); c.moveTo(gx, gy); c.lineTo(px, py); c.stroke()

              c.globalAlpha = state === 2 ? 0.25 : 1
              const r = 4
              c.fillStyle = state === 1 ? this.palette.withdrawn : colour
              c.beginPath(); c.arc(px, py, r, 0, 6.284); c.fill()

              if (state === 0) {
                // Where its nose points, which is where it can see and shoot.
                // Yaw is a heading in the ground plane, so it is drawn there and
                // projected, not swung around the screen.
                const a = (yaw / 256) * 6.28318
                const nose = this.project(x + Math.cos(a) * this.arena[0] * 0.05,
                                          y + Math.sin(a) * this.arena[1] * 0.05, z)
                c.strokeStyle = c.fillStyle
                c.lineWidth = 1.5
                c.beginPath(); c.moveTo(px, py); c.lineTo(nose[0], nose[1]); c.stroke()

                // Health as an arc over the mark, so a losing drone reads at a
                // glance rather than needing a table.
                c.strokeStyle = "rgba(255,255,255,0.65)"
                c.lineWidth = 2
                c.beginPath()
                c.arc(px, py, r + 3, -1.5708, -1.5708 + 6.2832 * (health / 100))
                c.stroke()
              }
            }

            // ⚠ LAST, AND BOTH FOR THE SAME REASON. The ground's belief and the
            // masts themselves are small marks competing with twenty-four
            // full-alpha aircraft; drawn first they are painted over and the
            // page tells a visitor to look for something that is not there.
            this.believed(f)
            this.masts()
            c.globalAlpha = 1
          },

        }
      </script>

      <div class="flex items-baseline justify-between">
        <h3 class="text-base font-semibold">The last fight</h3>
        <span class="text-xs opacity-50">
          {@kind} · {@ticks} ticks ·
          <span style={"color: #{side_colour(@winner)}"}>{Dronex.SayWhoWon.said(@winner)}</span>
        </span>
      </div>

      <%!-- ⚠ 4/3 WHEN THE RAIL IS BESIDE IT, AND THE REASON IS NOT LETTERBOX.
            `project' normalises the world into the unit square and scales to
            whatever canvas it is given, so nothing is ever letterboxed — the
            scene STRETCHES. A wide canvas therefore flattens the vertical
            axis, and the vertical axis is altitude, which is the whole of the
            dome story: a station's reach is 350 m on the floor and 180 m at
            the ceiling, so height is how a raider gets past a network.
            Rendered both ways at the railed width before choosing: at 16/9 the
            swarm reads as one flat cluster, at 4/3 the stalks lengthen and who
            is high is legible. --%>
      <canvas
        id="dronex-replay"
        phx-hook=".Replay"
        phx-update="ignore"
        data-bout={@payload}
        class={[
          "mt-2 w-full rounded lg:aspect-[4/3]",
          backdrop(),
          (@big && "aspect-[16/9]") || "aspect-[5/3]"
        ]}
        role="img"
        aria-label={"a #{@ticks} tick engagement, #{Dronex.SayWhoWon.said(@winner)}"}
      >
      </canvas>

      <div class="mt-2 flex items-center gap-3">
        <button id="dronex-replay-play" class="btn btn-xs">play / pause</button>
        <input
          id="dronex-replay-scrub"
          type="range"
          min="0"
          value="0"
          class="range range-xs grow"
          aria-label="scrub through the recording"
        />
        <span :if={@count > 0} class="text-xs opacity-40">{@count} frames</span>
        <span :if={@count == 0 and @published > 0} class="text-xs opacity-60">
          this recording is no longer held — {@published} frames, dropped to stay inside
          the board's memory budget
        </span>
      </div>
    </figure>
    """
  end

  @doc """
  How much of the raid the defender's towers actually had located, by altitude.

  ## ⚠ THE SUMMARY OF THE OVERLAY ABOVE, AND NOT A CHART OF WHERE THEY DIED

  The pale rings in the replay are what the network BELIEVED. Watching them lag
  and lose the drones is the thing a visitor sees; this is that same fact
  counted.

  Deaths-by-altitude is the chart NOT to draw: the towers stand on the ground and
  so does the objective, so deaths pile up low from exposure geometry alone, and
  the picture would read as proof of "height buys silence" while showing only
  that the fighting happens where the fighting happens. A rate with time at
  altitude underneath it has no such problem — a band nobody flies in cannot
  flatter itself.

  ## ⚠⚠ IT IS A CEILING, BECAUSE A TRACK HAS NO NAME

  Tracks are published with no id and no confidence, deliberately, so this cannot
  say a drone was tracked. It says a track existed within the gate of it, and two
  raiders flying together are both covered by one track. Over-counting is the
  only direction it errs in, which is why the caption calls it a ceiling.
  """
  attr :readings, :map, required: true

  def coverage(assigns) do
    assigns = assign(assigns, coverage: assigns.readings.coverage, n: assigns.readings.n)

    ~H"""
    <div class="instrument mt-4 p-3">
      <div class="flex items-baseline justify-between gap-2">
        <span class="text-xs font-semibold opacity-70">What the towers hold, by altitude</span>
        <span class="font-mono text-xs opacity-50">
          {@n} raids · within {@coverage.gate} m
        </span>
      </div>

      <div class="mt-2 space-y-1">
        <div :for={b <- Enum.reverse(@coverage.bands)} class="flex items-center gap-2 text-xs">
          <span class="w-16 shrink-0 text-right font-mono tabular-nums opacity-50">
            {b.from}–{b.to} m
          </span>

          <div class="h-3 w-40 shrink-0 rounded-sm bg-base-300/60">
            <div
              :if={b.coverage}
              class="h-3 rounded-sm"
              style={"width: #{b.coverage}%; background: var(--side-attacker)"}
              title={"#{b.held} of #{b.frames} raider-frames held"}
            >
            </div>
          </div>

          <span class="w-8 shrink-0 font-mono tabular-nums">
            {(b.coverage && "#{b.coverage}%") || "—"}
          </span>

          <%!-- ⚠ THE DENOMINATOR IS ON THE ROW. A band flown for three frames and
                one flown for three hundred must not read alike, and a percentage
                alone makes them identical. --%>
          <span class="font-mono text-[10px] opacity-30">n={b.frames}</span>
        </div>
      </div>

      <details class="mt-2">
        <summary class="cursor-pointer text-xs opacity-40">
          What this counts, and why it is a ceiling
        </summary>
        <p class="mt-2 text-xs opacity-50">
          Of all the time raiders spent alive at each altitude, the share of it
          where the defender's network had a track within {@coverage.gate} metres.
          The design says height buys silence — a tower tests slant range, so its
          reach shrinks as a raider climbs — and this is the first thing that has
          measured it.
          <span class="mt-2 block">
            ⚠ A ceiling, not a measurement of a drone. Tracks carry no id and no
            confidence on purpose, so this cannot say <em>that</em>
            drone was held; it says a track was near it. Two raiders flying
            together are both counted against one track. And a band with a small
            n is noise however tall its bar, which is why n is on every row.
          </span>
        </p>
      </details>
    </div>
    """
  end

  # The same deep blue-black the maps use. A function and not a module attribute:
  # inside a `~H` sigil `@backdrop` means `assigns.backdrop`.
  # ⚠ THE WINNER IS A SIDE, so it takes the side's colour. "won by attacker" in
  # neutral text made the one word that decides the whole fight the only word on
  # the panel with nothing to distinguish it.
  defp side_colour("attacker"), do: "var(--side-attacker)"
  defp side_colour("defender"), do: "var(--side-defender)"
  defp side_colour(_draw), do: "var(--side-draw)"

  defp backdrop, do: "bg-[var(--arena-floor)]"
end
