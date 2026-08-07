defmodule Dronex.WeighTheExperience do
  @moduledoc """
  Does having bred longer win wars? The one question that joins this exhibit's
  two halves.

  ## Why this is the chart worth more than the rest

  Everything else here measures one of two things and never both. The frozen exam
  measures SKILL, against a fixed ladder that never changes. The raids measure
  WAR, against opponents that do. Nothing connects them, so the page can say an
  island is good at drills and that it wins fights, and never whether the first
  causes the second.

  The stamps make the join possible: every raid now carries where each side was
  in its own breeding when it was fought. Both answers teach. If the gap predicts
  the winner, evolution is doing what this exhibit claims. If it does not, then
  exam skill does not transfer to combat — which for a research commons is the
  more interesting sentence, and no other chart here can produce it.

  ## ⚠ `rounds`, NEVER `generation`

  `generation` is `lists:max` over the roster and `raid:absorb/3` admits captured
  genomes at generation 0, so an island that absorbs a swarm has its generation
  CUT without having bred any less. `rounds` is the breeding clock and only ever
  climbs. Using the wrong one would make "more experienced" mean "has not been
  raided lately".

  ## ⚠⚠ AN UNSTAMPED RAID IS EXCLUDED, NEVER TREATED AS ZERO

  The stamp shipped after these islands had been fighting for days, and a fleet
  mid-roll has both versions on the wire at once: a raid between an updated
  attacker and a defender still on the old image carries one stamp and not the
  other. An older island publishes `0`, and a zero read as a reading would put a
  gap of *the attacker's entire breeding history* on the plot.

  So a raid counts only when BOTH sides are stamped, and the ones that are not
  are counted and reported. A chart that silently drew what it had would be
  answering a different question convincingly.
  """

  @doc """
  One point per settled raid where both sides are stamped, plus what was left out.

  `gap` is the attacker's rounds minus the defender's: positive means the raider
  had bred longer.
  """
  @spec gaps([map()]) :: %{points: [map()], excluded: map()}
  def gaps(raids) when is_list(raids) do
    {points, excluded} = Enum.reduce(raids, {[], blank()}, &weigh/2)
    %{points: Enum.reverse(points), excluded: excluded}
  end

  defp blank, do: %{unsettled: 0, unstamped: 0}

  defp weigh(raid, {points, out}) do
    recording = Enum.at(Map.get(raid.parts, :raid, []), 0)
    place(recording, raid, points, out)
  end

  # No recording: the raid is still out, or its defender went dark. Either way it
  # has no outcome, so it is not a missing stamp and must not be counted as one.
  defp place(nil, _raid, points, out), do: {points, %{out | unsettled: out.unsettled + 1}}

  defp place(recording, raid, points, out) do
    commitments = Map.get(raid.parts, :committed, [])

    attacker = rounds_of(role(commitments, "attacker"))
    # ⚠ TWO SOURCES FOR THE DEFENDER AND THAT IS DELIBERATE. It publishes both a
    # commitment and the recording, and either may be from the older image, so
    # taking whichever carries a stamp keeps raids a stricter reading would drop.
    defender = first_stamp([role(commitments, "defender"), recording])

    keep(attacker, defender, recording, points, out)
  end

  defp keep(a, d, recording, points, out) when is_integer(a) and is_integer(d) do
    {[
       %{
         gap: a - d,
         winner: Map.get(recording, "winner"),
         attacker_rounds: a,
         defender_rounds: d
       }
       | points
     ], out}
  end

  defp keep(_a, _d, _recording, points, out),
    do: {points, %{out | unstamped: out.unstamped + 1}}

  defp role(commitments, which),
    do: Enum.find(commitments, &(Map.get(&1, "role") == which))

  defp first_stamp(sources), do: Enum.find_value(sources, &rounds_of/1)

  # ⚠ ZERO IS AN OLDER ISLAND, NOT A ROSTER THAT HAS NEVER BRED. An island that
  # has genuinely run no rounds has also never fielded a raiding party, so a zero
  # here always means "published by something that did not carry the field".
  defp rounds_of(%{"rounds" => n}) when is_integer(n) and n > 0, do: n
  defp rounds_of(_absent), do: nil

  @doc """
  The points split into the lanes a strip plot draws, newest first.

  A draw is its own lane rather than folded into either: it is an outcome both
  sides paid for and neither won.
  """
  @spec lanes([map()]) :: [{String.t(), [map()]}]
  def lanes(points) do
    by = Enum.group_by(points, &Map.get(&1, "winner", &1.winner))

    # The same three words the histogram and the replay use, from one place.
    for {wire, said, _role} <- Dronex.SayWhoWon.every(), do: {said, Map.get(by, wire, [])}
  end
end
