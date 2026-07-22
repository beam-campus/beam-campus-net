defmodule BeamCampusWeb.AdaptationLive do
  @moduledoc """
  Live cart-pole adaptation demo. Three evolved faber-tweann controllers are
  deployed into a hidden motor fault; a server-side timer steps the real
  `BeamCampus.Adaptation` backend and streams each frame to a canvas hook.
  """
  use BeamCampusWeb, :live_view

  alias BeamCampus.Adaptation

  @tick_ms 33

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Post-deployment adaptation",
       arms: Adaptation.arms(),
       shift_at: Adaptation.shift_at(),
       goal: Adaptation.goal(),
       limit: Adaptation.angle_limit(),
       track: Adaptation.track(),
       playing: false
     )
     |> reset_agents()}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    cond do
      socket.assigns.playing ->
        {:noreply, assign(socket, playing: false)}

      all_done?(socket) ->
        {:noreply, socket |> reset_agents() |> start()}

      true ->
        {:noreply, start(socket)}
    end
  end

  def handle_event("restart", _params, socket) do
    {:noreply, socket |> assign(playing: false) |> reset_agents() |> push_event("reset", %{})}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{playing: false}} = socket), do: {:noreply, socket}

  def handle_info(:tick, socket) do
    stepped = Map.new(socket.assigns.agents, fn {arm, a} -> {arm, Adaptation.step(a)} end)
    frames = Map.new(stepped, fn {arm, {f, _}} -> {arm, f} end)
    agents = Map.new(stepped, fn {arm, {_, a}} -> {arm, a} end)
    step = socket.assigns.step + 1
    done = Enum.all?(agents, fn {_, a} -> a.done end) or step >= socket.assigns.goal

    socket =
      socket
      |> assign(agents: agents, frames: frames, step: step, playing: not done)
      |> push_event("frame", %{step: step, agents: frames})

    unless done, do: Process.send_after(self(), :tick, @tick_ms)
    {:noreply, socket}
  end

  defp start(socket) do
    Process.send_after(self(), :tick, @tick_ms)
    assign(socket, playing: true)
  end

  defp reset_agents(socket) do
    agents = Map.new(socket.assigns.arms, fn %{key: k} -> {k, Adaptation.init(k)} end)
    frames = Map.new(agents, fn {k, _} -> {k, initial_frame()} end)
    assign(socket, agents: agents, frames: frames, step: 0)
  end

  defp initial_frame, do: %{cpos: 0.0, angle: 0.0628, step: 0, done: false, status: :balancing, shifted: false}

  defp all_done?(socket), do: Enum.all?(socket.assigns.agents, fn {_, a} -> a.done end)

  # --- render -------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-6 py-16">
        <p class="font-mono text-xs uppercase tracking-[0.22em] text-primary mb-4">
          Faber Neuroevolution · live demo · EXP-046
        </p>
        <h1 class="text-3xl sm:text-4xl font-semibold tracking-tight text-balance mb-4">
          An evolved controller that re-wires itself when the motor fails
        </h1>
        <p class="text-base-content/70 max-w-2xl mb-8">
          Three controllers, all <em>evolved</em> not programmed, balance a windy pole. At step
          <b>{@shift_at}</b> the motor <b>reverses</b> — a hidden fault, unsensed, felt only through the pole's
          response. This runs the real faber-tweann engine live on the server: every frame is a network
          forward pass plus a physics step.
        </p>

        <div class="flex flex-wrap items-center gap-3 mb-8">
          <button class="btn btn-primary" phx-click="toggle">
            {if @playing, do: "❚❚ Pause", else: "▶ Play"}
          </button>
          <button class="btn btn-outline" phx-click="restart">↺ Restart</button>
          <span class="font-mono text-sm text-base-content/60">
            step <b class="text-base-content">{@step}</b> / {@goal}
          </span>
          <span class={[
            "font-mono text-xs px-3 py-1 rounded-full border transition-opacity",
            (@step >= @shift_at && "border-error text-error opacity-100") || "border-base-300 text-base-content/50 opacity-60"
          ]}>
            motor reverses at {@shift_at}
          </span>
        </div>

        <div
          id="pole-field"
          phx-hook=".PoleField"
          data-limit={@limit}
          data-track={@track}
          class="grid gap-5 sm:grid-cols-3"
        >
          <.pole_panel :for={arm <- @arms} arm={arm} frame={@frames[arm.key]} />
        </div>

        <div class="card bg-base-100 border border-base-300 mt-8">
          <div class="card-body">
            <h2 class="font-mono text-xs uppercase tracking-[0.1em] text-base-content/60">What you are watching</h2>
            <p class="text-sm">
              All three agents were evolved with separable CMA-ES. A constant wind pushes the cart, so the
              controller must apply continuous force — which is what makes a motor reversal <em>matter</em> (a
              settled regulator that applies no force would not even notice). The <b>fixed</b> policy's
              corrections invert at the fault and it topples. The <b>adaptive</b> policy derives an error signal
              from the pole's tilt and lets it gate changes to its own weights (the three-factor rule
              <span class="text-base-content/60">dw = M·η·(A·pre·post + …)</span>), re-wiring to recover.
            </p>
            <p class="text-sm text-base-content/60">
              Honest framing: adaptation recovers reliably (5 of 5 evolved runs); a fixed controller is
              unreliable rather than doomed, and recurrence alone (CfC) is not enough. The fixed run shown was
              trained only on the normal regime and deployed into the fault — the real post-deployment case.
            </p>
          </div>
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PoleField">
        export default {
          mounted() {
            this.limit = parseFloat(this.el.dataset.limit)
            this.track = parseFloat(this.el.dataset.track)
            this.ctxs = {}
            this.el.querySelectorAll("canvas[data-arm]").forEach(c => {
              c.width = 300; c.height = 200
              this.ctxs[c.dataset.arm] = c.getContext("2d")
            })
            this.handleEvent("frame", ({agents}) => { for (const a in agents) this.draw(a, agents[a]) })
            this.handleEvent("reset", () => this.resetAll())
            this.resetAll()
          },
          ink() { return getComputedStyle(this.el).color },
          resetAll() { for (const a in this.ctxs) this.draw(a, {cpos:0, angle:0.0628, done:false, status:"balancing"}) },
          poleColor(f) {
            if (f.status === "crashed") return "#C7583F"
            const r = Math.abs(f.angle) / this.limit
            if (r >= 0.85) return "#C7583F"
            if (r >= 0.5) return "#F2B142"
            return "#4E9F6B"
          },
          draw(arm, f) {
            const ctx = this.ctxs[arm]; if (!ctx) return
            const W = 300, H = 200, trackY = 150, poleLen = 80, cartW = 42, cartH = 18
            const ink = this.ink()
            const px = x => 24 + ((x + this.track) / (2 * this.track)) * 252
            const hx = px(f.cpos), hy = trackY - cartH / 2
            const col = this.poleColor(f)
            ctx.clearRect(0, 0, W, H)
            // track
            ctx.strokeStyle = ink; ctx.globalAlpha = 0.18; ctx.lineWidth = 3
            ctx.beginPath(); ctx.moveTo(18, trackY); ctx.lineTo(282, trackY); ctx.stroke()
            ctx.globalAlpha = 1
            // angle-limit guides
            ctx.strokeStyle = ink; ctx.globalAlpha = 0.14; ctx.lineWidth = 1; ctx.setLineDash([3,3])
            for (const s of [-1,1]) {
              ctx.beginPath(); ctx.moveTo(hx, hy)
              ctx.lineTo(hx + poleLen*Math.sin(s*this.limit), hy - poleLen*Math.cos(s*this.limit)); ctx.stroke()
            }
            ctx.setLineDash([]); ctx.globalAlpha = 1
            // cart
            ctx.fillStyle = ink; ctx.globalAlpha = 0.55
            this.roundRect(ctx, hx - cartW/2, trackY - cartH, cartW, cartH, 4); ctx.fill()
            ctx.globalAlpha = 1
            // pole
            const tx = hx + poleLen*Math.sin(f.angle), ty = hy - poleLen*Math.cos(f.angle)
            ctx.strokeStyle = col; ctx.lineWidth = 5; ctx.lineCap = "round"
            ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(tx, ty); ctx.stroke()
            ctx.fillStyle = col; ctx.beginPath(); ctx.arc(tx, ty, 6, 0, 2*Math.PI); ctx.fill()
            ctx.fillStyle = ink; ctx.beginPath(); ctx.arc(hx, hy, 3.5, 0, 2*Math.PI); ctx.fill()
          },
          roundRect(ctx, x, y, w, h, r) {
            ctx.beginPath(); ctx.moveTo(x+r, y)
            ctx.arcTo(x+w, y, x+w, y+h, r); ctx.arcTo(x+w, y+h, x, y+h, r)
            ctx.arcTo(x, y+h, x, y, r); ctx.arcTo(x, y, x+w, y, r); ctx.closePath()
          }
        }
      </script>
    </Layouts.app>
    """
  end

  attr :arm, :map, required: true
  attr :frame, :map, required: true

  defp pole_panel(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body p-4">
        <h3 class="font-semibold text-sm">{@arm.label}</h3>
        <p class="font-mono text-[11px] text-base-content/50 -mt-1">{@arm.sub}</p>
        <canvas data-arm={@arm.key} class="w-full h-auto my-1"></canvas>
        <div class="font-mono text-xs">
          <.status_badge frame={@frame} />
        </div>
      </div>
    </div>
    """
  end

  attr :frame, :map, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-2",
      status_color(@frame.status)
    ]}>
      <span class={["w-2 h-2 rounded-full", status_dot(@frame.status)]}></span>
      {status_text(@frame)}
    </span>
    """
  end

  defp status_color(:crashed), do: "text-error"
  defp status_color(:stable), do: "text-success"
  defp status_color(_), do: "text-base-content/60"

  defp status_dot(:crashed), do: "bg-error"
  defp status_dot(:stable), do: "bg-success"
  defp status_dot(_), do: "bg-base-content/40"

  defp status_text(%{status: :crashed, step: n}), do: "CRASHED — toppled at step #{n}"
  defp status_text(%{status: :stable}), do: "STABLE — survived all steps"
  defp status_text(%{status: :recovering, step: n}), do: "recovering… step #{n}"
  defp status_text(%{status: :balancing, step: n}), do: "balancing… step #{n}"
  end
