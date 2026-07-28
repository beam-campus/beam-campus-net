defmodule BeamCampus.RedQueen do
  @moduledoc """
  The Red Queen, numerically (faber insight 053). A COEVOLUTION-METHODOLOGY demo, NOT
  neuroevolution: players are single numbers (no network), so the true progress is a
  value we can read directly and the failure of co-fitness is undeniable.

  Two populations coevolve on a stochastic "bigger tends to win" game
  (P(A beats B) = logistic((x_A - x_B)/tau)). The trait escalates without bound (real,
  observable progress), while co-fitness -- population A's mean win-probability against
  population B -- stays pinned at ~0.5, blind to it. That is the Red Queen, and it is
  why coevolution must be measured against a fixed benchmark, not the moving opponent.

  Runs live (pure arithmetic). `run/1` returns the per-generation trajectory.
  """

  @mu 20
  @lambda 20
  @sigma 0.3
  @tau 0.3
  @x0 50.0

  @doc "Run the self-play numbers game for `gens` generations. Returns [%{gen, trait, cofit}]."
  def run(gens \\ 90) do
    loop(gens, 0, List.duplicate(@x0, @mu), [])
  end

  def x0, do: @x0

  defp loop(gens, g, _pop, acc) when g >= gens, do: Enum.reverse(acc)

  defp loop(gens, g, pop, acc) do
    pop1 = top_mu(pop ++ offspring(pop), pop)
    champ = Enum.max(pop1)
    # trait = the champion's absolute value (escalates); co-fitness = the champion's
    # win-probability against its CURRENT contemporaries (its relative edge over the
    # field), which stays flat as the whole population escalates together -- the Red Queen.
    frame = %{gen: g, trait: champ, cofit: fitness(champ, pop1)}
    loop(gens, g + 1, pop1, [frame | acc])
  end

  defp offspring(pop), do: for(_ <- 1..@lambda, do: Enum.random(pop) + @sigma * :rand.normal())

  defp top_mu(cands, opp) do
    cands
    |> Enum.map(&{fitness(&1, opp), &1})
    |> Enum.sort_by(&elem(&1, 0), :desc)
    |> Enum.take(@mu)
    |> Enum.map(&elem(&1, 1))
  end

  defp fitness(x, opp), do: mean(for o <- opp, do: logistic((x - o) / @tau))

  defp logistic(z) when z > 30.0, do: 1.0
  defp logistic(z) when z < -30.0, do: 0.0
  defp logistic(z), do: 1.0 / (1.0 + :math.exp(-z))
  defp mean([]), do: 0.0
  defp mean(l), do: Enum.sum(l) / length(l)
end
