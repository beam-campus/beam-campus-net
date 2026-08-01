defmodule BeamCampus.Repo.Migrations.EmptyBiotopeSamplesForWorldTen do
  @moduledoc """
  World 10 is a different game, so the history of world 9 goes.

  The standing rule since world 6: **every new world gets one of these.** The
  island page promises that only samples sharing an island's current rules are
  drawn, and wiping is the cheap way to keep that promise.

  ## World 10 changes no constant either, which is why the fingerprint cannot help

  The change is that a predator takes `min(uptake, frame, what is there)` from a
  victim instead of the whole of it, and buries what it cannot hold. Not one
  number in the economy moves, so world 9's samples and world 10's carry an
  **identical `econ_id`**, exactly as world 8's and world 9's did. This is the
  second world running where the fingerprint filter is blind and the wipe is the
  only thing separating two games.

  It matters here because the change is visible in the curves. Energy from
  creatures falls from 31% to 21% and `ground_spread` from 86 to 60, so a series
  spanning the change would draw a step that reads as something the world did
  rather than as a deploy.

  ## The restart guard now covers the ordering hazard, and this is still worth doing

  `RecordHistory` drops an island's earlier rows when its tick goes backwards, so
  a restarted island cleans up after itself and the old "release the islands
  first or the wipe lands too early" trap is much less sharp than it was. That
  guard fires per island on restart; this fires once, for the whole table, at the
  moment the site is released. Two different scopes, and the cheap one is not a
  reason to drop the standing rule.
  """
  use Ecto.Migration

  def up, do: execute("DELETE FROM biotope_samples")
  def down, do: execute("DELETE FROM biotope_samples")
end
