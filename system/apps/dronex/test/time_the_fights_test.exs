defmodule Dronex.TimeTheFightsTest do
  @moduledoc """
  How long fights last, and the censoring that decides whether the answer means
  anything.
  """
  use ExUnit.Case, async: true

  alias Dronex.TimeTheFights, as: Time

  defp raid(ticks, winner) do
    %{id: "r", parts: %{raid: [%{"ticks" => ticks, "winner" => winner}]}}
  end

  test "durations land in bins of a hundred ticks" do
    d = Time.distribution([raid(50, "attacker"), raid(150, "attacker"), raid(160, "defender")])

    assert d.n == 3
    assert %{from: 0, to: 99, count: 1} = Enum.at(d.bins, 0)
    assert %{from: 100, to: 199, count: 2} = Enum.at(d.bins, 1)
  end

  # ⚠ AN EMPTY BIN IS A FACT ABOUT THE SHAPE. A histogram that omits its gaps
  # draws a different distribution from the one it was given.
  test "the empty bins between are kept" do
    d = Time.distribution([raid(50, "attacker"), raid(350, "attacker")])

    assert length(d.bins) == 4
    assert Enum.map(d.bins, & &1.count) == [1, 0, 0, 1]
  end

  # ⚠⚠ THE WHOLE REASON THIS MODULE EXISTS. A pile of raids on one exact value is
  # the cap revealing itself, and it is discovered rather than assumed because the
  # island does not publish `max_ticks'.
  test "raids piled on the longest value are counted, because that pile is the cap" do
    d = Time.distribution([raid(1200, "draw"), raid(1200, "draw"), raid(300, "attacker")])

    assert d.longest == 1200
    assert d.at_longest == 2
  end

  test "one raid at the longest value is a maximum, not yet a cap" do
    d = Time.distribution([raid(300, "attacker"), raid(900, "defender")])

    assert d.longest == 900
    assert d.at_longest == 1
  end

  # Duration alone cannot say who was better, so it is never reported alone.
  test "the summary splits by who won" do
    d =
      Time.distribution([
        raid(100, "attacker"),
        raid(300, "attacker"),
        raid(900, "defender"),
        raid(1200, "draw")
      ])

    assert [raider, drawn, held] = d.by_outcome
    assert %{outcome: "raider won", n: 2, median: 200} = raider
    assert %{outcome: "drawn", n: 1} = drawn
    assert %{outcome: "island held", n: 1, median: 900} = held
  end

  test "an outcome nobody achieved is left out rather than shown as zero" do
    d = Time.distribution([raid(100, "attacker")])

    assert Enum.map(d.by_outcome, & &1.outcome) == ["raider won"]
  end

  # A raid still in flight has no duration. That is not a duration of zero.
  test "an unsettled raid is not a fight of length nothing" do
    unsettled = %{id: "r", parts: %{committed: [%{"role" => "attacker"}]}}

    assert Time.distribution([unsettled]).n == 0
  end

  test "a recording with no tick count is skipped rather than counted as zero" do
    assert Time.distribution([%{id: "r", parts: %{raid: [%{"winner" => "draw"}]}}]).n == 0
    assert Time.distribution([raid(0, "draw")]).n == 0
  end

  # A scale with no data is not a scale of zero.
  test "nothing timed reports nothing" do
    d = Time.distribution([])

    assert d.n == 0
    assert d.longest == nil
    assert d.bins == []
  end

  # ⚠ STACKED BY WHO WON. A short bar made of "raider won" and a short bar made of
  # "island held" are opposite findings, and one flat colour hides that.
  test "each outcome is its own series over the same bins" do
    d =
      Time.distribution([
        raid(50, "attacker"),
        raid(150, "attacker"),
        raid(150, "defender")
      ])

    assert [%{name: "raider won", data: [1, 1]}, %{name: "island held", data: [0, 1]}] = d.series
  end

  test "an outcome nobody achieved gets no series rather than a row of zeroes" do
    d = Time.distribution([raid(50, "attacker")])

    assert Enum.map(d.series, & &1.name) == ["raider won"]
  end

  test "nothing timed has no series" do
    assert Time.distribution([]).series == []
  end

  test "an even count takes the midpoint of the two middle values" do
    d = Time.distribution([raid(100, "attacker"), raid(200, "attacker")])

    assert [%{median: 150}] = d.by_outcome
  end
end
