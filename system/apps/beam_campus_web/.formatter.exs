[
  import_deps: [:phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  # Excluded below: holds a captured champion-chase trajectory as a single-line
  # literal. The formatter explodes it to one map per line, which is a
  # readability regression on data, not a cleanup.
  # NOTE: globs are anchored to __DIR__ on purpose. `mix format` runs from the
  # umbrella root, so a bare relative wildcard here silently expands to nothing
  # and the format gate passes while checking no files at all.
  inputs:
    ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"]
    |> Enum.flat_map(&Path.wildcard(Path.join(__DIR__, &1), match_dot: true))
    |> Enum.map(&Path.relative_to(&1, __DIR__))
    |> Kernel.--(["lib/beam_campus_web/live/neural_coevolution_live.ex"])
]
