defmodule Biotope.WatchIslands do
  @moduledoc """
  Subscribes to the islands' facts, files them on the board, tells the page.

  The whole slice: two topics in, an ETS row out, a `Phoenix.PubSub` broadcast so
  any mounted LiveView redraws. Nothing here publishes, and nothing here computes
  a world.

  ## Subscribing is retried, because the pool is not up at boot

  `init/1` runs before the Macula pool has finished a single handshake, so a
  subscribe attempted there is attempted against nothing. Both the rumbler and
  the biotope learned this on the service side by subscribing once and silently
  never receiving anything. So this ticks until every topic is subscribed and
  then stops ticking.

  ## The same wire value arrives in two different shapes, and which one is luck

  CBOR encodes both an atom and a binary as a text string, and the SDK decodes a
  text string to an **existing atom when one exists** and to `{:text, binary}`
  when it does not. So the shape a key arrives in depends on what happens to be
  in the receiving node's atom table, which differs between nodes and changes as
  modules load.

  The biotope publishes maps with atom keys, so this is not hypothetical: a fact
  can arrive with `:island` and `"tick"` in the same map. A rumble duel fact
  arrived on this node with four atom keys and eleven string ones, from a single
  published map, and a `Map.get(fact, "turns")` returned nil without raising.

  `untag/1` therefore collapses **both** shapes to strings, keys and values
  alike, once at the edge. `true`, `false` and `nil` are left alone: CBOR has real
  booleans and null, so those never came from text.

  Nothing downstream becomes an atom. These are bytes off a public realm, and
  `String.to_atom/1` on network input fills the atom table until the node dies.
  """

  use GenServer
  require Logger

  alias Biotope.WatchIslands.Board

  @retry_ms 3_000
  @pubsub BeamCampus.PubSub
  @channel "biotope"
  # ⚠ THREE TOPICS SINCE THE ISLANDS LEARNED TO TALK. `narration` is a sentence a
  # language model wrote about an island's own figures, on its own topic
  # deliberately: counts and pictures are what an island MEASURED, and prose is
  # what a model SAID about them. A reader that wants one should not have to take
  # the other, and nothing downstream should be able to confuse them.
  @kinds [:world, :chart, :narration]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Subscribe the calling LiveView to board changes."
  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @channel)

  @doc """
  Collapse a delivered payload to plain strings, keys and values alike.

  Public because it IS the contract with the transport, and the shape it
  normalises away is not something a reader can guess. See the module doc.
  """
  @spec untag(term()) :: term()
  def untag({:text, b}), do: b
  def untag(m) when is_map(m), do: Map.new(m, fn {k, v} -> {untag(k), untag(v)} end)
  def untag(l) when is_list(l), do: Enum.map(l, &untag/1)
  def untag(v) when is_boolean(v) or is_nil(v), do: v
  def untag(v) when is_atom(v), do: Atom.to_string(v)
  def untag(v), do: v

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
    {:noreply, attempt(Biotope.Mesh.configured?(), %{s | timer: nil})}
  end

  # The ref says which subscription this is, which is more reliable than
  # re-parsing the topic string.
  def handle_info({:macula_event, ref, _topic, payload, _meta}, s) do
    file(Map.get(s.refs, ref), untag(payload))
    {:noreply, s}
  end

  # A subscription died with the link. Re-arm: the pool reconnects underneath and
  # the topic has to be re-subscribed on the new one.
  def handle_info({:macula_event_gone, ref, reason}, s) do
    Logger.warning("[Biotope] subscription gone (#{inspect(reason)}), re-arming")
    Process.send_after(self(), :subscribe, @retry_ms)
    {:noreply, forget(ref, s)}
  end

  def handle_info(_msg, s), do: {:noreply, s}

  # ── Subscribing ─────────────────────────────────────────────────

  defp attempt(false, s), do: s
  defp attempt(true, s), do: arm(Biotope.Mesh.handle(), s)

  defp arm({:error, :not_ready}, s), do: retry(s)

  defp arm({:ok, pool, realm}, s) do
    @kinds
    |> Enum.reject(&(&1 in s.subscribed))
    |> Enum.reduce(s, &subscribe_one(&1, pool, realm, &2))
    |> tick_if_incomplete()
  end

  defp subscribe_one(kind, pool, realm, s) do
    case :macula.subscribe(pool, realm, topic(kind), self()) do
      {:ok, ref} -> %{s | subscribed: [kind | s.subscribed], refs: Map.put(s.refs, ref, kind)}
      other -> warn_subscribe(kind, other, s)
    end
  end

  defp warn_subscribe(kind, other, s) do
    Logger.warning("[Biotope] subscribe #{kind} failed: #{inspect(other)}")
    s
  end

  defp tick_if_incomplete(s) when length(s.subscribed) == length(@kinds), do: ready(s)
  defp tick_if_incomplete(s), do: retry(s)

  defp ready(s) do
    Logger.info("[Biotope] watching #{namespace()} (#{length(@kinds)} topics)")
    %{s | timer: nil}
  end

  # THE TIMER REF IS STATE. It stops a second `:subscribe` arriving mid-retry
  # from stacking a parallel timer, which would double the tick rate every time
  # it happened, and it is the only way to observe from outside that an
  # unconfigured node is genuinely idle rather than quietly ticking forever.
  defp retry(%{timer: t} = s) when is_reference(t), do: s
  defp retry(s), do: %{s | timer: Process.send_after(self(), :subscribe, @retry_ms)}

  defp forget(ref, s) do
    kind = Map.get(s.refs, ref)
    %{s | subscribed: List.delete(s.subscribed, kind), refs: Map.delete(s.refs, ref)}
  end

  # ── Filing ──────────────────────────────────────────────────────

  # A fact with no island is filed nowhere and announced to nobody. That is the
  # version gap made visible: an older island publishes without the field, and
  # the honest response is to show nothing rather than to invent a name for it.
  defp file(:world, fact), do: announce(Board.put_stats(fact), fact["island"])
  defp file(:chart, fact), do: announce(Board.put_chart(fact), fact["island"])
  defp file(:narration, fact), do: announce(Board.put_narration(fact), fact["island"])
  defp file(nil, _fact), do: :ok

  # THE ANNOUNCEMENT SAYS WHICH ISLAND SPOKE, and it used to say only that
  # something had.
  #
  # A page showing one island has no way to ignore the other two without it, so
  # the island page redrew its four hundred circles every time ANY island
  # published, six times a second on a three-island fleet. Its own moduledoc
  # claimed it redrew "only when THIS island speaks", which was true of the
  # intent and false of the code.
  defp announce(:ignored, _name), do: :ok
  defp announce(_written, name) do
    Phoenix.PubSub.broadcast(@pubsub, @channel, {:biotope, :changed, name})
  end

  # ── Topics ──────────────────────────────────────────────────────

  # Matches `world_facts:topic/1` in the island. The island id is NOT in the
  # topic: one topic carries every island and the payload says which.
  defp topic(kind), do: "#{namespace()}/#{kind}"

  defp namespace, do: Application.get_env(:biotope, :namespace, "biotope")
end
