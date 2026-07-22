defmodule BeamCampusWeb.ResearchLive do
  @moduledoc """
  The Faber neuroevolution research agenda — outward-facing.

  Surfaces the nine research programmes (one engine, two couplings) and links
  each charter to its canonical home in the faber-ecosystem corpus on Codeberg.
  This page does not host the charters; it points to them, so the corpus stays
  the single source of truth. Copy is commons-framed: participation and shared
  findings, never product or market.
  """
  use BeamCampusWeb, :live_view

  @corpus "https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master"
  @charters "#{@corpus}/plans"

  # One engine (P1-P7), two couplings (P8 language, P9 body).
  @programmes [
    %{
      n: "P1",
      name: "Capabilities",
      axis: "Representation — what the network can express",
      status: "Closed",
      group: :engine,
      file: "CHARTER_P1_CAPABILITIES.md",
      blurb:
        "Which network capability (tuner depth, memory mechanism, topology) helps which problem. Arc: capability value = task-match x budget x optimizer."
    },
    %{
      n: "P2",
      name: "Search Strategies",
      axis: "Operators — variation and selection",
      status: "Active",
      group: :engine,
      file: "CHARTER_P2_SEARCH_STRATEGIES.md",
      blurb:
        "Which search algorithm (GA, ES, CMA-ES, CoSyNE) suits which landscape, and whether a stronger optimizer overturns the capability findings."
    },
    %{
      n: "P3",
      name: "Meta-learning",
      axis: "Meta-adaptation — learning to learn",
      status: "Next",
      group: :engine,
      file: "CHARTER_P3_META_LEARNING.md",
      blurb:
        "Evolved plasticity and lifetime learning: the system adapts its own learning, not just its weights."
    },
    %{
      n: "P4",
      name: "Objectives",
      axis: "Selection pressure — what fitness rewards",
      status: "Open",
      group: :engine,
      file: "CHARTER_P4_OBJECTIVES.md",
      blurb:
        "Quality-Diversity and novelty search: reward diversity and stepping-stones rather than a single objective. The answer to deception."
    },
    %{
      n: "P5",
      name: "Scale / Substrate",
      axis: "Distribution of the search — mesh and federation",
      status: "Open",
      group: :engine,
      file: "CHARTER_P5_SCALE_SUBSTRATE.md",
      blurb:
        "Island models, distributed populations, and federated evolution across independently owned mesh nodes. Where the substrate becomes the subject."
    },
    %{
      n: "P6",
      name: "Encoding / Development",
      axis: "Genotype to phenotype — direct vs generative",
      status: "Open",
      group: :engine,
      file: "CHARTER_P6_ENCODING_DEVELOPMENT.md",
      blurb:
        "Direct versus indirect and developmental encodings (CPPN, HyperNEAT, cellular encoding). The axis that gates scale-up."
    },
    %{
      n: "P7",
      name: "Coevolution / Self-play",
      axis: "Interaction — fitness from contest",
      status: "Open",
      group: :engine,
      file: "CHARTER_P7_COEVOLUTION.md",
      blurb:
        "Competitive and cooperative coevolution, arms races, and open-endedness, where the problem itself moves as agents interact."
    },
    %{
      n: "P8",
      name: "LLM-augmented Evolution",
      axis: "Augmentation — language in the loop",
      status: "Horizon",
      group: :coupling,
      file: "CHARTER_P8_LLM_AUGMENTED.md",
      blurb:
        "Language models as intelligent variation operators and objective authors; the bridge between neuroevolution and language-model cognition."
    },
    %{
      n: "P9",
      name: "DARS / Physical AI",
      axis: "Embodiment at scale — distributed robots",
      status: "Horizon",
      group: :coupling,
      file: "CHARTER_P9_DARS.md",
      blurb:
        "Distributed Autonomous Robotic Systems: swarms, embodied evolution, and sim-to-real, with the mesh as the coordination fabric."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Research — the Faber programmes",
       programmes: @programmes,
       charters_base: @charters,
       root_url: "#{@charters}/PLAN_PROGRAMMES_ROOT.md",
       corpus_url: "#{@corpus}/insights/INDEX.md"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.intro root_url={@root_url} />
      <.couplings />
      <.map programmes={@programmes} charters_base={@charters_base} />
      <.fork />
      <.contribute corpus_url={@corpus_url} root_url={@root_url} />
      <.research_footer root_url={@root_url} corpus_url={@corpus_url} />
    </Layouts.app>
    """
  end

  # ── Intro ─────────────────────────────────────────────────────────────
  defp intro(assigns) do
    ~H"""
    <section class="border-b border-base-300/60">
      <div class="mx-auto max-w-5xl px-6 py-20 sm:py-28">
        <p class="font-mono text-xs uppercase tracking-[0.28em] text-primary">
          Research · Faber
        </p>
        <h1 class="mt-5 text-4xl sm:text-6xl font-semibold tracking-tight text-balance">
          Nine programmes for evolving intelligence on the BEAM
        </h1>
        <p class="mt-6 max-w-2xl text-lg text-base-content/80 leading-relaxed">
          Faber is the evolutionary layer of the stack: neuroevolution built to run
          populations across a federated mesh. Its research is organised as an open,
          signed corpus — every finding, positive or negative, written down and grounded
          in the literature. These are the programmes that corpus is built around.
        </p>
        <div class="mt-9 flex flex-wrap gap-3">
          <a href={@root_url} class="btn btn-primary" target="_blank" rel="noreferrer">
            The master charter <span aria-hidden="true">&rarr;</span>
          </a>
          <.link navigate={~p"/research/adaptation"} class="btn btn-outline">
            ▶ Live demo: post-deployment adaptation
          </.link>
        </div>
      </div>
    </section>
    """
  end

  # ── One engine, two couplings ─────────────────────────────────────────
  defp couplings(assigns) do
    ~H"""
    <section class="border-b border-base-300/60 bg-base-200/40">
      <div class="mx-auto max-w-6xl px-6 py-20 sm:py-24">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">The shape</p>
        <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight text-balance">
          One engine, two couplings
        </h2>
        <p class="mt-4 max-w-2xl text-base-content/70 leading-relaxed">
          Seven programmes are the evolutionary engine — the near-orthogonal axes of the
          design space. Two more couple that engine to the world: to language, and to the
          body. It is the symbol-grounding problem drawn as a map.
        </p>

        <div class="mt-10 grid gap-4 lg:grid-cols-3 lg:items-stretch">
          <.coupling_card kicker="P9 · the body" title="DARS / Physical AI" accent="accent">
            Distributed robots, swarms, embodied evolution and sim-to-real. Sensorimotor
            ground, at collective scale.
          </.coupling_card>

          <article class="card border-2 border-primary/40 bg-base-100">
            <div class="card-body gap-2">
              <span class="font-mono text-[11px] uppercase tracking-widest text-primary">
                P1 – P7 · the engine
              </span>
              <h3 class="text-xl font-semibold">The evolutionary engine</h3>
              <p class="text-sm text-base-content/70 leading-relaxed">
                Representation, search, meta-adaptation, objectives, scale, encoding and
                coevolution — the seven axes that hold steady while each is varied in turn,
                so findings compose.
              </p>
            </div>
          </article>

          <.coupling_card kicker="P8 · language" title="LLM-augmented Evolution" accent="secondary">
            Language models as variation operators and objective authors. The bridge to
            language-model cognition.
          </.coupling_card>
        </div>
      </div>
    </section>
    """
  end

  attr :kicker, :string, required: true
  attr :title, :string, required: true
  attr :accent, :string, default: "primary"
  slot :inner_block, required: true

  defp coupling_card(assigns) do
    ~H"""
    <article class="card bg-base-100 border border-base-300 h-full">
      <div class="card-body gap-2">
        <span class={["font-mono text-[11px] uppercase tracking-widest", accent_class(@accent)]}>
          {@kicker}
        </span>
        <h3 class="text-xl font-semibold">{@title}</h3>
        <p class="text-sm text-base-content/70 leading-relaxed">{render_slot(@inner_block)}</p>
      </div>
    </article>
    """
  end

  # ── The map ───────────────────────────────────────────────────────────
  defp map(assigns) do
    ~H"""
    <section class="mx-auto max-w-6xl px-6 py-20 sm:py-24">
      <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">The programmes</p>
      <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight">
        The nine charters
      </h2>
      <p class="mt-4 max-w-2xl text-base-content/70">
        Each programme has a charter: its axis, its open questions, a first experiment, and
        where the literature already stands. One is the active front; the rest are chartered
        and open to take up.
      </p>

      <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <.programme_card :for={p <- @programmes} p={p} charters_base={@charters_base} />
      </div>
    </section>
    """
  end

  attr :p, :map, required: true
  attr :charters_base, :string, required: true

  defp programme_card(assigns) do
    ~H"""
    <article class="card bg-base-100 border border-base-300 h-full">
      <div class="card-body gap-2">
        <div class="flex items-center justify-between">
          <span class="font-mono text-[11px] uppercase tracking-widest text-base-content/50">
            {@p.n}
          </span>
          <span class={["badge badge-sm", status_class(@p.status)]}>{@p.status}</span>
        </div>
        <h3 class="text-lg font-semibold">{@p.name}</h3>
        <p class="font-mono text-[11px] text-base-content/50">{@p.axis}</p>
        <p class="text-sm text-base-content/70 leading-relaxed flex-1">{@p.blurb}</p>
        <a
          href={"#{@charters_base}/#{@p.file}"}
          target="_blank"
          rel="noreferrer"
          class="link link-hover text-sm text-primary w-fit mt-1"
        >
          Read the charter <span aria-hidden="true">&rarr;</span>
        </a>
      </div>
    </article>
    """
  end

  # ── The current fork ──────────────────────────────────────────────────
  defp fork(assigns) do
    ~H"""
    <section class="border-y border-base-300/60 bg-base-200/40">
      <div class="mx-auto max-w-3xl px-6 py-20 sm:py-24">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">Where it stands</p>
        <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight text-balance">
          One wall, three explanations
        </h2>
        <p class="mt-6 text-base-content/70 leading-relaxed">
          Two programmes have converged on the same open question: a classic non-Markov
          control benchmark that neither the genetic algorithm nor a self-adaptive evolution
          strategy has solved. That single wall has three competing explanations, one on each
          of three axes, and the near-term work is a clean fork that resolves which:
        </p>
        <ul class="mt-6 space-y-3 text-sm">
          <li class="flex gap-3">
            <span class="font-mono text-primary shrink-0">P3</span>
            <span class="text-base-content/70">
              <strong>Representation</strong> — the memory timescale is fixed and cannot evolve.
            </span>
          </li>
          <li class="flex gap-3">
            <span class="font-mono text-primary shrink-0">P2</span>
            <span class="text-base-content/70">
              <strong>Optimizer</strong> — the search is too weak for the landscape.
            </span>
          </li>
          <li class="flex gap-3">
            <span class="font-mono text-primary shrink-0">P4</span>
            <span class="text-base-content/70">
              <strong>Deception</strong> — the fitness gradient leads away from the solution.
            </span>
          </li>
        </ul>
        <p class="mt-6 text-base-content/70 leading-relaxed">
          Whichever leg breaks the wall first becomes a signed finding; the ones that do not
          are signed negatives, and just as valuable.
        </p>
      </div>
    </section>
    """
  end

  # ── Contribute ────────────────────────────────────────────────────────
  defp contribute(assigns) do
    ~H"""
    <section class="mx-auto max-w-6xl px-6 py-20 sm:py-24">
      <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">Take part</p>
      <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight">
        Pick a charter, run an experiment, sign a finding
      </h2>
      <p class="mt-4 max-w-2xl text-base-content/70">
        The corpus is a commons. The harness is built and green; the open questions are small
        enough to start on in days. An open charter names its first experiment against tools
        that already run.
      </p>

      <div class="mt-10 grid gap-4 lg:grid-cols-3">
        <.step n="1" title="Read the charter">
          Each open programme states its axis, its first experiment, and where the literature
          already stands, so you begin with grounding rather than a blank page.
        </.step>
        <.step n="2" title="Run against the harness">
          The scapes, the evolutionary loop, and the plan-feed-insight cycle are in place. A
          first experiment is a bounded run, not a new framework.
        </.step>
        <.step n="3" title="Sign the finding">
          Write the result into the shared corpus — evidence cited, negatives kept. Findings
          are reported as reproducible replication, never overclaimed as discovery.
        </.step>
      </div>

      <div class="mt-10 flex flex-wrap gap-3">
        <a href={@root_url} class="btn btn-primary" target="_blank" rel="noreferrer">
          The programme map <span aria-hidden="true">&rarr;</span>
        </a>
        <a href={@corpus_url} class="btn btn-outline" target="_blank" rel="noreferrer">
          The signed corpus
        </a>
        <a href="mailto:raf.lefever@erlef.org" class="btn btn-ghost">Say hello</a>
      </div>
    </section>
    """
  end

  attr :n, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp step(assigns) do
    ~H"""
    <article class="card bg-base-100 border border-base-300 h-full">
      <div class="card-body gap-2">
        <span class="font-mono text-2xl font-bold text-primary/70">{@n}</span>
        <h3 class="text-lg font-semibold">{@title}</h3>
        <p class="text-sm text-base-content/70 leading-relaxed">{render_slot(@inner_block)}</p>
      </div>
    </article>
    """
  end

  # ── Footer ────────────────────────────────────────────────────────────
  defp research_footer(assigns) do
    ~H"""
    <footer class="border-t border-base-300/60 bg-base-200/60">
      <div class="mx-auto max-w-6xl px-6 py-12">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <a href={~p"/"} class="link link-hover font-mono text-xs text-base-content/60">
            &larr; BEAM Campus
          </a>
          <div class="flex flex-wrap gap-x-6 gap-y-2 font-mono text-xs text-base-content/50">
            <a href={@root_url} class="link link-hover" target="_blank" rel="noreferrer">
              programme map
            </a>
            <a href={@corpus_url} class="link link-hover" target="_blank" rel="noreferrer">
              signed corpus
            </a>
            <a
              href="https://codeberg.org/rgfaber/faber-ecosystem"
              class="link link-hover"
              target="_blank"
              rel="noreferrer"
            >
              faber-ecosystem
            </a>
          </div>
        </div>
      </div>
    </footer>
    """
  end

  # Literal classes so Tailwind's JIT sees them (no interpolated class names).
  defp accent_class("secondary"), do: "text-secondary"
  defp accent_class("accent"), do: "text-accent"
  defp accent_class(_), do: "text-primary"

  defp status_class("Active"), do: "badge-primary"
  defp status_class("Next"), do: "badge-secondary"
  defp status_class("Open"), do: "badge-outline badge-accent"
  defp status_class("Closed"), do: "badge-ghost"
  defp status_class("Horizon"), do: "badge-ghost"
  defp status_class(_), do: "badge-ghost"
end
