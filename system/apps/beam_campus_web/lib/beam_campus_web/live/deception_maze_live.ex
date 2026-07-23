defmodule BeamCampusWeb.DeceptionMazeLive do
  @moduledoc """
  Live workbench experiment for faber insight 051: novelty search solves a deceptive
  maze where goal-chasing is trapped. A showcase animates two pre-evolved champions
  side by side (goal-chaser vs novelty-seeker) on the deceptive maze, with the
  non-deceptive twin as the control; a live section evolves either objective or
  novelty search on the real faber-tweann engine and watches the champion path change
  generation by generation. Every rollout and evolution step is `BeamCampus.DeceptionMaze`.
  """
  use BeamCampusWeb, :live_view

  alias BeamCampus.DeceptionMaze, as: Maze

  @cell 22
  @pad 10
  @tick_ms 140
  @gen_default 45
  @gen_min 10
  @gen_max 90
  @gen_step 5
  @replay_ms 6000

  @impl true
  def mount(_params, _session, socket) do
    {w, h} = Maze.dims()
    obj = Maze.run(:objective, :deceptive)
    nov = Maze.run(:novelty, :deceptive)
    twin = Maze.run(:objective_twin, :twin)

    {:ok,
     assign(socket,
       page_title: "Deceptive maze — novelty vs objective",
       w: w,
       h: h,
       start: Maze.start_cell(),
       goal: Maze.goal_cell(),
       walls_d: Maze.wall_cells(:deceptive),
       walls_n: Maze.wall_cells(:twin),
       obj_path: obj.path,
       nov_path: nov.path,
       twin_path: twin.path,
       # showcase animation
       sc_len: max(effective_len(obj.path), effective_len(nov.path)),
       sc_idx: 0,
       sc_playing: false,
       # live evolve
       mode: :novelty,
       generations: @gen_default,
       gen_min: @gen_min,
       gen_max: @gen_max,
       gen_step: @gen_step,
       phase: :idle,
       frame: nil,
       frames: [],
       play_idx: 0,
       play_tick: @tick_ms,
       task: nil
     )}
  end

  # --- showcase controls --------------------------------------------------------

  @impl true
  def handle_event("sc_toggle", _p, socket) do
    cond do
      socket.assigns.sc_playing -> {:noreply, assign(socket, sc_playing: false)}
      socket.assigns.sc_idx >= socket.assigns.sc_len -> {:noreply, socket |> assign(sc_idx: 0) |> sc_start()}
      true -> {:noreply, sc_start(socket)}
    end
  end

  def handle_event("sc_restart", _p, socket), do: {:noreply, assign(socket, sc_playing: false, sc_idx: 0)}

  # --- live evolve controls -----------------------------------------------------

  def handle_event("mode", %{"mode" => m}, socket) do
    {:noreply, assign(socket, mode: String.to_existing_atom(m), phase: :idle, frame: nil)}
  end

  def handle_event("gens", %{"generations" => g}, socket) do
    {:noreply, assign(socket, generations: clamp_gens(g))}
  end

  def handle_event("mevolve", _p, socket) do
    mode = socket.assigns.mode
    gens = socket.assigns.generations

    # Collect one champion frame per generation, then replay them on a tick so the
    # evolution is watchable rather than a burst of diffs.
    task =
      Task.async(fn ->
        me = self()
        Maze.evolve(mode, Maze.maze(:deceptive), gens, fn gen, champ -> send(me, {:f, frame(gen, champ)}) end)
        collect(gens + 1, [])
      end)

    {:noreply, assign(socket, phase: :evolving, frame: nil, frames: [], play_idx: 0, task: task)}
  end

  # --- animation + evolution messages -------------------------------------------

  @impl true
  def handle_info(:sc_tick, %{assigns: %{sc_playing: false}} = socket), do: {:noreply, socket}

  def handle_info(:sc_tick, socket) do
    idx = socket.assigns.sc_idx + 1
    playing = idx < socket.assigns.sc_len
    if playing, do: Process.send_after(self(), :sc_tick, @tick_ms)
    {:noreply, assign(socket, sc_idx: idx, sc_playing: playing)}
  end

  def handle_info({ref, frames}, %{assigns: %{task: %Task{ref: ref}}} = socket) do
    Process.demonitor(ref, [:flush])
    tick = replay_tick(length(frames))
    Process.send_after(self(), :mtick, tick)
    {:noreply, assign(socket, phase: :playing, frames: frames, play_idx: 0, frame: List.first(frames), play_tick: tick, task: nil)}
  end

  def handle_info(:mtick, %{assigns: %{phase: :playing}} = socket) do
    idx = socket.assigns.play_idx + 1
    frames = socket.assigns.frames

    cond do
      idx < length(frames) ->
        Process.send_after(self(), :mtick, socket.assigns.play_tick)
        {:noreply, assign(socket, play_idx: idx, frame: Enum.at(frames, idx))}

      true ->
        {:noreply, assign(socket, phase: :done)}
    end
  end

  def handle_info(:mtick, socket), do: {:noreply, socket}

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}

  # --- helpers ------------------------------------------------------------------

  defp sc_start(socket) do
    Process.send_after(self(), :sc_tick, @tick_ms)
    assign(socket, sc_playing: true)
  end

  defp frame(gen, champ), do: %{gen: gen, path: champ.path, solved: champ.solved, close: champ.close}

  # Snap a slider value into range and onto the step grid.
  defp clamp_gens(g), do: g |> to_string() |> Integer.parse() |> snap_gens()
  defp snap_gens(:error), do: @gen_default
  defp snap_gens({v, _}), do: v |> max(@gen_min) |> min(@gen_max) |> div(@gen_step) |> Kernel.*(@gen_step)

  # Pace the whole replay to ~@replay_ms regardless of generation count (clamped so a
  # short run is not a strobe and a long one is not a slideshow).
  defp replay_tick(frames), do: (@replay_ms / max(1, frames)) |> round() |> max(45) |> min(200)

  defp collect(0, acc), do: Enum.reverse(acc)
  defp collect(n, acc) do
    receive do
      {:f, f} -> collect(n - 1, [f | acc])
    end
  end

  # Trim trailing repeats (a trapped agent sits on one cell) so the animation length
  # is the real distance travelled, not the full step budget.
  defp effective_len(path), do: length(dedup_trailing(path))

  defp dedup_trailing([]), do: []

  defp dedup_trailing(path) do
    [last | _] = rev = Enum.reverse(path)
    rev |> Enum.drop_while(&(&1 == last)) |> then(&Enum.reverse([last | &1]))
  end

  # --- render -------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-4xl px-6 py-16">
        <.link navigate={~p"/research/workbench"} class="link link-hover font-mono text-xs text-base-content/50">
          &larr; Workbench
        </.link>
        <p class="font-mono text-xs uppercase tracking-[0.22em] text-primary mt-4 mb-4">
          Faber Neuroevolution · live workbench · EXP-051
        </p>
        <h1 class="text-3xl sm:text-4xl font-semibold tracking-tight text-balance mb-4">
          Abandoning the objective: escaping a deceptive maze
        </h1>
        <p class="text-base-content/70 max-w-2xl mb-8">
          Same start, same goal, same network. One search is rewarded for getting <b>closer to the goal</b>;
          the other for reaching <b>new places</b>, ignoring the goal entirely. On a maze built as a trap —
          the way through first leads <em>away</em> — only the second gets out. Every move here is the real
          faber-tweann engine on the server.
        </p>

        <section class="mb-12">
          <div class="flex items-center gap-3 mb-4">
            <button class="btn btn-sm btn-primary" phx-click="sc_toggle">
              {if @sc_playing, do: "❚❚ Pause", else: "▶ Play"}
            </button>
            <button class="btn btn-sm btn-outline" phx-click="sc_restart">↺ Restart</button>
            <span class="font-mono text-xs text-base-content/50">step {min(@sc_idx, @sc_len)} / {@sc_len}</span>
          </div>

          <div class="grid gap-4 sm:grid-cols-2">
            <.panel title="Chasing the goal" sub="reward = get closer to G" accent="objective" solved={false}>
              <.maze_view
                w={@w} h={@h} walls={@walls_d} start={@start} goal={@goal}
                {trail_agent(@obj_path, @sc_idx)} accent="objective"
              />
            </.panel>
            <.panel title="Seeking novelty" sub="reward = reach new places" accent="novelty" solved={reached?(@nov_path, @sc_idx, @goal)}>
              <.maze_view
                w={@w} h={@h} walls={@walls_d} start={@start} goal={@goal}
                {trail_agent(@nov_path, @sc_idx)} accent="novelty"
              />
            </.panel>
          </div>
          <p class="text-sm text-base-content/60 mt-3">
            Left, the goal-chaser climbs straight at the goal and jams against the wall one cell short — the
            cul-de-sac its own reward walked it into. Right, the novelty-seeker heads <em>away</em>, around the
            far side, through the distant gap, and reaches the goal.
          </p>
        </section>

        <section class="mb-12">
          <h2 class="text-lg font-semibold mb-1">The control: the same goal-chaser, on the twin maze</h2>
          <p class="text-sm text-base-content/60 mb-4">
            Identical maze, but the wall's gap is moved onto the greedy route. Now chasing the goal works — it
            solves in {length(@twin_path) - 1} steps. So it is the <em>trap</em> that stops it on the left, not the maze being hard.
          </p>
          <div class="max-w-xs">
            <.panel title="Goal-chaser · twin maze" sub="gap on the greedy route" accent="novelty" solved={true}>
              <.maze_view
                w={@w} h={@h} walls={@walls_n} start={@start} goal={@goal}
                trail={@twin_path} agent={List.last(@twin_path)} accent="novelty"
              />
            </.panel>
          </div>
        </section>

        <section class="mb-10">
          <h2 class="text-lg font-semibold mb-1">Now evolve it live</h2>
          <p class="text-sm text-base-content/60 mb-4">
            Run the real (μ+λ) evolution on the deceptive maze and watch the best-so-far path change each
            generation. Chase the goal and it converges into the cul-de-sac; seek novelty and it works its way
            around to the goal.
          </p>

          <div class="card bg-base-100 border border-base-300">
            <div class="card-body gap-5">
              <div class="flex flex-wrap items-center gap-3">
                <div class="flex gap-2">
                  <button phx-click="mode" phx-value-mode="objective" class={["btn btn-sm", (@mode == :objective && "btn-primary") || "btn-outline"]}>Chase the goal</button>
                  <button phx-click="mode" phx-value-mode="novelty" class={["btn btn-sm", (@mode == :novelty && "btn-primary") || "btn-outline"]}>Seek novelty</button>
                </div>
                <button phx-click="mevolve" disabled={@phase in [:evolving, :playing]} class="btn btn-secondary btn-sm">
                  {if @phase in [:evolving, :playing], do: "Evolving…", else: "⚙ Evolve"}
                </button>
                <.evolve_status phase={@phase} frame={@frame} goal={@goal} />
              </div>

              <form phx-change="gens" class="max-w-sm">
                <label class="block">
                  <span class="font-mono text-xs uppercase tracking-wide text-base-content/50">
                    Budget · {@generations} generations
                  </span>
                  <input
                    type="range" name="generations"
                    min={@gen_min} max={@gen_max} step={@gen_step} value={@generations}
                    disabled={@phase in [:evolving, :playing]}
                    class="range range-secondary range-sm mt-2"
                  />
                </label>
                <p class="font-mono text-[11px] text-base-content/40 mt-1">
                  more budget gives novelty more room to work around the trap
                </p>
              </form>

              <div class="max-w-xs">
                <.panel title={mode_title(@mode)} sub="deceptive maze · live" accent={to_string(@mode)} solved={@frame && @frame.solved}>
                  <.maze_view
                    w={@w} h={@h} walls={@walls_d} start={@start} goal={@goal}
                    trail={(@frame && @frame.path) || [@start]} agent={live_agent(@frame, @start)} accent={to_string(@mode)}
                  />
                </.panel>
              </div>
            </div>
          </div>
        </section>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body gap-3">
            <p class="text-sm text-base-content/70">
              Deception is not a horsepower problem — in the signed experiment a strong sep-CMA-ES optimiser is
              trapped just as badly (0 of 40 runs), because a better goal-chaser only reaches the dead end
              faster. Changing <em>what you reward</em>, not the strength of the search, is what escapes.
            </p>
            <div class="flex flex-wrap gap-x-6 gap-y-2 font-mono text-xs text-base-content/50 pt-1">
              <a href="https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master/plans/CHARTER_P4_OBJECTIVES.md" class="link link-hover" target="_blank" rel="noreferrer">Programme 4 charter</a>
              <a href="https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master/insights/INDEX.md" class="link link-hover" target="_blank" rel="noreferrer">signed insight 051</a>
              <.link navigate={~p"/research/notes/abandoning-the-objective"} class="link link-hover">the plain-language note</.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- components ----------------------------------------------------------------

  attr :title, :string, required: true
  attr :sub, :string, required: true
  attr :accent, :string, required: true
  attr :solved, :any, default: false
  slot :inner_block, required: true

  defp panel(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body p-4 gap-2">
        <div class="flex items-center justify-between">
          <div>
            <h3 class={["font-semibold text-sm", accent_text(@accent)]}>{@title}</h3>
            <p class="font-mono text-[11px] text-base-content/50">{@sub}</p>
          </div>
          <span :if={@solved} class="badge badge-sm badge-success">reached ✓</span>
        </div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :w, :integer, required: true
  attr :h, :integer, required: true
  attr :walls, :list, required: true
  attr :start, :any, required: true
  attr :goal, :any, required: true
  attr :trail, :list, required: true
  attr :agent, :any, required: true
  attr :accent, :string, required: true

  defp maze_view(assigns) do
    assigns = assign(assigns, vb_w: @pad * 2 + assigns.w * @cell, vb_h: @pad * 2 + assigns.h * @cell, cell: @cell)

    ~H"""
    <svg viewBox={"0 0 #{@vb_w} #{@vb_h}"} class="w-full h-auto" role="img"
         aria-label="A grid maze with a wall, a start and a goal, and the agent's path.">
      <rect :for={{x, y} <- @walls} x={cx(x) - @cell / 2 + 1} y={cy(y, @h) - @cell / 2 + 1}
            width={@cell - 2} height={@cell - 2} rx="3" fill="currentColor" opacity="0.42" />
      <rect x={cx(elem(@goal, 0)) - @cell / 2 + 2} y={cy(elem(@goal, 1), @h) - @cell / 2 + 2}
            width={@cell - 4} height={@cell - 4} rx="4" fill="#4E9F6B" opacity="0.9" />
      <text x={cx(elem(@goal, 0))} y={cy(elem(@goal, 1), @h) + 4} text-anchor="middle"
            font-family="ui-monospace, monospace" font-size="11" font-weight="bold" fill="#fff">G</text>
      <circle cx={cx(elem(@start, 0))} cy={cy(elem(@start, 1), @h)} r={@cell / 2 - 3}
              fill="none" stroke="currentColor" stroke-opacity="0.35" stroke-width="1.5" />
      <text x={cx(elem(@start, 0))} y={cy(elem(@start, 1), @h) + 4} text-anchor="middle"
            font-family="ui-monospace, monospace" font-size="10" fill="currentColor" opacity="0.5">S</text>
      <polyline :if={length(@trail) > 1} points={points(@trail, @h)} fill="none"
                stroke={accent_hex(@accent)} stroke-width="2.5" stroke-opacity="0.55"
                stroke-linejoin="round" stroke-linecap="round" />
      <circle :if={@agent} cx={cx(elem(@agent, 0))} cy={cy(elem(@agent, 1), @h)} r="6"
              fill={accent_hex(@accent)} />
    </svg>
    """
  end

  attr :phase, :atom, required: true
  attr :frame, :any, required: true
  attr :goal, :any, required: true

  defp evolve_status(assigns) do
    ~H"""
    <span class={["font-mono text-xs", evolve_tone(@frame)]}>{evolve_msg(@phase, @frame)}</span>
    """
  end

  # --- view helpers -------------------------------------------------------------

  defp cx(x), do: @pad + x * @cell + div(@cell, 2)
  defp cy(y, h), do: @pad + (h - 1 - y) * @cell + div(@cell, 2)

  defp points(cells, h), do: Enum.map_join(cells, " ", fn {x, y} -> "#{cx(x)},#{cy(y, h)}" end)

  # The agent position and trail up to the current animation index (clamped at the end).
  defp trail_agent(path, idx) do
    n = length(path)
    shown = min(idx, n - 1)
    %{trail: Enum.take(path, shown + 1), agent: Enum.at(path, shown)}
  end

  defp reached?(path, idx, goal), do: Enum.at(path, min(idx, length(path) - 1)) == goal

  defp live_agent(nil, start), do: start
  defp live_agent(frame, _start), do: List.last(frame.path)

  defp mode_title(:objective), do: "Chasing the goal"
  defp mode_title(:novelty), do: "Seeking novelty"

  defp accent_text("objective"), do: "text-error"
  defp accent_text(_), do: "text-success"

  defp accent_hex("objective"), do: "#C7583F"
  defp accent_hex(_), do: "#4E9F6B"

  defp evolve_tone(%{solved: true}), do: "text-success"
  defp evolve_tone(_), do: "text-base-content/60"

  defp evolve_msg(:idle, _), do: "pick a reward, then evolve"
  defp evolve_msg(:evolving, _), do: "evolving…"
  defp evolve_msg(_phase, %{gen: g, solved: true}), do: "generation #{g} — reached the goal ✓"
  defp evolve_msg(_phase, %{gen: g}), do: "generation #{g} — still trapped in the cul-de-sac"
  defp evolve_msg(_phase, nil), do: "pick a reward, then evolve"
end
