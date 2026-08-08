defmodule BeamCampus.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      listeners: [Phoenix.CodeReloader],
      releases: releases()
    ]
  end

  # Release overlay pattern (mirrors macula-realm): `bin/start` runs migrations
  # via `bin/migrate` then boots the server via `bin/server`. The Dockerfile
  # entrypoint is `./bin/start`.
  defp releases do
    [
      beam_campus: [
        include_executables_for: [:unix],
        steps: [:assemble, :tar],
        applications: [
          beam_campus: :permanent,
          biotope: :permanent,
          dronex: :permanent,
          beam_campus_web: :permanent
        ]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp deps do
    [
      # Required to run "mix format" on ~H/.heex files from the umbrella root
      {:phoenix_live_view, ">= 0.0.0"},
      # Style linter. The Elixir counterpart to elvis/rebar3_lint on the Erlang
      # repos; .credo.exs mirrors the `macula_min` ruleset used there.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  #
  # Aliases listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp aliases do
    [
      # run `mix setup` in all child apps
      setup: ["cmd mix setup"],
      # ⚠ THE CHARTS ARE RENDERED AND MEASURED, NOT EYEBALLED. This builds each
      # chart option with the same pure functions the browser uses, renders it to
      # SVG under Node, and asserts the geometry: equal radii, marks inside their
      # cells, nothing at NaN, colours actually painted.
      #
      # It exists because this page twice shipped a chart that was arithmetically
      # correct and visually wrong — an invisible 48% tint, and an in-flight
      # marker drawn four rows tall — and both were found by a human sending a
      # screenshot. Verified to go red with either bug reintroduced.
      #
      # ⚠ A FUNCTION, NOT `cmd'. `mix cmd' in an umbrella runs the command once
      # per child app, from inside each one, so the path resolves in neither.
      "charts.check": &charts_check/1,
      # ⚠ `credo --strict' IS IN CI AND WAS NOT IN HERE, so a commit could pass
      # every local gate and fail the branch. It did, on the vitals read model:
      # eleven `|| 0' fallbacks in one function, cyclomatic complexity 12. Local
      # and CI must run the same checks or the local ones are decoration.
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "credo --strict",
        "charts.check",
        "test"
      ]
    ]
  end

  defp charts_check(_args) do
    {out, code} =
      System.cmd("node", ["apps/beam_campus_web/assets/js/charts_check.mjs"],
        stderr_to_stdout: true
      )

    IO.puts(out)
    code == 0 || Mix.raise("chart checks failed")
  end
end
