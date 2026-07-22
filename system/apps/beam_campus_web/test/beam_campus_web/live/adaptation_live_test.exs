defmodule BeamCampusWeb.AdaptationLiveTest do
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "mounts, renders the three controllers, and survives the live tick loop", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/research/adaptation")
    assert html =~ "re-wires itself"
    assert html =~ "data-arm=\"fixed\""
    assert html =~ "data-arm=\"plastic\""
    assert html =~ "balancing"

    # Starting play schedules the real-backend tick loop; let several ticks run.
    render_click(view, "toggle")
    Process.sleep(250)

    # If handle_info(:tick) had crashed, the LiveView process would be dead and this
    # would raise. Surviving + advancing past step 0 proves the loop drives the backend.
    rendered = render(view)
    refute rendered =~ "step <b class=\"text-base-content\">0</b>"
  end
end
