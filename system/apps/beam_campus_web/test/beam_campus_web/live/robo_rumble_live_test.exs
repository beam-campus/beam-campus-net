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
      "challenger_seat" => "first"
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/robo-rumble")

    assert html =~ "abcdef0123"
    assert html =~ "6300"
    assert html =~ "s/2001"
    assert html =~ "243 turns"
  end
end
