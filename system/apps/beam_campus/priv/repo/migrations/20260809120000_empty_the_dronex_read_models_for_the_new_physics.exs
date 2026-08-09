defmodule BeamCampus.Repo.Migrations.EmptyTheDronexReadModelsForTheNewPhysics do
  @moduledoc """
  Empty every DroneX read model. The fleet was wiped and the physics changed
  under it, so nothing recorded before today is comparable to anything after.

  ⚠ WHY DELETION AND NOT A FLAG. On 2026-08-09 the guided interceptor went from
  600 m of reach to 60 m and from four rounds to two, and engagements moved from
  opening 400 m apart to 800 m. The islands started a new lineage the same day —
  a new event stream, `$dronex:roster_g2` — so every genome, every archived
  invader and every champion from before is gone at the source.

  What is left here is the shadow of that: raids fought with a weapon that owned
  most of the arena, exam profiles graded on ladders whose rung orders are now
  void, and champion reigns whose scores were earned in a different game. Kept
  alongside the new rows they would sit on the same axes, in the same charts,
  under the same headings, with nothing on the page saying which physics produced
  which point.

  ⚠⚠ AND THAT IS THE EXACT ERROR `REGISTER I.22` RECORDS, ONE LAYER OUT. There
  the exam had quietly moved inside the training set, so a rising line measured
  the curriculum rather than improvement. Here a line spanning today would
  measure the weapon change. Both are the same mistake: a series drawn across a
  discontinuity nobody marked.

  ⚠⚠⚠ THIS MUST BE DEPLOYED AFTER THE ISLANDS, NOT BEFORE, AND THE REASON IS THE
  ROLLING DEPLOY. Islands roll one at a time — watchtower within seconds on
  beam00-03, `podman auto-update` on a five minute timer on msi00 — so there is a
  window where some are on the new physics and some are not. An island still
  running the old image is still publishing old-physics samples, and this
  migration runs exactly once, at boot. Empty the tables during that window and
  the un-rolled islands simply refill them, silently, with the rows this exists to
  remove.

  So: push the island image, confirm all five are on it and publishing, and only
  then push the site. There is no code here that can enforce that, which is why it
  is written down here rather than assumed.

  ⚠⚠⚠⚠ THE TABLES SURVIVE, ONLY THE ROWS GO. The projections are unchanged and
  will refill from the mesh within minutes of the islands coming up, which is
  what makes this safe to run: the site holds no state of its own here, it is a
  reader. There is no `down/0` for the same reason — the rows are not
  reconstructible from anything the site has, and an island will not republish a
  lineage it no longer carries.
  """
  use Ecto.Migration

  def up do
    execute("DELETE FROM dronex_champions")
    execute("DELETE FROM dronex_raids")
    execute("DELETE FROM dronex_samples")
  end

  # ⚠ DELIBERATELY IRREVERSIBLE. Rolling back would have to invent rows, and
  # inventing rows on the one panel whose subject is provenance is worse than
  # refusing.
  def down do
    raise Ecto.MigrationError,
      message:
        "the pre-2026-08-09 DroneX lineage cannot be restored: the islands no longer carry it"
  end
end
