defmodule BeamCampusWeb.HankoJwt do
  @moduledoc """
  Verifies Hanko-issued JWTs against Hanko's JWKS endpoint.

  Ported from macula-portal's own `MaculaPortalWeb.HankoJwt`, which
  solved this exact problem for its own self-hosted Hanko instance.
  Hanko is not an OIDC provider, so standard OIDC client libraries are
  the wrong shape for this integration. Instead we fetch JWKS directly,
  cache signers per `kid`, and validate signature + `iss` + `aud` +
  `exp` + `iat` with Joken.

  Cache TTL defaults to one hour; on a `kid` miss we force a refresh
  before giving up.
  """

  use GenServer
  require Logger

  @type claims :: %{optional(String.t()) => term()}

  @default_ttl_ms :timer.hours(1)

  ## -- Public API ---------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Verify a Hanko webhook JWT. Hanko's webhook tokens only carry
  `sub=hanko webhooks`, `aud`, `exp`, `iat`, `data`, `evt` — no `iss`.
  Signed by the same JWKS that signs Hanko session tokens.
  """
  @spec verify_webhook(String.t()) :: {:ok, claims()} | {:error, term()}
  def verify_webhook(token) when is_binary(token) do
    with {:ok, kid} <- peek_kid(token),
         {:ok, signer} <- fetch_signer(kid),
         {:ok, claims} <- Joken.verify(token, signer),
         :ok <- validate_webhook_claims(claims) do
      {:ok, claims}
    end
  end

  @doc "Invalidate the cached JWKS. Primarily for tests."
  def refresh, do: GenServer.call(__MODULE__, :refresh)

  ## -- GenServer ----------------------------------------------------------

  @impl true
  def init(opts) do
    {:ok,
     %{
       opts: opts,
       signers: %{},
       fetched_at: 0
     }}
  end

  @impl true
  def handle_call({:get_signer, kid}, _from, state) do
    state = maybe_refresh(state, kid)

    case Map.fetch(state.signers, kid) do
      {:ok, signer} -> {:reply, {:ok, signer}, state}
      :error -> {:reply, {:error, {:unknown_kid, kid}}, state}
    end
  end

  def handle_call(:refresh, _from, state) do
    {:reply, :ok, %{state | signers: %{}, fetched_at: 0}}
  end

  ## -- Internals ----------------------------------------------------------

  defp fetch_signer(kid), do: GenServer.call(__MODULE__, {:get_signer, kid})

  defp maybe_refresh(state, kid) do
    cond do
      Map.has_key?(state.signers, kid) and not expired?(state) -> state
      true -> do_refresh(state)
    end
  end

  defp expired?(%{fetched_at: 0}), do: true

  defp expired?(%{fetched_at: ts, opts: opts}) do
    ttl = Keyword.get(opts, :cache_ttl, @default_ttl_ms)
    System.monotonic_time(:millisecond) - ts > ttl
  end

  defp do_refresh(state) do
    url = Keyword.fetch!(state.opts, :jwks_url)

    case fetch_jwks(url) do
      {:ok, jwks} ->
        %{state | signers: to_signers(jwks), fetched_at: System.monotonic_time(:millisecond)}

      {:error, reason} ->
        Logger.warning("Hanko JWKS refresh failed: #{inspect(reason)}")
        state
    end
  end

  defp fetch_jwks(url) do
    case Req.get(url, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: %{"keys" => keys}}} when is_list(keys) -> {:ok, keys}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, err} -> {:error, err}
    end
  end

  defp to_signers(keys) do
    keys
    |> Enum.reduce(%{}, fn jwk_map, acc ->
      case build_signer(jwk_map) do
        {:ok, kid, signer} -> Map.put(acc, kid, signer)
        :error -> acc
      end
    end)
  end

  defp build_signer(%{"kid" => kid, "alg" => alg} = jwk_map) when is_binary(alg) do
    jwk = JOSE.JWK.from_map(Map.delete(jwk_map, "alg"))
    # `alg:` must be set on the Signer struct itself — Joken's
    # `check_signer_not_empty/1` rejects any Signer with `alg: nil`
    # before signature verification even runs (returns :empty_signer).
    {:ok, kid, %Joken.Signer{alg: alg, jwk: jwk, jws: JOSE.JWS.from_map(%{"alg" => alg})}}
  end

  defp build_signer(%{"kid" => _kid} = jwk_map) do
    # Hanko omits `alg` on some JWKS responses; default to RS256.
    build_signer(Map.put(jwk_map, "alg", "RS256"))
  end

  defp build_signer(_), do: :error

  defp peek_kid(token) do
    with [header_b64, _, _] <- String.split(token, ".", parts: 3),
         {:ok, header_json} <- Base.url_decode64(header_b64, padding: false),
         {:ok, %{"kid" => kid}} <- Jason.decode(header_json) do
      {:ok, kid}
    else
      _ -> {:error, :missing_kid}
    end
  end

  @doc false
  @spec validate_webhook_claims(claims()) :: :ok | {:error, atom()}
  def validate_webhook_claims(claims) do
    cfg = Application.get_env(:beam_campus_web, __MODULE__, [])
    now = :erlang.system_time(:second)

    cond do
      claims["sub"] != "hanko webhooks" -> {:error, :not_a_webhook_token}
      not is_integer(claims["exp"]) or claims["exp"] < now -> {:error, :expired}
      not is_integer(claims["iat"]) or claims["iat"] > now + 60 -> {:error, :iat_in_future}
      not aud_ok?(claims["aud"], cfg[:audience]) -> {:error, :audience_mismatch}
      not is_binary(claims["evt"]) -> {:error, :missing_evt}
      true -> :ok
    end
  end

  defp aud_ok?(_, nil), do: true
  defp aud_ok?(aud, expected) when is_binary(aud), do: aud == expected
  defp aud_ok?(aud, expected) when is_list(aud), do: expected in aud
  defp aud_ok?(_, _), do: false
end
