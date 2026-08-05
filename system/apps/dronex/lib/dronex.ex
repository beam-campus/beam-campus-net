defmodule Dronex do

  # ⚠ THE BASE SCORE IS EXCLUDED FROM THE REASON, and leaving it in made the
  # chooser useless: every raid outranks every bout by this much, so every
  # raid's "strongest reason" was the identical line "a raid: evolved against
  # evolved" and seven rows explained nothing. A reason has to be the strongest
  # DISTINGUISHING one, or a list of reasons is a list of the same reason.
  @base 1000
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

  @doc """
  Every fight the site could draw, best first.

  ⚠ **THIS RANKING IS A HEURISTIC FOR ORDERING A LIST AND NOTHING ELSE.** It is
  not a measurement, no register entry may cite it, and it decides nothing about
  the world. It exists because with four islands there are up to twelve directed
  pairs raiding each other and "the newest one" is a poor way to choose what a
  visitor sees first: the newest fight is very often a rout.

  What it rewards, said plainly so the list is not a black box:

    * a **raid** over a training bout, always. A bout is one evolved controller
      against a scripted drill; a raid is twelve evolved controllers against
      twelve others bred on a different machine under pressures neither side
      chose. That is the thing this archipelago exists to produce.
    * **both sides bleeding.** A fight where one side lost nothing is a rout, and
      a rout is the same picture every time.
    * **closeness**, by how near the two survivor counts finished.
    * **an attacker win**, because attacking is priced twice — airframes spent,
      and no ground network in somebody else's airspace — so a raider that wins
      did something harder than a defender that held.
    * **length**, mildly. A fight that ran long was contested.

  Each entry carries `why`, the single strongest reason it is here, so a visitor
  can see the ranking's opinion rather than being asked to trust it.
  """
  def watchable do
    (Enum.flat_map(raids(), &watchable_raid/1) ++ Enum.flat_map(islands(), &watchable_bout/1))
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp watchable_raid(%{id: id, parts: parts}) do
    case Map.get(parts, :raid) do
      [fact | _] -> [scored({:raid, id}, :raid, fact)]
      _none -> []
    end
  end

  defp watchable_bout(row) do
    case fact(row, :bout) do
      nil -> []
      fact -> [scored({:bout, row.id}, :bout, fact)]
    end
  end

  defp scored(key, kind, fact) do
    reasons = reasons(kind, fact)

    %{
      key: key,
      kind: kind,
      fact: fact,
      title: title(kind, fact),
      score: Enum.sum(Enum.map(reasons, &elem(&1, 0))),
      why: why(Enum.reject(reasons, &(elem(&1, 0) >= @base)))
    }
  end

  # {points, reason}. The reason is shown; the points only order the list.
  defp reasons(:bout, _fact), do: [{0, "a training bout against a scripted drill"}]

  defp reasons(:raid, f) do
    sent = num(f, "raiders")
    home = num(f, "raiders_home")
    held = num(f, "defenders")
    stood = num(f, "defenders_home")

    [
      {@base, "a raid: evolved against evolved"},
      bled(home < sent and stood < held),
      close(abs(home - stood)),
      upset(Map.get(f, "winner")),
      contested(num(f, "ticks"))
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp bled(true), do: {300, "both sides lost airframes"}
  defp bled(false), do: nil

  defp close(0), do: {400, "it finished level"}
  defp close(gap) when gap <= 3, do: {400 - gap * 60, "it finished within #{gap}"}
  defp close(_wide), do: nil

  defp upset("attacker"), do: {250, "the raider won, away and outnumbered by its ground"}
  defp upset(_other), do: nil

  defp contested(ticks) when ticks > 600, do: {120, "it ran long"}
  defp contested(_short), do: nil

  defp why([]), do: "a raid, and nothing else to say for it"
  defp why(reasons), do: reasons |> Enum.max_by(&elem(&1, 0)) |> elem(1)

  defp title(:raid, f), do: "#{name_of(Map.get(f, "attacker_id"))} → #{Map.get(f, "island")}"
  defp title(:bout, f), do: "#{Map.get(f, "island")} against a drill"

  defp name_of(nil), do: "somebody"

  defp name_of(id) do
    case island(id) do
      nil -> String.slice(to_string(id), 0, 8)
      row -> label(row)
    end
  end

  @doc """
  Islands ranked, and ranked on the FROZEN BENCHMARK rather than on raids.

  ⚠ **THE RAID RECORD IS SHOWN AND IS DELIBERATELY NOT THE RANKING.** Raids are
  not comparable between islands: who you fought, how often, and whether your
  neighbours were awake all move the number, and an island that raided a weak
  neighbour twenty times would top a table it never earned. The benchmark is the
  only number every island earns on identical terms — the same scripted drills
  from the same fixed starts, flown as an AWAY game with no ground network at
  all, so it scores the controller and never the terrain.

  That is also why the benchmark was built before any breeding existed: a rising
  number against a moving exam is an artifact, and a leaderboard is exactly the
  place that artifact would be laundered into a fact.
  """
  def leaderboard do
    islands()
    |> Enum.map(&standing/1)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp standing(row) do
    v = fact(row, :vitals) || %{}
    rungs = length(Map.get(v, "benchmark_rungs", []))
    starts = num(v, "benchmark_starts")
    wins = Enum.sum(Map.get(v, "benchmark_wins", []))

    %{
      island: label(row),
      id: row.id,
      score: percent(wins, rungs * starts),
      rungs: rungs,
      generation: num(v, "generation"),
      roster: num(v, "roster"),
      capacity: num(v, "capacity"),
      raids: num(v, "raids"),
      captures: num(v, "captures"),
      defences: num(v, "defences")
    }
  end

  defp percent(_w, 0), do: 0
  defp percent(w, n), do: div(w * 100, n)

  defp num(map, key) when is_map(map) do
    case Map.get(map, key) do
      n when is_integer(n) -> n
      _otherwise -> 0
    end
  end

  defp num(_map, _key), do: 0
end
