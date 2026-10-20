defmodule BeamCampusWeb.LetsEncryptGenerationYChainTest do
  @moduledoc """
  The chain auth.beam-campus.net serves since Let's Encrypt's generation Y:
  leaf <- YE1 <- Root YE <- ISRG Root X2 (cross-signed by ISRG Root X1).
  Every CA in it carries an extended key usage (serverAuth, and clientAuth on
  the X2 cross-sign) next to keyCertSign. OTP 27.2's public_key refused that
  as `key_usage_mismatch`, so the site could not fetch Hanko's JWKS, every
  webhook token failed as `unknown_kid`, and nobody could sign in. OTP 27.3+
  accepts it (RFC 5280 leaves EKU on a CA to the application).

  The fixtures are the public CA certificates as served on 2026-10-20. Expiry
  is ignored so the test proves the key-usage rule, not the calendar.
  """
  use ExUnit.Case, async: true

  @fixtures Path.expand("../support/fixtures/lets_encrypt_generation_y", __DIR__)

  test "this OTP validates Let's Encrypt's generation Y chain up to ISRG Root X1" do
    path = Enum.map(~w(isrg_root_x2_by_x1 root_ye_by_x2 ye1_by_root_ye), &der/1)

    assert {:ok, _} =
             :public_key.pkix_path_validation(der("isrg_root_x1"), path,
               verify_fun: {&ignore_expiry/3, nil}
             )
  end

  defp der(name) do
    [{:Certificate, der, :not_encrypted}] =
      @fixtures |> Path.join(name <> ".pem") |> File.read!() |> :public_key.pem_decode()

    der
  end

  defp ignore_expiry(_cert, {:bad_cert, :cert_expired}, state), do: {:valid, state}
  defp ignore_expiry(_cert, {:bad_cert, _} = reason, _state), do: {:fail, reason}
  defp ignore_expiry(_cert, {:extension, _}, state), do: {:unknown, state}
  defp ignore_expiry(_cert, _valid, state), do: {:valid, state}
end
