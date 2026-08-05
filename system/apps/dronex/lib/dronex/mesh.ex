defmodule Dronex.Mesh do
  @moduledoc """
  Holds the Macula SDK pool this app reads islands through.

  ## Why each spectator holds its own pool

  It is nearly the same code as the other readers here, and the duplication is
  deliberate rather than overlooked. Each reads a different realm, and an
  independent pool means a reconnect or an outage on one page cannot take the
  others down with it. Sharing one pool would save a QUIC connection and couple
  unrelated pages; the connection is cheaper than the coupling.

  ## Unconfigured is a normal state, not an error

  The site must boot with no mesh at all: in dev, in CI, and for anyone who
  clones the repo. With no seeds configured this holder stays quietly
  unconnected, `handle/0` answers `{:error, :not_ready}` forever, and the page
  renders its empty state. Nothing crashes and nothing retries in a hot loop.

  ## The realm is public, the seeds are not defaulted

  Dronex facts have their own realm, `net.beamcampus.dronex`, exactly so that a
  public web container never holds the tag that routes sentinel sightings and
  warden facts. A realm id is sha256 of its name, so the tag is derived rather
  than issued and naming it openly is the point:

      net.beamcampus.dronex
      686fbbf84c5c33455764f4c07c642bd1b79ef4efc78455f61ac12936ca3bffe3

  Seeds have no default. Naming a public realm costs nothing; dialling a
  production station from every dev clone does.
  """

  use GenServer
  require Logger

  @retry_ms 5_000
  @health_ms 1_000

  # ── Public API ──────────────────────────────────────────────────

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  `{:ok, pool, realm}` once a link is actually **healthy**, else
  `{:error, :not_ready}`.

  ## A connected pool is not a usable pool, and this cost an afternoon

  `:macula.connect/2` returns a pool immediately and completes its link
  handshakes asynchronously. Subscribing in that window does not fail: the frame
  is sent, the peering is still in `:handshaking`, and the station logs
  `_macula.peering.unexpected` and drops it. `:macula.subscribe/4` still answers
  `{:ok, ref}`, so a subscriber that treats that as success stops retrying and
  waits forever for facts that are being published perfectly well.

  That is exactly what happened the first time this page was pointed at a live
  island: pool connected, two topics "subscribed", not one fact ever delivered.

  So readiness is gated on `healthy_links > 0` from `:macula.status/1`, which is
  the only thing that distinguishes connected from subscribed.
  """
  @spec handle() :: {:ok, pid(), binary()} | {:error, :not_ready}
  def handle, do: GenServer.call(__MODULE__, :handle)

  @doc "Whether the site is configured to read islands at all."
  @spec configured?() :: boolean()
  def configured?, do: realm() != nil and seeds() != []

  # ── GenServer ───────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    send(self(), :connect)
    {:ok, %{pool: nil, realm: realm(), seeds: seeds(), healthy: false}}
  end

  @impl true
  def handle_call(:handle, _from, %{pool: p, realm: r, healthy: true} = s)
      when is_pid(p) and is_binary(r),
      do: {:reply, {:ok, p, r}, s}

  def handle_call(:handle, _from, s), do: {:reply, {:error, :not_ready}, s}

  @impl true
  def handle_info(:connect, %{pool: p} = s) when is_pid(p), do: {:noreply, s}
  def handle_info(:connect, %{realm: nil} = s), do: {:noreply, s}
  def handle_info(:connect, %{seeds: []} = s), do: {:noreply, s}
  def handle_info(:connect, s), do: {:noreply, try_connect(s)}

  # Polled rather than awaited, because the pool drives its own handshakes and
  # offers nothing to wait on. Once healthy this stops: a link that later drops
  # is announced to the subscriber as `macula_event_gone`, which re-arms.
  def handle_info(:check_health, %{healthy: true} = s), do: {:noreply, s}
  def handle_info(:check_health, s), do: {:noreply, check_health(s)}

  def handle_info(_msg, s), do: {:noreply, s}

  # ── Internals ───────────────────────────────────────────────────

  # The pool returns immediately and completes its link handshakes
  # asynchronously, driving its own reconnect, replay and dedup. So a successful
  # connect is the whole job; this holder never polls it.
  defp try_connect(%{seeds: seeds} = s) do
    case :macula.connect(seeds, %{}) do
      {:ok, pool} ->
        Logger.info("[Dronex.Mesh] pool connected (#{length(seeds)} seeds), waiting for a link")
        send(self(), :check_health)
        %{s | pool: pool}

      {:error, reason} ->
        Logger.warning("[Dronex.Mesh] connect failed: #{inspect(reason)}")
        Process.send_after(self(), :connect, @retry_ms)
        s
    end
  end

  # `healthy_links` is the only field that distinguishes a pool that exists from
  # a pool that can carry a subscription. Wrapped, because status/1 on a pool
  # that is still starting can exit rather than answer, and a holder that dies
  # here takes the page's only route to the mesh with it.
  defp check_health(%{pool: pool} = s) do
    healthy =
      case safe_status(pool) do
        {:ok, %{healthy_links: n}} when n > 0 -> true
        _otherwise -> false
      end

    ready(healthy, s)
  end

  defp ready(true, s) do
    Logger.info("[Dronex.Mesh] link healthy, ready to subscribe")
    %{s | healthy: true}
  end

  defp ready(false, s) do
    Process.send_after(self(), :check_health, @health_ms)
    s
  end

  defp safe_status(pool) do
    :macula.status(pool)
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  # The 64-hex realm tag, decoded to the 32 bytes the wire wants. A malformed tag
  # is treated as absent rather than crashing the site over a typo in an env var.
  defp realm do
    :dronex
    |> Application.get_env(:realm)
    |> decode_realm()
  end

  defp decode_realm(nil), do: nil
  defp decode_realm(""), do: nil

  defp decode_realm(hex) when is_binary(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, <<r::binary-size(32)>>} -> r
      _otherwise -> warn_bad_realm()
    end
  end

  defp warn_bad_realm do
    Logger.warning("[Dronex.Mesh] realm is not 64 hex characters, staying dark")
    nil
  end

  defp seeds do
    :dronex
    |> Application.get_env(:seeds, [])
    |> Enum.map(&to_string/1)
  end
end
