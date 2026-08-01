defmodule BeamCampus.Repo.Migrations.AddEntropyAndDescentToBiotopeSamples do
  @moduledoc """
  Four columns for the two questions the samples could not answer.

  ## Entropy

  `dissipated` is every unit ever spent on living, as heat. At one temperature it
  IS this world's entropy, so the Second Law is the claim that the line only ever
  rises, and a chart of it is that claim made checkable.

  It is also the third term of the energy books. Ground plus creatures plus burnt
  changes only by what the sun adds. Two of those three were already recorded and
  the third was not, so the First Law could be asserted on the page and never
  checked from it.

  ## Descent

  `depth` is generations in the deepest living line and `lineages` how many
  foundings still have descendants. World 8 ended with creatures carrying four
  hundred times what they were founded with, and it ended because nothing had
  been born since tick 15. Every column already here describes a population; not
  one of them could tell a living population from a frozen one.

  ## Nullable on purpose, and this is the part that has bitten before

  The schema's own moduledoc records the failure twice: a required field the
  islands stopped sending meant every arriving fact failed validation, recording
  stopped dead, and nothing surfaced anywhere except a chart going flat while the
  islands were perfectly healthy.

  A fleet is deployed one node at a time, so during any rollout some islands send
  fact version 4 and some send 5. These four are therefore NULLABLE and optional
  in the changeset: an older island records its row without them rather than
  failing to record at all.
  """
  use Ecto.Migration

  def change do
    alter table(:biotope_samples) do
      add :dissipated, :integer
      add :structure_total, :integer
      add :depth, :integer
      add :lineages, :integer
    end
  end
end
