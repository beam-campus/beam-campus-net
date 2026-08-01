defmodule BeamCampus.Repo.Migrations.EmptyBiotopeSamplesForWorldSeven do
  @moduledoc """
  World 7 is a different game, so the history of world 6 goes.

  Follows the standing rule set with world 6: **every new world gets one of
  these.** The island page promises that only samples sharing an island's
  current rules are drawn, and wiping is the cheap way to keep that promise.

  ## Why matching `econ_id` cannot keep it on its own

  World 6 changed the rules and not one constant, so its samples and world 5's
  carried an identical fingerprint. World 7 does change a constant, since
  `transfer_efficiency` is new, so the fingerprint would differ this time and
  the filter would in fact work.

  **It gets a wipe anyway.** A rule that only applies when it happens to be
  needed is a rule nobody can rely on, and the next world may again change no
  constant at all. Cheaper to make it unconditional than to make the reader work
  out whether it applied.

  ## The islands stop being replicates here

  Worlds 2 to 6 ran all three islands on identical rules, differing only by
  seed. World 7 runs them at three different efficiencies, because that constant
  is the one thing in this world that is deliberately **swept rather than
  derived**: the experiment publishes every value and chooses none.

  So the three cards are now three points on an axis rather than three runs of
  one thing, their `econ_id`s genuinely differ, and history from before the
  change cannot be read against any of them.

  ## Deploy the islands first

  This empties the table once, when the site is released. Any node still on the
  old world keeps publishing into the freshly emptied table, so **release the
  islands first and the site second**, or the wipe lands too early.
  """
  use Ecto.Migration

  def up, do: execute("DELETE FROM biotope_samples")
  def down, do: execute("DELETE FROM biotope_samples")
end
