defmodule BeamCampusWeb.HankoWebhookControllerTest do
  use BeamCampusWeb.ConnCase, async: true

  test "POST without token/event is rejected", %{conn: conn} do
    conn = post(conn, ~p"/api/v1/internal/hanko/webhook", %{})
    assert %{"ok" => false, "error" => "missing token or event"} = json_response(conn, 400)
  end

  test "POST with a malformed token is rejected without delivering anything", %{conn: conn} do
    conn =
      post(conn, ~p"/api/v1/internal/hanko/webhook", %{
        "token" => "not-a-real-jwt",
        "event" => "email.send"
      })

    assert %{"ok" => false} = json_response(conn, 400)
  end
end
