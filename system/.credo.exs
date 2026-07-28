# Credo is the Elixir counterpart to elvis/rebar3_lint on the Erlang repos.
#
# This mirrors the `macula_min` elvis ruleset (see reckon-db-org/*/rebar.config):
# a focused set targeting structural smells rather than the full default ruleset,
# which would bury us in style nits. Expand once the codebase is clean.
#
# Rule parity with the Erlang side:
#
#   elvis {elvis_style, no_deep_nesting, #{level => 2}}
#     -> Credo.Check.Refactor.Nesting, max_nesting: 2
#        Same semantic on both sides: maximum nesting DEPTH 2, flagged at 3+.
#        Credo counts if/unless/case/cond/fn/for/with inside def/defp/defmacro;
#        elvis counts the equivalent Erlang forms. Credo's own default is
#        already 2, and it is pinned here so the parity is explicit rather
#        than inherited.
#
#   elvis {elvis_style, no_nested_try_catch, #{}}
#     -> no Credo equivalent. Recorded here rather than silently dropped.
#
#   elvis {elvis_style, no_if_expression, #{}}
#     -> no Credo equivalent. Credo ships no "ban if" check, and the house
#        preference for pattern-matched clauses over if/case stays a review
#        convention on the Elixir side unless someone writes a custom check.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["apps/*/lib/", "apps/*/test/", "apps/*/mix.exs", "mix.exs"],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/node_modules/",
          # Same three files the formatter skips (see apps/*/.formatter.exs):
          # they embed evolved-champion genomes and a captured chase trajectory
          # as single-line literals. Linting them yields only "line too long"
          # and "space missing after comma" against data, never against code.
          ~r"apps/beam_campus/lib/beam_campus/adaptation\.ex$",
          ~r"apps/beam_campus/lib/beam_campus/deception_maze\.ex$",
          ~r"apps/beam_campus_web/lib/beam_campus_web/live/neural_coevolution_live\.ex$"
        ]
      },
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        extra: [
          {Credo.Check.Refactor.Nesting, [max_nesting: 2]},
          # Default is 8. Raised to accommodate one existing offender,
          # BeamCampus.Coevolution.step_done/10, a private clause-dispatch
          # helper threading the whole loop state. Owed cleanup: bundle that
          # state into a struct and drop this back to 8. Kept as a live check
          # rather than disabled so anything worse than the status quo trips.
          {Credo.Check.Refactor.FunctionArity, [max_arity: 10]}
        ],
        disabled: [
          # mix format owns line breaking and it runs as its own CI gate.
          {Credo.Check.Readability.MaxLineLength, []},
          # This check's advice is "consider using `if` instead", which is the
          # opposite of the house rule (prefer pattern-matched clauses; avoid
          # `if` and `case`). Mirrors elvis `no_if_expression` on the Erlang
          # side, in spirit if not in mechanism.
          {Credo.Check.Refactor.CondStatements, []},
          # Fires only on Phoenix-generated scaffolding (core_components.ex,
          # test/support/data_case.ex). Re-enable if it ever fires on our code.
          {Credo.Check.Design.AliasUsage, []}
        ]
      }
    }
  ]
}
