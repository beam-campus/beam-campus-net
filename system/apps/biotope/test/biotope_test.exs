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

  describe "marks/1" do
    # A SEPARATE STRIDE FROM points/1, because a scent mark is a position AND a
    # strength with no list to run parallel to, while creature energies do have
    # one and arrive alongside. Mixing the two conventions is how a reader draws
    # a plausible and completely wrong picture instead of failing.
    test "reads flat triples" do
      assert Biotope.marks([0, 0, 30, 1, -1, 12]) == [{0, 0, 30}, {1, -1, 12}]
    end

    # Network input. A truncated frame should cost one smudge on one redraw, not
    # the page.
    test "drops a trailing partial mark" do
      assert Biotope.marks([0, 0, 30, 1]) == [{0, 0, 30}]
      assert Biotope.marks([0, 0, 30, 1, -1]) == [{0, 0, 30}]
    end

    test "an absent or malformed field is no marks" do
      assert Biotope.marks([]) == []
      assert Biotope.marks(nil) == []
      assert Biotope.marks("scent") == []
    end
  end
  # ══════════════════════════════════════════════════════════════════════
  # What each creature is built like
  # ══════════════════════════════════════════════════════════════════════

  describe "kinds" do
    # ⚠ THE WIRE SENDS INDEXES AND THIS IS THE ONLY PLACE THEY ARE GIVEN
    # MEANING. The island holds the same two lists and pins their order with a
    # test of its own; this site deliberately takes no dependency on the
    # island's code, so it mirrors them, and the mirror is the risk.
    #
    # Reordering either list would silently change the meaning of every kind
    # table ever published: a reader would draw a scent sensor where a ground
    # sensor is, and nothing about the page would look wrong. This test cannot
    # detect a change made on the island. It can only stop this side drifting on
    # its own, which is the most a reader can do.
    #
    # ⚠ `:water` IS FIFTH BECAUSE THE ISLAND APPENDED IT IN ITS WORLD 23, and
    # this list did not follow for a whole world. Appending is the safe
    # direction, so the first four indexes kept decoding correctly and nothing
    # looked wrong; what this reader could not do was name a water sensor.
    # Appending here is safe for the same reason. INSERTING would not be.
    test "the wire codes for fields and purposes are the fact_version 18 orders" do
      assert Biotope.fields() == [:creatures, :ground, :scent, :self, :water]
      assert Biotope.purposes() == [:move, :breed, :grow, :eat]
    end

    # A cell is wet or it is not, so water arrives as position with no amount.
    test "decodes water as position pairs and drops a truncated tail" do
      assert Biotope.pairs([1, 2, -3, 4]) == [{1, 2}, {-3, 4}]
      assert Biotope.pairs([1, 2, 9]) == [{1, 2}]
      assert Biotope.pairs([]) == []
      assert Biotope.pairs(nil) == []
    end

    # NSensors, then field and reach pairs, then hidden, then the count of
    # purposes and the purposes.
    test "decodes an architecture into what a creature actually is" do
      table = [2, 1, 0, 2, 1, 1, 2, 0, 3]

      assert [kind] = Biotope.kinds(table)
      assert kind.sensors == [{:ground, 0}, {:scent, 1}]
      assert kind.hidden == 1
      assert kind.purposes == [:move, :eat]
      # The flat form is kept because it is what the colour is derived from.
      assert kind.raw == [2, 1, 0, 2, 1, 1, 0, 3]
    end

    test "decodes several architectures from one table" do
      table = [1, 1, 0, 0, 1, 0] ++ [0, 2, 2, 1, 2]

      assert [first, second] = Biotope.kinds(table)
      assert first.sensors == [{:ground, 0}]
      assert first.hidden == 0
      assert second.sensors == []
      assert second.hidden == 2
      assert second.purposes == [:breed, :grow]
    end

    # A CREATURE THAT MEASURES NOTHING IS A LEGITIMATE CREATURE. It pays no rent,
    # values every cell alike and wanders, and it is the null forager everything
    # else has to beat. It must render, not vanish.
    test "a blind creature with no brain and no acts is still a kind" do
      assert [kind] = Biotope.kinds([0, 0, 0])
      assert kind.sensors == []
      assert kind.hidden == 0
      assert kind.purposes == []
    end

    # ⚠ NETWORK INPUT FROM A SERVICE ON SOMEONE ELSE'S MACHINE, possibly a
    # version ahead. A truncated or nonsensical table must cost the rest of the
    # table and not the spectator's page.
    test "a malformed table costs the rest of the table and not the page" do
      assert Biotope.kinds([1, 1, 0, 0, 1]) == []
      assert Biotope.kinds([3, 1, 0]) == []
      assert Biotope.kinds([-1]) == []
      assert Biotope.kinds("not a list") == []
      assert Biotope.kinds(nil) == []
      # Everything read cleanly before the damage is kept.
      assert [_one] = Biotope.kinds([1, 1, 0, 0, 1, 0] ++ [9, 9])
    end

    # An island a version ahead may name a field this reader has never heard of.
    # Showing the number is honest; inventing a name for it would not be.
    test "an unknown field or purpose is shown as itself rather than guessed at" do
      assert [kind] = Biotope.kinds([1, 99, 0, 0, 1, 98])
      assert kind.sensors == [{99, 0}]
      assert kind.purposes == [98]
    end
  end

  describe "kind_rgb" do
    # ⚠ THE SAME ARCHITECTURE MUST WEAR THE SAME COLOUR ON BOTH PAGES. The island
    # serves its own local view and this site serves the public one, and they are
    # two drawings of one world. `:erlang.phash2/2` is portable across nodes and
    # ERTS versions and both sides hash the same flat integer list, so a kind
    # keeps its colour whichever page you are looking at.
    #
    # These four values were taken from the island's own `island_disc:kind_rgb/1`
    # and are pinned here. If this test fails, the two drawings have diverged and
    # one of them is lying about which creatures are alike.
    test "matches the island's own colour for the same architecture" do
      assert Biotope.kind_rgb([1, 1, 0, 0, 1, 0]) == 0x4760D1
      assert Biotope.kind_rgb([2, 0, 1, 1, 2, 1, 0, 2, 0, 3]) == 0xD147C1
      assert Biotope.kind_rgb([0, 3, 4, 0, 1, 2, 3]) == 0x47D1C9
      assert Biotope.kind_rgb([1, 2, 4, 0, 0]) == 0xD1474C
    end

    # NOT DERIVED FROM THE INDEX IN THE TABLE. The table holds the kinds present,
    # sorted, so one creature dying shifts every index above it. A colour taken
    # from an index would repaint the whole board for a change to one creature
    # and a viewer would read that as the population turning over.
    test "a kind keeps its colour when another kind dies" do
      alone = Biotope.kinds([1, 2, 0, 0, 1, 0])
      crowded = Biotope.kinds([1, 1, 0, 0, 1, 0] ++ [1, 2, 0, 0, 1, 0])

      assert Biotope.kind_rgb(hd(alone).raw) ==
               Biotope.kind_rgb(List.last(crowded).raw)
    end

    test "different architectures are visibly different and never black" do
      colours =
        for n <- 1..40, do: Biotope.kind_rgb([1, rem(n, 4), div(n, 4), 0, 1, 0])

      assert Enum.all?(colours, &(&1 > 0x101010))
      assert Enum.all?(colours, &(&1 <= 0xFFFFFF))
      assert length(Enum.uniq(colours)) > 8
    end

    test "something that is not an architecture draws grey rather than crashing" do
      assert Biotope.kind_rgb(nil) == 0x888888
      assert Biotope.kind_rgb("nonsense") == 0x888888
    end
  end

  describe "kind_tally" do
    test "counts how many creatures hold each kind" do
      assert Biotope.kind_tally([0, 1, 0, 0, 2]) == %{0 => 3, 1 => 1, 2 => 1}
    end

    # An island on an older build sends nothing, which is not the same as an
    # island whose creatures are all one kind.
    test "an absent list is no creatures rather than one kind" do
      assert Biotope.kind_tally(nil) == %{}
      assert Biotope.kind_tally([]) == %{}
    end
  end

end
