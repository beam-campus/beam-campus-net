defmodule BeamCampusWeb.SpartanLive do
  @moduledoc """
  The Spartan research line: LLM cognition, outward-facing.

  Every claim on this page is traceable to a numbered note in the hecate-spartan
  insights corpus, which is the single source of truth. This page points at it and
  hosts nothing. Note numbers are Spartan's own and are unrelated to Faber's, which
  is why the corpus is always named alongside a number.

  The credit line is not decoration. Spartan is Dr. Gene Sher's work and the corpus
  says so on its front page; any public surface derived from it carries the same.
  """
  use BeamCampusWeb, :live_view

  @repo "https://github.com/hecate-services/hecate-spartan"
  @corpus "#{@repo}/blob/main/insights"
  @upstream "https://github.com/CorticalComputer/Spartan"

  # Notes that carry the line's current shape. Numbers are Spartan corpus numbers.
  @notes [
    %{
      n: "011",
      file: "011_the_signed_negative_memory_is_falsified.md",
      title: "The signed negative: memory is falsified",
      state: "Signed",
      blurb:
        "Inject fired 507 times and added nothing. A 100% precision oracle is reliably worse than engine-plus-reset, and restoration loses to restart under recurrence jitter."
    },
    %{
      n: "012",
      file: "012_what_survives_the_substrate_after_the_kernel_dies.md",
      title: "What survives after the kernel dies",
      state: "Signed",
      blurb:
        "Inject died, but retrieval queried from outside was the winner all along, and that is a public commons rather than an improving private kernel."
    },
    %{
      n: "013",
      file: "013_the_scope_of_the_negative_and_the_frontier.md",
      title: "The scope of the negative, and the frontier",
      state: "Retraction",
      blurb:
        "Saying the programme was over turned out to be a mood rather than a measurement, and is retracted. The kill is narrow: it binds verbatim recall under drift and nothing wider."
    },
    %{
      n: "014",
      file: "014_experiment_m1_self_audit_economics_pre_registration.md",
      title: "M1: self-audit economics",
      state: "Pre-registered",
      blurb:
        "Does draft-then-verify cut hallucination enough to justify twice the compute? Mechanical checker, constant-free kill rule, and the programme's first cost ledger. Cleared, build-ready."
    },
    %{
      n: "015",
      file: "015_experiment_m2_peer_review_economics_pre_registration.md",
      title: "M2: peer-review economics",
      state: "Draft",
      blurb:
        "Does a second independent model's review earn its compute beyond self-audit, by removing decorrelated blind spots rather than by context poverty? Pending adversarial clearance."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Research — Spartan",
       notes: @notes,
       corpus: @corpus,
       corpus_url: "#{@corpus}/README.md",
       repo: @repo,
       upstream: @upstream
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.intro corpus_url={@corpus_url} />
      <.negative />
      <.notes notes={@notes} corpus={@corpus} />
      <.method />
      <.credit upstream={@upstream} repo={@repo} />
    </Layouts.app>
    """
  end

  # ── Intro ─────────────────────────────────────────────────────────────
  attr :corpus_url, :string, required: true

  defp intro(assigns) do
    ~H"""
    <section class="border-b border-base-300/60">
      <div class="mx-auto max-w-5xl px-6 py-20 sm:py-28">
        <p class="font-mono text-xs uppercase tracking-[0.28em] text-secondary">
          Research · Spartan
        </p>
        <h1 class="mt-5 text-4xl sm:text-6xl font-semibold tracking-tight text-balance">
          What is a society of minds a substrate for?
        </h1>
        <p class="mt-6 max-w-2xl text-lg text-base-content/80 leading-relaxed">
          Spartan is the other research line: not evolving networks, but a federation of
          persistent LLM-driven minds. The question the corpus sits on is whether its central
          claims can be made falsifiable at all, and then whether they survive the test. The
          method is to interrogate the architecture, find where it cannot be disproven, and
          redesign toward falsifiability.
        </p>
        <div class="mt-9 flex flex-wrap gap-3">
          <a href={@corpus_url} class="btn btn-primary" target="_blank" rel="noreferrer">
            The research log <span aria-hidden="true">&rarr;</span>
          </a>
          <.link navigate={~p"/research"} class="btn btn-outline">
            Both research lines
          </.link>
        </div>
      </div>
    </section>
    """
  end

  # ── The headline result ───────────────────────────────────────────────
  defp negative(assigns) do
    ~H"""
    <section class="border-b border-base-300/60 bg-base-200/40">
      <div class="mx-auto max-w-5xl px-6 py-16">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-secondary">
          The result so far
        </p>
        <h2 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight text-balance">
          One mechanism is signed dead
        </h2>
        <p class="mt-5 max-w-2xl text-base-content/80 leading-relaxed">
          Verbatim memory recall, replaying stored past under drift, loses to forgetting and
          relearning. It loses even with a perfect recognizer, because the past returns changed.
          That was the programme's central claim, it was pre-registered, and it failed.
        </p>
        <p class="mt-4 max-w-2xl text-base-content/70 leading-relaxed">
          The kill is deliberately narrow. It is licensed to generalise along its own mechanism
          and no further, and an earlier claim that the whole programme was finished has been
          retracted as an over-reach. Recalling the shape rather than the numbers, memory as
          learned dynamics, and every faculty that reads the present rather than the past all
          remain open and untested.
        </p>
      </div>
    </section>
    """
  end

  # ── Notes ─────────────────────────────────────────────────────────────
  attr :notes, :list, required: true
  attr :corpus, :string, required: true

  defp notes(assigns) do
    ~H"""
    <section class="mx-auto max-w-5xl px-6 py-16">
      <p class="font-mono text-xs uppercase tracking-[0.2em] text-secondary">The log</p>
      <h2 class="mt-3 text-3xl font-semibold tracking-tight">Where the line stands</h2>
      <p class="mt-4 max-w-2xl text-base-content/70 leading-relaxed">
        These are Spartan corpus numbers. Faber numbers its own findings separately and the two
        sequences are unrelated, so a number is only meaningful with its corpus named.
      </p>
      <div class="mt-8 grid gap-4">
        <.note_card :for={note <- @notes} note={note} corpus={@corpus} />
      </div>
    </section>
    """
  end

  attr :note, :map, required: true
  attr :corpus, :string, required: true

  defp note_card(assigns) do
    ~H"""
    <a
      href={"#{@corpus}/#{@note.file}"}
      class="card border border-base-300/60 bg-base-100 transition hover:border-secondary/60"
      target="_blank"
      rel="noreferrer"
    >
      <div class="card-body py-5">
        <div class="flex flex-wrap items-center gap-3">
          <span class="font-mono text-[11px] uppercase tracking-widest text-base-content/50">
            Note {@note.n}
          </span>
          <span class="badge badge-sm badge-outline">{@note.state}</span>
        </div>
        <h3 class="mt-1 text-lg font-semibold tracking-tight">{@note.title}</h3>
        <p class="text-sm text-base-content/70 leading-relaxed">{@note.blurb}</p>
      </div>
    </a>
    """
  end

  # ── Method ────────────────────────────────────────────────────────────
  defp method(assigns) do
    ~H"""
    <section class="border-t border-base-300/60">
      <div class="mx-auto max-w-5xl px-6 py-16">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-secondary">How it runs</p>
        <h2 class="mt-3 text-3xl font-semibold tracking-tight">The method</h2>
        <div class="mt-8 grid gap-6 sm:grid-cols-3">
          <div>
            <h3 class="font-semibold">Pre-register first</h3>
            <p class="mt-2 text-sm text-base-content/70 leading-relaxed">
              The metric and the kill threshold are written down before anything is built, so a
              disappointing result cannot quietly become a reframed one.
            </p>
          </div>
          <div>
            <h3 class="font-semibold">Adversarial clearance</h3>
            <p class="mt-2 text-sm text-base-content/70 leading-relaxed">
              An independent model reviews each design and each claim, with the job of attacking
              it rather than helping. Experiments wait for clearance before they run.
            </p>
          </div>
          <div>
            <h3 class="font-semibold">Plain language, always</h3>
            <p class="mt-2 text-sm text-base-content/70 leading-relaxed">
              Every note carries a plain-language section. If a finding cannot be explained
              simply, the corpus treats that as evidence it is not yet understood.
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ── Credit ────────────────────────────────────────────────────────────
  attr :upstream, :string, required: true
  attr :repo, :string, required: true

  defp credit(assigns) do
    ~H"""
    <section class="border-t border-base-300/60 bg-base-200/40">
      <div class="mx-auto max-w-5xl px-6 py-12">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-secondary">Credit</p>
        <p class="mt-4 max-w-2xl text-base-content/80 leading-relaxed">
          Spartan is Dr. Gene Sher's. Its mind, its mechanisms and its philosophy are his, and
          this research stands entirely on that work. What the commons contributes is a BEAM
          port, a federated mesh substrate, and the falsification work recorded above.
        </p>
        <div class="mt-6 flex flex-wrap gap-4">
          <a href={@upstream} class="link link-hover text-sm" target="_blank" rel="noreferrer">
            Spartan, upstream
          </a>
          <a href={@repo} class="link link-hover text-sm font-mono" target="_blank" rel="noreferrer">
            hecate-spartan
          </a>
        </div>
      </div>
    </section>
    """
  end
end
