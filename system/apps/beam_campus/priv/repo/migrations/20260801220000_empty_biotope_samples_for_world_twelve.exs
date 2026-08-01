defmodule BeamCampus.Repo.Migrations.EmptyBiotopeSamplesForWorldTwelve do
  @moduledoc """
  Worlds 11 and 12 are different games, so the history of world 10 goes.

  The standing rule since world 6: **every new world gets one of these.** Two
  worlds are covered by one wipe because **world 11 was never deployed** — the
  fleet goes from 10 straight to 12, and there is no world 11 history to keep.

  ## Neither world changes a constant, so the fingerprint filter is blind again

  World 11 made feeding a property of a creature rather than of a contest, and
  world 12 gave movement a speed and a fare that scales with the body. Not one
  number in the economy moves for either, so world 10's samples and world 12's
  carry an **identical `econ_id`**. That is the fourth world running where the
  fingerprint cannot separate two games and the wipe is the only thing that can.

  It matters more here than it has yet, because world 12 moved almost every
  curve on the page. Largest body 3,831 to 450, population 797 to 1,285,
  `ground_spread` 66 to 22. A series spanning the change would draw three
  simultaneous cliffs that read as a catastrophe rather than as a deploy.

  ## The restart guard covers the ordering, and this is still worth doing

  `RecordHistory` drops an island's earlier rows when its tick goes backwards,
  and every island will restart onto the new image with a fresh seed, so each
  cleans up after itself. That fires per island; this fires once for the table.
  Different scopes, and the cheap one is not a reason to drop the rule.
  """
  use Ecto.Migration

  def up, do: execute("DELETE FROM biotope_samples")
  def down, do: execute("DELETE FROM biotope_samples")
end
