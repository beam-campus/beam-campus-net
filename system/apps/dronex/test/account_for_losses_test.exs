defmodule Dronex.AccountForLossesTest do
  @moduledoc """
  The arithmetic that separates a weapon from a ram, checked against the exact
  constants the island publishes with.
  """
  use ExUnit.Case, async: true

  alias Dronex.AccountForLosses

  # One frame, as it arrives: drones flat at stride 7
  # [id, x, y, z, yaw, health_percent, state].
  defp frame(drones, munitions \\ []) do
    %{
      "t" => 0,
      "d" => Enum.flat_map(drones, fn {id, hp, state} -> [id, 0, 0, 0, 0, hp, state] end),
      "m" => Enum.flat_map(munitions, fn guided -> [0, 0, 0, 0, guided] end),
      "k" => []
    }
  end

  # ⚠ THE WHOLE METHOD IN ONE ASSERTION. HIT_DAMAGE is 2500 of a START_HEALTH of
  # 10000, published as `H * 100 div 10000`, so a weapon hit is always exactly 25
  # points. If the island ever changes that constant to something that is not a
  # multiple of 100, this test fails and the analysis it guards becomes a guess.
  test "a weapon hit is exactly a quarter, and is read as weapon damage" do
    a = AccountForLosses.account([frame([{0, 100, 0}]), frame([{0, 75, 0}])])

    assert a.quantised == 25
    assert a.unquantised == 0
    assert a.weapon_share == 100
  end

  test "an interceptor is exactly a half" do
    a = AccountForLosses.account([frame([{0, 100, 0}]), frame([{0, 50, 0}])])

    assert a.quantised == 50
    assert a.unquantised == 0
  end

  # ⚠ THE QUANTUM SURVIVES FRACTIONAL HEALTH, which is what makes this work at
  # all. A drone rammed down to 93.7% and then shot still shows a drop of exactly
  # 25, because 2500 is a multiple of 100 and the floor divides identically.
  test "a weapon hit reads as 25 even after a collision left odd health" do
    a = AccountForLosses.account([frame([{0, 93, 0}]), frame([{0, 68, 0}])])

    assert a.quantised == 25
    assert a.unquantised == 0
  end

  # A ram is START_HEALTH * closing_speed div KILL_SPEED — continuous, and lands
  # on a multiple of 25 only by coincidence.
  test "a collision leaves a remainder that cannot be a weapon" do
    a = AccountForLosses.account([frame([{0, 100, 0}]), frame([{0, 88, 0}])])

    assert a.quantised == 0
    assert a.unquantised == 12
    assert a.other_share == 100
  end

  # ⚠ A DROP IS SPLIT AND NOT LABELLED. Thirty points is a weapon hit AND five
  # points of something else; calling the event either name throws away the half
  # that is certain.
  test "a mixed drop is decomposed rather than bucketed" do
    a = AccountForLosses.account([frame([{0, 100, 0}]), frame([{0, 70, 0}])])

    assert a.quantised == 25
    assert a.unquantised == 5
    assert a.total == 30
  end

  test "healing and unchanged health are not damage" do
    a = AccountForLosses.account([frame([{0, 50, 0}]), frame([{0, 50, 0}])])

    assert a.total == 0
    # ⚠ NIL, NOT ZERO. No damage is a question with no answer, and a zeroed bar
    # would answer it anyway.
    assert a.weapon_share == nil
  end

  test "deaths are counted from the last frame, including one in it" do
    a =
      AccountForLosses.account([
        frame([{0, 100, 0}, {1, 100, 0}]),
        frame([{0, 0, 2}, {1, 100, 1}])
      ])

    # State 2 is dead; state 1 is WITHDRAWN, which is alive and out of the fight.
    assert a.deaths == 1
  end

  test "several drones are accounted independently" do
    a =
      AccountForLosses.account([
        frame([{0, 100, 0}, {1, 100, 0}]),
        frame([{0, 75, 0}, {1, 91, 0}])
      ])

    assert a.quantised == 25
    assert a.unquantised == 9
    assert a.drops == 2
  end

  test "an empty or single-frame recording accounts to nothing rather than crashing" do
    assert AccountForLosses.account([]).total == 0
    assert AccountForLosses.account([frame([{0, 100, 0}])]).total == 0
  end
end
