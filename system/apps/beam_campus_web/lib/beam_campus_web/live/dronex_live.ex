defmodule BeamCampusWeb.DronexLive do
  @moduledoc """
  Islands breeding drone controllers, and the last fight each of them ran.

  ## It plays a recording. It does not run the fight.

  Every twenty seconds an island publishes one whole engagement: every frame,
  already computed, in one fact of a few tens of kilobytes. This page stores it
  and animates it in the browser, which is why it can offer scrub, pause and slow
  motion, and why a hundred viewers cost the island nothing.

  The removed Robo Rumble page did the opposite. It received two genomes and a
  start index and **re-ran the duel locally**, which put a game engine inside a
  content website, pinned the site and the service to commits that drifted apart
  with nothing comparing them, and made every viewer repeat about 1,900 frames of
  identical work. Raf's correction was *aggregate and visualize, never
  regenerate*, and this page is that correction with a canvas on it.

  ## ⚠ These are training bouts, not raids

  Nothing crosses the mesh yet. What is drawn is an island's own best controller
  against one of its own scripted drills, which is what an island actually spends
  its time doing. The fact says `kind: training` and this page repeats it, because
  calling it a raid would be the first lie this track told.

  ## Coalesced, because a bout is not small

  A fact arrives every twenty seconds per island and carries the whole fight. The
  page marks itself dirty and redraws at most every `@redraw_ms`, which is the
  lesson the biotope page paid for: six full re-renders a second of a 700 KB
  document is not a crash and is indistinguishable from one, because the socket
  drops and the client shows its reconnect banner.
  """

  use BeamCampusWeb, :live_view

  import BeamCampusWeb.DronexMap, only: [archipelago: 1]

  @redraw_ms 500

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Dronex.subscribe()
    {:ok, socket |> assign(dirty?: false, chosen: nil) |> load()}
  end

  @impl true
  def handle_info({:dronex_changed, _kind}, socket), do: {:noreply, mark_dirty(socket)}
  def handle_info(:redraw, socket), do: {:noreply, socket |> assign(dirty?: false) |> load()}
  def handle_info(_msg, socket), do: {:noreply, socket}

  # One timer in flight at a time: the first fact after a redraw schedules the
  # next one and every fact until then is absorbed.
  defp mark_dirty(%{assigns: %{dirty?: true}} = socket), do: socket

  defp mark_dirty(socket) do
    Process.send_after(self(), :redraw, @redraw_ms)
    assign(socket, dirty?: true)
  end

  @impl true
  def handle_event("choose", %{"id" => id}, socket), do: {:noreply, assign(socket, chosen: id)}

  # The same deep blue-black the maps use. A function and not a module attribute:
  # inside a `~H` sigil `@backdrop` means `assigns.backdrop`.
  defp backdrop, do: "bg-[#0a1220]"

  defp load(socket) do
    islands = Dronex.islands()

    assign(socket,
      islands: islands,
      raids: Dronex.raids(),
      fight: Dronex.latest_fight(),
      state: Dronex.state(),
      refused: Dronex.refused()
    )
  end

  # The island being watched: whichever was clicked, else the first that has
  # actually published a bout, else the first at all.
  defp showing(islands, chosen) do
    Enum.find(islands, fn i -> i.id == chosen end) ||
      Enum.find(islands, &Dronex.fact(&1, :bout)) ||
      List.first(islands)
  end

  @impl true
  def render(assigns) do
    shown = showing(assigns.islands, assigns.chosen)

    assigns = assign(assigns, shown: shown, bout: shown && Dronex.fact(shown, :bout))

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-4 py-10">
        <.header>
          DroneX
          <:subtitle>
            <strong>Islands breeding drone controllers, and the last fight each one ran.</strong>
            A drone is a quadcopter with a battery, a forward sensor that cannot
            see behind it, one unguided weapon effective inside about fifteen
            metres and four guided interceptors. None of how it flies is written
            down: the controller is a neural network, and an island breeds them
            continuously against its own drills.
            <span class="mt-2 block">
              Each island also sits a <strong>frozen exam</strong>
              it never trains against, because a score measured against opponents
              that keep changing rises for reasons nobody can name.
            </span>
          </:subtitle>
        </.header>

        <.dronex_state state={@state} refused={@refused} />

        <%!-- ⚠ THE FIGHT FIRST, AND EVERYTHING ELSE UNDER IT. What anybody
             opening this page wants is drones fighting drones. The map, the
             counters and the frozen ladder all explain the fight; none of them
             replaces it, and for a while the fight was a small canvas below a
             picture of two circles and an arc. --%>
        <.fight :if={@fight} fight={@fight} />

        <%!-- ⚠ THE MAP SECOND. Every island has been a
             row in a list until now, which reads as several unrelated
             experiments. They are one archipelago, and the raids between them
             are the only thing that makes that true rather than asserted. --%>
        <.archipelago :if={@islands != []} islands={@islands} raids={@raids} class="mt-8" />

        <%!-- ⚠ OUTSIDE THE ISLANDS BLOCK ON PURPOSE. A raid is archipelago
             state, not island state, and a commitment can arrive before either
             island's vitals do — the two travel on different topics at
             different rates. Nested inside, the first raid of a cold start
             would be invisible. --%>
        <.raids raids={@raids} />

        <div :if={@islands != []} class="mt-8">
          <div class="flex flex-wrap gap-2">
            <button
              :for={i <- @islands}
              phx-click="choose"
              phx-value-id={i.id}
              class={["btn btn-sm", @shown && i.id == @shown.id && "btn-primary"]}
            >
              {Dronex.label(i)}
            </button>
          </div>

          <.vitals :if={@shown} row={@shown} />
        </div>

        <p class="mt-10 text-sm opacity-60">
          A bout arrives as a recording: every frame, already computed by the
          island that ran it, in one fact. This page animates it and holds no
          engine of its own, so what you are watching is what was counted rather
          than a re-enactment.
        </p>
      </div>
    </Layouts.app>
    """
  end

  # ── Vitals ──────────────────────────────────────────────────────

  attr :row, :map, required: true

  defp vitals(assigns) do
    v = Dronex.fact(assigns.row, :vitals) || %{}

    assigns =
      assign(assigns,
        v: v,
        rungs: Map.get(v, "benchmark_rungs", []),
        wins: Map.get(v, "benchmark_wins", []),
        starts: Map.get(v, "benchmark_starts", 0)
      )

    ~H"""
    <div class="mt-6 grid gap-4 sm:grid-cols-4">
      <.stat label="roster" value={num(@v, "roster")} of={num(@v, "capacity")} />
      <.stat label="generation" value={num(@v, "generation")} />
      <.stat label="rounds bred" value={num(@v, "rounds")} />
      <.stat label="admitted" value={num(@v, "admissions")} />
    </div>

    <%!-- ⚠ CAPTURES IS THE ONE THAT SAYS WHETHER ANY OF THIS IS HAPPENING.
          Raids and defences can both climb while it stays zero — an island
          refusing every raid on an engine mismatch looks identical from
          outside — and then the archipelago is several separate experiments
          with a light show on top. --%>
    <div class="mt-4 grid gap-4 sm:grid-cols-4">
      <.stat label="raids sent" value={num(@v, "raids")} />
      <.stat label="raids defended" value={num(@v, "defences")} />
      <.stat label="genomes captured" value={num(@v, "captures")} />
      <.stat label="airframes lost" value={num(@v, "raids_lost")} />
    </div>

    <p class="mt-3 text-xs opacity-50">
      <span class={["badge badge-sm", (@v["open"] && "badge-success") || "badge-ghost"]}>
        {(@v["open"] && "open for battle") || "closed for battle"}
      </span>
      <%!-- Being open is the resting state: an island that does nothing stays a
            target, and closing is an act. So `closed' means either a decision or
            an island ground down to its roster floor, and the roster above says
            which. --%>
      An island announces that it can be fought, and re-announces while it can.
      Staying open is what happens if it does nothing; closing is a decision, and
      an island at its floor closes whether it wants to or not.
    </p>

    <div class="mt-4">
      <h3 class="text-sm font-semibold opacity-70">The frozen exam</h3>
      <%!-- ⚠ A PROFILE AND NEVER A TOTAL. Six rungs, each a win rate. A single
            number would need weights, and weights are a judgement about which
            rung matters smuggled into a measurement. --%>
      <p :if={@starts == 0} class="mt-1 text-xs opacity-50">
        Not sat yet. An island sits it every five minutes once it has bred
        something, and a zero here is different from having sat it and lost.
      </p>
      <div :if={@starts > 0} class="mt-2 space-y-1">
        <div :for={{rung, wins} <- Enum.zip(@rungs, @wins)} class="flex items-center gap-2 text-xs">
          <span class="w-20 shrink-0 opacity-70">{rung}</span>
          <div class="h-2 grow rounded bg-base-300">
            <div class="h-2 rounded bg-primary" style={"width: #{pct(wins, @starts)}%"}></div>
          </div>
          <span class="w-14 shrink-0 tabular-nums opacity-60">{wins}/{@starts}</span>
        </div>
      </div>
      <p :if={@starts > 0} class="mt-2 text-xs opacity-40">
        Won at the bottom and lost at the top is what a graded instrument looks
        like. The rungs get harder left to right: the last one holds station and
        shoots, and never pays for closing.
      </p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :of, :any, default: nil

  defp stat(assigns) do
    ~H"""
    <div class="rounded-lg border border-base-300 p-3">
      <div class="text-xs uppercase tracking-wide opacity-50">{@label}</div>
      <div class="mt-1 text-2xl tabular-nums">
        {@value}<span :if={@of} class="text-base opacity-40">/{@of}</span>
      </div>
    </div>
    """
  end

  # ── The fight ───────────────────────────────────────────────────

  @doc """
  The most recent fight, played big.

  ⚠ **A RAID IS SIX AGAINST SIX AND A TRAINING BOUT IS ONE AGAINST A SCRIPT.**
  Both arrive in the same shape, so the same player draws either; what differs is
  that a raid is the only one where both sides are alive, evolved, and bred on
  different machines. It is shown whenever there is one.
  """
  attr :fight, :any, required: true

  def fight(%{fight: {kind, b}} = assigns) do
    assigns = assign(assigns, bout: b, raid?: kind == :raid)

    ~H"""
    <section class="mt-8">
      <div class="flex items-baseline justify-between gap-3">
        <h2 class="text-sm font-semibold opacity-80">
          {(@raid? && "A raid, fought in somebody else's airspace") || "A training bout"}
        </h2>
        <span :if={@raid?} class="badge badge-sm badge-error badge-outline">raid</span>
      </div>

      <p class="mt-1 text-xs opacity-50">
        {(@raid? &&
            "Twelve evolved controllers against twelve others, bred on a different machine under selection pressures neither side chose. The attacker flew in; the defender ran the fight and keeps every genome that attacked it.") ||
          "One evolved controller against a scripted drill. No island has been raided yet, so this is what there is to watch."}
      </p>

      <%!-- ⚠ A SCORE SHOWING ONE SIDE IS NOT A SCORE. The fight reported "raid
            bout · 240 ticks · won by defender", which is thin and wrong about
            what it was looking at. Both sides pay airframes on the same terms,
            so both are counted. --%>
      <.scoreline :if={@raid?} raid={@bout} />

      <.replay bout={@bout} big={@raid?} />
    </section>
    """
  end

  def fight(assigns), do: ~H""

  attr :raid, :map, required: true

  defp scoreline(assigns) do
    r = assigns.raid

    assigns =
      assign(assigns,
        sent: num(r, "raiders"),
        home: num(r, "raiders_home"),
        held: num(r, "defenders"),
        held_home: num(r, "defenders_home"),
        winner: Map.get(r, "winner", "draw"),
        ticks: num(r, "ticks")
      )

    ~H"""
    <div class="mt-3 grid gap-3 sm:grid-cols-3">
      <div class="rounded border border-base-300 p-3">
        <div class="text-xs uppercase tracking-wide opacity-50">attacker</div>
        <div class="mt-1 font-mono text-lg">{@home} / {@sent}</div>
        <div class="text-xs opacity-40">came home</div>
      </div>

      <div class="rounded border border-base-300 p-3">
        <div class="text-xs uppercase tracking-wide opacity-50">defender</div>
        <div class="mt-1 font-mono text-lg">{@held_home} / {@held}</div>
        <div class="text-xs opacity-40">still flying</div>
      </div>

      <div class="rounded border border-base-300 p-3">
        <div class="text-xs uppercase tracking-wide opacity-50">outcome</div>
        <div class="mt-1 font-mono text-lg">{@winner}</div>
        <div class="text-xs opacity-40">{@ticks} ticks</div>
      </div>
    </div>

    <p class="mt-2 text-xs opacity-40">
      <%!-- ⚠ WITHDRAWN IS NOT DEAD, and a score that could not tell them apart
            would price a successful retreat the same as a casualty, which is
            what the withdraw actuator exists to make a real choice. --%>
      Coming home counts a drone that broke off and left as well as one that
      survived the fight: withdrawing is a decision, not a casualty. Every drone
      that does not come home has to be bred back, on both sides.
    </p>
    """
  end

  attr :bout, :map, required: true
  attr :big, :boolean, default: false

  defp replay(assigns) do
    b = assigns.bout

    assigns =
      assign(assigns,
        payload:
          Jason.encode!(%{
            arena: Map.get(b, "arena", [1000, 1000, 300]),
            frames: Map.get(b, "frames", []),
            stride: 7,
            mstride: 5
          }),
        winner: Map.get(b, "winner", "draw"),
        ticks: Map.get(b, "ticks", 0),
        kind: Map.get(b, "kind", "training"),
        count: length(Map.get(b, "frames", []))
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

          read() {
            const d = JSON.parse(this.el.dataset.bout || "{}")
            this.arena = d.arena || [1000, 1000, 300]
            this.frames = d.frames || []
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
            if (!f) return

            for (let k = 0; k + this.mstride <= f.m.length; k += this.mstride) {
              const [px, py] = this.project(f.m[k + 1], f.m[k + 2], f.m[k + 3])
              c.globalAlpha = 1
              c.fillStyle = f.m[k + 4] ? "#E8A33D" : "#9AA3AF"
              c.beginPath()
              c.arc(px, py, f.m[k + 4] ? 2.5 : 1.5, 0, 6.284)
              c.fill()
            }

            for (let k = 0; k + this.stride <= f.d.length; k += this.stride) {
              const id = f.d[k]
              const x = f.d[k + 1], y = f.d[k + 2], z = f.d[k + 3]
              const yaw = f.d[k + 4], health = f.d[k + 5], state = f.d[k + 6]
              const attacker = id % 2 === 0
              const colour = attacker ? "#4C8DFF" : "#E2556E"
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

              // The shadow is where it is on the ground; the stalk is how high.
              // Together they are the only cue that survives a still frame.
              c.globalAlpha = 0.16
              c.fillStyle = "#000"
              c.beginPath(); c.ellipse(gx, gy, 4, 1.6, 0, 0, 6.284); c.fill()
              c.strokeStyle = colour
              c.globalAlpha = 0.22
              c.lineWidth = 1
              c.beginPath(); c.moveTo(gx, gy); c.lineTo(px, py); c.stroke()

              c.globalAlpha = state === 2 ? 0.25 : 1
              const r = 4
              c.fillStyle = state === 1 ? "#7BC47F" : colour
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
            c.globalAlpha = 1
          },

        }
      </script>

      <div class="flex items-baseline justify-between">
        <h3 class="text-sm font-semibold opacity-70">The last fight</h3>
        <span class="text-xs opacity-50">
          {@kind} bout · {@ticks} ticks · won by {@winner}
        </span>
      </div>

      <canvas
        id="dronex-replay"
        phx-hook=".Replay"
        phx-update="ignore"
        data-bout={@payload}
        class={["mt-2 w-full rounded", backdrop()]}
        style={(@big && "aspect-ratio: 16 / 9") || "aspect-ratio: 5 / 3"}
        role="img"
        aria-label={"a #{@ticks} tick engagement, won by #{@winner}"}
      >
      </canvas>

      <div class="mt-2 flex items-center gap-3">
        <button id="dronex-replay-play" class="btn btn-xs">play / pause</button>
        <input id="dronex-replay-scrub" type="range" min="0" value="0" class="range range-xs grow" />
        <span class="text-xs opacity-40">{@count} frames</span>
      </div>

      <p class="mt-2 text-xs opacity-40">
        <%!-- ⚠ THE CAPTION USED TO SAY "the scripted drill it is being measured
              against", which stopped being true the moment a raid was what got
              played: in a raid the red side is another island's evolved swarm,
              not a script. --%>
        Blue is the attacking side, red the defending one, green a drone that
        withdrew alive, faded a drone that was destroyed. The line is where a
        drone's nose points, which is the only direction it can see or shoot.
        Orange marks are guided interceptors and grey ones are unguided.
      </p>

      <p class="mt-1 text-xs opacity-40">
        <%!-- Altitude and distance share a screen axis in any oblique view, so
              the stalk is not decoration: it is the only thing that tells a
              drone high overhead from one far across the arena. --%>
        The fight is three-dimensional and so is this view: the floor is a
        thousand metres square, the ceiling three hundred up, and each drone is
        joined to its own shadow by a stalk showing how high it is. The tail
        behind it is where it actually was — every point a position the island
        computed, joined and faded, never a smoothed curve.
      </p>
    </figure>
    """
  end

  # ── States ──────────────────────────────────────────────────────

  attr :state, :atom, required: true
  attr :refused, :integer, required: true

  defp dronex_state(assigns) do
    ~H"""
    <div
      :if={@state != :watching}
      class="mt-6 rounded-lg border border-base-content/10 bg-base-200 p-6 text-sm"
    >
      <p :if={@state == :unconfigured}>
        This site is not configured to read this track. It needs <code>BEAM_CAMPUS_DRONEX_SEEDS</code>, which has no default on purpose:
        naming a public realm costs nothing, dialling a production station from
        every clone does.
      </p>
      <p :if={@state == :dark}>Configured, and not connected to the mesh yet. Retrying.</p>
      <p :if={@state == :silent}>
        Connected, and no island has said anything yet. Either none is running, or
        they are publishing on a different realm or namespace.
      </p>
    </div>
    <p :if={@refused > 0} class="mt-4 text-sm text-warning">
      {@refused} island(s) refused because this page's cap was reached. The view
      below is incomplete.
    </p>
    """
  end

  defp num(map, key), do: Map.get(map, key, 0)

  defp pct(_wins, 0), do: 0
  defp pct(wins, starts), do: round(wins * 100 / starts)

  @doc """
  Where the archipelago's genetic traffic is going, and how much of it there is.

  ⚠ **A LIST OF RAIDS IS NOT INFORMATION, AND IT WAS ONE FOR AN HOUR.** With two
  islands every raid renders the same sentence, so the page grew thirty-seven
  near-identical lines that said "beam01 sent 6" over and over. The map above
  already draws each raid as an arc; repeating them as text added length and no
  meaning.

  What a reader cannot get from the map is the **flow**: how much traffic runs
  each way, what it costs, and whether anything is stuck. So this is one row per
  DIRECTION, however many raids there have been, and a single line for the ones
  still out.

  ⚠⚠ **A raid in flight and a raid whose defender went dark look the same from
  here.** Both sides publish a commitment when the price is paid; only the
  defender publishes the recording. The page says "still out" rather than
  pretending to know which, and the attacker's own timer settles it after five
  minutes.
  """
  attr :raids, :list, required: true

  def raids(assigns) do
    assigns =
      assign(assigns,
        flows: flows(assigns.raids),
        out: Enum.count(assigns.raids, &(!Dronex.finished?(&1)))
      )

    ~H"""
    <div :if={@raids != []} class="mt-8">
      <h3 class="text-sm font-semibold opacity-70">Where the genomes are going</h3>
      <p class="mt-1 text-xs opacity-50">
        A raid moves opponents rather than fitness: what the defender keeps is
        the attacker's genomes, which its own trainer then has to beat. Losing
        drones is the price, and they have to be bred back.
      </p>

      <ul class="mt-3 space-y-1">
        <%!-- ⚠ `data-raid` EXISTS FOR THE TESTS AND IS WORTH THE ATTRIBUTE. Three
              times a refutation has been written against words that also appear
              in prose — "raid", then "fought", then "in flight", the last living
              in the map's own caption. A marker only a rendered row can produce
              cannot collide with a sentence. --%>
        <li :for={f <- @flows} data-raid={f.key} class="flex items-baseline gap-3 text-xs">
          <span class="font-mono opacity-70">{f.from} &rarr; {f.to}</span>
          <span class="opacity-50">
            {f.raids} {(f.raids == 1 && "raid") || "raids"}, {f.airframes} airframes committed
          </span>
        </li>
      </ul>

      <p :if={@out > 0} class="mt-2 text-xs opacity-40">
        {@out} still out. A raid whose defender has gone quiet looks exactly like
        one still being fought, so this page does not guess: the attacker writes
        the party off after five minutes.
      </p>
    </div>
    """
  end

  # One row per direction, newest direction first. A commitment names both ends,
  # so a single arriving fact is enough to attribute the traffic — which matters,
  # because the two commitments travel separately and one may never come.
  defp flows(raids) do
    raids
    |> Enum.flat_map(&flow(&1))
    |> Enum.group_by(& &1.key)
    |> Enum.map(fn {key, rows} ->
      %{
        key: key,
        from: hd(rows).from,
        to: hd(rows).to,
        raids: length(rows),
        airframes: Enum.sum(Enum.map(rows, & &1.airframes))
      }
    end)
    |> Enum.sort_by(& &1.raids, :desc)
  end

  defp flow(raid) do
    {att, def_} = Dronex.sides(raid)
    named(att || def_)
  end

  # A raid nobody described is dropped rather than given a row that says nothing.
  # It happens for recordings published before commitments existed.
  defp named(nil), do: []

  defp named(%{"role" => "attacker"} = c),
    do: [
      %{
        key: "#{c["island_id"]}->#{c["opponent_id"]}",
        from: c["island"],
        to: short(c["opponent_id"]),
        airframes: c["airframes"] || 0
      }
    ]

  defp named(c),
    do: [
      %{
        key: "#{c["opponent_id"]}->#{c["island_id"]}",
        from: short(c["opponent_id"]),
        to: c["island"],
        airframes: c["airframes"] || 0
      }
    ]

  # An island we have only ever seen named as somebody's opponent has an id and
  # no nickname. A short digest is better than a blank.
  defp short(nil), do: "?"
  defp short(id), do: String.slice(id, 0, 8)
end
