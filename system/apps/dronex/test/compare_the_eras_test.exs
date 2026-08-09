defmodule Dronex.CompareTheErasTest do
  @moduledoc """
  The master tournament pooled across the fleet, and the states it must keep
  apart.

  The reading this slice serves is one shape judgement: a level profile across
  ages is progress, and a profile falling away to the right is a treadmill. Every
  test here defends something that would make those two look alike.
  """
  use ExUnit.Case, async: false

  alias Dronex.CompareTheEras
  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  defp island(id, name, fields) do
    Board.put(id, :vitals, Map.merge(%{"island_id" => id, "island" => name}, fields))
    Dronex.island(id)
  end

  defp sat(id, name, eras, wins, draws, losses, extra \\ %{}) do
    island(
      id,
      name,
      Map.merge(
        %{
          "master_eras" => eras,
          "master_wins" => wins,
          "master_draws" => draws,
          "master_losses" => losses,
          "master_flown" => Enum.sum(wins) + Enum.sum(draws) + Enum.sum(losses),
          "master_archived" => 40
        },
        extra
      )
    )
  end

  # An island on fact version 6. No master key at all.
  defp older(id, name), do: island(id, name, %{"rounds" => 12})

  # A well-formed publication, so a test can break exactly one field of it.
  defp published(id, fields) do
    island(
      id,
      "beam00",
      Map.merge(
        %{
          "master_eras" => [3],
          "master_wins" => [2],
          "master_draws" => [0],
          "master_losses" => [0],
          "master_flown" => 2,
          "master_archived" => 9
        },
        fields
      )
    )
  end

  describe "the five bands" do
    test "an era lands in the band its age belongs to" do
      # An era is now the log2 of an age in SECONDS, measured rather than assumed:
      # the fleet's tick turned out to be about six seconds and to differ between
      # islands, so ticks could not be compared across the mesh at all.
      # 5 -> under 4 min, 9 -> 4 to 34 min, 12 -> 34 min to 5 h, 15 -> 5 to 36 h,
      # 20 -> over 36 hours. One engagement each, all won, so only placement moves.
      a =
        sat("aaa", "beam00", [5, 9, 12, 15, 20], [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [
          0,
          0,
          0,
          0,
          0
        ])

      r = CompareTheEras.fleet([a])

      assert r.n == [1, 1, 1, 1, 1]
      assert r.measured == 5
    end

    # ⚠ ALL FIVE, ALWAYS. An empty right-hand column is the finding "we hold
    # nothing that old"; a column that vanishes says nothing at all.
    test "all five bands come back even when one is measured" do
      a = sat("aaa", "beam00", [3], [2], [0], [0])

      r = CompareTheEras.fleet([a])

      assert length(r.bands) == 5
      assert length(r.won) == 5
      assert r.won == [100, nil, nil, nil, nil]
      assert r.measured == 1
    end

    test "eras above the last edge all pool into the oldest band" do
      a = sat("aaa", "beam00", [19, 21, 24], [1, 1, 0], [0, 0, 0], [0, 0, 2])

      r = CompareTheEras.fleet([a])

      assert r.n == [nil, nil, nil, nil, 4]
      assert r.won == [nil, nil, nil, nil, 50]
      assert r.oldest == "over 36 hours"
    end
  end

  describe "pooling" do
    # ⚠⚠ AN INTERSECTION, AND THIS TEST ASSERTED THE OPPOSITE UNTIL 2026-08-09.
    # It reasoned that keeping only the bands every island holds "would delete the
    # oldest band, and the oldest band is the only one the treadmill reading
    # depends on". That is true and it is the wrong conclusion, because a band
    # held by ONE island is that island's opinion wearing the fleet's clothes.
    #
    # A restart empties an island's archive, so after every deploy the young
    # bands are held by everyone and the oldest by whichever island has been up
    # longest. If that island is mid-slump the pooled profile falls away to the
    # right and the panel announces a treadmill. Nothing has been forgotten: the
    # right-hand bands are a different sample of islands from the left-hand ones,
    # and that is the ordinary post-roll state of this fleet.
    #
    # Losing the reading is the correct outcome. A panel that says "too few
    # islands hold the old bands to compare" is useful. One that draws a
    # confident falling line off a sample of one is worse than nothing.
    test "a band only one island holds is dropped rather than pooled" do
      a = sat("aaa", "beam00", [3, 20], [2, 0], [0, 0], [0, 2])
      b = sat("bbb", "beam01", [3], [1], [0], [1])

      r = CompareTheEras.fleet([a, b])

      # Both hold the young band; only beam00 holds the ancient one.
      assert r.won == [75, nil, nil, nil, nil]
      assert r.n == [4, nil, nil, nil, nil]

      # And the drop is counted rather than the axis quietly narrowing.
      assert r.incomparable == 1
    end

    # The same shape when every island holds every band: nothing is dropped.
    test "a band every island holds is pooled and nothing is counted as dropped" do
      a = sat("aaa", "beam00", [3, 20], [2, 0], [0, 0], [0, 2])
      b = sat("bbb", "beam01", [3, 20], [1, 1], [0, 0], [1, 1])

      r = CompareTheEras.fleet([a, b])

      assert r.won == [75, nil, nil, nil, 25]
      assert r.incomparable == 0
    end

    test "two islands in the same band share one denominator" do
      a = sat("aaa", "beam00", [3], [2], [0], [0])
      b = sat("bbb", "beam01", [4], [0], [0], [2])

      r = CompareTheEras.fleet([a, b])

      assert r.won == [50, nil, nil, nil, nil]
      assert r.n == [4, nil, nil, nil, nil]
    end

    # ⚠ THE DENOMINATOR IS PER BAND AND `master_flown` IS THE TOTAL ACROSS ALL OF
    # THEM. Reusing `CompareTheExams.profiles/2`, which divides every rung by one
    # scalar `_starts`, would report rates wrong by a factor of the era count.
    test "the rate divides by that band's own fights, not by the total flown" do
      a = sat("aaa", "beam00", [3, 20], [2, 1], [0, 0], [0, 1])

      r = CompareTheEras.fleet([a])

      assert r.flown == 4
      assert r.won == [100, nil, nil, nil, 50]
    end
  end

  describe "draws" do
    # An invader that survives has not been defeated, and at a denominator of two
    # a single draw is half the band.
    test "a draw is neither a win nor a loss, and the ceiling shows it" do
      a = sat("aaa", "beam00", [3], [3], [2], [1])

      r = CompareTheEras.fleet([a])

      assert r.won == [50, nil, nil, nil, nil]
      assert r.ceiling == [83, nil, nil, nil, nil]
    end

    test "with no draws the ceiling sits on the win rate" do
      a = sat("aaa", "beam00", [3], [3], [0], [3])

      r = CompareTheEras.fleet([a])

      assert r.won == [50, nil, nil, nil, nil]
      assert r.ceiling == [50, nil, nil, nil, nil]
    end
  end

  describe "a gap is not a zero" do
    # ⚠ THE TWO STATES THIS EXHIBIT KEEPS HAVING TO TELL APART. "We flew it and
    # lost every one" is a finding; "we drew nothing from this age" is silence.
    test "a band flown and lost is zero, a band never drawn from is nil" do
      a = sat("aaa", "beam00", [3, 20], [0, 0], [0, 0], [2, 0])

      r = CompareTheEras.fleet([a])

      assert r.won == [0, nil, nil, nil, nil]
      assert r.n == [2, nil, nil, nil, nil]
      assert r.measured == 1
    end
  end

  describe "islands that publish nothing" do
    # ⚠ THREE STATES, AND `Map.get(v, "master_eras", [])` COLLAPSES TWO OF THEM.
    # An older build publishes no key at all; a new build that has not flown one
    # publishes `master_flown => 0`. They are different news.
    test "an island on an older build is silent, not unsat" do
      a = sat("aaa", "beam00", [3], [2], [0], [0])
      b = older("bbb", "beam01")

      r = CompareTheEras.fleet([a, b])

      assert r.silent == 1
      assert r.unsat == 0
      assert r.sat == 1
      assert r.islands == 2
    end

    test "an island on the new build that has not flown one is unsat, not silent" do
      b =
        island("bbb", "beam01", %{
          "master_eras" => [],
          "master_wins" => [],
          "master_draws" => [],
          "master_losses" => [],
          "master_flown" => 0,
          "master_archived" => 17
        })

      r = CompareTheEras.fleet([b])

      assert r.unsat == 1
      assert r.silent == 0
      assert r.measured == 0
      # ⚠ ITS ARCHIVE STILL COUNTS. "We hold nothing that old" and "we sampled
      # nothing that old" are different findings, and the depth separates them.
      assert r.archived == 17
    end

    # ⚠ THE PANEL GETS THINNER AND SAYS SO. It never goes blank: islands roll one
    # at a time and half a fleet is on the old build for a while.
    test "the fleet profile still draws when only some islands contribute" do
      a = sat("aaa", "beam00", [3], [2], [0], [0])
      _b = older("bbb", "beam01")

      r = CompareTheEras.fleet([a, Dronex.island("bbb")])

      assert r.measured == 1
      assert r.won == [100, nil, nil, nil, nil]
    end

    test "nobody on the board is an empty reading rather than a crash" do
      r = CompareTheEras.fleet([])

      assert r.islands == 0
      assert r.measured == 0
      assert r.won == [nil, nil, nil, nil, nil]
      assert r.oldest == nil
    end
  end

  describe "numbers that do not line up" do
    # ⚠ EXCLUDED AND COUNTED, NEVER COERCED. A list of small integers can ride
    # CBOR as a charlist, and this exhibit has already misread a perfect result
    # as three zeroes once.
    test "vectors of different lengths are refused, not zipped short" do
      a = published("aaa", %{"master_eras" => [3, 20]})

      r = CompareTheEras.fleet([a])

      assert r.unreadable == 1
      assert r.sat == 0
      assert r.measured == 0
    end

    test "a vector carrying something that is not a count is refused" do
      a = published("aaa", %{"master_wins" => ["two"]})

      assert CompareTheEras.fleet([a]).unreadable == 1
    end

    test "a flown count that is not an integer is refused" do
      a = published("aaa", %{"master_flown" => "two"})

      assert CompareTheEras.fleet([a]).unreadable == 1
    end

    test "a vector that is missing entirely is refused rather than read as empty" do
      a = published("aaa", %{})
      Board.put("aaa", :vitals, Map.delete(Dronex.fact(a, :vitals), "master_draws"))

      assert CompareTheEras.fleet([Dronex.island("aaa")]).unreadable == 1
    end
  end

  describe "the table twin" do
    test "every island appears with its own per-band numbers and its state" do
      a = sat("aaa", "beam00", [3], [2], [1], [1])
      _b = older("bbb", "beam01")

      r = CompareTheEras.fleet([a, Dronex.island("bbb")])

      assert [%{state: :sat, cells: cells}, %{state: :silent}] = r.series
      assert [%{w: 2, d: 1, l: 1, n: 4}, nil, nil, nil, nil] = cells
    end

    # ⚠ NEVER SUMMED. One number across ages needs weights across ages, and that
    # judgement is what this instrument exists to avoid making silently.
    test "nothing in the reading is a score, a total or an average" do
      a = sat("aaa", "beam00", [3, 20], [2, 0], [0, 0], [0, 2])

      keys = Map.keys(CompareTheEras.fleet([a]))

      refute :score in keys
      refute :total in keys
      refute :average in keys
      refute :rate in keys
    end
  end
end
