defmodule BeamCampusWeb.BiotopeHistoryLive do
  @moduledoc """
  Where the islands have been, rather than where they are.

  The live page draws the last frame that arrived and is wiped by every deploy.
  This one reads the sampled history out of SQLite, so it can answer the question
  an ETS board is structurally unable to answer: what happened overnight.

  ## Drawn against the world's clock, not this node's

  Every series is plotted against `tick`. Publishing runs on wall clock and an
  island runs at whatever pace it was configured for, so the two drift, and a
  chart against wall clock would compress or stretch depending on how fast the
  world happened to be running. The tick is the world's own time.

  ## A gap in the line is a real thing and is left visible

  A row is written only when an island's tick advances, so a frozen island stops
  producing samples. That shows as a line that stops, which is the truth. Nothing
  here interpolates across it.
  """

  use BeamCampusWeb, :live_view

  import BeamCampusWeb.BiotopeComponents

  alias Biotope.RecordHistory

  @w 640
  @h 120
  # Refreshed on a timer rather than on a fact, because the writer samples on a
  # slow clock of its own. Redrawing on every arriving fact would repaint a chart
  # that had not changed.
  @refresh_ms 30_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_ms, :refresh)
    {:ok, load(socket)}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, load(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load(socket) do
    islands =
      for name <- RecordHistory.recorded_islands() do
        {name, RecordHistory.history(name)}
      end

    assign(socket, islands: islands, rows: RecordHistory.count())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-4 py-10">
        <.header>
          Biotope history
          <:subtitle>
            Population and standing crop over time, sampled from what the islands
            published. Drawn against the world's own tick.
          </:subtitle>
        </.header>

        <.switch current={:history} />

        <p
          :if={@islands == []}
          class="mt-8 rounded-lg border border-base-content/10 bg-base-200 p-6 text-sm"
        >
          No history recorded yet. Samples are written every thirty seconds once an
          island is heard from, and only when its tick has advanced, so a page this
          empty means nothing is being received rather than that nothing is
          happening.
        </p>

        <div class="mt-8 space-y-10">
          <.series :for={{name, samples} <- @islands} name={name} samples={samples} />
        </div>

        <p :if={@islands != []} class="mt-10 text-sm opacity-60">
          {@rows} samples held. This is a read model: it is rebuilt from the facts
          that arrive and can be deleted without losing anything, because the
          islands are the things that are actually alive. Rows older than thirty
          days are pruned.
        </p>
      </div>
    </Layouts.app>
    """
  end

  attr :name, :string, required: true
  attr :samples, :list, required: true

  defp series(assigns) do
    samples = assigns.samples

    assigns =
      assign(assigns,
        w: @w,
        h: @h,
        population: polyline(samples, & &1.population),
        plants: polyline(samples, & &1.plants),
        first: List.first(samples),
        last: List.last(samples)
      )

    ~H"""
    <section>
      <div class="flex items-baseline justify-between">
        <h2 class="font-semibold">{@name}</h2>
        <span class="text-xs opacity-60">
          {length(@samples)} samples · ticks {@first.tick} to {@last.tick}
        </span>
      </div>

      <svg
        viewBox={"0 0 #{@w} #{@h}"}
        class="mt-2 w-full h-auto rounded bg-black/40"
        role="img"
        aria-label={"Population and plants on #{@name} over #{length(@samples)} samples"}
      >
        <polyline points={@plants} fill="none" stroke="#3FBF7F" stroke-width="1.5" opacity="0.8" />
        <polyline points={@population} fill="none" stroke="#F2B142" stroke-width="1.5" />
      </svg>

      <dl class="mt-2 flex gap-6 text-sm">
        <.legend colour="#F2B142" label="creatures" value={@last.population} />
        <.legend colour="#3FBF7F" label="plants" value={@last.plants} />
        <.legend colour="transparent" label="starved" value={@last.starved} />
        <.legend colour="transparent" label="of old age" value={@last.aged_out} />
      </dl>
    </section>
    """
  end

  attr :colour, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp legend(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <span class="inline-block h-2 w-2 rounded-full" style={"background: #{@colour}"}></span>
      <dt class="opacity-60">{@label}</dt>
      <dd class="font-mono">{@value}</dd>
    </div>
    """
  end

  # ── Plotting ────────────────────────────────────────────────────

  # Each series is scaled to its own maximum, because population and standing
  # crop are different quantities in different units and forcing them onto one
  # axis would say something false about their relative size. What the pair is
  # for is the SHAPE: grazing pressure against regrowth.
  # NOT called `path`: Phoenix.VerifiedRoutes imports path/2, and shadowing it
  # fails at compile time inside ~p with a message about a path string that names
  # neither this function nor the collision.
  defp polyline([], _get), do: ""

  defp polyline(samples, get) do
    values = Enum.map(samples, get)
    top = max(Enum.max(values), 1)
    span = max(length(values) - 1, 1)

    values
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {v, i} ->
      x = i / span * @w
      y = @h - v / top * (@h - 4) - 2
      "#{Float.round(x, 1)},#{Float.round(y, 1)}"
    end)
  end
end
