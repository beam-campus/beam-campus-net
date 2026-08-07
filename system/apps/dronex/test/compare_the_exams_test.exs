defmodule Dronex.CompareTheExamsTest do
  @moduledoc """
  The six numbers behind the one percentage, and the ways they must refuse to
  compare things that are not comparable.
  """
  use ExUnit.Case, async: false

  alias Dronex.CompareTheExams
  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  defp island(id, name, drills, wins, starts \\ 48) do
    Board.put(id, :vitals, %{
      "island_id" => id,
      "island" => name,
      "benchmark_rungs" => drills,
      "benchmark_wins" => wins,
      "benchmark_starts" => starts
    })

    Dronex.island(id)
  end

  test "a profile is a rate per drill, in the ladder's own order" do
    a = island("aaa", "beam00", ["hoverer", "chaser"], [48, 12])

    p = CompareTheExams.profiles([a])

    assert p.drills == ["hoverer", "chaser"]
    assert [%{island: "beam00", rates: [100, 25]}] = p.series
  end

  # ⚠ THE ORDER IS DIFFICULTY AND CARRIES THE WHOLE READING. Sorting these any
  # other way destroys the only thing the sequence says.
  test "the ladder keeps its order, not an alphabetical one" do
    a = island("aaa", "beam00", ["hoverer", "chaser", "evader"], [48, 12, 24])

    assert CompareTheExams.profiles([a]).drills == ["hoverer", "chaser", "evader"]
  end

  # ⚠⚠ ONLY THE DRILLS EVERY ISLAND SAT. Islands roll one at a time, so mid-deploy
  # one may publish a ladder the others have never seen, and a gap beside a score
  # reads as a failure.
  test "a drill only one island sat is left out of the comparison" do
    a = island("aaa", "beam00", ["hoverer", "chaser"], [48, 12])
    b = island("bbb", "beam01", ["hoverer", "chaser", "sniper"], [24, 6, 48])

    p = CompareTheExams.profiles([a, b])

    assert p.drills == ["hoverer", "chaser"]
    assert [%{rates: [100, 25]}, %{rates: [50, 12]}] = p.series
  end

  test "different start counts still compare, because a rate is not a count" do
    a = island("aaa", "beam00", ["hoverer"], [48], 48)
    b = island("bbb", "beam01", ["hoverer"], [4], 8)

    assert [%{rates: [100]}, %{rates: [50]}] = CompareTheExams.profiles([a, b]).series
  end

  test "an island that has not sat the exam is absent, not zero" do
    a = island("aaa", "beam00", ["hoverer"], [48])
    b = island("bbb", "beam01", [], [])

    assert [%{island: "beam00"}] = CompareTheExams.profiles([a, b]).series
  end

  # A ladder and a result list of different lengths is a pair nobody can align.
  test "a mismatched ladder and result list is refused" do
    a = island("aaa", "beam00", ["hoverer", "chaser"], [48])

    assert %{drills: [], series: []} = CompareTheExams.profiles([a])
  end

  test "nobody sitting it is an empty comparison rather than a crash" do
    assert %{drills: [], series: []} = CompareTheExams.profiles([])
  end
end
