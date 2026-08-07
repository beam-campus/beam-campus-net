defmodule Dronex.TraceTheExam do
  @moduledoc """
  Which drills moved, when the exam score moved.

  ## Why this exists

  The frozen exam is a LADDER. An island publishes `benchmark_wins` as one entry
  per rung, and `Board.exam_score/1` collapses that vector into a single
  percentage. The leaderboard ranks on the percentage and the trend chart draws
  the percentage, so the page has only ever been able to say THAT a score moved.

  `REGISTER D.15` is the standing anomaly: an island's exam score swings by up to
  a hundred points in a day, and `benchmark_sitter` says the champion was bred
  locally every time, which killed the obvious explanation that it had captured a
  foreign genome. Nobody knows why.

  The decomposition that could tell one kind of swing from another was thrown
  away every thirty seconds. It is kept now, and this draws it.

  ## ⚠ WHAT A READER CAN ANSWER WITH THIS THAT THEY COULD NOT BEFORE

  A vertical stripe, every rung changing at once, is a changed sitter or a
  changed harness. Erosion from the top of the ladder down is a skill genuinely
  lost. A recovery that returns on DIFFERENT rungs from the ones that fell is a
  different animal wearing the same score. Three different diagnoses, all
  invisible in a single percentage.

  ## ⚠⚠ RATES, NEVER RAW WINS

  Every rung is sat `starts` times and `starts` is not constant across islands or
  across time. Drawing raw wins would compare an island that sat each rung 48
  times against one that sat it 8, and call the first one better.

  ## ⚠⚠⚠ AND A SAMPLE IS NOT A RE-SIT

  The exam re-sits on its own timer, minutes apart; the board samples every 30
  seconds. So the same result is republished many times over, and consecutive
  columns are usually the SAME measurement rather than a trend. That is why this
  reports `sat`, the number of distinct results behind the picture. A wall of
  identical columns is one exam, not a stable island.
  """

  @doc """
  Samples turned into a rung-by-time grid, oldest first.

  Returns `%{rungs: n, columns: [...], cells: [...], sat: n}` where a cell is
  `%{x: column, y: rung, rate: 0..100}`. Empty when nothing carries a vector,
  which is every sample written before 2026-08-07.
  """
  @spec grid([map()]) :: map()
  def grid(samples) when is_list(samples) do
    samples
    |> Enum.filter(&measured?/1)
    |> Enum.reverse()
    |> built()
  end

  # A sample from before the vector was kept, or from an island that has not sat
  # the exam, carries no rungs. That is absent, not a row of zeroes.
  defp measured?(%{rungs: rungs, starts: starts}) when is_list(rungs) and starts > 0,
    do: rungs != []

  defp measured?(_older), do: false

  defp built([]), do: %{rungs: 0, columns: [], cells: [], sat: 0}

  defp built(samples) do
    rungs = samples |> Enum.map(&length(&1.rungs)) |> Enum.max()

    %{
      rungs: rungs,
      columns: Enum.map(samples, & &1.at),
      cells: cells(samples),
      sat: samples |> Enum.map(& &1.rungs) |> Enum.uniq() |> length()
    }
  end

  defp cells(samples) do
    for {sample, x} <- Enum.with_index(samples),
        {wins, y} <- Enum.with_index(sample.rungs) do
      %{x: x, y: y, rate: rate(wins, sample.starts)}
    end
  end

  defp rate(_wins, starts) when starts <= 0, do: 0
  defp rate(wins, starts), do: min(100, div(wins * 100, starts))

  @doc """
  What the shape says, in one sentence, or nil when it cannot say anything yet.

  ⚠ IT DESCRIBES AND NEVER CONCLUDES. `D.15` is open, and a caption that named a
  cause would be this page deciding an open question on two columns of data.
  """
  @spec reading(map()) :: binary() | nil
  def reading(%{sat: sat}) when sat < 2, do: nil

  def reading(%{cells: cells, rungs: rungs, sat: sat}) do
    spread = spread_of(cells, rungs)
    "#{sat} distinct results. #{spread}"
  end

  def reading(_absent), do: nil

  # The gap between the easiest rung and the hardest, on the newest column: a
  # ladder that is flat and a ladder with a cliff are different animals at the
  # same score.
  defp spread_of(cells, rungs) do
    last = cells |> Enum.map(& &1.x) |> Enum.max(fn -> 0 end)
    newest = for c <- cells, c.x == last, do: c.rate

    described(Enum.min(newest, fn -> 0 end), Enum.max(newest, fn -> 0 end), rungs)
  end

  defp described(low, high, rungs) when high - low >= 25,
    do: "Across #{rungs} drills the newest profile runs #{low}% to #{high}%, so the ladder is uneven."

  defp described(low, high, rungs),
    do: "Across #{rungs} drills the newest profile runs #{low}% to #{high}%, so the ladder is level."
end
