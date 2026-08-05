defmodule Dronex do
  @moduledoc """
  Read-only view onto the islands of the drone-AI track.

  An island is a `hecate-dronex` service running somewhere on the mesh. It breeds
  a population of drone controllers, sits a frozen exam it never trains against,
  and every twenty seconds publishes one engagement as a **recording**.

  ## It plays a recording and never runs the fight

  The bout fact carries every frame, already computed. This app stores it and
  animates it, which buys scrub, pause and slow motion and costs one transfer.

  **It could not run the fight if it wanted to: it does not have the engine.**
  The removed Robo Rumble page did the opposite, receiving two genomes and a
  start index and regenerating the duel locally, which put a game engine inside a
  content website, pinned the site and the service to commits that drifted apart,
  and made every viewer repeat identical work.

  ## What arrives, and what it is not

  ⚠ **A bout is a TRAINING bout, not a raid.** Nothing crosses the mesh yet: what
  is published is an island's own best controller against one of its own scripted
  drills. The fact says so in its `kind` field and this page repeats it, because
  calling it a raid would be the first lie this track told.
  """

  alias Dronex.WatchBouts
  alias Dronex.WatchBouts.Board

  @doc "Islands heard from, sorted by what they call themselves."
  defdelegate islands(), to: Board

  @doc "What to call an island, given its row."
  defdelegate label(row), to: Board

  @doc "One island's row by its 128-bit identity, or nil."
  defdelegate island(key), to: Board

  @doc "Islands refused because the board's cap was reached."
  defdelegate refused(), to: Board

  @doc "Milliseconds since this island last said anything."
  defdelegate quiet_for(row), to: Board

  @doc "Subscribe the calling LiveView to board changes."
  defdelegate subscribe(), to: WatchBouts

  @doc "Whether the site is configured to read this track at all."
  defdelegate configured?(), to: Dronex.Mesh

  @doc """
  Whether a healthy link exists, as against merely being configured.

  Distinct from `configured?/0` on purpose: configured-and-dark and
  never-configured look identical on a page unless it is told them apart, and
  they need different responses from whoever is reading.
  """
  def watching?, do: match?({:ok, _pool, _realm}, Dronex.Mesh.handle())

  @doc """
  What this reader is actually looking at, as one atom.

  FOUR STATES, AND EACH WANTS A DIFFERENT RESPONSE FROM WHOEVER IS READING.

    * `:unconfigured` — no seeds. A local clone. Nothing is wrong.
    * `:dark` — configured and no healthy link. A transport question.
    * `:silent` — subscribed and nothing has arrived. A transport question again,
      and a different one from `:dark`.
    * `:watching` — islands are on the board.

  Collapsing any two produces a page that sends the reader to look in the wrong
  place.
  """
  @spec state() :: :unconfigured | :dark | :silent | :watching
  def state, do: judge(configured?(), watching?(), islands() == [])

  defp judge(false, _watching, _empty), do: :unconfigured
  defp judge(true, false, _empty), do: :dark
  defp judge(true, true, true), do: :silent
  defp judge(true, true, false), do: :watching

  @doc """
  Raids the site knows about, newest first.

  Each carries whatever has arrived: one commitment, usually both, and the
  recording once the fight is over. A raid with commitments and no recording is
  one in flight — or one whose defender went dark, which looks the same from
  here and is exactly why both sides publish.
  """
  defdelegate raids, to: Dronex.WatchBouts.Board

  @doc """
  The most recent fight worth watching, and what kind it is.

  ⚠ **A RAID BEATS A TRAINING BOUT EVERY TIME.** A bout is one controller against
  a scripted drill: two marks, and the drill is not alive in any interesting
  sense. A raid is six evolved controllers against six others, bred on different
  machines under selection pressures neither chose. That is the thing this whole
  archipelago exists to produce, and it was being shown underneath a map of two
  circles.

  Falls back to a bout, because an island that has never been raided still has
  something to show and an empty canvas explains nothing.
  """
  def latest_fight do
    case newest_raid() do
      nil -> from_bout()
      raid -> {:raid, raid}
    end
  end

  defp newest_raid do
    raids()
    |> Enum.flat_map(fn r -> List.wrap(Map.get(r.parts, :raid)) |> Enum.take(1) end)
    |> List.first()
  end

  defp from_bout do
    islands()
    |> Enum.find_value(fn row -> fact(row, :bout) end)
    |> case do
      nil -> nil
      bout -> {:bout, bout}
    end
  end

  @doc "Whether a raid has been fought and drawn, as opposed to still being out."
  def finished?(%{parts: parts}), do: Map.has_key?(parts, :raid)
  def finished?(_other), do: false

  @doc "The two sides of a raid, as `{attacker_row, defender_row}` where known."
  def sides(%{parts: parts}) do
    commitments = Map.get(parts, :committed, [])

    {Enum.find(commitments, &(&1["role"] == "attacker")),
     Enum.find(commitments, &(&1["role"] == "defender"))}
  end

  @doc "One island's latest fact of a given kind, or nil."
  def fact(row, kind) when is_map(row), do: Map.get(row.facts, kind)
  def fact(_row, _kind), do: nil
end
