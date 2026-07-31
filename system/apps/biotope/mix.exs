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
      deps: deps()
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
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.2"}
    ]
  end
end
