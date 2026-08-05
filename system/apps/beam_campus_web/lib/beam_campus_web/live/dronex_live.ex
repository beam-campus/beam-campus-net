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

  defp load(socket) do
    islands = Dronex.islands()
    assign(socket, islands: islands, state: Dronex.state(), refused: Dronex.refused())
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
          <.replay :if={@bout} bout={@bout} />
          <p :if={@shown && is_nil(@bout)} class="mt-6 text-sm opacity-60">
            This island is reporting, and has not published a fight yet. An island
            publishes one every twenty seconds once it has a population.
          </p>
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

  # ── The replay ──────────────────────────────────────────────────

  attr :bout, :map, required: true

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
          },

          // Top-down. Altitude is mark SIZE plus a shadow on the floor, because a
          // flat plan of a fight in a 300 m column throws away the axis the
          // drones spend most of their thrust on.
          at(x, y) {
            return [x / this.arena[0] * this.w, y / this.arena[1] * this.h]
          },

          paint() {
            const c = this.ctx
            const f = this.frames[this.i]
            c.clearRect(0, 0, this.w, this.h)
            c.strokeStyle = "rgba(255,255,255,0.10)"
            c.lineWidth = 1
            c.strokeRect(0.5, 0.5, this.w - 1, this.h - 1)
            if (!f) return

            for (let k = 0; k + this.mstride <= f.m.length; k += this.mstride) {
              const [px, py] = this.at(f.m[k + 1], f.m[k + 2])
              c.fillStyle = f.m[k + 4] ? "#E8A33D" : "#9AA3AF"
              c.beginPath()
              c.arc(px, py, f.m[k + 4] ? 2.5 : 1.5, 0, 6.284)
              c.fill()
            }

            for (let k = 0; k + this.stride <= f.d.length; k += this.stride) {
              const [px, py] = this.at(f.d[k + 1], f.d[k + 2])
              const alt = f.d[k + 3] / this.arena[2]
              const yaw = f.d[k + 4]
              const health = f.d[k + 5]
              const state = f.d[k + 6]
              const attacker = f.d[k] % 2 === 0
              const r = 3 + alt * 5

              // The shadow is where it is; the mark is how high.
              c.globalAlpha = 0.18
              c.fillStyle = "#000"
              c.beginPath(); c.arc(px, py, 3, 0, 6.284); c.fill()

              c.globalAlpha = state === 2 ? 0.25 : 1
              const colour = attacker ? "#4C8DFF" : "#E2556E"
              c.fillStyle = state === 1 ? "#7BC47F" : colour
              c.beginPath(); c.arc(px, py, r, 0, 6.284); c.fill()

              // Where its nose points, which is where it can see and shoot.
              if (state === 0) {
                const a = yaw / 256 * 6.28318
                c.strokeStyle = c.fillStyle
                c.lineWidth = 1.5
                c.beginPath()
                c.moveTo(px, py)
                c.lineTo(px + Math.cos(a) * (r + 6), py + Math.sin(a) * (r + 6))
                c.stroke()
                // Health as an arc over the mark, so a losing drone reads at a glance.
                c.strokeStyle = "rgba(255,255,255,0.65)"
                c.lineWidth = 2
                c.beginPath()
                c.arc(px, py, r + 3, -1.57, -1.57 + 6.28318 * health / 100)
                c.stroke()
              }
              c.globalAlpha = 1
            }
          }
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
        class="mt-2 w-full rounded bg-black/40"
        style="aspect-ratio: 5 / 3"
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
        Blue is the island's own controller, red the scripted drill it is being
        measured against, green a drone that withdrew alive, faded a drone that
        was destroyed. The line is where a drone's nose points, which is the only
        direction it can see or shoot. Orange marks are guided interceptors and
        grey ones are unguided.
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
end
