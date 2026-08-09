defmodule BeamCampusWeb.DronexMasterProfile do
  @moduledoc """
  Can the archipelago still beat what attacked it long ago?

  ## The one distinction, and why it gets a panel of its own

  Every ten minutes an island flies its best drone against a sample of the
  invaders that have raided it, one drawn from each age band. Pooled across the
  fleet, that is a win rate per age, and the SHAPE of it is the reading:

    * **level** is genuine progress. The population still beats what beat it
      long ago.
    * **falling away to the right** is a **treadmill**. The population is
      cycling, beating what it fights now and losing to what it used to beat,
      while every local number on this page rises.

  Nothing else on `/dronex` can say that. The two scripted exams are floor tests
  the fleet has cleared, and the raid record is relative: every island can
  improve at once and the win rate stays near a coin flip.

  ## ⚠ IT LIVES IN ITS OWN MODULE, NOT IN `DronexLive`

  That file is past 1,200 lines and holds eight components. A ninth would be
  another ninety lines nobody can find, and this one has its own vocabulary.

  ## ⚠⚠ POOLED, BECAUSE THE ISLANDS ARE NOT COMPETITORS

  They distribute one search across a mesh and make each other's opponents
  diverse. Where a drone was bred does not matter, and five per-island staircases
  at two fights apiece would destroy the alignment judgement the form exists for.
  Pooling CAN hide one island cycling while three hold level, so the per island
  numbers are in the table beneath and the caption says so.
  """
  use BeamCampusWeb, :html

  # The keys the browser needs. The per-island table travels with the reading and
  # never into `data-spec`: it is prose the server already rendered, and shipping
  # it twice would put a kilobyte of JSON behind a chart that cannot read it.
  @drawn [:kind, :bands, :won, :ceiling, :n, :cells]

  @doc """
  The panel: status line, chart, caption, and the per-island numbers behind it.

  ⚠ **IT NEVER GOES BLANK MID-DEPLOY.** Islands roll one at a time and the master
  tournament arrived at fact version 7, so half a fleet publishes none of it for
  a while. The chart draws on whatever contributed and the status line names the
  shortfall; a panel that required every island would disappear exactly when the
  fleet was changing.
  """
  attr :islands, :list, required: true

  def master_profile(assigns) do
    reading = Dronex.CompareTheEras.fleet(assigns.islands)

    assigns =
      assign(assigns,
        r: reading,
        spec: Jason.encode!(Map.take(reading, @drawn)),
        spoken: spoken(reading)
      )

    ~H"""
    <section :if={@r.islands > 0} class="settle mt-8">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h2 class="instrument-lede text-base font-semibold">
          Can the archipelago still beat what attacked it long ago?
        </h2>
        <span class="font-mono text-xs opacity-40">
          master tournament · a profile, never a score
        </span>
      </div>

      <p class="mt-1 font-mono text-xs opacity-40">{status(@r)}</p>

      <%!-- ⚠ THREE STATES BEHIND ONE EMPTY PANEL, AND THEY ARE NOT THE SAME
            NEWS. Nobody on the new build is a deploy that has not reached the
            fleet; on the new build and never flown is a timer that has not come
            round yet. Saying "no data" would send a reader to look in the wrong
            place. --%>
      <p :if={@r.measured == 0} class="instrument mt-2 p-3 text-xs opacity-60">
        {nothing_yet(@r)}
      </p>

      <div :if={@r.measured > 0} class="instrument mt-2 p-3">
        <div
          id="master-profile"
          phx-hook="DronexChart"
          phx-update="ignore"
          class="h-72 w-full"
          role="img"
          aria-label={@spoken}
          data-spec={@spec}
        >
        </div>
      </div>

      <p class="mt-2 max-w-3xl text-xs opacity-50">
        <span>
          Every ten minutes each island flies its best drone against a sample of
          the invaders that have raided it, one drawn from each age band, in the
          attacker's seat. Every island's engagements are <strong>pooled</strong>
          here, because they are not competitors: they distribute one search and
          make each other's opponents diverse, and where a drone was bred does
          not matter.
        </span>
        <%!-- ⚠ WITH ONE BAND MEASURED THE READING IS WITHDRAWN, not softened. A
              lone rule is trivially level, and level is the word this panel uses
              for progress. --%>
        <span :if={@r.measured == 1} class="mt-1 block">
          <strong>One age band so far.</strong> Level and falling mean nothing until there are two.
        </span>
        <%!-- ⚠ `measured > 1', NOT `measured != 1'. The second is also true of
              ZERO, so both no-chart states emitted the whole reading with no
              chart above it: a visitor arriving mid-roll read "0 flown against 0
              held is a thin sample of a deep archive" as a measurement of an
              archipelago that in fact holds hundreds of invaders and has simply
              not published the field yet. The section that exists to keep "has
              not sat it" apart from "sat it and lost" was adding a third
              confusion of its own. --%>
        <span :if={@r.measured > 1} class="mt-1 block">
          <strong>
            A level profile is genuine progress, because the archipelago still
            beats what beat it long ago. A profile that falls away to the right is
            a treadmill
          </strong>
          — a population cycling through opponents, beating what attacks it now and
          losing to what it used to beat, while every local number rises.
        </span>
        <span :if={@r.measured > 0} class="mt-1 block">
          The rule is the share won.
          <%!-- ⚠ A SECOND HAIRLINE FOR "won or drew"
          STOOD HERE AND WAS MEASURED OUT ON 2026-08-09: draws are zero in every
          published cell but one, across both exams and all five islands, so it
          sat exactly on top of the rule it was meant to differ from. The count
          is still in the tooltip and the table. --%>
          A band drawn faintly was decided by
          fewer than six engagements and is not a reading. A sitting flies at most
          twelve of what an island holds, so {@r.flown} flown against {@r.archived} held is a thin sample of a deep archive, and the
          oldest bands are the ones a sitting reaches last. Pooling can hide one
          island cycling while three hold level, so the per island numbers are in
          the table below.
        </span>
        <span class="mt-1 block">
          Ages are <strong>island uptime</strong>
          and a lower bound: the tick starves under load, and stops entirely while
          a container is down. An archive does not survive a restart, so after a
          deploy the right-hand bands empty for every island at once, which is a
          redeploy and not a decline. A blank band is an age nothing was drawn
          from, never an age that was lost.
        </span>
      </p>

      <details :if={@r.sat > 0} class="mt-2">
        <summary class="cursor-pointer text-xs opacity-50">the numbers behind this</summary>

        <div class="mt-2 overflow-x-auto">
          <table class="table table-xs">
            <thead>
              <tr>
                <th>island</th>
                <th :for={b <- @r.bands} class="text-right">{b.top} {b.bottom}</th>
                <th class="text-right">held</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={s <- @r.series}>
                <td class="whitespace-nowrap">
                  {s.island}
                  <span :if={s.state != :sat} class="opacity-40">· {said(s.state)}</span>
                </td>
                <td :for={c <- s.cells} class="text-right font-mono tabular-nums">
                  {(c && "#{c.w}/#{c.d}/#{c.l}") || "·"}
                </td>
                <td class="text-right font-mono tabular-nums">{s.archived}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="mt-1 max-w-3xl text-xs opacity-40">
          Won / drawn / lost, per island, per age band. A dot is an age that
          island drew nothing from. <strong>These are not summed and must not
          be</strong>: one number across ages needs weights across ages, and that
          judgement is what this instrument exists to avoid.
        </p>
      </details>
    </section>
    """
  end

  # ⚠ COVERAGE IS ALWAYS ON SCREEN, NEVER ONLY IN A TOOLTIP. A profile with no
  # denominator beside it invites a reader to interpret two fights.
  defp status(r) do
    Enum.join(
      [
        "#{r.sat} of #{r.islands} islands contributed",
        absent(r),
        "#{r.flown} engagements flown",
        # ⚠ HELD, NEVER "FACED". An archive holds 96 per island and evicts from
        # its fullest band, so this saturates and stops being a count of what
        # ever attacked.
        "#{r.archived} invaders held",
        reached(r.oldest)
      ]
      |> Enum.reject(&is_nil/1),
      " · "
    )
  end

  defp absent(%{unsat: 0, silent: 0, unreadable: 0}), do: nil

  defp absent(r) do
    [
      {r.unsat, "has not sat one yet"},
      {r.silent, "on an older build and publishes none"},
      {r.unreadable, "published numbers that do not line up"}
    ]
    |> Enum.reject(fn {n, _said} -> n == 0 end)
    |> Enum.map_join(" · ", fn {n, said} -> "#{n} #{said}" end)
  end

  defp reached(nil), do: nil
  defp reached(span), do: "measured back to #{span}"

  defp nothing_yet(%{silent: silent, islands: islands}) when silent == islands do
    "No island publishes a master tournament yet. It arrived at fact version 7 " <>
      "and the fleet rolls one island at a time."
  end

  defp nothing_yet(r) do
    "#{r.islands - r.silent} islands are on the new build and none has sat a " <>
      "tournament yet. The first sitting is about three minutes after an island " <>
      "boots, then every ten minutes, and the result does not survive a restart. " <>
      "Their archives hold #{r.archived} invaders between them."
  end

  defp said(:unsat), do: "not sat"
  defp said(:silent), do: "older build"
  defp said(:unreadable), do: "numbers do not line up"
  defp said(_sat), do: nil

  # The chart is never the only channel. This is the same reading as a sentence,
  # band by band, with "nothing drawn" kept distinct from a zero.
  defp spoken(%{measured: 0}), do: "Master tournament: nothing measured yet."

  defp spoken(r) do
    bands =
      r.bands
      |> Enum.zip(r.won)
      |> Enum.map_join(", ", fn {b, won} -> heard(won, b.span) end)

    "Master tournament, pooled across #{r.sat} islands. #{bands}."
  end

  defp heard(nil, span), do: "nothing drawn from #{span}"
  defp heard(won, span), do: "#{won} percent against invaders #{span}"
end
