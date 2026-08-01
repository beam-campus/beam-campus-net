defmodule BeamCampusWeb.BiotopeLive do
  @moduledoc """
  Every island this node has heard from, as a card. Click one to go in.

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

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Biotope.subscribe()
      RecordHistory.subscribe()
    end

    {:ok, socket |> assign(page: 1) |> load_islands() |> load_history()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, page: page_of(params))}
  end

  @impl true
  # A fact moved a world: redraw the discs and the counts, not the sparklines.
  def handle_info({:biotope, :changed}, socket), do: {:noreply, load_islands(socket)}

  # A row was written: redraw the sparklines, which is the only thing that has
  # changed and the only thing that costs a query.
  def handle_info({:biotope_history, :written}, socket), do: {:noreply, load_history(socket)}

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_islands(socket) do
    names = Biotope.islands()

    assign(socket,
      names: names,
      rows: Map.new(names, &{&1, Biotope.island(&1)}),
      liveness: Map.new(names, &{&1, Biotope.liveness(&1)}),
      refused: Biotope.refused(),
      watching?: Biotope.watching?(),
      configured?: Biotope.configured?()
    )
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

    assigns =
      assign(assigns,
        pages: pages,
        page: page,
        shown: Enum.slice(assigns.names, (page - 1) * @per_page, @per_page)
      )

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-4 py-10">
        <.header>
          Biotopes
          <:subtitle>
            Open populations on the mesh. Energy gathers in the ground, creatures
            feed, breed, starve and eat each other. There are no plants: staying
            put and living off what gathers where you stand is a way of living,
            not a kind of thing. They do have brains, and so far evolution has
            thrown them away.
          </:subtitle>
        </.header>

        <.switch current={:now} />
        <.refused_notice refused={@refused} />

        <div :if={@names == []} class="mt-8">
          <.dark configured?={@configured?} watching?={@watching?} />
        </div>

        <.viz_tokens />

        <div class="mt-8 space-y-8">
          <.card
            :for={name <- @shown}
            name={name}
            row={@rows[name]}
            liveness={@liveness[name]}
            samples={Map.get(@history, name, [])}
          />
        </div>

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

  # ── One card ────────────────────────────────────────────────────

  attr :name, :string, required: true
  attr :row, :map, required: true
  attr :liveness, :any, required: true
  attr :samples, :list, required: true

  # A SECTION AND NOT A LINK-WRAPPED BLOCK.
  #
  # The whole card used to be one anchor, which was fine while it held nothing
  # but text and a picture. It cannot stay that way now that every chart carries
  # an expandable table: a `details` inside an `a` is invalid, and a keyboard
  # user tabbing through it gets one target that swallows all of them.
  #
  # So the heading is the link, the card is a section, and the card grew tall
  # enough to say something. One per row rather than two: the disc and four
  # charts do not fit in half a column, and scrolling costs a reader far less
  # than a chart too small to read.
  defp card(assigns) do
    assigns = assign(assigns, chart: assigns.row[:chart], stats: assigns.row[:stats])

    ~H"""
    <section class="rounded-lg border border-base-content/10 bg-base-200 p-5">
      <div class="flex items-baseline justify-between gap-2">
        <h2 class="font-semibold">
          <.link navigate={~p"/research/workbench/biotope/#{@name}"} class="link link-hover">
            {@name}
          </.link>
        </h2>
        <.liveness liveness={@liveness} />
      </div>

      <.ruleset stats={@stats} class="mt-1" />

      <div class="mt-4 grid gap-5 sm:grid-cols-[minmax(0,260px)_1fr]">
        <div>
          <.caption
            :if={@chart}
            label="the island now"
            keys={[{"#2F7D52", "ground"}, {"#C2557A", "died here"}, {"#8B7CE8", "scent"}]}
          />
          <.disc :if={@chart} chart={@chart} size={260} class="mt-2" />
          <p :if={@chart} class="mt-1 text-xs opacity-40">
            a creature's size is its body, its colour how fast it feeds
          </p>
          <p :if={is_nil(@chart)} class="text-sm opacity-60">
            Counts but no picture. This island may have its chart turned off, which
            is what a headless run does.
          </p>
        </div>

        <div class="space-y-4">
          <dl :if={@stats} class="grid grid-cols-3 gap-2 text-sm">
            <.stat label="creatures" value={@stats["population"]} />
            <.stat label="stayed put" value={pct(@stats["still_pct"])} />
            <.stat label="tick" value={@stats["tick"]} />
          </dl>

          <.descent :if={@stats} stats={@stats} />
          <.share :if={@stats} stats={@stats} />
        </div>
      </div>

      <.stocks samples={@samples} w={340} h={140} class="mt-6" />

      <div class="mt-4 grid gap-4 sm:grid-cols-2">
        <.entropy samples={@samples} w={340} h={140} />
        <.plot
          samples={@samples}
          get={& &1.depth}
          label="generations deep"
          hint="zero means every creature alive is a founder"
          w={340}
          h={140}
        />
      </div>

      <.ledger :if={@stats} stats={@stats} class="mt-4" />
    </section>
    """
  end

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

  defp pct(nil), do: "–"
  defp pct(n), do: "#{n}%"
end
