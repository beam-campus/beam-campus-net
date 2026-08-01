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
      "ground" => [2, 0, 400]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope")

    assert html =~ "beam01"
    assert html =~ "412"
    assert html =~ "78"
    # Two creatures and one plant, drawn as circles.
    assert html =~ "<svg"
    assert html =~ "#F2B142"
    assert html =~ "#2F7D52"
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
end
