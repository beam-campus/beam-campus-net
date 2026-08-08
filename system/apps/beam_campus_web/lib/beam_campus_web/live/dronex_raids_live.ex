defmodule BeamCampusWeb.DronexRaidsLive do
  @moduledoc """
  Who raids whom, what it costs them, and whether any genome actually crosses.

  ## This is the one idea the repository is named after

  `CHARTER.md` prices a raid in airframes and makes it the way opponent
  diversity crosses the mesh. Everything else on DroneX is an island talking
  about itself; this is the only view where two islands appear in one fact, and
  the matrix is the only diagram that can show the archipelago as a graph rather
  than as a list.

  ## ⚠ IT REPLACED A MAP THAT DREW A HASH AS GEOGRAPHY

  Islands used to sit at positions derived from a hash of their names, so
  distance, adjacency and arc length encoded nothing at all. The matrix carries
  the facts the arcs pretended to: who attacked whom, how often, and how it went.

  ## Why it is its own route

  `/dronex` loaded every panel on every redraw, twice a second, whatever it was
  showing. This view asks for islands and raids, and never touches the
  leaderboard, the recordings or the fleet readings.
  """

  use BeamCampusWeb, :live_view

  import BeamCampusWeb.DronexChrome, only: [dronex_state: 1, nav: 1]

  @redraw_ms 500

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Dronex.subscribe()

    {:ok,
     socket
     |> assign(page_title: "DroneX · Raids")
     |> assign(dirty?: false, focus: nil)
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

  # ⚠ CLICKING THE FOCUSED ISLAND CLEARS IT. A filter you can enter and cannot
  # leave is a trap, and the selection rides the URL so it survives the trip to
  # another view.
  @impl true
  def handle_event("focus_island", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: path_for(toggled(socket.assigns.focus, id)))}
  end

  defp path_for(nil), do: ~p"/research/workbench/dronex/raids"
  defp path_for(island), do: ~p"/research/workbench/dronex/raids?#{[island: island]}"

  defp toggled(same, same), do: nil
  defp toggled(_was, id), do: id

  # ⚠ ISLANDS AND RAIDS. Nothing below reads the leaderboard, the watchable list
  # or a recording, and the page this came from fetched all three every 500 ms.
  defp load(socket) do
    islands = Dronex.islands()

    assign(socket,
      islands: islands,
      ordered_islands: Enum.sort_by(islands, &Dronex.label/1),
      raids: Dronex.raids(),
      state: Dronex.state(),
      refused: Dronex.refused()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="workbench mx-auto max-w-7xl px-4 py-10">
        <.header>
          DroneX · Raids
          <:subtitle>
            <strong>An island raids a neighbour, and keeps the genomes it beats.</strong>
            Raiding is the only way a controller bred on one machine ever flies on
            another. You fight at home with your ground network and away without
            it, so a raid is expensive on purpose.
          </:subtitle>
        </.header>

        <.nav current={:raids} focus={@focus} />
        <.dronex_state state={@state} refused={@refused} />

        <.ledger :if={@islands != []} islands={@islands} raids={@raids} focus={@focus} />
        <.experience raids={@raids} />
        <.captures :if={@islands != []} islands={@ordered_islands} />
      </div>
    </Layouts.app>
    """
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

  # ⚠ THE LANES ARE THE SIDES. `WeighTheExperience.lanes/1` names them "raider
  # won", "drawn" and "island held", and every dot in all three was drawn in the
  # same blue, so the page's flagship chart was set to contradict the histogram
  # directly above it on the day it finally gets data.
  defp lane_colour("raider won"), do: "var(--side-attacker)"
  defp lane_colour("island held"), do: "var(--side-defender)"
  defp lane_colour(_drawn), do: "var(--side-draw)"

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
end
