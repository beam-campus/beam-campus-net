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
    # ⚠ AND TWO REPLACEMENTS HAD THE SAME FAULT. `refute html =~ "fought"`
    # matched "an island announces that it can be fought"; `refute html =~ "in
    # flight"` matched the map caption's "a moving one is a raid in flight".
    # Both are prose about the mechanism, not claims about this bout.
    #
    # `data-raid` is emitted by a rendered raid row and by nothing else, which is
    # what a refutation needs: a marker no sentence can produce.
    refute html =~ "data-raid"
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

    # ⚠ ONE ROW PER DIRECTION, NOT ONE PER RAID. With two islands every raid
    # renders the same sentence, and the page grew thirty-seven near-identical
    # lines before anybody said so. The map already draws each raid as an arc;
    # what a reader cannot get from the map is the flow and what it costs.
    assert html =~ "data-raid"
    assert html =~ "beam01"
    assert html =~ "6 airframes committed"

    # No recording has arrived, so it is still out — and the page says so
    # without claiming to know whether it is being fought or was abandoned.
    assert html =~ "1 still out"
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

    # It counts toward the flow, and it is no longer out.
    assert html =~ "data-raid"
    assert html =~ "6 airframes committed"
    refute html =~ "still out"
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

  # ⚠ THE MAP IS ONE CANVAS, HOWEVER MANY ISLANDS JOIN. That is the whole reason
  # the biotope's per-island grid was removed: one canvas, one hook and one
  # animation loop, regardless of fleet size.
  test "the archipelago is drawn as one canvas with every island on it", %{conn: conn} do
    for {id, name} <- [{"aaa", "beam01"}, {"bbb", "beam02"}] do
      Board.put(id, :vitals, %{
        "island" => name,
        "island_id" => id,
        "roster" => 120,
        "capacity" => 240,
        "open" => true
      })
    end

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ ~s(id="dronex-archipelago")
    assert html =~ "data-world-width"
    assert html =~ "data-isles"
    assert html =~ "data-arcs"

    # Positions are a hash of a name, so any two viewers holding the same
    # islands draw the same world. Both islands are on the one canvas.
    [_, isles] = Regex.run(~r/data-isles="([^"]*)"/, html)
    decoded = isles |> unescape() |> Jason.decode!()
    assert length(decoded) == 2
    assert Enum.map(decoded, & &1["name"]) |> Enum.sort() == ["beam01", "beam02"]

    # The ring is how much roster is left: half a roster is half a ring, which
    # is the price of being popular made visual rather than tabular.
    assert Enum.all?(decoded, &(&1["fill"] == 0.5))
    assert Enum.all?(decoded, & &1["open"])
  end

  # ⚠ AN ARC NEEDS BOTH ENDS, AND ONE COMMITMENT NAMES BOTH. The two commitments
  # travel separately and one of them may never arrive, so a single fact has to
  # be enough to draw the arc.
  test "a raid is drawn as an arc from attacker to defender", %{conn: conn} do
    for {id, name} <- [{"aaa", "beam01"}, {"bbb", "beam02"}] do
      Board.put(id, :vitals, %{
        "island" => name,
        "island_id" => id,
        "roster" => 100,
        "capacity" => 240
      })
    end

    Board.put_raid("r9", :committed, %{
      "island" => "beam01",
      "island_id" => "aaa",
      "raid_id" => "r9",
      "role" => "attacker",
      "opponent_id" => "bbb",
      "airframes" => 6
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    [_, arcs] = Regex.run(~r/data-arcs="([^"]*)"/, html)
    [arc] = arcs |> unescape() |> Jason.decode!()

    # In flight, because no recording has arrived, and as many marks as the
    # sortie so the cost is visible on the arc itself.
    assert arc["live"]
    assert arc["marks"] == 6
    assert arc["x1"] != arc["x2"] or arc["y1"] != arc["y2"]
  end

  # An island nobody has heard vitals from has no place on the map, so an arc to
  # it is dropped rather than drawn to a guessed position.
  test "an arc to an island the map has never heard of is dropped", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam01",
      "island_id" => "aaa",
      "roster" => 100,
      "capacity" => 240
    })

    Board.put_raid("r10", :committed, %{
      "island_id" => "aaa",
      "raid_id" => "r10",
      "role" => "attacker",
      "opponent_id" => "never-heard-of",
      "airframes" => 6
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    [_, arcs] = Regex.run(~r/data-arcs="([^"]*)"/, html)
    assert arcs |> unescape() |> Jason.decode!() == []
  end

  defp unescape(s) do
    s
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&#39;", "'")
  end

  # ⚠ A RAID BEATS A TRAINING BOUT EVERY TIME, and for a while it lost to one. A
  # bout is one controller against a scripted drill: two marks, and the drill is
  # not alive in any interesting sense. A raid is six evolved controllers against
  # six others, bred on different machines under pressures neither chose. That is
  # what this archipelago exists to produce and it was being played small,
  # underneath a picture of two circles and an arc.
  test "a raid is what gets played, in preference to a training bout", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "island_id" => "aaa"})

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    Board.put_raid("r3", :raid, %{
      "raid_id" => "r3",
      "kind" => "raid",
      "winner" => "defender",
      "ticks" => 240,
      "raiders" => 12,
      "raiders_home" => 3,
      "defenders" => 12,
      "defenders_home" => 8,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 100, 100, 80, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "A raid, fought in somebody else&#39;s airspace"
    assert html =~ "240 tick"
    refute html =~ "A training bout"

    # ⚠ BOTH SIDES OF THE LEDGER. The fight reported only "won by defender" and
    # a tick count; a score that shows what a raid cost one side and not the
    # other is not a score, and both pay airframes on the same terms.
    assert html =~ "3 / 12"
    assert html =~ "8 / 12"
    assert html =~ "defender"
  end

  # And an island that has never been raided still has something to watch, rather
  # than an empty canvas that explains nothing.
  test "a training bout is played when there has been no raid", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "island_id" => "aaa"})

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "A training bout"
    assert html =~ "No island has been raided yet"
  end
end
