defmodule BiotopeTest do
  use ExUnit.Case, async: true

  alias Biotope.WatchIslands
  alias Biotope.WatchIslands.Board

  # ── The wire shape ──────────────────────────────────────────────

  describe "untag/1" do
    # THE FAILURE THIS PREVENTS IS SILENT. CBOR encodes an atom and a binary
    # identically, and the SDK decodes a text string to an existing atom when one
    # happens to be in the receiving node's atom table and to {:text, binary}
    # when it is not. So one published map arrives with its keys split between
    # two shapes, differently on different nodes, and a Map.get with the wrong
    # one returns nil without raising.
    test "collapses atoms and tagged text to strings, keys and values alike" do
      mixed = %{:island => "beam01", {:text, "tick"} => 42, "population" => 7}

      assert WatchIslands.untag(mixed) == %{
               "island" => "beam01",
               "tick" => 42,
               "population" => 7
             }
    end

    test "leaves booleans and nil alone, because CBOR has real ones" do
      assert WatchIslands.untag(%{:decided => true, :why => nil}) ==
               %{"decided" => true, "why" => nil}
    end

    test "reaches inside lists" do
      assert WatchIslands.untag(%{:creatures => [1, 2, 3, 4]}) ==
               %{"creatures" => [1, 2, 3, 4]}
    end

    # Nothing downstream may become an atom: these are bytes off a PUBLIC realm,
    # and String.to_atom on network input fills the atom table until the node dies.
    test "produces no new atoms" do
      out = WatchIslands.untag(%{{:text, "never_seen_before_key"} => {:text, "v"}})
      assert Map.keys(out) == ["never_seen_before_key"]
      assert is_binary(hd(Map.keys(out)))
    end
  end

  # ── Coordinates ─────────────────────────────────────────────────

  describe "points/1" do
    test "chunks a flat list into pairs" do
      assert Biotope.points([1, 2, 3, 4]) == [{1, 2}, {3, 4}]
    end

    # A truncated frame should cost one creature on one redraw, not the page.
    test "discards a trailing odd element rather than raising" do
      assert Biotope.points([1, 2, 3]) == [{1, 2}]
    end

    test "survives a non-list" do
      assert Biotope.points(nil) == []
    end
  end

  describe "to_pixel/2" do
    test "the origin lands in the middle of the box" do
      box = %{radius: 20, size: 320}
      {x, y} = Biotope.to_pixel({0, 0}, box)
      assert_in_delta x, 160.0, 0.001
      assert_in_delta y, 160.0, 0.001
    end

    # Every one of the six neighbours is the same distance away, which is the
    # whole reason the world is hexagonal rather than square.
    test "all six neighbours are equidistant" do
      box = %{radius: 20, size: 320}
      {cx, cy} = Biotope.to_pixel({0, 0}, box)

      distances =
        for {q, r} <- [{1, 0}, {1, -1}, {0, -1}, {-1, 0}, {-1, 1}, {0, 1}] do
          {x, y} = Biotope.to_pixel({q, r}, box)
          :math.sqrt(:math.pow(x - cx, 2) + :math.pow(y - cy, 2))
        end

      Enum.each(distances, &assert_in_delta(&1, hd(distances), 0.001))
    end

    # The whole disc has to fit the box, or creatures at the rim are drawn
    # outside the picture and nobody sees them starve.
    test "the rim stays inside the box" do
      box = %{radius: 20, size: 320}
      {x, y} = Biotope.to_pixel({20, 0}, box)
      assert x <= 320 and x >= 0
      assert y <= 320 and y >= 0
    end
  end

  # ── The board ───────────────────────────────────────────────────

  describe "board" do
    setup do
      :ets.whereis(:biotope_board) == :undefined and Board.init()
      :ets.delete_all_objects(:biotope_board)
      :ok
    end

    test "files each fact under its own island" do
      Board.put_stats(%{"island" => "beam01", "population" => 7})
      Board.put_chart(%{"island" => "beam01", "creatures" => [0, 0]})
      Board.put_stats(%{"island" => "beam02", "population" => 3})

      assert Board.islands() == ["beam01", "beam02"]

      assert %{stats: %{"population" => 7}, chart: %{"creatures" => [0, 0]}} =
               Board.island("beam01")

      assert %{stats: %{"population" => 3}, chart: nil} = Board.island("beam02")
    end

    test "keeps only the latest of each" do
      Board.put_stats(%{"island" => "beam01", "tick" => 1})
      Board.put_stats(%{"island" => "beam01", "tick" => 2})
      assert %{stats: %{"tick" => 2}} = Board.island("beam01")
    end

    # A fact with no island cannot be attributed, and inventing a name for it
    # would put a phantom island on the page. An older service publishing
    # without the field is exactly this case.
    test "refuses a fact with no island" do
      assert Board.put_stats(%{"population" => 7}) == :ignored
      assert Board.islands() == []
    end

    test "an unknown island reads as nil rather than raising" do
      assert Board.island("nowhere") == nil
      assert Board.empty?()
    end
  end

  # ── Readiness ───────────────────────────────────────────────────

  describe "readiness" do
    # A CONNECTED POOL IS NOT A USABLE POOL. :macula.connect/2 returns
    # immediately and handshakes asynchronously; subscribing in that window does
    # not fail, the frame is dropped by a peering still in :handshaking, and
    # :macula.subscribe/4 answers {:ok, ref} anyway. A subscriber that trusts
    # that stops retrying and waits forever for facts being published perfectly
    # well. That is exactly what happened the first time this page met a live
    # island: two topics "subscribed", not one fact delivered.
    #
    # So handle/0 is gated on healthy_links > 0. Unconfigured is the case a test
    # node can actually reach; the gate itself was verified against the live
    # island, where the station's dropped-frame log went from many to zero.
    test "an unconfigured node is never ready" do
      refute Biotope.configured?()
      refute Biotope.watching?()
      assert Biotope.Mesh.handle() == {:error, :not_ready}
    end
  end

  describe "liveness" do
    setup do
      :ets.whereis(:biotope_board) == :undefined and Board.init()
      :ets.delete_all_objects(:biotope_board)
      :ok
    end

    test "an island that just spoke is live" do
      Board.put_stats(%{"island" => "beam01", "population" => 40})
      assert Biotope.liveness("beam01") == :live
    end

    # AN EXTINCT ISLAND PUBLISHES PERFECTLY WELL. Its plants regrow, its tick
    # advances, every fact arrives on time. Without this it reads as healthy and
    # the only clue is a population of zero that nobody is looking at.
    test "an extinct island is extinct, not live" do
      Board.put_stats(%{"island" => "beam09", "population" => 0, "extinct_at" => 4213})
      assert Biotope.liveness("beam09") == {:extinct, 4213}
    end

    # Dead AND unreachable is still dead, and that is the more important fact.
    test "extinction outranks silence" do
      Board.put_stats(%{"island" => "beam09", "population" => 0, "extinct_at" => 7})
      [{key, row}] = :ets.lookup(:biotope_board, {:island, "beam09"})
      :ets.insert(:biotope_board, {key, %{row | seen_at: 0}})

      assert {:extinct, 7} = Biotope.liveness("beam09")
    end

    test "an island that stopped talking is quiet, with how long" do
      Board.put_stats(%{"island" => "beam02", "population" => 40})
      [{key, row}] = :ets.lookup(:biotope_board, {:island, "beam02"})

      :ets.insert(
        :biotope_board,
        {key, %{row | seen_at: System.system_time(:millisecond) - 120_000}}
      )

      assert {:quiet, ms} = Biotope.liveness("beam02")
      assert ms > 100_000
      assert Biotope.since(ms) == "2m"
    end

    test "an island never heard from is its own state" do
      assert Biotope.liveness("nowhere") == :never_heard
    end
  end
end
