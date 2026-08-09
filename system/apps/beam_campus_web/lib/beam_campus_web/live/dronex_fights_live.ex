defmodule BeamCampusWeb.DronexFightsLive do
  @moduledoc """
  The last fights the archipelago ran, played back frame by frame.

  ## It plays a recording. It does not run the fight.

  Every twenty seconds an island publishes one whole engagement: every frame,
  already computed, in one fact of **about 1.2 MB** — measured on the box, after
  a comment claiming "a few tens of kilobytes" cost the site a fortnight of
  two-hourly OOM kills. This page stores it and animates it in the browser, which
  is why it can offer scrub, pause and slow motion, and why a hundred viewers
  cost the island nothing.

  The removed Robo Rumble page did the opposite. It received two genomes and a
  start index and **re-ran the duel locally**, which put a game engine inside a
  content website and made every viewer repeat about 1,900 frames of identical
  work. Raf's correction was *aggregate and visualize, never regenerate*, and
  this page is that correction with a canvas on it.

  ## ⚠ THE MASS IS FETCHED FOR ONE FIGHT, AND ONLY WHEN THE FIGHT CHANGES

  `Dronex.recording/1` fetches by single-key lookup and `put_fight/2` re-encodes
  only when the chosen fight actually changed. This page redraws twice a second;
  pulling 1.2 MB and running it through `Jason` each time burnt several megabytes
  a second of garbage to produce a byte-identical string.

  ## ⚠⚠ WHICH IS WHY THIS IS THE ROUTE THAT MOST NEEDED SPLITTING OFF

  All of the above used to happen on a page that also drew the raid matrix, the
  ablation table, the leaderboard and both exam ladders, whichever tab was open.
  A visitor reading the exam results was paying for a recording they were not
  watching. Now they are two pages and neither pays for the other.

  ## A LIST of fights, never "this island's fight"

  A raid belongs to TWO islands — the board keys raids by `raid_id` precisely so
  the attacker's half of the story has a home — so "beam03's last fight" is not
  well formed when beam03 raided msi00 and msi00 raided beam03 in the same
  minute. A list of fights INVOLVING an island is a different claim and a true
  one, which is what the chooser offers.
  """

  use BeamCampusWeb, :live_view

  import BeamCampusWeb.DronexFight, only: [fight: 1]
  import BeamCampusWeb.DronexChrome, only: [island_name: 1, dronex_state: 1, nav: 1]

  @redraw_ms 500

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Dronex.subscribe()

    {:ok,
     socket
     |> assign(page_title: "DroneX · Fights")
     |> assign(dirty?: false, watching: nil, focus: nil)
     |> assign(fight: nil, payload: nil, frame_count: 0)
     |> load()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> assign(focus: params["island"]) |> load()}
  end

  @impl true
  def handle_info({:dronex_changed, _kind}, socket), do: {:noreply, mark_dirty(socket)}
  def handle_info(:redraw, socket), do: {:noreply, socket |> assign(dirty?: false) |> load()}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp mark_dirty(%{assigns: %{dirty?: true}} = socket), do: socket

  defp mark_dirty(socket) do
    Process.send_after(self(), :redraw, @redraw_ms)
    assign(socket, dirty?: true)
  end

  # ⚠ THE PICKED FIGHT SURVIVES A REDRAW, which is the whole point of holding it
  # in the socket rather than recomputing "the best one" every second. Facts
  # arrive continuously from five islands; a visitor who clicked a fight and had
  # it swapped out from under them two seconds later would conclude the page was
  # broken, and would be right.
  @impl true
  def handle_event("watch", %{"key" => key}, socket),
    do: {:noreply, socket |> assign(watching: key) |> load()}

  def handle_event("focus_island", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(watching: nil)
     |> push_patch(to: path_for(toggled(socket.assigns.focus, id)))}
  end

  defp path_for(nil), do: ~p"/research/workbench/dronex/fights"
  defp path_for(island), do: ~p"/research/workbench/dronex/fights?#{[island: island]}"

  defp toggled(same, same), do: nil
  defp toggled(_was, id), do: id

  # ⚠ RAIDS, THE WATCHABLE LIST AND ONE RECORDING. No leaderboard, no exam
  # profiles, no ablation history: the page this came from loaded all of them on
  # every redraw whatever it was showing.
  defp load(socket) do
    focus = socket.assigns[:focus]
    watchable = Dronex.watchable(focus)

    socket
    |> assign(
      islands: Dronex.islands(),
      raids: Dronex.raids(),
      watchable: watchable,
      focused: Enum.find(Dronex.islands(), &(&1.id == focus)),
      readings: Dronex.fleet_readings(),
      state: Dronex.state(),
      refused: Dronex.refused()
    )
    |> put_fight(watching(watchable, socket.assigns[:watching]))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="workbench mx-auto max-w-7xl px-4 py-10">
        <.header>
          DroneX · Fights
          <:subtitle>
            <strong>Drones fighting drones, as the island that ran it counted them.</strong>
            A drone is a quadcopter with a battery, a forward sensor that cannot
            see behind it, one unguided weapon effective inside about fifteen
            metres and two guided interceptors that reach about sixty. None of how
            it flies is written down: the controller is a neural network.
          </:subtitle>
        </.header>

        <.nav current={:fights} focus={@focus} />
        <.dronex_state state={@state} refused={@refused} />

        <div :if={@focused} class="mt-4">
          <button
            phx-click="focus_island"
            phx-value-id={@focus}
            class="badge badge-primary badge-sm gap-1"
            aria-label={"showing fights involving #{Dronex.TellIslandsApart.spoken(@focused)} only. Activate to show every fight."}
          >
            fights involving <.island_name row={@focused} class="" />
            <span aria-hidden="true">✕</span>
          </button>
        </div>

        <%!-- THE FIGHT AND ITS CHOOSER, side by side, because a list you pick
              from belongs next to the thing it changes. --%>
        <div class="mt-4 lg:grid lg:grid-cols-3 lg:items-start lg:gap-6">
          <div class="lg:col-span-2">
            <.fight :if={@fight} fight={@fight} payload={@payload} frame_count={@frame_count} />
          </div>

          <div class="lg:col-span-1">
            <.chooser watchable={@watchable} watching={@watching} focused={@focused} />
          </div>
        </div>

        <.how_long_fights_last raids={@raids} />

        <%!-- ⚠ FLEET-WIDE, NOT ABOUT THE SELECTED FIGHT. Both of these described
              whichever fight was selected once, so both were n=1. Measured at
              ingest and accumulated they describe every raid the board has seen,
              and the `n` is printed because the raids are a rolling window
              rather than a sample anybody chose. --%>
        <BeamCampusWeb.DronexFight.losses :if={@readings.damage} readings={@readings} />
        <BeamCampusWeb.DronexFight.coverage :if={@readings.coverage} readings={@readings} />

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

  # ⚠ COPIED, NOT SHARED. Two lines is cheaper than a dependency.
  defp num(map, key), do: Map.get(map, key, 0)

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
              <span class="font-mono text-xs">
                {f.title}
                <%!-- ⚠ A BADGE, NOT A HUE, AND DELIBERATELY SO. The only two
                      colours on this page are `--side-attacker` and
                      `--side-defender`, which are reserved for the two sides of
                      a fight and are already carrying the seats in the canvas
                      below. Recolouring an entry by the provenance of one
                      entrant would put a third meaning on a two-colour
                      encoding, and `mix charts.check` refuses those hues on
                      anything that is not a side. This is the same idiom the
                      exam ladder already uses to mark a captured sitter. --%>
                <span
                  :if={f.fact["opponent"] == "captured"}
                  class="ml-1 rounded-sm px-1 text-[10px] opacity-70"
                  style="background: color-mix(in oklab, currentColor 12%, transparent)"
                  title="the opponent is a controller this island took in a raid, not one it bred"
                >
                  captured
                </span>
              </span>
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
end
