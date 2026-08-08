defmodule BeamCampusWeb.DronexFightsLiveTest do
  @moduledoc """
  The fights view: the recording player, its chooser and the fight-derived
  summaries.

  ⚠ **ITS OWN FILE BECAUSE IT IS ITS OWN ROUTE.** These moved here whole from
  `DronexLiveTest` when `/dronex` became four pages. Only the URL changed, and
  in two cases the tab-click that used to reach the player is now the route
  itself. Every assertion and the comment above it is the one that was there.
  """
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

  defp squashed(text), do: text |> String.replace(~r|\s+|, " ") |> String.trim()

  defp unescape(s) do
    s
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&#39;", "'")
  end

  # ⚠ IT SAYS WHAT IT IS. Nothing crosses the mesh yet, so a fight drawn here is
  # an island against its own drill. Calling it a raid would be the first lie
  # this track told, and the fact carries `kind` precisely so the page cannot.
  test "a published bout is drawn and named as a training bout", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam01",
      # ⚠ EVERY REAL FACT CARRIES ITS island_id AND THESE FIXTURES DID NOT. On
      # the landing page the island's name came from a per-island heading, so the
      # omission never showed. This route names the island through the fight's
      # own title, which is built from `island_id`, so a fixture without one was
      # asking the page to do something no real fact would ever ask of it.
      "island_id" => "aaa",
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
      "island_id" => "aaa",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

    assert html =~ "training"
    # The page speaks raider/island now; `attacker` stays on the wire only.
    assert html =~ "raider won"
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

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

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

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

    assert html =~ "What the towers hold, by altitude"
    assert html =~ "0–50 m"
    # Held in both frames, and the denominator is on the row.
    assert html =~ "n=2"
    # ⚠ AND THE FLEET COUNT, because these are accumulations over a rolling
    # window rather than a sample anybody chose.
    assert html =~ "1 raids"
  end

  # ⚠ THE POINT OF THE FOURTH ISLAND IS SIMULTANEITY, so a page that can only
  # ever draw one fight would silently drop the other two the moment it arrived.
  test "concurrent raids are all offered, not just the newest", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "roster" => 90, "capacity" => 240})

    for {id, attacker} <- [{"r1", "beam01"}, {"r2", "beam02"}, {"r3", "beam03"}] do
      Board.put_raid(id, :raid, raid(attacker, "beam00"))
    end

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

    offered = Regex.scan(~r/data-watch="raid:([^"]*)"/, html) |> Enum.map(&List.last/1)
    assert Enum.sort(offered) == ["r1", "r2", "r3"]
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
      "island_id" => "aaa",
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

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

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
      "island_id" => "aaa",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

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

    {:ok, view, _html} = live(conn, ~p"/research/workbench/dronex/fights")

    all = view |> render() |> watch_keys()
    assert Enum.sort(all) == ["away", "home", "other"]

    html = render_click(view, "focus_island", %{"id" => "aaa"})
    assert Enum.sort(watch_keys(html)) == ["away", "home"]
    # ⚠ THE SAME INTENT, IN THIS PAGE'S OWN WORDS. On the landing view the
    # focused island is named in a per-island panel heading, which this route
    # does not have and should not: there is no such thing as "this island's
    # fight" when two islands raided each other in the same minute. Here the
    # selection is named on the badge above the player.
    assert html =~ "fights involving"

    # ⚠ AND IT LETS GO. Clicking the focused island again clears it; a filter
    # with no way out is a trap, and on a canvas there is no obvious "off".
    assert render_click(view, "focus_island", %{"id" => "aaa"}) |> watch_keys() |> length() == 3
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

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

    assert html =~ "lg:grid lg:grid-cols-3"
    assert html =~ "lg:col-span-2"

    # ⚠ AND 4/3 WHEN RAILED. `project` normalises the world into the unit square
    # and stretches it to whatever canvas it is given, so a wide canvas flattens
    # the ALTITUDE axis — which is the whole of the dome story. Rendered both
    # ways before choosing.
    assert html =~ "lg:aspect-[4/3]"
  end

  # An island running older code publishes neither key. It must draw a floor with
  # no towers rather than crash, and it must not claim an away game either.
  test "a bout from before the towers existed still draws", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 24, "capacity" => 240})

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "island_id" => "aaa",
      "kind" => "training",
      "winner" => "draw",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

    [_, payload] = Regex.run(~r/data-bout="([^"]*)"/, html)
    assert payload |> unescape() |> Jason.decode!() |> Map.get("ground") == []

    # ⚠ AND IT CLAIMS NEITHER. Captioning an old recording "no towers stood
    # here" would be the page asserting something it was never told: absent is
    # not the same claim as empty.
    refute html =~ "No towers stand on this floor"
    refute html =~ "of them, and the pale discs"
  end

  # The ranking orders a list and measures nothing, but it must at least put a
  # raid above a training bout: a bout is one controller against a script.
  test "a raid outranks a training bout, and says why", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "roster" => 90, "capacity" => 240})
    Board.put("aaa", :bout, %{"island" => "beam00", "kind" => "training", "winner" => "draw"})
    Board.put_raid("r1", :raid, raid("beam01", "beam00"))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

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

  # ⚠ THE TOWERS MUST REACH THE PAGE, NOT MERELY THE WIRE. The island published
  # `ground' for a while before anything read it, which draws exactly the same
  # picture as not publishing it: an empty floor.
  test "a fight at home draws the defending island's towers", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 24, "capacity" => 240})

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "island_id" => "aaa",
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

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

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
      "island_id" => "aaa",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "ground" => [],
      "ground_range" => 0,
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/fights")

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
end
