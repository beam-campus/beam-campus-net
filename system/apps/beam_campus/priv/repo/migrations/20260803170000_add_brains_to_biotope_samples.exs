defmodule BeamCampus.Repo.Migrations.AddBrainsToBiotopeSamples do
  @moduledoc """
  Four columns so the history can show what the experiment is about.

  ## The complaint this answers, in the words it was made in

  *"None of the history or the overview shows us anything about what these
  experiments are in essence all about: neuroevolution. Brain diversity — sensors,
  actuators and hidden layers — is in essence what defines a creature and soon a
  species, so that needs to be more prominent."*

  It was correct. Every column in this table describes an ECOLOGY: how many
  creatures, how much energy, what died of what. The islands are running a
  neuroevolution experiment and the recorded history of it could not answer
  whether a single brain had ever appeared.

  ## What each one is

    * `hidden_mean` — hidden nodes per creature, times a hundred. THE ONE NUMBER
      THAT SAYS WHETHER ANYTHING COMPUTES. A creature with no hidden layer is a
      linear valuer of cells: it cannot act on its own state at all, because its
      own energy reads the same for every cell it can reach and cancels in the
      comparison. Proprioception and nonlinearity are worth nothing apart and
      something together.

    * `hidden_width` — live weights per hidden node, times a hundred. A brain
      getting CHEAPER and a brain getting SIMPLER are indistinguishable from the
      node count alone, which is why both are here and not one.

    * `kinds` — how many distinct architectures are alive.

    * `kind_max_pct` — what share the commonest holds. Two islands can carry
      nineteen kinds each and be a monoculture with a fringe, or genuinely
      diverse, and the count alone cannot tell them apart.

  `sensor_mean` was already recorded, so with these the three things that define
  a creature — what it senses, what it computes with, what it can do — are all
  in the history rather than only in the live view, which forgets everything on
  restart.

  ## Why NOT `lineages`, which is already here and reads 1

  It counts ANCESTORS. In a finite asexual population every line coalesces to one
  eventually, so the column can only fall, and it reaching 1 says nothing about
  variety. Measured: a world reading ONE lineage routinely carries between five
  and twenty-seven distinct architectures. For eighteen worlds that 1 was read as
  a monoculture and it never was one.

  ## Nullable, for the reason this table has learned twice

  A fleet is deployed one node at a time. `kinds` and `kind_max_pct` arrived with
  fact version 13 and `hidden_width` with world 19, so during any rollout some
  islands send them and some do not. The schema's own moduledoc records what
  happens when a required field stops arriving: every fact fails validation,
  recording stops dead, and the only symptom is a chart going flat while the
  islands are perfectly healthy. A missing value is NULL and drawn as a gap,
  which is the truth. A zero would be a claim that nothing computes.
  """
  use Ecto.Migration

  def change do
    alter table(:biotope_samples) do
      add :hidden_mean, :integer
      add :hidden_width, :integer
      add :kinds, :integer
      add :kind_max_pct, :integer
    end
  end
end
