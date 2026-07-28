[
  import_deps: [:ecto, :ecto_sql],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  # Excluded below: these modules embed pre-evolved champion genomes as
  # single-line literals (114 floats each). The formatter explodes them to one
  # float per line, which is a readability regression on data, not a cleanup.
  # NOTE: globs are anchored to __DIR__ on purpose. `mix format` runs from the
  # umbrella root, so a bare relative wildcard here silently expands to nothing
  # and the format gate passes while checking no files at all.
  inputs:
    ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
    |> Enum.flat_map(&Path.wildcard(Path.join(__DIR__, &1), match_dot: true))
    |> Enum.map(&Path.relative_to(&1, __DIR__))
    |> Kernel.--(["lib/beam_campus/adaptation.ex", "lib/beam_campus/deception_maze.ex"])
]
