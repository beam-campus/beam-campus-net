defmodule ASociety.WatchIslands do
  @moduledoc """
  Subscribes to the islands' facts, files them on the board, tells the page.

  The whole slice: topics in, an ETS row out, a `Phoenix.PubSub` broadcast so any
  mounted LiveView redraws. Nothing here publishes, and nothing here computes.

  ## ⚠ THE TOPIC LIST IS EMPTY, AND THAT IS THE HONEST STATE

  `hecate-society` publishes nothing yet. Its service module asks the realm for
  authority over an empty resource list, which is deliberate there: a scope
  claimed before it is used is a credential lying around with no owner.

  So this subscribes to nothing, says so, and the page says so. **Inventing topic
  names here would be worse than an empty list**: the island is the side that
  owns the contract, and a reader that guesses at it is a reader that will
  silently listen on the wrong channel and show an empty page that looks
  identical to a quiet mesh.

  When the island publishes its first fact, `@kinds` gains one entry and
  everything below it already works.

  ## Subscribing is retried, because the pool is not up at boot

  `init/1` runs before the Macula pool has finished a single handshake, so a
  subscribe attempted there is attempted against nothing. Both siblings learned
  this by subscribing once and silently never receiving anything. So this ticks
  until every topic is subscribed and then stops ticking.

  ## The same wire value arrives in two different shapes, and which one is luck

  CBOR encodes both an atom and a binary as a text string, and the SDK decodes a
  text string to an **existing atom when one exists** and to `{:text, binary}`
  when it does not. So the shape a key arrives in depends on what happens to be
  in the receiving node's atom table, which differs between nodes and changes as
  modules load.

  Services here publish maps with atom keys, so this is not hypothetical: a fact
  can arrive with `:island` and `"tick"` in the same map. A sibling's fact
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

  alias ASociety.WatchIslands.Board

  @retry_ms 3_000
  @pubsub BeamCampus.PubSub
  @channel "asociety"

  # ⚠ EMPTY UNTIL THE ISLAND PUBLISHES. See the module doc: the island owns the
  # contract and a reader that guesses at it listens on the wrong channel and
  # shows a page indistinguishable from a quiet mesh.
  @kinds []

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Subscribe the calling LiveView to board changes."
  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @channel)

  @doc "Which topic kinds this reader listens on. Empty while the island is silent."
  @spec kinds() :: [atom()]
  def kinds, do: @kinds

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
    {:noreply, attempt(ASociety.Mesh.configured?(), %{s | timer: nil})}
  end

  def handle_info({:macula_event, ref, _topic, payload}, s) do
    {:noreply, file(Map.get(s.refs, ref), payload, s)}
  end

  # A link that drops is announced, and re-arming is what turns an outage into a
  # gap rather than into silence for the lifetime of the node.
  def handle_info({:macula_event_gone, ref}, s) do
    Logger.info("[ASociety] subscription gone, re-arming")
    {:noreply, rearm(%{s | subscribed: s.subscribed -- [Map.get(s.refs, ref)],
                         refs: Map.delete(s.refs, ref)})}
  end

  def handle_info(_msg, s), do: {:noreply, s}

  # ── Internals ───────────────────────────────────────────────────

  defp attempt(false, s), do: s

  defp attempt(true, s) do
    case ASociety.Mesh.handle() do
      {:ok, pool, realm} -> subscribe_missing(pool, realm, s)
      {:error, :not_ready} -> rearm(s)
    end
  end

  # Nothing left to subscribe to means stop ticking. With an empty `@kinds` that
  # is true immediately, which is correct: there is no topic to wait for yet.
  defp subscribe_missing(pool, realm, s) do
    missing = @kinds -- s.subscribed
    done(missing, pool, realm, s)
  end

  defp done([], _pool, _realm, s), do: s

  defp done(missing, pool, realm, s) do
    Enum.reduce(missing, s, fn kind, acc -> one(kind, pool, realm, acc) end)
    |> keep_ticking()
  end

  defp one(kind, pool, realm, s) do
    topic = topic_for(kind)

    case :macula.subscribe(pool, realm, topic, self()) do
      {:ok, ref} ->
        Logger.info("[ASociety] subscribed #{topic}")
        %{s | subscribed: [kind | s.subscribed], refs: Map.put(s.refs, ref, kind)}

      other ->
        Logger.warning("[ASociety] subscribe #{topic} failed: #{inspect(other)}")
        s
    end
  end

  defp keep_ticking(%{subscribed: subscribed} = s) when length(subscribed) == length(@kinds),
    do: s

  defp keep_ticking(s), do: rearm(s)

  defp rearm(%{timer: nil} = s), do: %{s | timer: Process.send_after(self(), :subscribe, @retry_ms)}
  defp rearm(s), do: s

  defp topic_for(kind), do: "#{namespace()}/#{kind}"

  defp namespace, do: Application.get_env(:asociety, :namespace, "society")

  # A fact with no island identity cannot be filed against anything and is
  # dropped rather than invented a key for. That is network input from a public
  # realm and a missing field is a version difference, not a crash.
  defp file(nil, _payload, s), do: s

  defp file(kind, payload, s) do
    fact = untag(payload)
    store(Map.get(fact, "island_id"), kind, fact)
    Phoenix.PubSub.broadcast(@pubsub, @channel, {:asociety_changed, kind})
    s
  end

  defp store(id, kind, fact) when is_binary(id), do: Board.put(id, kind, fact)
  defp store(_missing, _kind, _fact), do: :ok
end
