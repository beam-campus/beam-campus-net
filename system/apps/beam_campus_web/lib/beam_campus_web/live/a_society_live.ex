defmodule BeamCampusWeb.ASocietyLive do
  @moduledoc """
  The artificial-cultures line: islands of persons who hold beliefs and teach them.

  ## Why this is not a map

  The obvious drawing is an archipelago with little figures moving between
  islands, and it is the wrong one twice over.

  There is **no space inside an island** in this design. An island is an
  undifferentiated population, so a hundred persons would be a hundred identical
  dots and position would be the one thing the model does not have.

  And the subjects here are **beliefs, not believers**. Cultural fitness in that
  design is the number of learners a variant reaches, so the thing being selected
  is the belief and the person is the substrate it lives in. Twenty bands of
  colour rising and falling say what a hundred dots cannot.

  ## Scaffold, and it says so

  `hecate-society` publishes nothing at this commit. Four islands are deployed
  and healthy and hold no people. This page therefore reports **which of five
  states it is in** rather than drawing an empty chart, because an empty chart
  and a broken feed look identical and send the reader to look in different
  places.

  The state today is `:no_contract`: connected, with no topic to subscribe to,
  because the island has not defined a fact yet. That is a statement about the
  island's build and not about the mesh.
  """
  use BeamCampusWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: ASociety.subscribe()

    {:ok,
     socket
     |> assign(page_title: "A Society")
     |> load()}
  end

  @impl true
  def handle_info({:asociety_changed, _kind}, socket), do: {:noreply, load(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load(socket) do
    assign(socket,
      state: ASociety.state(),
      islands: ASociety.islands(),
      refused: ASociety.refused()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.intro />
      <.feed state={@state} islands={@islands} refused={@refused} />
      <.what_it_will_draw />
      <.corpus />
    </Layouts.app>
    """
  end

  # ── Intro ─────────────────────────────────────────────────────────────
  defp intro(assigns) do
    ~H"""
    <section class="border-b border-base-300/60">
      <div class="mx-auto max-w-5xl px-6 py-20 sm:py-28">
        <.link
          navigate={~p"/research/workbench"}
          class="link link-hover font-mono text-xs text-base-content/50"
        >
          &larr; Workbench
        </.link>
        <p class="font-mono text-xs uppercase tracking-[0.28em] text-accent mt-4">
          Artificial cultures
        </p>
        <h1 class="mt-5 text-4xl sm:text-6xl font-semibold tracking-tight text-balance">
          A Society
        </h1>
        <p class="mt-6 max-w-2xl text-lg text-base-content/80 leading-relaxed">
          Every formal model of cultural evolution runs on a graph somebody drew.
          Here an island is a machine, the reach between islands is the mesh, and a
          partition is a barrier nobody chose. Each island decides for itself who
          may land.
        </p>
        <p class="mt-4 max-w-2xl text-base-content/70 leading-relaxed">
          A person holds two kinds of belief: a <em>model</em>, written only by what
          they have seen, and a <em>doctrine</em>, written only by what they were
          told. The gap between the two is the subject.
        </p>
      </div>
    </section>
    """
  end

  # ── The feed, and its five honest states ──────────────────────────────
  attr :state, :atom, required: true
  attr :islands, :list, required: true
  attr :refused, :integer, required: true

  defp feed(assigns) do
    ~H"""
    <section class="mx-auto max-w-5xl px-6 py-16 sm:py-20 border-b border-base-300/60">
      <div class="flex items-baseline justify-between gap-4 flex-wrap">
        <h2 class="text-2xl font-semibold tracking-tight">Live</h2>
        <.state_badge state={@state} />
      </div>

      <p class="mt-4 max-w-2xl text-base-content/70 leading-relaxed">
        {ASociety.explain(@state)}
      </p>

      <div :if={@islands != []} class="mt-8 grid gap-4 sm:grid-cols-2">
        <.island_card :for={i <- @islands} island={i} />
      </div>

      <p :if={@refused > 0} class="mt-6 text-sm text-warning font-mono">
        {@refused} island(s) refused: the board is full and this page is showing
        fewer than exist.
      </p>
    </section>
    """
  end

  attr :state, :atom, required: true

  defp state_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm font-mono", badge_class(@state)]}>
      {@state}
    </span>
    """
  end

  defp badge_class(:watching), do: "badge-success"
  defp badge_class(:silent), do: "badge-warning"
  defp badge_class(:dark), do: "badge-warning"
  defp badge_class(_unconfigured), do: "badge-ghost"

  attr :island, :map, required: true

  defp island_card(assigns) do
    assigns = assign(assigns, vitals: ASociety.vitals(assigns.island))

    ~H"""
    <article class="card border border-base-300/60 bg-base-100">
      <div class="card-body">
        <div class="flex items-baseline justify-between gap-3">
          <h3 class="text-lg font-semibold tracking-tight">{ASociety.label(@island)}</h3>
          <span :if={@vitals} class="font-mono text-xs text-base-content/50 tabular-nums">
            tick {@vitals["tick"]}
          </span>
        </div>
        <p class="font-mono text-[11px] text-base-content/40 break-all">{@island.id}</p>

        <.counts :if={@vitals} vitals={@vitals} />
        <.needs :if={@vitals} vitals={@vitals} />
        <.satisfiers :if={@vitals} vitals={@vitals} />

        <p :if={ASociety.quiet_for(@island)} class="mt-3 text-sm text-base-content/60">
          heard {ASociety.since(ASociety.quiet_for(@island))} ago
        </p>
      </div>
    </article>
    """
  end

  attr :vitals, :map, required: true

  defp counts(assigns) do
    ~H"""
    <div class="mt-3 flex flex-wrap gap-x-5 gap-y-1 font-mono text-xs text-base-content/60 tabular-nums">
      <span>{@vitals["persons"]} / {@vitals["capacity"]} persons</span>
      <span>{@vitals["births"]} born</span>
      <span>{@vitals["deaths"]} died</span>
    </div>
    """
  end

  # ── The nine, and why they are all one colour ─────────────────────────
  #
  # ⚠ ONE HUE FOR ALL NINE BARS, AND THAT IS NOT A SHORTCUT. Colouring each bar
  # differently would be a value ramp on nominal categories: it double-encodes
  # length as hue and burns the only free channel on information the bar already
  # shows. Worse here, it would encode a HIERARCHY. Max-Neef's central claim is
  # that the nine needs are simultaneous, with none foundational and none a
  # luxury, and a chart that painted subsistence a different colour from identity
  # would say the opposite of the model it is drawing.
  #
  # ⚠⚠ AND THERE IS NO TOTAL BAR. Charter rule 9: the axes are incommensurable, so
  # any single number would be a weighting, and a weighting is somebody's culture
  # rather than a measurement. This is the last place it could be smuggled in,
  # because a panel wants a headline and whoever writes one will be tempted.
  attr :vitals, :map, required: true

  defp needs(assigns) do
    assigns = assign(assigns, rows: ASociety.needs(assigns.vitals))

    ~H"""
    <div :if={@rows != []} class="mt-4">
      <p class="font-mono text-[11px] uppercase tracking-widest text-base-content/40">
        Needs met, per axis
      </p>
      <dl class="mt-2 space-y-[2px]">
        <.need_row :for={{axis, level} <- @rows} axis={axis} level={level} />
      </dl>
    </div>
    """
  end

  attr :axis, :string, required: true
  attr :level, :integer, required: true

  defp need_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <dt class="w-28 shrink-0 text-[11px] text-base-content/60 truncate">{@axis}</dt>
      <dd class="flex-1 flex items-center gap-2">
        <div class="h-1.5 flex-1 rounded-full bg-base-300/70 overflow-hidden">
          <div class="h-full rounded-full bg-primary" style={"width: #{percent(@level)}%"}></div>
        </div>
        <span class="w-9 shrink-0 text-right font-mono text-[11px] text-base-content/50 tabular-nums">
          {percent(@level)}
        </span>
      </dd>
    </div>
    """
  end

  # Clamped, because this is network input from a public realm and an island a
  # version ahead could send a level on a scale this reader does not know. A bar
  # 300% wide would break the card layout; a clamped one is merely wrong.
  defp percent(level) when is_integer(level) do
    level |> Kernel.*(100) |> div(ASociety.level_ceiling()) |> max(0) |> min(100)
  end

  defp percent(_other), do: 0

  # ── Whether the practices in use actually work ────────────────────────
  attr :vitals, :map, required: true

  defp satisfiers(assigns) do
    assigns = assign(assigns, classes: ASociety.satisfier_classes(assigns.vitals))

    ~H"""
    <div :if={@classes != []} class="mt-4">
      <p class="font-mono text-[11px] uppercase tracking-widest text-base-content/40">
        Practices in use
      </p>
      <div class="mt-2 flex flex-wrap gap-x-4 gap-y-1 font-mono text-[11px] tabular-nums">
        <span :for={{class, n} <- @classes} class={class_ink(class, n)} title={class_meaning(class)}>
          {n} {class}
        </span>
      </div>
    </div>
    """
  end

  # ⚠ STATUS INK ONLY WHERE THE COLOUR MEANS SOMETHING, and only when the count is
  # non-zero. A violator claims to meet a need while making it harder to meet, so
  # its presence IS a status. Zero of them is not good news worth colouring, it is
  # simply the ordinary case.
  defp class_ink("violator", n) when n > 0, do: "text-error"
  defp class_ink("pseudo", n) when n > 0, do: "text-warning"
  defp class_ink(_class, _n), do: "text-base-content/50"

  defp class_meaning("synergic"), do: "meets its own need and others with it"
  defp class_meaning("singular"), do: "meets its own need, exactly"
  defp class_meaning("inhibiting"), do: "works, at a price paid on another need"
  defp class_meaning("pseudo"), do: "claims a need it does not meet, and harms nothing"

  defp class_meaning("violator"),
    do: "claims a need it does not meet, and damages another"

  defp class_meaning(_other), do: nil

  # ── What this page will draw, once there is anything to draw ──────────
  defp what_it_will_draw(assigns) do
    ~H"""
    <section class="mx-auto max-w-5xl px-6 py-16 sm:py-20 border-b border-base-300/60">
      <h2 class="text-2xl font-semibold tracking-tight">What this will show</h2>
      <p class="mt-4 max-w-2xl text-base-content/70 leading-relaxed">
        Not a map. There is no space inside an island, so a hundred persons would be
        a hundred identical dots. The subjects are beliefs, not believers.
      </p>

      <div class="mt-8 grid gap-6 sm:grid-cols-3">
        <.planned
          title="Belief composition"
          body="One column per island, colour per proposition, stacked over time. Divergence or convergence between islands, visible directly."
        />
        <.planned
          title="The dissonance scatter"
          body="One point per person: what they were told against what they have seen. The diagonal is coherence and everything off it is the subject."
        />
        <.planned
          title="The instruments"
          body="Effective population and the drift floor, things said per window, between-group variation against what drift alone predicts."
        />
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :body, :string, required: true

  defp planned(assigns) do
    ~H"""
    <div class="border-l-2 border-base-300 pl-4">
      <h3 class="font-semibold tracking-tight">{@title}</h3>
      <p class="mt-2 text-sm text-base-content/70 leading-relaxed">{@body}</p>
    </div>
    """
  end

  # ── Where the real record lives ───────────────────────────────────────
  defp corpus(assigns) do
    ~H"""
    <section class="mx-auto max-w-5xl px-6 py-16 sm:py-20">
      <h2 class="text-2xl font-semibold tracking-tight">The record</h2>
      <p class="mt-4 max-w-2xl text-base-content/70 leading-relaxed">
        This page is a reader. It takes no dependency on the island's code and
        computes nothing: the contract between them is the published fact and its
        version. The charter, the design documents and the register are the source
        of truth, and findings are written down whichever way they fall.
      </p>
      <div class="mt-6 flex flex-wrap gap-4">
        <a
          href="https://github.com/hecate-services/hecate-society/blob/main/CHARTER.md"
          class="btn btn-sm btn-primary"
          target="_blank"
          rel="noreferrer"
        >
          The charter <span aria-hidden="true">&rarr;</span>
        </a>
        <a
          href="https://github.com/hecate-services/hecate-society/blob/main/REGISTER.md"
          class="link link-hover text-sm font-mono text-base-content/60"
          target="_blank"
          rel="noreferrer"
        >
          hecate-society / register
        </a>
      </div>
    </section>
    """
  end
end
