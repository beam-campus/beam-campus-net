defmodule Dronex.CountTheCapturesTest do
  @moduledoc """
  A rate, where a running total drew a flat line whatever the fleet did.
  """
  use ExUnit.Case, async: false

  alias Dronex.CountTheCaptures
  alias Dronex.WatchBouts.Board

  @bin 600_000

  setup do
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  # ⚠ `Board.put/3` WRITES A SAMPLE OF ITS OWN, with `captures` defaulting to
  # zero, so seeding a row and then adding samples leaves a phantom point that
  # invents a delta. The history is cleared between the two.
  defp island(id, name, points) do
    Board.put(id, :vitals, %{"island_id" => id, "island" => name})
    :ets.delete(:dronex_history, id)
    Board.remember_samples(id, Enum.map(points, fn {at, c} -> %{at: at, captures: c} end))
    Dronex.island(id)
  end

  test "a rate is the difference between samples, summed into bins" do
    a = island("aaa", "beam00", [{0, 100}, {1000, 104}, {@bin, 110}])

    r = CountTheCaptures.rate([a], @bin)

    assert r.bins == [0, @bin]
    assert [%{island: "beam00", data: [4, 6]}] = r.series
  end

  # ⚠ A COUNTER THAT WENT DOWN IS A RESTART, NOT A NEGATIVE CAPTURE. A clamped
  # zero would say "took nothing", which is a claim about the fleet; what
  # happened is that the measurement broke.
  test "a counter that falls is dropped, not clamped to zero" do
    a = island("aaa", "beam00", [{0, 100}, {1000, 40}])

    assert %{bins: [], series: []} = CountTheCaptures.rate([a], @bin)
  end

  # ⚠⚠ A GAP IS NOT A ZERO. A bin an island has no samples for must draw blank,
  # because a bar of height nought claims a measurement nobody made.
  test "a bin an island has no samples for is nil, not zero" do
    a = island("aaa", "beam00", [{0, 100}, {1000, 105}])
    b = island("bbb", "beam01", [{@bin, 10}, {@bin + 1000, 13}])

    r = CountTheCaptures.rate([a, b], @bin)

    assert r.bins == [0, @bin]
    assert [%{data: [5, nil]}, %{data: [nil, 3]}] = r.series
  end

  test "an island with one sample has no rate yet" do
    a = island("aaa", "beam00", [{0, 100}])

    assert %{bins: [], series: []} = CountTheCaptures.rate([a], @bin)
  end

  test "nothing sampled is an empty panel rather than a crash" do
    assert %{bins: [], series: []} = CountTheCaptures.rate([], @bin)
  end

  # Bins are shared across islands so the heights compare, which is the whole
  # point of drawing them together.
  test "every island is drawn over the same bins" do
    a = island("aaa", "beam00", [{0, 100}, {1000, 102}])
    b = island("bbb", "beam01", [{0, 10}, {1000, 19}])

    r = CountTheCaptures.rate([a, b], @bin)

    assert Enum.all?(r.series, &(length(&1.data) == length(r.bins)))
    assert [%{data: [2]}, %{data: [9]}] = r.series
  end
end
