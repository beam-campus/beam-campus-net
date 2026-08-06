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
  import BeamCampusWeb.DronexFight, only: [fight: 1]

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
     |> assign(fight: nil, payload: nil, frame_count: 0, losses: nil)
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
  # A link to the tab that briefly existed lands on the numbers it charted.
  defp panel_of("history"), do: :vitals
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
  defp put_fight(socket, nil),
    do: assign(socket, fight: nil, payload: nil, frame_count: 0, losses: nil)

  defp put_fight(%{assigns: %{fight: %{key: k, fact: f}}} = socket, %{key: k, fact: f}),
    do: socket

  defp put_fight(socket, entry) do
    frames = drawable(Dronex.recording(entry.key))

    assign(socket,
      fight: entry,
      payload: encode(entry.fact, frames),
      frame_count: length(frames),
      # ⚠ WALKED ONCE, WITH THE PAYLOAD. This reads every drone in every frame;
      # doing it per render would be that walk twice a second for a number that
      # only changes when the fight does.
      losses: Dronex.AccountForLosses.account(frames)
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
        <%!-- ⚠ THE TABS OWN EVERYTHING UNDER THEM, INCLUDING THE PLAYER.
              They used to scope only a side column while the fight stayed
              visible beside them — so a tab labelled "Fights" sat next to a
              permanently playing fight, and switching to Vitals left it there.
              Either the label was wrong or the scope was, and the label is
              right.

              The earlier argument for keeping the player outside was that a
              raid belongs to TWO islands and must not be filed under one. That
              is still true and is not what this does: the tab set is a set of
              VIEWS, the Fights view holds the player and its chooser, and the
              player still shows a fight between two islands that the selection
              merely filters. Vitals and Exam also get the full width, which
              they wanted — a rung profile in a third of a column was cramped
              before any history chart was added to it. --%>
        <.island_panel
          :if={@shown}
          row={@shown}
          panel={@panel}
          selected?={@focus != nil}
          fight={@fight}
          payload={@payload}
          frame_count={@frame_count}
          losses={@losses}
          watchable={@watchable}
          watching={@watching}
          focused={@focused}
          islands={@islands}
        />

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

  # ── History ─────────────────────────────────────────────────────

  @doc """
  One measure's trajectory, drawn beside the number it is the history of.

  ## ⚠ IT STARTS EMPTY, AND SAYS SO

  This is memory and not a store. The site reads the mesh and holds no database,
  so a restart begins the trajectory again. A panel that drew two points as a
  confident line would be claiming a history it does not have.

  ## ⚠⚠ THE AXIS RUNS 0 TO THE REAL CEILING, NEVER TO THE DATA

  The exam is 0-100 and the roster is 0-capacity, fixed. Fitting the axis to
  whatever arrived would turn beam03's fall from 100% to 0.3% and its climb back
  to 27% into three similar-looking wiggles, which is the oldest way to lie with
  a line.
  """
  attr :row, :map, required: true
  attr :metric, :atom, required: true
  attr :label, :string, required: true
  attr :ceiling, :integer, required: true
  attr :unit, :string, default: ""

  def trend_panel(assigns) do
    samples = Dronex.history(assigns.row.id)

    assigns = assign(assigns, samples: samples, enough?: length(samples) >= 2)

    ~H"""
    <div class="mt-4">
      <p :if={!@enough?} class="text-xs opacity-40">
        {@label} over time appears here once there are two samples. The board
        samples every {div(Dronex.sample_every_ms(), 1000)}s and keeps it in memory
        rather than a database, so a restart begins it again.
      </p>

      <.trend
        :if={@enough?}
        label={"#{@label} over time"}
        unit={@unit}
        samples={@samples}
        pick={@metric}
        ceiling={@ceiling}
        span={span_of(@samples)}
      />

      <details :if={@enough?} class="mt-2">
        <summary class="cursor-pointer text-xs opacity-40">The samples, as a table</summary>
        <div class="mt-2 max-h-56 overflow-y-auto">
          <table class="table table-xs">
            <thead>
              <tr class="text-xs opacity-50">
                <th>at</th>
                <th class="text-right">{@label}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={p <- Enum.reverse(@samples)}>
                <td class="font-mono text-xs opacity-60">{clock(p.at)}</td>
                <td class="text-right font-mono">{Map.get(p, @metric)}{@unit}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </details>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :unit, :string, default: ""
  attr :samples, :list, required: true
  attr :pick, :atom, required: true
  attr :ceiling, :integer, required: true
  attr :span, :any, required: true

  defp trend(assigns) do
    latest = assigns.samples |> List.last() |> Map.get(assigns.pick)

    assigns =
      assign(assigns,
        latest: latest,
        points: polyline(assigns.samples, assigns.pick, assigns.ceiling, assigns.span),
        dots: plotted(assigns.samples, assigns.pick, assigns.ceiling, assigns.span)
      )

    ~H"""
    <figure>
      <figcaption class="flex items-baseline justify-between gap-2">
        <span class="text-xs font-semibold opacity-70">{@label}</span>
        <%!-- ⚠ THE LAST VALUE IS LABELLED AND THE OTHERS ARE NOT. A number on
              every point is 240 numbers and no shape. --%>
        <span class="font-mono text-sm tabular-nums">{@latest}{@unit}</span>
      </figcaption>

      <svg
        viewBox="0 0 600 140"
        class="mt-1 h-auto w-full text-primary"
        role="img"
        aria-label={"#{@label} over the last #{minutes(@span)} minutes, now #{@latest}#{@unit}, on a scale from 0 to #{@ceiling}"}
      >
        <%!-- Recessive, and drawn under the data. --%>
        <line
          :for={f <- [0.0, 0.5, 1.0]}
          x1="34"
          x2="592"
          y1={grid_y(f)}
          y2={grid_y(f)}
          class="stroke-base-content/15"
          stroke-width="1"
        />
        <text
          :for={{f, v} <- [{0.0, @ceiling}, {1.0, 0}]}
          x="30"
          y={grid_y(f) + 3}
          text-anchor="end"
          class="fill-base-content/40"
          font-size="9"
        >
          {v}
        </text>

        <polyline
          points={@points}
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linejoin="round"
          stroke-linecap="round"
        />

        <%!-- Native tooltips: every sample interrogable, no JavaScript. --%>
        <circle :for={{x, y, p} <- @dots} cx={x} cy={y} r="6" fill="transparent">
          <title>{clock(p.at)} · {Map.get(p, @pick)}{@unit}</title>
        </circle>
      </svg>
    </figure>
    """
  end

  # ── Plotting ────────────────────────────────────────────────────

  defp span_of([]), do: nil
  defp span_of([only]), do: {only.at, only.at + 1}

  defp span_of(samples) do
    {List.first(samples).at, max(List.last(samples).at, List.first(samples).at + 1)}
  end

  defp polyline(samples, pick, ceiling, span) do
    samples
    |> plotted(pick, ceiling, span)
    |> Enum.map_join(" ", fn {x, y, _p} -> "#{x},#{y}" end)
  end

  defp plotted(samples, pick, ceiling, {t0, t1}) do
    Enum.map(samples, fn p ->
      x = 34 + (p.at - t0) * 558 / max(1, t1 - t0)
      y = 128 - min(Map.get(p, pick, 0), ceiling) * 116 / max(1, ceiling)
      {Float.round(x * 1.0, 1), Float.round(y * 1.0, 1), p}
    end)
  end

  # 12 is the top of the plot and 128 the baseline.
  defp grid_y(fraction), do: 12 + fraction * 116

  defp minutes({t0, t1}), do: div(t1 - t0, 60_000)

  defp clock(at) do
    at |> DateTime.from_unix!(:millisecond) |> Calendar.strftime("%H:%M")
  end

  # ── Vitals ──────────────────────────────────────────────────────

  attr :row, :map, required: true
  attr :panel, :atom, default: :vitals
  attr :islands, :list, default: []

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
    <div :if={@panel == :vitals} class="mt-4 grid gap-4 sm:grid-cols-4">
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
    <.trend_panel
      :if={@panel == :vitals}
      row={@row}
      metric={:roster}
      label="Roster"
      ceiling={max(1, num(@v, "capacity"))}
    />

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
    <div :if={@panel == :vitals} class="mt-3 grid gap-4 sm:grid-cols-4">
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

      <%!-- ⚠ A PROFILE IS A SHAPE, SO DRAW IT AS ONE. This was six bars each
            spanning the full width of the panel: a thousand pixels of primary
            colour to say "48 of 48", six times over. Length carried the value and
            the eye had to travel the whole screen to compare two rungs that are
            adjacent in the ladder.
            Columns side by side make the SHAPE the thing you read, which is what
            a profile is for — the rungs get harder left to right, so the
            expected picture is a descending staircase and a bulge in the middle
            is visible instantly. beam01 wins 40 at 'hoverer', 9 at 'chaser' and
            29 at 'sniper': non-monotonic, and invisible in six long bars. --%>
      <div :if={@starts > 0} class="mt-3 flex items-end gap-1.5" style="height: 4.5rem">
        <div :for={{rung, wins} <- Enum.zip(@rungs, @wins)} class="flex w-12 flex-col items-center">
          <span class="font-mono text-[10px] tabular-nums opacity-50">{wins}</span>
          <div class="mt-0.5 flex h-12 w-full items-end rounded-sm bg-base-300/60">
            <div
              class="w-full rounded-sm"
              style={"height: #{max(pct(wins, @starts), 2)}%; background: var(--chart-1)"}
              title={"#{rung}: #{wins} of #{@starts}"}
            >
            </div>
          </div>
          <span class="mt-1 w-full truncate text-center text-[10px] opacity-50" title={rung}>
            {rung}
          </span>
        </div>
      </div>

      <p :if={@starts > 0} class="mt-3 text-xs opacity-40">
        Six scripted drills, each flown {@starts} times from fixed starts, as an
        away game with no ground network. They get harder left to right: the last
        one holds station and shoots, and never pays for closing. Won at the
        bottom and lost at the top is what a graded instrument looks like.
      </p>

      <.trend_panel row={@row} metric={:score} label="Frozen exam" ceiling={100} unit="%" />

      <.ladder :if={@starts > 0} islands={@islands} focus={@row.id} rungs={@rungs} />
    </div>
    """
  end

  @doc """
  Every island against every drill, as one matrix.

  ## ⚠ THE ONE DIAGRAM THE DATA ALWAYS SUPPORTED AND NOTHING DREW

  `benchmark_wins` has been a PER-RUNG list on the wire the whole time, so which
  drills an island fails has always been knowable and was never shown — the page
  drew one total per island and six bars for whichever island was selected, and
  you could not see across the fleet at all. An adversarial review of what to
  visualise even asserted this needed a new field. It did not.

  It earns the space because the exam is the standing anomaly. beam03 has gone
  100% → 0.3% → 27% → 86% in a day; beam00 sits at 59%. A total cannot say
  whether an island is failing everywhere or falling off one drill, and those are
  different findings. beam00 wins 47/48 at `hoverer` and 19/48 at `sniper` — it
  is losing the top of the ladder. beam01 wins 40 at `hoverer`, **9 at `chaser`**
  and 29 at `sniper`: worst in the MIDDLE, which is not what a graded ladder is
  supposed to do and is invisible in any per-island view.

  ## Sequential, one hue, and never a rainbow

  Fill is a single hue at varying opacity, which is what a magnitude wants. The
  cell keeps a border at every value so a zero is a drawn zero rather than an
  absence, and carries its number, so identity is never colour alone.
  """
  attr :islands, :list, required: true
  attr :rungs, :list, required: true
  attr :focus, :any, default: nil

  def ladder(assigns) do
    ~H"""
    <div class="mt-6">
      <h3 class="text-sm font-semibold opacity-70">Every island, every drill</h3>

      <div class="mt-2 overflow-x-auto">
        <table class="text-xs">
          <thead>
            <tr>
              <th></th>
              <th :for={rung <- @rungs} class="px-1 pb-1 text-center font-normal opacity-50">
                {rung}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @islands} class={[@focus == row.id && "font-semibold"]}>
              <td class="py-0.5 pr-2 text-right font-mono opacity-70">{Dronex.label(row)}</td>
              <td :for={{wins, starts} <- rung_cells(row)} class="p-0.5">
                <div
                  class={[
                    "flex h-7 w-14 items-center justify-center rounded-sm border",
                    (@focus == row.id && "border-primary/60") || "border-base-300"
                  ]}
                  title={"#{Dronex.label(row)}: #{wins} of #{starts}"}
                >
                  <%!-- ⚠ A STEP FROM THE RAMP, NOT AN OPACITY ON A BRAND HUE.
                        Fading `primary' moves lightness and chroma together and
                        unevenly, and does it differently in each theme; these are
                        five validated steps, monotone in lightness, chosen
                        separately for light and dark. --%>
                  <div
                    class="absolute h-7 w-14 rounded-sm"
                    style={"background: #{step(wins, starts)}"}
                  >
                  </div>
                  <span class="relative font-mono tabular-nums">{pct(wins, starts)}</span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="mt-2 text-xs opacity-40">
        Win rate per drill, as a percentage. The ladder is ordered by difficulty,
        so a healthy island shades from left to right; a hole in the middle is a
        controller that has lost one specific skill rather than declined overall.
      </p>
    </div>
    """
  end

  # ⚠ FIVE STEPS, NOT A CONTINUOUS FADE. A ramp a reader can name a value on
  # beats one they can only compare against its neighbours, and the validator
  # checks the gaps between exactly these steps.
  #
  # ⚠⚠ AND THE FLOOR IS A DRAWN STEP. A cell at 0% must not vanish into the
  # surface and read as "no data" beside an island that has simply lost every
  # attempt — those are the two states this exhibit keeps having to tell apart,
  # which is why the lightest step is validated for contrast against the surface.
  defp step(_wins, 0), do: "var(--chart-seq-1)"

  defp step(wins, starts) do
    "var(--chart-seq-#{min(5, div(wins * 5, starts) + 1)})"
  end

  defp rung_cells(row) do
    v = Dronex.fact(row, :vitals) || %{}
    starts = num(v, "benchmark_starts")
    Enum.map(Map.get(v, "benchmark_wins", []), fn wins -> {wins, starts} end)
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
  attr :fight, :any, default: nil
  attr :payload, :any, default: nil
  attr :frame_count, :integer, default: 0
  attr :losses, :any, default: nil
  attr :watchable, :list, required: true
  attr :watching, :any, default: nil
  attr :focused, :any, default: nil
  attr :islands, :list, default: []

  def island_panel(assigns) do
    ~H"""
    <section class="mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h2 class="text-base font-semibold">
          {(@focused && Dronex.label(@focused)) || "Every island"}
        </h2>

        <span :if={@panel != :fights and !@selected?} class="text-xs opacity-40">
          {Dronex.label(@row)}, shown because nothing is selected
        </span>
      </div>

      <div role="tablist" class="tabs tabs-bordered mt-2">
        <button
          :for={{id, label} <- panels()}
          role="tab"
          aria-selected={to_string(@panel == id)}
          phx-click="show_panel"
          phx-value-panel={id}
          class={["tab", @panel == id && "tab-active"]}
        >
          {label}
        </button>
      </div>

      <%!-- THE FIGHT AND ITS CHOOSER, side by side, because a list you pick from
            belongs next to the thing it changes. --%>
      <div :if={@panel == :fights} class="mt-2 lg:grid lg:grid-cols-3 lg:items-start lg:gap-6">
        <div class="lg:col-span-2">
          <.fight
            :if={@fight}
            fight={@fight}
            payload={@payload}
            frame_count={@frame_count}
            losses={@losses}
          />
        </div>

        <div class="lg:col-span-1">
          <.chooser watchable={@watchable} watching={@watching} focused={@focused} />
        </div>
      </div>

      <.vitals :if={@panel in [:vitals, :exam]} row={@row} panel={@panel} islands={@islands} />
    </section>
    """
  end

  # ⚠ NO "HISTORY" TAB. A chart of the roster belongs beside the roster, and a
  # chart of the exam beside the exam — not in a third place that makes you hold
  # a number in your head while you go and look at its trajectory. The tabs it
  # would have sat next to are six tiles and nine rungs; there was never a space
  # problem, only a filing one.
  defp panels, do: [{:fights, "Fights"}, {:vitals, "Vitals"}, {:exam, "Exam"}]

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
              <%!-- ⚠ THE SCORE AND WHO EARNED IT, TOGETHER. `roster:best/1'
                    sits the exam and a raid admits CAPTURED genomes into the
                    same roster, so an island's headline number can belong to a
                    controller bred on another machine. Reading the score
                    without that is how a change of champion gets mistaken for
                    an evolutionary result — which is live right now: beam03 went
                    288/288, then 1/288, then 27% inside a day while absorbing
                    2,113 foreign genomes. --%>
              <td class={["text-right font-mono", s.score < 10 && "text-error font-semibold"]}>
                {s.score}%
                <span :if={s.score < 10} class="ml-1 opacity-70" title="the exam has collapsed">
                  ⚠
                </span>
                <span
                  :if={s.sitter == "captured"}
                  class="ml-1 text-[10px] opacity-60"
                  title="the controller that sat this exam was captured from a neighbour, not bred here"
                >
                  captured
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
