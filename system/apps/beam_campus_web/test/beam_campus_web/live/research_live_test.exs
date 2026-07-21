defmodule BeamCampusWeb.ResearchLiveTest do
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the research agenda", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research")
    assert html =~ "One engine, two couplings"
    assert html =~ "DARS / Physical AI"
    assert html =~ "The nine charters"
    assert html =~ "CHARTER_P2_SEARCH_STRATEGIES.md"
  end

  test "the landing page links to the research agenda", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ ~p"/research"
  end
end
