defmodule Dronex.ReadTheLedgerTest do
  @moduledoc """
  The matrix that replaced the map: who raided whom, from the same facts the
  arcs were drawn from, minus the invented geography.
  """
  use ExUnit.Case, async: true

  alias Dronex.ReadTheLedger

  defp settled(attacker, defender, winner) do
    %{
      id: "r",
      parts: %{
        raid: [%{"attacker_id" => attacker, "island_id" => defender, "winner" => winner}]
      }
    }
  end

  defp committed(role, mine, theirs) do
    %{id: "r", parts: %{committed: [%{"role" => role, "island_id" => mine, "opponent_id" => theirs}]}}
  end

  test "a settled raid lands in the attacker's row and the defender's column" do
    p = ReadTheLedger.pairs([settled("a", "d", "attacker")])

    assert p[{"a", "d"}] == %{raids: 1, wins: 1, losses: 0, in_flight: 0}
    assert p[{"d", "a"}] == nil
  end

  # ⚠ WINS ARE THE ROW'S, ALWAYS. A table whose two axes mean different things is
  # a table nobody can read, so the row is the attacker and the record is its own.
  test "a defender win is a loss in the attacker's cell, not a win in another" do
    p = ReadTheLedger.pairs([settled("a", "d", "defender")])

    assert p[{"a", "d"}] == %{raids: 1, wins: 0, losses: 1, in_flight: 0}
  end

  test "the two directions of one pair are separate cells" do
    p =
      ReadTheLedger.pairs([
        settled("a", "d", "attacker"),
        settled("d", "a", "attacker")
      ])

    assert p[{"a", "d"}].wins == 1
    assert p[{"d", "a"}].wins == 1
  end

  # ⚠ THE ARCHIPELAGO TOTAL HIDES THE DIRECTION. 30–34 over the whole fleet reads
  # as a coin flip; per pair it can be lopsided, and that is the finding the map
  # could never show.
  test "a lopsided pair survives a balanced total" do
    raids =
      List.duplicate(settled("a", "d", "attacker"), 3) ++
        List.duplicate(settled("d", "a", "attacker"), 3)

    p = ReadTheLedger.pairs(raids)

    assert p[{"a", "d"}] == %{raids: 3, wins: 3, losses: 0, in_flight: 0}
    assert p[{"d", "a"}] == %{raids: 3, wins: 3, losses: 0, in_flight: 0}
  end

  # ⚠ A RAID IN FLIGHT IS NOT A RAID THAT DID NOT HAPPEN. Counting it as zero
  # would quietly write off every fight in progress.
  test "a commitment with no recording counts as in flight, not as a raid" do
    p = ReadTheLedger.pairs([committed("attacker", "a", "d")])

    assert p[{"a", "d"}] == %{raids: 0, wins: 0, losses: 0, in_flight: 1}
  end

  # Both sides emit a commitment, so the pair must resolve the same way from
  # either end — otherwise a defender-only commitment lands transposed.
  test "a defender's commitment names the same ordered pair" do
    p = ReadTheLedger.pairs([committed("defender", "d", "a")])

    assert p[{"a", "d"}].in_flight == 1
  end

  test "a draw costs both sides and is neither's win" do
    p = ReadTheLedger.pairs([settled("a", "d", "draw")])

    assert p[{"a", "d"}] == %{raids: 1, wins: 0, losses: 0, in_flight: 0}
  end

  test "an island never raids itself, however the facts arrive" do
    assert ReadTheLedger.pairs([settled("a", "a", "attacker")]) == %{}
  end

  test "a raid missing either side is dropped rather than half-counted" do
    assert ReadTheLedger.pairs([settled(nil, "d", "attacker")]) == %{}
    assert ReadTheLedger.pairs([%{id: "r", parts: %{}}]) == %{}
  end

  #============================================================================
  # Which way a pair leans, which is what the grid is for
  #============================================================================

  defp cell(wins, losses), do: %{raids: wins + losses, wins: wins, losses: losses, in_flight: 0}

  # ⚠ ONE RAID WON IS 100% AND MUST NOT BE PAINTED LIKE IT. Below three decided
  # raids the cell claims nothing and its numbers speak for themselves.
  test "a pair with too few decided raids claims no direction" do
    assert ReadTheLedger.lean(cell(1, 0)) == :thin
    assert ReadTheLedger.lean(cell(2, 0)) == :thin
    assert ReadTheLedger.lean(nil) == :thin
  end

  test "three decided raids is enough to lean" do
    assert {:attacker, _} = ReadTheLedger.lean(cell(3, 0))
  end

  # ⚠⚠ EVEN IS NOT THIN. A pair that fought ten times to a standstill has told
  # you something; one that fought once has not, and both drawn blank says the
  # same thing about both.
  test "a measured standstill is even, not absent" do
    assert ReadTheLedger.lean(cell(5, 5)) == :even
  end

  test "the row island prevailing leans to the attacker, and the reverse to the defender" do
    assert {:attacker, 5} = ReadTheLedger.lean(cell(4, 0))
    assert {:defender, 5} = ReadTheLedger.lean(cell(0, 4))
  end

  # Never zero: a pair that is not even must not render as though it were.
  test "a weak lean is still a lean" do
    assert {:attacker, n} = ReadTheLedger.lean(cell(3, 2))
    assert n >= 1
  end

  test "the further from a coin flip, the stronger the step" do
    {:attacker, weak} = ReadTheLedger.lean(cell(3, 2))
    {:attacker, strong} = ReadTheLedger.lean(cell(5, 0))

    assert strong > weak
  end

  # A draw says neither side prevailed, which is not evidence about which would.
  test "draws are excluded from the direction rather than counted as half" do
    assert ReadTheLedger.lean(%{raids: 9, wins: 4, losses: 4, in_flight: 0}) == :even
  end

  # A scale with no data is not a scale of zero.
  test "the busiest route is nil when nothing has been fought" do
    assert ReadTheLedger.busiest(%{}) == nil
    assert ReadTheLedger.busiest(ReadTheLedger.pairs([committed("attacker", "a", "d")])) == nil
    assert ReadTheLedger.busiest(ReadTheLedger.pairs([settled("a", "d", "attacker")])) == 1
  end
end
