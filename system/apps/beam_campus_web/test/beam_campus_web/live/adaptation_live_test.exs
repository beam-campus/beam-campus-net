defmodule BeamCampusWeb.AdaptationLiveTest do
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "mounts and renders the workbench controls", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/research/adaptation")
    assert html =~ "Evolve a controller"
    assert html =~ "pole-wb"
    assert html =~ "⚙ Evolve"
    assert html =~ "no data yet"

    # Switching controller updates the shown description without crashing.
    html = view |> element("button[phx-value-arm=fixed]") |> render_click()
    assert html =~ "no adaptation"

    # Changing a scenario parameter is handled.
    html = render_change(view, "params", %{"wind" => "3.0", "shift_at" => "120"})
    assert html =~ "3.0 N"
  end
end
