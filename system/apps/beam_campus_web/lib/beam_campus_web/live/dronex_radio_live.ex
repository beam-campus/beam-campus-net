defmodule BeamCampusWeb.DronexRadioLive do
  @moduledoc """
  Whether the radio does anything, which is the only causal instrument this
  track owns.

  ## What an ablation is, and why it is the one thing here that can prove anything

  Every other number on DroneX is an observation: this island scored that, this
  raid went the other way. An ablation is an intervention. The SAME genome flies
  the SAME opponents twice and one channel is silenced on the second run, so the
  difference between the two is caused by the channel and by nothing else.

  ## ⚠ ITS DELTAS ARE STILL INCONSISTENT IN SIGN, AND THAT IS THE HEADLINE

  `CHARTER.md` Owed: the deltas disagree across islands AND across arms, at a
  resolution where one engagement changing hands moves the number 25 points. One
  exercise cannot settle it and neither can two. What settles it is the same
  number drifting off zero across many, which is why the per-island history is
  here beside the fleet reading rather than on some other page.

  ## Why it is its own route

  `/dronex` loaded every panel's data on every redraw, twice a second, whatever
  it was showing. This view asks for islands and nothing else. The comms table
  and the ablation history were the least-visited half of the busiest page on
  the site, and they are the half that most needs room to be read.
  """

  use BeamCampusWeb, :live_view

  import BeamCampusWeb.DronexChrome, only: [island_name: 1, dronex_state: 1, nav: 1]

  @redraw_ms 500

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Dronex.subscribe()

    {:ok,
     socket
     |> assign(page_title: "DroneX · Radio")
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

  # One timer in flight at a time: the first fact after a redraw schedules the
  # next one and every fact until then is absorbed.
  defp mark_dirty(%{assigns: %{dirty?: true}} = socket), do: socket

  defp mark_dirty(socket) do
    Process.send_after(self(), :redraw, @redraw_ms)
    assign(socket, dirty?: true)
  end

  # ⚠ ISLANDS AND NOTHING ELSE. The page this came from also pulled raids, the
  # leaderboard, the watchable list, the fleet readings and a 1.2 MB recording,
  # on every redraw, whichever panel was open. Nothing below reads any of them.
  defp load(socket) do
    assign(socket,
      islands: Enum.sort_by(Dronex.islands(), &Dronex.label/1),
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
          DroneX · Radio
          <:subtitle>
            <strong>Does the channel do anything?</strong>
            Drones can transmit four numbers nothing names, and the ground can
            hear them. Whether either matters is answered by silencing one and
            flying the same genome against the same opponents again.
          </:subtitle>
        </.header>

        <.nav current={:radio} focus={@focus} />
        <.dronex_state state={@state} refused={@refused} />

        <.comms :if={@islands != []} islands={@islands} />

        <%!-- ⚠ THE PER-ISLAND HISTORY BELONGS BESIDE THE FLEET READING, and it
              used to sit on the per-island Vitals tab of the landing page. A
              chart of the ablation belongs beside the ablation, not in a third
              place that makes you hold a number in your head while you go and
              look at its trajectory. That is the same argument the landing page
              already makes about the roster and the exam. --%>
        <section :if={@islands != []} class="mt-10">
          <h2 class="text-sm font-semibold opacity-80">Each island's history</h2>
          <p class="mt-1 text-xs opacity-60">
            One exercise cannot settle a sign. What settles it is the same number
            drifting off zero across many, so these are the trajectories rather
            than the latest reading.
          </p>

          <div class="mt-3 grid gap-6 lg:grid-cols-2">
            <div :for={row <- @islands}>
              <h3 class="text-xs font-semibold opacity-70">
                <.island_name row={row} class="" />
              </h3>
              <.ablation_trace row={row} />
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  # ⚠ COPIED, NOT SHARED. `BeamCampusWeb.DronexFight` states the house position:
  # "A `utils` module holding four formatters would be the junk drawer the
  # architecture rules name outright." Two lines is cheaper than a dependency.
  defp num(map, key), do: Map.get(map, key, 0)

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
end
