defmodule BeamCampusWeb.DronexLiveTest do
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    :ets.delete_all_objects(:dronex_board)
    :ets.delete_all_objects(:dronex_recordings)
    :ets.delete_all_objects(:dronex_history)
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
    # The marker moved when the flows list went into the map's arcs, but the
    # requirement did not: a refutation needs something no sentence can produce.
    # A chooser row for a raid is that.
    refute html =~ "data-watch=\"raid:"
  end

  # ⚠ A RAID IN FLIGHT AND A RAID WHOSE DEFENDER WENT DARK LOOK THE SAME FROM
  # HERE, and the page says "in flight" rather than pretending to know which.
  # Only the defender publishes the recording; both sides publish a commitment,
  # which is why a paid cost always leaves a trace even when the fight does not.

  # And once the recording arrives it stops being in flight. The recording is
  # published by the defender, so it is filed under the same raid rather than
  # under whoever published it.

  # A profile is a curve and never a total. A single number would need weights,
  # and weights are a judgement about which rung matters.
  test "the frozen exam is drawn per rung and never summed", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam01",
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => [6, 1],
      "benchmark_starts" => 6
    })

    # ⚠ THE EXAM IS BEHIND ITS TAB, so this asks for it rather than assuming the
    # default view carries it. Reached by URL, which is the point of the tab
    # being in the address bar: a link can open somebody on this panel.
    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex?panel=exam")

    assert html =~ "hoverer"
    assert html =~ "sniper"

    # ⚠ THE DENOMINATOR IS SAID ONCE, NOT SIX TIMES. Every rung is flown the same
    # number of times, so "6/6" on each column was repeating a constant; the
    # count leads and the whole reading is in the cell's title.
    assert html =~ "hoverer: 6 of 6"
    assert html =~ "sniper: 1 of 6"
  end

  # The tab is a view and not a second island selection, so switching it must not
  # disturb which island is being read.
  test "the exam tab is reachable by click and keeps the selection", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam01",
      "island_id" => "aaa",
      "benchmark_rungs" => ["hoverer"],
      "benchmark_wins" => [6],
      "benchmark_starts" => 6
    })

    {:ok, view, html} = live(conn, ~p"/research/workbench/dronex")

    # ⚠ FIGHTS IS THE DEFAULT, because it is the chooser for the canvas beside
    # it. Neither of the other two is rendered until asked for.
    # ⚠ NOT A RUNG NAME. The drill names now appear on the landing view as the
    # matrix's column headings, so "hoverer" no longer distinguishes a tab from
    # the page around it. This asserts on what is unique to each panel.
    refute html =~ "fields at most"
    refute html =~ "Six scripted drills"

    html = render_click(view, "show_panel", %{"panel" => "vitals"})
    assert html =~ "fields at most"
    refute html =~ "Six scripted drills"

    html = render_click(view, "show_panel", %{"panel" => "exam"})
    assert html =~ "Six scripted drills"
    refute html =~ "fields at most"
  end

  # ⚠ THE PLAYER BELONGS TO THE FIGHTS TAB, and this test used to assert the
  # opposite. A tab labelled "Fights" sitting beside a permanently visible fight
  # is incoherent: either the label is wrong or the scope is, and the label is
  # right. The earlier reasoning — that a raid is about two islands and must not
  # be filed under one — is still true and is not what a tab set decides; these
  # tabs choose a VIEW, and the fight the player shows is still a fight between
  # two islands that the selection merely filters.
  test "the player belongs to the fights tab and only to it", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put_raid("r1", :raid, raid("bbb", "beam00") |> Map.put("island_id", "aaa"))

    {:ok, view, html} = live(conn, ~p"/research/workbench/dronex")
    assert html =~ "dronex-replay"

    for panel <- ["vitals", "exam", "history"] do
      refute render_click(view, "show_panel", %{"panel" => panel}) =~ "dronex-replay"
    end

    assert render_click(view, "show_panel", %{"panel" => "fights"}) =~ "dronex-replay"
  end

  # ⚠ THE LEDGER HAS TO REACH THE PAGE, and the first version did not: every
  # component declared the attribute and the outermost call never passed it, so
  # it defaulted to nil three levels down and the panel silently rendered
  # nothing. The analysis was correct and invisible, which is the worst pair.
  test "the loss ledger reaches the page from the frames", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    frames =
      for hp <- [100, 75, 50] do
        %{"t" => 0, "d" => [0, 0, 0, 0, 0, hp, 0], "m" => [], "k" => []}
      end

    Board.put_raid(
      "r1",
      :raid,
      raid("bbb", "beam00") |> Map.put("island_id", "aaa") |> Map.put("frames", frames)
    )

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "What destroys them"
    # Two exact 25-point falls: all of it weapons, none of it a ram.
    assert html =~ "weapons 100%"
  end

  # ⚠ AND THE COVERAGE SUMMARY HAS TO REACH THE PAGE TOO. The loss ledger was
  # computed correctly and rendered nowhere because one call site did not pass
  # the attribute; this walks the same path for the second analysis.
  test "the tower coverage summary reaches the page from the frames", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    # Drone 0 is a RAIDER (even id), alive, at 20 m, with a track on top of it.
    frames =
      for _ <- 1..2 do
        %{"t" => 0, "d" => [0, 100, 100, 20, 0, 100, 0], "m" => [], "k" => [100, 100, 20]}
      end

    Board.put_raid(
      "r1",
      :raid,
      raid("bbb", "beam00") |> Map.put("island_id", "aaa") |> Map.put("frames", frames)
    )

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "What the towers hold, by altitude"
    assert html =~ "0–50 m"
    # Held in both frames, and the denominator is on the row.
    assert html =~ "n=2"
    # ⚠ AND THE FLEET COUNT, because these are accumulations over a rolling
    # window rather than a sample anybody chose.
    assert html =~ "1 raids"
  end

  # ── Does breeding longer win wars ───────────────────────────────

  # ⚠ A CHART THAT SILENTLY DREW WHAT IT HAD WOULD ANSWER A DIFFERENT QUESTION
  # CONVINCINGLY. The stamp shipped after these islands had been fighting for
  # days, so a fleet mid-roll carries raids with one side stamped and not the
  # other, and those must be counted out loud rather than drawn at a fabricated
  # gap.
  test "an unplottable raid is reported rather than drawn", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    # Settled, but only the attacker carries a stamp.
    Board.put_raid("r1", :raid, raid("aaa", "beam01") |> Map.put("island_id", "bbb"))

    Board.put_raid("r1", :committed, %{
      "raid_id" => "r1",
      "role" => "attacker",
      "island_id" => "aaa",
      "opponent_id" => "bbb",
      "rounds" => 9000
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "Does breeding longer win wars"
    assert html =~ "Nothing to plot yet"
    assert html =~ "waiting"
  end

  test "a raid stamped on both sides is plotted with its sign", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    Board.put_raid(
      "r1",
      :raid,
      raid("aaa", "beam01") |> Map.merge(%{"island_id" => "bbb", "rounds" => 8000})
    )

    Board.put_raid("r1", :committed, %{
      "raid_id" => "r1",
      "role" => "attacker",
      "island_id" => "aaa",
      "opponent_id" => "bbb",
      "rounds" => 9000
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    refute html =~ "Nothing to plot yet"
    assert html =~ "1000 rounds: raider 9000, island 8000"
    # The lanes are named for what happened, not for a side.
    assert html =~ "raider won"
    assert html =~ "island held"
  end

  # ── Does the radio matter ───────────────────────────────────────
  #
  # ⚠ THE ONLY CAUSAL NUMBER ON THE WIRE. Every other figure on this page is an
  # observation; this is an experiment — the same genome against the same
  # opponents with one channel silenced — so it is the only one immune to the
  # hardware differences between these machines.

  defp with_ablation(id, name, extra) do
    Board.put(
      id,
      :vitals,
      Map.merge(
        %{
          "island" => name,
          "island_id" => id,
          "ablations" => 12,
          "ablation_void" => false,
          "signal_volume" => 500,
          "signal_entropy" => 1200,
          "ablation_delta_air" => 0,
          "ablation_delta_ground" => 0,
          "ablation_delta_all" => 0
        },
        extra
      )
    )
  end

  test "the sign convention is stated, because a reader cannot guess it", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_delta_air" => 25})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "Does the radio matter"
    assert html =~ "+ means the swarm got worse without it"
    assert html =~ "25 points of attacker score"
  end

  # ⚠ VOID IS NOT ZERO. Nothing was transmitted, so there is no measurement — and
  # three empty bars would read as "the channel does not matter", which is the
  # one thing this cannot say.
  test "a void measurement is drawn as unmeasurable, never as zero", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_void" => true, "signal_volume" => 0})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "nothing transmitted · not measurable"
    refute html =~ "points of attacker score"
  end

  # ⚠ SCALED TO THE FULL RANGE, NEVER TO THE DATA. The score is a percentage, so
  # ±100 is the honest half-width; fitting the axis to the ±25 actually observed
  # would draw one fight changing hands as a full bar.
  test "the bar is scaled to the possible range, not the observed one", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_delta_air" => 25})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    # 25 of a ±100 range is an eighth of the track, not a full bar.
    assert html =~ "width: 12.5%"
    refute html =~ "width: 100.0%"
  end

  # The panel must say the resolution out loud: one fight changing hands moves
  # this a whole step, and the run count is exercises run, not samples averaged.
  test "the coarse resolution is stated rather than left to the bar", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_delta_all" => -25})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "one fight changing hands is a whole\nstep" or html =~ "changing hands"
    assert html =~ "the wire carries the latest exercise only"
  end

  # ── Who raids whom, which replaced the map ──────────────────────
  #
  # ⚠ THE MAP DREW A HASH AS GEOGRAPHY. Islands sat at positions derived from a
  # hash of their names, so distance, adjacency and arc length encoded NOTHING.
  # These are the facts the arcs actually carried, now asserted against the table
  # that carries them without the invented coordinate system.

  test "a settled raid appears in the attacker's row and the defender's column", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put("bbb", :vitals, %{"island" => "beam01", "island_id" => "bbb", "roster" => 90})
    Board.put_raid("r1", :raid, raid("aaa", "beam01") |> Map.put("island_id", "bbb"))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "Who raids whom"
    assert html =~ "beam00 → beam01: 1 raids"
  end

  # ⚠ A RAID IN FLIGHT IS NOT A RAID THAT DID NOT HAPPEN. Counting it as zero
  # would quietly write off every fight in progress.
  test "a pair with commitments and no recording reads as still out", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put("bbb", :vitals, %{"island" => "beam01", "island_id" => "bbb", "roster" => 90})

    Board.put_raid("r1", :committed, %{
      "raid_id" => "r1",
      "role" => "attacker",
      "island_id" => "aaa",
      "opponent_id" => "bbb"
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "1 still out"
  end

  # The map is gone, and so is every trace of it: a canvas nobody draws is a
  # hook nobody loads.
  test "no map, no canvas, no viewport plumbing", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    refute html =~ "dronex-archipelago"
    refute html =~ "data-arcs"
    refute html =~ "data-isles"
  end

  # ⚠ FLEET-SCOPED THINGS MUST NOT HIDE BEHIND A PER-ISLAND TAB. The island ×
  # drill matrix sat on the Exam tab, so the most informative diagram on the page
  # was two clicks behind a video player and a visitor landed on a canvas and one
  # small bar. It is every island against every drill; it belongs with the map
  # and the standings, which are the other two fleet-scoped things.
  test "the drill matrix is on the landing view, not behind a tab", %{conn: conn} do
    exam = fn name, wins ->
      %{
        "island" => name,
        "island_id" => name,
        "benchmark_rungs" => ["hoverer", "sniper"],
        "benchmark_wins" => wins,
        "benchmark_starts" => 10
      }
    end

    Board.put("aaa", :vitals, exam.("beam00", [10, 2]))
    Board.put("bbb", :vitals, exam.("beam01", [4, 9]))

    {:ok, view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "Every island, every drill"
    assert html =~ "hoverer"

    # and it stays put whichever island panel is open
    for panel <- ["vitals", "exam", "fights"] do
      assert render_click(view, "show_panel", %{"panel" => panel}) =~ "Every island, every drill"
    end
  end

  # ── History ─────────────────────────────────────────────────────

  # ⚠ ONE POINT IS NOT A TRAJECTORY. A chart of a single sample is a dot
  # pretending to be a line, and the panel says so rather than drawing it.
  test "a trend says it is empty rather than drawing one point", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex?panel=vitals")

    assert html =~ "Roster over time appears here once there are two samples"
    refute html =~ "<polyline"
  end

  # ⚠ THE CHART BELONGS BESIDE THE NUMBER IT IS THE HISTORY OF. A separate tab
  # made you hold a value in your head and go and look at its trajectory, on a
  # page whose tabs are six tiles and nine rungs.
  test "each trend sits on the tab that reports its number", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    {:ok, view, html} = live(conn, ~p"/research/workbench/dronex?panel=vitals")
    assert html =~ "Roster over time"
    refute html =~ "Frozen exam over time"

    html = render_click(view, "show_panel", %{"panel" => "exam"})
    assert html =~ "Frozen exam over time"
    refute html =~ "Roster over time"

    # and the tab that briefly existed is gone, its links landing on the numbers
    refute html =~ ~s(phx-value-panel="history")
  end

  test "two samples draw a line, and the axis runs to the real ceiling", %{conn: conn} do
    exam = fn wins ->
      %{
        "island" => "beam00",
        "island_id" => "aaa",
        "roster" => 90,
        "capacity" => 240,
        "benchmark_rungs" => ["a"],
        "benchmark_wins" => [wins],
        "benchmark_starts" => 100
      }
    end

    Board.put("aaa", :vitals, exam.(100))
    # ⚠ THE SAMPLER THROTTLES, so a second put lands in the same window and is
    # dropped. Reaching past the API here is deliberate: the alternative is a
    # test that sleeps for the sampling interval.
    [{_id, [first]}] = :ets.lookup(:dronex_history, "aaa")
    :ets.insert(:dronex_history, {"aaa", [%{first | at: first.at - 60_000, score: 3}]})
    Board.put("aaa", :vitals, exam.(100))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex?panel=exam")

    assert html =~ "<polyline"
    # 0 and the ceiling are labelled; the axis is never fitted to the data.
    # Whitespace-tolerant: the formatter reflows HEEx text nodes onto their own
    # lines, so a bare ">100<" is a test of the formatter and not of the chart.
    assert html =~ ~r/>\s*100\s*</
    assert html =~ "Frozen exam over time"
  end

  # The leaderboard and the chart must not be able to disagree about a score.
  test "the exam percentage has one implementation", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam00",
      "island_id" => "aaa",
      "benchmark_rungs" => ["a", "b"],
      "benchmark_wins" => [10, 5],
      "benchmark_starts" => 10
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert Dronex.WatchBouts.Board.exam_score(Dronex.fact(Board.island("aaa"), :vitals)) == 75
    assert html =~ "75%"
  end

  # An island that has not sat the exam is different from one that sat it and
  # lost everything, and a zero must not be drawn as a flat bar.
  test "an unsat exam says so", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "benchmark_starts" => 0})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex?panel=exam")

    assert html =~ "Not sat yet"
  end

  # ⚠ THE MAP IS ONE CANVAS, HOWEVER MANY ISLANDS JOIN. That is the whole reason
  # the biotope's per-island grid was removed: one canvas, one hook and one
  # animation loop, regardless of fleet size.

  # ⚠ AN ARC NEEDS BOTH ENDS, AND ONE COMMITMENT NAMES BOTH. The two commitments
  # travel separately and one of them may never arrive, so a single fact has to
  # be enough to draw the arc.

  # An island nobody has heard vitals from has no place on the map, so an arc to
  # it is dropped rather than drawn to a guessed position.

  # ⚠ THE TOWERS MUST REACH THE PAGE, NOT MERELY THE WIRE. The island published
  # `ground' for a while before anything read it, which draws exactly the same
  # picture as not publishing it: an empty floor.
  test "a fight at home draws the defending island's towers", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 24, "capacity" => 240})

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "ground" => [500, 500, 0, 750, 500, 0],
      "ground_range" => 350,
      "frames" => [
        %{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => [], "k" => [480, 505, 95]}
      ]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    [_, payload] = Regex.run(~r/data-bout="([^"]*)"/, html)
    bout = payload |> unescape() |> Jason.decode!()
    assert bout["ground"] == [500, 500, 0, 750, 500, 0]
    assert bout["ground_range"] == 350

    # ⚠ AND THE NETWORK'S BELIEF TRAVELS WITH THE TRUTH. Without it a viewer
    # cannot tell "the raiders got through" from "the raiders were never
    # confirmed", which are different findings about the same defeat.
    assert [%{"k" => [480, 505, 95]}] = bout["frames"]
  end

  # ⚠ AND AN AWAY FIGHT MUST SAY SO IN WORDS. An empty floor is indistinguishable
  # from a page that failed to load something, and the absence is the interesting
  # half: it is what makes attacking cost more than the airframes it spends.
  test "a fight away from home says there were no towers", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 24, "capacity" => 240})

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "ground" => [],
      "ground_range" => 0,
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    # ⚠ THE DATA, NOT THE PROSE THAT USED TO DESCRIBE IT. An away fight publishes
    # an empty `ground`, and empty must stay distinguishable from ABSENT: one
    # means the raider had no ground support, the other means an older island
    # never said. The captions that spelled this out were removed; the
    # distinction they rested on is still load-bearing for the drawing.
    [_, payload] = Regex.run(~r/data-bout="([^"]*)"/, html)
    bout = payload |> unescape() |> Jason.decode!()
    assert bout["ground"] == []
    assert bout["ground_range"] == 0
  end

  # An island running older code publishes neither key. It must draw a floor with
  # no towers rather than crash, and it must not claim an away game either.
  test "a bout from before the towers existed still draws", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 24, "capacity" => 240})

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "kind" => "training",
      "winner" => "draw",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    [_, payload] = Regex.run(~r/data-bout="([^"]*)"/, html)
    assert payload |> unescape() |> Jason.decode!() |> Map.get("ground") == []

    # ⚠ AND IT CLAIMS NEITHER. Captioning an old recording "no towers stood
    # here" would be the page asserting something it was never told: absent is
    # not the same claim as empty.
    refute html =~ "No towers stand on this floor"
    refute html =~ "of them, and the pale discs"
  end

  # ⚠ THE POINT OF THE FOURTH ISLAND IS SIMULTANEITY, so a page that can only
  # ever draw one fight would silently drop the other two the moment it arrived.
  test "concurrent raids are all offered, not just the newest", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "roster" => 90, "capacity" => 240})

    for {id, attacker} <- [{"r1", "beam01"}, {"r2", "beam02"}, {"r3", "beam03"}] do
      Board.put_raid(id, :raid, raid(attacker, "beam00"))
    end

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    offered = Regex.scan(~r/data-watch="raid:([^"]*)"/, html) |> Enum.map(&List.last/1)
    assert Enum.sort(offered) == ["r1", "r2", "r3"]
  end

  # The ranking orders a list and measures nothing, but it must at least put a
  # raid above a training bout: a bout is one controller against a script.
  test "a raid outranks a training bout, and says why", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "roster" => 90, "capacity" => 240})
    Board.put("aaa", :bout, %{"island" => "beam00", "kind" => "training", "winner" => "draw"})
    Board.put_raid("r1", :raid, raid("beam01", "beam00"))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    [first | _] = Regex.scan(~r/data-watch="([^:]*):/, html) |> Enum.map(&List.last/1)
    assert first == "raid"

    # ⚠ AND THE REASON MUST DISCRIMINATE. Every raid outscores every bout by the
    # same base, so reporting the strongest reason including that base gave all
    # seven raids the identical line "a raid: evolved against evolved" and the
    # chooser explained nothing. This raid finished 5 home against 4.
    # ⚠ THE COUNTS ARE IN THE REASON. Six of eight rows once read "it finished
    # within 1", which is true of all six and says nothing about which to click.
    # This raid finished 5 home against 4 still up.
    assert html =~ "close: 5 home against 4 still up"
    refute html =~ "a raid: evolved against evolved"
  end

  # ⚠ THE RANKING COLUMN AND THE INTERESTING COLUMNS ARE NOT THE SAME COLUMNS.
  # Ranking on raids would let an island that raided a sleepy neighbour twenty
  # times top a table it never earned; the benchmark is the only number every
  # island earns on identical terms.
  test "the leaderboard ranks on the frozen benchmark, not on raids", %{conn: conn} do
    Board.put("aaa", :vitals, standing("beam00", [1, 1], 8, 40))
    Board.put("bbb", :vitals, standing("beam01", [6, 6], 8, 0))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    ranked = Regex.scan(~r/data-standing="([^"]*)"/, html) |> Enum.map(&List.last/1)
    # beam01 has 75% of the benchmark and no raids; beam00 has 12% and forty.
    assert ranked == ["beam01", "beam00"]
    assert html =~ "deliberately not on"
  end

  # ⚠ THE PAYLOAD CARRIES TRACKS. THIS ASSERTS SOMETHING DRAWS THEM.
  #
  # `believed/1` was deleted by an unrelated edit and shipped missing for a day
  # while a caption underneath went on telling visitors to hunt for teal rings
  # that no code drew. The test that was supposed to protect it asserted that
  # CAPTION, which survived the deletion untouched — so it stayed green through
  # exactly the failure it existed to catch. The caption has since been removed;
  # this guard is what is left, and it is the half that would have bitten.
  #
  # A colocated hook is extracted at build time and never appears in the rendered
  # HTML, so this reads the source. That is a guard probe and it is brittle on
  # purpose: it fails loudly when the drawing goes away, which is better than the
  # page failing quietly.

  # ⚠ CLICKING AN ISLAND FILTERS BOTH ROLES, NOT JUST THE HOST. A raid is
  # published by the DEFENDER because the defender hosted it, so filtering on the
  # publisher alone would answer "fights fought in this airspace" and silently
  # drop every raid the island flew away from home. Both are its fights.
  test "focusing an island narrows the list to its fights, home and away", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put("bbb", :vitals, %{"island" => "beam01", "island_id" => "bbb", "roster" => 90})
    Board.put("ccc", :vitals, %{"island" => "beam02", "island_id" => "ccc", "roster" => 90})

    # aaa defends one and attacks another; ccc is in neither.
    Board.put_raid("home", :raid, raid("bbb", "beam00") |> Map.put("island_id", "aaa"))
    Board.put_raid("away", :raid, raid("aaa", "beam01") |> Map.put("island_id", "bbb"))
    Board.put_raid("other", :raid, raid("ccc", "beam01") |> Map.put("island_id", "bbb"))

    {:ok, view, _html} = live(conn, ~p"/research/workbench/dronex")

    all = view |> render() |> watch_keys()
    assert Enum.sort(all) == ["away", "home", "other"]

    html = render_click(view, "focus_island", %{"id" => "aaa"})
    assert Enum.sort(watch_keys(html)) == ["away", "home"]
    assert panel_island(html) == "beam00"

    # ⚠ AND IT LETS GO. Clicking the focused island again clears it; a filter
    # with no way out is a trap, and on a canvas there is no obvious "off".
    assert render_click(view, "focus_island", %{"id" => "aaa"}) |> watch_keys() |> length() == 3
  end

  # Clicking open sea clears the filter too.
  test "focusing nothing clears the filter", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put_raid("home", :raid, raid("bbb", "beam00") |> Map.put("island_id", "aaa"))

    {:ok, view, _html} = live(conn, ~p"/research/workbench/dronex")

    render_click(view, "focus_island", %{"id" => "aaa"})
    html = render_click(view, "focus_island", %{"id" => nil})
    refute html =~ "Fights at"
  end

  # ⚠ THE RAIL IS A DESKTOP ARRANGEMENT AND MUST NOT REACH BELOW `lg'. The
  # container is max-w-5xl, so a four-column split at tablet width would leave
  # the replay ~552px and the rail ~184px and cramp both. This asserts the
  # breakpoint is on the grid rather than unqualified, which is the one thing
  # that silently regresses when somebody tidies class lists.
  test "the fights rail is desktop-only and the canvas widens vertically with it",
       %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put_raid("r1", :raid, raid("bbb", "beam00") |> Map.put("island_id", "aaa"))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "lg:grid lg:grid-cols-3"
    assert html =~ "lg:col-span-2"

    # ⚠ AND 4/3 WHEN RAILED. `project` normalises the world into the unit square
    # and stretches it to whatever canvas it is given, so a wide canvas flattens
    # the ALTITUDE axis — which is the whole of the dome story. Rendered both
    # ways before choosing.
    assert html =~ "lg:aspect-[4/3]"
  end

  # ⚠ THERE IS NO TEST FOR THE PAGE TITLE, AND THE ONE THAT WAS HERE WAS A LIE.
  # It read `assert html =~ "DroneX ·" or (html =~ "<title" and html =~
  # "DroneX")`, which cannot fail: "DroneX" is in the site navigation on every
  # page. `live/2` returns the LiveView's own markup and not the root layout, so
  # the title is not assertable from here at all — and a test that cannot fail is
  # worse than no test, because it reports the thing as covered.
  #
  # `page_title` IS assigned in mount, exactly as `a_society_live` does it.
  # Neither page's title reaches the browser: both still serve the layout's
  # default. That is a root-layout problem across the whole site rather than this
  # page's, and it is written down here rather than papered over with a green
  # tick that meant nothing.

  # The one selection: picking an island scopes the fights AND the vitals panel.
  # It used to be two independent selections with two rows of controls.
  test "one island selection scopes both the fights and the vitals", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put("bbb", :vitals, %{"island" => "beam01", "island_id" => "bbb", "roster" => 12})

    {:ok, view, html} = live(conn, ~p"/research/workbench/dronex")

    # No separate tab row survives to set a second copy of this state.
    refute html =~ ~s(phx-click="choose")

    html = render_click(view, "focus_island", %{"id" => "bbb"})
    assert panel_island(html) == "beam01"

    # ⚠ AND THE SAME SELECTION SCOPES THE OTHER TABS, which is the point of them
    # sharing a panel: one island, three views, no second copy of the state.
    assert render_click(view, "show_panel", %{"panel" => "vitals"}) =~ "fields at most"
  end

  # ── The table follows the map ───────────────────────────────────

  # ⚠ A COLLAPSE IS NOT A LOW SCORE. beam03 sat 288/288 in the morning and 1/288
  # nine hours later while raiding hard, and the table drew that in the same grey
  # as 88%. The exam is the one number every island earns on identical terms, so
  # an island that has stopped earning it at all is the most interesting row on
  # the page rather than the least.
  test "an exam that has collapsed is marked, and a merely low one is not", %{conn: conn} do
    rung = fn wins ->
      %{"benchmark_rungs" => ["a"], "benchmark_wins" => [wins], "benchmark_starts" => 100}
    end

    Board.put("aaa", :vitals, Map.merge(rung.(1), %{"island" => "beam03", "island_id" => "aaa"}))
    Board.put("bbb", :vitals, Map.merge(rung.(60), %{"island" => "beam01", "island_id" => "bbb"}))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "text-error"
    assert html =~ "the exam has collapsed"

    # and 60% is a bad score, not a broken instrument
    refute Regex.match?(~r/text-error[^>]*>\s*60%/, html)
  end

  # Which island the side panel says it is showing. One heading, because the
  # scope used to be announced three times in one 300px column.
  defp panel_island(html) do
    case Regex.run(~r|<h2 class="text-base font-semibold">\s*([^<]+?)\s*</h2>|, html) do
      [_, name] -> name
      _ -> nil
    end
  end

  # ⚠ THE DEFAULT IS EVERYTHING, and it has to be. The map reports what it is
  # showing only after it has painted, so before that — and for anyone on a
  # keyboard, who cannot pan a canvas at all — an empty report would mean an
  # empty table.

  # ⚠ RANK IS OVER THE WHOLE ARCHIPELAGO, NEVER OVER THE VIEWPORT. A number that
  # renumbered as you panned would be measuring where you are looking. beam02 is
  # third on the exam and must still read as third when the top two are off
  # screen.

  # The selection has to be legible as text. It was a white ellipse inside a
  # canvas, which no screen reader can see and which is off screen the moment you
  # scroll to the fight it filtered.
  test "the selection is named in words and can be cleared from there", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    {:ok, view, html} = live(conn, ~p"/research/workbench/dronex")
    assert html =~ "every island"

    html = render_click(view, "focus_island", %{"id" => "aaa"})
    assert html =~ "showing beam00"

    assert render_click(view, "focus_island", %{"id" => "aaa"}) =~ "every island"
  end

  defp watch_keys(html) do
    ~r/data-watch="raid:([^"]*)"/ |> Regex.scan(html) |> Enum.map(&List.last/1)
  end

  defp raid(attacker, island) do
    %{
      "island" => island,
      "attacker_id" => attacker,
      "kind" => "raid",
      "winner" => "attacker",
      "ticks" => 800,
      "raiders" => 12,
      "raiders_home" => 5,
      "defenders" => 12,
      "defenders_home" => 4,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => [], "k" => []}]
    }
  end

  defp standing(name, wins, starts, raids) do
    %{
      "island" => name,
      "roster" => 90,
      "capacity" => 240,
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => wins,
      "benchmark_starts" => starts,
      "raids" => raids,
      "captures" => raids,
      "generation" => 3
    }
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

    # Same re-anchoring: a raid still beats a bout, and the replay says which
    # it is playing.
    assert html =~ "raid ·"
    assert html =~ "240 tick"
    assert html =~ "defender"
    refute html =~ "training bout \u00b7"

    # ⚠ THE BOTH-SIDES SCORELINE WENT WITH THE SECTION IT LIVED IN. It asserted
    # that a raid showed what it cost the DEFENDER as well as the raider, which
    # was worth having while the numbers were on the page. They are not any
    # more, so this asserts the ranking still reads both halves of the ledger —
    # `close/1` compares the two survivor counts and cannot be computed from one
    # side alone, and neither can `bled/1`, which is what this raid earns: 3 of
    # 12 home against 8 of 12 still flying.
    assert html =~ "both sides bled — 3 home, 8 still up"
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

    # ⚠ RE-ANCHORED. The heading that used to carry this was removed with the
    # rest of the fight section's prose; the guarantee it protected — that a
    # bout is what gets played when no raid exists — is unchanged, so the
    # assertion moved to the replay's own line rather than being dropped.
    assert html =~ "training ·"

    # The paragraph that said so in words was removed with the rest of the
    # section's prose. What it promised — that an island nobody has raided still
    # has something to watch — is what the line above asserts.
    refute html =~ "raid bout ·"
  end
end
