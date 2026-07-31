defmodule RoboRumblerTest do
  @moduledoc """
  The site's half of the contract with the rumbler.

  The fixture below is shaped exactly like a published `duel_featured` fact,
  built here rather than captured, so these tests run with no mesh and no
  network. What they check is that this app can turn such a fact back into the
  fight it names.
  """
  use ExUnit.Case, async: true

  alias RoboRumbler.WatchRumbles
  alias RoboRumbler.WatchRumbles.Board

  # FROZEN, NOT COMPUTED HERE. Both numbers come from running the two fixture
  # genomes against each other at held-out start 1 through `:robo_rumble.battle/2`
  # directly, outside this module, so nothing in the code under test contributed
  # to them:
  #
  #     index 1: seat first -> 243 turns (winner :none) | seat second -> 168
  #     index 2: seat first -> 237                      | seat second -> 170
  #     index 3: seat first -> 232                      | seat second -> 202
  #
  # The neighbouring indices are listed because they are what makes the golden
  # discriminating: an off-by-one in the start index lands on 237, not 243.
  #
  # If the engine's physics change these will fail, and that is the point: the
  # published turn counts on the mesh will have changed too.
  @golden_turns 243
  @golden_turns_second 168

  # ── Replaying a published duel ──────────────────────────────────

  # THE ONE THAT MATTERS. The rumbler publishes 1.2 KB where the fight is 93 MB,
  # and the entire viewer rests on those saying the same thing. If this can pass
  # while the two disagree, the site draws a fight nobody fought.
  test "a published duel replays into a real battle" do
    {:ok, r} = RoboRumbler.replay(duel_fact())

    # THE GOLDEN, and it is not decoration. Asserting `turns > 0` or comparing
    # against a number this same code produced is circular: an off-by-one in the
    # start index passes both, because the wrong fight is still a fight and still
    # agrees with itself. A frozen count from an independent derivation is the
    # only assertion that can tell the right battle from a plausible one.
    assert r.turns == @golden_turns
    assert r.verified
    # One frame per turn, plus the final state the verdict was read from.
    assert length(r.frames) == r.turns + 1
    assert r.challenger == :first
  end

  test "frames carry what a viewer draws, in the engine's own units" do
    {:ok, r} = RoboRumbler.replay(duel_fact())
    frame = hd(r.frames)

    assert [:bullets, :tanks, :turn] == frame |> Map.keys() |> Enum.sort()
    assert [:dead, :energy, :heading, :id, :x, :y] == hd(frame.tanks) |> Map.keys() |> Enum.sort()
    assert length(frame.tanks) == 2

    # Coordinates are fixed point, so they land inside the arena's own bounds and
    # the viewer scales once instead of rounding twice.
    {w, h} = r.arena
    assert Enum.all?(frame.tanks, &(&1.x >= 0 and &1.x <= w and &1.y >= 0 and &1.y <= h))
  end

  # Same two tanks, same geometry, seats swapped: 243 turns one way and 168 the
  # other. Not a mirrored fight, a different one, which is why the fact carries
  # the seat at all and why a viewer that ignored it would be wrong most of the
  # time without ever looking wrong.
  test "the seat decides which geometry the challenger gets" do
    {:ok, first} = RoboRumbler.replay(duel_fact())
    {:ok, second} = RoboRumbler.replay(%{duel_fact() | "challenger_seat" => "second",
                                                       "turns" => @golden_turns_second})

    assert first.turns == @golden_turns
    assert second.turns == @golden_turns_second
    assert second.challenger == :second
    assert first.frames != second.frames
  end

  # The site re-derives the placement from the start index, so that arithmetic
  # now lives in two codebases and can drift. The fact carries the turn count the
  # rumbler measured, so a drifted replay is caught here instead of being drawn.
  test "a replay that disagrees with the published turn count is refused" do
    lying = %{duel_fact() | "turns" => @golden_turns + 1}
    assert {:error, {:replay_mismatch, _want, _got}} = RoboRumbler.replay(lying)
  end

  # Unverifiable is not the same as wrong. A fact published before the rumbler
  # carried a turn count still replays; it just does not claim to have been
  # checked, and the page can say so.
  test "a fact with no turn count replays unverified" do
    {:ok, r} = RoboRumbler.replay(Map.delete(duel_fact(), "turns"))
    refute Map.has_key?(r, :verified)
    assert r.turns == @golden_turns
  end

  # ── Refusing rather than guessing ───────────────────────────────

  test "a fact missing a genome is refused" do
    assert {:error, :genome_missing} = RoboRumbler.replay(Map.delete(duel_fact(), "resident_genome"))
  end

  test "a genome that is not base64 is refused" do
    assert {:error, :genome_not_base64} =
             RoboRumbler.replay(%{duel_fact() | "challenger_genome" => "not base64 at all!"})
  end

  test "a genome this engine will not accept is refused" do
    assert {:error, _why} =
             RoboRumbler.replay(%{duel_fact() | "challenger_genome" => Base.encode64("RGxx")})
  end

  # An index outside the held-out split is refused rather than wrapped. A wrapped
  # index is a different fight drawn under the right name, which is the failure
  # mode a viewer can never notice.
  test "a start index outside the split is refused" do
    assert {:error, {:start_index_out_of_range, 0}} =
             RoboRumbler.replay(%{duel_fact() | "start_index" => 0})

    assert {:error, {:start_index_out_of_range, 9_999}} =
             RoboRumbler.replay(%{duel_fact() | "start_index" => 9_999})
  end

  test "a fact with no seat is refused" do
    assert {:error, :challenger_seat_missing} =
             RoboRumbler.replay(Map.delete(duel_fact(), "challenger_seat"))
  end

  # ── The board ───────────────────────────────────────────────────

  describe "board" do
    setup do
      # The subscriber owns the table in production. Here the test does.
      table = :ets.info(:robo_rumbler_board)
      if table == :undefined, do: Board.init()
      :ets.delete_all_objects(:robo_rumbler_board)
      :ok
    end

    test "an arrival is fighting until its row settles" do
      Board.put_arrival(%{"challenger_id" => "abc", "type" => "visit_started"})
      assert [%{"challenger_id" => "abc"}] = Board.fighting()

      Board.put_visit(%{"challenger_id" => "abc", "type" => "visit_settled"})
      assert [] == Board.fighting()
      assert [%{"challenger_id" => "abc"}] = Board.visits()
    end

    # A battle that never settles STAYS listed. That is the honest behaviour: a
    # timer would quietly erase the evidence that the rumbler stopped answering.
    test "an arrival with no row keeps showing" do
      Board.put_arrival(%{"challenger_id" => "ghost"})
      assert [%{"challenger_id" => "ghost"}] = Board.fighting()
    end

    test "visits are newest first and bounded" do
      for n <- 1..40, do: Board.put_visit(%{"challenger_id" => "c#{n}"})

      visits = Board.visits()
      assert length(visits) == 25
      assert hd(visits)["challenger_id"] == "c40"
    end

    test "duels are newest first and bounded" do
      for n <- 1..30, do: Board.put_duel(%{"start_index" => n})

      duels = Board.duels()
      assert length(duels) == 10
      assert hd(duels)["start_index"] == 30
    end

    test "an empty board is empty, not a crash" do
      assert Board.empty?()
      assert Board.field() == nil
      assert Board.visits() == []
      assert Board.fighting() == []
    end
  end

  # ── Running without a mesh ──────────────────────────────────────

  describe "unconfigured" do
    test "the site is not watching and says so" do
      refute RoboRumbler.watching?()
    end

    # An unconfigured node has nothing to connect to, ever, so the subscriber must
    # not sit on a retry timer for the lifetime of the process.
    #
    # Asserting on an empty MAILBOX does not test this: a pending timer is not a
    # message until it fires, so that assertion passes just as happily with the
    # loop running. The armed timer has to be state to be observable at all.
    test "the subscriber stops ticking rather than retrying forever" do
      assert %{timer: nil} = :sys.get_state(RoboRumbler.WatchRumbles)
    end
  end

  # ── The wire shapes ─────────────────────────────────────────────

  describe "untagging a delivered payload" do
    # THE BUG THIS EXISTS FOR, taken from a real fact off the mesh. CBOR encodes
    # an atom and a binary identically, and the SDK decodes text back to an
    # EXISTING atom when one exists. So one published map arrived with four atom
    # keys and eleven string keys, and `fact["turns"]` was nil while
    # `fact["start_index"]` worked. Nothing raised; the self-check just silently
    # stopped running.
    test "atom keys and tagged keys both become strings" do
      delivered = %{
        :type => :duel_featured,
        :turns => 2000,
        {:text, "challenger_seat"} => {:text, "first"},
        {:text, "start_index"} => 32
      }

      plain = WatchRumbles.untag(delivered)

      assert plain == %{
               "type" => "duel_featured",
               "turns" => 2000,
               "challenger_seat" => "first",
               "start_index" => 32
             }
    end

    # A seat published as a binary can come back as the atom :first purely
    # because robo_rumble put that atom in the table. Values need collapsing for
    # the same reason keys do.
    test "an atom value becomes a string too" do
      assert WatchRumbles.untag(%{{:text, "challenger_seat"} => :second}) == %{
               "challenger_seat" => "second"
             }
    end

    # CBOR has real booleans and null. Those never came from text, so turning
    # them into "true"/"false" would corrupt them.
    test "booleans and null survive untouched" do
      assert WatchRumbles.untag(%{{:text, "decided"} => false, {:text, "winner"} => nil}) == %{
               "decided" => false,
               "winner" => nil
             }
    end

    test "nested lists and maps are untagged all the way down" do
      assert WatchRumbles.untag(%{{:text, "results"} => [%{:resident_id => {:text, "AB"}, :wins => 3}]}) == %{
               "results" => [%{"resident_id" => "AB", "wins" => 3}]
             }
    end

    # A fact whose keys arrive as atoms must still replay. This is the failure
    # that was observed live: the turn count was unreadable, so the replay ran
    # unverified rather than checking itself.
    test "a fact delivered with atom keys still replays and verifies" do
      atom_keyed =
        Map.new(duel_fact(), fn {k, v} -> {String.to_atom(k), v} end)

      {:ok, r} = RoboRumbler.replay(WatchRumbles.untag(atom_keyed))
      assert r.turns == @golden_turns
      assert r.verified
    end
  end

  # ── Fixtures ────────────────────────────────────────────────────

  # Shaped exactly like `visit_facts:duel_featured/3` publishes it: string keys,
  # genomes as base64, the index 1-based into the held-out split.
  defp duel_fact do
    %{
      "type" => "duel_featured",
      "challenger_genome" => Base.encode64(packed(0)),
      "resident_genome" => Base.encode64(packed(3)),
      "start_index" => 1,
      "challenger_seat" => "first",
      "start_split" => "heldout",
      "turns" => @golden_turns
    }
  end

  # The smallest genome the game accepts: straight from the 17 senses to the 5
  # controls. Two different weight fills so the two tanks are not one tank twice.
  defp packed(fill) do
    layers = [:robo_pilot.inputs(), :robo_pilot.outputs()]
    weights = List.duplicate(fill, :robo_net.weight_count(layers))
    :robo_genome.pack({layers, weights})
  end
end
