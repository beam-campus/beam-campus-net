defmodule BeamCampusWeb.DeceptionMazeLiveTest do
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "mounts, renders both showcase champions and the control", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/research/workbench/deception-maze")
    assert html =~ "escaping a deceptive maze"
    assert html =~ "Chasing the goal"
    assert html =~ "Seeking novelty"
    assert html =~ "the same goal-chaser, on the twin maze"

    # Playing the showcase advances without crashing.
    html = view |> element("button[phx-click=sc_toggle]") |> render_click()
    assert html =~ "Pause"
  end

  test "the live-evolve mode switch and evolve are handled", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/research/workbench/deception-maze")

    html = view |> element("button[phx-value-mode=objective]") |> render_click()
    assert html =~ "Chasing the goal"

    html = view |> element("button[phx-click=mevolve]") |> render_click()
    assert html =~ "Evolving…"
  end
end
