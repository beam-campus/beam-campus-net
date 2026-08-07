defmodule Dronex.Application do
  @moduledoc """
  Three children, always started, whether or not a mesh is configured.

  The subscriber creates the board and then ticks, so an unconfigured site has a
  working, empty page rather than a crashed supervisor. `Dronex.watching?/0` is
  what tells the page which of those it is looking at.

  ⚠ `RememberRaids` STARTS LAST AND THAT IS AN ORDERING, NOT A LIST. It puts
  stored raids back into the board on boot, so the board has to exist first, and
  `WatchBouts` is what creates it.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Dronex.Mesh,
      Dronex.WatchBouts,
      Dronex.RememberRaids
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Dronex.Supervisor)
  end
end
