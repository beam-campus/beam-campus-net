defmodule Dronex.CompareTheExams do
  @moduledoc """
  Every island's exam profile, side by side, on the drills they all sat.

  ## Why a profile and not a rank

  The frozen exam is the only measure on this page that is ABSOLUTE. Raids are
  relative: every island can improve, or every island can decay, and the win rate
  stays near a coin flip either way. Today it is 48% fleet-wide and says nothing.

  But the exam has been collapsed to one percentage everywhere it appears, and
  `REGISTER D.15` is that the percentage swings up to a hundred points in a day
  on a champion the island says it bred. A number nobody can interpret should not
  be the thing a leaderboard sorts on.

  The six numbers behind it CAN be interpreted, because the drills are named and
  ordered by difficulty:

      hoverer    holds station, unarmed        can you kill anything at all
      orbiter    flies a circle, unarmed       can you kill something moving
      evader     turns away and runs, unarmed  can you catch it
      chaser     closes and shoots             can you win a fight it chose
      duellist   closes, shoots, breaks off    has to be finished
      sniper     holds station and shoots      it never pays for closing

  Measured 2026-08-07: beam00 ran 46, 47, 47 then 21, 24 then 41 out of 48, and
  beam01 ran 24, 23, 27 then 3, 10 then 24. Both hold up against the three
  unarmed drills and fall apart against `chaser` and `duellist`, the two that
  shoot AND close, while partly recovering against the stationary `sniper`.
  beam02 and beam03 were flat across all six.

  That is a named deficit, that these controllers cannot fight something which
  comes at them, and no single percentage can say it.

  ## ⚠ ONLY THE DRILLS EVERY ISLAND SAT

  Islands roll one at a time, so mid-deploy one may publish a ladder the others
  have never seen. Comparing across a drill only some of them sat would leave a
  gap beside a score and invite it to be read as a failure.
  """

  @doc """
  `%{drills: [name], series: [%{island, id, rates}]}`, empty until somebody sits it.

  ## ⚠ TWO EXAMS NOW, AND ONLY ONE OF THEM MAY BE CALLED IMPROVEMENT

  `"benchmark"` is the CURRICULUM: six of the opponents the trainer breeds
  against, so what it reports is performance against the training set.
  `REGISTER I.22` has the arithmetic — between about 11% and 28% of breeding
  rounds per island draw one of these six as an opponent — and it was promised
  as held-out in four separate documents while being enforced in none.

  `"trials"` is the HELD-OUT exam: six opponents that shoot AND close, which
  nothing trains against and which a test in the island repository keeps that
  way. It arrived at fact version 5, so an island on an older build publishes
  none and is simply absent from the comparison rather than drawn at zero.
  """
  @spec profiles([map()], String.t()) :: map()
  def profiles(rows, prefix \\ "benchmark") when is_list(rows) do
    rows
    |> Enum.map(&sat(&1, prefix))
    |> Enum.reject(&is_nil/1)
    |> aligned()
  end

  defp sat(row, prefix) do
    vitals = Dronex.fact(row, :vitals) || %{}

    entry(
      row,
      Map.get(vitals, prefix <> "_rungs", []),
      counts(Map.get(vitals, prefix <> "_wins")),
      Map.get(vitals, prefix <> "_starts", 0)
    )
  end

  # ⚠ AS A LIST OF INTEGERS, WHATEVER THE WIRE CALLS IT. A list of small integers
  # may arrive as a charlist, and this session already misread a perfect 288/288
  # as three zeroes once.
  defp counts(wins) when is_list(wins), do: Enum.filter(wins, &(is_integer(&1) and &1 >= 0))
  defp counts(_absent), do: []

  defp entry(_row, drills, wins, starts) when drills == [] or wins == [] or starts <= 0, do: nil

  defp entry(row, drills, wins, starts) when length(drills) == length(wins) do
    %{
      island: Dronex.TellIslandsApart.spoken(row),
      id: row.id,
      drills: drills,
      rates: Enum.map(wins, &min(100, div(&1 * 100, starts)))
    }
  end

  # A ladder and a result list of different lengths is a pair nobody can align.
  defp entry(_row, _drills, _wins, _starts), do: nil

  defp aligned([]), do: %{drills: [], series: []}
  defp aligned(entries), do: build(common(entries), entries)

  defp build([], _entries), do: %{drills: [], series: []}

  defp build(drills, entries) do
    %{
      drills: drills,
      series:
        for e <- entries do
          %{island: e.island, id: e.id, rates: for(d <- drills, do: rate_of(e, d))}
        end
    }
  end

  # The drills every island sat, in the order the first lists them, because a
  # ladder is ordered by difficulty and sorting it any other way destroys the
  # only thing that order carries.
  defp common([first | rest]) do
    Enum.filter(first.drills, fn d -> Enum.all?(rest, &(d in &1.drills)) end)
  end

  defp rate_of(entry, drill) do
    Enum.at(entry.rates, Enum.find_index(entry.drills, &(&1 == drill)))
  end
end
