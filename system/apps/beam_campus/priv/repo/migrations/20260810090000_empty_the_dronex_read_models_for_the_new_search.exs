defmodule BeamCampus.Repo.Migrations.EmptyTheDronexReadModelsForTheNewSearch do
  @moduledoc """
  Empty every DroneX read model, again. The physics is unchanged this time; the
  SEARCH changed, and that moves the numbers just as thoroughly.

  ⚠ WHAT CHANGED, AND WHY IT IS A DISCONTINUITY. Measured on 2026-08-10 across
  all five rosters, 452 entries and 10,848 time constants: not one time constant
  in the archipelago was fast (below 0.2) or slow (above 0.8), after 150
  generations. `breed:random/1` drew every seeded tau into [0.406, 0.644], a
  quarter of what the encoding expresses, and one sigma quoted in gene units
  moved a tau at a quarter of a weight's pace through a range four times larger.
  The range was not being searched and could not be.

  Two changes followed. Seeding now draws time constants across their whole
  range with the step scaled to match, and the trainer seats a child while the
  roster has room instead of turning away anything that lost to the worst entry,
  which had left every island sitting at 25% to 64% of capacity. The islands
  started a new lineage the same day, `$dronex:roster_g3`.

  A `_g2` genome and a `_g3` genome were not produced by the same process. They
  start from different distributions and move at different rates, so their exam
  profiles, champion reigns and raid outcomes are not points on one series.

  ⚠⚠ SAME REASONING AS THE 2026-08-09 MIGRATION BESIDE THIS ONE, AND THE SAME
  ERROR IT NAMES. `REGISTER I.22`: a line drawn across a discontinuity nobody
  marked measures the discontinuity. There it was the exam moving inside the
  training set, then the weapon changing, now the search itself.

  ⚠⚠⚠ DEPLOY THIS AFTER THE ISLANDS, NOT BEFORE. Islands roll one at a time,
  watchtower within seconds on beam00-03 and `podman auto-update` on a five
  minute timer on msi00, so there is a window where some are on the new search
  and some are not. This migration runs exactly once, at boot. Empty the tables
  during that window and the un-rolled islands refill them with the rows it
  exists to remove. Push the island image, confirm all five are on it and
  publishing, and only then push the site.

  ⚠⚠⚠⚠ THE TABLES SURVIVE, ONLY THE ROWS GO. The projections are unchanged and
  refill from the mesh within minutes. There is no `down/0`: the rows are not
  reconstructible from anything the site holds, and an island will not republish
  a lineage it no longer carries.
  """
  use Ecto.Migration

  def up do
    execute("DELETE FROM dronex_champions")
    execute("DELETE FROM dronex_raids")
    execute("DELETE FROM dronex_samples")
  end

  # ⚠ DELIBERATELY IRREVERSIBLE, for the same reason as its predecessor. Rolling
  # back would have to invent rows, and inventing rows on the one panel whose
  # subject is provenance is worse than refusing.
  def down do
    raise Ecto.MigrationError,
      message: "the $dronex:roster_g2 lineage cannot be restored: the islands no longer carry it"
  end
end
