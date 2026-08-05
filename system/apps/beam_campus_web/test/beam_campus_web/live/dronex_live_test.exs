defmodule BeamCampusWeb.DronexLiveTest do
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    :ets.delete_all_objects(:dronex_board)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  test "an unconfigured site says so rather than showing an empty chart", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "BEAM_CAMPUS_DRONEX_SEEDS"
    assert html =~ "DroneX"
  end

  # ⚠ THE SITE NAV IS ITS OWN LIST AND A WORKBENCH CARD DOES NOT FEED IT. That is
  # how a sibling page shipped invisible: the card was added, a test asserted the
  # card, and the dropdown listed the other tracks and nothing else.
  test "DroneX is in the site navigation", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research")

    assert html =~ "DroneX"
    assert html =~ "/research/workbench/dronex"
  end

  test "it renders inside the site layout", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ ">Workbench<"
  end

  # ⚠ IT SAYS WHAT IT IS. Nothing crosses the mesh yet, so a fight drawn here is
  # an island against its own drill. Calling it a raid would be the first lie
  # this track told, and the fact carries `kind` precisely so the page cannot.
  test "a published bout is drawn and named as a training bout", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam01",
      "roster" => 24,
      "capacity" => 240,
      "generation" => 9,
      "rounds" => 120,
      "admissions" => 31,
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => [6, 1],
      "benchmark_starts" => 6
    })

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "training"
    assert html =~ "won by attacker"
    assert html =~ "beam01"

    # ⚠ A TRAINING BOUT MUST NOT BE DRESSED AS A RAID. The assertion used to be
    # `refute html =~ "raid"`, which stopped being about that the moment the page
    # grew raid counters and a raids section — the word appears legitimately now,
    # and a blunt refute would have forced deleting a check worth keeping.
    #
    # What actually matters is that no raid is CLAIMED: this island has fought
    # none, so the raids section is absent.
    #
    # ⚠ AND THE REPLACEMENT HAD THE SAME FAULT ONCE. `refute html =~ "fought"`
    # matched the sentence "An island announces that it can be fought", which is
    # prose about availability and not a claim about this bout. A refutation has
    # to name something only the thing being refuted would produce.
    refute html =~ "in flight"
    refute html =~ ~r/against\s+beam/
  end

  # ⚠ A RAID IN FLIGHT AND A RAID WHOSE DEFENDER WENT DARK LOOK THE SAME FROM
  # HERE, and the page says "in flight" rather than pretending to know which.
  # Only the defender publishes the recording; both sides publish a commitment,
  # which is why a paid cost always leaves a trace even when the fight does not.
  test "a raid with commitments and no recording is shown as in flight", %{conn: conn} do
    for {role, island, opponent} <- [
          {"attacker", "beam01", "bbb"},
          {"defender", "beam02", "aaa"}
        ] do
      Board.put_raid("r1", :committed, %{
        "island" => island,
        "island_id" => island,
        "raid_id" => "r1",
        "role" => role,
        "opponent_id" => opponent,
        "airframes" => 6
      })
    end

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "in flight"
    assert html =~ "beam01 sent 6 against beam02"
    refute html =~ "fought"
  end

  # And once the recording arrives it stops being in flight. The recording is
  # published by the defender, so it is filed under the same raid rather than
  # under whoever published it.
  test "a raid with a recording is shown as fought", %{conn: conn} do
    Board.put_raid("r2", :committed, %{
      "island" => "beam01",
      "raid_id" => "r2",
      "role" => "attacker",
      "opponent_id" => "bbb",
      "airframes" => 6
    })

    Board.put_raid("r2", :raid, %{
      "raid_id" => "r2",
      "kind" => "raid",
      "winner" => "defender",
      "raiders" => 6,
      "raiders_home" => 2
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "fought"
    refute html =~ "in flight"
  end

  # A profile is a curve and never a total. A single number would need weights,
  # and weights are a judgement about which rung matters.
  test "the frozen exam is drawn per rung and never summed", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam01",
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => [6, 1],
      "benchmark_starts" => 6
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "hoverer"
    assert html =~ "sniper"
    assert html =~ "6/6"
    assert html =~ "1/6"
  end

  # An island that has not sat the exam is different from one that sat it and
  # lost everything, and a zero must not be drawn as a flat bar.
  test "an unsat exam says so", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "benchmark_starts" => 0})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "Not sat yet"
  end
end
