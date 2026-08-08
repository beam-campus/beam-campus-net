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

    # ⚠ EXAM IS THE DEFAULT NOW, AND FIGHTS WAS. Fights was the default because
    # it was the chooser for the canvas beside it; the canvas has its own route,
    # so the default is the panel this page is actually about.
    # ⚠ NOT A RUNG NAME. The drill names appear on the landing view as the
    # matrix's column headings, so "hoverer" does not distinguish a tab from the
    # page around it. This asserts on what is unique to each panel.
    assert html =~ "Six scripted drills"
    refute html =~ "fields at most"

    html = render_click(view, "show_panel", %{"panel" => "vitals"})
    assert html =~ "fields at most"
    refute html =~ "Six scripted drills"

    html = render_click(view, "show_panel", %{"panel" => "exam"})
    assert html =~ "Six scripted drills"
    refute html =~ "fields at most"
  end

  # ⚠ THE PLAYER HAS EXACTLY ONE HOME, AND THIS TEST HAS NOW MOVED IT TWICE.
  # It first asserted the fight was always visible, then that it belonged to the
  # Fights TAB, and now that it belongs to the fights ROUTE. The finding under
  # all three is the same one: a page that draws the fight is paying for a 1.2 MB
  # recording, so exactly one page should, and it should be the page a visitor
  # opened in order to watch a fight.
  #
  # The earlier reasoning — that a raid is about two islands and must not be
  # filed under one — is still true and is not what this decides. The fights
  # route holds a LIST of fights, which is participation rather than ownership.
  test "the player is not on the landing view at all", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put_raid("r1", :raid, raid("bbb", "beam00") |> Map.put("island_id", "aaa"))

    {:ok, view, html} = live(conn, ~p"/research/workbench/dronex")
    refute html =~ "dronex-replay"

    for panel <- ["vitals", "exam"] do
      refute render_click(view, "show_panel", %{"panel" => panel}) =~ "dronex-replay"
    end

    # And the route that does hold it says so in the nav.
    assert html =~ "/research/workbench/dronex/fights"
  end

  # ⚠ "LOST IT" AND "DREW IT" WERE THE SAME CELL. On a graded ladder those are
  # different findings: a drone that draws the sniper held station and could not
  # finish; one that lost it was killed.
  test "a ladder cell distinguishes a draw from a loss", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam00",
      "island_id" => "aaa",
      "benchmark_rungs" => ["sniper"],
      "benchmark_wins" => [2],
      "benchmark_draws" => [5],
      "benchmark_losses" => [3],
      "benchmark_starts" => 10
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "beam00: 2 won, 5 drawn, 3 lost of 10"
  end

  # ⚠ AN ISLAND SITTING A CAPTURED CHAMPION IS NOT REPORTING ITS OWN BREEDING.
  test "an island whose exam was sat by a captured genome is badged", %{conn: conn} do
    base = %{
      "benchmark_rungs" => ["sniper"],
      "benchmark_wins" => [9],
      "benchmark_starts" => 10
    }

    Board.put(
      "aaa",
      :vitals,
      Map.merge(base, %{
        "island" => "beam00",
        "island_id" => "aaa",
        "benchmark_sitter" => "captured"
      })
    )

    Board.put(
      "bbb",
      :vitals,
      Map.merge(base, %{"island" => "beam01", "island_id" => "bbb", "benchmark_sitter" => "bred"})
    )

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "captured, not one it bred"
    # exactly one island carries it
    assert length(Regex.scan(~r/captured, not one it bred/, html)) == 1
  end

  # ⚠ THREE SECTIONS LEFT THIS FILE AND THEIR HEADINGS WENT WITH THEM.
  # Breeding-longer-wins-wars and who-raids-whom are in
  # `DronexRaidsLiveTest`; does-the-radio-matter is in `DronexRadioLiveTest`.
  # A heading left behind would claim this file still covers them.

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

  # ⚠⚠ TWO ISLANDS MAY CALL THEMSELVES THE SAME THING, and in an archipelago
  # meant to admit strangers they eventually will. `dronex_identity' says so in
  # its own header: "Anyone may type your island's name into their own config".
  #
  # The board always kept them apart, because every row is keyed on `island_id'.
  # It was THIS PAGE that merged them, by never rendering an id anywhere, so two
  # correct and separate rows were byte-identical on screen and a reader saw one
  # island contradicting itself.
  #
  # The fixtures elsewhere in this file use ids of three characters, which is
  # shorter than a mark, so they never exercised this. These are real ones.
  test "two islands with one name are told apart on the page", %{conn: conn} do
    first = "a6b1605a0f8f82d8dde1bfa260e41168"
    second = "e649229946edce4883dec30091566da5"

    Board.put(first, :vitals, %{"island" => "beam01", "island_id" => first, "roster" => 90})
    Board.put(second, :vitals, %{"island" => "beam01", "island_id" => second, "roster" => 90})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "a6b1"
    assert html =~ "e649"
  end

  # And the mark rides along in the text-only places too, where markup cannot go.
  test "the panel heading names the island and says which one", %{conn: conn} do
    id = "a6b1605a0f8f82d8dde1bfa260e41168"
    Board.put(id, :vitals, %{"island" => "beam01", "island_id" => id, "roster" => 90})

    {:ok, view, _html} = live(conn, ~p"/research/workbench/dronex")

    assert panel_island(render_click(view, "focus_island", %{"id" => id})) == "beam01 a6b1"
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
  # ⚠ FOUND BY A DATA HOOK, NOT BY ITS CLASSES. A class-based match finds whichever
  # section was added to the page most recently, and it picked up "How long a fight
  # lasts" the moment that instrument landed above the panel.
  #
  # ⚠⚠ AND IT HOLDS MARKUP, so this strips tags rather than refusing to
  # match them. An island's name is rendered beside the four characters of its id
  # that say WHICH island, in its own muted span, so `[^<]+' stopped matching the
  # moment names stopped being bare text.
  defp panel_island(html) do
    case Regex.run(~r|<h2 data-panel-heading[^>]*>(.*?)</h2>|s, html) do
      [_, inner] -> inner |> String.replace(~r|<[^>]*>|, "") |> squashed()
      _ -> nil
    end
  end

  defp squashed(text), do: text |> String.replace(~r|\s+|, " ") |> String.trim()

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

  # ── The held-out exam ───────────────────────────────────────────

  # ⚠⚠ TWO MATRICES OF THE SAME SHAPE THAT MEAN OPPOSITE THINGS. `REGISTER I.22`:
  # the `benchmark_*` rungs are six of the opponents each island BREEDS against,
  # so a high score there is familiarity as much as skill. The `trials_*` rungs
  # are held out and nothing trains on them. A page that drew both without saying
  # which was which would be worse than a page that drew neither.
  test "both exams are drawn, and each says which one it is", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam00",
      "island_id" => "aaa",
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => [48, 48],
      "benchmark_starts" => 48,
      "trials_rungs" => ["circler", "leader"],
      "trials_wins" => [48, 26],
      "trials_starts" => 48
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    # Both ladders reached the page, under their own rung names.
    assert html =~ "hoverer"
    assert html =~ "circler"
    assert html =~ "Every island, every held-out rung"
    assert html =~ "Every island, every drill"

    # And the contaminated one is labelled as such rather than left to be read
    # as an achievement.
    assert html =~ "breeds against"
    assert html =~ "Nothing trains against these"
  end

  # ⚠ AN ISLAND ON AN OLDER BUILD PUBLISHES NO HELD-OUT PROFILE AT ALL, and
  # islands roll one at a time. A page that required the new fields would go
  # blank for half a fleet mid-deploy, which is the failure this whole track
  # keeps paying for in one costume or another.
  test "an island that publishes no held-out exam still draws its curriculum one", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam00",
      "island_id" => "aaa",
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => [40, 9],
      "benchmark_starts" => 48
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "Every island, every drill"
    assert html =~ "hoverer"
    refute html =~ "Every island, every held-out rung"
  end
end
