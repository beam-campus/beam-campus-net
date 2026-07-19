defmodule BeamCampusWeb.HomeLive do
  @moduledoc """
  The BEAM Campus landing page — the public face of the research commons.

  Content is grounded in the position paper: a commons, not a company; the
  defensible value is a network, a mark and a reputation; sustained by grants,
  patrons, contributed compute and modest participatory income.
  """
  use BeamCampusWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "A European Research Commons")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.hero />
      <.thesis />
      <.substrate />
      <.commons />
      <.sustain />
      <.join />
      <.site_footer />
    </Layouts.app>
    """
  end

  # ── Hero ──────────────────────────────────────────────────────────────
  defp hero(assigns) do
    ~H"""
    <section class="relative overflow-hidden border-b border-base-300/60">
      <div class="pointer-events-none absolute inset-0 opacity-90">
        <.node_field />
      </div>
      <div
        class="beam-sweep pointer-events-none"
        style="position:absolute; inset:-40% -60%; background:linear-gradient(115deg,transparent 42%,rgba(255,217,137,0.16) 50%,transparent 58%);"
      >
      </div>

      <div class="relative mx-auto max-w-5xl px-6 py-24 sm:py-32">
        <p class="font-mono text-xs uppercase tracking-[0.28em] text-primary">
          A European Research Commons
        </p>
        <h1 class="mt-5 text-5xl sm:text-7xl font-semibold tracking-tight text-balance">
          <span class="font-mono font-bold">BEAM</span> Campus
        </h1>
        <div
          class="mt-6 h-1 w-48 rounded"
          style="background:linear-gradient(90deg,var(--color-primary),transparent);"
        >
        </div>
        <p class="mt-6 max-w-2xl text-lg sm:text-xl text-base-content/80">
          A European substrate for research into <strong>sovereign, distributed and
            evolutionary AI</strong> — a mesh of small, cheap, low-power nodes, owned by
          no one and by everyone, running meaningful workloads outside the reach of
          Big Tech and Big Politics.
        </p>
        <div class="mt-9 flex flex-wrap gap-3">
          <a href="#join" class="btn btn-primary">
            Take part <span aria-hidden="true">&rarr;</span>
          </a>
          <a href="#thesis" class="btn btn-outline">Read the thesis</a>
        </div>
        <p class="mt-8 font-mono text-xs text-base-content/50">
          BEAM = the Erlang virtual machine · the beam of light is a wink
        </p>
      </div>
    </section>
    """
  end

  # ── Thesis ────────────────────────────────────────────────────────────
  defp thesis(assigns) do
    ~H"""
    <section id="thesis" class="mx-auto max-w-3xl px-6 py-20 sm:py-24">
      <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">The frame</p>
      <p class="mt-6 text-2xl sm:text-3xl leading-snug text-balance">
        Macula was never a product. It is research infrastructure — closer to an
        independent lab than a software vendor. So the correct frame is a <strong class="text-primary">research commons</strong>, not a company.
      </p>
      <p class="mt-6 text-base-content/70 leading-relaxed">
        A product optimises for capture: lock-in, proprietary advantage, an addressable
        market. A commons optimises for reach, correctness, participation and durability.
        Beyond a point, the two are opposed — and we chose the commons. The research
        stays open (AGPL, published); what is protected is the network, the mark and the
        reputation, held in stewardship.
      </p>
    </section>
    """
  end

  # ── The substrate ─────────────────────────────────────────────────────
  defp substrate(assigns) do
    ~H"""
    <section id="substrate" class="border-y border-base-300/60 bg-base-200/40">
      <div class="mx-auto max-w-6xl px-6 py-20 sm:py-24">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">The substrate</p>
        <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight">
          One stack, built on the BEAM
        </h2>
        <p class="mt-4 max-w-2xl text-base-content/70">
          Population-based, evolutionary AI is embarrassingly parallel and hungry for
          cheap, distributed compute — the workload a federated mesh is best suited to,
          and a hyperscale cloud is worst. The architecture of the science and the
          architecture of the substrate agree.
        </p>

        <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.pillar name="Macula" role="The network" accent="primary">
            A federated relay mesh over QUIC — DHT routing, membership and identity.
            Populations of agents live, migrate and are evaluated here, with no central
            owner and no single-provider dependency.
          </.pillar>
          <.pillar name="ReckonDB" role="The data" accent="secondary">
            A BEAM-native event store with zero external dependencies — no PostgreSQL,
            no Kafka, no Redis. Raft consensus, a full CQRS / event-sourcing framework.
          </.pillar>
          <.pillar name="Hecate" role="The platform" accent="secondary">
            A sovereign application platform: a mesh-connected, event-sourced daemon plus
            a desktop app and an app store for extension capabilities.
          </.pillar>
          <.pillar name="Faber" role="The evolution" accent="accent">
            The evolutionary layer — neuroevolution (TWEANN) on the BEAM. Populations
            evolve across many small, unreliable, scattered machines. Gene Sher's Spartan
            agents are among the first inhabitants.
          </.pillar>
        </div>
      </div>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :role, :string, required: true
  attr :accent, :string, default: "primary"
  slot :inner_block, required: true

  defp pillar(assigns) do
    ~H"""
    <article class="card bg-base-100 border border-base-300 h-full">
      <div class="card-body gap-2">
        <span class={["font-mono text-[11px] uppercase tracking-widest", accent_class(@accent)]}>
          {@role}
        </span>
        <h3 class="text-xl font-semibold">{@name}</h3>
        <p class="text-sm text-base-content/70 leading-relaxed">{render_slot(@inner_block)}</p>
      </div>
    </article>
    """
  end

  # ── The commons: value theory ─────────────────────────────────────────
  defp commons(assigns) do
    ~H"""
    <section id="commons" class="mx-auto max-w-6xl px-6 py-20 sm:py-24">
      <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">The commons</p>
      <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight text-balance">
        The value is real — it just isn't proprietary code
      </h2>
      <p class="mt-4 max-w-2xl text-base-content/70">
        In a commons the defensible assets are genuine, but none of them is a patent
        portfolio. The right instrument is <strong>AGPL plus trademark</strong>, held by
        a steward — protection without enclosure.
      </p>

      <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.asset title="The network">
          A federation of contributed nodes, worth more as it grows and near-impossible
          to replicate. You cannot fork a community or copy the trust that holds a mesh
          together.
        </.asset>
        <.asset title="The trademark">
          "Macula" and "BEAM Campus" as marks. Anyone may run the software; only the
          commons may call itself the commons.
        </.asset>
        <.asset title="The reputation">
          Published results, working infrastructure, and the standing of the group that
          built Europe's sovereign substrate for evolutionary AI.
        </.asset>
        <.asset title="The know-how">
          The tacit expertise of the people who built and understand the substrate —
          monetisable as research capacity, never as closed research.
        </.asset>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp asset(assigns) do
    ~H"""
    <div class="border-l-2 border-primary/60 pl-4">
      <h3 class="font-semibold">{@title}</h3>
      <p class="mt-2 text-sm text-base-content/70 leading-relaxed">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  # ── Sustainability ────────────────────────────────────────────────────
  defp sustain(assigns) do
    ~H"""
    <section class="border-y border-base-300/60 bg-base-200/40">
      <div class="mx-auto max-w-3xl px-6 py-16 text-center">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">Sustainability</p>
        <p class="mt-5 text-2xl sm:text-3xl font-semibold text-balance">
          Monetise participation and convenience.<br />
          <span class="text-primary">Never monetise the research.</span>
        </p>
        <p class="mt-5 text-base-content/70">
          Grants, patrons, contributed compute and modest participatory income can pay a
          researcher a fair wage and keep the lights on — none of it turning the science
          into a product. A museum charges for the shop and the café while the collection
          stays free to view.
        </p>
      </div>
    </section>
    """
  end

  # ── The three asks ────────────────────────────────────────────────────
  defp join(assigns) do
    ~H"""
    <section id="join" class="mx-auto max-w-6xl px-6 py-20 sm:py-24">
      <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">Take part</p>
      <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight">
        Three ways in, in ascending commitment
      </h2>

      <div class="mt-10 grid gap-4 lg:grid-cols-3">
        <.ask n="01" title="Run a node" cta="How to run a node">
          Contribute compute to the substrate and grow the federation. The lowest-friction
          contribution there is — and it makes you a literal participant, not a customer.
        </.ask>
        <.ask n="02" title="Become a patron" cta="Become a patron">
          Fund the commons and take a seat as a co-researcher. You pay for alignment,
          participation and talent — never for private privilege.
        </.ask>
        <.ask n="03" title="Open a door" cta="Open a door">
          Help secure institutional affiliation, introduce a funder, or lend a name to a
          grant consortium. Institution first; then the doors closed to a person open to
          the commons.
        </.ask>
      </div>
    </section>
    """
  end

  attr :n, :string, required: true
  attr :title, :string, required: true
  attr :cta, :string, required: true
  slot :inner_block, required: true

  defp ask(assigns) do
    ~H"""
    <article class="card bg-base-100 border border-base-300 h-full">
      <div class="card-body gap-3">
        <span class="font-mono text-sm text-primary tracking-widest">{@n}</span>
        <h3 class="text-xl font-semibold">{@title}</h3>
        <p class="text-sm text-base-content/70 leading-relaxed flex-1">{render_slot(@inner_block)}</p>
        <a href="mailto:raf.lefever@erlef.org" class="btn btn-outline btn-sm w-fit mt-2">
          {@cta}
        </a>
      </div>
    </article>
    """
  end

  # ── Footer ────────────────────────────────────────────────────────────
  defp site_footer(assigns) do
    ~H"""
    <footer class="border-t border-base-300/60 bg-base-200/60">
      <div class="mx-auto max-w-6xl px-6 py-12">
        <div class="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
          <img
            src={~p"/images/beam-campus-horizontal.svg"}
            alt="BEAM Campus"
            class="h-8 w-auto opacity-90"
          />
          <p class="font-mono text-xs text-base-content/50 tracking-wide">
            AGPL + trademark · held in stewardship for the commons
          </p>
        </div>
        <div class="mt-8 flex flex-wrap gap-x-6 gap-y-2 font-mono text-xs text-base-content/50">
          <span class="text-secondary">MACULA</span>
          <span>RECKONDB</span>
          <span>HECATE</span>
          <span>FABER</span>
          <span class="grow"></span>
          <a href="mailto:raf.lefever@erlef.org" class="link link-hover">raf.lefever@erlef.org</a>
        </div>
      </div>
    </footer>
    """
  end

  # ── Hero node field (inline SVG, decorative) ──────────────────────────
  defp node_field(assigns) do
    ~H"""
    <svg
      class="h-full w-full"
      viewBox="0 0 1280 640"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
    >
      <defs>
        <radialGradient id="hero-glow" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stop-color="#FFD989" stop-opacity="0.8" />
          <stop offset="1" stop-color="#F2B142" stop-opacity="0" />
        </radialGradient>
      </defs>
      <g stroke="var(--color-base-300)" stroke-width="1.4" fill="none" opacity="0.7">
        <line x1="880" y1="120" x2="1010" y2="180" /><line x1="880" y1="120" x2="900" y2="270" />
        <line x1="1010" y1="180" x2="1060" y2="300" /><line x1="900" y1="270" x2="1060" y2="300" />
        <line x1="900" y1="270" x2="980" y2="440" /><line x1="1060" y1="300" x2="1120" y2="440" />
      </g>
      <g stroke="#F2B142" stroke-width="2" fill="none" opacity="0.7">
        <line x1="880" y1="120" x2="900" y2="270" /><line x1="900" y1="270" x2="1060" y2="300" />
      </g>
      <g>
        <circle cx="880" cy="120" r="18" fill="url(#hero-glow)" />
        <circle cx="900" cy="270" r="22" fill="url(#hero-glow)" />
        <circle cx="1060" cy="300" r="18" fill="url(#hero-glow)" />
      </g>
      <g stroke="#FFD989" stroke-width="3" fill="#F2B142">
        <circle cx="880" cy="120" r="9" /><circle cx="900" cy="270" r="11" /><circle
          cx="1060"
          cy="300"
          r="9"
        />
      </g>
      <line x1="980" y1="440" x2="1070" y2="500" stroke="#5FD08A" stroke-width="2.4" opacity="0.9" />
      <circle cx="980" cy="440" r="8" fill="var(--color-base-100)" stroke="#5FD08A" stroke-width="3" />
      <circle cx="1070" cy="500" r="5" fill="#5FD08A" />
    </svg>
    """
  end

  # Literal classes so Tailwind's JIT sees them (no interpolated class names).
  defp accent_class("secondary"), do: "text-secondary"
  defp accent_class("accent"), do: "text-accent"
  defp accent_class(_), do: "text-primary"
end
