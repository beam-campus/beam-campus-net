defmodule BeamCampus.Repo.Migrations.RebuildBiotopeSamplesForWorldTwo do
  @moduledoc """
  World 2 has no plants, so the column counting them has to go.

  ## The failure this is actually preventing

  The changeset requires every field it declares. When the islands were rebuilt
  the first time, `eaten` became `plants_eaten` and this table still demanded the
  old name, so every arriving fact failed validation and recording stopped dead.
  No error surfaced anywhere: the writer simply had nothing valid to write, and
  the chart went flat while the islands were perfectly healthy.

  The same thing is about to happen again for a better reason. A plant was never
  a kind of thing, it is a way of living, so world 2 deleted the entity entirely.
  Energy gathers in the ground and a creature that stays put living off it simply
  IS one. There is no plant count to record because there is nothing to count.

  ## Why it drops rather than alters, again

  Every existing row was written by a world where plants were objects scattered
  by a random number generator. In this one the ground holds a quantity
  everywhere, patchiness is the depletion grazing leaves behind, and a corpse
  enriches the cell it fell on above anything sunlight can reach. Those are not
  the same measurements and charting them on one axis would splice two different
  games into a single curve.

  Losing them is cheap and was always meant to be: this is a read model, not a
  store. The islands are what is alive.

  ## What arrives instead

  `ground_total` in place of the plant count, and two numbers that did not exist:
  `still_pct`, the share of creatures that did not move, which is the closest
  thing to asking how much of this population has become a plant; and
  `ground_spread`, the share of ground energy in the richest tenth of cells,
  which answers whether places have come to differ from one another. Ten is flat.
  Above it, the landscape has structure that nobody installed.
  """
  use Ecto.Migration

  def up do
    drop table(:biotope_samples)
    create_samples()
  end

  def down do
    drop table(:biotope_samples)
    create_samples()
  end

  defp create_samples do
    create table(:biotope_samples) do
      add :island, :string, null: false
      add :tick, :integer, null: false
      add :econ_id, :string, null: false

      # The state of the world at that tick. Energy lives in exactly two places
      # and the pair of them is the whole of the world's books.
      add :population, :integer, null: false
      add :energy_total, :integer, null: false
      add :ground_total, :integer, null: false

      # Totals since the island's world began, never reset. A rate is
      # recoverable from two totals and a total is not recoverable from rates.
      add :born, :integer, null: false
      add :starved, :integer, null: false
      add :aged_out, :integer, null: false
      add :consumed, :integer, null: false
      add :absorbed, :integer, null: false

      # Observers' numbers, counted from what happened rather than from any
      # category the world enforces. Nothing in the island's physics reads any
      # of these and no creature is treated differently for what they say.
      add :from_creatures_pct, :integer, null: false
      add :sensor_mean, :integer, null: false
      add :still_pct, :integer, null: false
      add :ground_spread, :integer, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:biotope_samples, [:island, :econ_id, :tick])
    create unique_index(:biotope_samples, [:island, :tick])
  end
end
