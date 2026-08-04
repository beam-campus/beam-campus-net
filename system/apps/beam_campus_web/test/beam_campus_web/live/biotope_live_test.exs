defmodule BeamCampusWeb.BiotopeLiveTest do
  @moduledoc """
  The page with no mesh behind it, and the page with facts on the board.

  An unconfigured site must serve a working page: that is how it renders in dev,
  in CI, and for anyone who clones the repo.
  """
  # NOT async. The board is one ETS table for the whole node, so tests that write
  # to it are not independent.
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Biotope.WatchIslands.Board

  setup do
    if :ets.info(:biotope_board) == :undefined, do: Board.init()
    :ets.delete_all_objects(:biotope_board)
    :ok
  end

  test "renders with nothing at all", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "Biotopes"
    # Not configured in test, and the page says which kind of quiet it is rather
    # than one apologetic sentence for both.
    assert html =~ "not configured to read islands"
  end

  # ⚠ THE CLAIM THE WHOLE TRACK RESTS ON, ASSERTED RATHER THAN HOPED FOR.
  #
  # The world is the sum of the nodes. If two islands land on one map at the
  # same place, or the map holds only one of them, the page is saying the
  # opposite of what the charter says and nothing else would notice: every
  # island's own panel would still render perfectly.
  test "two islands land on ONE map, in different places", %{conn: conn} do
    for name <- ["beam01", "beam03"] do
      Board.put_chart(%{
        "island" => name,
        "tick" => 10,
        "radius" => 20,
        "stride" => 2,
        "creatures" => [0, 0],
        "ground" => [2, 0, 400],
        "water" => [3, 0],
        "water_stride" => 2
      })
    end

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    [_, isles] = Regex.run(~r/data-isles="([^"]*)"/, html)
    isles = isles |> unescape() |> Jason.decode!()

    assert length(isles) == 2
    assert Enum.map(isles, & &1["name"]) |> Enum.sort() == ["beam01", "beam03"]

    # Distinct ground, or they are drawn on top of each other and the map is a
    # lie told in one place instead of three.
    assert isles |> Enum.map(&{&1["x"], &1["y"]}) |> Enum.uniq() |> length() == 2
  end

  # And a name with no picture yet is a name, not a place. Drawing an empty disc
  # for an island that has announced itself and published nothing would say it
  # is barren when it is only silent.
  test "an island that has sent no chart is not drawn on the map", %{conn: conn} do
    Board.put_stats(%{"island" => "beam02", "tick" => 1, "population" => 5})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    refute html =~ "data-isles"
  end

  test "draws an island from its facts", %{conn: conn} do
    Board.put_stats(%{
      "island" => "beam01",
      "tick" => 412,
      "population" => 78,
      "ground_total" => 42_000,
      "still_pct" => 61,
      "ground_spread" => 17,
      "movers" => 70,
      "breeders" => 66,
      "hidden_mean" => 140,
      "absorbed" => 9100,
      "energy_total" => 5882,
      "born" => 249,
      "starved" => 171,
      "aged_out" => 0,
      "births_refused" => 0
    })

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 20,
      "stride" => 2,
      "creatures" => [0, 0, 1, -1],
      "ground" => [2, 0, 400],
      "water" => [3, 0, 3, 1],
      "water_stride" => 2
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "beam01"
    assert html =~ "412"
    assert html =~ "78"

    # The board is a canvas fed by packed numbers. Two creatures at four values
    # each, one ground cell at four, and the green is an integer now rather than
    # a colour string, because markup is the wrong carrier for a particle field.
    assert html =~ "<canvas"
    [_, creatures] = Regex.run(~r/data-creatures="([^"]*)"/, html)
    [_, ground] = Regex.run(~r/data-ground="([^"]*)"/, html)
    # SIX values per creature: id, x, y, radius, feeding colour, kind colour.
    # Both colourings travel in one frame so pressing K is a repaint and not a
    # refetch, and a viewer never asks the island for a different picture of the
    # same moment.
    assert length(Jason.decode!(creatures)) == 12
    assert [_x, _y, 0x2F7D52, _alpha] = Jason.decode!(ground)

    # ⚠ AND THE WATER, WHICH TOOK TWO WORLDS TO REACH THIS PAGE. World 23 was
    # entirely about water and put it on no wire at all; world 24 added it to the
    # island's own chart and it still was not on the mesh fact this page reads.
    # Position only, stride two: a cell is wet or it is not, so two cells are
    # four numbers and there is no amount to shade.
    [_, water] = Regex.run(~r/data-water="([^"]*)"/, html)
    assert length(Jason.decode!(water)) == 4
  end

  # ⚠ PAINT ORDER IS A CORRECTNESS PROPERTY AND NOT A MATTER OF TASTE.
  #
  # The ground is painted for every cell holding energy, at an alpha running to
  # 0.65, so water underneath it is invisible: green over blue reads as green.
  # The first version painted water first, reasoning that water is the landscape
  # and the ground grows on it, which is true and produced a live board with no
  # lakes and no rivers on it while the arrays were on the wire, decoded, and
  # painted.
  #
  # Nothing else could have caught that. Every test passed and the data was
  # correct at every step; the only symptom was a picture a person had to look
  # at. So the order is asserted where it lives, in the painter's source.
  test "water is painted over the ground and under the living" do
    src = File.read!("lib/beam_campus_web/live/biotope_components.ex")
    ground = :binary.match(src, "this.ground.length") |> elem(0)
    water = :binary.match(src, "this.water.length") |> elem(0)

    # ⚠ ANCHORED ON THE PAINTING LOOP BY NAME, not by position. There are two
    # loops over creatures: one remembers positions so the next frame can tween
    # from them, and one paints. Here the painter is the SECOND; in the island's
    # own copy of this hook it is the FIRST, so neither "first" nor "last" is a
    # rule that holds. Both were tried and both were wrong somewhere.
    {creatures, _} = :binary.match(src, "const colour = css(this.creatures")

    assert water > ground
    assert water < creatures
  end

  # Counts arrive on their own clock and a picture may be switched off entirely,
  # which is what a headless island does. The page must say so rather than draw
  # an empty disc that looks like an island where everything died.
  # A fleet is redeployed one node at a time, so during a rollout two cards
  # genuinely show different physics. The econ id cannot say this: world 6
  # changed the rules and not one constant, so two islands a world apart share
  # an econ id exactly.
  test "says which world an island is running, in words", %{conn: conn} do
    Board.put_stats(%{
      "island" => "beam01",
      "tick" => 9,
      "population" => 3,
      "world" => 6,
      "world_line" => "A creature has a lunchbox and a body."
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "world 6"
    assert html =~ "A creature has a lunchbox and a body."
  end

  # MOST PEOPLE LAND HERE, so the terms have to be explained here. Half of them
  # this project made up and the other half mean something narrower than they do
  # in ordinary use, and a `title` attribute is invisible on a touch screen.
  #
  # `founder lines` is the one that actively misleads: it reads as a count of
  # KINDS and it is a count of ANCESTORS. Two creatures in one line can be far
  # less alike than two in different ones, and a line can never split, so it is
  # not a species by any definition and must not be labelled as one.
  test "explains its terms on the page people land on", %{conn: conn} do
    Board.put_stats(%{
      "island" => "beam01",
      "tick" => 9,
      "population" => 3,
      "depth" => 2,
      "lineages" => 1,
      "from_creatures_pct" => 21
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "founder lines"
    assert html =~ "Ancestry, not kind"
    refute html =~ "species"

    for term <- ["tick", "generations", "meat"], do: assert(html =~ term)
  end

  # A TICK THAT DROPS BACK TO NOTHING IS A NEW WORLD, NOT A GLITCH. Without this
  # the only visible sign that an island began again is the clock running
  # backwards, which reads as the page being broken.
  test "says so when an island has begun a new world", %{conn: conn} do
    Board.put_stats(%{
      "island" => "beam03",
      "tick" => 12,
      "population" => 40,
      "run" => 3,
      "previous_end" => 630
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "world number 3"
    assert html =~ "ended at tick 630"
    assert html =~ "stays ended"
  end

  # A fleet that has never lost a world says nothing about runs at all.
  test "stays quiet about runs on a first world", %{conn: conn} do
    Board.put_stats(%{"island" => "beam01", "tick" => 9, "population" => 3, "run" => 1})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    refute html =~ "world number"
  end

  # THE PAGE IS 700 KILOBYTES AND THE FLEET SPEAKS SIX TIMES A SECOND. Every fact
  # used to redraw three discs of ~2,600 circles, twelve charts and a table, per
  # viewer. That is what "the site crashes sometimes" was: nothing crashed, the
  # socket simply could not keep up, dropped, and the client showed its reconnect
  # banner.
  #
  # Asserted as ONE redraw for many facts rather than as a duration, because the
  # claim is that facts are absorbed and not that any particular millisecond
  # elapses.
  test "absorbs a burst of facts into a single redraw", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/research/workbench/biotope")

    for tick <- 1..20 do
      Board.put_stats(%{"island" => "beam01", "tick" => tick, "population" => tick})
      send(view.pid, {:biotope, :changed, "beam01"})
    end

    # Nothing has been drawn from those yet: the page still shows the state it
    # mounted with, and one timer is in flight for all twenty.
    refute render(view) =~ ">20<"

    Process.sleep(700)
    assert render(view) =~ "20"
  end

  # An island on an older build sends no world number. Naming one would be a
  # guess, and a guess about which experiment produced a picture is the one
  # thing this page must never make.
  test "says nothing about the world when an island does not send one", %{conn: conn} do
    Board.put_stats(%{"island" => "beam02", "tick" => 9, "population" => 3})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "beam02"
    # The label itself, not the word: the page's own prose says "world" in
    # several places and a looser check would pass for the wrong reason.
    refute html =~ ~s(text-primary">world)
  end

  test "says so when an island sends counts but no picture", %{conn: conn} do
    Board.put_stats(%{
      "island" => "beam02",
      "tick" => 9,
      "population" => 40,
      "ground_total" => 51_000,
      "still_pct" => 44,
      "ground_spread" => 22,
      "movers" => 40,
      "breeders" => 38,
      "hidden_mean" => 90,
      "absorbed" => 4400,
      "energy_total" => 3200,
      "born" => 0,
      "starved" => 0,
      "aged_out" => 0,
      "births_refused" => 0
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "beam02"
    assert html =~ "Counts but no picture"
  end

  # NAVIGATION IS ONE FEATURE WITH TWO FACES. Before the switch existed the
  # history page linked back here and this one linked nowhere, so the history was
  # reachable only by someone who already knew the URL. A one-way link is not
  # navigation.
  test "offers both faces and a way back up", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ ~s|href="/research/workbench/biotope/history"|
    assert html =~ ~s|href="/research/workbench"|
    # The page says which of the two it is, for a screen reader as well as an eye.
    assert html =~ ~s|aria-current="page"|
  end

  # THE PAGE MUST CARRY THE SITE, not just its own content. Both biotope pages
  # shipped without `<Layouts.app>`, so they rendered with no header, no nav, no
  # theme toggle and no footer: the content looked right in a curl and the page
  # was a dead end in a browser. Asserting on a nav item that belongs to the
  # layout and not to this page is what catches that.
  test "renders inside the site layout", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "Robo Rumble"
    assert html =~ ">Workbench<"
  end

  # WITHOUT THIS A DEAD ISLAND IS INVISIBLE. The board keeps the last fact
  # forever, so an island whose world stopped, or whose transport did, goes on
  # showing its final frame with a tick that never advances. At one island you
  # would notice. At six you would not.
  test "says which islands are still talking", %{conn: conn} do
    Board.put_stats(%{"island" => "beam01", "tick" => 1, "population" => 5, "plants" => 5})
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "live"
  end

  # PAGING APPEARS ONLY WHEN IT IS NEEDED, so two islands see no pager at all
  # and fifty are readable. Discs are about a hundred and eighty circles each.
  test "shows no pager for a single page", %{conn: conn} do
    Board.put_stats(%{"island" => "beam01", "tick" => 1, "population" => 5, "plants" => 5})
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    refute html =~ "page 1 of"
  end

  test "pages once there are more islands than fit", %{conn: conn} do
    for n <- 1..8 do
      Board.put_stats(%{"island" => "beam#{n}", "tick" => n, "population" => n, "plants" => n})
    end

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "page 1 of 2"
    assert html =~ "next"
    # Six on the first page, so the seventh and eighth are not.
    assert html =~ "beam6"
    refute html =~ "beam7"
  end

  # Each card is a way in. Before this the only view was every island stacked on
  # one page, which stops being readable somewhere around four.
  test "each card links to its own island", %{conn: conn} do
    Board.put_stats(%{"island" => "beam01", "tick" => 1, "population" => 5, "plants" => 5})
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ ~s|href="/research/workbench/biotope/beam01"|
  end

  # The attribute arrives HTML-escaped, which is the renderer doing its job.
  # `&amp;` is undone LAST so an escaped ampersand is not unescaped twice.
  defp unescape(text) do
    text
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&amp;", "&")
  end
end
