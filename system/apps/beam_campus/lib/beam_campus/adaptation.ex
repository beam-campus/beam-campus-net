defmodule BeamCampus.Adaptation do
  @moduledoc """
  Runs (and evolves) faber-tweann controllers live on a cart-pole with a hidden
  mid-episode motor fault.

  Real inference, not replay: every `step/1` is an `:network_evaluator` forward pass
  plus a `:pb_sim` physics step on the BEAM. `evolve/3` runs separable CMA-ES on a
  chosen scenario, streaming per-generation fitness through a callback — so the site
  can evolve a controller live for parameters the user picks.

  Controllers:

    * `:fixed`   feedforward, no adaptation.
    * `:cfc`     recurrent (continuous-time), adapts via its internal state.
    * `:plastic` reward-modulated plasticity, adapts by re-wiring its own weights.

  A scenario is `%{wind, shift_gain, shift_at, goal}` (the motor multiplies by
  `shift_gain` from step `shift_at`; `wind` is a constant disturbance). A `frame` is
  `%{cpos, angle, step, done, status, shifted}` (cpos in metres, angle in radians).
  """

  @n_in 4
  @hidden [8]
  @out 1
  @nw hd(@hidden) * @n_in + hd(@hidden) + @out * hd(@hidden) + @out
  @ntau hd(@hidden)
  @mk 5.0
  @limit 2 * :math.pi() * 36 / 360
  @track 2.4

  @default_scenario %{wind: 5.0, shift_gain: -1.0, shift_at: 120, goal: 400}

  @genomes %{
    fixed:
      [0.575756, -1.738215, 1.087343, -2.104107, 0.189731, 0.519340, 1.419557, -1.084691, -0.061720, 0.893481, 2.031568, -0.146437, 0.382872, -0.029370, 0.211012, 0.818638, -1.535467, -0.513454, 1.751497, 1.021099, -0.091488, 0.472164, -1.405633, -1.722039, 1.405048, -0.176815, -1.333362, 0.014224, -0.044893, -0.602072, 1.900523, -0.351251, 1.440692, -0.741588, 1.054842, -0.929738, 0.629864, -0.597005, -3.020090, 0.677533, -1.240619, 1.402905, 1.617121, 3.676241, 0.513029, -2.106266, -1.325641, 2.830720, -1.465805],
    cfc:
      [0.986728, 2.194920, 0.123818, -32.156617, 0.575990, -1.853123, -7.007008, 5.301766, 10.258230, -4.070533, -6.455249, -21.173328, 1.968523, -8.244119, -39.133988, -26.742143, 22.027669, -7.388172, -0.286973, -6.304092, 1.357418, -5.159759, 2.926582, 3.643917, -3.577273, 7.283232, 5.317318, -2.743784, 1.786990, 1.913842, -26.007601, 16.085700, -1.269156, -22.099656, -6.244289, 2.713978, 10.312201, 4.970221, 2.371286, 7.090544, 3.328082, -10.832119, 13.883839, -17.960852, 2.137343, -13.738229, 0.545854, 1.500461, 3.194205, -1.762754, 14.865494, 0.305646, 7.099740, 21.900832, 7.535048, 5.011859, 4.239477],
    plastic:
      [-0.333047, -17.126701, 3.827638, -3.541775, 0.011010, 0.654606, 0.089883, 7.127044, 8.662681, -3.237075, 4.728959, 8.428751, 11.499705, -3.691563, 21.353101, -2.470246, 4.105046, -4.371631, 25.448380, 20.009441, 1.156409, 2.908713, -4.524845, 0.274956, 3.706073, -12.302640, 0.478556, 7.922473, -5.748809, 0.777654, 1.379473, -1.489141, 6.723612, 0.755335, -11.258255, -1.795275, -0.292837, -6.062292, -1.337447, -4.592095, -0.841682, 0.553018, 10.846005, 7.796205, -1.053719, 0.444597, 2.340526, -4.184125, -0.118913, 2.897530, -54.644130, -3.756147, -8.350249, 19.960626]
  }

  @arms [
    %{key: :fixed, label: "Fixed", sub: "feedforward · no adaptation"},
    %{key: :cfc, label: "Recurrent (CfC)", sub: "continuous-time state"},
    %{key: :plastic, label: "Adaptive", sub: "reward-modulated plasticity"}
  ]

  @doc "The controllers, with display metadata."
  def arms, do: @arms

  @doc "The default showcase scenario (motor reversal, wind 5, fault at 120)."
  def default_scenario, do: @default_scenario

  @doc "The genome dimensionality for a controller (for evolution)."
  def dim(:fixed), do: @nw
  def dim(:cfc), do: @nw + @ntau
  def dim(:plastic), do: @nw + 5

  def angle_limit, do: @limit
  def track, do: @track

  @doc "Initialise a controller from its pre-evolved genome, in the default scenario."
  def init(arm) when is_map_key(@genomes, arm), do: init_with(arm, @genomes[arm], @default_scenario)

  @doc "Initialise a controller from a genome and scenario."
  def init_with(arm, genome, scenario) do
    %{
      arm: arm,
      net: build_net(arm, genome),
      rule: rule(arm, genome),
      scape: scape(scenario),
      scenario: scenario,
      step: 0,
      prev_tilt: 0.0,
      done: false,
      survived: 0,
      last: {0.0, first_angle()}
    }
  end

  @doc """
  Evolve a controller for a scenario with separable CMA-ES. `on_gen` is a
  `fun(gen, best_fitness)` for live progress. Returns `{genome, fitness}`.
  """
  def evolve(arm, scenario, on_gen, opts \\ []) do
    lambda = Keyword.get(opts, :lambda, 60)
    max_gen = Keyword.get(opts, :max_generations, 60)
    fit = fn vec -> survival(init_with(arm, vec, scenario), scenario.goal) end

    es = %{
      lambda: lambda,
      max_generations: max_gen,
      fitness_goal: (scenario.goal - 15) * 1.0,
      init_sigma: 1.0,
      on_generation: on_gen
    }

    r = :sep_cma_es.evolve(fit, dim(arm), es)
    {r.best, round(r.fitness)}
  end

  @doc """
  Run one control step. Returns `{frame, agent}`. A finished agent is frozen.
  """
  def step(%{done: true, step: n, survived: sv, scenario: sc, last: {cpos, angle}} = agent) do
    {frame(cpos, angle, n, true, status(n, true, sv, sc), n >= sc.shift_at), agent}
  end

  def step(agent) do
    sc = agent.scenario
    {in_vec, s1} = :pb_sim.sense(:x, [@n_in], agent.scape)
    tilt = abs(Enum.at(in_vec, 2))
    out = :network_evaluator.evaluate(agent.net, in_vec)
    net1 = learn(agent.arm, agent, in_vec, tilt)
    {_f, halt, s2} = :pb_sim.act(:x, [:without_damping, 0, sc.goal], out, s1)
    done = halt != 0
    {cpos, angle} = read(s2)
    n = agent.step
    survived = if done, do: n, else: agent.survived
    frame = frame(cpos, angle, n, done, status(n, done, survived, sc), n >= sc.shift_at)
    {frame,
     %{agent | net: net1, scape: s2, step: n + 1, prev_tilt: tilt, done: done, survived: survived, last: {cpos, angle}}}
  end

  # --- fitness (survival steps) for evolution -----------------------------------

  defp survival(agent, goal) do
    result =
      Enum.reduce_while(1..(goal + 1), agent, fn _, a ->
        {f, a2} = step(a)
        if f.done, do: {:halt, f.step}, else: {:cont, a2}
      end)

    if is_integer(result), do: result * 1.0, else: goal * 1.0
  end

  # --- per-controller inference -------------------------------------------------

  defp build_net(:cfc, genome) do
    {wv, tv} = Enum.split(genome, @nw)
    net = set_taus(:network_evaluator.set_weights(create_cfc(), wv), tv)
    :network_evaluator.reset_internal_state(net)
  end

  defp build_net(_arm, genome), do: :network_evaluator.set_weights(create_ff(), Enum.take(genome, @nw))

  defp rule(:plastic, genome) do
    [a, b, c, d, eta_raw] = Enum.drop(genome, @nw)
    {a, b, c, d, 0.1 * :math.tanh(eta_raw)}
  end

  defp rule(_arm, _genome), do: nil

  defp learn(:cfc, agent, in_vec, _tilt) do
    {_out, net1} = :network_evaluator.evaluate_with_state(agent.net, in_vec)
    net1
  end

  defp learn(:plastic, agent, in_vec, tilt) do
    m = :math.tanh(@mk * (agent.prev_tilt - tilt))
    {_out, net1} = :network_evaluator.evaluate_with_neuromod(agent.net, in_vec, agent.rule, m)
    net1
  end

  defp learn(:fixed, agent, _in, _tilt), do: agent.net

  # --- helpers ------------------------------------------------------------------

  defp create_ff, do: :network_evaluator.create_feedforward(@n_in, @hidden, @out, :tanh, :tanh)
  defp create_cfc, do: :network_evaluator.create_cfc_feedforward(@n_in, @hidden, @out, :tanh, :tanh)

  defp scape(%{shift_at: sa, shift_gain: sg, wind: w}), do: :pb_sim.init(shift_at: sa, shift_gain: sg, wind: w)

  defp read(scape_state) do
    {[cpos_s, _cvel, angle_s | _], _} = :pb_sim.sense(:x, [@n_in], scape_state)
    {cpos_s * @track, angle_s * @limit}
  end

  defp first_angle, do: 3.6 * (2 * :math.pi() / 360)

  defp frame(cpos, angle, step, done, status, shifted) do
    %{cpos: r3(cpos), angle: r4(angle), step: step, done: done, status: status, shifted: shifted}
  end

  defp status(step, false, _sv, %{shift_at: sa}) when step < sa, do: :balancing
  defp status(_step, false, _sv, _sc), do: :recovering
  defp status(_step, true, sv, %{goal: g}) when sv >= g, do: :stable
  defp status(_step, true, _sv, _sc), do: :crashed

  defp set_taus(net, tau_params) do
    meta = :network_evaluator.get_neuron_meta(net)
    {new_meta, []} = Enum.map_reduce(meta, tau_params, &set_layer_taus/2)
    :network_evaluator.set_neuron_meta(net, new_meta)
  end

  defp set_layer_taus(layer_meta, params), do: Enum.map_reduce(layer_meta, params, &set_neuron_tau/2)

  defp set_neuron_tau(%{neuron_type: :cfc} = m, [p | rest]), do: {Map.put(m, :tau, tau_transform(p)), rest}
  defp set_neuron_tau(%{neuron_type: :standard} = m, params), do: {m, params}

  defp tau_transform(x), do: 0.05 + :math.log(1.0 + :math.exp(min(x, 30.0)))

  defp r3(x), do: Float.round(x * 1.0, 3)
  defp r4(x), do: Float.round(x * 1.0, 4)
end
