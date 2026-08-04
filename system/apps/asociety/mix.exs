defmodule ASociety.MixProject do
  use Mix.Project

  def project do
    [
      app: :asociety,
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
      mod: {ASociety.Application, []},
      extra_applications: [:logger]
    ]
  end

  # NO DEPENDENCY ON hecate_society, AND THAT IS THE POINT. The contract between
  # an island and this reader is the published fact and its `fact_version`,
  # nothing else. The rumble taught the alternative expensively: the site pinned
  # the engine at one commit, the service at another, and the fingerprint they
  # both published drifted with nothing comparing them. A reader that shares code
  # with the thing it reads is a reader that can quietly start computing.
  defp deps do
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
