defmodule BeamCampusWeb.WorkbenchLiveTest do
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "the workbench index lists the runnable experiments", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench")
    assert html =~ "Watch the findings run"
    assert html =~ "Abandoning the objective"
    assert html =~ "Adapt to a broken world"
    assert html =~ "Open the experiment"
    # cross-links to the other faces
    assert html =~ "/research/workbench/deception-maze"
    assert html =~ "/research/notes/abandoning-the-objective"
  end

  test "the adaptation demo is reachable at its new nested route", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/adaptation")
    assert html =~ "Evolve a controller"
  end
end
