defmodule BeamCampus.DeceptionMaze do
  @moduledoc """
  The deceptive-maze demo (faber insight 051): novelty search solves a maze whose
  objective gradient is a trap, where goal-chasing and a strong optimiser cannot.

  A faithful port of the signed EXP-051 runner
  (`faber-programmes/experiments/exp051_deceptive_maze_novelty_tests.erl`): same
  11x11 grid, same position-only sensors (Markov, no goal pointer — the deception is
  in the landscape, not leaked), same (mu+lambda) EA differing only in the score
  (closeness-to-goal vs final-position k-NN novelty). The net is real faber-tweann
  (`:network_evaluator`), so a champion genome replays identically here.

  Two mazes, a matched pair. `:deceptive` — the wall's only gap is far from the
  goal, so the greedy "get closer" route dead-ends in a cul-de-sac. `:twin` — the
  gap sits on the greedy route, so goal-chasing solves it. Same start `{1,1}`, same
  goal `{1,9}`. The twin is the control: goal-chasing failing on `:deceptive` but
  solving `:twin` shows it is the trap, not the difficulty.
  """

  @w 11
  @h 11
  @t 60
  @hid 10
  @sigma 0.15
  @mu 20
  @lambda 20
  @k_nov 15
  @np @hid * 6 + @hid + 4 * @hid + 4
  @s {1, 1}
  @g {1, 9}

  # Pre-evolved champions (mined with `mine_champions/0`; genomes are 114 weights):
  # objective-on-deceptive is trapped in the cul-de-sac, novelty-on-deceptive reaches
  # the goal, objective-on-twin reaches the goal (the control).
  @obj_champion [0.111166, -0.099729, 0.966654, 0.39349, 0.024614, -0.38603, -1.0471, 0.775765, -0.255581, 1.021105, -0.757959, 0.751875, 0.253987, 1.428907, 0.90174, 0.479937, 0.915156, -0.119392, 0.193394, -1.484382, -0.797999, -0.713899, 0.856224, 0.705597, -0.073038, -0.668262, -0.616791, -1.032884, 0.248217, 0.194796, -0.911054, -1.32632, 0.865449, -1.581756, 1.974395, -0.037978, -0.046034, 0.65444, -0.493803, 0.269775, 0.635457, 0.01898, 1.518582, -0.214559, 1.727262, -0.998268, 0.456429, 0.282194, -2.503487, 1.201344, -2.170376, 1.204714, -0.033353, -1.296441, 1.325983, 0.857886, -0.458107, -0.303429, 0.175947, -0.761657, -3.456104, -0.590236, -0.927018, -0.032223, 0.958823, -0.042305, 1.150567, 0.191357, 1.284565, -0.710909, 0.095873, -1.248008, -0.738289, 1.09932, 0.640515, -0.878062, -0.917134, 2.993566, 0.43024, -0.662844, 0.23095, 0.04974, 0.769745, -0.680573, 1.394799, 1.814108, -2.617107, -0.482435, 0.304248, -0.49221, 0.972931, -0.152782, 0.693302, 0.937698, 0.26675, -1.2403, -0.703447, 1.091929, 0.664041, 0.158967, -0.010827, 0.812324, -0.587373, -0.492473, 0.473794, -1.792376, 0.09995, -0.03335, -1.021319, 0.67125, 1.724658, -1.701363, -0.88378, 0.319933]
  @nov_champion [-2.31858, 0.822991, -0.352079, 0.090569, -0.524304, 0.507585, 1.409721, -0.718997, 1.64089, 1.605697, -0.372481, -0.59231, 0.253972, -0.660201, 2.344268, -0.202827, 0.549891, -0.334272, 2.537842, 0.845478, 0.10726, 2.166757, -0.438634, 1.824228, 1.632972, -0.235863, 1.126617, 0.489777, -0.436067, 0.923907, -0.064848, -1.577208, 0.099373, -1.066129, -1.989761, 1.420844, -1.607864, -0.349481, 0.113402, -1.517933, -1.052471, -1.039738, 0.098146, -1.597838, -0.395954, -1.048602, -1.331883, -0.713338, -0.637001, 1.268812, -1.617871, -0.722771, 3.09998, 0.545802, -1.137999, 1.271209, -1.549291, -0.840713, 1.01293, 1.243774, 1.02111, 0.787562, 0.546533, -1.188699, 0.035168, -1.493515, 1.459216, -0.368119, -0.81139, -0.301778, -0.003638, -1.307074, -0.413652, -0.471092, 0.006896, -0.280428, -0.527259, -1.3907, -0.799515, 1.561557, 1.780321, 0.718946, 0.174737, -1.45711, 0.055417, 0.578832, 0.382234, 0.414145, -0.254642, -0.670436, -1.949574, -2.840038, -1.489017, -0.876478, 0.321286, 0.133933, 0.056288, -1.425571, -0.462228, 1.847459, 0.497106, -0.504337, -2.190929, 0.698539, -0.984939, -2.77863, 0.238359, -0.050484, -0.847604, 2.425072, -0.212271, 1.228603, 1.231897, 0.936093]
  @obj_twin_champion [-1.268042, 0.709543, 0.421206, 1.006643, -0.711971, 0.40952, -0.935984, -1.223872, 0.89652, 0.975013, 0.282439, -0.34128, 1.043846, 0.683316, -1.975537, 1.888891, -1.28949, 0.179237, 2.158813, -0.326618, -0.864669, 0.432154, -1.220421, 1.046911, -0.396008, 0.221271, -0.440222, -2.017506, 1.303539, -0.525047, -0.158749, -0.092724, 1.276339, 0.20898, -1.056118, -0.677675, -1.038729, 0.400701, 0.878329, 0.095808, -1.396959, 0.468892, -0.052497, 0.098663, -0.612874, -1.428693, 0.446706, 0.494572, -0.028249, 0.976962, -1.031674, 1.053709, -0.148535, 0.319403, 2.117603, 0.932644, -0.520681, 0.427654, -1.367968, -0.341314, -1.661242, -0.960632, -2.181086, -0.366568, -0.69008, -0.013119, -0.13055, 0.318233, 0.116048, -0.515128, 0.297419, -0.049184, -1.075329, -1.435196, -0.060502, -1.001644, 0.925545, -0.549775, 0.818654, -0.934056, 0.231604, 1.303324, 0.338819, 1.917843, -1.156018, -1.15486, 0.68914, 0.368913, 1.046944, -0.318563, 0.979615, -0.778458, 0.86194, 0.019116, 1.12708, 0.522509, -0.321229, 0.089159, 0.097244, -0.154229, 0.473003, -0.693977, -0.126002, -1.94296, 1.041585, -0.585924, -0.649982, -0.548225, 1.046389, -0.677858, 0.526578, 1.34869, -1.446869, -0.725072]

  # --- public surface -----------------------------------------------------------

  @doc "Grid size `{w, h}` (cells are `{x, y}` with x,y in 0..w-1 / 0..h-1)."
  def dims, do: {@w, @h}
  def start_cell, do: @s
  def goal_cell, do: @g
  def steps, do: @t

  @doc "The maze spec for `:deceptive` or `:twin`."
  def maze(:deceptive), do: %{blocked: wall_gap([9, 10]), s: @s, g: @g}
  def maze(:twin), do: %{blocked: wall_gap([1]), s: @s, g: @g}

  @doc "The wall (blocked) cells of a maze, for rendering."
  def wall_cells(maze_key), do: maze_key |> maze() |> Map.fetch!(:blocked) |> Map.keys()

  @doc "A champion's genome. `:objective` / `:novelty` on the deceptive maze; `:objective_twin` on the twin."
  def champion(:objective), do: @obj_champion
  def champion(:novelty), do: @nov_champion
  def champion(:objective_twin), do: @obj_twin_champion

  @doc """
  Roll a genome out through a maze, returning `%{path, final, solved}` — the ordered
  list of cells the agent occupies (start first, one per step, stopping at the goal),
  its final cell, and whether it reached the goal.
  """
  def rollout_path(genome, maze), do: walk(mk_net(genome), maze, maze.s, @t, [maze.s], maze.s == maze.g)

  @doc "Roll a pre-evolved champion out through a maze key (e.g. `run(:novelty, :deceptive)`)."
  def run(mode, maze_key), do: rollout_path(champion(mode), maze(maze_key))

  @doc """
  Evolve on a maze with a (mu+lambda) EA. `mode` is `:objective` (score = closeness to
  goal) or `:novelty` (score = final-position k-NN novelty). `on_gen` is
  `fun(generation, champion_individual)` for live progress, where the champion is the
  best-by-closeness individual (its `:path` is what to draw). Returns that champion.
  """
  def evolve(mode, maze, generations, on_gen) do
    pop = for _ <- 1..@mu, do: evalind(maze, rand_genome())
    emit_best(on_gen, 0, pop)
    ea_loop(mode, maze, generations, pop, [], on_gen, 0)
  end

  @doc false
  # One-off: evolve the three showcase champions locally and return their genomes.
  def mine_champions do
    %{
      objective: mine_trapped().g,
      novelty: mine_solved(:novelty, :deceptive).g,
      objective_twin: mine_solved(:objective, :twin).g
    }
  end

  # --- evolution ----------------------------------------------------------------

  defp ea_loop(_mode, _maze, total, pop, _arch, _on, gen) when gen >= total, do: champ(pop)

  defp ea_loop(mode, maze, total, pop, arch, on, gen) do
    offspring = for _ <- 1..@lambda, do: evalind(maze, mutate(pick(pop).g))
    new_pop = top_mu(score(mode, pop ++ offspring, arch))
    arch1 = archive_update(mode, arch, offspring)
    emit_best(on, gen + 1, new_pop)
    ea_loop(mode, maze, total, new_pop, arch1, on, gen + 1)
  end

  defp emit_best(on, gen, pop), do: on.(gen, champ(pop))
  defp champ(pop), do: Enum.max_by(pop, & &1.close)
  defp pick(pop), do: Enum.random(pop)

  defp top_mu(scored) do
    scored |> Enum.sort_by(&elem(&1, 0), :desc) |> Enum.take(@mu) |> Enum.map(&elem(&1, 1))
  end

  defp score(:objective, inds, _arch), do: Enum.map(inds, &{&1.close, &1})

  defp score(:novelty, inds, arch) do
    all = Enum.map(inds, & &1.fp) ++ arch
    Enum.map(inds, &{novelty(&1.fp, all), &1})
  end

  # Append-only archive: add the single most-novel offspring endpoint (a sliding
  # window would forget old behaviours and let novelty re-farm explored regions).
  defp archive_update(:objective, arch, _off), do: arch

  defp archive_update(:novelty, arch, off) do
    fps = Enum.map(off, & &1.fp)
    {_, most} = fps |> Enum.map(&{novelty(&1, arch ++ fps), &1}) |> Enum.max_by(&elem(&1, 0))
    [most | arch]
  end

  # Novelty = mean of the k smallest distances to the others, INCLUDING duplicates at
  # distance 0 (the anti-convergence penalty). Drop exactly one self-distance.
  defp novelty(fp, others) do
    ds = others |> Enum.map(&manhattan(fp, &1)) |> Enum.sort() |> drop_one_zero()
    mean(Enum.take(ds, max(1, min(@k_nov, length(ds)))))
  end

  defp drop_one_zero([0 | t]), do: t
  defp drop_one_zero(ds), do: ds

  defp evalind(maze, g) do
    %{path: path, final: final, solved: solved} = rollout_path(g, maze)
    %{g: g, fp: final, close: closeness(final, maze.g), solved: solved, path: path}
  end

  defp mine_trapped do
    c = evolve(:objective, maze(:deceptive), 60, fn _, _ -> :ok end)
    trapped_or_retry(c)
  end

  defp trapped_or_retry(%{solved: true}), do: mine_trapped()
  defp trapped_or_retry(c), do: c

  defp mine_solved(mode, maze_key) do
    c = evolve(mode, maze(maze_key), 80, fn _, _ -> :ok end)
    solved_or_retry(c, mode, maze_key)
  end

  defp solved_or_retry(%{solved: true} = c, _mode, _key), do: c
  defp solved_or_retry(_c, mode, key), do: mine_solved(mode, key)

  # --- rollout ------------------------------------------------------------------

  defp walk(_net, _maze, pos, 0, acc, solved), do: done_path(acc, pos, solved)
  defp walk(_net, _maze, pos, _t, acc, true), do: done_path(acc, pos, true)

  defp walk(net, maze, pos, t, acc, false) do
    next = move(pos, argmax(:network_evaluator.evaluate(net, sense(maze, pos))), maze)
    walk(net, maze, next, t - 1, [next | acc], next == maze.g)
  end

  defp done_path(acc, final, solved), do: %{path: Enum.reverse(acc), final: final, solved: solved}

  # Sensors: normalised position + a legality bit per direction (no goal pointer).
  defp sense(maze, {x, y} = p) do
    [
      x / (@w - 1),
      y / (@h - 1),
      lbit(maze, move(p, 0, maze)),
      lbit(maze, move(p, 1, maze)),
      lbit(maze, move(p, 2, maze)),
      lbit(maze, move(p, 3, maze))
    ]
  end

  # Directions: 0=N 1=E 2=S 3=W. Illegal moves are no-ops (stay).
  defp move(from, dir, maze), do: stay_or_go(from, delta(from, dir), maze)
  defp stay_or_go(from, to, maze), do: pick_cell(legal?(maze, to), from, to)
  defp pick_cell(true, _from, to), do: to
  defp pick_cell(false, from, _to), do: from

  defp delta({x, y}, 0), do: {x, y + 1}
  defp delta({x, y}, 1), do: {x + 1, y}
  defp delta({x, y}, 2), do: {x, y - 1}
  defp delta({x, y}, 3), do: {x - 1, y}

  defp legal?(maze, {x, y}), do: x in 0..(@w - 1) and y in 0..(@h - 1) and not Map.has_key?(maze.blocked, {x, y})

  defp lbit(maze, cell), do: bit(legal?(maze, cell))
  defp bit(true), do: 1.0
  defp bit(false), do: 0.0

  defp closeness(final, g), do: 1.0 / (1.0 + manhattan(final, g))
  defp manhattan({x1, y1}, {x2, y2}), do: abs(x1 - x2) + abs(y1 - y2)

  defp argmax([h | t]), do: argmax(t, 1, h, 0)
  defp argmax([], _i, _best, best_i), do: best_i
  defp argmax([h | t], i, best, _best_i) when h > best, do: argmax(t, i + 1, h, i)
  defp argmax([_h | t], i, best, best_i), do: argmax(t, i + 1, best, best_i)

  # --- net / genome -------------------------------------------------------------

  defp mk_net(g), do: :network_evaluator.set_weights(:network_evaluator.create_feedforward(6, [@hid], 4, :tanh, :tanh), g)
  defp rand_genome, do: for(_ <- 1..@np, do: :rand.normal())
  defp mutate(g), do: for(x <- g, do: x + @sigma * :rand.normal())

  defp mean([]), do: 0.0
  defp mean(l), do: Enum.sum(l) / length(l)

  # Wall = the whole y=5 row except the given gap columns.
  defp wall_gap(gaps), do: for(x <- 0..(@w - 1), x not in gaps, into: %{}, do: {{x, 5}, true})
end
