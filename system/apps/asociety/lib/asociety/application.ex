defmodule ASociety.Application do
  @moduledoc """
  Two children, always started, whether or not a mesh is configured.

  The subscriber creates the board and then ticks, so an unconfigured site has a
  working, empty page rather than a crashed supervisor. `ASociety.watching?/0` is
  what tells the page which of those it is looking at.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ASociety.Mesh,
      ASociety.WatchIslands
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ASociety.Supervisor)
  end
end
