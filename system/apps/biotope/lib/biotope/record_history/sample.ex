defmodule Biotope.RecordHistory.Sample do
  @moduledoc """
  One island, at one tick, as it was.

  A row is written from a `world_advanced` fact, which arrives with string keys
  because `untag/1` collapses the wire's atom-or-text ambiguity at the edge. The
  changeset is therefore the boundary where network input becomes a typed row,
  and it is deliberately strict: a fact missing any field is not recorded rather
  than recorded with a zero, because a zero population is a real and alarming
  value that must never be manufactured by a parser.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @fields [
    :island,
    :tick,
    :population,
    :plants,
    :energy_total,
    :born,
    :starved,
    :aged_out,
    :eaten
  ]

  schema "biotope_samples" do
    field :island, :string
    field :tick, :integer
    field :population, :integer
    field :plants, :integer
    field :energy_total, :integer
    field :born, :integer
    field :starved, :integer
    field :aged_out, :integer
    field :eaten, :integer

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
