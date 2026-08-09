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

  import BeamCampusWeb.DronexChrome, only: [island_name: 1, dronex_state: 1, nav: 1]
  import BeamCampusWeb.DronexMasterProfile, only: [master_profile: 1]

  @redraw_ms 500

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Dronex.subscribe()

    {:ok,
     socket
     # Without this the tab, the history entry and every shared link read as the
     # site's generic title, so four different workbench pages are one bookmark.
     |> assign(page_title: "DroneX")
     |> assign(dirty?: false, focus: nil, panel: :exam)
     |> load()}
  end

  # ⚠ THE PANEL IS `:exam' OR `:vitals' AND THERE IS NO `:fights' ANY MORE. The
  # player has its own route, so a tab that used to open it now sends you there.
  # An old link carrying `?panel=fights' lands on the exam, which is the closest
  # true thing this page can show it.
  defp panel_of("vitals"), do: :vitals
  defp panel_of(_exam), do: :exam

  defp dronex_path(island, panel), do: ~p"/research/workbench/dronex?#{query(island, panel)}"

  defp query(nil, panel), do: [panel: panel]
  defp query(island, panel), do: [island: island, panel: panel]

  @impl true
  def handle_event("focus_island", %{"id" => id}, socket) do
    {:noreply,
     push_patch(socket,
       to: dronex_path(toggled(socket.assigns.focus, id), socket.assigns.panel)
     )}
  end

  def handle_event("show_panel", %{"panel" => panel}, socket) do
    {:noreply, push_patch(socket, to: dronex_path(socket.assigns.focus, panel_of(panel)))}
  end

  # ⚠ ISLANDS, RAIDS AND THE STANDINGS. No watchable list, no 1.2 MB recording,
  # no fleet readings: all three belong to the fights route now, and this page
  # pulled every one of them on every redraw whichever tab was open.
  defp load(socket) do
    islands = Dronex.islands()
    focus = socket.assigns[:focus]

    assign(socket,
      islands: islands,
      raids: Dronex.raids(),
      focused: Enum.find(islands, &(&1.id == focus)),
      ranked: ranked(),
      state: Dronex.state(),
      refused: Dronex.refused()
    )
  end

  # The island whose per-island panel is shown when nothing is selected. First
  # come, first shown: with no fight to prefer, any choice is arbitrary and the
  # panel says out loud which one it picked.
  defp showing(islands, focus) do
    Enum.find(islands, fn i -> i.id == focus end) || List.first(islands)
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, shown: showing(assigns.islands, assigns.focus))

    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- ⚠ WIDER THAN THE REST OF THE SITE, ON PURPOSE. `max-w-5xl' is right
           for prose and wrong for this: a workbench whose main content is a data
           table earns the extra 256px. --%>
      <div class="workbench mx-auto max-w-7xl px-4 py-10">
        <.header>
          DroneX
          <:subtitle>
            <strong>Islands breeding drone controllers, and how well they actually fly.</strong>
            A drone is a quadcopter with a battery, a forward sensor that cannot
            see behind it, one unguided weapon effective inside about fifteen
            metres and two guided interceptors that reach about sixty. None of
            how it flies is written down: the controller is a neural network, and
            an island breeds them continuously against a set of scripted drills.
          </:subtitle>
        </.header>

        <.nav current={:archipelago} focus={@focus} />

        <.dronex_state state={@state} refused={@refused} />

        <div class="settle" style="animation-delay: 40ms">
          <.one_world
            :if={@islands != []}
            islands={@islands}
            raids={@raids}
            standings={@ranked}
            focus={@focus}
            focused={@focused}
          />
        </div>

        <div class="settle" style="animation-delay: 120ms">
          <.island_panel :if={@shown} row={@shown} panel={@panel} selected?={@focus != nil} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  @doc """
  Everything about the fleet as a whole, which is what this page is for.

  ⚠ **THE DRILL MATRIX IS ON THE LANDING VIEW AND MUST STAY THERE.** It sat on
  the per-island Exam tab once, so the most informative diagram on the page was
  two clicks behind a video player and a visitor landed on a canvas and one
  small bar. Moving it to a fourth route would be the same mistake by a
  different mechanism, so the split left it here and moved the fights, the raids
  and the radio away from it instead.
  """
  attr :islands, :list, required: true
  attr :raids, :list, required: true
  attr :standings, :list, required: true
  attr :focus, :string, default: nil
  attr :focused, :any, default: nil

  def one_world(assigns) do
    assigns =
      assign(assigns,
        rungs: rungs_of(assigns.islands, :curriculum),
        held_out_rungs: rungs_of(assigns.islands, :held_out)
      )

    ~H"""
    <section class="mt-6">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h2 class="text-sm font-semibold opacity-80">One world</h2>

        <%!-- ⚠ THE SELECTION SAID IN WORDS. A filter you cannot see is a page
              that looks broken to whoever forgot it was on, and nothing else
              here tells you how to clear it. --%>
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
          every island · pick one in the table
        </span>
      </div>

      <.at_a_glance islands={@islands} raids={@raids} />

      <%!-- ⚠ THE HELD-OUT EXAM COMES FIRST, AND THE ORDER IS THE ARGUMENT. The
            curriculum ladder is saturated — four of five islands at 47 or 48 of
            48 on every rung — and it is also inside the training set, so it is
            the weaker of the two on both counts. Drawing it first would make the
            flat one the headline and the informative one the footnote.
            ⚠⚠ AND BOTH ARE DRAWN, NEVER ONE. An island on a build older than
            fact version 5 publishes no held-out profile at all, so a page that
            showed only the new one would go blank for half a fleet mid-deploy. --%>
      <%!-- ⚠ AND THE MASTER TOURNAMENT COMES BEFORE BOTH OF THEM, ON THE SAME
            ARGUMENT. Both scripted ladders are FLOOR tests the fleet has
            cleared: one is saturated and the other is a fixed six. This is the
            one measure here that cannot saturate, because its opponents are the
            invaders that actually raided the island and they keep arriving. It
            is also the only panel that can distinguish progress from a
            treadmill, which is the question the whole archipelago is asking. --%>
      <.master_profile islands={@islands} />

      <.exam_profiles islands={@islands} exam={:held_out} />
      <.ladder
        :if={@held_out_rungs != []}
        islands={@islands}
        focus={@focus}
        rungs={@held_out_rungs}
        exam={:held_out}
      />

      <.champions standings={@standings} />
      <.leaderboard standings={@standings} focus={@focus} />

      <.exam_profiles islands={@islands} exam={:curriculum} />
      <.ladder :if={@rungs != []} islands={@islands} focus={@focus} rungs={@rungs} />
    </section>
    """
  end

  # The ladder's column headings come from whichever island has sat the exam;
  # they are the same rungs for everyone, and an island that has not sat it
  # publishes none.
  defp rungs_of(islands, exam) do
    key = prefix(exam) <> "_rungs"

    Enum.find_value(islands, [], fn row ->
      case Map.get(Dronex.fact(row, :vitals) || %{}, key, []) do
        [] -> nil
        rungs -> rungs
      end
    end)
  end

  @doc """
  One island's own numbers and their trajectories.

  ⚠ **NO "HISTORY" TAB, AND NO "FIGHTS" TAB EITHER.** A chart of the roster
  belongs beside the roster and a chart of the exam beside the exam, not in a
  third place that makes you hold a number in your head while you go and look at
  its trajectory. The fights tab held a player that is now a route of its own,
  for the same reason in the opposite direction: it was the heaviest thing on
  the page and everybody paid for it whether or not they were watching.
  """
  attr :row, :map, required: true
  attr :panel, :atom, default: :exam
  attr :selected?, :boolean, default: false

  def island_panel(assigns) do
    ~H"""
    <section class="mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <%!-- ⚠ A STABLE HOOK, because a test that finds this heading by its CLASS
             finds whichever section was added most recently instead. That has
             happened twice in one day. --%>
        <h2 data-panel-heading class="text-base font-semibold">
          <.island_name row={@row} class="" />
        </h2>

        <span :if={!@selected?} class="text-xs opacity-40">
          shown because nothing is selected
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

      <.vitals row={@row} panel={@panel} />
    </section>
    """
  end

  defp panels, do: [{:exam, "Exam"}, {:vitals, "Vitals"}]

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(focus: params["island"], panel: panel_of(params["panel"]))
     |> load()}
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

  defp toggled(same, same), do: nil
  defp toggled(_was, id), do: id

  # ⚠ RANKED OVER EVERY ISLAND, AND NUMBERED HERE. The table below may be
  # filtered to whatever the map is showing, and a rank that renumbered under
  # that filter would be measuring the viewport rather than the archipelago.
  defp ranked do
    Dronex.leaderboard()
    |> Enum.with_index(1)
    |> Enum.map(fn {standing, place} -> Map.put(standing, :rank, place) end)
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
  attr :exam, :atom, default: :curriculum

  def exam_profiles(assigns) do
    spec = Dronex.CompareTheExams.profiles(assigns.islands, prefix(assigns.exam))
    assigns = assign(assigns, spec: spec, held_out?: assigns.exam == :held_out)

    ~H"""
    <section :if={@spec.drills != []} class="settle mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h2 class="instrument-lede text-base font-semibold">
          {(@held_out? && "What each island can actually do") ||
            "What each island can do against its own curriculum"}
        </h2>
        <span class="font-mono text-xs opacity-40">
          {(@held_out? && "held out · the rungs, easiest first") ||
            "trained against · the drills, easiest first"}
        </span>
      </div>

      <%!-- ⚠ THE EXAM IS IN THE ID, because `one_world/1` renders this component
            TWICE, held-out and curriculum, and a hardcoded id put two elements
            carrying the same phx-hook on every page where both exams had data.
            LiveView keys its DOM on id, and the browser resolves
            `getElementById` to whichever came first. `exam_ladder/1` two hundred
            lines up already interpolates its row id and was the model this
            should have copied. --%>
      <div class="instrument mt-2 p-3">
        <div
          id={"exam-profiles-#{@exam}"}
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
        <span :if={@held_out?}>
          This is the only <strong>absolute</strong>
          measure here: six fixed opponents <strong>nothing trains against</strong>, each sat the same
          number of times. Raids cannot do this job, because every island can
          improve at once and the win rate stays near a coin flip.
        </span>
        <span :if={!@held_out?}>
          ⚠ These six are also six of the opponents each island <strong>breeds against</strong>, so this is performance against the
          curriculum and not improvement. It was described as held out for months
          and was never enforced as such; between about 11% and 28% of breeding
          rounds draw one of these as an opponent. It is kept because a number
          withdrawn leaves a hole in a history and a number labelled leaves a
          record.
        </span>
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
  Which controllers crossed the mesh.

  ⚠ THE CLAIM THIS EXHIBIT IS FOR. `CHARTER.md` makes a raid the way opponent
  diversity crosses the mesh, and for most of this track's life the page could
  only draw captures as a number going up. A genome id is the sha256 of its
  packed form, so a controller named here on an island that did not breed it is
  the same controller and not a resemblance.

  ⚠⚠ IT REPORTED ZERO FOR TWO DIFFERENT REASONS IN SUCCESSION, and neither was
  about the world. First a captured genome entered at fitness 0 and nothing ever
  re-scored it, so it could never be `roster:best/1` and never be champion:
  `REGISTER I.25`. Then, once that was fixed, the count was taken inside a top
  ten ranked on tenure — and a controller that has just crossed has by definition
  just arrived, so it sorted last and fell off the limit.

  ⚠⚠⚠ A RANKED TABLE OF CHAMPIONS WAS DELETED FROM HERE ON 2026-08-09. Measured
  over all 207 controllers it had recorded, `islands` was 1 for every one and was
  its primary sort key, `sorties` was 0 for 166, `generation` is not comparable
  across islands, and its journey column printed one island name per row. Worse,
  it ranked on tenure, and a champion is displaced the moment its island finds
  something better — so it sorted the most STAGNANT island to the top and read as
  a table of the best controllers.
  """
  attr :standings, :list, default: []

  def champions(assigns) do
    assigns =
      assign(assigns,
        # ⚠ OVER EVERY REIGN, NOT OVER A RANKED TOP TEN. Counting inside the
        # ranking made this permanently zero: a controller that has just crossed
        # holds one island and has held it for seconds, so it sorted last and
        # fell off the limit. The headline read "0 of 10 crossed the mesh" while
        # crossings sat in the very table it was counting over.
        crossed: Dronex.FollowTheChampions.crossed(),
        seen: Dronex.FollowTheChampions.counted() || 0,
        crossings: Dronex.FollowTheChampions.crossings(12)
      )

    ~H"""
    <section :if={@seen > 0} class="settle mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h2 class="instrument-lede text-base font-semibold">Which controllers crossed the mesh</h2>
        <span class="font-mono text-xs opacity-40">
          {@crossed} of {@seen} controllers seen
        </span>
      </div>

      <%!-- ⚠⚠ A RANKED TABLE OF CHAMPIONS STOOD HERE AND WAS DELETED ON
            2026-08-09, BECAUSE FOUR OF ITS FIVE COLUMNS CARRIED NOTHING.
            Measured over all 207 controllers it had ever recorded: `islands` was
            1 for every one of them and was the PRIMARY SORT KEY; `sorties` was
            0 for 166; `generation` is lineage depth and is not comparable across
            islands, which is why it had already been removed from the
            leaderboard; and "where it has been" printed a single island name on
            every row, so the journey it promised never appeared.

            ⚠⚠⚠ AND IT RANKED THE OPPOSITE OF WHAT IT SEEMED TO. A champion is
            displaced the moment its island breeds or captures something better,
            so tenure is TIME SINCE THAT ISLAND LAST IMPROVED. Sorting champions
            by it puts the most stagnant island at the top and reads as a table
            of the best controllers.

            What is left is the thing the panel was built for. --%>
      <ul :if={@crossings != []} class="instrument mt-2 grid gap-1 p-3">
        <li :for={r <- @crossings} class="font-mono text-xs">
          <span class="opacity-70">{String.slice(r.genome_id, 0, 8)}</span>
          <span class="opacity-40">bred on</span>
          {Dronex.TellIslandsApart.spoken_id(r.taken_from)}
          <span class="opacity-40">· now holding</span>
          {r.island}
          <span class="opacity-40">· {held_for(r.last_seen - r.first_seen)}</span>
        </li>
      </ul>

      <p :if={@crossings == []} class="instrument mt-2 p-3 text-xs opacity-50">
        No controller has yet been taken in a raid and then become good enough,
        on the island that took it, to be its champion. That is the archipelago's
        one idea in its most literal form, so this staying empty is a finding
        rather than a gap.
      </p>

      <p class="mt-2 max-w-3xl text-xs opacity-50">
        A controller is identified by the <strong>sha256 of its packed genome</strong>, so this is the same controller and not a
        resemblance. It was taken in a raid, entered the local roster as an
        opponent, and then beat everything its captor could breed against it.
      </p>
    </section>
    """
  end

  # A tenure of seconds is a champion that was displaced immediately, and reading
  # it as "0m" would lose that. Minutes once there are any.
  defp held_for(ms) when ms < 60_000, do: "#{div(ms, 1000)}s"
  defp held_for(ms) when ms < 3_600_000, do: "#{div(ms, 60_000)}m"
  defp held_for(ms), do: "#{div(ms, 3_600_000)}h"

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
  attr :exam, :atom, default: :curriculum

  def ladder(assigns) do
    assigns = assign(assigns, held_out?: assigns.exam == :held_out)

    ~H"""
    <div class="mt-6">
      <h3 class="text-sm font-semibold opacity-70">
        {(@held_out? && "Every island, every held-out rung") || "Every island, every drill"}
      </h3>

      <%!-- ⚠ WHICH EXAM, SAID ON THE DIAGRAM. Two matrices of the same shape sit
            one above the other and they mean opposite things: the one below is
            performance against opponents the island breeds against, and the one
            above is the only measure here that may be called improvement. --%>
      <p class="mt-1 text-xs opacity-50">
        <span :if={@held_out?}>
          Nothing trains against these. Every rung shoots <strong>and</strong>
          closes, which is where the fleet's deficit survived once the curriculum
          saturated.
        </span>
        <span :if={!@held_out?}>
          ⚠ Six of the opponents each island breeds against, so a high score here
          is familiarity as much as skill. <code>REGISTER I.22</code>.
        </span>
      </p>

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
              <td :for={{wins, starts, lost, drew} <- rung_cells(row, @exam)} class="p-0.5">
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
  # ⚠ ONE WORD SEPARATES THE TWO EXAMS ON THE WIRE, and everything that reads
  # either of them goes through here rather than spelling a key inline. The
  # curriculum is `benchmark_*` and the held-out ladder is `trials_*`; a panel
  # that reached for the wrong one would draw a real number under the wrong
  # heading, which is the only failure mode here a reader cannot catch.
  defp prefix(:held_out), do: "trials"
  defp prefix(_curriculum), do: "benchmark"

  defp rung_cells(row, exam) do
    v = Dronex.fact(row, :vitals) || %{}
    p = prefix(exam)
    starts = num(v, p <> "_starts")
    losses = Map.get(v, p <> "_losses", [])
    draws = Map.get(v, p <> "_draws", [])

    Map.get(v, p <> "_wins", [])
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
              <th class="text-right">held-out exam</th>
              <th class="text-right">curriculum</th>
              <th class="text-right">rounds</th>
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
              <%!-- ⚠ THE HELD-OUT SCORE IS THE RANKING AND LEADS THE ROW. Until
                    2026-08-08 this column was the curriculum exam, which is both
                    saturated and inside the training set: `REGISTER I.22`. --%>
              <td class={[
                "text-right font-mono",
                s.held_out? && s.held_out < 10 && "text-error font-semibold"
              ]}>
                <span
                  :if={!s.held_out?}
                  class="opacity-40"
                  title="this island has not published a held-out exam yet"
                >
                  not sat
                </span>
                <span :if={s.held_out?}>{s.held_out}%</span>
                <span
                  :if={s.held_out? && s.held_out < 10}
                  class="ml-1 opacity-70"
                  title="the exam has collapsed"
                >
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
              <%!-- Kept, and muted, because it is a real quantity that is not
                    improvement. A number withdrawn leaves a hole in a history. --%>
              <td
                class="text-right font-mono opacity-40"
                title="performance against the six drills this island also breeds against"
              >
                {s.score}%
              </td>
              <%!-- ⚠ ROUNDS REPLACED GENERATION HERE. `raid:absorb` admits every
                    captured genome at generation 0, so a heavily raided island
                    reports a SHALLOWER lineage while having bred more. Rounds is
                    breeding attempts and is comparable across islands. --%>
              <td class="text-right font-mono opacity-60">{s.rounds}</td>
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
