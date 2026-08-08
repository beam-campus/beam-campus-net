defmodule Dronex.WeighTheRadio do
  @moduledoc """
  What the ablation has actually measured, as opposed to how often it was sampled.

  ## Why this exists

  An island re-runs the same engagements with one channel silenced and publishes
  the difference in the raider's score. It republishes the SAME exercise until it
  runs the next one, and the board samples every 30 seconds, so one measurement
  arrives thirty to eighty times.

  The panel drew a dot per sample. Measured 2026-08-08: 240 samples per island,
  and between THREE and EIGHT distinct values behind them. A cloud that looks
  like a distribution was one exercise repeated, and the visual weight was
  manufactured by the sampling rate rather than by evidence.

  ## ⚠ CONSECUTIVE REPEATS ONLY, NEVER `Enum.uniq/1`

  The same delta genuinely measured twice is two measurements and must count
  twice. Only a repeat with nothing between it and its predecessor is the wire
  saying the same thing again. Deduplicating by value would silently discard real
  agreement, which is the one thing that could ever settle this.

  ## ⚠⚠ AND `n` IS THE HEADLINE

  The readings are multiples of about 25, because one engagement changing hands
  is a whole step. Three of them scattered across zero is noise wearing a chart's
  clothes. What would settle it is the same sign holding over many, so the count
  of distinct exercises belongs beside the number and not in a footnote.
  """

  @channels [{:air, "air silenced"}, {:ground, "ground silenced"}, {:all, "both silenced"}]

  @doc """
  Per channel: the distinct readings in the order they were measured, and what
  they add up to.

  `[%{channel, label, readings, n, mean, low, high, agree}]`. `agree` is the
  share of readings on the same side of zero as the mean, which is the only
  summary here worth reading before `n` is large.
  """
  @spec weigh([map()]) :: [map()]
  def weigh(samples) when is_list(samples) do
    ordered = Enum.sort_by(samples, & &1.at)

    for {key, label} <- @channels do
      ordered |> Enum.map(&Map.get(&1, key)) |> Enum.filter(&is_integer/1) |> summarise(key, label)
    end
  end

  defp summarise(values, key, label) do
    readings = distinct(values)
    built(readings, key, label)
  end

  defp built([], key, label),
    do: %{channel: key, label: label, readings: [], n: 0, mean: nil, low: nil, high: nil, agree: nil}

  defp built(readings, key, label) do
    mean = Enum.sum(readings) / length(readings)

    %{
      channel: key,
      label: label,
      readings: readings,
      n: length(readings),
      mean: Float.round(mean, 1),
      low: Enum.min(readings),
      high: Enum.max(readings),
      agree: agreement(readings, mean)
    }
  end

  # ⚠ CONSECUTIVE ONLY. `[25, 25, -25, 25]` is three measurements, not two: the
  # island really did measure 25 again after measuring -25.
  defp distinct(values) do
    values
    |> Enum.chunk_by(& &1)
    |> Enum.map(&hd/1)
  end

  # How much of the evidence points the same way as its own average. A channel
  # that matters sits off zero and STAYS there; noise scatters across it.
  defp agreement(_readings, mean) when mean == 0.0, do: 0

  defp agreement(readings, mean) do
    same = Enum.count(readings, &(&1 != 0 and &1 > 0 == mean > 0))
    round(same * 100 / length(readings))
  end

  @doc """
  What the panel is allowed to say, in one sentence.

  ⚠ IT REFUSES TO CONCLUDE ON A HANDFUL. The measure moves in steps of about 25,
  so one engagement changing hands is a whole step, and a claim off three
  readings would be this page inventing a result.
  """
  @spec reading(map()) :: binary()
  def reading(%{n: 0}), do: "not measured yet"
  def reading(%{n: n}) when n < 8, do: "#{n} exercises, too few to say"

  def reading(%{n: n, agree: agree, mean: mean}) when agree >= 75 and mean > 0,
    do: "#{n} exercises, #{agree}% say the swarm needs it"

  def reading(%{n: n, agree: agree, mean: mean}) when agree >= 75 and mean < 0,
    do: "#{n} exercises, #{agree}% say the swarm flies better silent"

  def reading(%{n: n, agree: agree}), do: "#{n} exercises, #{agree}% agree, so no lean yet"
end
