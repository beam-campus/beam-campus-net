defmodule BeamCampusWeb.BiotopeLive do
  @moduledoc """
  Islands, drawn from what they say about themselves.

  Every island the node has heard from gets a panel: a hex disc with its plants
  and creatures, and the counts underneath.

  ## Nothing here computes a world

  The page draws the last frame that arrived and no more. It does not simulate,
  interpolate between frames, or fill a gap with a guess. A frozen island shows
  a frozen picture with a tick that stops advancing, which is the truth and is
  also the fastest way to notice.

  ## Server-rendered SVG, no JavaScript

  About a hundred and eighty circles per island per frame, at whatever rate the
  island publishes, as LiveView diffs. That is comfortable at one or two frames a
  second and would not be at twenty across many viewers. The fact carries
  `ticks_per_second`, so if this ever needs a canvas hook the page can say why
  rather than guess.
  """

  use BeamCampusWeb, :live_view

  @size 320

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Biotope.subscribe()
    {:ok, load(socket)}
  end

  @impl true
  def handle_info({:biotope, :changed}, socket), do: {:noreply, load(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load(socket) do
    islands = Enum.map(Biotope.islands(), &{&1, Biotope.island(&1)})

    assign(socket,
      islands: islands,
      watching?: Biotope.watching?(),
      configured?: Biotope.configured?()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl px-4 py-10">
      <.header>
        Biotopes
        <:subtitle>
          Open populations on the mesh. Plants grow, creatures forage, breed and
          starve. Nothing here has a brain yet.
        </:subtitle>
      </.header>

      <div :if={@islands == []} class="mt-8">
        <.dark configured?={@configured?} watching?={@watching?} />
      </div>

      <div class="mt-8 grid gap-8 md:grid-cols-2">
        <.island :for={{name, row} <- @islands} name={name} row={row} />
      </div>

      <p class="mt-10 text-sm opacity-60">
        Each island publishes counts once a second and a picture more often. The
        site subscribes and draws; it holds no world of its own and shares no code
        with the islands. What you see is the last frame that arrived.
      </p>
    </div>
    """
  end

  # ── One island ──────────────────────────────────────────────────

  attr :name, :string, required: true
  attr :row, :map, required: true

  defp island(assigns) do
    chart = assigns.row[:chart]
    stats = assigns.row[:stats]

    assigns =
      assign(assigns,
        chart: chart,
        stats: stats,
        box: box(chart)
      )

    ~H"""
    <section class="rounded-lg border border-base-content/10 bg-base-200 p-4">
      <div class="flex items-baseline justify-between">
        <h2 class="font-semibold">{@name}</h2>
        <span class="text-xs opacity-60">
          tick {number(@stats["tick"] || @chart["tick"])}
        </span>
      </div>

      <.disc :if={@chart} chart={@chart} box={@box} />
      <p :if={is_nil(@chart)} class="mt-3 text-sm opacity-60">
        Counts have arrived but no picture yet. This island may have its chart
        turned off, which is what a headless run does.
      </p>

      <.counts :if={@stats} stats={@stats} />
    </section>
    """
  end

  attr :chart, :map, required: true
  attr :box, :map, required: true

  defp disc(assigns) do
    assigns =
      assign(assigns,
        size: @size,
        cell: Biotope.cell_radius(assigns.box),
        plants: place(assigns.chart["plants"], assigns.box),
        creatures: place(assigns.chart["creatures"], assigns.box)
      )

    ~H"""
    <svg
      viewBox={"0 0 #{@size} #{@size}"}
      class="mt-3 w-full h-auto rounded bg-black/40"
      role="img"
      aria-label={"Island with #{length(@creatures)} creatures and #{length(@plants)} plants"}
    >
      <circle
        cx={@size / 2}
        cy={@size / 2}
        r={@size / 2 - @cell}
        fill="none"
        stroke="currentColor"
        stroke-width="1"
        opacity="0.12"
      />
      <circle :for={{x, y} <- @plants} cx={x} cy={y} r={@cell * 0.55} fill="#3FBF7F" opacity="0.85" />
      <circle :for={{x, y} <- @creatures} cx={x} cy={y} r={@cell * 0.8} fill="#F2B142" />
    </svg>
    """
  end

  attr :stats, :map, required: true

  defp counts(assigns) do
    ~H"""
    <dl class="mt-3 grid grid-cols-3 gap-2 text-sm">
      <.stat label="creatures" value={@stats["population"]} />
      <.stat label="plants" value={@stats["plants"]} />
      <.stat label="energy" value={@stats["energy_total"]} />
      <.stat label="born" value={@stats["born"]} />
      <.stat label="starved" value={@stats["starved"]} />
      <.stat label="of old age" value={@stats["aged_out"]} />
    </dl>
    <p :if={(@stats["births_refused"] || 0) > 0} class="mt-2 text-xs text-warning">
      {number(@stats["births_refused"])} births refused: this island is at its
      safety cap, so the population is not at a natural ceiling.
    </p>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp stat(assigns) do
    ~H"""
    <div>
      <dt class="text-xs uppercase tracking-wide opacity-50">{@label}</dt>
      <dd class="font-mono">{number(@value)}</dd>
    </div>
    """
  end

  # Configured-and-dark and never-configured need different responses from
  # whoever is reading, so the page says which it is rather than showing one
  # apologetic sentence for both.
  attr :configured?, :boolean, required: true
  attr :watching?, :boolean, required: true

  defp dark(assigns) do
    ~H"""
    <div class="rounded-lg border border-base-content/10 bg-base-200 p-6 text-sm">
      <p :if={not @configured?}>
        This site is not configured to read islands. It needs <code>BEAM_CAMPUS_BIOTOPE_SEEDS</code>, which has no default on purpose:
        naming a public realm costs nothing, dialling a production station from
        every clone does.
      </p>
      <p :if={@configured? and not @watching?}>
        Configured, but not connected to the mesh yet. Retrying.
      </p>
      <p :if={@configured? and @watching?}>
        Connected, and no island has said anything yet. Either none is running,
        or they are publishing on a different realm or namespace.
      </p>
    </div>
    """
  end

  # ── Helpers ─────────────────────────────────────────────────────

  # The board is sized from the fact's own radius, so a viewer never has to be
  # configured to agree with a world it cannot see. A chart that somehow arrives
  # without one gets a harmless default rather than a crashed page.
  defp box(nil), do: %{radius: 1, size: @size}
  defp box(chart), do: %{radius: chart["radius"] || 20, size: @size}

  defp place(flat, box) do
    flat
    |> Biotope.points()
    |> Enum.map(&Biotope.to_pixel(&1, box))
  end

  defp number(nil), do: "–"
  defp number(n) when is_integer(n), do: Integer.to_string(n)
  defp number(other), do: to_string(other)
end
