defmodule BeamCampusWeb.BiotopeJoinLiveTest do
  @moduledoc """
  The page that tells a stranger how to run an island.

  Two claims on it are the kind that rot: that migrants are not built yet, and
  that a station name is not a place. Both are true today and both would be
  quietly wrong later if nothing watched them.
  """
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "gives a runnable command with the public realm", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/research/workbench/biotope/join")

    assert html =~ "docker run"
    assert html =~ "HECATE_BIOTOPE_REALM"
    assert html =~ "ghcr.io/hecate-services/hecate-biotope"
    assert html =~ "7f73d3d9361bb16d4bed2812428ea6e6257a6f50c9de7ac8c581665dc0d01171"
  end

  # NOT YET BUILT, and the page must keep saying so. Implying a mesh that
  # already trades populations would be the one dishonest thing here.
  test "says invasion is opt-in and not built" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    assert html =~ "not built yet"
  end

  # A station name is an identity, never a location.
  test "offers stations without claiming they are places" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    assert html =~ "station-fi-helsinki.macula.io"
    assert html =~ "not locations"
    refute html =~ "Finland"
    refute html =~ "Germany"
  end

  # THE DOORS ARE NOT FREE, and the page should say what the two ways to help
  # are rather than only asking for a node. A station carries other people's
  # islands, which is the part that costs money every month.
  test "names both ways to support it" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    assert html =~ "macula.io"
    assert html =~ "coffee"
    assert html =~ "cost real money"
  end

  test "the overview links to it" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope")

    assert html =~ "/research/workbench/biotope/join"
  end
end
