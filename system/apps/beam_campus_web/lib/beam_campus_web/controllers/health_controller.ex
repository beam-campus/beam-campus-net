defmodule BeamCampusWeb.HealthController do
  @moduledoc "Liveness probe for load balancers, Caddy and container healthchecks."
  use BeamCampusWeb, :controller

  def show(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
