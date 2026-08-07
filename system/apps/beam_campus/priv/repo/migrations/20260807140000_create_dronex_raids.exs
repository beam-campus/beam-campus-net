defmodule BeamCampus.Repo.Migrations.CreateDronexRaids do
  @moduledoc """
  A raid outlives a deploy.

  Everything /dronex draws about raids lived in ETS and nowhere else, so every
  restart of the site emptied the board and every chart started again from
  whatever arrived next. Raids are RARE, a handful an hour across the fleet, so
  the loss is not a gap in a curve: it is the whole sample. The duration
  histogram, the ledger matrix, the experience plot and the loss ledger all read
  the same 64 rows, and all four reset together.

  ⚠ THE FRAMES ARE DELIBERATELY NOT HERE. A recording is around 150 KB of
  positions and only the replay player wants it. What every other instrument
  needs is the scalars plus the two readings taken at ingest, which together are
  a few hundred bytes. Persisting frames would put the site's whole memory
  problem on a disk instead of fixing it.
  """
  use Ecto.Migration

  def change do
    create table(:dronex_raids) do
      add :raid_id, :string, null: false
      add :attacker_id, :string
      add :island_id, :string
      add :winner, :string
      add :ticks, :integer

      # Where each side was in its own breeding. Nullable, because the stamp
      # shipped after these islands had been fighting for days and a fleet
      # mid-roll has both versions on the wire at once.
      add :generation, :integer
      add :rounds, :integer

      add :raiders, :integer
      add :raiders_home, :integer
      add :defenders, :integer
      add :defenders_home, :integer

      # ⚠ JSONB RATHER THAN A COLUMN PER NUMBER. These are computed once at
      # ingest from frames that are then thrown away, and which readings exist
      # changes as instruments are added: damage today, coverage today, whatever
      # the ablation needs next. A column per reading would make every new
      # instrument a migration, and a migration on a read model that is
      # rebuildable from the mesh buys nothing.
      add :readings, :map

      timestamps()
    end

    # One row per raid however many times it is seen. Both sides publish a
    # commitment and the defender publishes the recording, so the same raid
    # arrives repeatedly, and a restart that forgets what it has written must not
    # be able to duplicate history.
    create unique_index(:dronex_raids, [:raid_id])

    # The instruments read newest-first and prune oldest-first.
    create index(:dronex_raids, [:inserted_at])
  end
end
