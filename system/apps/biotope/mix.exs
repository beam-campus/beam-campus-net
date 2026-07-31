defmodule Biotope.MixProject do
  use Mix.Project

  def project do
    [
      app: :biotope,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {Biotope.Application, []},
      extra_applications: [:logger]
    ]
  end

  # NO DEPENDENCY ON hecate_biotope, AND THAT IS THE POINT. The contract between
  # the island and this reader is the published fact and its `fact_version`,
  # nothing else. The rumble taught the alternative expensively: the site pinned
  # the engine at one commit, the service at another, and the fingerprint they
  # both published drifted with nothing comparing them. A reader that shares code
  # with the thing it reads is a reader that can quietly start computing.
  defp deps do
    [
      {:macula, "~> 7.1"},
      # The Repo, and the PubSub the subscriber already broadcasts on. Declared
      # now rather than relied on implicitly: an umbrella lets a sibling's
      # modules resolve at runtime without a dependency, which compiles happily
      # and orders the release wrong.
      {:beam_campus, in_umbrella: true},
      {:ecto_sql, "~> 3.10"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.2"}
    ]
  end

  # The Repo lives in :beam_campus, so the repo has to be named explicitly:
  # `mix ecto.migrate` run from here would otherwise look for :biotope's own
  # :ecto_repos, find none, and do nothing at all rather than complain.
  defp aliases do
    [
      test: [
        "ecto.create -r BeamCampus.Repo --quiet",
        "ecto.migrate -r BeamCampus.Repo --quiet",
        "test"
      ]
    ]
  end
end
