defmodule RoboRumbler.WatchRumbles do
  @moduledoc """
  Subscribes to the rumbler's facts, files them on the board, tells the page.

  The whole slice: four topics in, an ETS row out, a `Phoenix.PubSub` broadcast so
  any mounted LiveView redraws. Nothing here publishes.

  ## Subscribing is retried, because the pool is not up at boot

  `init/1` runs before the Macula pool has finished a single handshake, so a
  subscribe attempted there is attempted against nothing. The rumbler learned this
  the hard way, by subscribing in `init/1` inside `hecate_om:boot/2` and silently
  never receiving anything. So this ticks until every topic is subscribed and then
  stops ticking.

  ## Payload keys arrive tagged and that has bitten this codebase before

  CBOR distinguishes text strings from byte strings, and the SDK preserves the
  distinction: a map published as `%{type: :visit_settled}` is delivered as
  `%{{:text, "type"} => {:text, "visit_settled"}}`. Matching on `%{"type" => t}`
  never matches and every event looks like it never arrived. `plain/1` untags the
  whole structure once, at the edge, so nothing downstream has to know.

  Keys stay strings rather than becoming atoms. These are bytes off a network and
  `String.to_atom/1` on network input fills the atom table until the node dies.
  """

  use GenServer
  require Logger

  alias RoboRumbler.WatchRumbles.Board

  @retry_ms 3_000
  @pubsub BeamCampus.PubSub
  @channel "robo_rumbler"

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Subscribe the calling LiveView to board changes."
  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @channel)

  # ── GenServer ───────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    Board.init()
    send(self(), :subscribe)
    {:ok, %{subscribed: [], refs: %{}, timer: nil}}
  end

  @impl true
  # An unconfigured site has nothing to connect to, ever, so it must not tick a
  # retry timer for the lifetime of the node. Configured-but-dark still retries:
  # that is a mesh that may come back.
  def handle_info(:subscribe, s) do
    {:noreply, attempt(RoboRumbler.Mesh.configured?(), %{s | timer: nil})}
  end

  # The delivered shape is `{:macula_event, ref, topic, payload, meta}`. The ref
  # says which of the four subscriptions this is, which is more reliable than
  # re-parsing the topic string.
  def handle_info({:macula_event, ref, _topic, payload, _meta}, s) do
    file(Map.get(s.refs, ref), plain(payload))
    {:noreply, s}
  end

  # A subscription died with the link. Re-arm: the pool will reconnect underneath
  # and the topic has to be re-subscribed on the new one.
  def handle_info({:macula_event_gone, ref, reason}, s) do
    Logger.warning("[RoboRumbler] subscription gone (#{inspect(reason)}), re-arming")
    Process.send_after(self(), :subscribe, @retry_ms)
    {:noreply, forget(ref, s)}
  end

  def handle_info(_msg, s), do: {:noreply, s}

  # ── Subscribing ─────────────────────────────────────────────────

  defp attempt(false, s), do: s
  defp attempt(true, s), do: arm(RoboRumbler.Mesh.handle(), s)

  defp arm({:error, :not_ready}, s), do: retry(s)

  defp arm({:ok, pool, realm}, s) do
    Enum.reduce(missing(s), s, &subscribe_one(&1, pool, realm, &2))
    |> tick_if_incomplete()
  end

  defp missing(s), do: Enum.reject(kinds(), &(&1 in s.subscribed))

  defp subscribe_one(kind, pool, realm, s) do
    case :macula.subscribe(pool, realm, topic(kind), self()) do
      {:ok, ref} -> %{s | subscribed: [kind | s.subscribed], refs: Map.put(s.refs, ref, kind)}
      other -> warn_subscribe(kind, other, s)
    end
  end

  defp warn_subscribe(kind, other, s) do
    Logger.warning("[RoboRumbler] subscribe #{kind} failed: #{inspect(other)}")
    s
  end

  defp tick_if_incomplete(s) when length(s.subscribed) == 4, do: ready(s)
  defp tick_if_incomplete(s), do: retry(s)

  defp ready(s) do
    Logger.info("[RoboRumbler] watching #{namespace()} (4 topics)")
    %{s | timer: nil}
  end

  # THE TIMER REF IS STATE, for two reasons. It stops a second `:subscribe`
  # arriving mid-retry from stacking a parallel timer, which would double the tick
  # rate every time it happened. And it is the only way to observe from outside
  # that an unconfigured node is genuinely idle rather than quietly ticking
  # forever: a pending timer is invisible in the mailbox until it fires.
  defp retry(%{timer: t} = s) when is_reference(t), do: s
  defp retry(s), do: %{s | timer: Process.send_after(self(), :subscribe, @retry_ms)}

  defp forget(ref, s) do
    kind = Map.get(s.refs, ref)
    %{s | subscribed: List.delete(s.subscribed, kind), refs: Map.delete(s.refs, ref)}
  end

  # ── Filing ──────────────────────────────────────────────────────

  defp file(:field, fact), do: announce(Board.put_field(fact), :field)
  defp file(:arrival, fact), do: announce(Board.put_arrival(fact), :arrival)
  defp file(:visit, fact), do: announce(Board.put_visit(fact), :visit)
  defp file(:duel, fact), do: announce(Board.put_duel(fact), :duel)
  defp file(nil, _fact), do: :ok

  defp announce(_written, kind), do: Phoenix.PubSub.broadcast(@pubsub, @channel, {:rumble, kind})

  # ── Topics ──────────────────────────────────────────────────────

  defp kinds, do: [:field, :arrival, :visit, :duel]

  defp topic(kind), do: "#{namespace()}/#{kind}"

  # Matches `visit_facts:namespace/0` in the rumbler, scratch default included.
  defp namespace, do: Application.get_env(:robo_rumbler, :namespace, "rumble-scratch")

  # ── Untagging ───────────────────────────────────────────────────

  defp plain({:text, b}), do: b
  defp plain(m) when is_map(m), do: Map.new(m, fn {k, v} -> {plain(k), plain(v)} end)
  defp plain(l) when is_list(l), do: Enum.map(l, &plain/1)
  defp plain(v), do: v
end
