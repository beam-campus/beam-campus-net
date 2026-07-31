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
  def handle_info({:biotope, :changed}, socket), do: {:noreply, load_island(socket)}
  def handle_info({:biotope_history, :written}, socket), do: {:noreply, load_history(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_island(socket) do
    name = socket.assigns.name

    assign(socket,
      row: Biotope.island(name),
      liveness: Biotope.liveness(name)
    )
  end

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
          <.liveness liveness={@liveness} />
        </div>

        <p
          :if={is_nil(@row)}
          class="mt-6 rounded-lg border border-base-content/10 bg-base-200 p-6 text-sm"
        >
          Nothing has arrived from an island by this name. It may not be running,
          or it may be publishing on a different realm or namespace. Nothing here
          invents a world to fill the space.
        </p>

        <div :if={@chart} class="mt-6">
          <.disc chart={@chart} size={480} />
        </div>

        <p :if={@chart} class="mt-2 text-xs opacity-50">
          A creature's SIZE is its energy, because the stronger consumes the
          weaker on contact and so energy is armour. Its COLOUR is its lineage:
          creatures carry a heritable scent signature and read a trail by how
          unlike themselves it smells, so kin share a colour and long-separated
          families do not. Green is a plant. The violet haze is scent, ground
          something walked over recently, fading tick by tick, and the only thing
          here that outlives the moment it was made.
        </p>

        <dl :if={@stats} class="mt-4 grid grid-cols-3 gap-3 text-sm sm:grid-cols-4">
          <.stat label="creatures" value={@stats["population"]} />
          <.stat label="plants" value={@stats["plants"]} />
          <.stat label="energy" value={@stats["energy_total"]} />
          <.stat label="tick" value={@stats["tick"]} />
          <.stat label="born" value={@stats["born"]} />
          <.stat label="plants eaten" value={@stats["plants_eaten"]} />
          <.stat label="breeds at" value={@stats["breed_at_mean"]} />
          <.stat label="ticks/s" value={@stats["ticks_per_second"]} />
        </dl>

        <div :if={@stats} class="mt-6 grid gap-6 sm:grid-cols-2">
          <.share stats={@stats} />
          <.census stats={@stats} />
          <.deaths stats={@stats} />
          <.signature stats={@stats} />
          <.churn stats={@stats} />
        </div>

        <p :if={@stats && (@stats["births_refused"] || 0) > 0} class="mt-3 text-xs text-warning">
          {@stats["births_refused"]} births refused: this island is at its safety
          cap, so its population is not at a natural ceiling.
        </p>

        <.econ stats={@stats} />

        <section :if={@stats} class="mt-8">
          <h2 class="text-sm font-semibold opacity-70">Where it has been</h2>
          <p class="mt-1 text-xs opacity-50">
            Amber is the population, green the standing crop. Each is scaled to its
            own maximum: they are different quantities, and one axis would say
            something false about their relative size. Plotted against the world's
            own tick.
          </p>
          <.sparkline samples={@samples} w={720} h={160} class="mt-3" />
          <p :if={@samples != []} class="mt-2 text-xs opacity-50">
            {length(@samples)} samples, ticks {List.first(@samples).tick} to {List.last(@samples).tick}.
            A line that stops is an island that stopped: a row is written only when
            its tick advances.
          </p>

          <h2 class="mt-8 text-sm font-semibold opacity-70">What they became</h2>
          <p class="mt-1 text-xs opacity-50">
            Amber is the share of eaten energy that came from other creatures;
            blue is how much measuring a creature carries. Neither is a rule.
            There is no herbivore field and no carnivore flag anywhere in the
            island: both are counted afterwards from what actually happened.
          </p>
          <.trends samples={@samples} w={720} h={140} class="mt-3" />
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
