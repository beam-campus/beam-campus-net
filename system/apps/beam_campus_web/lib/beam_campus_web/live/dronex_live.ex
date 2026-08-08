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
     |> assign(fight: nil, payload: nil, frame_count: 0)
     |> assign(panel: :fights)
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
      refused: Dronex.refused(),
      readings: Dronex.fleet_readings()
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
    do: assign(socket, fight: nil, payload: nil, frame_count: 0)

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
  # ⚠ TWO SIDES, AND IT READ AS ONE NUMBER PAIR. "8–3" here is raiders home
  # against defenders home; "5–2" in the ledger is one island's wins against its
  # losses. Identical shapes, opposite meanings, and nothing told them apart.
  defp survivors(%{kind: :raid, fact: f}) do
    assigns = %{home: num(f, "raiders_home"), held: num(f, "defenders_home")}

    ~H"""
    <span style="color: var(--side-attacker)">{@home}</span><span class="opacity-40">–</span><span style="color: var(--side-defender)">{@held}</span>
    """
  end

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
      <div class="workbench mx-auto max-w-7xl px-4 py-10">
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
        <div class="settle" style="animation-delay: 40ms">
          <.one_world
            :if={@islands != []}
            islands={@islands}
            raids={@raids}
            standings={@ranked}
            focus={@focus}
            focused={@focused}
            readings={@readings}
          />
        </div>

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
        <div class="settle" style="animation-delay: 120ms">
          <.island_panel
            :if={@shown}
            row={@shown}
            panel={@panel}
            selected?={@focus != nil}
            fight={@fight}
            payload={@payload}
            frame_count={@frame_count}
            watchable={@watchable}
            watching={@watching}
            focused={@focused}
            islands={@islands}
          />
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

  # ── How long a fight lasts ──────────────────────────────────────

  @doc """
  The distribution of raid durations, and whether a clock is cutting it off.

  ⚠ **THE PILE ON THE LONGEST BAR IS THE HEADLINE, not the shape.** A raid that
  ended because a cap was reached did not take that long, it took at least that
  long, and every average over a censored quantity is biased. So the caption
  leads with how many raids share the longest value seen, which is the cap
  revealing itself as a measurement rather than as an assumption. The island does
  not publish `max_ticks`, and hardcoding it here would put a world constant in a
  second repository on a different release cadence.

  Duration is NOT a measure of genome quality and the split by outcome is there
  to stop it being read as one. A short raid is a crushing attacker or a suicidal
  one; a long raid is a stout defence or two swarms that never met.
  """
  attr :raids, :list, required: true

  def how_long_fights_last(assigns) do
    assigns = assign(assigns, d: Dronex.TimeTheFights.distribution(assigns.raids))

    ~H"""
    <section :if={@d.n > 0} class="settle mt-8">
      <h2 class="instrument-lede text-base font-semibold">How long a fight lasts</h2>

      <p class="mt-1 max-w-2xl text-sm opacity-70">
        {@d.n} settled {(@d.n == 1 && "raid") || "raids"}, in ticks, because the island
        publishes its clock in ticks and not its rate.
        <%!-- One raid at the maximum is not a ceiling, it is the maximum, and there is
             always exactly one of those. A ceiling is a PILE. --%>
        <strong :if={@d.ceiling}>
          {@d.at_longest} of them end on exactly {@d.ceiling}, which is a ceiling
          rather than a duration: those fights were stopped, not finished.
        </strong>
        <span :if={is_nil(@d.ceiling)}>
          The longest ran {@d.longest} and nothing else stopped there, so no clock
          is cutting these off.
        </span>
      </p>

      <div class="instrument mt-2 p-3">
        <div
          id="fight-durations"
          phx-hook="DronexChart"
          phx-update="ignore"
          class="h-64 w-full"
          role="img"
          aria-label={bars_spoken(@d)}
          data-spec={histogram_spec(@d)}
        >
        </div>
      </div>

      <table class="mt-3 text-xs">
        <thead>
          <tr class="opacity-50">
            <th class="pr-3 text-left font-normal">outcome</th>
            <th class="pr-3 text-right font-normal">n</th>
            <th class="pr-3 text-right font-normal">median</th>
            <th :if={@d.ceiling} class="text-right font-normal">at the ceiling</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={o <- @d.by_outcome}>
            <td class="pr-3">{o.outcome}</td>
            <td class="pr-3 text-right font-mono tabular-nums">{o.n}</td>
            <td class="pr-3 text-right font-mono tabular-nums">{o.median}</td>
            <td :if={@d.ceiling} class="text-right font-mono tabular-nums">{o.at_ceiling}</td>
          </tr>
        </tbody>
      </table>

      <p class="mt-2 max-w-2xl text-xs opacity-50">
        Duration is not a measure of quality. A short raid is a crushing attacker or
        a suicidal one, and a long one is a stout defence or two swarms that never
        met, which is why it is never shown without who won.
      </p>
    </section>
    """
  end

  # ⚠ SHAPE AND DATA ONLY, NEVER COLOUR. The browser reads the palette off the
  # stylesheet so a theme switch does not need a round trip and the brand lives
  # in exactly one place.
  defp histogram_spec(d) do
    Jason.encode!(%{
      x_name: "ticks",
      y_name: "raids",
      categories: Enum.map(d.bins, & &1.from),
      series: d.series
    })
  end

  defp bars_spoken(d) do
    "#{d.n} raids by duration in bins of #{d.bin} ticks, longest #{d.longest}, " <>
      "#{d.at_longest} of them ending on exactly that value"
  end

  @doc """
  Which drills moved, when the exam score moved. The `REGISTER D.15` instrument.

  ⚠ IT DESCRIBES AND NEVER CONCLUDES. D.15 is open: an island's score swings a
  hundred points in a day on a champion it says it bred, and nobody knows why.
  This shows the SHAPE of a move, which is the discriminator nobody had, and it
  is not the page's job to name a cause from it.
  """
  attr :row, :map, required: true

  def exam_ladder(assigns) do
    grid = Dronex.TraceTheExam.grid(Dronex.history(assigns.row.id))
    assigns = assign(assigns, grid: grid, reading: Dronex.TraceTheExam.reading(grid))

    ~H"""
    <div :if={@grid.rungs > 0} class="mt-4">
      <h3 class="text-sm font-semibold opacity-70">Which drills moved</h3>

      <div class="instrument mt-2 p-3">
        <div
          id={"exam-ladder-#{@row.id}"}
          phx-hook="DronexChart"
          phx-update="ignore"
          class="h-40 w-full"
          role="img"
          aria-label={"win rate per drill over #{length(@grid.columns)} samples"}
          data-spec={Jason.encode!(Map.put(@grid, :kind, "exam"))}
        >
        </div>
      </div>

      <p class="mt-2 max-w-2xl text-xs opacity-50">
        One column per sample, one row per drill, darker is a higher win rate. {@reading} A vertical stripe is every drill moving together; erosion from
        the top is a skill lost; a recovery on different drills from the ones that
        fell is a different controller wearing the same score. The single
        percentage above cannot tell those apart.
        <span class="mt-1 block">
          Written down, so it survives a deploy.
        </span>
      </p>
    </div>
    """
  end

  @doc """
  The three ablation readings over time, which is the only way they resolve.

  The board has collected `air`, `ground` and `all` every 30 seconds since it was
  written, under a comment saying a trajectory is the only thing that settles a
  signal this coarse. Nothing had ever drawn them.
  """
  attr :row, :map, required: true

  def ablation_trace(assigns) do
    samples = assigns.row.id |> Dronex.history() |> Enum.reverse()
    assigns = assign(assigns, samples: samples, enough?: length(samples) >= 2)

    ~H"""
    <div :if={@enough?} class="mt-4">
      <h3 class="text-sm font-semibold opacity-70">Does the radio matter, over time</h3>

      <div class="instrument mt-2 p-3">
        <div
          id={"ablation-#{@row.id}"}
          phx-hook="DronexChart"
          phx-update="ignore"
          class="h-40 w-full"
          role="img"
          aria-label={"ablation deltas over #{length(@samples)} samples, zero means the channel changed nothing"}
          data-spec={ablation_spec(@samples)}
        >
        </div>
      </div>

      <p class="mt-2 max-w-2xl text-xs opacity-50">
        The change in the raider's score when a channel is silenced, sampled over
        time. <strong>One reading is noise</strong>
        — the measure moves in steps of about 25, so one engagement changing hands
        is a whole step. What settles it is a line sitting off zero and staying
        there. Drawn as steps, because the wire republishes one exercise until the
        next is run.
        <span class="mt-1 block">
          Written down, so it survives a deploy.
        </span>
      </p>
    </div>
    """
  end

  defp ablation_spec(samples) do
    Jason.encode!(%{
      kind: "ablation",
      at: Enum.map(samples, & &1.at),
      series: [
        %{name: "air silenced", data: Enum.map(samples, & &1.air)},
        %{name: "ground silenced", data: Enum.map(samples, & &1.ground)},
        %{name: "both silenced", data: Enum.map(samples, & &1.all)}
      ]
    })
  end

  @doc """
  The whole archipelago in one row of numbers, before any chart.

  ⚠ A DASHBOARD LEADS WITH FIGURES, and this page led with a matrix. Everything
  here was already on the page, several screens down, spread across five
  instruments and reachable only by reading their captions. A visitor's first
  four questions are: is it alive, how much has happened, is either side
  winning, and how old is any of this.
  """
  attr :islands, :list, required: true
  attr :raids, :list, required: true

  def at_a_glance(assigns) do
    settled = Enum.filter(assigns.raids, &match?(%{parts: %{raid: [_ | _]}}, &1))
    won = Enum.count(settled, &(raid_winner(&1) == "attacker"))

    assigns =
      assign(assigns,
        settled: length(settled),
        flying: length(assigns.raids) - length(settled),
        share: (settled != [] && round(won * 100 / length(settled))) || nil,
        captures:
          assigns.islands
          |> Enum.map(&num(Dronex.fact(&1, :vitals) || %{}, "captures"))
          |> Enum.sum(),
        live?: Dronex.watching?(),
        rounds:
          assigns.islands
          |> Enum.map(&num(Dronex.fact(&1, :vitals) || %{}, "rounds"))
          |> Enum.max(fn -> 0 end)
      )

    ~H"""
    <div class="instrument settle mt-4 divide-y divide-base-content/5 p-0 sm:grid sm:grid-cols-3 sm:divide-x sm:divide-y-0 lg:grid-cols-5">
      <.figure label="islands" value={length(@islands)} note="heard from" live?={@live?} />
      <.figure label="raids settled" value={@settled} note={"#{@flying} still out"} />
      <.figure label="raider wins" value={(@share && "#{@share}%") || "–"} note="of settled raids" />
      <.figure label="longest lineage" value={@rounds} note="breeding rounds" />
      <.figure label="genomes captured" value={@captures} note="taken and kept" />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :note, :string, default: nil
  attr :live?, :boolean, default: false

  defp figure(assigns) do
    ~H"""
    <div class="px-4 py-3 sm:px-5 sm:py-4">
      <div class="flex items-center gap-1.5 text-[11px] uppercase tracking-[0.15em] opacity-40">
        {@label}
        <%!-- ⚠ A HEARTBEAT, NOT A DECORATION. A page of numbers that update
              silently cannot be told from a page that has frozen, and this one
              spent the afternoon looking identical whether the mesh was
              delivering or not. --%>
        <span
          :if={@live?}
          class="inline-block size-1.5 rounded-full bg-[var(--status-good)] motion-safe:animate-pulse"
          title="facts are arriving"
        >
        </span>
      </div>
      <div class="mt-1.5 font-mono text-3xl leading-none tabular-nums">{@value}</div>
      <div :if={@note} class="mt-1.5 text-xs opacity-40">{@note}</div>
    </div>
    """
  end

  defp raid_winner(%{parts: %{raid: [f | _]}}), do: Map.get(f, "winner")
  defp raid_winner(_unsettled), do: nil

  @doc """
  Every island's exam profile against every drill, which is what the exam is for.

  ⚠ A PROFILE, NOT A RANK. `REGISTER D.15` is that the single percentage swings a
  hundred points in a day on a locally bred champion, and nobody knows why. A
  number that unstable should not be the thing a table sorts on, but the six
  numbers behind it are readable: the drills are named and ordered by difficulty,
  so WHERE an island fails is a sentence rather than a score.
  """
  attr :islands, :list, required: true

  def exam_profiles(assigns) do
    spec = Dronex.CompareTheExams.profiles(assigns.islands)
    assigns = assign(assigns, spec: spec)

    ~H"""
    <section :if={@spec.drills != []} class="settle mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h2 class="instrument-lede text-base font-semibold">What each island can actually do</h2>
        <span class="font-mono text-xs opacity-40">the drills, easiest first</span>
      </div>

      <div class="instrument mt-2 p-3">
        <div
          id="exam-profiles"
          phx-hook="DronexChart"
          phx-update="ignore"
          class="h-64 w-full"
          role="img"
          aria-label={"exam win rate per drill for #{length(@spec.series)} islands"}
          data-spec={Jason.encode!(Map.put(@spec, :kind, "exam_profile"))}
        >
        </div>
      </div>

      <p class="mt-2 max-w-3xl text-xs opacity-50">
        The frozen exam is the only <strong>absolute</strong>
        measure here: six fixed opponents no island ever trains against, each sat
        the same number of times. Raids cannot do this job, because every island
        can improve at once and the win rate stays near a coin flip.
        <span class="mt-1 block">
          The drills run easiest to hardest. The first three are unarmed, so they
          ask only whether a swarm can kill. The last three shoot back, and two of
          them close the distance. <strong>A cliff between them is a named
          deficit</strong>: a controller that can hit a target but cannot fight
          something coming at it.
        </span>
        <span class="mt-1 block">
          Only drills every island has sat are drawn, because a gap beside a score
          reads as a failure.
        </span>
      </p>
    </section>
    """
  end

  @doc """
  Which controllers have held which islands, and which of them crossed the mesh.

  ⚠ THE CLAIM THIS EXHIBIT IS FOR, SHOWN AT LAST. `CHARTER.md` makes a raid the
  way opponent diversity crosses the mesh, and until the islands began naming
  their champion the page could only draw captures as a number going up. A genome
  id is the sha256 of its packed form, so the same id holding two islands IS the
  crossing.

  ⚠⚠ RANKED ON STRUCTURE, NEVER ON THE EXAM. The frozen exam is saturated at 47
  or 48 of 48 for four of five islands and `REGISTER D.15` says it swings a
  hundred points in a day. Islands held, then tenure, then sorties survived.
  """
  attr :standings, :list, default: []

  def champions(assigns) do
    ranked = Dronex.FollowTheChampions.ranked(10)
    assigns = assign(assigns, ranked: ranked, crossed: Enum.count(ranked, & &1.crossed?))

    ~H"""
    <section :if={@ranked != []} class="settle mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h2 class="instrument-lede text-base font-semibold">Which controllers have held an island</h2>
        <span class="font-mono text-xs opacity-40">
          {@crossed} of {length(@ranked)} crossed the mesh
        </span>
      </div>

      <div class="instrument mt-2 overflow-x-auto p-3">
        <table class="table table-sm">
          <thead>
            <tr class="text-xs opacity-50">
              <th>controller</th>
              <th class="text-right">islands</th>
              <th class="text-right">held</th>
              <th class="text-right">sorties</th>
              <th class="text-right">generation</th>
              <th>where it has been</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={c <- @ranked}>
              <td class="font-mono text-xs">
                {String.slice(c.genome_id, 0, 8)}
                <%!-- A controller that left the machine that made it is the whole
                      point, so it is marked rather than left to be inferred from
                      the island count. --%>
                <span
                  :if={c.crossed?}
                  class="ml-1 rounded-sm px-1 text-[10px]"
                  style="background: color-mix(in oklab, var(--side-attacker) 25%, transparent)"
                  title="this controller has left the island that bred it"
                >
                  crossed
                </span>
              </td>
              <td class="text-right font-mono tabular-nums">{c.islands}</td>
              <td class="text-right font-mono tabular-nums">{held_for(c.held_ms)}</td>
              <td class="text-right font-mono tabular-nums">{c.sorties}</td>
              <td class="text-right font-mono tabular-nums">{c.generation}</td>
              <td class="font-mono text-xs opacity-70">{journey(c.reigns)}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="mt-2 max-w-3xl text-xs opacity-50">
        A controller is identified by the <strong>sha256 of its packed genome</strong>, so the same id holding two islands is the
        same controller, not a guess. <strong>Crossed</strong>
        means it has left the island that bred it, either by holding another or by
        having been taken in a raid.
        <span class="mt-1 block">
          Ranked on islands held, then on how long, then on sorties survived.
          Deliberately not on the frozen exam: four of five islands sit at 47 or
          48 of 48 on it and it can move a hundred points in a day, so a ranking
          built on it would inherit every one of those faults.
        </span>
      </p>
    </section>
    """
  end

  # A tenure of seconds is a champion that was displaced immediately, and reading
  # it as "0m" would lose that. Minutes once there are any.
  defp held_for(ms) when ms < 60_000, do: "#{div(ms, 1000)}s"
  defp held_for(ms) when ms < 3_600_000, do: "#{div(ms, 60_000)}m"
  defp held_for(ms), do: "#{div(ms, 3_600_000)}h"

  # The islands it has held, in the order it held them, which is the path.
  defp journey(reigns) do
    reigns
    |> Enum.map(& &1.island)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.join(" → ")
  end

  # ── Who is who ──────────────────────────────────────────────────

  @doc """
  An island's name, and the four characters that say WHICH island.

  ⚠ **A NAME IS A STRING SOMEBODY TYPED ABOUT THEMSELVES.** Two islands may both
  call themselves `beam01`, and in an archipelago meant to admit strangers they
  eventually will. The board already keeps them apart, since every row is keyed
  on `island_id`; it was this page that merged them, by never showing an id at
  all. The reasoning, and what this does NOT fix, is in `Dronex.TellIslandsApart`.

  The mark is muted so it reads as a qualifier rather than as part of the name.

  ⚠ **AND IT IS NOT `aria-hidden`, WHICH THE FIRST VERSION HAD.** Hiding the mark
  from a screen reader hides the disambiguation from exactly the readers who
  cannot see the styling, so two islands called `beam01` would be told apart for
  sighted visitors and merged for everybody else. The separator is a real space
  INSIDE the span rather than an `ml-1`, because a CSS margin is not a space: the
  text read out was "beam01a6b1".
  """
  attr :row, :map, required: true
  attr :class, :string, default: "font-mono text-xs opacity-70"

  def island_name(assigns) do
    {name, mark} = Dronex.TellIslandsApart.named(assigns.row)
    assigns = assign(assigns, name: name, mark: mark)

    ~H"""
    <span class={@class}>
      {@name}<span :if={@mark} class="opacity-50">{" " <> @mark}</span>
    </span>
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
        samples every {div(Dronex.sample_every_ms(), 1000)}s, and writes each one
        down, so a restart resumes rather than starting again.
      </p>

      <div :if={@enough?} class="instrument p-3">
        <.trend
          label={"#{@label} over time"}
          unit={@unit}
          samples={@samples}
          pick={@metric}
          ceiling={@ceiling}
          span={span_of(@samples)}
        />
      </div>

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
    <.ablation_trace row={@row} />

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
      <div :if={@starts > 0} class="instrument mt-3 flex items-end gap-1.5 p-3" style="height: 6rem">
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
      <.exam_ladder row={@row} />
    </div>
    """
  end

  @doc """
  Where the archipelago's genetic material is going, one island at a time.

  ## ⚠ SMALL MULTIPLES, NOT ONE CHART WITH FIVE LINES

  Five islands on one pair of axes needs five distinguishable colours. This site
  has a validated CATEGORICAL PAIR — two hues, checked for separation under
  colour blindness — and inventing three more to fill a legend is how a palette
  becomes a rainbow and stops being readable by the people it was validated for.

  ## ⚠⚠ ONE SCALE ACROSS ALL OF THEM, OR THEY DO NOT COMPARE

  Each sparkline is drawn against the FLEET's largest count rather than its own,
  so an island that has taken four hundred genomes reads visibly taller than one
  that has taken forty. Per-island scaling would draw both as the same rising
  line, which is the classic small-multiple mistake and would make this panel say
  the opposite of what it is for.

  Captures is the number the vitals grid calls the one that says whether any of
  this is happening: raids and defences can both climb while it stays flat, and
  then the archipelago is five separate experiments with a light show on top.
  """
  attr :islands, :list, required: true

  def captures(assigns) do
    spec = Dronex.CountTheCaptures.rate(assigns.islands)
    assigns = assign(assigns, spec: spec)

    ~H"""
    <div class="mt-6">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h3 class="text-sm font-semibold opacity-70">Genomes taken, per ten minutes</h3>
        <span :if={@spec.bins != []} class="font-mono text-xs opacity-40">
          same scale on every island
        </span>
      </div>

      <p :if={@spec.bins == []} class="instrument mt-2 p-3 text-xs opacity-50">
        Nothing plotted yet. The board samples every {div(Dronex.sample_every_ms(), 1000)}s and needs two points in
        different ten-minute bins before a rate exists. Samples are written down,
        so this resumes after a deploy rather than starting again.
      </p>

      <div :if={@spec.bins != []} class="instrument mt-2 p-3">
        <div
          id="captures-rate"
          phx-hook="DronexChart"
          phx-update="ignore"
          class="h-56 w-full"
          role="img"
          aria-label={"genomes taken per ten minutes, #{length(@spec.series)} islands over #{length(@spec.bins)} bins"}
          data-spec={Jason.encode!(Map.merge(@spec, %{kind: "rates", label: "taken"}))}
        >
        </div>
      </div>

      <p class="mt-2 max-w-3xl text-xs opacity-50">
        Genomes taken from a defeated raiding party and kept, counted <strong>per ten minutes</strong>
        rather than as a running total. A cumulative count over a window this
        short is a flat line whatever the fleet does, which is what this panel
        drew until now: five islands between 6,656 and 7,585 on an axis anchored
        at zero differ by about four pixels.
        <span class="mt-1 block">
          A run of empty bins is an island that has stopped taking anything, which
          is the most useful thing this feed can say and the one a running total
          renders identically to a healthy island. A gap is a bin with no samples,
          not a bin in which nothing was taken.
        </span>
      </p>
    </div>
    """
  end

  @doc """
  Does breeding longer win wars? The chart that joins this exhibit's two halves.

  ## Both answers teach, which is why it is worth the space

  Everything else here measures one of two things and never both. The frozen exam
  measures SKILL against a ladder that never changes; the raids measure WAR
  against opponents that do. Nothing connected them, so the page could say an
  island is good at drills and that it wins fights, and never whether the first
  causes the second.

  If the gap predicts the winner, evolution is doing what this exhibit claims. If
  it does not, then exam skill does not transfer to combat — which for a research
  commons is the more interesting sentence, and no other chart here can produce
  it.

  ## ⚠ IT SAYS WHAT IT COULD NOT USE

  The stamp shipped after these islands had been fighting for days, and a fleet
  mid-roll carries both versions at once: a raid between an updated attacker and
  a defender still on the old image has one stamp and not the other. Those raids
  are excluded rather than drawn at a fabricated gap, and the count of them sits
  under the plot — a chart that silently drew what it had would answer a
  different question convincingly.
  """
  attr :raids, :list, required: true

  def experience(assigns) do
    %{points: points, excluded: excluded} = Dronex.WeighTheExperience.gaps(assigns.raids)
    span = Enum.map(points, & &1.gap)

    assigns =
      assign(assigns,
        lanes: Dronex.WeighTheExperience.lanes(points),
        n: length(points),
        excluded: excluded,
        reach: Enum.max([1 | Enum.map(span, &abs/1)])
      )

    ~H"""
    <div class="mt-6">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h3 class="text-sm font-semibold opacity-70">Does breeding longer win wars</h3>
        <span class="font-mono text-xs opacity-40">
          raider's breeding rounds, less the island's
        </span>
      </div>

      <div :if={@n > 0} class="instrument mt-2 space-y-2 p-3">
        <div :for={{lane, dots} <- @lanes} class="flex items-center gap-2">
          <span class="w-24 shrink-0 text-right text-xs opacity-50">{lane}</span>

          <div class="relative h-6 grow rounded-sm bg-base-300/40">
            <%!-- Zero is drawn, always. A strip plot of a difference with no
                  centre line is a cloud of numbers nobody can read a sign off. --%>
            <div class="absolute inset-y-0 left-1/2 w-px bg-base-content/30"></div>

            <div
              :for={p <- dots}
              class="absolute top-1/2 h-2 w-2 -translate-x-1/2 -translate-y-1/2 rounded-full opacity-70"
              style={"left: #{50 + p.gap / @reach * 46}%; background: #{lane_colour(lane)}"}
              title={"#{p.gap} rounds: raider #{p.attacker_rounds}, island #{p.defender_rounds}"}
            >
            </div>
          </div>

          <span class="w-6 shrink-0 text-right font-mono text-xs opacity-40">{length(dots)}</span>
        </div>

        <div class="flex justify-between px-24 font-mono text-[10px] opacity-30">
          <span>island bred longer</span>
          <span>raider bred longer</span>
        </div>
      </div>

      <p :if={@n == 0} class="instrument mt-2 p-3 text-xs opacity-50">
        Nothing to plot yet. A raid counts only when <strong>both</strong>
        sides carry a breeding stamp, and the stamp shipped after these islands
        had been fighting for days — so a raid between an updated attacker and an
        island still on the older image has one and not the other. {@excluded.unstamped} settled {(@excluded.unstamped ==
                                                                                                     1 &&
                                                                                                     "raid is") ||
          "raids are"} waiting
        on that, and {@excluded.unsettled} more {(@excluded.unsettled == 1 && "is") || "are"} still
        out. This fills as the fleet finishes rolling.
      </p>

      <p :if={@n > 0} class="mt-2 text-xs opacity-40">
        One dot per settled raid, placed by how much more the raider had bred than
        the island it attacked. {@n} raids plotted; <strong>{@excluded.unstamped} excluded</strong>
        because one side predates the stamp, and {@excluded.unsettled} still out.
        Measured in <strong>rounds</strong>
        and never generations: a captured genome enters at generation zero, so an
        island that absorbs a swarm has its generation cut without having bred any
        less.
      </p>
    </div>
    """
  end

  @doc """
  Whether the radio matters. The only causal number this fleet publishes.

  ## ⚠ WHY THIS OUTRANKS EVERY OTHER CHART HERE

  Every other number on this page is an observation: who won, what died, what the
  towers held. This one is an EXPERIMENT. The island re-runs the same engagements
  with a channel silenced and reports the difference, which is the same genome
  against the same opponents with one thing changed — so it is immune to the
  hardware confound that makes every cross-island comparison on this page
  suspect, and it is the only thing here that can answer *why* rather than
  *what*.

  It has been published every second since the channel shipped, and until now the
  page did not draw it. `DESIGN_DRONES_THAT_TALK.md` asks the question; the
  exhibit could not answer it.

  ## The sign, said out loud, because a reader cannot guess it

  `delta = baseline − muted`, both being the attacker's points percentage (a win
  is 2, a draw 1, a loss 0, over twice the engagements). So **positive means
  silencing that channel made the attacker WORSE**, which is the channel carrying
  weight. Zero means the channel is being driven and nothing depends on it.
  Negative means the swarm did better once it stopped talking.

  ## ⚠⚠ AND THE RESOLUTION IS COARSE, WHICH THE PANEL SAYS

  The delta comes from a handful of engagements, so it moves in steps of about 25
  points: **one fight changing hands is a whole step**. The count beside each row
  is how many ablation exercises have been RUN, not how many went into the number
  shown — the wire carries the last exercise only. A reader who takes ±25 here
  for a result is being misled, so the panel says so rather than letting the bar
  do the talking.

  ## Void is not zero

  Signal volume of zero means nothing was ever transmitted, so a claim about
  coordination for that period is VOID rather than null — the island publishes
  that as its own flag precisely so the two cannot be confused, and drawing it as
  a zero bar would undo the distinction on the way to the screen.
  """
  attr :islands, :list, required: true

  def comms(assigns) do
    ~H"""
    <div class="mt-6">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h3 class="text-sm font-semibold opacity-70">Does the radio matter</h3>
        <span class="font-mono text-xs opacity-40">
          silencing a channel · + means the swarm got worse without it
        </span>
      </div>

      <div class="instrument mt-2 overflow-x-auto p-3">
        <table class="table table-xs">
          <thead>
            <tr class="text-xs opacity-50">
              <th>island</th>
              <th class="text-center">air</th>
              <th class="text-center">ground</th>
              <th class="text-center">all</th>
              <th class="text-right">runs</th>
              <th class="text-right">volume</th>
              <th class="text-right">entropy</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @islands}>
              <td><.island_name row={row} /></td>

              <%!-- ⚠ VOID SPANS THE ARMS RATHER THAN DRAWING THREE ZEROES.
                    Nothing was transmitted, so there is no measurement to plot,
                    and three empty bars would read as "the channel does not
                    matter" — which is the one thing this cannot say. --%>
              <td :if={void?(row)} colspan="3" class="text-center text-xs opacity-40">
                nothing transmitted · not measurable
              </td>

              <td :for={arm <- (!void?(row) && ~w(air ground all)) || []} class="px-1">
                <.delta_spread
                  points={ablation(row, arm)}
                  samples={sampled(row, arm)}
                  weighed={weighed(row, arm)}
                />
              </td>

              <td class="text-right font-mono text-xs opacity-60">{ablation(row, "runs")}</td>
              <td class="text-right font-mono text-xs opacity-40">{ablation(row, "volume")}</td>
              <td class="text-right font-mono text-xs opacity-40">{ablation(row, "entropy")}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <details class="mt-2">
        <summary class="cursor-pointer text-xs opacity-40">
          How this is measured, and why ±25 is not a result
        </summary>
        <p class="mt-2 text-xs opacity-50">
          An island re-runs the same engagements with one channel silenced and
          reports the difference in the raider's score. Same genome, same
          opponents, one thing changed — which makes it the only number here
          immune to the hardware differences between these machines, and the only
          one that can answer <em>why</em>
          rather than <em>what</em>.
          <span class="mt-2 block">
            ⚠ It is measured over a handful of engagements, so it moves in steps
            of about 25 points and <strong>one fight changing hands is a whole
            step</strong>.
            <span class="mt-2 block">
              <strong>Each dot is one exercise, not one sample.</strong>
              The wire republishes a result until the next is run and the board
              samples every 30 seconds, so a single exercise used to be drawn up
              to eighty times: a cloud whose weight came from the sampling rate
              rather than from evidence. Consecutive repeats are collapsed and the
              count that survives is printed as <code>n</code>. The run count in
              the table is how many exercises the ISLAND has run, which is far
              larger than how many distinct results have reached this page.
            </span>
            Treat a single ±25 as noise. What would settle it is the same sign
            holding over many, which is why nothing is claimed below eight.
          </span>
          <span class="mt-2 block">
            <strong>Volume</strong>
            is how much was transmitted and <strong>entropy</strong>
            is in millibits over sixteen buckets: a
            channel driven with a constant is silence wearing a signal's clothes,
            and it would pass a volume test. Talking, saying something, and it
            mattering are three different facts.
          </span>
        </p>
      </details>
    </div>
    """
  end

  # ⚠ THIS IS WHAT SETTLES WHETHER THE RADIO MATTERS.
  #
  # A single exercise moves in steps of about 25, so one reading cannot tell "the
  # channel carries weight" from "one fight changed hands". Neither can two. What
  # can is the SHAPE of many: a channel that matters sits off zero and stays
  # there; noise scatters across it.
  #
  # Every sampled reading is drawn rather than summarised. A mean alone would
  # hide the one thing worth seeing — whether the readings AGREE — and a fitted
  # bell would be worse: over a handful of coarsely quantised values it asserts a
  # generating process nobody has established. The dots are what was measured.
  # What each channel has actually measured, as opposed to how often the board
  # sampled it. Computed once per island rather than once per cell.
  # ⚠ THE COLUMN IS A STRING AND THE CHANNEL IS AN ATOM. Comparing them directly
  # never matches, so every cell fell silently through to the old renderer and
  # the panel looked unchanged. `sampled/2` converts for the same reason.
  defp weighed(row, arm) do
    key = String.to_existing_atom(arm)

    row.id
    |> Dronex.history()
    |> Dronex.WeighTheRadio.weigh()
    |> Enum.find(%{n: 0}, &(&1.channel == key))
  end

  attr :points, :integer, required: true
  attr :samples, :list, default: []
  attr :weighed, :map, default: %{n: 0}

  # ⚠ ONE DOT PER MEASUREMENT, NOT PER SAMPLE, and the difference was the whole
  # panel. The wire republishes one exercise until the next runs and the board
  # samples every 30 seconds, so 240 samples were between THREE and EIGHT
  # measurements drawn up to eighty times each. The cloud looked like a
  # distribution and its weight came from the sampling rate.
  #
  # `WeighTheRadio` collapses consecutive repeats and reports what is left, with
  # `n` beside it, because on a measure that moves in steps of about 25 the count
  # of exercises is more of the story than their average.
  defp delta_spread(%{weighed: %{n: n}} = assigns) when n >= 1 do
    ~H"""
    <div
      class="relative mx-auto h-4 w-24 rounded-sm bg-base-300/40"
      title={"#{Dronex.WeighTheRadio.reading(@weighed)}, from #{@weighed.low} to #{@weighed.high}"}
    >
      <div class="absolute inset-y-0 left-1/2 w-px bg-base-content/30"></div>

      <div
        :for={{v, i} <- Enum.with_index(@weighed.readings)}
        class="absolute h-1.5 w-1.5 -translate-x-1/2 rounded-full opacity-70"
        style={"left: #{50 + min(max(v, -100), 100) / 2}%; top: #{3 + rem(i, 6) * 2}px; background: var(--chart-cat-3)"}
      >
      </div>

      <div
        class="absolute inset-y-0 w-0.5"
        style={"left: #{50 + min(max(@weighed.mean, -100), 100) / 2}%; background: var(--chart-cat-2)"}
      >
      </div>

      <%!-- ⚠ `n` ON THE FACE OF IT. Three readings scattered across zero is
            noise, and nothing else on this strip says how many there are. --%>
      <span class="absolute -right-6 top-0 font-mono text-[10px] opacity-40">n{@weighed.n}</span>
    </div>
    """
  end

  # ⚠ SCALED TO THE FULL POSSIBLE RANGE, NEVER TO THE DATA. The score is a
  # percentage, so ±100 is the honest half-width; fitting the axis to the ±25
  # actually observed would draw one fight changing hands as a full bar.
  defp delta_spread(assigns) do
    assigns = assign(assigns, width: min(abs(assigns.points), 100) / 2)

    ~H"""
    <div
      class="relative mx-auto h-4 w-24 rounded-sm bg-base-300/40"
      title={"#{@points} points of raider score"}
    >
      <div class="absolute inset-y-0 left-1/2 w-px bg-base-content/30"></div>

      <div
        :if={@points != 0}
        class="absolute inset-y-0.5 rounded-sm"
        style={bar_style(@points, @width)}
      >
      </div>

      <span
        :if={@points == 0}
        class="absolute inset-0 flex items-center justify-center font-mono text-[10px] opacity-40"
      >
        0
      </span>
    </div>
    """
  end

  # ⚠ SIGN, NOT SIDE. Left is "the swarm flew better silent" and right is "the
  # radio helped". This used the blue/rose generic pair, which on a page that
  # teaches red=raider and blue=island reads as two sides rather than two
  # directions. Orange and green are neither.
  defp bar_style(points, width) when points > 0,
    do: "left: 50%; width: #{width}%; background: var(--chart-cat-3)"

  defp bar_style(_points, width),
    do: "right: 50%; width: #{width}%; background: var(--chart-cat-2)"

  # ⚠ THE TRAJECTORY, NOT THE LATEST. The wire republishes one exercise; the
  # board samples it every 30s, so this is the only place readings accumulate.
  defp sampled(row, arm) do
    key = String.to_existing_atom(arm)
    row.id |> Dronex.history() |> Enum.map(&Map.get(&1, key, 0))
  end

  defp void?(row), do: (Dronex.fact(row, :vitals) || %{})["ablation_void"] == true

  defp ablation(row, key) do
    v = Dronex.fact(row, :vitals) || %{}

    case key do
      "runs" -> num(v, "ablations")
      "volume" -> num(v, "signal_volume")
      "entropy" -> num(v, "signal_entropy")
      arm -> num(v, "ablation_delta_" <> arm)
    end
  end

  @doc """
  Who raided whom, as a table. This replaced the map.

  ## ⚠ THE MAP DREW A HASH AS GEOGRAPHY

  Islands sat at positions derived from a hash of their names — `Archipelago`
  said so plainly — so distance, adjacency and the length of a raid arc encoded
  NOTHING. Four real facts were wrapped in a coordinate system that carried no
  information, and the wrapping was the part that looked impressive. Every one of
  those facts is in this table and the invented geography is not.

  ## ⚠⚠ THE ARCHIPELAGO TOTAL HIDES THE DIRECTION

  Over the recordings held, the winner runs close to even, which reads as a coin
  flip and is why the fights looked like they carried nothing. That is the SUM
  over every pair. An island that beats one neighbour and is beaten by another is
  invisible in a total and obvious in a grid.

  Rows attack, columns defend, and the record in a cell is the ROW's — a table
  whose two axes mean different things is a table nobody can read.
  """
  attr :islands, :list, required: true
  attr :raids, :list, required: true
  attr :focus, :string, default: nil

  def ledger(assigns) do
    pairs = Dronex.ReadTheLedger.pairs(assigns.raids)

    assigns =
      assign(assigns,
        pairs: pairs,
        busiest: Dronex.ReadTheLedger.busiest(pairs),
        ordered: Enum.sort_by(assigns.islands, &Dronex.label/1)
      )

    ~H"""
    <div class="mt-3">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h3 class="text-sm font-semibold opacity-70">Who raids whom</h3>
        <span class="font-mono text-xs opacity-40">rows are the raider · columns are the island</span>
      </div>

      <div class="instrument mt-2 overflow-x-auto p-3">
        <div
          id="who-raids-whom"
          phx-hook="DronexChart"
          phx-update="ignore"
          class="h-72 w-full"
          role="img"
          aria-label={matrix_spoken(@ordered, @pairs)}
          data-spec={matrix_spec(@ordered, @pairs, @busiest)}
        >
        </div>

        <%!-- ⚠ THE NUMBERS STAY REACHABLE. A canvas is not readable by a screen
              reader and is not selectable, so the grid keeps a table beside it
              rather than instead of it. --%>
        <details class="mt-2">
          <summary class="cursor-pointer text-xs opacity-40">The routes, as a table</summary>
          <table class="mt-2 text-xs">
            <thead>
              <tr class="opacity-50">
                <th class="pr-3 text-left font-normal">raider</th>
                <th class="pr-3 text-left font-normal">island</th>
                <th class="pr-3 text-right font-normal">raids</th>
                <th class="pr-3 text-right font-normal">won</th>
                <th class="text-right font-normal">held</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{{a, d}, c} <- Enum.sort_by(@pairs, fn {_k, c} -> -c.raids end)}>
                <td class="pr-3">{Dronex.TellIslandsApart.spoken_id(a)}</td>
                <td class="pr-3">{Dronex.TellIslandsApart.spoken_id(d)}</td>
                <td class="pr-3 text-right font-mono tabular-nums">{c.raids}</td>
                <td class="pr-3 text-right font-mono tabular-nums">{c.wins}</td>
                <td class="text-right font-mono tabular-nums">{c.losses}</td>
              </tr>
            </tbody>
          </table>
        </details>
      </div>

      <p class="mt-2 text-xs opacity-40">
        Each cell is the row island raiding the column island. <strong>Red where the raider prevails</strong>, blue where the island
        holds, grey where it is even, and the number on it is how many raids have
        been fought there. A <strong>faded</strong>
        cell has fewer than three decided raids and is not claiming a direction,
        because one raid won is 100%. Hover for the full numbers, or open the
        table below. A raid
        still out: both sides commit on acceptance and the defender publishes the
        recording when it ends, so a pair with commitments and no recording is
        either in flight or one whose defender went dark, which look the same from
        here.
      </p>
    </div>
    """
  end

  # ⚠ NO DATA IS NOT A ZERO ROUTE. A pair that has never fought must not shade
  # like one that fought and always lost.
  # ⚠ THE ARCS ARE THE LIBRARY'S NOW. What stood here computed SVG pie slices by
  # hand: sin, cos, large-arc flags, and a special case for a slice that is the
  # whole circle, which was wrong on the first attempt and draws nothing at all
  # when it is wrong. ECharts was vendored an hour before this was written.
  #
  # The server sends the DATA and the browser builds the chart, because the
  # colours are CSS custom properties and only resolve there.
  defp matrix_spec(ordered, pairs, busiest) do
    Jason.encode!(%{
      kind: "matrix",
      busiest: max(busiest || 1, 1),
      rows: Enum.map(ordered, &Dronex.TellIslandsApart.spoken/1),
      cols: Enum.map(ordered, &Dronex.TellIslandsApart.spoken/1),
      cells: cells_of(ordered, pairs)
    })
  end

  defp cells_of(ordered, pairs) do
    for {a, r} <- Enum.with_index(ordered),
        {d, c} <- Enum.with_index(ordered),
        a.id != d.id,
        cell = pairs[{a.id, d.id}],
        # ⚠ IN FLIGHT COUNTS AS SOMETHING HAPPENING. A pair with commitments and
        # no recording is fighting right now, and filtering on settled raids alone
        # drew it as a pair that has never met.
        cell && (cell.raids > 0 or cell.in_flight > 0) do
      %{
        r: r,
        c: c,
        n: cell.raids,
        a: cell.wins,
        d: cell.losses,
        # A draw cost both sides and settled nothing, and it is part of what
        # happened on that route.
        x: cell.raids - cell.wins - cell.losses,
        f: cell.in_flight,
        of: "#{Dronex.TellIslandsApart.spoken(a)} → #{Dronex.TellIslandsApart.spoken(d)}"
      }
    end
  end

  # A canvas says nothing to a screen reader, so the shape of the grid is spoken.
  defp matrix_spoken(ordered, pairs) do
    fought = Enum.count(pairs, fn {_k, c} -> c.raids > 0 end)
    "who raids whom, #{length(ordered)} islands, #{fought} routes fought"
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

      <div class="instrument mt-2 overflow-x-auto p-3">
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
              <td class="whitespace-nowrap py-0.5 pr-2 text-right font-mono opacity-70">
                <.island_name row={row} />
                <%!-- ⚠ AN ISLAND SITTING A CAPTURED CHAMPION IS NOT REPORTING ITS
                      OWN BREEDING. `roster:best/1` sits the exam and a raid
                      admits foreign genomes into the roster it is chosen from. --%>
                <span
                  :if={sitter(row) == "captured"}
                  class="ml-1 text-[10px] opacity-60"
                  title="this island's exam was sat by a controller it captured, not one it bred"
                >
                  captured
                </span>
              </td>
              <td :for={{wins, starts, lost, drew} <- rung_cells(row)} class="p-0.5">
                <div
                  class={[
                    "flex h-7 w-14 items-center justify-center rounded-sm border",
                    (@focus == row.id && "border-primary/60") || "border-base-300"
                  ]}
                  title={"#{Dronex.TellIslandsApart.spoken(row)}: #{wins} won, #{drew} drawn, #{lost} lost of #{starts}"}
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

  # ⚠ WINS ALONE MADE "LOST IT" AND "DREW IT" THE SAME CELL. On a graded ladder
  # those are different findings: a drone that draws the sniper held station and
  # could not finish; one that lost it was killed.
  defp rung_cells(row) do
    v = Dronex.fact(row, :vitals) || %{}
    starts = num(v, "benchmark_starts")
    losses = Map.get(v, "benchmark_losses", [])
    draws = Map.get(v, "benchmark_draws", [])

    Map.get(v, "benchmark_wins", [])
    |> Enum.with_index()
    |> Enum.map(fn {wins, i} ->
      {wins, starts, Enum.at(losses, i, 0), Enum.at(draws, i, 0)}
    end)
  end

  defp sitter(row), do: (Dronex.fact(row, :vitals) || %{})["benchmark_sitter"]

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
  attr :focus, :string, default: nil
  attr :focused, :any, default: nil
  attr :readings, :map, required: true

  def one_world(assigns) do
    assigns =
      assign(assigns,
        shown: assigns.standings,
        rungs: rungs_of(assigns.islands),
        ordered_islands: Enum.sort_by(assigns.islands, &Dronex.label/1)
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
          aria-label={"showing #{Dronex.TellIslandsApart.spoken(@focused)} only. Activate to show every island."}
        >
          showing <.island_name row={@focused} class="" /> <span aria-hidden="true">✕</span>
        </button>

        <span :if={!@focused} class="text-xs opacity-40">
          every island · pick one on the map or in the table
        </span>
      </div>

      <.at_a_glance islands={@islands} raids={@raids} />
      <.ledger islands={@islands} raids={@raids} focus={@focus} />
      <.how_long_fights_last raids={@raids} />

      <.comms islands={@ordered_islands} />

      <.experience raids={@raids} />

      <.captures islands={@ordered_islands} />

      <.exam_profiles islands={@islands} />
      <.champions standings={@shown} />
      <.leaderboard standings={@shown} focus={@focus} />

      <%!-- ⚠ FLEET-SCOPED, SO IT LIVES WITH THE FLEET. This sat on the per-island
            Exam tab, which was wrong twice: it is every island against every
            drill, so a per-island panel is the wrong home for it, and burying the
            most informative thing on the page two clicks behind a video player
            meant a visitor landed on a canvas and one small bar. --%>
      <.ladder :if={@rungs != []} islands={@islands} focus={@focus} rungs={@rungs} />

      <%!-- ⚠ FLEET-WIDE, WHICH IS WHY THEY MOVED HERE. Both of these described
            whichever fight was selected, so both were n=1. Measured at ingest
            and accumulated they describe every raid the board has seen, and the
            `n` is printed on them because the raids are a rolling window rather
            than a sample anybody chose. --%>
      <BeamCampusWeb.DronexFight.losses :if={@readings.damage} readings={@readings} />
      <BeamCampusWeb.DronexFight.coverage :if={@readings.coverage} readings={@readings} />
    </section>
    """
  end

  # The ladder's column headings come from whichever island has sat the exam;
  # they are the same six drills for everyone, and an island that has not sat it
  # publishes none.
  defp rungs_of(islands) do
    Enum.find_value(islands, [], fn row ->
      case Map.get(Dronex.fact(row, :vitals) || %{}, "benchmark_rungs", []) do
        [] -> nil
        rungs -> rungs
      end
    end)
  end

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
  attr :watchable, :list, required: true
  attr :watching, :any, default: nil
  attr :focused, :any, default: nil
  attr :islands, :list, default: []

  def island_panel(assigns) do
    ~H"""
    <section class="mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <%!-- ⚠ A STABLE HOOK, because a test that finds this heading by its CLASS finds
             whichever section was added most recently instead. That has now happened
             twice in one day: once when the name grew a span and once when a second
             `h2' with the same classes appeared above it. --%>
        <h2 data-panel-heading class="text-base font-semibold">
          <.island_name :if={@focused} row={@focused} class="" />
          <span :if={!@focused}>Every island</span>
        </h2>

        <span :if={@panel != :fights and !@selected?} class="text-xs opacity-40">
          <.island_name row={@row} class="" />, shown because nothing is selected
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

  # ⚠ THE LANES ARE THE SIDES. `WeighTheExperience.lanes/1` names them "raider
  # won", "drawn" and "island held", and every dot in all three was drawn in the
  # same blue, so the page's flagship chart was set to contradict the histogram
  # directly above it on the day it finally gets data.
  defp lane_colour("raider won"), do: "var(--side-attacker)"
  defp lane_colour("island held"), do: "var(--side-defender)"
  defp lane_colour(_drawn), do: "var(--side-draw)"

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
