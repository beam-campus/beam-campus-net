defmodule BeamCampusWeb.CoevolutionDemosTest do
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "the numerical Red Queen demo mounts and runs", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/research/workbench/red-queen")
    assert html =~ "running to stay in place"
    assert html =~ "not neuroevolution"
    html = view |> element("button[phx-click=play]") |> render_click()
    assert html =~ "Pause"
  end

  test "the neural coevolution demo mounts and animates", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/research/workbench/neural-coevolution")
    assert html =~ "Neural coevolution"
    assert html =~ "real engine"
    assert html =~ "disengagement"
    html = view |> element("button[phx-click=play]") |> render_click()
    assert html =~ "Pause"
  end

  test "the workbench index lists both coevolution demos with kind labels", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench")
    assert html =~ "Neural coevolution"
    assert html =~ "The Red Queen"
    assert html =~ "methodology · numbers"
    assert html =~ "real engine"
  end
end
