defmodule BeamCampusWeb.AdaptationLive do
  @moduledoc """
  Live neuroevolution workbench. Pick a controller and a fault scenario, evolve it
  with separable CMA-ES (the fitness curve streams in live), then run the evolved
  controller on the cart-pole and watch it meet the hidden motor fault. Real backend:
  both evolution and inference are faber-tweann on the BEAM.
  """
  use BeamCampusWeb, :live_view

  alias BeamCampus.Adaptation

  @tick_ms 33
  @max_gen 120
  @lambda 70

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Adaptation workbench",
       arms: Adaptation.arms(),
       limit: Adaptation.angle_limit(),
       track: Adaptation.track(),
       # showcase: the three pre-evolved controllers, same default fault, side by side
       sc_agents: showcase_agents(),
       sc_frames: showcase_frames(),
       sc_playing: false,
       sc_step: 0,
       sc_goal: Adaptation.default_scenario().goal,
       sc_shift_at: Adaptation.default_scenario().shift_at,
       # workbench: evolve your own
       controller: :plastic,
       fault: :reversal,
       wind: 5.0,
       shift_at: 90,
       goal: 250,
       phase: :idle,
       curve: [],
       best_fit: nil,
       genome: nil,
       agent: nil,
       frame: initial_frame(),
       task: nil
     )}
  end

  # --- controls -----------------------------------------------------------------

  @impl true
  def handle_event("controller", %{"arm" => arm}, socket) do
    {:noreply, socket |> assign(controller: String.to_existing_atom(arm)) |> to_idle()}
  end

  def handle_event("fault", %{"type" => type}, socket) do
    {:noreply, socket |> assign(fault: String.to_existing_atom(type)) |> to_idle()}
  end

  def handle_event("params", %{"wind" => w, "shift_at" => s}, socket) do
    {:noreply, socket |> assign(wind: to_num(w, 5.0), shift_at: trunc(to_num(s, 90))) |> to_idle()}
  end

  def handle_event("evolve", _params, socket) do
    lv = self()
    sc = scenario(socket.assigns)
    arm = socket.assigns.controller

    task =
      Task.async(fn ->
        Adaptation.evolve(arm, sc, fn g, f -> send(lv, {:gen, g, f}) end,
          max_generations: @max_gen,
          lambda: @lambda
        )
      end)

    {:noreply, assign(socket, phase: :evolving, curve: [], best_fit: nil, genome: nil, agent: nil, task: task)}
  end

  def handle_event("run", _params, socket) when not is_nil(socket.assigns.genome) do
    agent = Adaptation.init_with(socket.assigns.controller, socket.assigns.genome, scenario(socket.assigns))
    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, socket |> assign(phase: :running, agent: agent, frame: initial_frame()) |> push_event("wb_reset", %{})}
  end

  def handle_event("stop", _params, socket), do: {:noreply, assign(socket, phase: :ready)}

  def handle_event("sc_toggle", _params, socket) do
    cond do
      socket.assigns.sc_playing -> {:noreply, assign(socket, sc_playing: false)}
      sc_all_done?(socket) -> {:noreply, socket |> reset_showcase() |> sc_start()}
      true -> {:noreply, sc_start(socket)}
    end
  end

  def handle_event("sc_restart", _params, socket) do
    {:noreply, socket |> assign(sc_playing: false) |> reset_showcase() |> push_event("reset", %{})}
  end

  # --- evolution progress + result ----------------------------------------------

  @impl true
  def handle_info({:gen, gen, fit}, socket) do
    {:noreply, assign(socket, curve: [{gen, fit} | socket.assigns.curve], best_fit: round(fit))}
  end

  def handle_info({ref, {genome, fit}}, %{assigns: %{task: %Task{ref: ref}}} = socket) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, phase: :ready, genome: genome, best_fit: fit, task: nil)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}

  # --- animation ----------------------------------------------------------------

  def handle_info(:tick, %{assigns: %{phase: :running, agent: agent}} = socket) do
    {frame, agent2} = Adaptation.step(agent)
    socket = socket |> assign(frame: frame, agent: agent2) |> push_event("wb_frame", frame)

    if frame.done do
      {:noreply, assign(socket, phase: :done)}
    else
      Process.send_after(self(), :tick, @tick_ms)
      {:noreply, socket}
    end
  end

  def handle_info(:tick, socket), do: {:noreply, socket}

  def handle_info(:sc_tick, %{assigns: %{sc_playing: false}} = socket), do: {:noreply, socket}

  def handle_info(:sc_tick, socket) do
    stepped = Map.new(socket.assigns.sc_agents, fn {arm, a} -> {arm, Adaptation.step(a)} end)
    frames = Map.new(stepped, fn {arm, {f, _}} -> {arm, f} end)
    agents = Map.new(stepped, fn {arm, {_, a}} -> {arm, a} end)
    step = socket.assigns.sc_step + 1
    done = Enum.all?(agents, fn {_, a} -> a.done end) or step >= socket.assigns.sc_goal

    socket =
      socket
      |> assign(sc_agents: agents, sc_frames: frames, sc_step: step, sc_playing: not done)
      |> push_event("frame", %{agents: frames})

    unless done, do: Process.send_after(self(), :sc_tick, @tick_ms)
    {:noreply, socket}
  end

  # --- helpers ------------------------------------------------------------------

  defp showcase_agents, do: Map.new(Adaptation.arms(), fn %{key: k} -> {k, Adaptation.init(k)} end)
  defp showcase_frames, do: Map.new(Adaptation.arms(), fn %{key: k} -> {k, initial_frame()} end)
  defp reset_showcase(socket), do: assign(socket, sc_agents: showcase_agents(), sc_frames: showcase_frames(), sc_step: 0)
  defp sc_all_done?(socket), do: Enum.all?(socket.assigns.sc_agents, fn {_, a} -> a.done end)

  defp sc_start(socket) do
    Process.send_after(self(), :sc_tick, @tick_ms)
    assign(socket, sc_playing: true)
  end

  defp scenario(a), do: %{wind: a.wind, shift_gain: fault_gain(a.fault), shift_at: a.shift_at, goal: a.goal}

  defp fault_gain(:reversal), do: -1.0
  defp fault_gain(:weaken), do: 0.35

  defp to_idle(socket), do: assign(socket, phase: :idle, curve: [], best_fit: nil, genome: nil, agent: nil, frame: initial_frame())

  defp initial_frame, do: %{cpos: 0.0, angle: 0.0628, step: 0, done: false, status: :balancing, shifted: false}

  defp to_num(s, default) do
    case Float.parse(to_string(s)) do
      {v, _} -> v
      :error -> default
    end
  end

  # --- render -------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-4xl px-6 py-16">
        <p class="font-mono text-xs uppercase tracking-[0.22em] text-primary mb-4">
          Faber Neuroevolution · live workbench · EXP-046
        </p>
        <h1 class="text-3xl sm:text-4xl font-semibold tracking-tight text-balance mb-4">
          Evolve a controller, then break its world
        </h1>
        <p class="text-base-content/70 max-w-2xl mb-8">
          Pick a controller and a fault, evolve it live with separable CMA-ES, then run it on a windy pole whose
          motor <b>reverses</b> partway — a hidden fault it must survive by adapting, not by design. Evolution and
          physics both run the real faber-tweann engine on the server.
        </p>

        <section class="mb-12">
          <h2 class="text-lg font-semibold mb-1">Three controllers, one fault</h2>
          <p class="text-sm text-base-content/60 mb-4">
            The pre-evolved controllers on the default scenario — motor reverses at step {@sc_shift_at}. Press play
            and watch fixed topple, adaptive recover, and recurrent struggle in between.
          </p>
          <div class="flex items-center gap-3 mb-4">
            <button class="btn btn-sm btn-primary" phx-click="sc_toggle">
              {if @sc_playing, do: "❚❚ Pause", else: "▶ Play"}
            </button>
            <button class="btn btn-sm btn-outline" phx-click="sc_restart">↺ Restart</button>
            <span class="font-mono text-xs text-base-content/50">step {@sc_step} / {@sc_goal}</span>
          </div>
          <div id="pole-field" phx-hook=".PoleField" data-limit={@limit} data-track={@track} class="grid gap-4 sm:grid-cols-3">
            <.sc_panel :for={arm <- @arms} arm={arm} frame={@sc_frames[arm.key]} />
          </div>
        </section>

        <h2 class="text-lg font-semibold mb-1">Now evolve your own</h2>
        <p class="text-sm text-base-content/60 mb-4">
          Pick a controller and a fault, evolve it live with separable CMA-ES, then run the evolved controller.
        </p>

        <div class="card bg-base-100 border border-base-300 mb-6">
          <div class="card-body gap-5">
            <div>
              <p class="font-mono text-xs uppercase tracking-wide text-base-content/50 mb-2">Controller</p>
              <div class="flex flex-wrap gap-2">
                <button
                  :for={arm <- @arms}
                  phx-click="controller"
                  phx-value-arm={arm.key}
                  class={["btn btn-sm", (@controller == arm.key && "btn-primary") || "btn-outline"]}
                >
                  {arm.label}
                </button>
              </div>
              <p class="font-mono text-[11px] text-base-content/50 mt-2">
                {Enum.find(@arms, &(&1.key == @controller)).sub}
              </p>
            </div>

            <form phx-change="params" class="grid gap-5 sm:grid-cols-3 sm:items-end">
              <div class="sm:col-span-1">
                <p class="font-mono text-xs uppercase tracking-wide text-base-content/50 mb-2">Fault</p>
                <div class="flex gap-2">
                  <button type="button" phx-click="fault" phx-value-type="reversal" class={["btn btn-sm", (@fault == :reversal && "btn-primary") || "btn-outline"]}>reverse</button>
                  <button type="button" phx-click="fault" phx-value-type="weaken" class={["btn btn-sm", (@fault == :weaken && "btn-primary") || "btn-outline"]}>weaken</button>
                </div>
              </div>
              <label class="block">
                <span class="font-mono text-xs uppercase tracking-wide text-base-content/50">Wind · {:erlang.float_to_binary(@wind, decimals: 1)} N</span>
                <input type="range" name="wind" min="0" max="8" step="0.5" value={@wind} class="range range-primary range-sm mt-2" />
              </label>
              <label class="block">
                <span class="font-mono text-xs uppercase tracking-wide text-base-content/50">Fault at step · {@shift_at}</span>
                <input type="range" name="shift_at" min="40" max="180" step="10" value={@shift_at} class="range range-primary range-sm mt-2" />
              </label>
            </form>

            <div class="flex flex-wrap items-center gap-3">
              <button phx-click="evolve" disabled={@phase == :evolving} class="btn btn-primary">
                {if @phase == :evolving, do: "Evolving…", else: "⚙ Evolve"}
              </button>
              <button phx-click="run" disabled={@phase not in [:ready, :done]} class="btn btn-secondary">
                ▶ Run the fault
              </button>
              <.phase_label phase={@phase} best={@best_fit} goal={@goal} />
            </div>
          </div>
        </div>

        <div class="grid gap-6 sm:grid-cols-2">
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4">
              <h2 class="font-mono text-xs uppercase tracking-wide text-base-content/50">Evolution (best fitness / generation)</h2>
              <.fitness_curve curve={@curve} goal={@goal} />
            </div>
          </div>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4">
              <h2 class="font-mono text-xs uppercase tracking-wide text-base-content/50">The run</h2>
              <div id="pole-wb" phx-hook=".PoleWb" data-limit={@limit} data-track={@track}>
                <canvas id="wb-canvas" class="w-full h-auto"></canvas>
              </div>
              <div class="font-mono text-xs mt-1">
                <.run_status frame={@frame} phase={@phase} shift_at={@shift_at} />
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 border border-base-300 mt-6">
          <div class="card-body">
            <p class="text-sm text-base-content/70">
              A constant wind means the controller must always apply force, so a motor reversal actually bites (a
              settled regulator applying no force would not notice). <b>Fixed</b> was never built to adapt and
              topples; <b>adaptive</b> (reward-modulated plasticity) derives an error from the pole's tilt and
              re-wires its own weights to recover; <b>recurrent</b> adapts through its internal state, less
              reliably. Try evolving each — and note that with a short budget none may fully solve, exactly as in
              the research (adaptation is reliable, not free).
            </p>
          </div>
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PoleWb">
        export default {
          mounted() {
            this.limit = parseFloat(this.el.dataset.limit)
            this.track = parseFloat(this.el.dataset.track)
            const c = this.el.querySelector("#wb-canvas")
            c.width = 560; c.height = 240
            this.ctx = c.getContext("2d")
            this.handleEvent("wb_frame", (f) => this.draw(f))
            this.handleEvent("wb_reset", () => this.draw({cpos:0, angle:0.0628, done:false, status:"balancing"}))
            this.draw({cpos:0, angle:0.0628, done:false, status:"balancing"})
          },
          ink() { return getComputedStyle(this.el).color },
          color(f) {
            if (f.status === "crashed") return "#C7583F"
            const r = Math.abs(f.angle) / this.limit
            if (r >= 0.85) return "#C7583F"
            if (r >= 0.5) return "#F2B142"
            return "#4E9F6B"
          },
          draw(f) {
            const ctx = this.ctx, W = 560, H = 240, trackY = 180, poleLen = 120, cartW = 60, cartH = 24
            const ink = this.ink()
            const px = x => 40 + ((x + this.track) / (2 * this.track)) * 480
            const hx = px(f.cpos), hy = trackY - cartH / 2, col = this.color(f)
            ctx.clearRect(0, 0, W, H)
            ctx.strokeStyle = ink; ctx.globalAlpha = 0.18; ctx.lineWidth = 3
            ctx.beginPath(); ctx.moveTo(30, trackY); ctx.lineTo(530, trackY); ctx.stroke()
            ctx.globalAlpha = 0.14; ctx.lineWidth = 1; ctx.setLineDash([3,3])
            for (const s of [-1,1]) { ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(hx+poleLen*Math.sin(s*this.limit), hy-poleLen*Math.cos(s*this.limit)); ctx.stroke() }
            ctx.setLineDash([]); ctx.globalAlpha = 0.55; ctx.fillStyle = ink
            ctx.fillRect(hx - cartW/2, trackY - cartH, cartW, cartH)
            ctx.globalAlpha = 1
            const tx = hx + poleLen*Math.sin(f.angle), ty = hy - poleLen*Math.cos(f.angle)
            ctx.strokeStyle = col; ctx.lineWidth = 6; ctx.lineCap = "round"
            ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(tx, ty); ctx.stroke()
            ctx.fillStyle = col; ctx.beginPath(); ctx.arc(tx, ty, 8, 0, 2*Math.PI); ctx.fill()
            ctx.fillStyle = ink; ctx.beginPath(); ctx.arc(hx, hy, 4, 0, 2*Math.PI); ctx.fill()
          }
        }
      </script>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PoleField">
        export default {
          mounted() {
            this.limit = parseFloat(this.el.dataset.limit)
            this.track = parseFloat(this.el.dataset.track)
            this.ctxs = {}
            this.el.querySelectorAll("canvas[data-arm]").forEach(c => { c.width = 300; c.height = 176; this.ctxs[c.dataset.arm] = c.getContext("2d") })
            this.handleEvent("frame", ({agents}) => { for (const a in agents) this.draw(a, agents[a]) })
            this.handleEvent("reset", () => this.resetAll())
            this.resetAll()
          },
          ink() { return getComputedStyle(this.el).color },
          resetAll() { for (const a in this.ctxs) this.draw(a, {cpos:0, angle:0.0628, status:"balancing"}) },
          color(f) { if (f.status === "crashed") return "#C7583F"; const r = Math.abs(f.angle)/this.limit; if (r >= 0.85) return "#C7583F"; if (r >= 0.5) return "#F2B142"; return "#4E9F6B" },
          draw(arm, f) {
            const ctx = this.ctxs[arm]; if (!ctx) return
            const trackY = 130, poleLen = 72, cartW = 40, cartH = 16, ink = this.ink()
            const px = x => 24 + ((x + this.track) / (2 * this.track)) * 252
            const hx = px(f.cpos), hy = trackY - cartH/2, col = this.color(f)
            ctx.clearRect(0, 0, 300, 176)
            ctx.strokeStyle = ink; ctx.globalAlpha = 0.18; ctx.lineWidth = 2.5
            ctx.beginPath(); ctx.moveTo(18, trackY); ctx.lineTo(282, trackY); ctx.stroke()
            ctx.globalAlpha = 0.55; ctx.fillStyle = ink; ctx.fillRect(hx - cartW/2, trackY - cartH, cartW, cartH); ctx.globalAlpha = 1
            const tx = hx + poleLen*Math.sin(f.angle), ty = hy - poleLen*Math.cos(f.angle)
            ctx.strokeStyle = col; ctx.lineWidth = 5; ctx.lineCap = "round"
            ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(tx, ty); ctx.stroke()
            ctx.fillStyle = col; ctx.beginPath(); ctx.arc(tx, ty, 6, 0, 2*Math.PI); ctx.fill()
          }
        }
      </script>
    </Layouts.app>
    """
  end

  attr :arm, :map, required: true
  attr :frame, :map, required: true

  defp sc_panel(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body p-3 gap-1">
        <h3 class="font-semibold text-sm">{@arm.label}</h3>
        <canvas data-arm={@arm.key} class="w-full h-auto"></canvas>
        <div class={["font-mono text-[11px]", run_color(@frame.status)]}>{sc_text(@frame)}</div>
      </div>
    </div>
    """
  end

  defp sc_text(%{status: :crashed, step: n}), do: "crashed at step #{n}"
  defp sc_text(%{status: :stable}), do: "survived ✓"
  defp sc_text(%{status: :recovering, step: n}), do: "recovering… #{n}"
  defp sc_text(%{step: n}), do: "balancing… #{n}"

  attr :phase, :atom, required: true
  attr :best, :any, required: true
  attr :goal, :integer, required: true

  defp phase_label(assigns) do
    ~H"""
    <span class={["font-mono text-xs", phase_tone(@phase)]}>{phase_msg(@phase, @best, @goal)}</span>
    """
  end

  defp phase_tone(:ready), do: "text-success"
  defp phase_tone(_), do: "text-base-content/60"

  defp phase_msg(:idle, _b, _g), do: "choose a scenario, then evolve"
  defp phase_msg(:evolving, b, g), do: "evolving… best #{b || 0}/#{g}"
  defp phase_msg(:ready, b, g), do: "evolved · best #{b}/#{g} — now run it"
  defp phase_msg(:running, _b, _g), do: "running…"
  defp phase_msg(:done, _b, _g), do: "run finished — evolve or run again"

  attr :frame, :map, required: true
  attr :phase, :atom, required: true
  attr :shift_at, :integer, required: true

  defp run_status(assigns) do
    ~H"""
    <span class={run_color(@frame.status)}>
      {run_text(@frame, @phase)}
    </span>
    """
  end

  defp run_color(:crashed), do: "text-error"
  defp run_color(:stable), do: "text-success"
  defp run_color(_), do: "text-base-content/60"

  defp run_text(_f, :idle), do: "evolve a controller, then run it"
  defp run_text(_f, :ready), do: "ready — press Run the fault"
  defp run_text(%{status: :crashed, step: n}, _), do: "CRASHED — toppled at step #{n}"
  defp run_text(%{status: :stable}, _), do: "STABLE — survived the fault"
  defp run_text(%{status: :recovering, step: n}, _), do: "recovering after the fault… step #{n}"
  defp run_text(%{step: n}, _), do: "balancing… step #{n}"

  attr :curve, :list, required: true
  attr :goal, :integer, required: true

  defp fitness_curve(%{curve: []} = assigns) do
    ~H|<div class="h-[200px] grid place-items-center text-base-content/40 font-mono text-xs">no data yet — press Evolve</div>|
  end

  defp fitness_curve(assigns) do
    pts = Enum.reverse(assigns.curve)
    maxg = pts |> List.last() |> elem(0) |> max(1)
    goal = assigns.goal

    poly =
      Enum.map_join(pts, " ", fn {g, f} ->
        x = 34 + g / maxg * 278
        y = 170 - min(f, goal) / goal * 150
        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)

    assigns = assign(assigns, poly: poly, maxg: maxg)

    ~H"""
    <svg viewBox="0 0 320 200" class="w-full h-auto" role="img" aria-label="Best fitness per generation">
      <line x1="34" y1="170" x2="312" y2="170" stroke="currentColor" stroke-opacity="0.2" />
      <line x1="34" y1="20" x2="34" y2="170" stroke="currentColor" stroke-opacity="0.2" />
      <text x="30" y="24" text-anchor="end" font-family="monospace" font-size="9" fill="currentColor" opacity="0.5">{@goal}</text>
      <text x="30" y="172" text-anchor="end" font-family="monospace" font-size="9" fill="currentColor" opacity="0.5">0</text>
      <polyline fill="none" stroke="#F2B142" stroke-width="2" points={@poly} />
      <text x="312" y="14" text-anchor="end" font-family="monospace" font-size="10" fill="#F2B142">gen {@maxg}</text>
    </svg>
    """
  end
end
