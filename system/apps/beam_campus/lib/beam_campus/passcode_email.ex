defmodule BeamCampus.PasscodeEmail do
  @moduledoc """
  Delivers Hanko-rendered passcode emails via the existing Mailgun
  adapter (HTTPS, port 443) — outbound SMTP is blocked on this host,
  same reason macula-portal solved this the same way; ported from
  `MaculaPortal.PasscodeEmail`.

  Only invoked from `BeamCampusWeb.HankoWebhookController`, which
  receives Hanko's `email.send` webhook (`email_delivery.enabled:
  false` in this deployment's Hanko config).

  The webhook payload carries the fully-rendered email bodies — we do
  no templating here, just forward to Mailgun.
  """

  import Swoosh.Email
  require Logger

  alias BeamCampus.Mailer

  @type payload :: %{required(String.t()) => term()}

  @spec deliver(payload()) :: {:ok, term()} | {:error, term()}
  def deliver(%{
        "to_email_address" => to_address,
        "subject" => subject,
        "body_plain" => body_plain,
        "body" => body_html
      })
      when is_binary(to_address) and is_binary(subject) do
    from_address = Application.get_env(:beam_campus, :mail_from, "no-reply@beam-campus.net")
    from_name = Application.get_env(:beam_campus, :mail_from_name, "BEAM Campus")

    email =
      new()
      |> to(to_address)
      |> from({from_name, from_address})
      |> subject(subject)
      |> text_body(body_plain || "")
      |> html_body(body_html || "")

    # The subject carries the live passcode, a credential, so it is never logged; the
    # address is personal data, so the log names it only by hash and domain.
    case Mailer.deliver(email) do
      {:ok, resp} ->
        Logger.info("[PasscodeEmail] sent #{recipient(to_address)} id=#{inspect(resp[:id])}")
        {:ok, resp}

      {:error, reason} = err ->
        Logger.error("[PasscodeEmail] failed #{recipient(to_address)}: #{inspect(reason)}")
        err
    end
  end

  def deliver(other) do
    Logger.error("[PasscodeEmail] invalid payload: #{inspect(Map.keys(other))}")
    {:error, :invalid_payload}
  end

  # to_hash=<12 hex of sha256(lowercased address)> to_domain=<domain>: one person's mails
  # correlate across lines and the domain shows the route, without the address itself.
  defp recipient(address) do
    hash =
      :crypto.hash(:sha256, String.downcase(address))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    domain = address |> String.split("@") |> List.last()
    "to_hash=#{hash} to_domain=#{domain}"
  end
end
