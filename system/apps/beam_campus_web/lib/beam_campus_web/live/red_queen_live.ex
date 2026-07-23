defmodule BeamCampusWeb.RedQueenLive do
  @moduledoc """
  Workbench demo: the Red Queen, numerically (faber insight 053). A COEVOLUTION-METHODOLOGY
  demonstrator, explicitly NOT neuroevolution -- players are numbers, so true progress is a
  value you can read directly, and co-fitness's blindness is undeniable. The trait escalates
  while the champion's score against its current rivals stays flat. Runs live (arithmetic).
  """
  use BeamCampusWeb, :live_view

  alias BeamCampus.RedQueen

  @tick_ms 90
  @gens 90

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "The Red Queen (numerical)", traj: nil, idx: 0, playing: false)}
  end

  @impl true
  def handle_event("play", _p, socket) do
    cond do
      socket.assigns.playing -> {:noreply, assign(socket, playing: false)}
      socket.assigns.traj && socket.assigns.idx < length(socket.assigns.traj) -> {:noreply, start(socket)}
      true -> {:noreply, socket |> assign(traj: RedQueen.run(@gens), idx: 0) |> start()}
    end
  end

  def handle_event("restart", _p, socket) do
    {:noreply, assign(socket, traj: RedQueen.run(@gens), idx: 0, playing: false)}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{playing: false}} = socket), do: {:noreply, socket}

  def handle_info(:tick, socket) do
    idx = socket.assigns.idx + 1
    playing = idx < length(socket.assigns.traj)
    if playing, do: Process.send_after(self(), :tick, @tick_ms)
    {:noreply, assign(socket, idx: idx, playing: playing)}
  end

  defp start(socket) do
    Process.send_after(self(), :tick, @tick_ms)
    assign(socket, playing: true)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-4xl px-6 py-16">
        <.link navigate={~p"/research/workbench"} class="link link-hover font-mono text-xs text-base-content/50">
          &larr; Workbench
        </.link>
        <p class="font-mono text-xs uppercase tracking-[0.22em] text-primary mt-4 mb-4">
          Faber · coevolution methodology · insight 053
        </p>
        <h1 class="text-3xl sm:text-4xl font-semibold tracking-tight text-balance mb-4">
          The Red Queen: running to stay in place
        </h1>

        <div class="alert bg-base-200 border border-base-300 text-sm mb-6">
          <span>
            <b>This is not neuroevolution.</b> The players here are plain numbers, not networks,
            on purpose: it isolates the <b>coevolution measurement trap</b> where the true progress
            is a value you can read directly. It is the calibration of the ruler we use on the real
            engine next door. For coevolving networks, see the
            <.link navigate={~p"/research/workbench/neural-coevolution"} class="link">neural coevolution demo</.link>.
          </span>
        </div>

        <p class="text-base-content/70 max-w-2xl mb-6">
          A population competes with itself on a "bigger tends to win" game. Selection pushes the
          trait up without bound (real, observable progress). Yet the best individual's score against
          its <em>current</em> rivals never improves: it is always about as good relative to its peers,
          because they climb with it. Watch the two lines.
        </p>

        <div class="flex items-center gap-3 mb-4">
          <button class="btn btn-sm btn-primary" phx-click="play">
            {if @playing, do: "❚❚ Pause", else: "▶ Play"}
          </button>
          <button class="btn btn-sm btn-outline" phx-click="restart">↺ Restart</button>
          <span :if={@traj} class="font-mono text-xs text-base-content/50">
            generation {min(@idx, length(@traj) - 1)} / {length(@traj) - 1}
          </span>
        </div>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body p-4">
            <.chart traj={@traj} idx={@idx} />
          </div>
        </div>

        <div class="card bg-base-100 border border-base-300 mt-6">
          <div class="card-body gap-3">
            <p class="text-sm text-base-content/70">
              The green trait climbs; the terracotta score stays flat. If you measured progress by
              "how am I doing against my current opponents", you would conclude nothing is happening.
              That is the Red Queen, and it is why coevolution must be measured against a
              <b>fixed benchmark</b>, not the moving opponent.
            </p>
            <div class="flex flex-wrap gap-x-6 gap-y-2 font-mono text-xs text-base-content/50 pt-1">
              <a href="https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master/plans/CHARTER_P7_COEVOLUTION.md" class="link link-hover" target="_blank" rel="noreferrer">Programme 7 charter</a>
              <a href="https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master/insights/INDEX.md" class="link link-hover" target="_blank" rel="noreferrer">signed insight 053</a>
              <.link navigate={~p"/research/notes/running-to-stay-in-place"} class="link link-hover">the plain-language note</.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :traj, :any, required: true
  attr :idx, :integer, required: true

  defp chart(%{traj: nil} = assigns) do
    ~H|<div class="h-[300px] grid place-items-center text-base-content/40 font-mono text-xs">press Play to run the coevolution</div>|
  end

  defp chart(assigns) do
    shown = Enum.take(assigns.traj, max(1, assigns.idx + 1))
    n = length(assigns.traj)
    tmax = assigns.traj |> Enum.map(& &1.trait) |> Enum.max()
    tmin = BeamCampus.RedQueen.x0()
    trait_pts = Enum.map_join(shown, " ", fn f -> "#{gx(f.gen, n)},#{ty(f.trait, tmin, tmax)}" end)
    cofit_pts = Enum.map_join(shown, " ", fn f -> "#{gx(f.gen, n)},#{cy(f.cofit)}" end)
    assigns = assign(assigns, trait_pts: trait_pts, cofit_pts: cofit_pts, tmax: tmax)

    ~H"""
    <svg viewBox="0 0 560 300" class="w-full h-auto" role="img" aria-label="The champion's trait rising while its score against current rivals stays flat.">
      <text x="86" y="34" text-anchor="end" font-family="ui-monospace, monospace" font-size="10" fill="#4E9F6B" opacity="0.8">{Float.round(@tmax, 0)}</text>
      <text x="86" y="120" text-anchor="end" font-family="ui-monospace, monospace" font-size="10" fill="#4E9F6B" opacity="0.6">trait</text>
      <line x1="92" y1="128" x2="524" y2="128" stroke="currentColor" stroke-opacity="0.12" />
      <polyline points={@trait_pts} fill="none" stroke="#4E9F6B" stroke-width="2.5" />
      <text x="86" y="176" text-anchor="end" font-family="ui-monospace, monospace" font-size="10" fill="#C7583F" opacity="0.7">100%</text>
      <text x="86" y="262" text-anchor="end" font-family="ui-monospace, monospace" font-size="10" fill="#C7583F" opacity="0.7">0%</text>
      <text x="30" y="220" font-family="ui-monospace, monospace" font-size="10" fill="#C7583F" opacity="0.7" transform="rotate(-90 30 220)" text-anchor="middle">score vs rivals</text>
      <line x1="92" y1="266" x2="524" y2="266" stroke="currentColor" stroke-opacity="0.2" />
      <line x1="92" y1="216" x2="524" y2="216" stroke="#C7583F" stroke-opacity="0.15" stroke-dasharray="5 4" />
      <polyline points={@cofit_pts} fill="none" stroke="#C7583F" stroke-width="2.5" />
      <text x="298" y="292" text-anchor="middle" font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.5">generations &rarr;</text>
    </svg>
    """
  end

  # trait strip occupies y in [40, 128]; cofit strip y in [166, 266].
  defp gx(gen, n), do: Float.round(92 + gen / max(1, n - 1) * 432, 1)
  defp ty(v, lo, hi), do: Float.round(128 - (v - lo) / max(1.0, hi - lo) * 88, 1)
  defp cy(v), do: Float.round(266 - v * 100, 1)
end
