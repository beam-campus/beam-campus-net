defmodule BeamCampus.Repo.Migrations.EmptyBiotopeSamplesForWorldSix do
  @moduledoc """
  World 6 is a different game, so the history of world 5 goes.

  ## The standing rule this establishes

  **Whenever a new world rolls out, the site's history is wiped.** Add one of
  these per world. Raf's call, and it is the cheap way to keep one promise the
  island page makes in its own words:

  > Only samples sharing this island's current rules are drawn. Change the
  > economy and the line starts again rather than bending, because an island
  > before and after a rules change is two different games.

  ## Why matching `econ_id` is no longer enough to keep it

  That promise is kept by comparing `econ_id`, a fingerprint of the CONSTANTS:
  metabolism, ground_seed, radius and the rest. It worked until now because
  every previous world moved at least one of them.

  World 6 changed the rules in the code and **not one constant**. A world 5
  sample and a world 6 sample therefore carry a byte-identical `econ_id`, so
  the page would draw them as one unbroken line and state that they share the
  same rules. They do not. A trend line spliced across two different physics is
  worse than no trend line, because it looks like a result.

  ## Why it empties rather than dropping and recreating

  The schema is unchanged: world 6 splits a creature's store from its structure
  and adds no column here. Every earlier migration in this directory dropped the
  table because the SHAPE of a sample changed. Nothing about the shape changed
  this time, only which world produced the rows, so the rows are what goes.

  Losing them is cheap and was always meant to be: this is a read model, not a
  store. The islands are what is alive.

  ## Deploy the islands first

  This empties the table once, when the site is released. Islands are redeployed
  one node at a time, and any node still on the old world keeps publishing into
  the freshly emptied table. **Release the islands first and the site second**,
  or the wipe lands too early and the splice this exists to prevent happens
  anyway, in a smaller and harder-to-see way.
  """
  use Ecto.Migration

  # Rolling BACK is a world change too: it means the fleet is going back to
  # world 5, and world 6's rows must not survive into it either.
  def up, do: execute("DELETE FROM biotope_samples")
  def down, do: execute("DELETE FROM biotope_samples")
end
