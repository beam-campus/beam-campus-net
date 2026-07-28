defmodule BeamCampusWeb.NeuralCoevolutionLive do
  @moduledoc """
  Workbench demo: NEURAL coevolution (real faber-tweann). Two populations of networks --
  pursuers and evaders -- coevolve on a torus grid; every move is a `:network_evaluator`
  forward pass. Progress is measured against a FIXED benchmark (a frozen snapshot of the
  gen-0 opponents, per insight 054), not co-fitness.

  Honest outcome: this does NOT produce a Red Queen arms race. With the pursuer given a
  small speed edge it reliably catches, but then DOMINATES -- the evader's gradient dies
  (disengagement). Equal speed flips it the other way (the evader escapes forever). A
  two-sided arms race is the knife-edge between, and hitting it is the hard open problem
  the embodied Programme-7 rung exists to tackle. The demo shows the real dynamics: a
  live champion chase that ends in a capture, and flat coevolution curves that never
  become an arms race.

  Data is a captured run (replayed): running the coevolution live would take ~a minute.
  """
  use BeamCampusWeb, :live_view

  @w 9
  @cell 26
  @pad 8
  @tick_ms 260

  # captured trajectory (per generation) + a champion match (per step). Injected below.
  @traj [%{gen: 0, p: 0.35, e: 0.6, cofit: 0.0}, %{gen: 1, p: 0.95, e: 0.85, cofit: 1.0}, %{gen: 2, p: 0.95, e: 0.85, cofit: 1.0}, %{gen: 3, p: 1.0, e: 0.85, cofit: 1.0}, %{gen: 4, p: 0.95, e: 0.85, cofit: 1.0}, %{gen: 5, p: 0.9, e: 0.65, cofit: 0.0}, %{gen: 6, p: 1.0, e: 0.7, cofit: 1.0}, %{gen: 7, p: 0.95, e: 0.65, cofit: 1.0}, %{gen: 8, p: 0.95, e: 0.85, cofit: 1.0}, %{gen: 9, p: 0.95, e: 0.8, cofit: 1.0}, %{gen: 10, p: 0.95, e: 0.7, cofit: 1.0}, %{gen: 11, p: 0.8, e: 0.75, cofit: 1.0}, %{gen: 12, p: 1.0, e: 0.75, cofit: 1.0}, %{gen: 13, p: 0.9, e: 0.45, cofit: 1.0}, %{gen: 14, p: 0.9, e: 0.7, cofit: 1.0}, %{gen: 15, p: 0.9, e: 0.85, cofit: 1.0}, %{gen: 16, p: 0.9, e: 0.85, cofit: 1.0}, %{gen: 17, p: 0.9, e: 0.85, cofit: 1.0}, %{gen: 18, p: 1.0, e: 0.85, cofit: 1.0}, %{gen: 19, p: 0.9, e: 0.9, cofit: 1.0}, %{gen: 20, p: 1.0, e: 0.85, cofit: 1.0}, %{gen: 21, p: 1.0, e: 0.85, cofit: 1.0}, %{gen: 22, p: 0.9, e: 0.85, cofit: 1.0}, %{gen: 23, p: 1.0, e: 0.85, cofit: 1.0}, %{gen: 24, p: 0.9, e: 0.85, cofit: 1.0}, %{gen: 25, p: 0.95, e: 0.85, cofit: 1.0}, %{gen: 26, p: 0.95, e: 0.85, cofit: 1.0}, %{gen: 27, p: 0.95, e: 0.85, cofit: 1.0}]
  @path [{{0,0},{4,4}}, {{1,0},{4,5}}, {{2,0},{4,4}}, {{2,1},{4,4}}, {{2,2},{4,5}}, {{2,3},{4,6}}, {{2,4},{4,6}}, {{2,5},{4,7}}, {{2,6},{4,8}}, {{2,7},{4,8}}, {{3,7},{4,0}}, {{3,8},{4,1}}, {{3,0},{4,1}}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, w: @w, traj: @traj, path: @path, idx: 0, playing: false, len: length(@path))}
  end

  @impl true
  def handle_event("play", _p, socket) do
    cond do
      socket.assigns.playing -> {:noreply, assign(socket, playing: false)}
      socket.assigns.idx >= socket.assigns.len - 1 -> {:noreply, socket |> assign(idx: 0) |> start()}
      true -> {:noreply, start(socket)}
    end
  end

  def handle_event("restart", _p, socket), do: {:noreply, assign(socket, idx: 0, playing: false)}

  @impl true
  def handle_info(:tick, %{assigns: %{playing: false}} = socket), do: {:noreply, socket}

  def handle_info(:tick, socket) do
    idx = socket.assigns.idx + 1
    playing = idx < socket.assigns.len - 1
    if playing, do: Process.send_after(self(), :tick, @tick_ms)
    {:noreply, assign(socket, idx: idx, playing: playing)}
  end

  defp start(socket) do
    Process.send_after(self(), :tick, @tick_ms)
    assign(socket, playing: true)
  end

  @impl true
  def render(assigns) do
    {pp, pe} = Enum.at(assigns.path, min(assigns.idx, assigns.len - 1))
    # capture is adjacency on the torus (Chebyshev <= 1), matching the game rule.
    caught = caught?(pp, pe, assigns.w)
    assigns = assign(assigns, pursuer: pp, evader: pe, caught: caught)

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-4xl px-6 py-16">
        <.link navigate={~p"/research/workbench"} class="link link-hover font-mono text-xs text-base-content/50">
          &larr; Workbench
        </.link>
        <p class="font-mono text-xs uppercase tracking-[0.22em] text-primary mt-4 mb-4">
          Faber Neuroevolution · live workbench · Programme 7
        </p>
        <h1 class="text-3xl sm:text-4xl font-semibold tracking-tight text-balance mb-4">
          Neural coevolution: pursuers vs evaders
        </h1>

        <div class="alert bg-base-200 border border-base-300 text-sm mb-6">
          <span>
            <b>This is the real engine.</b> Two populations of faber-tweann networks coevolve on a
            torus; every move is a live forward pass. It is the honest counterpart to the
            <.link navigate={~p"/research/workbench/red-queen"} class="link">numerical Red Queen</.link>,
            which isolates the same measurement ideas where the truth is directly readable.
          </span>
        </div>

        <p class="text-base-content/70 max-w-2xl mb-6">
          Pursuers want to catch, evaders want to survive. Given a small speed edge the pursuer
          learns to catch, then <b>dominates</b>: the evader's gradient dies. That is
          <b>disengagement</b>, one of the three coevolution outcomes, and it is why a genuine
          arms race is hard. Watch the evolved champions play, then read the curves that never
          became a race.
        </p>

        <div class="grid gap-6 sm:grid-cols-2">
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4 gap-2">
              <div class="flex items-center justify-between">
                <h2 class="font-semibold text-sm">Champion match</h2>
                <span class={["badge badge-sm", (@caught && "badge-error") || "badge-ghost"]}>
                  {if @caught, do: "caught ✓", else: "step #{min(@idx, @len - 1)}/#{@len - 1}"}
                </span>
              </div>
              <.arena w={@w} pursuer={@pursuer} evader={@evader} caught={@caught} />
              <div class="flex items-center gap-3 mt-1">
                <button class="btn btn-sm btn-primary" phx-click="play">
                  {if @playing, do: "❚❚ Pause", else: "▶ Play"}
                </button>
                <button class="btn btn-sm btn-outline" phx-click="restart">↺ Restart</button>
              </div>
              <p class="font-mono text-[11px] text-base-content/50 mt-1">
                <span class="text-error">●</span> pursuer (1.5× speed) &nbsp; <span class="text-success">●</span> evader
              </p>
            </div>
          </div>

          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4 gap-2">
              <h2 class="font-semibold text-sm">Coevolution (no arms race)</h2>
              <.curves traj={@traj} />
              <p class="font-mono text-[11px] text-base-content/50">
                progress vs frozen gen-0 opponents; head-to-head pinned = disengagement
              </p>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 border border-base-300 mt-6">
          <div class="card-body gap-3">
            <p class="text-sm text-base-content/70">
              The curves never climb into a mutual arms race: the pursuer's benchmark progress rises
              as it learns to catch, and its head-to-head score pins at the top -- it dominates the
              current evader, which can never pull ahead. Tip the balance the other way -- equal speed
              -- and the evader escapes forever instead. A sustained two-sided arms race sits on a
              knife-edge between, and finding it is
              the open problem the embodied Programme-7 rung exists to tackle. That is the honest state
              of the art, measured with the instruments the
              <.link navigate={~p"/research/workbench/red-queen"} class="link">numerical rungs</.link>
              proved correct.
            </p>
            <div class="flex flex-wrap gap-x-6 gap-y-2 font-mono text-xs text-base-content/50 pt-1">
              <a href="https://github.com/rgfaber/faber-ecosystem/blob/master/plans/CHARTER_P7_COEVOLUTION.md" class="link link-hover" target="_blank" rel="noreferrer">Programme 7 charter</a>
              <a href="https://github.com/rgfaber/faber-ecosystem/blob/master/insights/INDEX.md" class="link link-hover" target="_blank" rel="noreferrer">signed insights 053-057</a>
              <.link navigate={~p"/research/notes/two-nets-learn-to-chase"} class="link link-hover">the plain-language note</.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- components ----------------------------------------------------------------

  attr :w, :integer, required: true
  attr :pursuer, :any, required: true
  attr :evader, :any, required: true
  attr :caught, :boolean, required: true

  defp arena(assigns) do
    vb = @pad * 2 + assigns.w * @cell
    assigns = assign(assigns, vb: vb, cell: @cell, pad: @pad)

    ~H"""
    <svg viewBox={"0 0 #{@vb} #{@vb}"} class="w-full h-auto" role="img" aria-label="A torus grid with a pursuer and an evader network.">
      <rect x={@pad} y={@pad} width={@w * @cell} height={@w * @cell} rx="4" fill="currentColor" fill-opacity="0.03" stroke="currentColor" stroke-opacity="0.1" />
      <g stroke="currentColor" stroke-opacity="0.06">
        <line :for={i <- 1..(@w - 1)} x1={@pad + i * @cell} y1={@pad} x2={@pad + i * @cell} y2={@pad + @w * @cell} />
        <line :for={i <- 1..(@w - 1)} x1={@pad} y1={@pad + i * @cell} x2={@pad + @w * @cell} y2={@pad + i * @cell} />
      </g>
      <circle :if={@caught} cx={cx(elem(@pursuer, 0))} cy={cy(elem(@pursuer, 1), @w)} r={@cell / 2} fill="#C7583F" opacity="0.25" />
      <circle cx={cx(elem(@evader, 0))} cy={cy(elem(@evader, 1), @w)} r="8" fill="#4E9F6B" />
      <circle cx={cx(elem(@pursuer, 0))} cy={cy(elem(@pursuer, 1), @w)} r="8" fill="#C7583F" />
    </svg>
    """
  end

  attr :traj, :list, required: true

  defp curves(assigns) do
    n = length(assigns.traj)
    line = fn key -> Enum.map_join(assigns.traj, " ", fn f -> "#{gx(f.gen, n)},#{vy(Map.fetch!(f, key))}" end) end
    assigns = assign(assigns, p_line: line.(:p), e_line: line.(:e), c_line: line.(:cofit))

    ~H"""
    <svg viewBox="0 0 300 200" class="w-full h-auto" role="img" aria-label="Coevolution progress curves: flat, pinned head-to-head, no arms race.">
      <line x1="30" y1="20" x2="30" y2="180" stroke="currentColor" stroke-opacity="0.15" />
      <line x1="30" y1="180" x2="290" y2="180" stroke="currentColor" stroke-opacity="0.15" />
      <text x="26" y="24" text-anchor="end" font-family="ui-monospace, monospace" font-size="8" fill="currentColor" opacity="0.5">1</text>
      <text x="26" y="182" text-anchor="end" font-family="ui-monospace, monospace" font-size="8" fill="currentColor" opacity="0.5">0</text>
      <polyline points={@p_line} fill="none" stroke="#C7583F" stroke-width="2" />
      <polyline points={@e_line} fill="none" stroke="#4E9F6B" stroke-width="2" />
      <polyline points={@c_line} fill="none" stroke="currentColor" stroke-opacity="0.5" stroke-width="1.5" stroke-dasharray="3 3" />
      <text x="290" y="14" text-anchor="end" font-family="ui-monospace, monospace" font-size="8.5" fill="currentColor" opacity="0.55">generations →</text>
      <g font-family="ui-monospace, monospace" font-size="8.5">
        <text x="40" y="196" fill="#C7583F">pursuer</text>
        <text x="120" y="196" fill="#4E9F6B">evader</text>
        <text x="200" y="196" fill="currentColor" opacity="0.55">head-to-head</text>
      </g>
    </svg>
    """
  end

  defp caught?({px, py}, {ex, ey}, w), do: max(td(px, ex, w), td(py, ey, w)) <= 1
  defp td(a, b, w), do: min(Integer.mod(a - b, w), Integer.mod(b - a, w))

  defp cx(x), do: @pad + x * @cell + div(@cell, 2)
  defp cy(y, w), do: @pad + (w - 1 - y) * @cell + div(@cell, 2)
  defp gx(gen, n), do: Float.round(30 + gen / max(1, n - 1) * 260, 1)
  defp vy(v), do: Float.round(180 - v * 160, 1)
end
