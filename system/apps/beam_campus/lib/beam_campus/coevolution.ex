defmodule BeamCampus.Coevolution do
  @moduledoc """
  Neural pursuit-evasion coevolution (Programme 7). Two populations of faber-tweann
  networks -- pursuers and evaders -- coevolve on a small torus grid: each is the
  other's environment. Real engine: every move is a `:network_evaluator` forward pass.

  The point of the demo is the coevolution METHODOLOGY the numbers-game rungs 053-055
  established: progress is measured against a FIXED benchmark (a frozen snapshot of the
  gen-0 opponent population), NOT co-fitness (score against the current opponent). If
  both benchmark curves rise while co-fitness stays flat, that is a Red Queen arms race;
  if one dominates and both flatten, that is disengagement. The demo shows whichever
  actually happens -- both are honest, both are educational.

  `mine/1` runs a coevolution offline and returns the per-generation trajectory
  (benchmark progress for each side + co-fitness) plus the final champion genomes, so a
  LiveView can replay the curves and animate a champion match.
  """

  @w 9
  @t 40
  @hidden [6]
  @np 6 * 2 + 6 + 4 * 6 + 4
  @mu 20
  @lambda 20
  @sigma 0.2
  @k 4
  @starts [{{0, 0}, {4, 4}}, {{0, 4}, {4, 0}}]

  @doc "Grid width (torus), episode length."
  def dims, do: {@w, @t}

  @doc """
  Run a coevolution for `gens` generations. Returns
  `%{traj: [%{gen, p_prog, e_prog, cofit}], pursuer: genome, evader: genome}`.
  """
  def mine(gens \\ 30) do
    pop_p = for _ <- 1..@mu, do: rand_genome()
    pop_e = for _ <- 1..@mu, do: rand_genome()
    bench_p = pop_p
    bench_e = pop_e
    loop(gens, 0, pop_p, pop_e, bench_p, bench_e, [])
  end

  @doc "Roll a champion pursuer vs a champion evader from one start; return the path of both."
  def match_path(pursuer, evader, start_idx \\ 0) do
    {sp, se} = Enum.at(@starts, start_idx)
    walk_path(mk_net(pursuer), mk_net(evader), sp, se, @t, [{sp, se}])
  end

  # --- coevolution loop ---------------------------------------------------------

  defp loop(gens, g, pop_p, pop_e, bench_p, bench_e, acc) do
    # evaluate + select each population against the current other population
    scored_p = Enum.map(pop_p ++ offspring(pop_p), &{pfit(&1, pop_e), &1})
    scored_e = Enum.map(pop_e ++ offspring(pop_e), &{efit(&1, pop_p), &1})
    new_p = top_mu(scored_p)
    new_e = top_mu(scored_e)
    champ_p = best(scored_p)
    champ_e = best(scored_e)

    # progress vs the FROZEN gen-0 benchmark; co-fitness vs the CURRENT opponent champion
    frame = %{
      gen: g,
      p_prog: catch_rate(champ_p, bench_e),
      e_prog: survive_rate(champ_e, bench_p),
      cofit: catch_rate(champ_p, [champ_e])
    }

    step_done(g + 1 >= gens, gens, g, new_p, new_e, bench_p, bench_e, [frame | acc], champ_p, champ_e)
  end

  defp step_done(true, _gens, _g, _np, _ne, _bp, _be, acc, cp, ce),
    do: %{traj: Enum.reverse(acc), pursuer: cp, evader: ce}

  defp step_done(false, gens, g, np, ne, bp, be, acc, _cp, _ce),
    do: loop(gens, g + 1, np, ne, bp, be, acc)

  defp offspring(pop), do: for(_ <- 1..@lambda, do: mutate(Enum.random(pop)))
  defp top_mu(scored), do: scored |> Enum.sort_by(&elem(&1, 0), :desc) |> Enum.take(@mu) |> Enum.map(&elem(&1, 1))
  defp best(scored), do: scored |> Enum.max_by(&elem(&1, 0)) |> elem(1)

  # --- fitness / benchmark metrics ----------------------------------------------

  # pursuer fitness vs a sample of evaders: rewards fast capture (gradient), no capture = 0.
  defp pfit(p, evaders) do
    opp = Enum.take_random(evaders, min(@k, length(evaders)))
    mean(for e <- opp, do: p_score(match(p, e)))
  end

  defp efit(e, pursuers) do
    opp = Enum.take_random(pursuers, min(@k, length(pursuers)))
    mean(for p <- opp, do: 1.0 - p_score(match(p, e)))
  end

  defp p_score({captured, step}), do: if(captured, do: 1.0 - 0.5 * step / @t, else: 0.0)

  # catch RATE = fraction of the (benchmark) evaders captured (clean 0..1 progress).
  defp catch_rate(p, evaders), do: mean(for e <- evaders, do: bit(captured?(match(p, e))))
  defp survive_rate(e, pursuers), do: mean(for p <- pursuers, do: bit(not captured?(match(p, e))))
  defp captured?({captured, _step}), do: captured
  defp bit(true), do: 1.0
  defp bit(false), do: 0.0

  # --- the game (one match, averaged over the fixed start set) ------------------

  defp match(p_genome, e_genome), do: duel(mk_net(p_genome), mk_net(e_genome))

  defp duel(p_net, e_net) do
    results = for {sp, se} <- @starts, do: play(p_net, e_net, sp, se, @t)
    # captured if caught in ANY start; report the earliest capture step
    captured = Enum.any?(results, fn {c, _} -> c end)
    step = results |> Enum.map(fn {_, s} -> s end) |> Enum.min()
    {captured, step}
  end

  defp play(_p, _e, pp, pe, 0), do: {chebyshev(pp, pe) <= 1, @t}
  defp play(p_net, e_net, pp, pe, t) do
    caught_now(chebyshev(pp, pe) <= 1, @t - t, p_net, e_net, pp, pe, t)
  end

  defp caught_now(true, step, _p, _e, _pp, _pe, _t), do: {true, step}

  defp caught_now(false, step, p_net, e_net, pp, pe, t) do
    pp2 = move(pp, argmax(:network_evaluator.evaluate(p_net, sense(pp, pe))))
    pe2 = e_move(pe, argmax(:network_evaluator.evaluate(e_net, sense(pe, pp))), step)
    play(p_net, e_net, pp2, pe2, t - 1)
  end

  # The evader skips 1 move in 3 -> the pursuer is 1.5x faster. Enough of an edge that real
  # pursuit evolves and captures happen (a watchable chase), but the pursuer then DOMINATES:
  # the evader's gradient dies (disengagement toward the pursuer). Equal speed flips it the
  # other way (evader escapes forever). A two-sided arms race is the knife-edge between.
  defp e_move(pe, dir, step), do: e_move_v(rem(step, 3), pe, dir)
  defp e_move_v(2, pe, _dir), do: pe
  defp e_move_v(_r, pe, dir), do: move(pe, dir)

  # path for animation: list of {pursuer_cell, evader_cell} per step, stopping at capture.
  defp walk_path(_p, _e, pp, pe, 0, acc), do: %{path: Enum.reverse(acc), caught: chebyshev(pp, pe) <= 1}

  defp walk_path(p_net, e_net, pp, pe, t, acc) do
    caught = chebyshev(pp, pe) <= 1
    walk_path_v(caught, p_net, e_net, pp, pe, t, acc)
  end

  defp walk_path_v(true, _p, _e, _pp, _pe, _t, acc), do: %{path: Enum.reverse(acc), caught: true}

  defp walk_path_v(false, p_net, e_net, pp, pe, t, acc) do
    pp2 = move(pp, argmax(:network_evaluator.evaluate(p_net, sense(pp, pe))))
    pe2 = e_move(pe, argmax(:network_evaluator.evaluate(e_net, sense(pe, pp))), @t - t)
    walk_path(p_net, e_net, pp2, pe2, t - 1, [{pp2, pe2} | acc])
  end

  # sensors: opponent's shortest wrap-around relative position, normalised to [-1, 1].
  defp sense({sx, sy}, {ox, oy}), do: [wrap_delta(ox - sx) / (@w / 2), wrap_delta(oy - sy) / (@w / 2)]

  defp wrap_delta(d) do
    m = Integer.mod(d, @w)
    over_half(m)
  end

  defp over_half(m) when m > div(@w, 2), do: m - @w
  defp over_half(m), do: m

  defp move({x, y}, 0), do: {x, Integer.mod(y + 1, @w)}
  defp move({x, y}, 1), do: {Integer.mod(x + 1, @w), y}
  defp move({x, y}, 2), do: {x, Integer.mod(y - 1, @w)}
  defp move({x, y}, 3), do: {Integer.mod(x - 1, @w), y}

  defp chebyshev({x1, y1}, {x2, y2}), do: max(torus_dist(x1, x2), torus_dist(y1, y2))
  defp torus_dist(a, b), do: min(Integer.mod(a - b, @w), Integer.mod(b - a, @w))

  defp argmax([h | t]), do: argmax(t, 1, h, 0)
  defp argmax([], _i, _b, bi), do: bi
  defp argmax([h | t], i, b, _bi) when h > b, do: argmax(t, i + 1, h, i)
  defp argmax([_h | t], i, b, bi), do: argmax(t, i + 1, b, bi)

  # --- net / genome / numerics --------------------------------------------------

  defp mk_net(g), do: :network_evaluator.set_weights(:network_evaluator.create_feedforward(2, @hidden, 4, :tanh, :tanh), g)
  defp rand_genome, do: for(_ <- 1..@np, do: :rand.normal())
  defp mutate(g), do: for(x <- g, do: x + @sigma * :rand.normal())
  defp mean([]), do: 0.0
  defp mean(l), do: Enum.sum(l) / length(l)
end
