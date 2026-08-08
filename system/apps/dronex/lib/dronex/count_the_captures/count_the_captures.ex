defmodule Dronex.CountTheCaptures do
  @moduledoc """
  How many genomes an island is taking NOW, rather than how many it has ever taken.

  ## Why the old panel said nothing

  It drew `captures` as five sparklines. `captures` is a CUMULATIVE counter, and
  the window is a couple of hours against a total near seven and a half thousand,
  so a flat line was guaranteed by arithmetic whatever the fleet did. Worse, the
  shared zero-based scale that made the heights comparable squeezed five islands
  between 6,656 and 7,585 into about four pixels.

  So the panel carried neither shape nor level, and the honest reading of it was
  "a slightly horizontal line, what gives".

  A cumulative total answers *has this ever happened*. Only its first difference
  answers *is it happening*.

  ## ⚠ A COUNTER THAT WENT DOWN IS A RESTART, NOT A NEGATIVE CAPTURE

  `captures` only ever climbs on a running island, so a fall means the island
  restarted and began its count again. That bin is dropped rather than clamped to
  zero: a zero would say "took nothing", which is a claim about the fleet, and
  what actually happened is that the measurement broke.
  """

  # Ten minutes. Long enough that a bin holds several raids at the fleet's rate,
  # short enough that a two-hour window still has a dozen of them.
  @bin_ms 600_000

  @doc """
  Captures per bin per island, oldest bin first.

  `%{bins: [start_ms], series: [%{island, id, data}]}`, empty until some island
  has two samples in different bins.
  """
  @spec rate([map()], pos_integer()) :: map()
  def rate(rows, bin_ms \\ @bin_ms) when is_list(rows) do
    rows
    |> Enum.map(&taken(&1, bin_ms))
    |> Enum.reject(&(&1 == nil))
    |> aligned()
  end

  # ⚠ SORTED, NOT REVERSED. `Board.history/1` already reverses its ETS list to
  # hand back OLDEST FIRST, and reversing it again made every difference
  # negative, so every bin was discarded as a restart and the panel drew nothing.
  # Ordering that matters is worth stating rather than inheriting.
  defp taken(row, bin_ms) do
    samples = row.id |> Dronex.history() |> Enum.sort_by(& &1.at)
    counted(row, deltas(samples, bin_ms))
  end

  defp counted(_row, taken) when map_size(taken) == 0, do: nil

  defp counted(row, taken) do
    %{island: Dronex.TellIslandsApart.spoken(row), id: row.id, taken: taken}
  end

  # Consecutive differences, summed into bins keyed by the start of the bin.
  defp deltas(samples, bin_ms) do
    samples
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(%{}, fn [a, b], acc -> add(acc, a, b, bin_ms) end)
  end

  defp add(acc, %{captures: was}, %{captures: now, at: at}, bin_ms)
       when is_integer(was) and is_integer(now) and now >= was do
    Map.update(acc, div(at, bin_ms) * bin_ms, now - was, &(&1 + (now - was)))
  end

  # A fall in a monotone counter is a restart. The bin is left out entirely.
  defp add(acc, _was, _now, _bin_ms), do: acc

  defp aligned([]), do: %{bins: [], series: []}

  defp aligned(entries) do
    bins = entries |> Enum.flat_map(&Map.keys(&1.taken)) |> Enum.uniq() |> Enum.sort()

    %{
      bins: bins,
      series: for(e <- entries, do: %{island: e.island, id: e.id, data: filled(e, bins)})
    }
  end

  # ⚠ A BIN AN ISLAND HAS NO SAMPLES FOR IS NOT A BIN IN WHICH IT TOOK NOTHING.
  # `nil` draws a gap; a zero draws a bar of height nought and claims a
  # measurement that was never made.
  defp filled(entry, bins), do: for(b <- bins, do: Map.get(entry.taken, b))
end
