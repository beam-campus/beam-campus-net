defmodule Dronex.TraceTheExamTest do
  @moduledoc """
  The decomposition that `REGISTER D.15` needs, and the ways it must refuse to
  claim more than it has.
  """
  use ExUnit.Case, async: true

  alias Dronex.TraceTheExam

  defp sample(at, rungs, starts \\ 48), do: %{at: at, rungs: rungs, starts: starts}

  # Newest first, as the board keeps them.
  defp history(list), do: Enum.reverse(list)

  test "a rung by time grid, oldest column first" do
    g = TraceTheExam.grid(history([sample(1, [48, 24]), sample(2, [24, 12])]))

    assert g.rungs == 2
    assert g.columns == [1, 2]
    assert %{x: 0, y: 0, rate: 100} = Enum.find(g.cells, &(&1.x == 0 and &1.y == 0))
    assert %{rate: 50} = Enum.find(g.cells, &(&1.x == 0 and &1.y == 1))
    assert %{rate: 25} = Enum.find(g.cells, &(&1.x == 1 and &1.y == 1))
  end

  # ⚠ RATES, NEVER RAW WINS. An island that sits each rung 48 times and one that
  # sits it 8 are not comparable in wins, and the grid puts them side by side.
  test "a rung is a rate, so different start counts compare" do
    g = TraceTheExam.grid(history([sample(1, [24], 48), sample(2, [4], 8)]))

    assert [%{rate: 50}, %{rate: 50}] = Enum.sort_by(g.cells, & &1.x)
  end

  # ⚠⚠ A SAMPLE IS NOT A RE-SIT. The exam re-sits minutes apart and the board
  # samples every 30 seconds, so most columns repeat the previous measurement. A
  # wall of identical columns is ONE exam, not a stable island.
  test "repeated samples of one result count as one distinct result" do
    g = TraceTheExam.grid(history([sample(1, [48]), sample(2, [48]), sample(3, [48])]))

    assert length(g.columns) == 3
    assert g.sat == 1
  end

  test "a changed result is a second distinct one" do
    g = TraceTheExam.grid(history([sample(1, [48]), sample(2, [48]), sample(3, [12])]))

    assert g.sat == 2
  end

  # Every sample written before 2026-08-07 has no vector. That is absent, not a
  # row of zeroes, and a zeroed row would read as an island that lost everything.
  test "samples with no vector are left out rather than drawn as failure" do
    g = TraceTheExam.grid(history([%{at: 1, rungs: [], starts: 48}, sample(2, [48])]))

    assert length(g.columns) == 1
    assert g.rungs == 1
  end

  test "an island that has not sat the exam has no grid" do
    assert %{rungs: 0, cells: [], sat: 0} = TraceTheExam.grid([%{at: 1, rungs: [24], starts: 0}])
    assert %{rungs: 0, cells: []} = TraceTheExam.grid([])
  end

  # ⚠⚠⚠ IT DESCRIBES AND NEVER CONCLUDES. D.15 is open, and a caption naming a
  # cause would be the page settling an open question off two columns.
  test "one result says nothing at all" do
    assert TraceTheExam.reading(TraceTheExam.grid(history([sample(1, [48])]))) == nil
  end

  test "an uneven ladder is described as uneven, without a cause" do
    g = TraceTheExam.grid(history([sample(1, [48, 48]), sample(2, [48, 4])]))
    said = TraceTheExam.reading(g)

    assert said =~ "uneven"
    assert said =~ "2 distinct results"
    refute said =~ "because"
  end

  test "a level ladder is described as level" do
    g = TraceTheExam.grid(history([sample(1, [48, 48]), sample(2, [46, 44])]))

    assert TraceTheExam.reading(g) =~ "level"
  end
end
