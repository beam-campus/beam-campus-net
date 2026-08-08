defmodule BeamCampusWeb.DronexChrome do
  @moduledoc """
  The chrome every DroneX view wears: who an island is, what the track is doing,
  and how to get from one view to another.

  ## Why this exists and `dronex_utils` does not

  `BeamCampusWeb.DronexFight` states the house position and it is followed here:
  "A `utils` module holding four formatters would be the junk drawer the
  architecture rules name outright." So the small formatters are NOT here. `num`
  and `pct` are two lines each and are copied into whichever view needs them,
  because two consumers is a copy.

  What IS here is the three things that are genuinely one thing across four
  routes: an island's identity, the track's connection state, and the navigation
  between the views. A second copy of the nav would be a second answer to "what
  views are there", and that question must have one.

  ## ⚠ THE NAV IS THE PRICE OF THE SPLIT, AND IT IS PAID HERE ONCE

  `/dronex` used to be one page that loaded everything on every redraw, twice a
  second, whatever it was showing. Four routes each load what they draw. What a
  visitor loses is scrolling past everything by accident, so the nav has to make
  the other three views obvious rather than merely reachable.
  """
  use BeamCampusWeb, :html

  # ⚠ A VIEW APPEARS HERE WHEN ITS ROUTE EXISTS, AND NOT ONE COMMIT EARLIER. The
  # split lands one view at a time and every commit is deployed, so a nav listing
  # where it is GOING rather than where it IS would put dead links on the live
  # site for as long as the refactor takes.
  @views [
    {:archipelago, "Exams", "/research/workbench/dronex"},
    {:fights, "Fights", "/research/workbench/dronex/fights"},
    {:raids, "Raids", "/research/workbench/dronex/raids"},
    {:radio, "Radio", "/research/workbench/dronex/radio"}
  ]

  @doc """
  The four views, with the current one marked.

  ⚠ **PLAIN LINKS, NOT `patch`.** These are separate LiveViews, so each is a
  real mount that loads only its own data, and that is the entire point of the
  split. A `patch` would keep one process alive across all four and put back
  exactly the load-everything the routes exist to end.

  ⚠⚠ **AND THE SELECTION TRAVELS.** An island focus is a filter, not a page, so
  it rides as a query parameter across every view. Picking beam03 on the raids
  view and clicking Radio should still be about beam03.
  """
  attr :current, :atom, required: true
  attr :focus, :string, default: nil

  def nav(assigns) do
    assigns = assign(assigns, views: @views)

    ~H"""
    <nav aria-label="DroneX views" class="mt-6">
      <ul role="tablist" class="tabs tabs-bordered">
        <li :for={{id, label, path} <- @views} role="presentation">
          <.link
            role="tab"
            navigate={path_with_focus(path, @focus)}
            aria-selected={to_string(@current == id)}
            aria-current={@current == id && "page"}
            class={["tab", @current == id && "tab-active"]}
          >
            {label}
          </.link>
        </li>
      </ul>
    </nav>
    """
  end

  defp path_with_focus(path, nil), do: path
  defp path_with_focus(path, ""), do: path
  defp path_with_focus(path, island), do: path <> "?" <> URI.encode_query(island: island)

  # ── Who is who ──────────────────────────────────────────────────

  @doc """
  An island's name, and the four characters that say WHICH island.

  ⚠ **A NAME IS A STRING SOMEBODY TYPED ABOUT THEMSELVES.** Two islands may both
  call themselves `beam01`, and in an archipelago meant to admit strangers they
  eventually will. The board already keeps them apart, since every row is keyed
  on `island_id`; it was this page that merged them, by never showing an id at
  all. The reasoning, and what this does NOT fix, is in `Dronex.TellIslandsApart`.

  The mark is muted so it reads as a qualifier rather than as part of the name.

  ⚠ **AND IT IS NOT `aria-hidden`, WHICH THE FIRST VERSION HAD.** Hiding the mark
  from a screen reader hides the disambiguation from exactly the readers who
  cannot see the styling, so two islands called `beam01` would be told apart for
  sighted visitors and merged for everybody else. The separator is a real space
  INSIDE the span rather than an `ml-1`, because a CSS margin is not a space: the
  text read out was "beam01a6b1".
  """
  attr :row, :map, required: true
  attr :class, :string, default: "font-mono text-xs opacity-70"

  def island_name(assigns) do
    {name, mark} = Dronex.TellIslandsApart.named(assigns.row)
    assigns = assign(assigns, name: name, mark: mark)

    ~H"""
    <span class={@class}>
      {@name}<span :if={@mark} class="opacity-50">{" " <> @mark}</span>
    </span>
    """
  end

  @doc """
  What the track itself is doing, before any of its numbers are believed.

  ⚠ **PUBLIC HERE, PRIVATE BEFORE.** It was a `defp` when one LiveView was the
  only caller. Four views each need to say "this site is not configured" before
  they draw an empty chart, and a view that skipped it would look merely quiet
  when it is actually unwired.
  """
  attr :state, :atom, required: true
  attr :refused, :integer, required: true

  def dronex_state(assigns) do
    ~H"""
    <div
      :if={@state != :watching}
      class="mt-6 rounded-lg border border-base-content/10 bg-base-200 p-6 text-sm"
    >
      <p :if={@state == :unconfigured}>
        This site is not configured to read this track. It needs <code>BEAM_CAMPUS_DRONEX_SEEDS</code>, which has no default on purpose:
        naming a public realm costs nothing, dialling a production station from
        every clone does.
      </p>
      <p :if={@state == :dark}>Configured, and not connected to the mesh yet. Retrying.</p>
      <p :if={@state == :silent}>
        Connected, and no island has said anything yet. Either none is running, or
        they are publishing on a different realm or namespace.
      </p>
    </div>
    <p :if={@refused > 0} class="mt-4 text-sm text-warning">
      {@refused} island(s) refused because this page's cap was reached. The view
      below is incomplete.
    </p>
    """
  end
end
