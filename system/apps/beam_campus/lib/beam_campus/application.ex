defmodule BeamCampus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BeamCampus.Repo,
      {DNSCluster, query: Application.get_env(:beam_campus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BeamCampus.PubSub}
      # Start a worker by calling: BeamCampus.Worker.start_link(arg)
      # {BeamCampus.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BeamCampus.Supervisor)
  end
end
