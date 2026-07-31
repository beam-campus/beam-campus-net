defmodule Biotope.Application do
  @moduledoc """
  Two children, always started, whether or not a mesh is configured.

  The subscriber creates the board and then ticks, so an unconfigured site has a
  working, empty page rather than a crashed supervisor. `Biotope.watching?/0` is
  what tells the page which of those it is looking at.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Biotope.Mesh,
      Biotope.WatchIslands,
      # Started after the subscriber, because it reads the board the subscriber
      # creates. It writes nothing until an island's tick advances, so it is
      # harmless on a node that never hears from one.
      Biotope.RecordHistory
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Biotope.Supervisor)
  end
end
