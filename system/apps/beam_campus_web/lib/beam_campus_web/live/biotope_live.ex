defmodule BeamCampusWeb.BiotopeLive do
  @moduledoc """
  The fleet, read across rather than one island at a time. Click a name to go in.

  ## Measure-major, because the point of a fleet is comparison

  This was island-major: a card per island holding every measure. That reads one
  island well and compares none of them, because each chart picks its own rounded
  ceiling, so a population of 1,000 and a population of 1 draw the same picture.
  Side by side would not have fixed it; sharing the axis does.

  So the page is three bands. A table, because whether something has died should
  not need scrolling. The discs in a row, which is the one thing that genuinely
  wants to be per-island. Then a row per measure with a panel per island on one
  scale, which is where divergence between seeds becomes something you can see.

  Per-island depth lives on the island page and is not repeated here. When it was,
  the index rendered `descent`, the ledger and four charts three times over, and
  that is what made it too tall to be a fleet view at all.

  ## Nothing here computes a world

  The page draws the last frame that arrived and no more. It does not simulate,
  interpolate between frames, or fill a gap with a guess. A frozen island shows
  a frozen picture with a tick that stops advancing, and now says so out loud
  rather than leaving a reader to notice the number is not moving.

  ## Two clocks, two subscriptions

  Charts arrive twice a second; history rows are written at most every thirty.
  Those are different rates and they update different parts of a card, so the
  page subscribes to both channels and each refreshes only what it owns. One
  subscription would repaint the sparklines two hundred times more often than
  they change, and run N database queries every time it did.

  ## Paged, because N is coming

  Discs are the appealing part and also the expensive part: about a hundred and
  eighty circles each, redrawn whenever any island speaks. Six is comfortable,
  fifty on one page is neither readable nor cheap. The pager appears only when
  there is more than one page, so at two islands it is invisible.
  """

  use BeamCampusWeb, :live_view

  import BeamCampusWeb.BiotopeComponents

  alias Biotope.RecordHistory

  @per_page 6

  # Twice a second. Fast enough that the discs read as alive, slow enough that a
  # 700 KB document does not have to cross the wire six times a second.
  @redraw_ms 500

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Biotope.subscribe()
      RecordHistory.subscribe()
    end

    {:ok, socket |> assign(page: 1, dirty?: false) |> load_islands() |> load_history()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, page: page_of(params))}
  end

  @impl true
  # ==========================================================================
  # COALESCED, BECAUSE THIS PAGE IS 700 KILOBYTES AND THE FLEET SPEAKS SIX TIMES
  # A SECOND
  # ==========================================================================
  #
  # Every fact from any island used to redraw everything: three discs of about
  # 2,600 circles each, twelve charts and a table. Three islands publishing a
  # picture twice a second is six full re-renders a second, of a document that
  # serves at 711 KB, per viewer.
  #
  # That is what "the site crashes sometimes" was. Nothing crashed: no container
  # restart, no error in any log, and Caddy clean. The socket simply could not
  # keep up, dropped, and the client showed its reconnect banner. A LiveView that
  # cannot ship its diff before the next one arrives is indistinguishable from a
  # broken one.
  #
  # So a fact marks the page dirty and a redraw happens at most every
  # `@redraw_ms`. The discs are still live; they are live at a rate a browser can
  # actually receive.
  def handle_info({:biotope, :changed, _name}, socket) do
    {:noreply, mark_dirty(socket)}
  end

  def handle_info(:redraw, socket) do
    {:noreply, socket |> assign(dirty?: false) |> load_islands()}
  end

  # A row was written: redraw the sparklines, which is the only thing that has
  # changed and the only thing that costs a query.
  def handle_info({:biotope_history, :written}, socket), do: {:noreply, load_history(socket)}

  def handle_info(_msg, socket), do: {:noreply, socket}

  # One timer in flight at a time: the first fact after a redraw schedules the
  # next one and every fact until then is absorbed.
  defp mark_dirty(%{assigns: %{dirty?: true}} = socket), do: socket

  defp mark_dirty(socket) do
    Process.send_after(self(), :redraw, @redraw_ms)
    assign(socket, dirty?: true)
  end

  defp load_islands(socket) do
    names = Biotope.islands()

    rows = Map.new(names, &{&1, Biotope.island(&1)})

    assign(socket,
      names: names,
      # ⚠ NAMES ARE KEYS AND KEYS ARE DIGESTS. An island is FILED under the
      # identity it minted for itself, because the name is a nickname two
      # islands can share, but nobody wants to read a digest. Every place that
      # shows an island to a person looks it up here.
      labels: Map.new(names, &{&1, Biotope.label(&1)}),
      # Only islands that have actually sent a picture. An island that has
      # announced itself and published no chart yet is a name, not a place, and
      # drawing an empty disc for it would say it is barren rather than silent.
      charts: for(n <- names, chart = chart_of(rows, n), do: {n, chart}),
      rows: rows,
      liveness: Map.new(names, &{&1, Biotope.liveness(&1)}),
      refused: Biotope.refused(),
      watching?: Biotope.watching?(),
      configured?: Biotope.configured?()
    )
  end

  defp chart_of(rows, name) do
    case Map.get(rows, name) do
      %{chart: %{} = chart} -> chart
      _absent -> nil
    end
  end

  defp load_history(socket) do
    history = Map.new(RecordHistory.recorded_islands(), &{&1, RecordHistory.history(&1, 60)})
    assign(socket, history: history)
  end

  defp page_of(%{"page" => p}) do
    case Integer.parse(p) do
      {n, _} when n > 0 -> n
      _otherwise -> 1
    end
  end

  defp page_of(_params), do: 1

  @impl true
  def render(assigns) do
    pages = max(ceil(length(assigns.names) / @per_page), 1)
    page = min(assigns.page, pages)

    shown = Enum.slice(assigns.names, (page - 1) * @per_page, @per_page)

    assigns =
      assign(assigns,
        pages: pages,
        page: page,
        shown: shown,
        series: Enum.map(shown, &{&1, Map.get(assigns.history, &1, [])}),
        comparable?: comparable?(shown, assigns.rows)
      )

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-4 py-10">
        <.header>
          <div class="flex items-baseline gap-3">
            <span>Biotopes</span>
            <.link
              navigate={~p"/research/workbench/biotope/join"}
              class="btn btn-sm btn-outline"
            >
              + Run one
            </.link>
          </div>
          <:subtitle>
            <strong>Open populations evolving bodies and brains.</strong>
            A creature is a set of sensors, a hidden layer and a set of things it
            can do, and NONE of it is assigned: a founder is drawn at random, and
            every birth may add a sensor, drop one, widen its reach, grow a node,
            or gain and lose the ability to act at all. What survives is whatever
            pays for itself.
            <span class="mt-2 block">
              The world it happens in is an energy economy. Energy gathers in the
              ground, creatures feed, breed, starve and eat each other. There are
              no plants: staying put and living off what gathers where you stand
              is a way of living, not a kind of thing.
            </span>
            <span class="mt-2 block">
              Every island runs the SAME physics and differs only in the random
              draw it started from, so whether they drift apart is the question
              this fleet exists to ask. Nothing here is a simulation of anything:
              the rules are about energy, and every role you can see was counted
              afterwards rather than assigned.
            </span>
          </:subtitle>
        </.header>

        <.switch current={:now} />
        <.refused_notice refused={@refused} />

        <div :if={@names == []} class="mt-8">
          <.dark configured?={@configured?} watching?={@watching?} />
        </div>

        <.viz_tokens />

        <div :if={@names != []} class="mt-8">
          <.fleet names={@shown} rows={@rows} liveness={@liveness} labels={@labels} />
          <.runs names={@shown} rows={@rows} />
          <.legend />
          <.running names={@shown} rows={@rows} />
          <.ending names={@shown} liveness={@liveness} />
        </div>
        
    <!-- ⚠ ONE WORLD FIRST, AND THE PANELS BELOW IT SECOND. Every island has
             been drawn in its own panel since the beginning, which reads as
             three unrelated experiments side by side. They are one world, and
             adding a node adds land to it. This is that, drawn, and it goes
             above the panels because it is the claim the panels illustrate. -->
        <div :if={@charts != []} class="mt-10">
          <.caption
            label="one world"
            keys={[{"#2F7D52", "ground"}, {"#2B6CB0", "water"}, {"#C2557A", "died here"}]}
          />
          <.archipelago charts={@charts} class="mt-2" />
          <p class="mt-2 text-xs opacity-40">
            every island on one map, and each node that joins adds land to it.
            An island's place here is a hash of its name, so nothing is claimed
            and nothing is granted: any two viewers holding the same islands
            draw the same world. The sea between them is not simulated and holds
            nothing, because islands are a graph joined by migration rather than
            one plane, and no creature walks across.
          </p>
        </div>

        <div :if={@names != []} class="mt-10">
          <.caption
            label="the islands now"
            keys={[{"#2F7D52", "ground"}, {"#C2557A", "died here"}, {"#8B7CE8", "scent"}]}
          />
          <.boards names={@shown} rows={@rows} labels={@labels} class="mt-2" />
          <p class="mt-2 text-xs opacity-40">
            a creature's size is its body and its colour is <span data-colouring>feeding rate</span>. Press
            <kbd class="rounded border px-1">K</kbd>
            to colour every board by KIND instead, where a kind is a body plan and
            a brain, and two dots of one colour are two creatures built the same
            way. Every disc is drawn to the same absolute scale, so they can be
            read against each other.
          </p>
        </div>

        <section :if={@names != []} class="mt-12">
          <h2 class="text-sm font-semibold opacity-70">Where they have been</h2>
          <p class="mt-1 text-xs opacity-50">
            {scale_note(@comparable?)} Plotted against each world's own tick, and
            every axis starts at zero.
          </p>

          <div class="mt-4 space-y-8">
            <!-- THE EXPERIMENT FIRST. Population and ground are the medium; how
                 many distinct architectures are alive and whether any of them
                 computes is the thing these islands exist to ask, and it was at
                 the bottom of the page or absent from it. -->
            <.compare
              series={@series}
              get={& &1.kinds}
              label="distinct kinds alive"
              hint="architectures, not ancestors: founder lines reads 1 either way"
              shared={@comparable?}
            />
            <.compare
              series={@series}
              get={&hundredth(&1.hidden_mean)}
              label="hidden nodes per creature"
              hint="leaving zero is the difference between reflex and deliberation"
              shared={@comparable?}
            />
            <.compare
              series={@series}
              get={& &1.population}
              label="creatures"
              role="creatures"
              shared={@comparable?}
            />
            <.compare
              series={@series}
              get={& &1.ground_total}
              label="energy in the ground"
              role="ground"
              shared={@comparable?}
            />
            <.compare
              series={@series}
              get={& &1.dissipated}
              label="burnt as heat"
              hint="the Second Law: this can only rise"
              shared={@comparable?}
            />
            <.compare
              series={@series}
              get={& &1.depth}
              label="generations deep"
              hint="zero means every creature alive is a founder"
              shared={@comparable?}
            />
          </div>
        </section>

        <nav :if={@pages > 1} class="mt-8 flex items-center justify-center gap-3" aria-label="Pages">
          <.link
            :if={@page > 1}
            patch={~p"/research/workbench/biotope?page=#{@page - 1}"}
            class="btn btn-sm"
          >
            ← previous
          </.link>
          <span class="text-sm opacity-60">page {@page} of {@pages}</span>
          <.link
            :if={@page < @pages}
            patch={~p"/research/workbench/biotope?page=#{@page + 1}"}
            class="btn btn-sm"
          >
            next →
          </.link>
        </nav>

        <p class="mt-10 text-sm opacity-60">
          Each island publishes counts once a second and a picture more often. The
          site subscribes and draws; it holds no world of its own and shares no
          code with the islands. What you see is the last frame that arrived.
        </p>
      </div>
    </Layouts.app>
    """
  end

  # ── The fleet, read across ──────────────────────────────────────

  # TWO ISLANDS SHARING A FINGERPRINT ARE COMPARABLE AND TWO THAT DO NOT ARE
  # PLAYING DIFFERENT GAMES. A shared axis is an invitation to read one against
  # the other, so it is only offered when the rules agree. During a rollout they
  # genuinely disagree, which is the moment this matters.
  defp comparable?(names, rows) do
    names
    |> Enum.map(&get_in(rows, [&1, :stats, "econ_id"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length() <= 1
  end

  # A MEAN ARRIVES TIMES A HUNDRED because the wire carries integers, and a
  # missing value must stay missing: an island that has not reported yet is not
  # an island whose creatures compute nothing.
  defp hundredth(nil), do: nil
  defp hundredth(n) when is_integer(n), do: n / 100
  defp hundredth(n), do: n

  defp scale_note(true),
    do:
      "One scale per row, shared by every island, because they are running " <>
        "identical rules and the whole reason to run more than one is to see " <>
        "whether they diverge."

  defp scale_note(false),
    do:
      "These islands do NOT share an economy, so each panel is scaled to itself " <>
        "and their heights must not be read against each other."

  # WHICH WORLD, IN WORDS, ONCE. The table's `world` column carries the number
  # per island, which is what exposes a rollout mid-flight; this is the sentence
  # saying what that world IS, and repeating it per island was three copies of
  # one fact.
  #
  # Said only when they all agree. During a rollout they genuinely do not, and a
  # single sentence would then be describing some of the discs above it and not
  # the others. The column has already made the disagreement visible; this stays
  # quiet rather than picking a winner.
  attr :names, :list, required: true
  attr :rows, :map, required: true

  defp running(assigns) do
    lines =
      assigns.names
      |> Enum.map(
        &{get_in(assigns.rows, [&1, :stats, "world"]),
         get_in(assigns.rows, [&1, :stats, "world_line"])}
      )
      |> Enum.reject(fn {number, _line} -> is_nil(number) end)
      |> Enum.uniq()

    assigns = assign(assigns, agreed: lines)

    ~H"""
    <p :if={match?([_one], @agreed)} class="mt-3 text-xs leading-snug">
      <span :for={{number, line} <- @agreed}>
        <span class="font-mono text-primary">world {number}</span>
        <span class="opacity-50">{line}</span>
      </span>
    </p>
    """
  end

  # A TICK THAT DROPS BACK TO NOTHING IS A NEW WORLD, NOT A GLITCH.
  #
  # A world that ends stays ended: nothing reseeds it and its history is not
  # continued. The island then begins ANOTHER one, after leaving the corpse on
  # show for a couple of minutes, because extinction is a result and an island
  # that restarted instantly would hide it.
  #
  # Without this line the only visible sign is the clock going backwards, which
  # reads as the page being broken. Said only for islands past their first world,
  # so a fleet that has never lost one says nothing.
  attr :names, :list, required: true
  attr :rows, :map, required: true

  defp runs(assigns) do
    assigns = assign(assigns, again: Enum.filter(assigns.names, &begun_again?(assigns.rows[&1])))

    ~H"""
    <div :if={@again != []} class="mt-3 space-y-1 text-xs opacity-60">
      <p :for={name <- @again}>
        <span class="font-medium">{name}</span>
        is on world number {get_in(@rows, [name, :stats, "run"])} since it was
        deployed{ended(get_in(@rows, [name, :stats, "previous_end"]))}. A world that
        ends stays ended, so the island began a new one rather than reviving it.
      </p>
    </div>
    """
  end

  defp begun_again?(row), do: (get_in(row, [:stats, "run"]) || 1) > 1

  defp ended(nil), do: ""
  defp ended(tick), do: ", the previous having ended at tick #{tick}"

  # A DEAD ISLAND IS A FLEET FACT, not a per-card one, and it needs saying once.
  # The table already reports "extinct at tick N" in its state column, which says
  # what happened and not what it means: an island whose data stopped arriving
  # looks much the same at a glance, and that is the one confusion this page
  # exists to prevent.
  attr :names, :list, required: true
  attr :liveness, :map, required: true

  defp ending(assigns) do
    assigns = assign(assigns, dead: Enum.filter(assigns.names, &extinct?(assigns.liveness[&1])))

    ~H"""
    <p :if={@dead != []} class="mt-3 rounded-lg border border-error/30 bg-error/10 p-3 text-sm">
      <span class="font-semibold text-error">
        {Enum.join(@dead, ", ")} {if length(@dead) == 1, do: "has", else: "have"} ended.
      </span>
      Every creature died, and nothing reseeds a world, so it will not come back.
      The ground still gathers energy and the clock still runs, which is why a dead
      island goes on publishing. World 9 ends this way in about two seeds in five,
      which is a result rather than a fault.
    </p>
    """
  end

  defp extinct?({:extinct, _tick}), do: true
  defp extinct?(_other), do: false

  # Configured-and-dark and never-configured need different responses from
  # whoever is reading, so the page says which it is rather than showing one
  # apologetic sentence for both.
  attr :configured?, :boolean, required: true
  attr :watching?, :boolean, required: true

  defp dark(assigns) do
    ~H"""
    <div class="rounded-lg border border-base-content/10 bg-base-200 p-6 text-sm">
      <p :if={not @configured?}>
        This site is not configured to read islands. It needs <code>BEAM_CAMPUS_BIOTOPE_SEEDS</code>, which has no default on purpose:
        naming a public realm costs nothing, dialling a production station from
        every clone does.
      </p>
      <p :if={@configured? and not @watching?}>
        Configured, but not connected to the mesh yet. Retrying.
      </p>
      <p :if={@configured? and @watching?}>
        Connected, and no island has said anything yet. Either none is running,
        or they are publishing on a different realm or namespace.
      </p>
    </div>
    """
  end
end
