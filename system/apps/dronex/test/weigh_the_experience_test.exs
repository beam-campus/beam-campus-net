defmodule Dronex.WeighTheExperienceTest do
  @moduledoc """
  Does breeding longer win wars. The join between the exam and the raids, and the
  exclusions that keep it honest while the fleet is mid-roll.
  """
  use ExUnit.Case, async: true

  alias Dronex.WeighTheExperience, as: Weigh

  defp raid(opts) do
    rec =
      case opts[:winner] do
        nil -> nil
        w -> [%{"winner" => w, "rounds" => opts[:defender_rec] || 0}]
      end

    commits =
      [
        opts[:attacker] && %{"role" => "attacker", "rounds" => opts[:attacker]},
        opts[:defender] && %{"role" => "defender", "rounds" => opts[:defender]}
      ]
      |> Enum.reject(&is_nil/1)

    %{id: "r", parts: Enum.reject(%{raid: rec, committed: commits}, fn {_k, v} -> v in [nil, []] end) |> Map.new()}
  end

  test "the gap is the attacker's rounds less the defender's" do
    r = Weigh.gaps([raid(winner: "attacker", attacker: 9000, defender: 8000)])

    assert [%{gap: 1000, winner: "attacker"}] = r.points
  end

  test "a raider with less breeding shows a negative gap" do
    r = Weigh.gaps([raid(winner: "defender", attacker: 7000, defender: 8000)])

    assert [%{gap: -1000, winner: "defender"}] = r.points
  end

  # ⚠ THE DEFENDER PUBLISHES TWICE and either may be from the older image, so
  # taking whichever carries a stamp keeps raids a stricter reading would drop.
  test "the defender's rounds come from the recording when its commitment lacks them" do
    r = Weigh.gaps([raid(winner: "attacker", attacker: 9000, defender_rec: 8500)])

    assert [%{gap: 500}] = r.points
  end

  # ⚠ AN UNSTAMPED RAID IS EXCLUDED, NEVER TREATED AS ZERO. A zero read as a
  # reading would put a gap of the attacker's entire breeding history on the plot.
  test "a raid with one side unstamped is excluded and counted" do
    r = Weigh.gaps([raid(winner: "attacker", attacker: 9000)])

    assert r.points == []
    assert r.excluded.unstamped == 1
  end

  test "a raid with neither side stamped is excluded" do
    r = Weigh.gaps([raid(winner: "defender")])

    assert r.points == []
    assert r.excluded.unstamped == 1
  end

  # A raid still out has no outcome to plot, which is different from a missing
  # stamp and must not be counted as one.
  test "a raid with no recording is unsettled, not unstamped" do
    r = Weigh.gaps([raid(attacker: 9000, defender: 8000)])

    assert r.points == []
    assert r.excluded.unsettled == 1
    assert r.excluded.unstamped == 0
  end

  # ⚠ ZERO IS AN OLDER ISLAND, NOT A ROSTER THAT NEVER BRED. An island that has
  # genuinely run no rounds has also never fielded a raiding party.
  test "a published zero is treated as absent" do
    r = Weigh.gaps([raid(winner: "attacker", attacker: 0, defender: 8000)])

    assert r.points == []
    assert r.excluded.unstamped == 1
  end

  test "the lanes separate a draw from either win" do
    points = [
      %{gap: 1, winner: "attacker"},
      %{gap: 2, winner: "draw"},
      %{gap: 3, winner: "defender"}
    ]

    assert [{"raider won", [%{gap: 1}]}, {"drawn", [%{gap: 2}]}, {"island held", [%{gap: 3}]}] =
             Weigh.lanes(points)
  end

  test "nothing to weigh reports nothing rather than crashing" do
    assert Weigh.gaps([]) == %{points: [], excluded: %{unsettled: 0, unstamped: 0}}
  end
end
