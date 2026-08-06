defmodule BeamCampusWeb.DronexLive do
  @moduledoc """
  Islands breeding drone controllers, and the last fight each of them ran.

  ## It plays a recording. It does not run the fight.

  Every twenty seconds an island publishes one whole engagement: every frame,
  already computed, in one fact of **about 1.2 MB** — measured on the box, after
  a comment claiming "a few tens of kilobytes" cost the site a fortnight of
  two-hourly OOM kills. This page stores it and animates it in the browser, which
  is why it can offer scrub, pause and slow motion, and why a hundred viewers
  cost the island nothing.

  ## The mass is fetched for ONE fight, and only when the fight changes

  The recording does not live in the board's rows and is not pulled on every
  redraw. `Dronex.recording/1` fetches the frames of the fight being drawn by
  single-key lookup, and `put_fight/2` below re-encodes only when the chosen
  fight actually changed. See `Dronex.WatchBouts.Board` for what happened when
  neither of those was true.

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

    {:ok,
     socket
     # Without this the tab, the history entry and every shared link read as the
     # site's generic title, so four different workbench pages are one bookmark.
     |> assign(page_title: "DroneX")
     |> assign(dirty?: false, watching: nil, focus: nil)
     |> assign(fight: nil, payload: nil, frame_count: 0)
     # `nil` means the map has not told us what it is showing. Before the first
     # report, and for anyone who never moves it, that has to mean EVERYTHING.
     |> assign(panel: :fights, in_view: nil)
     |> load()}
  end

  # ⚠ THE SELECTION AND THE PANEL LIVE IN THE URL, so a link carries what you
  # were looking at. This page already sets `page_title' for exactly that reason
  # — without it "four different workbench pages are one bookmark" — and putting
  # navigation behind tabs while leaving the address bar unchanged would make it
  # less shareable than the version that had no tabs at all.
  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(focus: params["island"], panel: panel_of(params["panel"]))
     |> load()}
  end

  defp panel_of("vitals"), do: :vitals
  defp panel_of("exam"), do: :exam
  defp panel_of(_fights), do: :fights

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
     |> assign(watching: nil)
     |> push_patch(to: dronex_path(toggled(socket.assigns.focus, id), socket.assigns.panel))}
  end

  def handle_event("show_panel", %{"panel" => panel}, socket) do
    {:noreply, push_patch(socket, to: dronex_path(socket.assigns.focus, panel_of(panel)))}
  end

  # ⚠ WHAT THE MAP IS SHOWING, DEBOUNCED AND ONLY ON CHANGE. The hook computes
  # this every frame because a raid in flight animates, but it only tells us when
  # the SET of visible islands differs — a message per frame would be sixty
  # round trips a second to move a table nobody asked to move.
  def handle_event("viewport", %{"ids" => ids}, socket) do
    {:noreply, assign(socket, in_view: MapSet.new(ids))}
  end

  # ⚠ NOT `path/2'. `Phoenix.VerifiedRoutes' imports one, and defining a private
  # function of that name shadows nothing — it makes the ~p macro try to expand
  # your arguments as a route and fail at compile time with a message about
  # compile-time path strings, which reads as a problem with the sigil.
  defp dronex_path(island, panel), do: ~p"/research/workbench/dronex?#{query(island, panel)}"

  defp query(nil, :fights), do: []
  defp query(nil, panel), do: [panel: panel]
  defp query(island, :fights), do: [island: island]
  defp query(island, panel), do: [island: island, panel: panel]

  defp toggled(same, same), do: nil
  defp toggled(_was, id), do: id

  # The same deep blue-black the maps use. A function and not a module attribute:
  # inside a `~H` sigil `@backdrop` means `assigns.backdrop`.
  defp backdrop, do: "bg-[#0a1220]"

  defp load(socket) do
    islands = Dronex.islands()
    focus = socket.assigns[:focus]
    watchable = Dronex.watchable(focus)

    socket
    |> assign(
      islands: islands,
      raids: Dronex.raids(),
      watchable: watchable,
      focused: Enum.find(islands, &(&1.id == focus)),
      ranked: ranked(),
      state: Dronex.state(),
      refused: Dronex.refused()
    )
    |> put_fight(watching(watchable, socket.assigns[:watching]))
  end

  # ⚠ RANKED OVER EVERY ISLAND, AND NUMBERED HERE. The table below may be
  # filtered to whatever the map is showing, and a rank that renumbered under
  # that filter would be measuring the viewport rather than the archipelago.
  defp ranked do
    Dronex.leaderboard()
    |> Enum.with_index(1)
    |> Enum.map(fn {standing, place} -> Map.put(standing, :rank, place) end)
  end

  # ⚠ THE RECORDING IS FETCHED AND ENCODED WHEN THE FIGHT CHANGES, NOT ON EVERY
  # REDRAW. This page redraws twice a second while four islands publish, and a
  # recording is about 1.2 MB: pulling it and running it through `Jason` each
  # time burnt several megabytes a second of garbage to produce a byte-identical
  # string that LiveView then diffed to nothing.
  #
  # The comparison is on the fact and not just the key, because a raid's
  # commitments arrive before its recording does — same key, and the second
  # arrival is the one worth drawing.
  defp put_fight(socket, nil), do: assign(socket, fight: nil, payload: nil, frame_count: 0)

  defp put_fight(%{assigns: %{fight: %{key: k, fact: f}}} = socket, %{key: k, fact: f}),
    do: socket

  defp put_fight(socket, entry) do
    frames = drawable(Dronex.recording(entry.key))

    assign(socket,
      fight: entry,
      payload: encode(entry.fact, frames),
      frame_count: length(frames)
    )
  end

  # A dropped recording draws nothing, and the player says which of the two it
  # is. See `Dronex.recording/1` — `:gone` is a real state, not a failure.
  defp drawable({:ok, frames}), do: frames
  defp drawable(:gone), do: []

  defp encode(fact, frames) do
    Jason.encode!(%{
      arena: Map.get(fact, "arena", [1000, 1000, 300]),
      frames: frames,
      # ⚠ WHERE THE DEFENDER'S TOWERS STOOD, AND EMPTY WHEN THERE WERE NONE. A
      # raider fights over somebody else's ground with no stations of its own,
      # and that asymmetry is what makes attacking cost something. An older
      # island publishes neither key and simply draws no towers, which is the
      # correct picture of a fight that predates them.
      ground: Map.get(fact, "ground", []),
      ground_range: Map.get(fact, "ground_range", 0),
      stride: 7,
      mstride: 5
    })
  end

  # Whichever fight was clicked, else the best one the ranking offers, else
  # whatever `Dronex.latest_fight/0` can still find. The last fallback matters:
  # an island that has published vitals and nothing else has no watchable fight
  # at all, and an empty canvas explains nothing.
  defp watching(watchable, key) do
    picked(Enum.find(watchable, &(tag(&1.key) == key)) || List.first(watchable))
  end

  # Both arms are ranking entries now: `latest_fight/0` answers the same shape
  # `watchable/0` elements have, so there is no longer a second shape for "a
  # fight" and no unwrapping for the caller to get wrong.
  defp picked(nil), do: Dronex.latest_fight()
  defp picked(entry), do: entry

  # ⚠ THE ONE NUMBER PAIR THAT ACTUALLY DIFFERS BETWEEN ROWS. A raid sends
  # twelve a side; how many of each came back is the whole outcome, and it is the
  # only part of the ranking's own description that is not the same string on
  # most rows. A training bout has no two sides, so it says so instead.
  defp survivors(%{kind: :raid, fact: f}),
    do: "#{num(f, "raiders_home")}–#{num(f, "defenders_home")}"

  defp survivors(_bout), do: "drill"

  defp ticks_of(%{fact: f}), do: "#{num(f, "ticks")}t"

  # `{:raid, "abc"}` is not something a DOM attribute can carry back.
  defp tag({kind, id}), do: "#{kind}:#{id}"

  # ⚠ ONE SELECTED ISLAND, NOT TWO. This page had `chosen' for the vitals tabs
  # and `focus' for the fights filter — two independent selections of the same
  # kind of thing, so a visitor could be reading beam03's vitals while watching
  # beam01's fights, with two rows of controls and no hint they were unrelated.
  # There is now one selection, set from the map or a leaderboard row, and it
  # scopes both.
  #
  # Unselected still shows something: the first island that has actually
  # published a bout, else the first at all, because an empty panel explains
  # nothing.
  defp showing(islands, focus) do
    Enum.find(islands, fn i -> i.id == focus end) ||
      Enum.find(islands, &Dronex.fact(&1, :bout)) ||
      List.first(islands)
  end

  @impl true
  def render(assigns) do
    shown = showing(assigns.islands, assigns.focus)

    assigns = assign(assigns, shown: shown, bout: shown && Dronex.fact(shown, :bout))

    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- ⚠ WIDER THAN THE REST OF THE SITE, ON PURPOSE. `max-w-5xl' is right
           for prose and wrong for this: it left the player 640px and the ranked
           table seven columns in a third of that, on screens with 1900px going
           spare. A workbench whose main content is a canvas and a data table
           earns the extra 256px. --%>
      <div class="mx-auto max-w-7xl px-4 py-10">
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

        <%!-- ⚠ THE FIGHT STILL COMES BEFORE THE DETAIL, and the band above it is
             NAVIGATION rather than content. What anybody opening this page wants
             is drones fighting drones; for a while the fight was a small canvas
             below a picture of two circles, and that is the mistake this
             ordering exists to avoid. The map and the table sit above it because
             they are how you CHOOSE what to watch, not because they are more
             interesting than it.
             ⚠⚠ AND THEY ARE ONE CONTROL, NOT TWO. Both drive `@focus'; the map
             is the spatial view of the selection and the table is the legible
             one. The table was below the fight and the map was unlabelled above
             it, so the page's primary navigation was the only thing on it
             without a title, and the two halves of one control were separated by
             the thing they control. --%>
        <.one_world
          :if={@islands != []}
          islands={@islands}
          raids={@raids}
          standings={@ranked}
          in_view={@in_view}
          focus={@focus}
          focused={@focused}
        />

        <%!-- ⚠ THE PANEL ENGAGES AT `lg' AND NOWHERE BELOW IT. The container is
              max-w-5xl, so at a 768px viewport this split would cramp both
              halves. Below `lg' everything stacks.
              ⚠⚠ A THIRD RATHER THAN A QUARTER, because this column stopped being
              a list of buttons. It now carries the stat tiles and the exam
              profile too, and 184px could hold neither. --%>
        <%!-- ⚠ THE TOP MARGIN IS ON THE ROW. It was on both children, and the
              panel then cancelled its own at `lg' — so the right column floated
              32px above the player it sits beside. --%>
        <div class="mt-8 lg:grid lg:grid-cols-3 lg:items-start lg:gap-6">
          <div class="lg:col-span-2">
            <.fight :if={@fight} fight={@fight} payload={@payload} frame_count={@frame_count} />
          </div>

          <%!-- ⚠ THE CHOOSER SITS BESIDE THE THING IT CHOOSES, and that is why
                the TABS moved up here rather than this list moving down to them.
                Three panels were scoped by one selection and lived in two places
                with different chrome: the fights beside the player, the numbers
                and the exam a screen below. Consolidating them is right; doing it
                by pushing the fights list down would have separated a control
                from the canvas it drives, so you would pick a fight in one place
                and watch it change in another. --%>
          <div class="lg:col-span-1">
            <.island_panel
              :if={@shown}
              row={@shown}
              panel={@panel}
              selected?={@focus != nil}
              watchable={@watchable}
              watching={@watching}
              focused={@focused}
            />
          </div>
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
  attr :panel, :atom, default: :vitals

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
    <div :if={@panel == :vitals} class="mt-4 grid gap-3 sm:grid-cols-4 lg:grid-cols-2">
      <.stat label="roster" value={num(@v, "roster")} of={num(@v, "capacity")} />
      <.stat label="generation" value={num(@v, "generation")} />
      <.stat label="rounds bred" value={num(@v, "rounds")} />
      <.stat label="admitted" value={num(@v, "admissions")} />
    </div>

    <%!-- ⚠ ONE LINE, BECAUSE THESE ARE THE ONLY TILES ON THE PAGE THAT FORGET
          THEIR AUDIENCE. "roster 210/240" arrives with nothing saying what 240
          is, and "admitted" reads as a membership count rather than as the
          survival rate of a breeding attempt. A visitor who cannot read the
          numbers cannot tell a healthy island from a dying one, which is the
          one thing this grid exists to show. --%>
    <p :if={@panel == :vitals} class="mt-2 text-xs opacity-40">
      An island fields at most {num(@v, "capacity")} drone controllers at once;
      the roster is how many it currently holds, and it falls when a raid costs
      airframes. A round is one attempt to breed a better controller than the
      worst one on the roster, and <em>admitted</em> counts the attempts that beat
      it — most do not.
    </p>

    <%!-- ⚠ CAPTURES IS THE ONE THAT SAYS WHETHER ANY OF THIS IS HAPPENING.
          Raids and defences can both climb while it stays zero — an island
          refusing every raid on an engine mismatch looks identical from
          outside — and then the archipelago is several separate experiments
          with a light show on top. --%>
    <div :if={@panel == :vitals} class="mt-3 grid gap-3 sm:grid-cols-4 lg:grid-cols-2">
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

    <div :if={@panel == :exam} class="mt-4">
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
    <div class="mt-2">
      <div class="flex flex-wrap items-baseline justify-between gap-3">
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
            <%!-- ⚠ THE SCORELINE LEADS, AND THE SENTENCE FOLLOWS IT SMALL.
                  Eight rows read "close: 1 home against 0 still up" five times
                  over, because the ranking's reasons collapse when almost every
                  engagement ends in mutual annihilation. The prose was doing no
                  work a reader could use to choose. The SURVIVOR COUNTS differ
                  even when the verdict does not, so they go first and in a size
                  you can scan down. --%>
            <div class="flex items-baseline justify-between gap-2">
              <span class="font-mono text-xs">{f.title}</span>
              <span class="shrink-0 font-mono text-sm tabular-nums">
                {survivors(f)}
              </span>
            </div>
            <div class="mt-0.5 flex items-baseline justify-between gap-2">
              <span class="truncate text-[11px] opacity-40">{f.why}</span>
              <span class="shrink-0 text-[11px] opacity-30">{ticks_of(f)}</span>
            </div>
          </button>
        </li>
      </ul>

      <%!-- ⚠ SAID OUT LOUD BUT NOT IN THE WAY. A ranking that will not explain
            itself is asking to be trusted, and five lines of it under an
            eight-row list is most of the column. Folded, not dropped. --%>
      <details class="mt-2">
        <summary class="cursor-pointer text-xs opacity-40">How this list is ordered</summary>
        <p class="mt-2 text-xs opacity-40">
          Ordered by how interesting the fight is likely to be, not by how recent:
          a raid over a training bout, both sides losing airframes over a rout, a
          close finish, and a raider winning away from home over a defender
          holding. The line under each is the strongest reason it is on this list.
          It is a way of sorting a list and it measures nothing.
        </p>
      </details>
    </div>
    """
  end

  @doc """
  The map and the ranked table, as one control over one selection.

  ## The table lists what the MAP IS SHOWING, and the rank is global anyway

  The map pans and zooms because a world that grows without limit stays readable
  only if the viewer moves. Once it does that, a table beside it that ignores
  where the viewer is looking is a second, unrelated list. So the rows follow the
  viewport.

  ⚠ **BUT THE RANK IS COMPUTED OVER EVERY ISLAND, NOT OVER THE VISIBLE ONES.**
  A ranking that renumbers when you pan is not a ranking, and the first island is
  not "the best one here", it is "the best one you happen to be looking at". Each
  row carries its place in the whole archipelago, so filtering the list never
  changes what a number means.

  ⚠⚠ **AND THE DEFAULT FIT SHOWS EVERYTHING**, which is what makes this safe: a
  visitor who never touches the map sees the full ranking, and so does anyone on
  a keyboard, who cannot pan a canvas at all. The filter only bites after a
  deliberate zoom, and the line above the table says so with a count.
  """
  attr :islands, :list, required: true
  attr :raids, :list, required: true
  attr :standings, :list, required: true
  attr :in_view, :any, default: nil
  attr :focus, :string, default: nil
  attr :focused, :any, default: nil

  def one_world(assigns) do
    shown = visible(assigns.standings, assigns.in_view)

    assigns =
      assign(assigns,
        shown: shown,
        hidden: length(assigns.standings) - length(shown)
      )

    ~H"""
    <section class="mt-6">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h2 class="text-sm font-semibold opacity-80">One world</h2>

        <%!-- ⚠ THE SELECTION SAID IN WORDS, because it was a white ellipse drawn
              inside a canvas and nothing else. A ring cannot be read by a screen
              reader, it is not visible once you have scrolled past the map, and
              nothing on the page told you how to clear it — that was a comment
              in the source. A filter you cannot see is a page that looks broken
              to whoever forgot it was on. --%>
        <button
          :if={@focused}
          phx-click="focus_island"
          phx-value-id={@focus}
          class="badge badge-primary badge-sm gap-1"
          aria-label={"showing #{Dronex.label(@focused)} only. Activate to show every island."}
        >
          showing {Dronex.label(@focused)} <span aria-hidden="true">✕</span>
        </button>

        <span :if={!@focused} class="text-xs opacity-40">
          every island · pick one on the map or in the table
        </span>
      </div>

      <.archipelago islands={@islands} raids={@raids} focus={@focus} class="mt-2" />

      <p :if={@hidden > 0} class="mt-2 text-xs opacity-50">
        {length(@shown)} of {length(@standings)} islands in view. Double-click the
        map to fit them all.
      </p>

      <.leaderboard standings={@shown} focus={@focus} />
    </section>
    """
  end

  # `nil` means the map has not reported yet — on first paint, and for anyone who
  # never moves it. Everything, rather than nothing, is the right answer then.
  defp visible(standings, nil), do: standings
  defp visible(standings, in_view), do: Enum.filter(standings, &MapSet.member?(in_view, &1.id))

  @doc """
  Everything one selection scopes, in one place, beside the fight.

  ## ⚠ THE FIGHT IS NOT A TAB HERE. A LIST OF FIGHTS IS.

  The distinction is the data model rather than taste, and it is worth keeping
  because the two look alike. A RAID belongs to two islands — the board keys
  raids by `raid_id` precisely because "filed under the publisher, the
  attacker's half of the story would have no home" — so a tab claiming to hold
  *beam03's last fight* would be a filing error the storage layer refuses to
  make. "beam03's last fight" is not well formed when beam03 raided msi00 and
  msi00 raided beam03 in the same minute.

  A list of fights **involving** an island is a different claim and a true one.
  It is participation, not ownership, and it is as much a view of one island as
  its roster is. So the fight stays on the canvas and the CHOOSER for it sits
  here, first, because choosing is what this column is for.

  ## And these are not the tab row that was removed

  That one was four buttons that chose an ISLAND, duplicating the table and the
  map: three controls for one piece of state, two of them wired to a stale copy.
  These choose a VIEW. The island selection still has exactly one home.
  """
  attr :row, :map, required: true
  attr :panel, :atom, default: :fights
  attr :selected?, :boolean, default: false
  attr :watchable, :list, required: true
  attr :watching, :any, default: nil
  attr :focused, :any, default: nil

  def island_panel(assigns) do
    ~H"""
    <section class="mt-8 lg:mt-0">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <%!-- ⚠ SAID ONCE. The heading, a badge beside it and the list's own
              scope line all announced "every island" inside one 300px column. --%>
        <h2 class="text-base font-semibold">
          {(@focused && Dronex.label(@focused)) || "Every island"}
        </h2>
      </div>

      <div role="tablist" class="tabs tabs-bordered mt-2">
        <button
          :for={{id, label} <- [{:fights, "Fights"}, {:vitals, "Vitals"}, {:exam, "Exam"}]}
          role="tab"
          aria-selected={to_string(@panel == id)}
          phx-click="show_panel"
          phx-value-panel={id}
          class={["tab tab-sm", @panel == id && "tab-active"]}
        >
          {label}
        </button>
      </div>

      <.chooser
        :if={@panel == :fights}
        watchable={@watchable}
        watching={@watching}
        focused={@focused}
      />

      <%!-- ⚠ THE NUMBERS FOLLOW THE SELECTION AND NOT THE FIGHT. With nothing
            selected this shows a default island and says so, because an empty
            panel explains nothing — but the fights tab beside it is showing the
            WHOLE archipelago at that moment, and a reader must not take the two
            for one island's story. --%>
      <p :if={@panel != :fights and !@selected?} class="mt-2 text-xs opacity-40">
        {Dronex.label(@row)}, shown because nothing is selected. Pick an island
        above.
      </p>

      <.vitals :if={@panel != :fights} row={@row} panel={@panel} />
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
    <div class="mt-3">
      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr class="text-xs opacity-50">
              <th class="w-8">#</th>
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
            <%!-- A clickable row that does not react to a pointer is a
                  clickable row nobody discovers. --%>
            <tr
              :for={s <- @standings}
              data-standing={s.island}
              class={[
                "cursor-pointer hover:bg-base-200/60",
                @focus == s.id && "bg-base-200 outline outline-1 outline-primary/40"
              ]}
            >
              <%!-- ⚠ THE RANK IS THE PLACE IN THE WHOLE ARCHIPELAGO, computed
                    before this list was filtered to what the map is showing. A
                    number that renumbered as you panned would be measuring the
                    viewport. --%>
              <td class="text-right font-mono text-xs opacity-50">
                <span :if={s.rank == 1} class="opacity-100">★</span>
                <span :if={s.rank != 1}>{s.rank}</span>
              </td>
              <td class="font-mono text-xs">
                <button phx-click="focus_island" phx-value-id={s.id} class="text-left">
                  {s.island}
                </button>
              </td>
              <%!-- ⚠ A COLLAPSE IS NOT A LOW SCORE AND MUST NOT READ AS ONE.
                    beam03 sat 288/288 in the morning and 1/288 nine hours later,
                    while raiding hard and absorbing 2,113 foreign genomes — and
                    the table drew that as a quiet fifth row in the same grey as
                    88%. The exam is the one number every island earns on
                    identical terms, so an island that has stopped earning it at
                    all is the most interesting thing on the page, not the least.
                    Marked, never explained away: the cause is not known and the
                    table does not get to guess. --%>
              <td class={["text-right font-mono", s.score < 10 && "text-error font-semibold"]}>
                {s.score}%
                <span :if={s.score < 10} class="ml-1 opacity-70" title="the exam has collapsed">
                  ⚠
                </span>
              </td>
              <td class="text-right font-mono opacity-60">{s.generation}</td>
              <td class="text-right font-mono opacity-60">{s.roster}/{s.capacity}</td>
              <td class="text-right font-mono opacity-60">{s.raids}</td>
              <td class="text-right font-mono opacity-60">{s.defences}</td>
              <td class="text-right font-mono opacity-60">{s.captures}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <%!-- ⚠ FOLDED, NOT DELETED. Five lines of dense prose sat between the
            ranked table and the fight, pushing the main event of the page below
            an explanation of a side panel. It still has to be READABLE — a
            ranking that will not explain itself is asking to be trusted — so it
            is one click away rather than gone. --%>
      <details class="mt-2">
        <summary class="cursor-pointer text-xs opacity-40">
          What this ranks on, and what it deliberately does not
        </summary>
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
      </details>
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
        <h3 class="text-base font-semibold">The last fight</h3>
        <span class="text-xs opacity-50">
          {@kind} · {@ticks} ticks · won by {@winner}
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
  # ⚠ THE FLOWS LIST IS GONE INTO THE MAP'S ARCS. It said, in words, which pair
  # had raided which and how often — exactly what an arc that thickens with
  # traffic now says where the traffic is drawn. Keeping both meant the map was
  # decoration with a table underneath doing its job. `short/1' went with it: it
  # existed to shorten an id for that list and had no other caller.
end
