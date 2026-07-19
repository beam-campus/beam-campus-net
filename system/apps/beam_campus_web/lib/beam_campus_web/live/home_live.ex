defmodule BeamCampusWeb.HomeLive do
  @moduledoc """
  The BEAM Campus landing page — outward-facing.

  Describes what BEAM Campus is, the open stack, and how to take part. It sells
  the invitation, not internal strategy: no funding model, no governance or IP
  reasoning, no motivations beyond the public identity.
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
      <.what_it_is />
      <.stack />
      <.why_mesh />
      <.take_part />
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
          Open infrastructure for <strong>sovereign, distributed and evolutionary AI</strong> —
          built on the BEAM, running across a federation of small machines owned by no one
          and open to everyone.
        </p>
        <div class="mt-9 flex flex-wrap gap-3">
          <a href="#stack" class="btn btn-primary">
            Explore the stack <span aria-hidden="true">&rarr;</span>
          </a>
          <a href="#take-part" class="btn btn-outline">Get involved</a>
        </div>
        <p class="mt-8 font-mono text-xs text-base-content/50">
          Open source · European · built on the BEAM (Erlang/OTP)
        </p>
      </div>
    </section>
    """
  end

  # ── What it is ────────────────────────────────────────────────────────
  defp what_it_is(assigns) do
    ~H"""
    <section class="mx-auto max-w-3xl px-6 py-20 sm:py-24">
      <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">What it is</p>
      <p class="mt-6 text-2xl sm:text-3xl leading-snug text-balance">
        AI that runs on many small machines — not one big cloud.
      </p>
      <p class="mt-6 text-base-content/70 leading-relaxed">
        BEAM Campus is an open, European effort to build the infrastructure for distributed
        and evolutionary AI: a federated mesh of small, low-power nodes that anyone can join,
        with no central owner. The tools are open source and run on the BEAM — the Erlang
        virtual machine behind decades of resilient, highly concurrent, distributed systems.
      </p>
    </section>
    """
  end

  # ── The stack ─────────────────────────────────────────────────────────
  defp stack(assigns) do
    ~H"""
    <section id="stack" class="border-y border-base-300/60 bg-base-200/40">
      <div class="mx-auto max-w-6xl px-6 py-20 sm:py-24">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">The stack</p>
        <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight">
          Four open pieces, one substrate
        </h2>
        <p class="mt-4 max-w-2xl text-base-content/70">
          Each layer stands on its own and is open source. Together they let populations of
          agents live, migrate and evolve across the mesh.
        </p>

        <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.pillar name="Macula" role="The network" accent="primary">
            A federated relay mesh over QUIC — DHT routing, membership and identity. Nodes
            connect across Europe with no single provider and automatic failover.
          </.pillar>
          <.pillar name="ReckonDB" role="The data" accent="secondary">
            A BEAM-native event store with zero external dependencies — distributed event
            sourcing on Raft, with a full CQRS framework. Published on hex.pm.
          </.pillar>
          <.pillar name="Hecate" role="The platform" accent="secondary">
            A sovereign application platform: a mesh-connected daemon plus a desktop app and
            an app store for extensions.
          </.pillar>
          <.pillar name="Faber" role="The evolution" accent="accent">
            The evolutionary layer — neuroevolution (topology-and-weight-evolving neural
            networks) on the BEAM, built to evolve populations across the mesh.
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

  # ── Why a mesh (light technical rationale) ────────────────────────────
  defp why_mesh(assigns) do
    ~H"""
    <section class="mx-auto max-w-3xl px-6 py-20 sm:py-24">
      <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">Why a mesh</p>
      <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight text-balance">
        The science and the substrate agree
      </h2>
      <p class="mt-6 text-base-content/70 leading-relaxed">
        Evolutionary methods evaluate many candidate solutions independently, generation
        after generation. There is no single enormous model to shard and no gradient to
        synchronise — just a population and its fitness. That work spreads naturally across
        many small, unreliable, geographically scattered machines: exactly what a federated
        mesh is good at, and exactly what a hyperscale cloud is not.
      </p>
    </section>
    """
  end

  # ── Take part ─────────────────────────────────────────────────────────
  defp take_part(assigns) do
    ~H"""
    <section id="take-part" class="border-t border-base-300/60 bg-base-200/40">
      <div class="mx-auto max-w-6xl px-6 py-20 sm:py-24">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">Get involved</p>
        <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight">
          Three ways to take part
        </h2>

        <div class="mt-10 grid gap-4 lg:grid-cols-3">
          <.way title="Run a node" cta="Get in touch" href="mailto:raf.lefever@erlef.org">
            Contribute compute to the mesh and help the federation grow. Every node that
            joins makes the network stronger and more resilient.
          </.way>
          <.way title="Build on it" cta="Browse the code" href="https://codeberg.org/beam-campus">
            The core libraries are open source and on hex.pm. Integrate Macula or ReckonDB in
            your own Erlang/Elixir project, or dig into how it works.
          </.way>
          <.way title="Collaborate" cta="Say hello" href="mailto:raf.lefever@erlef.org">
            Working on distributed or evolutionary AI, or curious where this is going? We'd
            like to hear from you.
          </.way>
        </div>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :cta, :string, required: true
  attr :href, :string, required: true
  slot :inner_block, required: true

  defp way(assigns) do
    ~H"""
    <article class="card bg-base-100 border border-base-300 h-full">
      <div class="card-body gap-3">
        <h3 class="text-xl font-semibold">{@title}</h3>
        <p class="text-sm text-base-content/70 leading-relaxed flex-1">{render_slot(@inner_block)}</p>
        <a href={@href} class="btn btn-outline btn-sm w-fit mt-2">{@cta}</a>
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
            Open source · European · built on the BEAM
          </p>
        </div>
        <div class="mt-8 flex flex-wrap gap-x-6 gap-y-2 font-mono text-xs text-base-content/50">
          <span class="text-secondary">MACULA</span>
          <span>RECKONDB</span>
          <span>HECATE</span>
          <span>FABER</span>
          <span class="grow"></span>
          <a href="https://codeberg.org/beam-campus" class="link link-hover">
            codeberg.org/beam-campus
          </a>
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
