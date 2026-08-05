defmodule DronexTest do
  @moduledoc """
  The spectator's contract: it reads, it never runs the fight, and it says which
  of four situations it is in.
  """
  use ExUnit.Case, async: false

  alias Dronex.WatchBouts
  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    :ets.delete_all_objects(:dronex_board)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  # ⚠ THE SHAPE THE WIRE ACTUALLY DELIVERS. CBOR encodes an atom and a binary
  # identically, and the SDK decodes a text string to an EXISTING atom when one
  # happens to exist, so the shape a key arrives in depends on the receiving
  # node's atom table. One published map has arrived with four atom keys and
  # eleven string ones.
  test "untag collapses both shapes to strings, keys and values alike" do
    assert WatchBouts.untag(%{:island => {:text, "beam01"}, "tick" => 5}) ==
             %{"island" => "beam01", "tick" => 5}

    assert WatchBouts.untag([{:text, "a"}, :b, 3]) == ["a", "b", 3]
  end

  # Booleans and nil are left alone: CBOR has real ones, so those never came from
  # text and turning them into strings would be a decode that loses a type.
  test "untag leaves booleans and nil alone" do
    assert WatchBouts.untag(%{"a" => true, "b" => nil}) == %{"a" => true, "b" => nil}
  end

  # ⚠ FILED UNDER THE IDENTITY, NEVER THE NAME. Two islands can carry one
  # nickname, and filed under it they overwrite each other while the page shows
  # one place flickering between two rosters.
  test "two islands sharing a name are two rows" do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 5})
    Board.put("bbb", :vitals, %{"island" => "beam01", "roster" => 9})

    assert length(Board.islands()) == 2
    assert Enum.map(Board.islands(), &Board.label/1) == ["beam01", "beam01"]
  end

  # A later fact of one kind must not erase another kind's payload: vitals arrive
  # every second and a bout every twenty, and folding them would drop the fight.
  test "a bout and its vitals live side by side" do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 5})
    Board.put("aaa", :bout, %{"island" => "beam01", "winner" => "attacker"})

    row = Board.island("aaa")
    assert Dronex.fact(row, :vitals)["roster"] == 5
    assert Dronex.fact(row, :bout)["winner"] == "attacker"
  end

  # ⚠ BOUNDED, AND IT SAYS WHEN IT REFUSES. A public realm is writable by anyone
  # who can reach a station, so an unbounded table is a memory leak with a
  # stranger holding the tap. A silent cap looks exactly like a small fleet.
  test "the board caps islands and counts what it turned away" do
    for n <- 1..70, do: Board.put("id#{n}", :vitals, %{"island" => "i#{n}"})

    assert length(Board.islands()) == 64
    assert Board.refused() == 6
  end

  # An island already held is always updated, cap or no cap: the cap is about
  # admitting NEW islands, and applying it to updates would freeze the ones shown.
  test "a known island is updated even when the board is full" do
    for n <- 1..64, do: Board.put("id#{n}", :vitals, %{"island" => "i#{n}"})
    Board.put("id1", :vitals, %{"island" => "i1", "roster" => 42})

    assert Dronex.fact(Board.island("id1"), :vitals)["roster"] == 42
  end

  # ⚠ WITHOUT THIS A DEAD ISLAND IS INVISIBLE. The board keeps the last fact
  # forever, so an island whose trainer stopped goes on showing its final bout.
  test "quiet_for reports how long an island has been silent" do
    Board.put("aaa", :vitals, %{"island" => "beam01"})
    assert Board.quiet_for(Board.island("aaa")) >= 0
    assert Board.quiet_for(nil) == nil
  end

  # Four states, each wanting a different response from whoever is reading.
  # Collapsing any two sends the reader to look in the wrong place.
  test "an unconfigured site says so rather than looking broken" do
    assert Dronex.state() == :unconfigured
    refute Dronex.configured?()
  end

  # ⚠ THE CONTRACT IS THE FACT, NOT THE ISLAND'S CODE. This app must never gain a
  # dependency on an engine: that is what the removed Robo Rumble page did, and
  # the site and the service ended up pinned to commits that drifted apart with
  # nothing comparing them.
  #
  # ⚠⚠ IT READS THIS APP'S OWN DECLARED DEPS, NOT THE UMBRELLA'S. The first
  # version used `Mix.Project.deps_apps/0`, which returns everything the umbrella
  # resolved, and `faber_tweann` is legitimately in there for the adaptation
  # workbench, which runs its own simulation and is allowed to. The question is
  # not what the umbrella contains; it is what THIS app asked for.
  test "the spectator declares no engine of its own" do
    declared =
      Dronex.MixProject.project()
      |> Keyword.get(:deps, [])
      |> Enum.map(&elem(&1, 0))

    assert declared == [:macula, :beam_campus, :phoenix_pubsub]
    refute :faber_tweann in declared
  end
end
