defmodule BeamCampusWeb.RoboRumbleLive do
  @moduledoc """
  Watch Robo Rumble. Live from the mesh, and the fights are regenerated here.

  The page is a spectator in the strict sense: everything it shows arrived as a
  published fact from `hecate-robo-rumbler`, running on a machine this site does
  not control, and the site sends nothing back.

  ## The fights are not a video

  A duel fact carries two genomes and a start index, about 1.2 KB. The fight
  itself is roughly 200 frames, and a full visit is 6,400 of them: about 93 MB.
  Because the engine is integer-deterministic, the 1.2 KB and the 93 MB say the
  same thing, so this page re-runs the battle on the web node and draws the frames
  it computes. It also checks itself: the fact carries the turn count measured on
  the rumbler's machine, and a replay that does not match it is reported rather
  than drawn.
  """
  use BeamCampusWeb, :live_view

  @tick_ms 40

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: RoboRumbler.subscribe()

    {:ok,
     socket
     |> assign(
       page_title: "Robo Rumble",
       watching: RoboRumbler.watching?(),
       arena: RoboRumbler.arena(),
       duel: nil,
       replay: nil,
       error: nil,
       step: 0,
       playing: false
     )
     |> load()}
  end

  # --- mesh ---------------------------------------------------------------------

  @impl true
  def handle_info({:rumble, _kind}, socket), do: {:noreply, load(socket)}

  # --- animation ----------------------------------------------------------------

  def handle_info(:tick, %{assigns: %{playing: true, replay: %{frames: frames}}} = socket) do
    advance(socket, socket.assigns.step + 1, length(frames))
  end

  def handle_info(:tick, socket), do: {:noreply, socket}

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp advance(socket, step, total) when step >= total do
    {:noreply, assign(socket, step: total - 1, playing: false)}
  end

  defp advance(socket, step, _total) do
    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, assign(socket, step: step)}
  end

  # --- controls -----------------------------------------------------------------

  @impl true
  def handle_event("watch", %{"index" => i}, socket) do
    {:noreply, watch(socket, Enum.at(RoboRumbler.duels(), String.to_integer(i)))}
  end

  def handle_event("play", _params, socket) do
    Process.send_after(self(), :tick, @tick_ms)
    {:noreply, assign(socket, playing: true, step: replay_step(socket))}
  end

  def handle_event("pause", _params, socket), do: {:noreply, assign(socket, playing: false)}

  def handle_event("seek", %{"value" => v}, socket) do
    {:noreply, assign(socket, step: String.to_integer(v), playing: false)}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, duel: nil, replay: nil, error: nil, playing: false)}
  end

  # Restart from the top when the viewer presses play on a finished replay,
  # rather than sitting on the last frame looking broken.
  defp replay_step(%{assigns: %{step: step, replay: %{frames: frames}}})
       when step >= length(frames) - 1,
       do: 0

  defp replay_step(%{assigns: %{step: step}}), do: step

  defp watch(socket, nil), do: socket

  defp watch(socket, fact) do
    socket
    |> assign(duel: fact, step: 0, playing: false)
    |> shown(RoboRumbler.replay(fact))
  end

  defp shown(socket, {:ok, replay}) do
    Process.send_after(self(), :tick, @tick_ms)
    assign(socket, replay: replay, error: nil, playing: true)
  end

  # A replay that will not reproduce is SAID, not hidden and not approximated.
  # This is the one place where the page could lie convincingly.
  defp shown(socket, {:error, why}), do: assign(socket, replay: nil, error: why)

  defp load(socket) do
    assign(socket,
      field: RoboRumbler.field(),
      visits: RoboRumbler.visits(),
      duels: RoboRumbler.duels(),
      fighting: RoboRumbler.fighting()
    )
  end

  # --- render -------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl px-4 py-10 space-y-10">
      <header class="space-y-3">
        <p class="font-mono text-xs uppercase tracking-widest opacity-60">Workbench</p>
        <h1 class="text-3xl font-semibold">Robo Rumble</h1>
        <p class="max-w-2xl opacity-80">
          Forty trained tanks hold a field on a machine in the lab. A visitor sends one
          genome, it fights all forty from eighty starting geometries in both seats, and
          the result is published to the mesh. This page is subscribed to that mesh.
        </p>
        <p class="max-w-2xl text-sm opacity-60">
          The fights below are not recordings. A published duel carries two genomes and
          a start index, about 1.2&nbsp;KB; the fight is about 200 frames and a whole
          visit is 93&nbsp;MB. The engine is integer-deterministic, so this page re-runs
          the battle here and gets the same one, turn for turn.
        </p>
      </header>

      <.dark :if={not @watching} />

      <.arena_panel
        :if={@duel}
        duel={@duel}
        replay={@replay}
        error={@error}
        step={@step}
        playing={@playing}
        arena={@arena}
      />

      <.fighting_now fighting={@fighting} />
      <.duel_list duels={@duels} />
      <.visit_list visits={@visits} />
      <.field_panel field={@field} />
    </div>
    """
  end

  # --- components ---------------------------------------------------------------

  defp dark(assigns) do
    ~H"""
    <div class="rounded-lg border border-dashed p-6 opacity-70">
      <p class="font-semibold">Not watching the mesh.</p>
      <p class="text-sm mt-1">
        This build has no realm configured, so there is nothing to subscribe to. The page
        works; it just has no facts yet.
      </p>
    </div>
    """
  end

  attr :fighting, :list, required: true

  defp fighting_now(assigns) do
    ~H"""
    <section :if={@fighting != []} class="space-y-2">
      <h2 class="font-mono text-xs uppercase tracking-widest opacity-60">Fighting now</h2>
      <ul class="space-y-1">
        <li :for={f <- @fighting} class="font-mono text-sm flex items-center gap-3">
          <span class="inline-block h-2 w-2 rounded-full bg-[#F2B142] animate-pulse"></span>
          {short(f["challenger_id"])}
          <span class="opacity-50">against the field</span>
        </li>
      </ul>
    </section>
    """
  end

  attr :duels, :list, required: true

  defp duel_list(assigns) do
    ~H"""
    <section class="space-y-3">
      <h2 class="font-mono text-xs uppercase tracking-widest opacity-60">Featured duels</h2>
      <p :if={@duels == []} class="text-sm opacity-60">
        Nothing yet. The rumbler publishes one watchable duel per visit: the longest
        battle that was actually decided. Length alone would always pick a turn-cap
        standoff, because a stalemate is by definition the longest a fight can run.
      </p>
      <ul class="grid gap-2 sm:grid-cols-2">
        <li :for={{d, i} <- Enum.with_index(@duels)}>
          <button
            phx-click="watch"
            phx-value-index={i}
            class="w-full text-left rounded-lg border p-3 hover:border-[#F2B142] transition"
          >
            <p class="font-mono text-sm">
              {short(d["challenger_id"])}
              <span class="opacity-50">vs</span>
              {d["resident_arm"]}/{d["resident_seed"]}
            </p>
            <p class="text-xs opacity-60 mt-1">
              {d["turns"]} turns, start {d["start_index"]}, challenger {d["challenger_seat"]}
            </p>
            <p :if={d["decided"] == false} class="text-xs opacity-50 mt-1">
              stalemate: ran out the turn cap
            </p>
          </button>
        </li>
      </ul>
    </section>
    """
  end

  attr :visits, :list, required: true

  defp visit_list(assigns) do
    ~H"""
    <section class="space-y-3">
      <h2 class="font-mono text-xs uppercase tracking-widest opacity-60">Settled visits</h2>
      <p :if={@visits == []} class="text-sm opacity-60">No rows have arrived on this node yet.</p>
      <div :if={@visits != []} class="overflow-x-auto">
        <table class="w-full text-sm font-mono">
          <thead class="opacity-50 text-left">
            <tr>
              <th class="py-1 pr-4">challenger</th>
              <th class="py-1 pr-4">matches</th>
              <th class="py-1 pr-4">W</th>
              <th class="py-1 pr-4">L</th>
              <th class="py-1 pr-4">D</th>
              <th class="py-1 pr-4">capped</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={v <- @visits} class="border-t border-current/10">
              <td class="py-1 pr-4">{short(v["challenger_id"])}</td>
              <td class="py-1 pr-4">{v["matches"]}</td>
              <td class="py-1 pr-4">{v["wins"]}</td>
              <td class="py-1 pr-4">{v["losses"]}</td>
              <td class="py-1 pr-4">{v["draws"]}</td>
              <td class="py-1 pr-4 opacity-60">{v["capped"]}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p :if={@visits != []} class="text-xs opacity-50">
        Capped battles are stalemates that reached the turn limit. They are counted
        separately and never folded into draws.
      </p>
    </section>
    """
  end

  attr :field, :map, default: nil

  defp field_panel(assigns) do
    ~H"""
    <section :if={@field} class="space-y-3">
      <h2 class="font-mono text-xs uppercase tracking-widest opacity-60">
        The field ({@field["size"]} residents)
      </h2>
      <p class="text-sm opacity-70 max-w-2xl">{@field["caveat"]}</p>
      <ul class="flex flex-wrap gap-2">
        <li :for={a <- @field["by_arm"] || []} class="rounded border px-2 py-1 font-mono text-xs">
          {a["arm"]} × {a["count"]}
        </li>
      </ul>
    </section>
    """
  end

  # --- the arena ----------------------------------------------------------------

  attr :duel, :map, required: true
  attr :replay, :map, default: nil
  attr :error, :any, default: nil
  attr :step, :integer, required: true
  attr :playing, :boolean, required: true
  attr :arena, :any, required: true

  defp arena_panel(assigns) do
    ~H"""
    <section class="rounded-lg border p-4 space-y-3">
      <div class="flex items-center justify-between gap-4">
        <h2 class="font-mono text-sm">
          {short(@duel["challenger_id"])}
          <span class="opacity-50">vs</span>
          {@duel["resident_arm"]}/{@duel["resident_seed"]}
        </h2>
        <button phx-click="close" class="text-xs opacity-60 hover:opacity-100">close</button>
      </div>

      <.replay_failed :if={@error} error={@error} />
      <.arena_svg :if={@replay} replay={@replay} step={@step} arena={@arena} />

      <div :if={@replay} class="flex items-center gap-3">
        <button
          phx-click={if @playing, do: "pause", else: "play"}
          class="rounded border px-3 py-1 text-sm hover:border-[#F2B142]"
        >
          {if @playing, do: "pause", else: "play"}
        </button>
        <input
          type="range"
          min="0"
          max={length(@replay.frames) - 1}
          value={@step}
          phx-change="seek"
          name="value"
          class="flex-1"
        />
        <span class="font-mono text-xs opacity-60 w-24 text-right">
          turn {@step}/{@replay.turns}
        </span>
      </div>

      <p :if={@replay} class="text-xs opacity-50">
        {verdict(@replay, @duel["decided"])}
        <span :if={Map.get(@replay, :verified)}>
          · reproduced exactly: {@replay.turns} turns here, {@duel["turns"]} on the rumbler
        </span>
      </p>
    </section>
    """
  end

  attr :error, :any, required: true

  defp replay_failed(assigns) do
    ~H"""
    <div class="rounded border border-red-500/40 p-3 text-sm">
      <p class="font-semibold">This duel did not reproduce.</p>
      <p class="opacity-70 mt-1 font-mono text-xs">{inspect(@error)}</p>
      <p class="opacity-70 mt-2">
        The page will not draw a fight it cannot verify. Either the fact is malformed or
        this node's engine differs from the one that published it.
      </p>
    </div>
    """
  end

  attr :replay, :map, required: true
  attr :step, :integer, required: true
  attr :arena, :any, required: true

  defp arena_svg(assigns) do
    {w, h} = assigns.arena
    frame = Enum.at(assigns.replay.frames, assigns.step) || %{tanks: [], bullets: [], turn: 0}
    assigns = assign(assigns, w: w, h: h, frame: frame)

    ~H"""
    <svg
      viewBox={"0 0 #{@w} #{@h}"}
      class="w-full h-auto rounded bg-black/40"
      role="img"
      aria-label="Robo Rumble arena"
    >
      <circle :for={b <- @frame.bullets} cx={b.x} cy={b.y} r={@w / 180} fill="#F2B142" />
      <g :for={t <- @frame.tanks} opacity={if t.dead, do: "0.25", else: "1"}>
        <circle cx={t.x} cy={t.y} r={@w / 45} fill={colour(t.id, @replay.challenger)} />
        <line
          x1={t.x}
          y1={t.y}
          x2={t.x + @w / 22 * cos(t.heading)}
          y2={t.y + @w / 22 * sin(t.heading)}
          stroke={colour(t.id, @replay.challenger)}
          stroke-width={@w / 300}
        />
        <rect
          x={t.x - @w / 45}
          y={t.y - @w / 30}
          width={@w / 45 * 2 * energy(t.energy)}
          height={@w / 250}
          fill={colour(t.id, @replay.challenger)}
          opacity="0.7"
        />
      </g>
    </svg>
    """
  end

  # --- helpers ------------------------------------------------------------------

  # The visitor is amber, the resident is slate. Which seat the visitor took comes
  # from the fact, so the colours follow the tank and not the position.
  defp colour(id, challenger) when id == challenger, do: "#F2B142"
  defp colour(_id, _challenger), do: "#8AA0B4"

  # Headings are BINARY ANGLES: one turn is 256, not 2π. Converting here rather
  # than in the engine keeps the wire integer and the trigonometry in the one
  # place that needs a circle drawn.
  defp cos(heading), do: :math.cos(heading * 2 * :math.pi() / 256)
  defp sin(heading), do: :math.sin(heading * 2 * :math.pi() / 256)

  # Full energy is 25_600 in fixed point, the same scale the terminal watcher's
  # bar uses.
  defp energy(e), do: max(0.0, min(1.0, e / 25_600))

  # A DRAW AND A TIMEOUT ARE NOT THE SAME THING, and this said "Draw at the turn
  # cap" for both. The live page duly announced a 1913-turn draw as having hit a
  # 2000-turn cap, which is simply false. Whether the fight ended or ran out is
  # what `decided` on the fact records, so it is what decides the sentence.
  @doc false
  def verdict(%{winner: w, challenger: w}, _decided), do: "The visitor won."
  def verdict(%{winner: :none}, false), do: "Stalemate: ran out the turn cap."
  def verdict(%{winner: :none}, _decided), do: "A draw: neither tank survived."
  def verdict(%{winner: _w}, _decided), do: "The resident won."

  defp short(nil), do: "?"
  defp short(id), do: String.slice(id, 0, 10)
end
