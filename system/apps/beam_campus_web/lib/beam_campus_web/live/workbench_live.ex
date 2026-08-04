defmodule BeamCampusWeb.WorkbenchLive do
  @moduledoc """
  The workbench index: a catalogue of runnable faber experiments. Each card is a
  self-contained live demo (its own LiveView + backend slice) and cross-links to its
  other three faces — the programme charter (why), the signed insight (rigorous), and
  the notebook note (plain language). A `:planned` card links to its note until its
  interactive demo is built; building one flips it to `:interactive`.
  """
  use BeamCampusWeb, :live_view

  @experiments [
    %{
      id: "asociety",
      title: "A Society: cultures on machines that decide who lands",
      tag: "Artificial cultures \u00b7 mesh",
      kind: :engine,
      status: :scaffold,
      route: "/research/workbench/asociety",
      programme: "Succeeds the biotope",
      # ⚠ ITS RECORD IS NOT IN faber-ecosystem. This line keeps its own charter,
      # design documents and register in hecate-society, with numbering continued
      # from the biotope. A card that linked to the faber insight index would send
      # a reader to a corpus that has never heard of it.
      record_label: "hecate-society / charter",
      record_url: "https://github.com/hecate-services/hecate-society/blob/main/CHARTER.md",
      note: nil,
      blurb:
        "Islands of persons who hold two kinds of belief: what they were told, and what they have seen. Every formal model of cultural evolution runs on a graph somebody drew; here an island is a machine, a partition is a barrier nobody chose, and each island decides who may land. Scaffold: four islands are deployed and hold no people, so the page reports which of five states it is in rather than drawing an empty chart. It will draw beliefs, never a map."
    },
    %{
      id: "biotope",
      title: "Biotopes: open populations on the mesh",
      tag: "ALife · mesh",
      kind: :engine,
      status: :interactive,
      route: "/research/workbench/biotope",
      programme: "P5 · Scale / Substrate",
      insight: "061-062",
      note: "/research/notes/too-loose-or-too-tight",
      blurb:
        "An island on a machine in the lab: plants grow, creatures forage, breed and starve, and it says what happened. Nothing has a brain yet, so the creatures walk at random \u2014 they are the null forager any later brain has to beat. This page subscribes and draws the last frame that arrived; it runs no world of its own and shares no code with the islands. Starvation outnumbers old age about seventy to one, which is another way of saying selection pressure exists."
    },
    %{
      id: "robo-rumble",
      title: "Robo Rumble: a field of forty, live from the mesh",
      tag: "Tank duels · mesh",
      kind: :engine,
      status: :interactive,
      route: "/research/workbench/robo-rumble",
      programme: "P8 · Robo Rumble",
      insight: "058-066",
      note: "/research/notes/our-tank-lost-every-fight",
      blurb:
        "Forty trained tanks hold a field on a machine in the lab. Visitors send a genome, it fights all forty from eighty geometries in both seats, and the row is published to the mesh. This page subscribes to it, and re-runs the featured duels here: the fight is not shipped, it is regenerated from two genomes and a start index, because the engine is deterministic to the turn."
    },
    %{
      id: "neural-coevolution",
      title: "Neural coevolution: pursuers vs evaders",
      tag: "Coevolution · torus",
      kind: :engine,
      status: :interactive,
      route: "/research/workbench/neural-coevolution",
      programme: "P7 · Coevolution",
      insight: "053-055",
      note: "/research/notes/running-to-stay-in-place",
      blurb:
        "Two populations of faber-tweann networks coevolve; every move is a live forward pass. Watch a champion chase end in a capture, and the honest outcome: disengagement, not an arms race. A two-sided race is a knife-edge."
    },
    %{
      id: "red-queen",
      title: "The Red Queen: running to stay in place",
      tag: "Coevolution methodology",
      kind: :methodology,
      status: :interactive,
      route: "/research/workbench/red-queen",
      programme: "P7 · Coevolution",
      insight: "053",
      note: "/research/notes/running-to-stay-in-place",
      blurb:
        "Numbers, not networks, on purpose: the trait escalates without bound while the score against current rivals stays flat. The measurement trap that calibrates the ruler before we trust it on the real engine."
    },
    %{
      id: "deception-maze",
      title: "Abandoning the objective",
      tag: "Deceptive maze",
      kind: :engine,
      status: :interactive,
      route: "/research/workbench/deception-maze",
      programme: "P4 · Objectives",
      insight: "051",
      note: "/research/notes/abandoning-the-objective",
      blurb:
        "A maze built as a trap: the way to the goal first leads away. Goal-chasing jams in the cul-de-sac; novelty search walks around and out. Watch two champions race, then evolve it live."
    },
    %{
      id: "adaptation",
      title: "Adapt to a broken world",
      tag: "Cart-pole · motor fault",
      kind: :engine,
      status: :interactive,
      route: "/research/workbench/adaptation",
      programme: "P3 · Meta-learning",
      insight: "046",
      note: "/research/notes/remember-or-rewire",
      blurb:
        "Evolve a pole-balancer, then reverse its motor mid-run. A fixed controller topples; a plastic one re-wires itself to recover. Evolution and physics both run live on the engine."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Workbench — runnable faber experiments",
       experiments: @experiments
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="border-b border-base-300/60">
        <div class="mx-auto max-w-5xl px-6 py-16 sm:py-20">
          <.link
            navigate={~p"/research"}
            class="link link-hover font-mono text-xs text-base-content/50"
          >
            &larr; Research
          </.link>
          <p class="font-mono text-xs uppercase tracking-[0.28em] text-primary mt-4">
            Workbench · Faber
          </p>
          <h1 class="mt-4 text-4xl sm:text-5xl font-semibold tracking-tight text-balance">
            Watch the findings run
          </h1>
          <p class="mt-5 max-w-2xl text-lg text-base-content/80 leading-relaxed">
            Each experiment here is a signed result you can drive yourself — evolution and inference
            on the real faber-tweann engine, on the server, in front of you. Every one links back to
            its programme, its rigorous corpus entry, and its plain-language note.
          </p>
        </div>
      </section>

      <section class="mx-auto max-w-5xl px-6 py-14 sm:py-16">
        <div class="grid gap-5 sm:grid-cols-2">
          <.experiment_card :for={x <- @experiments} x={x} />
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :x, :map, required: true

  defp experiment_card(assigns) do
    ~H"""
    <article class="card bg-base-100 border border-base-300 h-full">
      <div class="card-body gap-3">
        <div class="flex items-center justify-between">
          <span class="font-mono text-[11px] uppercase tracking-widest text-base-content/50">
            {@x.tag}
          </span>
          <span class={["badge badge-sm", status_class(@x.status)]}>{status_label(@x.status)}</span>
        </div>
        <div class="flex items-center gap-2">
          <h2 class="text-xl font-semibold">{@x.title}</h2>
          <span class={["badge badge-xs whitespace-nowrap", kind_class(@x.kind)]}>
            {kind_label(@x.kind)}
          </span>
        </div>
        <p class="text-sm text-base-content/70 leading-relaxed flex-1">{@x.blurb}</p>

        <div class="flex flex-wrap gap-x-4 gap-y-1 font-mono text-[11px] text-base-content/50">
          <span>{@x.programme}</span>
          <.record x={@x} />
          <.note :if={@x[:note]} note={@x.note} />
        </div>

        <.open_link x={@x} />
      </div>
    </article>
    """
  end

  # Most cards point at the faber insight index. A line that keeps its own corpus
  # names it instead, because sending a reader to a corpus that has never heard of
  # the experiment is worse than sending them nowhere.
  attr :x, :map, required: true

  defp record(%{x: %{insight: _i}} = assigns) do
    ~H"""
    <a
      href="https://github.com/rgfaber/faber-ecosystem/blob/master/insights/INDEX.md"
      class="link link-hover"
      target="_blank"
      rel="noreferrer"
    >
      insight {@x.insight}
    </a>
    """
  end

  defp record(assigns) do
    ~H"""
    <a href={@x.record_url} class="link link-hover" target="_blank" rel="noreferrer">
      {@x.record_label}
    </a>
    """
  end

  attr :note, :string, required: true

  defp note(assigns) do
    ~H"""
    <.link navigate={@note} class="link link-hover">the note</.link>
    """
  end

  attr :x, :map, required: true

  defp open_link(%{x: %{status: :interactive}} = assigns) do
    ~H"""
    <.link navigate={@x.route} class="btn btn-primary btn-sm w-fit mt-1">
      Open the experiment <span aria-hidden="true">&rarr;</span>
    </.link>
    """
  end

  defp open_link(%{x: %{status: :scaffold}} = assigns) do
    ~H"""
    <.link navigate={@x.route} class="btn btn-outline btn-sm w-fit mt-1">
      Open the scaffold <span aria-hidden="true">&rarr;</span>
    </.link>
    """
  end

  defp open_link(assigns) do
    ~H"""
    <.link navigate={@x.note} class="btn btn-outline btn-sm w-fit mt-1">
      Read the note (demo coming) <span aria-hidden="true">&rarr;</span>
    </.link>
    """
  end

  defp kind_class(:engine), do: "badge-success badge-outline"
  defp kind_class(:methodology), do: "badge-ghost"
  defp kind_label(:engine), do: "real engine"
  defp kind_label(:methodology), do: "methodology · numbers"

  defp status_class(:interactive), do: "badge-primary"
  defp status_class(:scaffold), do: "badge-info"
  defp status_class(:planned), do: "badge-ghost"

  defp status_label(:interactive), do: "live"
  defp status_label(:scaffold), do: "scaffold"
  defp status_label(:planned), do: "planned"
end
