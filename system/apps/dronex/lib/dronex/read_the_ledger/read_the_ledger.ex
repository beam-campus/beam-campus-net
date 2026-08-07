defmodule Dronex.ReadTheLedger do
  @moduledoc """
  Who raided whom, and how it went, as a matrix of pairs.

  ## What this replaces, and why the thing it replaces was a lie

  There was a map. Islands sat on it at positions derived from a hash of their
  names — `Dronex.Archipelago` said so plainly, "a position is a hash of the
  island's name" — so **distance, adjacency and the length of a raid arc encoded
  nothing at all**. Four real facts (who raided whom, how often, roster fill,
  open or closed) were wrapped in a coordinate system that carried no
  information, and the wrapping was the part that looked impressive.

  A matrix keeps every one of those facts and drops the invented geography.

  ## ⚠ THE ARCHIPELAGO TOTAL HIDES THE DIRECTION

  Over 64 recordings the winner is 30 attacker to 34 defender, which reads as a
  coin flip and is the reason the fights looked like they carried no
  information. But that is the SUM over every pair. Raiding may have direction:
  an island that beats one neighbour and is beaten by another is invisible in a
  30–34 total and obvious in a grid.

  ## ⚠⚠ A RAID IN FLIGHT IS NOT A RAID THAT DID NOT HAPPEN

  Both sides publish a commitment on acceptance and the defender publishes the
  recording when the fight ends, so a pair with commitments and no recording is
  a raid still out — or one whose defender went dark, which looks the same from
  here and is exactly why both sides emit one. Counting those as zero would
  quietly write off every fight in progress.
  """

  @doc """
  Every ordered pair that has fought, keyed `{attacker_id, defender_id}`.

  `wins` and `losses` are from the ATTACKER's side, because the row is the
  attacker and a table whose two axes mean different things is a table nobody
  can read.
  """
  @spec pairs([map()]) :: %{{binary(), binary()} => map()}
  def pairs(raids) when is_list(raids) do
    Enum.reduce(raids, %{}, &tally/2)
  end

  defp tally(raid, acc) do
    raid
    |> sides()
    |> record(raid, acc)
  end

  # The recording is authoritative about who fought and who won: it is published
  # by the defender, which hosted the engagement and counted it.
  defp sides(%{parts: %{raid: [fact | _]}}),
    do: {Map.get(fact, "attacker_id"), Map.get(fact, "island_id"), Map.get(fact, "winner")}

  # No recording yet, so the attacker's own commitment names the pair. A defender
  # commitment names the same pair from the other end.
  defp sides(%{parts: %{committed: commitments}}) do
    Enum.find_value(commitments, {nil, nil, nil}, fn c ->
      case Map.get(c, "role") do
        "attacker" -> {Map.get(c, "island_id"), Map.get(c, "opponent_id"), :in_flight}
        "defender" -> {Map.get(c, "opponent_id"), Map.get(c, "island_id"), :in_flight}
        _unknown -> nil
      end
    end)
  end

  defp sides(_other), do: {nil, nil, nil}

  defp record({a, d, _outcome}, _raid, acc) when is_nil(a) or is_nil(d), do: acc
  defp record({same, same, _outcome}, _raid, acc), do: acc

  defp record({a, d, outcome}, _raid, acc) do
    Map.update(acc, {a, d}, cell(outcome), &add(&1, outcome))
  end

  defp cell(outcome), do: add(%{raids: 0, wins: 0, losses: 0, in_flight: 0}, outcome)

  defp add(c, :in_flight), do: %{c | in_flight: c.in_flight + 1}
  defp add(c, "attacker"), do: %{c | raids: c.raids + 1, wins: c.wins + 1}
  defp add(c, "defender"), do: %{c | raids: c.raids + 1, losses: c.losses + 1}
  # A draw is settled and is neither side's win. It still cost both of them.
  defp add(c, _draw), do: %{c | raids: c.raids + 1}

  @doc """
  The busiest single route, so a caption can say what the darkest cell means.

  Nil when nothing has been fought: a scale with no data is not a scale of zero.
  """
  @spec busiest(%{{binary(), binary()} => map()}) :: pos_integer() | nil
  def busiest(pairs) when map_size(pairs) == 0, do: nil

  def busiest(pairs) do
    pairs |> Map.values() |> Enum.map(& &1.raids) |> Enum.max() |> zero_is_nothing()
  end

  defp zero_is_nothing(0), do: nil
  defp zero_is_nothing(n), do: n
end
