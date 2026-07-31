defmodule BeamCampusWeb.RoboRumbleLiveTest do
  @moduledoc """
  The page with no mesh behind it, which is how it renders in dev, in CI, and for
  anyone who clones the repo. An unconfigured site must serve a working page, not
  a crash and not a blank.
  """
  # NOT async. The board is one ETS table for the whole node, so tests that write
  # to it are not independent: an earlier test's row made the empty-page test see
  # a populated board and fail.
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BeamCampusWeb.RoboRumbleLive
  alias RoboRumbler.WatchRumbles.Board

  setup do
    if :ets.info(:robo_rumbler_board) == :undefined, do: Board.init()
    :ets.delete_all_objects(:robo_rumbler_board)
    :ok
  end

  test "renders with no facts at all", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/robo-rumble")

    assert html =~ "Robo Rumble"
    assert html =~ "Not watching the mesh"
    assert html =~ "No rows have arrived on this node yet"
  end

  test "the workbench lists it", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench")

    assert html =~ "Robo Rumble"
    assert html =~ ~p"/research/workbench/robo-rumble"
  end

  # Reachable in one click from anywhere, not two. It is the only live page on
  # the site, so it gets its own nav entry rather than only a workbench card.
  test "the research nav links straight to it", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ ~p"/research/workbench/robo-rumble"
  end

  # Facts filed on the board reach the page. Written directly here rather than
  # published, because the point under test is the render, not the transport.
  test "renders a settled row and a featured duel", %{conn: conn} do
    Board.put_visit(%{
      "challenger_id" => "abcdef0123456789",
      "matches" => 6400,
      "wins" => 12,
      "losses" => 6300,
      "draws" => 88,
      "capped" => 40
    })

    Board.put_duel(%{
      "challenger_id" => "abcdef0123456789",
      "resident_arm" => "s",
      "resident_seed" => 2001,
      "turns" => 243,
      "start_index" => 1,
      "challenger_seat" => "first",
      "decided" => true
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/robo-rumble")

    assert html =~ "abcdef0123"
    assert html =~ "6300"
    assert html =~ "s/2001"
    assert html =~ "243 turns"
    refute html =~ "ran out the turn cap"
  end

  # A duel that ran out the turn cap says so BEFORE anyone watches it. The
  # rumbler prefers decided battles now, but a row where nothing was decided
  # still features its longest, and two tanks circling for 2000 turns should not
  # be presented as the fight worth seeing.
  # A draw and a timeout are different things and the page said "Draw at the turn
  # cap" for both. It announced a live 1913-turn draw as having hit the 2000-turn
  # cap, which is false.
  test "a draw that ended is not called a timeout" do
    assert RoboRumbleLive.verdict(%{winner: :none, challenger: :first}, true) ==
             "A draw: neither tank survived."

    assert RoboRumbleLive.verdict(%{winner: :none, challenger: :first}, false) ==
             "Stalemate: ran out the turn cap."

    assert RoboRumbleLive.verdict(%{winner: :first, challenger: :first}, true) ==
             "The visitor won."

    assert RoboRumbleLive.verdict(%{winner: :second, challenger: :first}, true) ==
             "The resident won."
  end

  test "a stalemate duel is labelled", %{conn: conn} do
    Board.put_duel(%{
      "challenger_id" => "abcdef0123456789",
      "resident_arm" => "s",
      "resident_seed" => 2001,
      "turns" => 2000,
      "start_index" => 6,
      "challenger_seat" => "first",
      "decided" => false
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/robo-rumble")

    assert html =~ "stalemate: ran out the turn cap"
  end
end
