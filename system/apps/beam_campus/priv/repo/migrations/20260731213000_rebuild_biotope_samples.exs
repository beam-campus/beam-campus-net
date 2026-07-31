defmodule BeamCampus.Repo.Migrations.RebuildBiotopeSamples do
  @moduledoc """
  The islands were rebuilt on physics only, so the samples table follows.

  ## Why this drops rather than alters

  Every existing row was written by a world that no longer exists. That world had
  actions called `graze` and `hunt` and organs called `eye` and `nose`; the
  present one has neither, because naming them was writing biology into the
  physics and a world whose rules already say "hunt" cannot discover predation.

  Rows from the two are not comparable, and charting them on one axis would
  splice two different games into a single curve. Keeping them would be worse
  than losing them.

  Losing them is cheap and was always meant to be: this is a read model, not a
  store. The islands are the things that are alive. Deleting this table costs a
  chart, not a world.

  ## What changed in the fact

  `eaten` became `plants_eaten` and a new `consumed` counts deaths by predation,
  which used to have no name because predation used to be a verb rather than a
  consequence. Two observers' numbers arrive that did not exist at all:
  `from_creatures_pct`, the share of eaten energy that came from other creatures,
  and `sensor_mean`, how much a creature carries in the way of measurement.

  THE CHANGESET REQUIRES EVERY FIELD, so the moment the islands shipped the new
  fact the writer stopped recording entirely, quietly, with no error anywhere.
  That is the failure this migration is actually repairing.

  ## econ_id, and why a sample now carries the rules it was taken under

  Two islands sharing a fingerprint are comparable and two that do not are
  playing different games. The site already says so on every card, but its own
  history had no way to express it, so a rules change would have spliced a new
  world onto the end of an old curve exactly as this rebuild would have done.

  Recording it makes that structural. A curve is now drawn from samples that
  share a fingerprint, so changing the rules starts a fresh line rather than
  bending an existing one.
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
      # Which island, how far its world had got, and under which rules. The tick
      # makes a sample attributable to a moment in the world rather than to a
      # moment on this node's clock, and the two drift.
      add :island, :string, null: false
      add :tick, :integer, null: false
      add :econ_id, :string, null: false

      # The state of the world at that tick.
      add :population, :integer, null: false
      add :plants, :integer, null: false
      add :energy_total, :integer, null: false

      # Totals since the island's world began, never reset. A rate is
      # recoverable from two totals and a total is not recoverable from rates,
      # so a gap in sampling costs resolution and not meaning.
      add :born, :integer, null: false
      add :starved, :integer, null: false
      add :aged_out, :integer, null: false
      add :consumed, :integer, null: false
      add :plants_eaten, :integer, null: false

      # An observer's numbers, counted from what happened rather than from any
      # category the world enforces. Nothing in the island's physics reads
      # either of these and no creature is treated differently for what they say.
      add :from_creatures_pct, :integer, null: false
      add :sensor_mean, :integer, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # Every query this table exists to serve is "one island, one rulebook, most
    # recent first".
    create index(:biotope_samples, [:island, :econ_id, :tick])

    # ONE SAMPLE PER ISLAND PER TICK, enforced here rather than trusted. The
    # writer only records a tick it has not seen, so a frozen island stops
    # producing rows instead of filling the disk with the same number; this makes
    # that a property of the table rather than of the writer's memory, which a
    # restart would otherwise reset.
    create unique_index(:biotope_samples, [:island, :tick])
  end
end
