defmodule Biotope.RecordHistory.Sample do
  @moduledoc """
  One island, at one tick, as it was.

  A row is written from a `world_advanced` fact, which arrives with string keys
  because `untag/1` collapses the wire's atom-or-text ambiguity at the edge. The
  changeset is therefore the boundary where network input becomes a typed row,
  and it is deliberately strict: a fact missing any field is not recorded rather
  than recorded with a zero, because a zero population is a real and alarming
  value that must never be manufactured by a parser.

  THAT STRICTNESS HAS A BITE AND IT HAS ALREADY BITTEN TWICE. When the islands
  were first rebuilt, `eaten` became `plants_eaten` and this schema still
  required the old name, so every arriving fact failed validation and recording
  stopped dead. No error surfaced anywhere: the writer simply had nothing valid
  to write, and the chart went flat while the islands were perfectly healthy.

  World 2 then deleted plants outright, because a plant was never a kind of
  thing. A renamed or removed field is a breaking change to this file even though
  nothing here mentions the wire, and the only warning is a chart that stops.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required [
    :island,
    :tick,
    :econ_id,
    :population,
    :energy_total,
    :ground_total,
    :born,
    :starved,
    :aged_out,
    :consumed,
    :absorbed,
    :from_creatures_pct,
    :sensor_mean,
    :still_pct,
    :ground_spread
  ]

  # ARRIVED WITH FACT VERSION 5, SO THEY ARE OPTIONAL AND MUST STAY OPTIONAL.
  #
  # A fleet is deployed one node at a time, so during any rollout some islands
  # send version 4 and some send 5. Requiring these would do exactly what the
  # moduledoc above describes happening twice already: every fact from an island
  # not yet upgraded fails validation, recording stops dead, and the only symptom
  # is a chart going flat while the islands are perfectly healthy.
  #
  # A missing value is recorded as NULL and drawn as a gap, which is the truth. A
  # zero is not: it would put an island's entropy at nothing, and entropy at
  # nothing is a claim about physics rather than about a rollout.
  @optional [
    :dissipated,
    :structure_total,
    :depth,
    :lineages,
    # WHAT THE EXPERIMENT IS ABOUT, and optional for exactly the reason above:
    # `kinds` and `kind_max_pct` arrived with fact version 13 and `hidden_width`
    # with world 19, so a fleet mid-rollout sends facts with and without them.
    :hidden_mean,
    :hidden_width,
    :kinds,
    :kind_max_pct,
    # Fact version 16. `frontier` is the only column in this table that can
    # answer "is this world still finding new ways to live", and it is the only
    # one that can fall back to zero while everything else looks healthy.
    :explored,
    :behaviour_space,
    :frontier,
    :deepest_elite
  ]

  @fields @required ++ @optional

  schema "biotope_samples" do
    field :island, :string
    field :tick, :integer
    # WHICH RULES THIS SAMPLE WAS TAKEN UNDER. Two islands sharing a fingerprint
    # are comparable and two that do not are different games, so a curve is drawn
    # from samples that share one. Without it a rules change bends an existing
    # line instead of starting a new one, which is how a deploy becomes a
    # finding about ecology.
    field :econ_id, :string
    field :population, :integer
    field :energy_total, :integer
    # The other half of the books. Energy is in a creature or in the ground, and
    # the pair only changes by what arrives from the sun and what living costs.
    field :ground_total, :integer
    field :born, :integer
    field :starved, :integer
    field :aged_out, :integer
    field :consumed, :integer
    field :absorbed, :integer
    # Observers' numbers, counted from what happened. Nothing in the island's
    # physics reads either and no creature is treated differently for them.
    field :from_creatures_pct, :integer
    field :sensor_mean, :integer
    # THE PLANT-NESS OF THE POPULATION and whether places have come to differ.
    # Neither is a category the world enforces: there are no plants in world 2,
    # and no terrain was ever installed, so whatever structure the ground has was
    # made by things dying on it.
    field :still_pct, :integer
    field :ground_spread, :integer
    # THE ONE QUANTITY THAT CANNOT FALL. Every unit ever spent on living, as
    # heat, which at one temperature IS this world's entropy. It is also the
    # third term of the books: ground plus creatures plus this changes only by
    # what the sun adds, and the first two were recorded without it.
    field :dissipated, :integer
    # What the population is BUILT of, as against what it is carrying. A contest
    # is decided on structure alone.
    field :structure_total, :integer
    # WHETHER THE POPULATION CAN STILL CHANGE, which nothing above can answer.
    # `depth` is generations in the deepest living line, so zero means every
    # creature alive is a founder and the world has selected nothing.
    field :depth, :integer
    field :lineages, :integer
    # ══════════════════════════════════════════════════════════════════
    # WHAT A CREATURE IS, WHICH IS THE SUBJECT OF THE WHOLE EXERCISE
    # ══════════════════════════════════════════════════════════════════
    #
    # `sensor_mean` above is what a creature MEASURES. These are what it
    # COMPUTES WITH and how many distinct designs are alive. Every other column
    # in this table describes an ecology, and the islands are running a
    # neuroevolution experiment: until these, the recorded history could not say
    # whether a single brain had ever appeared.
    #
    # A creature with no hidden layer is a linear valuer of cells and cannot act
    # on its own state at all, since its own energy reads the same for every cell
    # it can reach and cancels in the comparison. So `hidden_mean` crossing zero
    # is the difference between reflex and deliberation.
    #
    # `hidden_width` is live weights per node, because A BRAIN GETTING CHEAPER
    # AND A BRAIN GETTING SIMPLER LOOK IDENTICAL from the node count alone.
    #
    # `kinds` is distinct architectures alive, as against `lineages` above, which
    # counts ANCESTORS and can only fall: a world reading ONE lineage routinely
    # carries between five and twenty-seven distinct architectures.
    field :hidden_mean, :integer
    field :hidden_width, :integer
    field :kinds, :integer
    field :kind_max_pct, :integer
    # ══════════════════════════════════════════════════════════════════
    # WHAT THEY DO, AS AGAINST WHAT THEY ARE
    # ══════════════════════════════════════════════════════════════════
    #
    # `kinds` above counts ARCHITECTURES. These count BEHAVIOURS: a creature's
    # place in a space of ways-of-living, from what share of its food it took
    # from other creatures, how much of its life it spent moving, and how far it
    # travelled from where it was born.
    #
    # The two disagree, which is the point of having both. Measured on one world
    # over six thousand ticks, architectures fell from 38 to 10 while ways of
    # living rose from 0 to 91 of 125: a census of the genotype alone was
    # reading expansion as convergence.
    #
    # ⚠ `explored` ONLY RISES AND `frontier` DOES NOT. A world that stopped
    # discovering still reports a large `explored`. The frontier counts what was
    # found in the last thousand ticks, and zero is convergence.
    field :explored, :integer
    field :behaviour_space, :integer
    field :frontier, :integer
    field :deepest_elite, :integer

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Build a row from a delivered fact.

  Takes the string-keyed map the subscriber files, so the caller does not have to
  know that the wire speaks strings.
  """
  def changeset(fact) when is_map(fact) do
    %__MODULE__{}
    |> cast(atomise(fact), @fields)
    |> validate_required(@required)
    |> validate_number(:population, greater_than_or_equal_to: 0)
    |> validate_number(:tick, greater_than_or_equal_to: 0)
    |> unique_constraint([:island, :tick])
  end

  # Only the keys this schema declares, so a fact that grows a field at a later
  # fact_version does not need this to change, and nothing off the wire ever
  # becomes a new atom.
  defp atomise(fact) do
    Map.new(@fields, fn field -> {field, Map.get(fact, Atom.to_string(field))} end)
  end
end
