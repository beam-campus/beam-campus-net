defmodule BeamCampus.Repo.Migrations.CreateDronexChampions do
  @moduledoc """
  Which controller held which island, and when. The record of gene flow.

  ⚠ ONE ROW PER GENOME PER ISLAND, NOT PER SIGHTING. A champion is republished
  every second; what is worth keeping is the SPAN it held. `first_seen` and
  `last_seen` make tenure a subtraction, and the same `genome_id` against two
  different `island_id`s is a controller that crossed the mesh, which is the
  archipelago's central claim and has never been visible.
  """
  use Ecto.Migration

  def change do
    create table(:dronex_champions) do
      add :genome_id, :string, null: false
      add :island_id, :string, null: false
      add :island, :string

      add :first_seen, :bigint, null: false
      add :last_seen, :bigint, null: false

      add :generation, :integer
      add :sorties, :integer
      # ⚠ THE OTHER END OF THE CROSSING. Null when this island bred it, which is
      # a different fact from not knowing.
      add :taken_from, :string
      add :score, :integer

      timestamps()
    end

    create unique_index(:dronex_champions, [:genome_id, :island_id])
    create index(:dronex_champions, [:last_seen])
  end
end
