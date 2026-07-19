defmodule BeamCampusWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BeamCampusWeb.Telemetry,
      # Start a worker by calling: BeamCampusWeb.Worker.start_link(arg)
      # {BeamCampusWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      BeamCampusWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BeamCampusWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BeamCampusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
