defmodule Dronex.TimeTheFights do
  @moduledoc """
  How long raids last, and whether the answer is being cut off by the clock.

  ## What this is for

  Raid duration is the only published quantity that is a property of the
  ENGAGEMENT rather than of either side's bookkeeping. Everything else on the
  page counts what somebody did.

  It is not a measure of genome quality and this module will not pretend
  otherwise. A short raid is a crushing attacker or a suicidal one; a long raid
  is a stout defence or two swarms that never met. Duration alone measures
  DECISIVENESS. Conditioned on who won it starts to mean something, which is why
  the summary below is always split by outcome and the histogram never stands
  alone.

  ## ⚠ THE FIRST QUESTION IS WHETHER THE CLOCK IS CUTTING THE ANSWER OFF

  An engagement ends when one side is finished or when the tick cap is reached.
  A raid that hits the cap did not take that long; it took AT LEAST that long,
  and every average over a censored quantity is biased. Worse, the bias grows
  precisely as the two sides become evenly matched, which is what coevolution
  does, so the measure decays exactly as the thing it measures gets interesting.

  So before anybody reasons about durations, this reports how many raids are
  piled on the longest value seen. That pile IS the censoring.

  ## ⚠⚠ THE CAP IS NOT PUBLISHED, SO IT IS DISCOVERED RATHER THAN ASSUMED

  `airspace:limits/0` knows `max_ticks`, and `dronex_bout:encode/4` ships
  `arena` and `ground_range` out of that map and not the cap. Hardcoding 1200
  here would put a world constant in a second repository on a different release
  cadence, which `CHARTER.md` rule 2 forbids by name after a sibling spent two
  hours in a boot-crash loop over exactly that.

  What can be done without knowing the cap is better anyway: report the longest
  duration observed and how many raids share that exact value. A spike on one
  precise number is the cap revealing itself, as a measurement rather than as an
  assumption. If it is ever published, this reads it instead.

  ## ⚠⚠⚠ AND THE UNIT IS TICKS, NOT SECONDS

  The island does not publish its tick rate either, so converting to seconds here
  would be inventing the second source of truth this module just refused to
  create. Ticks are what arrive; ticks are what is drawn.
  """

  # Ticks per bin. A round number rather than a computed one, so the axis does
  # not change shape every time a raid arrives.
  @bin 100

  @outcomes [{"attacker", "raider won"}, {"draw", "drawn"}, {"defender", "island held"}]

  @doc """
  The distribution of settled raid durations.

  `at_longest` is the count sharing the longest value seen, which is what a
  reader must look at before believing anything else here.
  """
  @spec distribution([map()]) :: map()
  def distribution(raids) when is_list(raids) do
    raids |> Enum.flat_map(&timed/1) |> summarised()
  end

  # A raid with no recording has not finished, so it has no duration. That is
  # different from a duration of zero and must not be counted as one.
  defp timed(%{parts: %{raid: [fact | _]}}), do: from(fact)
  defp timed(_unsettled), do: []

  defp from(fact) do
    kept(Map.get(fact, "ticks"), Map.get(fact, "winner"))
  end

  defp kept(ticks, winner) when is_integer(ticks) and ticks > 0,
    do: [%{ticks: ticks, winner: winner}]

  defp kept(_absent, _winner), do: []

  defp summarised([]) do
    %{n: 0, bins: [], longest: nil, at_longest: 0, bin: @bin, by_outcome: [], series: []}
  end

  defp summarised(points) do
    longest = points |> Enum.map(& &1.ticks) |> Enum.max()

    %{
      n: length(points),
      bins: binned(points, longest),
      longest: longest,
      at_longest: Enum.count(points, &(&1.ticks == longest)),
      bin: @bin,
      by_outcome: by_outcome(points, longest),
      series: series(points, longest)
    }
  end

  @doc """
  One series per outcome, counts per bin, ready to stack.

  ⚠ STACKED BY WHO WON RATHER THAN ONE FLAT BAR, because duration on its own
  cannot say who was better and a single-colour histogram invites exactly that
  reading. A short bar made of "raider won" and a short bar made of "island held"
  are opposite findings.

  Only outcomes that actually occurred get a series. An outcome nobody achieved
  is absent rather than a row of zeroes, which would put a dead entry in the
  legend and spend one of three categorical hues on nothing.
  """
  @spec series([map()], pos_integer()) :: [map()]
  def series(points, longest) do
    slots = 0..div(longest, @bin)

    for {key, label} <- @outcomes,
        side = Enum.filter(points, &(&1.winner == key)),
        side != [] do
      counts = Enum.frequencies_by(side, &div(&1.ticks, @bin))
      %{name: label, data: Enum.map(slots, &Map.get(counts, &1, 0))}
    end
  end

  # Every bin from zero to the longest, including the empty ones, because a gap
  # in a distribution is a fact about it and a histogram that omits its empty
  # bins draws a different shape.
  defp binned(points, longest) do
    counts = Enum.frequencies_by(points, &div(&1.ticks, @bin))

    for slot <- 0..div(longest, @bin) do
      %{from: slot * @bin, to: (slot + 1) * @bin - 1, count: Map.get(counts, slot, 0)}
    end
  end

  defp by_outcome(points, longest) do
    for {key, label} <- @outcomes, side = Enum.filter(points, &(&1.winner == key)), side != [] do
      %{
        outcome: label,
        n: length(side),
        median: median(Enum.map(side, & &1.ticks)),
        at_longest: Enum.count(side, &(&1.ticks == longest))
      }
    end
  end

  # ⚠ THE MEDIAN, AND IT IS STILL NOT SAFE IF THE PILE AT THE TOP IS LARGE. A
  # median survives censoring only while fewer than half the samples are censored.
  # Past that it is undefined and this returns the longest value, which is a floor
  # rather than an estimate. `at_longest` is what says which case a reader is in.
  defp median([]), do: nil

  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)
    at(sorted, middle, rem(length(sorted), 2))
  end

  defp at(sorted, middle, 1), do: Enum.at(sorted, middle)
  defp at(sorted, middle, 0), do: div(Enum.at(sorted, middle - 1) + Enum.at(sorted, middle), 2)
end
