defmodule BeamCampusWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :beam_campus_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {BeamCampusWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:beam_campus, in_umbrella: true},
      # The biotope spectator: subscribes to the islands' mesh facts and draws
      # the last frame that arrived. It regenerates nothing and shares no code
      # with the service it reads, which is the rule every spectator here now
      # follows: the Robo Rumble page did the opposite and was removed for it.
      {:biotope, in_umbrella: true},
      # The artificial-cultures spectator. Same contract as the biotope: it
      # subscribes to published facts and takes no dependency on the island's
      # code. Declared here so the umbrella compiles it FIRST and the release
      # starts it in the right order; without this the page's calls resolve at
      # runtime, which compiles with warnings and orders the release wrong.
      {:asociety, in_umbrella: true},
      # The drone-AI spectator. It PLAYS a published recording and never runs the
      # engine, which it could not do anyway: it takes no dependency on the
      # island's code, only on the fact and its fact_version.
      {:dronex, in_umbrella: true},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      # Notebook: compile-time markdown posts (the open lab notebook / ELI5 blog).
      {:nimble_publisher, "~> 1.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind beam_campus_web", "esbuild beam_campus_web"],
      "assets.deploy": [
        "tailwind beam_campus_web --minify",
        "esbuild beam_campus_web --minify",
        "phx.digest"
      ]
    ]
  end
end
