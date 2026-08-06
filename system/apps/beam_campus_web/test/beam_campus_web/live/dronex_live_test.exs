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
    assert html =~ "it finished within 1"
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
  test "the replay hook actually draws the tracks it is sent" do
    src = File.read!("lib/beam_campus_web/live/dronex_live.ex")

    # A function that consumes the per-frame track array...
    assert src =~ "believed(f) {"
    assert src =~ "f.k"
    # ...and a call site, because a defined-and-uncalled function draws nothing.
    assert src =~ "this.believed(f)"
    # And the masts, which vanished into the drone layer when drawn first.
    assert src =~ "this.masts()"
  end

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
    assert html =~ "Fights at beam00"

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
    assert html =~ "raid bout ·"
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
    assert html =~ "both sides lost airframes"
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
    assert html =~ "training bout ·"

    # The paragraph that said so in words was removed with the rest of the
    # section's prose. What it promised — that an island nobody has raided still
    # has something to watch — is what the line above asserts.
    refute html =~ "raid bout ·"
  end
end
