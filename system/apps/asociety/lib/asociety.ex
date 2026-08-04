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

  @doc "The last `vitals` fact from this island, or `nil`."
  @spec vitals(map()) :: map() | nil
  def vitals(%{facts: facts}), do: Map.get(facts, :vitals)
  def vitals(_row), do: nil

  @doc """
  The nine need levels paired with their own names.

  ⚠ THE NAMES COME OFF THE WIRE, NOT OUT OF THIS FILE. The island publishes its
  axis names beside the vector precisely so a reader never has to mirror an order
  it cannot see change. An island a version ahead, with a tenth axis, renders
  correctly here without this app being redeployed.

  A fact whose two lists disagree in length is a version difference or a truncated
  frame, and it costs the panel rather than the page.
  """
  @spec needs(map() | nil) :: [{String.t(), integer()}]
  def needs(nil), do: []

  def needs(fact) do
    axes = Map.get(fact, "axes", [])
    levels = Map.get(fact, "needs", [])
    paired(is_list(axes) and is_list(levels) and length(axes) == length(levels), axes, levels)
  end

  defp paired(true, axes, levels), do: Enum.zip(axes, levels)
  defp paired(false, _axes, _levels), do: []

  @doc """
  How many satisfiers in use are of each Max-Neef class.

  A violator claims to meet a need while making it harder to meet. It is the
  measurable form of a culture being bad for the persons carrying it, which is
  why it is on the wire and on the page rather than left to be inferred.
  """
  @spec satisfier_classes(map() | nil) :: [{String.t(), integer()}]
  def satisfier_classes(nil), do: []

  def satisfier_classes(fact) do
    for c <- ~w(synergic singular inhibiting pseudo violator),
        is_integer(Map.get(fact, c)),
        do: {c, Map.get(fact, c)}
  end

  @doc "The full level scale a need is measured on, so a bar knows its own maximum."
  def level_ceiling, do: 1000

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
    * `:silent` — subscribed and nothing has arrived. A transport question again,
      and a different one from `:dark`.
    * `:watching` — islands are on the board.

  Collapsing any two of these produces a page that sends the reader to look in
  the wrong place, which is the failure the sibling's four-state liveness check
  exists to prevent.

  ## `:no_contract` was a fifth state and is gone, deliberately

  It meant "connected, and the island publishes nothing, so there is no topic to
  subscribe to" — a statement about the island's build rather than about the
  mesh, and it was the honest state for as long as `hecate-society` published
  nothing.

  The island publishes now. **The compiler noticed before I did**: with `@kinds`
  no longer empty, the clause matching an empty topic list became unreachable and
  `--warnings-as-errors` refused to build. A state that cannot occur is a lie in
  the documentation, so it went rather than being left as reassuring dead code.
  """
  @spec state() :: :unconfigured | :dark | :silent | :watching
  def state, do: judge(configured?(), watching?(), empty?())

  defp judge(false, _watching, _empty), do: :unconfigured
  defp judge(true, false, _empty), do: :dark
  defp judge(true, true, true), do: :silent
  defp judge(true, true, false), do: :watching

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
