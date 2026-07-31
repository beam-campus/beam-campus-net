defmodule BeamCampusWeb.ResearchLiveTest do
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Rewritten against the page as it stands. It asserted the single-agenda copy
  # from before 7e15bf3 split /research into research lines, so it had been
  # failing on four strings that moved to other pages.
  test "renders the research lines", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research")
    assert html =~ "Faber"
    assert html =~ "Spartan"
    assert html =~ "Shared surfaces"
    assert html =~ "seven engine axes and two couplings"
  end

  test "the landing page links to the research agenda", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ ~p"/research"
  end
end
