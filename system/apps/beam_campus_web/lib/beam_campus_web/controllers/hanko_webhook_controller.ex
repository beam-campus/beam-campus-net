defmodule BeamCampusWeb.HankoWebhookController do
  @moduledoc """
  Receives signed webhook events from the Hanko backend.

  Ported from macula-portal's own `MaculaPortalWeb.HankoWebhookController`,
  which solved this exact problem for its own self-hosted Hanko instance.

  Hanko POSTs `{"token": "<JWT>", "event": "<evt>"}` to our callback URL
  when `webhooks.enabled: true` and we're subscribed to a matching event.
  The JWT is signed by the same JWKS that signs Hanko session tokens, so
  we verify it using `HankoJwt.verify_webhook/1` (which tolerates missing
  `iss` — webhook tokens don't carry it).

  Currently handles:

    * `email.send` — Hanko wants us to deliver an already-rendered email.
      Used when `email_delivery.enabled: false` in Hanko config (this
      host blocks outbound SMTP, same reason macula-portal took this
      path).
  """

  use BeamCampusWeb, :controller
  require Logger

  alias BeamCampus.PasscodeEmail
  alias BeamCampusWeb.HankoJwt

  def create(conn, %{"token" => token, "event" => event})
      when is_binary(token) and is_binary(event) do
    with {:ok, claims} <- HankoJwt.verify_webhook(token),
         :ok <- handle_event(event, claims) do
      conn
      |> put_status(:ok)
      |> json(%{ok: true})
    else
      {:error, reason} ->
        Logger.error("[HankoWebhook] rejected event=#{event}: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{ok: false, error: error_code(reason)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{ok: false, error: "missing token or event"})
  end

  # A rejection reason is any term ({:unknown_kid, kid}, a Joken error list,
  # {:email_delivery_failed, _}); the response names its kind only.
  defp error_code(reason) when is_atom(reason), do: Atom.to_string(reason)

  defp error_code(reason) when is_tuple(reason) and is_atom(elem(reason, 0)),
    do: reason |> elem(0) |> Atom.to_string()

  defp error_code(_reason), do: "rejected"

  ## --- Event dispatch ---------------------------------------------------

  defp handle_event("email.send", %{"data" => %{} = data}) do
    case PasscodeEmail.deliver(data) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:email_delivery_failed, reason}}
    end
  end

  defp handle_event(other_event, _claims) do
    Logger.warning("[HankoWebhook] unhandled event: #{other_event}")
    # Return :ok so Hanko doesn't retry — we deliberately don't subscribe
    # to other events right now.
    :ok
  end
end
