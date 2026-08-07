defmodule BeamCampus.Repo.Migrations.CreateDronexSamples do
  @moduledoc """
  An island's trajectory outlives a deploy.

  The board samples every island every 30 seconds and keeps 240 of them in ETS,
  which is two hours and nothing more: a restart empties it. Every trend on
  /dronex therefore began again on each of today's deploys, which is why they
  looked like flat lines with two points on them.

  ⚠ THE PER-RUNG VECTOR IS THE REASON THIS MATTERS MORE THAN IT LOOKS. `rungs`
  is the decomposition `REGISTER D.15` needs, and a two-hour window cannot show a
  swing that takes a day. The anomaly is a DAY-scale thing being watched through
  a two-hour hole.
  """
  use Ecto.Migration

  def change do
    create table(:dronex_samples) do
      add :island_id, :string, null: false
      # Milliseconds, as the board keeps them, so a restored sample is
      # indistinguishable from a live one.
      add :at, :bigint, null: false

      add :score, :integer
      add :roster, :integer
      add :generation, :integer
      add :rounds, :integer
      add :captures, :integer

      add :air, :integer
      add :ground, :integer
      add :all, :integer
      add :volume, :integer
      add :entropy, :integer

      # One entry per drill. JSON rather than a column each, because the ladder
      # is six rungs today and the number is the island's to change.
      add :rungs, :map
      add :starts, :integer

      timestamps()
    end

    # One row per island per instant, so a restart that forgets what it wrote
    # cannot duplicate a trajectory.
    create unique_index(:dronex_samples, [:island_id, :at])
    create index(:dronex_samples, [:at])
  end
end
