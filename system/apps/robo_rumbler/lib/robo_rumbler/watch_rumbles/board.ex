defmodule RoboRumbler.WatchRumbles.Board do
  @moduledoc """
  What the site knows about the rumble, held in ETS and nowhere else.

  ## No store, on purpose

  The site is a reader. The durable record of every visit is the rumbler's own
  content-addressed archive on beam03; this is a window onto the facts that
  happened to arrive while this node was up. Restart it and it is empty until the
  next fact lands, and that is the correct behaviour for a spectator: nothing here
  is a source of truth, so nothing here needs to survive.

  ## Why ETS rather than the subscriber's state

  A hundred spectators must not queue behind one gen_server to read a page. The
  table is public and read-optimised, so a LiveView mount reads it directly and
  the subscriber is only ever on the write path.

  ## Bounded, and it forgets the oldest

  A rumbler that runs for a month would otherwise fill this node's memory with
  rows nobody scrolls back to. The caps are small and deliberate.
  """

  @table :robo_rumbler_board
  @visits 25
  @duels 10

  @doc "Create the table. Called by the subscriber, which owns it."
  def init do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
  end

  @doc "The roster a visitor faces: 40 residents, published once per field version."
  def field, do: one(:field)

  @doc "Settled rows, newest first."
  def visits, do: many(:visits)

  @doc "Featured duels, newest first. Each is replayable; see `RoboRumbler.replay/1`."
  def duels, do: many(:duels)

  @doc """
  Challengers whose battles are running right now, newest first.

  Derived from arrivals that have not yet been answered by a settled row. This is
  the only thing on the page that is true for a few seconds at a time, and it is
  why arrivals are published separately from results.
  """
  def fighting, do: Map.values(one(:live) || %{})

  @doc "Whether anything at all has arrived yet."
  def empty?, do: field() == nil and visits() == []

  # ── Writes. Subscriber only. ────────────────────────────────────

  def put_field(fact), do: :ets.insert(@table, {:field, fact})

  def put_arrival(fact) do
    live = Map.put(one(:live) || %{}, fact["challenger_id"], fact)
    :ets.insert(@table, {:live, live})
  end

  @doc """
  Record a settled row and retire the matching arrival.

  Retiring by challenger id rather than by a timer is what keeps "fighting now"
  honest: a battle that never settles because the rumbler died stays listed, which
  is visible and therefore fixable, where a timer would quietly erase the evidence.
  """
  def put_visit(fact) do
    live = Map.delete(one(:live) || %{}, fact["challenger_id"])
    :ets.insert(@table, {:live, live})
    :ets.insert(@table, {:visits, Enum.take([fact | visits()], @visits)})
  end

  def put_duel(fact), do: :ets.insert(@table, {:duels, Enum.take([fact | duels()], @duels)})

  # ── Internals ───────────────────────────────────────────────────

  defp one(key) do
    case :ets.lookup(@table, key) do
      [{^key, v}] -> v
      [] -> nil
    end
  end

  defp many(key), do: one(key) || []
end
