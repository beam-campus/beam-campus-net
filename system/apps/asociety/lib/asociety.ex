defmodule ASociety do
  @moduledoc """
  Read-only view onto the islands of the artificial-cultures track.

  An island is a `hecate-society` service running somewhere on the mesh. Its
  people hold beliefs, teach them to each other, and decide who may land. This
  app subscribes and renders. **It never publishes, never runs an island, and
  takes no dependency on the island's code.**

  The contract is the published fact and its `fact_version`. A sibling did it the
  other way, sharing an engine library between the service and the site, and the
  two ended up pinned to different commits with a fingerprint that drifted and
  nothing comparing them.

  ## What it will draw, and what it will not

  Not a map. There is no space inside an island in this design: an island is an
  undifferentiated population, so a hundred persons would be a hundred identical
  dots, and position would be the one thing the model does not have.

  **The subjects are beliefs, not believers.** Cultural fitness in that design is
  the number of learners a variant reaches, so the thing being selected is the
  belief and the person is the substrate it lives in. Twenty bands of colour
  rising and falling say what a hundred dots cannot.

  ## Nothing arrives yet, and the page says so

  `hecate-society` publishes no facts at this commit. Four islands are deployed
  and healthy and hold no people. That is the honest state and it is what
  `state/0` reports, rather than an empty chart that looks like a broken feed.
  """

  alias ASociety.WatchIslands
  alias ASociety.WatchIslands.Board

  @doc "Islands heard from, sorted by what they call themselves."
  defdelegate islands(), to: Board

  @doc "What to call an island, given its row."
  defdelegate label(row), to: Board

  @doc "Whether anything has arrived yet."
  defdelegate empty?(), to: Board

  @doc "Islands refused because the board is full. Non-zero means a page is lying."
  defdelegate refused(), to: Board

  @doc "Milliseconds since this island last said anything, or `nil`."
  defdelegate quiet_for(row), to: Board

  @doc "Subscribe the calling process to board changes."
  defdelegate subscribe(), to: WatchIslands

  @doc "Which topics this reader listens on. Empty while the island is silent."
  defdelegate kinds(), to: WatchIslands

  @doc "Whether the site is configured to read islands at all."
  def configured?, do: ASociety.Mesh.configured?()

  @doc """
  Whether a mesh handle actually exists right now.

  Distinct from `configured?/0` on purpose: configured-and-dark and
  never-configured look identical on a page unless it is told them apart, and
  they need different responses from whoever is reading.
  """
  def watching? do
    match?({:ok, _pool, _realm}, ASociety.Mesh.handle())
  end

  @doc """
  What this reader is actually looking at, as one atom.

  FIVE STATES, AND EACH WANTS A DIFFERENT RESPONSE FROM WHOEVER IS READING.

    * `:unconfigured` — no seeds. A local clone. Nothing is wrong.
    * `:dark` — configured and no healthy link. A transport question.
    * `:no_contract` — connected, and the island publishes nothing yet, so there
      is no topic to subscribe to. **This is the state today**, and it is a
      statement about the island's build rather than about the mesh.
    * `:silent` — subscribed and nothing has arrived. A transport question again,
      and a different one from `:dark`.
    * `:watching` — islands are on the board.

  Collapsing any two of these produces a page that sends the reader to look in
  the wrong place, which is the failure the sibling's four-state liveness check
  exists to prevent.
  """
  @spec state() :: :unconfigured | :dark | :no_contract | :silent | :watching
  def state, do: judge(configured?(), watching?(), kinds(), empty?())

  defp judge(false, _watching, _kinds, _empty), do: :unconfigured
  defp judge(true, false, _kinds, _empty), do: :dark
  defp judge(true, true, [], _empty), do: :no_contract
  defp judge(true, true, _kinds, true), do: :silent
  defp judge(true, true, _kinds, false), do: :watching

  @doc """
  What each state means, in words, and where it sends the reader.

  Lives here rather than in the page because the sentence is part of the state:
  the whole reason for having five is that they point at different things, and a
  page that collapsed two of them would look helpful and be wrong. A test asserts
  the five are distinct.
  """
  @spec explain(atom()) :: String.t()
  def explain(:unconfigured),
    do:
      "This site is not configured to read the society realm. That is normal for " <>
        "a local clone: naming a public realm costs nothing, dialling a production " <>
        "station from every clone does."

  def explain(:dark),
    do:
      "Configured, and no healthy link to a station. The islands may be running " <>
        "perfectly and unreachable from here. This is a transport question."

  def explain(:no_contract),
    do:
      "Connected, and there is nothing to subscribe to yet. hecate-society " <>
        "publishes no facts at this commit: four islands are deployed, healthy, " <>
        "and hold no people. This page is scaffolding waiting on the island's " <>
        "first fact, and it would rather say so than draw an empty chart."

  def explain(:silent),
    do:
      "Subscribed, and nothing has arrived. Different from dark: the link is " <>
        "healthy, so either the islands are quiet or the facts are going " <>
        "somewhere else."

  def explain(:watching), do: "Islands are reporting."

  @doc "Human-readable elapsed time, for a page to show next to a quiet island."
  def since(ms) when ms < 60_000, do: "#{div(ms, 1000)}s"
  def since(ms) when ms < 3_600_000, do: "#{div(ms, 60_000)}m"
  def since(ms), do: "#{div(ms, 3_600_000)}h"
end
