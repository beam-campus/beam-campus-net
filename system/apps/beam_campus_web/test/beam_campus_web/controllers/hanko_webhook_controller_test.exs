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

  test "POST with a token whose key the JWKS does not hold is a 400 naming the reason, not a crash",
       %{conn: conn} do
    header = Base.url_encode64(~s({"alg":"RS256","kid":"no-such-kid"}), padding: false)
    token = header <> ".e30.c2ln"

    conn =
      post(conn, ~p"/api/v1/internal/hanko/webhook", %{"token" => token, "event" => "email.send"})

    assert %{"ok" => false, "error" => "unknown_kid"} = json_response(conn, 400)
  end
end
