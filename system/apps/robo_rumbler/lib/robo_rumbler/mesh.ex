defmodule RoboRumbler.Mesh do
  @moduledoc """
  Holds the one Macula SDK pool handle the site reads the mesh through.

  Not a wrapper and not a second pool implementation: it calls `:macula.connect/2`
  once and hands the handle out. Everything else calls the `:macula` facade
  directly. Lifted from `MaculaRealm.Mesh`, which does the same job for the realm.

  ## Unconfigured is a normal state, not an error

  The site must boot with no mesh at all: in dev, in CI, and for anyone who
  clones the repo. So the realm and seeds are read from the environment with no
  defaults, and when they are absent this holder stays quietly unconnected and
  `handle/0` answers `{:error, :not_ready}` forever. The workbench page then
  renders its empty state. Nothing crashes and nothing retries in a hot loop.

  ## Why no realm is baked in

  The rumble facts currently ride the same realm as the rest of the Hecate fleet.
  Committing that realm tag to a public website repo would hand every reader the
  routing identifier for every topic on it, not just the rumble ones. So it is
  configuration, supplied to the deployed site and to nobody else.
  """

  use GenServer
  require Logger

  @retry_ms 5_000

  # ── Public API ──────────────────────────────────────────────────

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  `{:ok, pool, realm}` once connected, else `{:error, :not_ready}`.

  A subscriber pattern-matches this on each tick and re-arms until it is ready.
  """
  @spec handle() :: {:ok, pid(), binary()} | {:error, :not_ready}
  def handle, do: GenServer.call(__MODULE__, :handle)

  @doc "Whether the site is configured to read the mesh at all."
  @spec configured?() :: boolean()
  def configured?, do: realm() != nil and seeds() != []

  # ── GenServer ───────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    send(self(), :connect)
    {:ok, %{pool: nil, realm: realm(), seeds: seeds()}}
  end

  @impl true
  def handle_call(:handle, _from, %{pool: p, realm: r} = s)
      when is_pid(p) and is_binary(r),
      do: {:reply, {:ok, p, r}, s}

  def handle_call(:handle, _from, s), do: {:reply, {:error, :not_ready}, s}

  @impl true
  def handle_info(:connect, %{pool: p} = s) when is_pid(p), do: {:noreply, s}

  def handle_info(:connect, %{realm: nil} = s), do: {:noreply, s}

  def handle_info(:connect, %{seeds: []} = s), do: {:noreply, s}

  def handle_info(:connect, s), do: {:noreply, try_connect(s)}

  def handle_info(_msg, s), do: {:noreply, s}

  # ── Internals ───────────────────────────────────────────────────

  # The pool returns immediately and completes its link handshakes
  # asynchronously, driving its own reconnect, replay and dedup. So a successful
  # connect is the whole job; this holder never polls it.
  defp try_connect(%{seeds: seeds} = s) do
    case :macula.connect(seeds, %{}) do
      {:ok, pool} ->
        Logger.info("[RoboRumbler.Mesh] pool connected (#{length(seeds)} seeds)")
        %{s | pool: pool}

      {:error, reason} ->
        Logger.warning("[RoboRumbler.Mesh] connect failed: #{inspect(reason)}")
        Process.send_after(self(), :connect, @retry_ms)
        s
    end
  end

  # The 64-hex realm tag, decoded to the 32 bytes the wire wants. A malformed tag
  # is treated as absent rather than crashing the site over a typo in an env var.
  defp realm do
    :robo_rumbler
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
    Logger.warning("[RoboRumbler.Mesh] realm is not 64 hex characters, staying dark")
    nil
  end

  defp seeds do
    :robo_rumbler
    |> Application.get_env(:seeds, [])
    |> Enum.map(&to_string/1)
  end
end
