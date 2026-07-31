defmodule BeamCampus.Repo.Migrations.CreateBiotopeSamples do
  @moduledoc """
  The first table this site has ever had.

  `BeamCampus.Repo` has been configured, supervised and completely empty since it
  was added: `ecto_sqlite3`, a `BEAM_CAMPUS_DB_PATH`, a repo in the supervision
  tree, and no migrations directory at all. This is what it was waiting for.

  ## A read model, not a store

  The site's rule is that it holds no store, and that rule survives intact. An
  event store is a source of truth you can replay; this is a projection of facts
  that happened to arrive, rebuilt from nothing if it is lost. The islands are
  the things that are actually alive. Deleting this table costs a chart, not a
  world.

  ## Why a table at all, when there is already an ETS board

  Frames are ephemeral and statistics are durable. The board holds the latest of
  each fact so a page can draw right now; it is wiped by every deploy and cannot
  answer "what happened overnight". A population curve is exactly the question
  the ETS board is structurally unable to answer.
  """
  use Ecto.Migration

  def change do
    create table(:biotope_samples) do
      # Which island, and how far its world had got. The tick is what makes a
      # sample attributable to a moment in the world rather than to a moment on
      # this node's clock, and the two drift: publishing runs on wall clock and
      # the world runs at whatever pace it was configured for.
      add :island, :string, null: false
      add :tick, :integer, null: false

      # The state of the world at that tick.
      add :population, :integer, null: false
      add :plants, :integer, null: false
      add :energy_total, :integer, null: false

      # Totals since the island's world began, never reset. Totals rather than
      # rates because a rate is recoverable from two totals and a total is not
      # recoverable from rates, so a gap in sampling costs resolution and not
      # meaning.
      add :born, :integer, null: false
      add :starved, :integer, null: false
      add :aged_out, :integer, null: false
      add :eaten, :integer, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # Every query this table exists to serve is "one island, most recent first".
    create index(:biotope_samples, [:island, :inserted_at])

    # ONE SAMPLE PER ISLAND PER TICK, enforced here rather than trusted. The
    # writer only records a tick it has not seen, so a frozen island stops
    # producing rows instead of filling the disk with the same number; this makes
    # that a property of the table rather than of the writer's memory, which a
    # restart would otherwise reset.
    create unique_index(:biotope_samples, [:island, :tick])
  end
end
