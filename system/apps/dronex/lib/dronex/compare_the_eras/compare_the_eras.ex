defmodule Dronex.CompareTheEras do
  @moduledoc """
  Whether the archipelago still beats the invaders that raided it long ago.

  ## The one distinction this exists to make

  Every ten minutes an island flies its best drone against a sample of the
  invaders that have raided it, one drawn per **era**, where an era is the log2
  of how long ago that invader arrived. What comes back is a win/draw/loss
  profile across ages.

  The islands are not competitors and ranking them is not the point. They
  distribute one search across a mesh and make each other's opponents diverse.
  The problem being solved is *a population of drones that can defeat invaders*,
  and where a drone was bred does not matter. So every island's engagements are
  **pooled**, and what is drawn is one archipelago-wide profile.

  Read it as one judgement:

    * **level across ages** is genuine progress. The population still beats what
      beat it long ago.
    * **high on recent ages and low on old ones** is a **treadmill**. The
      population is cycling: it beats what it fights now and loses to what it
      used to beat, while every local number rises.

  ## ⚠ NEVER SUMMED, IN ANY FORM

  There is no score here, no total and no weighted average. One number across
  ages needs weights across ages, and that judgement is exactly what this
  instrument exists to avoid making silently. `Board.exam_score/2` is the one
  place on this site where a profile IS collapsed, for a leaderboard that needs
  one number by definition, and it says so out loud. This is not that.

  ## ⚠⚠ THIS IS NOT `Dronex.CompareTheExams` WITH A DIFFERENT PREFIX

  `profiles/2` there assumes one scalar `<prefix>_starts` as the denominator for
  every rung. Master has no such field: the per-era denominator is
  `wins + draws + losses`, and `master_flown` is the TOTAL across all eras.
  Feeding it in would produce rates wrong by a factor of the era count.

  And `common/1` there keeps only the drills every island sat, which is right
  for a fixed ladder and wrong here. Islands legitimately hold different age
  bands, and intersecting them would delete the oldest band from the fleet
  view — the only band the treadmill reading depends on. This unions with gaps.

  ## Eras pooled into five named age bands

  One tick is 50 ms nominal, so 20 ticks per second, and era `e` covers ages
  `[2^e, 2^(e+1))` ticks. Raw eras give a pooled denominator of two to eight and
  a non-contiguous axis nobody can label, so they are pooled into five fixed
  bands that are contiguous and exhaustive by construction:

      band  eras      ages
      A     up to 11  under 3m25
      B     12 to 13  3m25 to 13m39
      C     14 to 15  13m39 to 54m37
      D     16 to 18  54m37 to 7h17
      E     19 and up 7h17 and older

  This is pooling into coarser bins, not summing a profile: the profile ACROSS
  bands survives intact, which is the whole reading.

  ⚠ Ages are **island uptime**, and a **lower bound**. The tick timer shares a
  mailbox with training and gets pushed back under load, so 20 Hz is a ceiling.
  An island does not age while its container is down. And the archive does not
  survive a restart, so after a deploy the deepest reachable era for every
  island at once is roughly `log2(20 x seconds since restart)`.
  """

  alias Dronex.TellIslandsApart
  alias Dronex.WatchBouts.Board

  # ⚠ THE BANDS ARE FIXED AND ALL FIVE ARE ALWAYS RETURNED, measured or not. An
  # empty right-hand column must read as "we hold nothing that old", which is a
  # finding; a column that vanishes reads as nothing at all.
  # ⚠⚠ THESE EDGES WERE WRONG BY A FACTOR NEAR A HUNDRED AND WERE MEASURED, NOT
  # REASONED, INTO CORRECTNESS. The first version read the island's DEFAULT tick
  # constants and derived "one tick is 50 ms". On the fleet, 2026-08-09:
  #
  #   env:       HECATE_DRONEX_TICKS_PER_SLOT=1   (the default is 10)
  #   observed:  +10, +7, +9, +11, +15 ticks in 60 seconds
  #
  # so a tick was about six seconds, and it ran at different rates on different
  # islands, so the bands were not comparable across the mesh at all. The island
  # now stamps an invader's arrival in wall clock and an era is the log2 of its
  # age in SECONDS. `invaders:era_seconds/1` in the island repo publishes that
  # mapping, and these edges are the only place it is consumed.
  #
  # era e covers [2^e, 2^(e+1)) seconds.
  @bands [
    %{top: "under", bottom: "4 min", span: "under 4 minutes"},
    %{top: "4 to 34", bottom: "min", span: "4 to 34 minutes"},
    %{top: "34 min", bottom: "to 5 h", span: "34 minutes to 5 hours"},
    %{top: "5 to 36", bottom: "hours", span: "5 to 36 hours"},
    %{top: "over", bottom: "36 hours", span: "over 36 hours"}
  ]

  # The upper era of each band but the last, which takes everything above.
  # 2^8 = 256s = 4.3 min · 2^11 = 2048s = 34 min · 2^14 = 16384s = 4.6 h ·
  # 2^17 = 131072s = 36 h
  @edges [7, 10, 13, 16]

  @last length(@bands) - 1

  @doc """
  The pooled profile, the fleet's coverage, and the per-island numbers behind it.

  ## ⚠ FOUR ISLAND STATES, AND COLLAPSING ANY TWO IS A LIE

    * `:silent` — no `master_flown` key at all, so a build older than fact
      version 7. Islands roll one at a time and this is the normal mid-deploy
      state. `Map.get(v, "master_eras", [])` would collapse it into `:unsat`.
    * `:unsat` — on the new build, `master_flown` is 0. It has published a
      tournament field and has not flown one yet. The first sitting is about
      three minutes after an island boots, then every ten minutes, and the
      result is not persisted, so a restart returns an island here.
    * `:unreadable` — the vectors are not four equal-length lists of
      non-negative integers. Excluded and counted, never coerced to zero.
    * `:sat` — it flew one, and its engagements are pooled.

  `archived` is counted for every island that publishes it, sat or not, because
  "we hold nothing that old" and "we sampled nothing that old" are different
  findings and the archive depth is what separates them.
  """
  @spec fleet([map()]) :: map()
  def fleet(rows) when is_list(rows) do
    read = Enum.map(rows, &read/1)
    sat = Enum.filter(read, &(&1.state == :sat))
    pooled = sat |> Enum.map(& &1.bands) |> pool() |> comparable(sat)
    counts = Enum.map(0..@last, &decided(Map.get(pooled, &1)))

    reading(read, pooled, counts)
  end

  # ⚠⚠⚠ A BAND IS DRAWN ONLY WHEN EVERY CONTRIBUTING ISLAND CAN FILL IT, AND
  # WITHOUT THIS THE PANEL CAN MANUFACTURE ITS OWN HEADLINE.
  #
  # The whole reading is "level across the axis is progress, falling away to the
  # right is a treadmill". Pool naively and the set of islands behind each band
  # is not the same set. A restart empties an island's archive, so after every
  # deploy the young bands are held by all five islands and the oldest by the one
  # that has been up longest. If that island is mid-slump the pooled profile
  # falls away to the right and the panel announces, in bold, that the
  # archipelago is on a treadmill. Nothing has been forgotten: the right-hand
  # bands are a different sample of islands from the left-hand ones.
  #
  # That is the ordinary post-roll state of this fleet, not a corner case. So a
  # band that not every sat island can fill is dropped, and the caption says how
  # many were dropped rather than quietly narrowing the axis.
  defp comparable(pooled, []), do: pooled

  defp comparable(pooled, sat) do
    holders = Enum.map(sat, fn r -> MapSet.new(Map.keys(r.bands)) end)
    everyone = Enum.reduce(holders, &MapSet.intersection/2)

    :maps.filter(fn band, _cell -> MapSet.member?(everyone, band) end, pooled)
  end

  defp reading(read, pooled, counts) do
    measured = for {n, i} <- Enum.with_index(counts), n > 0, do: i

    %{
      kind: "master",
      bands: @bands,
      won: Enum.map(0..@last, &rate(Map.get(pooled, &1), :won)),
      ceiling: Enum.map(0..@last, &rate(Map.get(pooled, &1), :ceiling)),
      n: Enum.map(counts, &blank_when_zero/1),
      # The pooled counts behind each rate, for a tooltip that enhances rather
      # than gates: a band decided by two fights is not a reading, and the only
      # honest way to say so is to hand over the denominator.
      cells: Enum.map(0..@last, &cell(Map.get(pooled, &1))),
      islands: length(read),
      sat: tally(read, :sat),
      unsat: tally(read, :unsat),
      silent: tally(read, :silent),
      unreadable: tally(read, :unreadable),
      flown: Enum.sum(Enum.map(read, & &1.flown)),
      archived: Enum.sum(Enum.map(read, & &1.archived)),
      measured: length(measured),
      # ⚠ HOW MANY BANDS WERE DROPPED FOR NOT BEING COMPARABLE. Narrowing the
      # axis quietly would be its own lie: a reader would see a short, level
      # profile and never learn that the old bands exist and were set aside.
      incomparable: incomparable(read),
      newest: span_at(List.first(measured)),
      oldest: span_at(List.last(measured)),
      series: Enum.map(read, &row_of/1)
    }
  end

  # Bands that at least one island holds but not every island holds.
  defp incomparable(read) do
    sat = Enum.filter(read, &(&1.state == :sat))
    holders = Enum.map(sat, fn r -> MapSet.new(Map.keys(r.bands)) end)
    counted_bands(holders)
  end

  defp counted_bands([]), do: 0

  defp counted_bands(holders) do
    any = Enum.reduce(holders, &MapSet.union/2)
    all = Enum.reduce(holders, &MapSet.intersection/2)
    MapSet.size(MapSet.difference(any, all))
  end

  defp tally(read, state), do: Enum.count(read, &(&1.state == state))

  defp span_at(nil), do: nil
  defp span_at(i), do: Enum.at(@bands, i).span

  # ── one island ────────────────────────────────────────────────────────────

  defp read(row) do
    vitals = Dronex.fact(row, :vitals) || %{}

    row
    |> version(vitals, Board.has_master?(vitals))
    |> Map.put(:island, TellIslandsApart.spoken(row))
    |> Map.put(:id, row.id)
  end

  defp version(_row, _vitals, false), do: absent(:silent)

  defp version(_row, vitals, true) do
    vectors(vitals, Map.get(vitals, "master_flown"), Map.get(vitals, "master_archived", 0))
  end

  # ⚠ FOUR EQUAL-LENGTH LISTS OF NON-NEGATIVE INTEGERS, OR NOTHING. A list of
  # small integers can ride CBOR as a charlist, and this exhibit has already
  # misread a perfect result as three zeroes once. An island whose vectors do
  # not line up is excluded and counted, never folded in at whatever the numbers
  # happen to be.
  defp vectors(vitals, flown, archived) when is_integer(flown) and flown >= 0 do
    aligned(
      Enum.map(
        ["master_eras", "master_wins", "master_draws", "master_losses"],
        &ints(Map.get(vitals, &1))
      ),
      flown,
      archived
    )
  end

  defp vectors(_vitals, _flown, _archived), do: absent(:unreadable)

  defp aligned([eras, wins, draws, losses], flown, archived)
       when is_list(eras) and is_list(wins) and is_list(draws) and is_list(losses) do
    same_length? = Enum.all?([wins, draws, losses], &(length(&1) == length(eras)))
    sat(same_length?, flown, count(archived), Enum.zip([eras, wins, draws, losses]))
  end

  defp aligned(_ragged, _flown, _archived), do: absent(:unreadable)

  defp sat(false, _flown, _archived, _rows), do: absent(:unreadable)

  # It publishes the field and has not flown one. Its archive still counts: an
  # island holding 96 invaders it has never been measured against is a different
  # thing from one holding none.
  defp sat(true, 0, archived, _rows),
    do: %{state: :unsat, flown: 0, archived: archived, bands: %{}}

  defp sat(true, flown, archived, rows),
    do: %{state: :sat, flown: flown, archived: archived, bands: banded(rows)}

  defp absent(state), do: %{state: state, flown: 0, archived: 0, bands: %{}}

  defp ints(list) when is_list(list) do
    case Enum.all?(list, &(is_integer(&1) and &1 >= 0)) do
      true -> list
      false -> :ragged
    end
  end

  defp ints(_absent), do: :ragged

  defp count(n) when is_integer(n) and n >= 0, do: n
  defp count(_other), do: 0

  # ── pooling ───────────────────────────────────────────────────────────────

  defp banded(rows) do
    Enum.reduce(rows, %{}, fn {era, w, d, l}, acc ->
      Map.update(acc, band_of(era), {w, d, l}, fn {aw, ad, al} ->
        {aw + w, ad + d, al + l}
      end)
    end)
  end

  # ⚠ A UNION, NEVER AN INTERSECTION. Islands hold different age bands, and
  # keeping only the bands every island holds would delete the oldest one.
  defp pool(per_island) do
    Enum.reduce(per_island, %{}, fn bands, acc ->
      Map.merge(acc, bands, fn _band, {aw, ad, al}, {w, d, l} ->
        {aw + w, ad + d, al + l}
      end)
    end)
  end

  defp band_of(era), do: Enum.find_index(@edges, &(era <= &1)) || @last

  defp decided(nil), do: 0
  defp decided({w, d, l}), do: w + d + l

  defp blank_when_zero(0), do: nil
  defp blank_when_zero(n), do: n

  # ⚠ A BAND NOBODY DREW FROM IS `nil`, NEVER 0. A zero is a measurement; a gap
  # is an age nothing was sampled from, and the two must never look the same.
  defp rate(nil, _which), do: nil

  defp rate({w, d, l}, which), do: share(numerator(which, w, d), w + d + l)

  defp numerator(:won, w, _d), do: w
  defp numerator(:ceiling, w, d), do: w + d

  defp share(_top, 0), do: nil
  defp share(top, n), do: round(top * 100 / n)

  # ── the table twin ────────────────────────────────────────────────────────

  # Pooling can hide one island cycling while three hold level, so the per
  # island numbers are carried alongside the pooled profile rather than instead
  # of it. The chart never receives these.
  defp row_of(entry) do
    %{
      island: entry.island,
      id: entry.id,
      state: entry.state,
      flown: entry.flown,
      archived: entry.archived,
      cells: Enum.map(0..@last, &cell(Map.get(entry.bands, &1)))
    }
  end

  defp cell(nil), do: nil
  defp cell({w, d, l}), do: %{w: w, d: d, l: l, n: w + d + l}
end
