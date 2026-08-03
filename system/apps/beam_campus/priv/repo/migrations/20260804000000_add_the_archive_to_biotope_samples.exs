defmodule BeamCampus.Repo.Migrations.AddTheArchiveToBiotopeSamples do
  @moduledoc """
  Four columns for the only question this history could not ask.

  ## What they are

    * `explored` — how many of the behaviour space's cells have ever held a
      creature. A **behaviour** is what a creature did, not what it is: what
      share of its intake came from other creatures rather than the ground, what
      share of its life it spent moving, and how far it got from where it was
      born.

    * `behaviour_space` — how many cells there are, so a reader can size the
      first number without being told.

    * `frontier` — how many were first seen in the last thousand ticks.

    * `deepest_elite` — the deepest lineage any way of living ever produced.

  ## ⚠ `frontier` IS THE ONE THAT MATTERS AND `explored` IS THE TRAP

  `explored` can only ever rise. A world that stopped discovering last night
  still reports a large number and looks perfectly healthy on it. The frontier
  is measured over a window, so it falls, and **zero is the operational
  definition of a converged world**.

  Measured over 32 seeds to 8,000 ticks under world 22 it runs 42, 9, 3, 2, 1,
  0, 0, 0: the median world stops finding new ways to make a living by tick
  6,000 while its population carries on at seventy-odd creatures. Nothing in
  this table could previously have said that.

  ## Why a history needs it and a live view does not suffice

  The live board holds the latest fact and nothing else. Convergence is a
  statement about a TRAJECTORY: the frontier at one instant says nothing, and
  the shape of it over hours is the whole finding. That is what a read model is
  for.

  ## Nullable, for the reason this table has learned three times

  They arrived with fact version 16. A fleet is deployed one node at a time, and
  the schema's own moduledoc records what happens when a required field stops
  arriving: every fact fails validation, recording stops dead, and the only
  symptom is a chart going flat while the islands are perfectly healthy.
  """
  use Ecto.Migration

  def change do
    alter table(:biotope_samples) do
      add :explored, :integer
      add :behaviour_space, :integer
      add :frontier, :integer
      add :deepest_elite, :integer
    end
  end
end
