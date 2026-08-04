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

  # ⚠ THE MENU ENTRY IS THE REQUIREMENT, not just the page. A demo reachable only
  # by typing its URL is a demo nobody finds, and the card is the only thing that
  # makes the workbench a menu rather than a list of routes somebody remembers.
  test "ASociety is on the menu and points at its own corpus", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench")

    assert html =~ "ASociety"
    assert html =~ "/research/workbench/asociety"
    assert html =~ "Open the scaffold"

    # Its record is in hecate-society, not in faber-ecosystem. A card that linked
    # to the faber insight index would send a reader to a corpus that has never
    # heard of this line.
    assert html =~ "hecate-society"
    refute html =~ ~s|insight </a>|
  end

  test "the adaptation demo is reachable at its new nested route", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/adaptation")
    assert html =~ "Evolve a controller"
  end
end
