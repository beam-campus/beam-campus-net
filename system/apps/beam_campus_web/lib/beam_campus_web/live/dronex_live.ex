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
    {:ok, socket |> assign(dirty?: false, chosen: nil, watching: nil, focus: nil) |> load()}
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

  # ⚠ THE PICKED FIGHT SURVIVES A REDRAW, which is the whole point of holding it
  # in the socket rather than recomputing "the best one" every second. Facts
  # arrive continuously from four islands; a visitor who clicked a fight and had
  # it swapped out from under them two seconds later would conclude the page was
  # broken, and would be right.
  def handle_event("watch", %{"key" => key}, socket),
    do: {:noreply, socket |> assign(watching: key) |> load()}

  # ⚠ CLICKING THE FOCUSED ISLAND CLEARS IT, and clicking open sea clears it too.
  # A filter you can enter and cannot leave is a trap, and on a canvas there is
  # no obvious "off" — so both the mark and the water are the way out.
  def handle_event("focus_island", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(focus: toggled(socket.assigns.focus, id), watching: nil)
     |> load()}
  end

  defp toggled(same, same), do: nil
  defp toggled(_was, id), do: id

  # The same deep blue-black the maps use. A function and not a module attribute:
  # inside a `~H` sigil `@backdrop` means `assigns.backdrop`.
  defp backdrop, do: "bg-[#0a1220]"

  defp load(socket) do
    islands = Dronex.islands()
    focus = socket.assigns[:focus]
    watchable = Dronex.watchable(focus)

    assign(socket,
      islands: islands,
      raids: Dronex.raids(),
      watchable: watchable,
      focused: Enum.find(islands, &(&1.id == focus)),
      leaderboard: Dronex.leaderboard(),
      fight: watching(watchable, socket.assigns[:watching]),
      state: Dronex.state(),
      refused: Dronex.refused()
    )
  end

  # Whichever fight was clicked, else the best one the ranking offers, else
  # whatever `Dronex.latest_fight/0` can still find. The last fallback matters:
  # an island that has published vitals and nothing else has no watchable fight
  # at all, and an empty canvas explains nothing.
  defp watching(watchable, key) do
    picked(Enum.find(watchable, &(tag(&1.key) == key)) || List.first(watchable))
  end

  # ⚠ `|>` BINDS TIGHTER THAN `||`, which made the first version of this return
  # the ranking ENTRY rather than the `{kind, fact}` the renderer takes — and
  # only in the case where a fight was actually found, so the fallback path
  # looked fine and the normal path did not.
  defp picked(nil), do: Dronex.latest_fight()
  defp picked(entry), do: {entry.kind, entry.fact}

  # `{:raid, "abc"}` is not something a DOM attribute can carry back.
  defp tag({kind, id}), do: "#{kind}:#{id}"

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
        <%!-- ⚠ THE MAP IS THE NAVIGATION AND SITS ABOVE THE FIGHT, small. It
              is not competing with the canvas for the eye: it is a strip that
              says which four machines this is happening between, and clicking an
              island narrows everything below to that island's fights. --%>
        <.archipelago
          :if={@islands != []}
          islands={@islands}
          raids={@raids}
          focus={@focus}
          class="mt-6"
        />

        <%!-- ⚠ THE RAIL ENGAGES AT `lg' AND NOWHERE BELOW IT. The container is
              max-w-5xl, so at a 768px viewport a four-column split would leave
              the replay ~552px and the rail ~184px and cramp both. Below `lg'
              everything stacks exactly as it did. --%>
        <div class="lg:grid lg:grid-cols-4 lg:items-start lg:gap-4">
          <div class="lg:col-span-3">
            <.fight :if={@fight} fight={@fight} />
          </div>

          <div class="lg:col-span-1">
            <.chooser
              :if={@watchable != [] || @focused}
              watchable={@watchable}
              watching={@watching}
              focused={@focused}
            />
          </div>
        </div>

        <%!-- ⚠ THE MAP SECOND. Every island has been a
             row in a list until now, which reads as several unrelated
             experiments. They are one archipelago, and the raids between them
             are the only thing that makes that true rather than asserted. --%>
        <.leaderboard :if={@leaderboard != []} standings={@leaderboard} focus={@focus} />

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

  # ── Choosing what to watch, and the standings ───────────────────

  @doc """
  Pick a fight to watch.

  ⚠ WITH FOUR ISLANDS THERE ARE TWELVE DIRECTED PAIRS AND "THE NEWEST ONE" IS A
  POOR ANSWER. The newest fight is very often a rout, and a visitor who arrives
  during one concludes the whole exhibit is a rout. Worse, three islands can now
  raid a fourth at the same moment — that is the point of the fourth island —
  and a page that shows one fight would silently drop the other two.
  """
  attr :watchable, :list, required: true
  attr :watching, :any, default: nil
  attr :focused, :any, default: nil

  def chooser(assigns) do
    ~H"""
    <section class="mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-3">
        <h2 class="text-sm font-semibold opacity-80">
          {(@focused && "Fights at #{Dronex.label(@focused)}") || "Watch another"}
        </h2>
        <span class="text-xs opacity-40">
          {length(@watchable)} held
          <%!-- ⚠ A FILTER YOU CANNOT LEAVE IS A TRAP, and clicking open sea is
                not discoverable. This is the visible way out. --%>
          <button
            :if={@focused}
            phx-click="focus_island"
            phx-value-id={@focused.id}
            class="btn btn-ghost btn-xs"
          >
            show all
          </button>
        </span>
      </div>

      <%!-- An island can be selected before it has fought anything, and an empty
            list with no explanation reads as a broken page. --%>
      <p :if={@watchable == []} class="mt-2 text-xs opacity-50">
        Nothing to watch at this island yet. It has published no fight — a raid it
        flew, or one it hosted — since this page started listening.
      </p>

      <%!-- Two columns while it is a full-width block below `lg', ONE while it
            is the rail beside the player. The rail holds about eight buttons at
            the canvas's height, which is exactly the cap, and it scrolls rather
            than stretching the row. --%>
      <ul class="mt-2 grid gap-1 sm:grid-cols-2 lg:max-h-[34rem] lg:grid-cols-1 lg:overflow-y-auto">
        <li :for={f <- Enum.take(@watchable, 8)}>
          <button
            phx-click="watch"
            phx-value-key={"#{elem(f.key, 0)}:#{elem(f.key, 1)}"}
            data-watch={"#{elem(f.key, 0)}:#{elem(f.key, 1)}"}
            class={[
              "w-full rounded border p-2 text-left transition",
              (@watching == "#{elem(f.key, 0)}:#{elem(f.key, 1)}" && "border-primary") ||
                "border-base-300 hover:border-base-content/30"
            ]}
          >
            <div class="flex items-baseline justify-between gap-2">
              <span class="font-mono text-xs">{f.title}</span>
              <span class={[
                "badge badge-xs",
                (f.kind == :raid && "badge-error badge-outline") || "badge-ghost"
              ]}>
                {f.kind}
              </span>
            </div>
            <div class="text-xs opacity-45">{f.why}</div>
          </button>
        </li>
      </ul>

      <p class="mt-2 text-xs opacity-40">
        <%!-- ⚠ SAID OUT LOUD, BECAUSE A RANKING THAT WILL NOT EXPLAIN ITSELF IS
              ASKING TO BE TRUSTED. This orders a list and measures nothing. --%>
        Ordered by how interesting the fight is likely to be, not by how recent:
        a raid over a training bout, both sides losing airframes over a rout, a
        close finish, and a raider winning away from home over a defender
        holding. The line under each is the strongest reason it is on this list.
        It is a way of sorting a list and it measures nothing.
      </p>
    </section>
    """
  end

  @doc """
  The islands, ranked on the one number they all earn on identical terms.
  """
  attr :standings, :list, required: true
  attr :focus, :string, default: nil

  def leaderboard(assigns) do
    ~H"""
    <section class="mt-8">
      <h2 class="text-sm font-semibold opacity-80">The archipelago, ranked</h2>

      <div class="mt-2 overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr class="text-xs opacity-50">
              <th>island</th>
              <th class="text-right">frozen exam</th>
              <th class="text-right">generation</th>
              <th class="text-right">roster</th>
              <th class="text-right">raids</th>
              <th class="text-right">held</th>
              <th class="text-right">captures</th>
            </tr>
          </thead>
          <tbody>
            <%!-- ⚠ THE SAME FILTER, REACHABLE FROM A KEYBOARD. Clicking a
                  canvas cannot be tabbed to, so the map alone would have put the
                  page's navigation out of reach of anyone not using a mouse.
                  These rows do the same thing and are buttons. --%>
            <tr
              :for={{s, n} <- Enum.with_index(@standings)}
              data-standing={s.island}
              class={["cursor-pointer", @focus == s.id && "bg-base-200"]}
            >
              <td class="font-mono text-xs">
                <button phx-click="focus_island" phx-value-id={s.id} class="text-left">
                  <span :if={n == 0} class="opacity-70">★</span> {s.island}
                </button>
              </td>
              <td class="text-right font-mono">{s.score}%</td>
              <td class="text-right font-mono opacity-60">{s.generation}</td>
              <td class="text-right font-mono opacity-60">{s.roster}/{s.capacity}</td>
              <td class="text-right font-mono opacity-60">{s.raids}</td>
              <td class="text-right font-mono opacity-60">{s.defences}</td>
              <td class="text-right font-mono opacity-60">{s.captures}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="mt-2 text-xs opacity-40">
        <%!-- ⚠ THE RANKING COLUMN AND THE INTERESTING COLUMNS ARE NOT THE SAME
              COLUMNS, and saying so is the whole reason this caption exists. --%>
        <%!-- ⚠ ONE PHRASE, NOT TWO. This said "frozen benchmark" while the
              section above said "frozen exam", so a reader had to work out that
              two names were one thing before reading either. --%>
        Ranked on the <strong>frozen exam</strong>
        — a fixed ladder of scripted
        opponents that never changes, so a rising score means the drones got
        better rather than the exam got easier —
        and deliberately not on
        raids. The benchmark is the only number every island earns on identical
        terms: the same scripted drills from the same fixed starts, flown as an
        away game with no ground network at all, so it scores the controller and
        never the terrain. Raid counts are shown because they are interesting and
        are not comparable between islands — who you fought, how often, and
        whether your neighbours were awake all move them, so an island that
        raided a sleepy neighbour twenty times would top a table it never earned.
      </p>
    </section>
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
      <.replay bout={@bout} big={@raid?} />
    </section>
    """
  end

  def fight(assigns), do: ~H""

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
            # ⚠ WHERE THE DEFENDER'S TOWERS STOOD, AND EMPTY WHEN THERE WERE
            # NONE. A raider fights over somebody else's ground with no
            # stations of its own, and that asymmetry is what makes attacking
            # cost something. An older island publishes neither key and simply
            # draws no towers, which is the correct picture of a fight that
            # predates them.
            ground: Map.get(b, "ground", []),
            ground_range: Map.get(b, "ground_range", 0),
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
            c.strokeStyle = "#45C8D8"
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
            c.fillStyle = "#9AE9F2"
            c.beginPath(); c.arc(tx, ty, 3.5, 0, 6.284); c.fill()

            // A pad on the floor, so the tower is planted rather than hovering.
            const [bx, by] = this.project(x, y, z)
            c.fillStyle = "#45C8D8"
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
              c.strokeStyle = "#45C8D8"
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
              const colour = attacker ? "#E2556E" : "#4C8DFF"
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
              // THEM IS VISIBLE. This drew black at alpha 0.16 — on a #0a1220
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
        <h3 class="text-sm font-semibold opacity-70">The last fight</h3>
        <span class="text-xs opacity-50">
          {@kind} bout · {@ticks} ticks · won by {@winner}
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
        aria-label={"a #{@ticks} tick engagement, won by #{@winner}"}
      >
      </canvas>

      <div class="mt-2 flex items-center gap-3">
        <button id="dronex-replay-play" class="btn btn-xs">play / pause</button>
        <input id="dronex-replay-scrub" type="range" min="0" value="0" class="range range-xs grow" />
        <span class="text-xs opacity-40">{@count} frames</span>
      </div>
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
