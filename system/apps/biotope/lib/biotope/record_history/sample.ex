defmodule Biotope.RecordHistory.Sample do
  @moduledoc """
  One island, at one tick, as it was.

  A row is written from a `world_advanced` fact, which arrives with string keys
  because `untag/1` collapses the wire's atom-or-text ambiguity at the edge. The
  changeset is therefore the boundary where network input becomes a typed row,
  and it is deliberately strict: a fact missing any field is not recorded rather
  than recorded with a zero, because a zero population is a real and alarming
  value that must never be manufactured by a parser.

  THAT STRICTNESS HAS A BITE AND IT HAS ALREADY BITTEN. When the islands were
  rebuilt, `eaten` became `plants_eaten` and this schema still required the old
  name, so every arriving fact failed validation and recording stopped dead. No
  error surfaced anywhere: the writer simply had nothing valid to write, and the
  chart went flat while the islands were perfectly healthy. A renamed field is a
  breaking change to this file even though nothing here mentions the wire.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @fields [
    :island,
    :tick,
    :econ_id,
    :population,
    :plants,
    :energy_total,
    :born,
    :starved,
    :aged_out,
    :consumed,
    :plants_eaten,
    :from_creatures_pct,
    :sensor_mean
  ]

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
    field :plants, :integer
    field :energy_total, :integer
    field :born, :integer
    field :starved, :integer
    field :aged_out, :integer
    field :consumed, :integer
    field :plants_eaten, :integer
    # Observers' numbers, counted from what happened. Nothing in the island's
    # physics reads either and no creature is treated differently for them.
    field :from_creatures_pct, :integer
    field :sensor_mean, :integer

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
    |> validate_required(@fields)
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
