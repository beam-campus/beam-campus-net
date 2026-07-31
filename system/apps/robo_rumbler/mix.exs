defmodule RoboRumbler.MixProject do
  use Mix.Project

  def project do
    [
      app: :robo_rumbler,
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
      mod: {RoboRumbler.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # The mesh. This is the first macula dependency in beam-campus-net and it
      # is a READER: the site subscribes and renders, never publishes and never
      # holds a store. See CLAUDE.md, which used to forbid macula here outright.
      {:macula, "~> 7.1"},
      # The engine, for `:robo_rumble.replay/2`. A published duel fact carries two
      # genomes and a start index, not frames, so the frames are regenerated here.
      # Same dep the beam_campus app already uses for the adaptation workbench.
      {:faber_tweann,
       git: "https://github.com/rgfaber/faber-tweann.git", branch: "master", manager: :rebar3},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.2"}
    ]
  end
end
