defmodule BeamCampusWeb.BiotopeIslandLive do
  @moduledoc """
  One island, as large as the page allows, with where it has been underneath.

  ## Now and then, on one page

  The disc is the last frame that arrived; the chart below is the same island
  sampled over time. Putting them together is the point: a picture on its own
  cannot tell a population that is holding steady from one halfway through a
  crash, and a curve on its own cannot show you what the world looks like.

  ## Two clocks again, and only this island's

  Frames arrive twice a second and rows are written at most every thirty, so the
  two halves refresh from two channels. The disc redraws only when THIS island
  speaks: the board carries every island, and repainting a hundred and eighty
  circles because a different island moved is work with nothing to show for it.

  ## The rules are on the page

  Two islands sharing an `econ_id` are comparable; two that do not are different
  games. It is shown here rather than left implicit, because the whole reason to
  run more than one island is that they differ, and reading two population
  curves against each other without knowing that is how a configuration bug
  becomes a finding about ecology.
  """

  use BeamCampusWeb, :live_view

  import BeamCampusWeb.BiotopeComponents

  alias Biotope.RecordHistory

  @impl true
  def mount(%{"island" => name}, _session, socket) do
    if connected?(socket) do
      Biotope.subscribe()
      RecordHistory.subscribe()
    end

    {:ok, socket |> assign(name: name) |> load_island() |> load_history()}
  end

  @impl true
  # ONLY WHEN THIS ISLAND SPEAKS, which this page has always claimed and never
  # did. The announcement carried no name, so every fact from every island
  # redrew four hundred circles here: six times a second on a three-island fleet,
  # for a page showing one of them.
  def handle_info({:biotope, :changed, name}, %{assigns: %{name: name}} = socket) do
    {:noreply, load_island(socket)}
  end

  def handle_info({:biotope, :changed, _other}, socket), do: {:noreply, socket}
  def handle_info({:biotope_history, :written}, socket), do: {:noreply, load_history(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_island(socket) do
    name = socket.assigns.name

    assign(socket,
      row: Biotope.island(name),
      liveness: Biotope.liveness(name)
    )
  end

  # The island publishes its own rules, so the viewer never has to be configured
  # to agree with a world it cannot see. Above the ceiling means a corpse, and
  # without it the picture could not tell enrichment from a full cell.
  defp ceiling(nil), do: 400
  defp ceiling(stats), do: get_in(stats, ["econ", "ground_ceiling"]) || 400

  defp load_history(socket) do
    assign(socket, samples: RecordHistory.history(socket.assigns.name, 240))
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        chart: assigns.row && assigns.row[:chart],
        stats: assigns.row && assigns.row[:stats]
      )

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-3xl px-4 py-10">
        <.link navigate={~p"/research/workbench/biotope"} class="link link-hover text-sm opacity-60">
          ← All islands
        </.link>

        <div class="mt-4 flex flex-wrap items-baseline justify-between gap-3">
          <h1 class="text-lg font-semibold leading-8">{@name}</h1>
          <div class="flex items-center gap-3">
            <.via stats={@stats} />
            <.liveness liveness={@liveness} />
          </div>
        </div>
        <p :if={@stats && @stats["station_host"]} class="mt-1 text-xs opacity-50">
          This island reaches the mesh through <span class="font-mono opacity-80">{@stats["station_host"]}</span>, and its
          two neighbours dial two other stations. All three publish to one topic and
          this page receives them on a single subscription: which station carried
          which is the mesh's business, not the reader's. The name is an identity on
          the mesh and not a place.
        </p>

        <.ruleset stats={@stats} class="mt-2" />

        <p
          :if={is_nil(@row)}
          class="mt-6 rounded-lg border border-base-content/10 bg-base-200 p-6 text-sm"
        >
          Nothing has arrived from an island by this name. It may not be running,
          or it may be publishing on a different realm or namespace. Nothing here
          invents a world to fill the space.
        </p>

        <.viz_tokens />

        <div :if={@chart} class="mt-6">
          <.disc id={"disc-" <> @name} chart={@chart} size={480} ceiling={ceiling(@stats)} />
        </div>

        <.narration row={@row} />

        <.kinds :if={@chart} chart={@chart} />

        <p :if={@chart} class="mt-2 text-xs opacity-50">
          A creature's SIZE is its body, because every contest here is decided on
          structure alone: a fat small creature loses to a lean large one. Its
          COLOUR is <span data-colouring>feeding rate</span>
          by default, and <kbd class="rounded border px-1">K</kbd>
          switches every board on the page to colour by KIND instead, so two dots
          of one colour are two creatures built the same way. Pale is gentle
          feeding and deep is voracious. Feed
          slower than the ground comes back and a cell sustains you for good; feed
          harder and you strip it, your income collapses to the bare floor, and you
          move or starve. The green surface is the ground itself, brighter where
          more energy has gathered and dark where something has grazed it bare.
          ROSE MEANS SOMETHING DIED THERE: sunlight stops at the ceiling, so only
          a corpse can carry a cell that high. The violet haze is scent, ground
          walked over recently, fading tick by tick.
        </p>

        <dl :if={@stats} class="mt-4 grid grid-cols-3 gap-3 text-sm sm:grid-cols-4">
          <.stat label="creatures" value={@stats["population"]} />
          <.stat label="in creatures" value={@stats["energy_total"]} />
          <.stat label="tick" value={@stats["tick"]} />
          <.stat label="born" value={@stats["born"]} />
          <.stat label="absorbed" value={@stats["absorbed"]} />
          <.stat label="signatures" value={@stats["scent_tags"]} />
          <.stat label="spread" value={@stats["scent_spread"]} />
          <.stat label="ticks/s" value={@stats["ticks_per_second"]} />
          <.stat label="ways of living" value={@stats["explored"]} />
          <.stat label="new ways lately" value={@stats["frontier"]} />
        </dl>

        <div :if={@stats} class="mt-6 grid gap-6 sm:grid-cols-2">
          <.descent stats={@stats} />
          <.ledger stats={@stats} />
          <.sessile stats={@stats} />
          <.share stats={@stats} />
          <.census stats={@stats} />
          <.landscape stats={@stats} />
          <.capable stats={@stats} />
          <.deaths stats={@stats} />
          <.churn stats={@stats} />
          <.shape
            bars={@stats["sensor_hist"]}
            label="sensors carried"
            hint="creatures at each count · the axis stops at the safety cap of 8"
          />
          <.shape
            bars={@stats["hidden_hist"]}
            label="hidden nodes"
            hint="creatures at each count · the axis stops at the safety cap of 6"
          />
          <.shape
            bars={@stats["uptake_hist"]}
            label="how fast they feed"
            hint="gentle to voracious"
            ramp={true}
          />
        </div>

        <p :if={@stats && (@stats["births_refused"] || 0) > 0} class="mt-3 text-xs text-warning">
          {@stats["births_refused"]} births refused: this island is at its safety
          cap, so its population is not at a natural ceiling.
        </p>

        <.econ stats={@stats} />

        <section :if={@stats} class="mt-8">
          <h2 class="text-sm font-semibold opacity-70">Where it has been</h2>
          <p class="mt-1 text-xs opacity-50">
            Grazing pressure against regrowth. Two charts rather than two lines on
            one: they count different things, so a crossing point between them
            would mean nothing. Both are plotted against the world's own tick, and
            both axes start at zero.
          </p>
          <.stocks samples={@samples} w={340} h={160} class="mt-3" />
          <p :if={@samples != []} class="mt-2 text-xs opacity-50">
            {length(@samples)} samples, ticks {List.first(@samples).tick} to {List.last(@samples).tick}.
            A line that stops is an island that stopped: a row is written only when
            its tick advances.
          </p>

          <h2 class="mt-8 text-sm font-semibold opacity-70">Whether it can still change</h2>
          <p class="mt-1 text-xs opacity-50">
            The entropy account and the depth of descent. The first is every unit
            ever spent on living, as heat, and it is the only quantity here that
            cannot fall. The second is how many births separate the oldest living
            creature from the founding: at zero, every creature alive IS a founder
            and the world has selected nothing.
          </p>
          <div class="mt-3 grid gap-4 sm:grid-cols-2">
            <.entropy samples={@samples} w={340} h={160} />
            <.plot
              samples={@samples}
              get={& &1.depth}
              label="generations deep"
              hint="zero means nothing but founders"
              w={340}
              h={160}
            />
          </div>

          <h2 class="mt-8 text-sm font-semibold opacity-70">What they became</h2>
          <p class="mt-1 text-xs opacity-50">
            Neither is a rule. There is no herbivore field and no carnivore flag
            anywhere in the island: both are counted afterwards from what actually
            happened.
          </p>
          <.becoming samples={@samples} w={340} h={160} class="mt-3" />
          <p class="mt-2 text-xs opacity-50">
            Only samples sharing this island's current rules are drawn. Change the
            economy and the line starts again rather than bending, because an
            island before and after a rules change is two different games.
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
