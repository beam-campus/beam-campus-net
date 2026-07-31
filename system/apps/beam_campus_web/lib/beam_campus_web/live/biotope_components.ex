defmodule BeamCampusWeb.BiotopeComponents do
  @moduledoc """
  Shared chrome for the two biotope pages.

  They are one feature with two faces: the islands as they are right now, and
  where they have been. Before this, the pairing existed only in the router:
  the history page linked back to the live one and the live one linked nowhere,
  so the history was reachable only by someone who already knew the URL.

  Lives here rather than in a generic components module because it belongs to
  this feature and nothing else uses it. A switch between two specific pages is
  not a reusable widget.
  """
  use Phoenix.Component
  use Phoenix.VerifiedRoutes, endpoint: BeamCampusWeb.Endpoint, router: BeamCampusWeb.Router

  @doc """
  The two faces, and the way back up.

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
end
