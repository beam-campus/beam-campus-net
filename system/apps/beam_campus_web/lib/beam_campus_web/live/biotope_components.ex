defmodule BeamCampusWeb.BiotopeComponents do
  @moduledoc """
  Shared chrome and shared drawing for the biotope pages.

  Three pages now, one feature: the islands as a set, one island in detail, and
  where they have all been. The switch below is what keeps them findable from
  each other; before it existed the history linked back and nothing linked
  forward, so a page was reachable only by someone who already knew the URL.

  Lives here rather than in a generic components module because it belongs to
  this feature and nothing else uses it.
  """
  use Phoenix.Component
  use Phoenix.VerifiedRoutes, endpoint: BeamCampusWeb.Endpoint, router: BeamCampusWeb.Router

  @doc """
  The faces of this feature, and the way back up.

  `current` is `:now` or `:history`. The active tab is still a link rather than
  a dead span, so the page can be re-entered to force a refresh, and it carries
  `aria-current` so a screen reader is told which one it is on rather than
  having to infer it from styling.
  """
  attr :current, :atom, required: true

  def switch(assigns) do
    ~H"""
    <nav class="mt-6 flex flex-wrap items-center justify-between gap-3" aria-label="Biotope views">
      <div class="join">
        <.link
          navigate={~p"/research/workbench/biotope"}
          class={["btn btn-sm join-item", @current == :now && "btn-active"]}
          aria-current={@current == :now && "page"}
        >
          Now
        </.link>
        <.link
          navigate={~p"/research/workbench/biotope/history"}
          class={["btn btn-sm join-item", @current == :history && "btn-active"]}
          aria-current={@current == :history && "page"}
        >
          History
        </.link>
      </div>

      <.link navigate={~p"/research/workbench"} class="link link-hover text-sm opacity-60">
        ← All experiments
      </.link>
    </nav>
    """
  end

  @doc """
  Whether an island is still talking.

  THREE STATES, NOT TWO. "Stopped" and "never heard from" want different
  responses from whoever is reading. And the elapsed time is always shown next
  to the verdict, so the threshold this makes a judgement against is visible
  rather than buried in a constant.
  """
  attr :liveness, :any, required: true

  def liveness(%{liveness: :live} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 text-xs">
      <span class="inline-block h-1.5 w-1.5 rounded-full bg-success"></span>
      <span class="opacity-60">live</span>
    </span>
    """
  end

  def liveness(%{liveness: {:quiet, ms}} = assigns) do
    assigns = assign(assigns, since: Biotope.since(ms))

    ~H"""
    <span class="inline-flex items-center gap-1.5 text-xs" title="No fact has arrived for this long">
      <span class="inline-block h-1.5 w-1.5 rounded-full bg-warning"></span>
      <span class="text-warning">quiet {@since}</span>
    </span>
    """
  end

  def liveness(assigns) do
    ~H"""
    <span class="text-xs opacity-40">never heard from</span>
    """
  end

  @doc """
  The board is capped, and a page that has silently stopped admitting islands
  looks exactly like a fleet that has stopped growing.
  """
  attr :refused, :integer, required: true

  def refused_notice(%{refused: n} = assigns) when n > 0 do
    ~H"""
    <p class="mt-4 rounded border border-warning/40 bg-warning/10 p-3 text-sm text-warning">
      {@refused} islands were refused because this node's board is full. What you
      are looking at is a subset, not the fleet.
    </p>
    """
  end

  def refused_notice(assigns), do: ~H""

  @doc """
  A hex disc: plants, creatures, and the rim.

  Sized from the chart's own radius, so a viewer never has to be configured to
  agree with a world it cannot see.
  """
  attr :chart, :map, required: true
  attr :size, :integer, default: 320

  def disc(assigns) do
    box = %{radius: assigns.chart["radius"] || 20, size: assigns.size}

    assigns =
      assign(assigns,
        cell: Biotope.cell_radius(box),
        plants: place(assigns.chart["plants"], box),
        creatures: place(assigns.chart["creatures"], box)
      )

    ~H"""
    <svg
      viewBox={"0 0 #{@size} #{@size}"}
      class="w-full h-auto rounded bg-black/40"
      role="img"
      aria-label={"#{length(@creatures)} creatures and #{length(@plants)} plants"}
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

  @doc """
  Population and standing crop over time.

  Each series is scaled to its OWN maximum, because they are different
  quantities in different units and one axis would say something false about
  their relative size. What the pair is for is the shape: grazing pressure
  against regrowth.
  """
  attr :samples, :list, required: true
  attr :w, :integer, default: 640
  attr :h, :integer, default: 120
  attr :class, :string, default: ""

  def sparkline(%{samples: []} = assigns) do
    ~H"""
    <p class={["text-xs opacity-40", @class]}>no history yet</p>
    """
  end

  def sparkline(assigns) do
    assigns =
      assign(assigns,
        population: polyline(assigns.samples, & &1.population, assigns.w, assigns.h),
        plants: polyline(assigns.samples, & &1.plants, assigns.w, assigns.h)
      )

    ~H"""
    <svg
      viewBox={"0 0 #{@w} #{@h}"}
      class={["w-full h-auto rounded bg-black/40", @class]}
      role="img"
      aria-label={"Population and plants over #{length(@samples)} samples"}
    >
      <polyline points={@plants} fill="none" stroke="#3FBF7F" stroke-width="1.5" opacity="0.8" />
      <polyline points={@population} fill="none" stroke="#F2B142" stroke-width="1.5" />
    </svg>
    """
  end

  @doc "One number with its label."
  attr :label, :string, required: true
  attr :value, :any, required: true

  def stat(assigns) do
    ~H"""
    <div>
      <dt class="text-xs uppercase tracking-wide opacity-50">{@label}</dt>
      <dd class="font-mono">{number(@value)}</dd>
    </div>
    """
  end

  @doc """
  Which rules an island runs.

  Two islands sharing a fingerprint are comparable; two that do not are
  different games, and their populations must not be read against each other.
  Shown on every island for that reason, not as decoration.
  """
  attr :stats, :map, required: true

  def econ(%{stats: nil} = assigns), do: ~H""

  def econ(assigns) do
    assigns = assign(assigns, id: assigns.stats["econ_id"], econ: assigns.stats["econ"] || %{})

    ~H"""
    <details class="mt-3 text-xs">
      <summary class="cursor-pointer opacity-60">
        rules <code class="font-mono">{@id}</code>
      </summary>
      <dl class="mt-2 grid grid-cols-2 gap-x-4 gap-y-1 sm:grid-cols-3">
        <div :for={{k, v} <- Enum.sort(@econ)} class="flex justify-between gap-2">
          <dt class="opacity-50">{k}</dt>
          <dd class="font-mono">{v}</dd>
        </div>
      </dl>
    </details>
    """
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp place(flat, box) do
    flat
    |> Biotope.points()
    |> Enum.map(&Biotope.to_pixel(&1, box))
  end

  # NOT called `path`: Phoenix.VerifiedRoutes imports path/2, and shadowing it
  # fails at compile time inside ~p with a message about a path string that
  # names neither this function nor the collision.
  defp polyline([], _get, _w, _h), do: ""

  defp polyline(samples, get, w, h) do
    values = Enum.map(samples, get)
    top = max(Enum.max(values), 1)
    span = max(length(values) - 1, 1)

    values
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {v, i} ->
      x = i / span * w
      y = h - v / top * (h - 4) - 2
      "#{Float.round(x, 1)},#{Float.round(y, 1)}"
    end)
  end

  defp number(nil), do: "–"
  defp number(n) when is_integer(n), do: Integer.to_string(n)
  defp number(other), do: to_string(other)
end
