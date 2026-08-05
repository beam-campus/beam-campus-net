defmodule Dronex.MixProject do
  use Mix.Project

  def project do
    [
      app: :dronex,
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
      mod: {Dronex.Application, []},
      extra_applications: [:logger]
    ]
  end

  # NO DEPENDENCY ON hecate_dronex, AND THAT IS THE WHOLE POINT OF THIS TRACK'S
  # WIRE FORMAT. An island publishes a bout as a RECORDING: every frame, already
  # computed, in one fact. This app stores it and animates it. It never runs the
  # engine and could not, because it does not have it.
  #
  # The removed Robo Rumble page did the opposite: it received two genomes and a
  # start index and RE-RAN the fight, which put a game engine inside a content
  # website, pinned the two to commits that drifted apart, and made every viewer
  # repeat identical work. That page is gone and this is the shape that replaces
  # it.
  # Public so `dronex_test` can assert what this app asked for, as against what
  # the umbrella happens to contain.
  def deps do
    [
      {:macula, "~> 7.1"},
      # The PubSub this app broadcasts board changes on. Declared rather than
      # relied on implicitly: an umbrella lets a sibling's modules resolve at
      # runtime without a dependency, which compiles happily and orders the
      # release wrong.
      {:beam_campus, in_umbrella: true},
      {:phoenix_pubsub, "~> 2.1"}
    ]
  end
end
