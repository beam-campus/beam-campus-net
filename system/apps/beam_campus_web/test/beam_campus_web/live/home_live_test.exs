defmodule BeamCampusWeb.HomeLiveTest do
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the landing page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "A European Research Commons"
    assert html =~ "Campus"
    assert html =~ "Run a node"
  end
end
