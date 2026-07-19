defmodule BeamCampusWeb.HealthControllerTest do
  use BeamCampusWeb.ConnCase, async: true

  test "GET /health returns ok", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert text_response(conn, 200) == "ok"
  end
end
