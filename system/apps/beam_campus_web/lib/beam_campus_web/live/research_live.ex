defmodule BeamCampusWeb.ResearchLive do
  @moduledoc """
  The research hub: the commons runs more than one research line, and this page is
  the level above them.

  Each line has its own signed corpus, its own insight numbering (both start at 001)
  and its own method. They are deliberately not merged: Faber studies evolving
  networks, Spartan studies what an LLM-driven society of minds is a substrate for.
  Conflating them would make the provenance of any given finding unreadable.

  This page hosts nothing. It points at the lines, and the lines point at their
  corpora, so each corpus stays the single source of truth for its own findings.
  """
  use BeamCampusWeb, :live_view

  @lines [
    %{
      slug: :faber,
      kicker: "Neuroevolution",
      name: "Faber",
      question: "What makes a population of evolving networks get better at getting better?",
      shape: "Nine programmes: seven engine axes and two couplings.",
      corpus: "faber-ecosystem / insights",
      corpus_url: "https://github.com/rgfaber/faber-ecosystem/blob/master/insights/INDEX.md",
      accent: "primary"
    },
    %{
      slug: :spartan,
      kicker: "LLM cognition",
      name: "Spartan",
      question:
        "What is a society of LLM minds actually a substrate for, and which of its claims survive being made falsifiable?",
      shape: "A running research log: pre-register, run, sign the result whichever way it falls.",
      corpus: "hecate-spartan / insights",
      corpus_url:
        "https://github.com/hecate-services/hecate-spartan/blob/main/insights/README.md",
      accent: "secondary"
    },
    %{
      slug: :asociety,
      kicker: "Artificial cultures",
      name: "A Society",
      question:
        "When the group boundaries are real machines rather than a graph somebody drew, what does a culture do?",
      shape:
        "Islands of persons holding two kinds of belief: what they were told, and what they have seen.",
      corpus: "hecate-society / charter",
      corpus_url: "https://github.com/hecate-services/hecate-society/blob/main/CHARTER.md",
      accent: "accent"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Research", lines: @lines)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.intro />
      <.lines lines={@lines} />
      <.shared />
    </Layouts.app>
    """
  end

  # ── Intro ─────────────────────────────────────────────────────────────
  defp intro(assigns) do
    ~H"""
    <section class="border-b border-base-300/60">
      <div class="mx-auto max-w-5xl px-6 py-20 sm:py-28">
        <p class="font-mono text-xs uppercase tracking-[0.28em] text-primary">
          Research
        </p>
        <h1 class="mt-5 text-4xl sm:text-6xl font-semibold tracking-tight text-balance">
          Three research lines, one commons
        </h1>
        <p class="mt-6 max-w-2xl text-lg text-base-content/80 leading-relaxed">
          The commons runs three independent lines of research. They share a method and a
          substrate, and nothing else: each keeps its own signed corpus, its own numbering,
          and its own frontier. Findings are written down whichever way they fall, and a
          negative result is published with the same care as a positive one.
        </p>
      </div>
    </section>
    """
  end

  # ── The lines ─────────────────────────────────────────────────────────
  attr :lines, :list, required: true

  defp lines(assigns) do
    ~H"""
    <section class="mx-auto max-w-5xl px-6 py-16 sm:py-20">
      <div class="grid gap-6 sm:grid-cols-2">
        <.line_card :for={l <- @lines} l={l} />
      </div>
    </section>
    """
  end

  # Verified routes cannot live in a module attribute, so the line data carries a slug
  # and the path is resolved here. Adding a line means adding one clause.
  defp line_path(:faber), do: ~p"/research/faber"
  defp line_path(:spartan), do: ~p"/research/spartan"
  defp line_path(:asociety), do: ~p"/research/asociety"

  attr :l, :map, required: true

  defp line_card(assigns) do
    ~H"""
    <article class="card border border-base-300/60 bg-base-100">
      <div class="card-body">
        <span class={[
          "font-mono text-[11px] uppercase tracking-widest",
          @l.accent == "primary" && "text-primary",
          @l.accent == "secondary" && "text-secondary",
          @l.accent == "accent" && "text-accent"
        ]}>
          {@l.kicker}
        </span>
        <h2 class="mt-1 text-2xl font-semibold tracking-tight">{@l.name}</h2>
        <p class="mt-3 text-base-content/80 leading-relaxed">{@l.question}</p>
        <p class="mt-3 text-sm text-base-content/60">{@l.shape}</p>
        <div class="mt-6 flex flex-wrap items-center gap-4">
          <.link navigate={line_path(@l.slug)} class="btn btn-sm btn-primary">
            The programme <span aria-hidden="true">&rarr;</span>
          </.link>
          <a
            href={@l.corpus_url}
            class="link link-hover text-sm font-mono text-base-content/60"
            target="_blank"
            rel="noreferrer"
          >
            {@l.corpus}
          </a>
        </div>
      </div>
    </article>
    """
  end

  # ── Shared surfaces ───────────────────────────────────────────────────
  defp shared(assigns) do
    ~H"""
    <section class="border-t border-base-300/60">
      <div class="mx-auto max-w-5xl px-6 py-16">
        <p class="font-mono text-xs uppercase tracking-[0.2em] text-primary">Across both lines</p>
        <h2 class="mt-3 text-3xl font-semibold tracking-tight">Shared surfaces</h2>
        <p class="mt-4 max-w-2xl text-base-content/70 leading-relaxed">
          Two things cut across the lines. The notebook explains findings from either corpus in
          plain language, labelled with the line it came from. The workbench runs the mechanisms
          live in the browser, so a claim can be watched rather than taken on trust.
        </p>
        <div class="mt-8 flex flex-wrap gap-3">
          <.link navigate={~p"/research/notes"} class="btn btn-outline btn-sm">
            The notebook
          </.link>
          <.link navigate={~p"/research/workbench"} class="btn btn-outline btn-sm">
            ▶ The live workbench
          </.link>
        </div>
      </div>
    </section>
    """
  end
end
