defmodule BeamCampus.Repo.Migrations.EmptyBiotopeSamplesForWorldNine do
  @moduledoc """
  World 9 is a different game, so the history of world 8 goes.

  The standing rule since world 6: **every new world gets one of these.** The
  island page promises that only samples sharing an island's current rules are
  drawn, and wiping is the cheap way to keep that promise.

  ## World 9 changes no constant at all, which is exactly why this is unconditional

  The change is that a parent no longer gives half its frame to a child, only
  half its store. Not one number in the economy moves, so world 8's samples and
  world 9's carry an **identical `econ_id`** and the fingerprint filter cannot
  separate them. This is the case the rule exists for.

  It also matters more here than usual. World 8's populations froze at four to
  sixteen creatures and world 9's run to hundreds, so a curve that spanned the
  change would show a step nobody could read as anything but a crash or a bloom.

  ## Deploy the islands first

  This empties the table once, when the site is released. Any node still on the
  old world keeps publishing into the freshly emptied table, so **release the
  islands first and the site second**, or the wipe lands too early.
  """
  use Ecto.Migration

  def up, do: execute("DELETE FROM biotope_samples")
  def down, do: execute("DELETE FROM biotope_samples")
end
