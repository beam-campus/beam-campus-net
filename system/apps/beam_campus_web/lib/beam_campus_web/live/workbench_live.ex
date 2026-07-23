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
      id: "deception-maze",
      title: "Abandoning the objective",
      tag: "Deceptive maze",
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
          <.link navigate={~p"/research"} class="link link-hover font-mono text-xs text-base-content/50">
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
          <span class="font-mono text-[11px] uppercase tracking-widest text-base-content/50">{@x.tag}</span>
          <span class={["badge badge-sm", status_class(@x.status)]}>{status_label(@x.status)}</span>
        </div>
        <h2 class="text-xl font-semibold">{@x.title}</h2>
        <p class="text-sm text-base-content/70 leading-relaxed flex-1">{@x.blurb}</p>

        <div class="flex flex-wrap gap-x-4 gap-y-1 font-mono text-[11px] text-base-content/50">
          <span>{@x.programme}</span>
          <a href="https://codeberg.org/rgfaber/faber-ecosystem/src/branch/master/insights/INDEX.md" class="link link-hover" target="_blank" rel="noreferrer">insight {@x.insight}</a>
          <.link navigate={@x.note} class="link link-hover">the note</.link>
        </div>

        <.open_link x={@x} />
      </div>
    </article>
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

  defp open_link(assigns) do
    ~H"""
    <.link navigate={@x.note} class="btn btn-outline btn-sm w-fit mt-1">
      Read the note (demo coming) <span aria-hidden="true">&rarr;</span>
    </.link>
    """
  end

  defp status_class(:interactive), do: "badge-primary"
  defp status_class(:planned), do: "badge-ghost"

  defp status_label(:interactive), do: "live"
  defp status_label(:planned), do: "planned"
end
