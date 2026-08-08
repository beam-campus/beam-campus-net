defmodule Dronex.FollowTheChampions.Reign do
  @moduledoc """
  One controller's hold on one island, from when it was first seen to last.

  ⚠ A SPAN, NOT A SIGHTING. The champion is republished every second, so a row
  per sighting would be a million rows saying the same thing. What is worth
  keeping is when a genome took an island and when it stopped holding it, and
  tenure is then a subtraction.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @fields [
    :genome_id,
    :island_id,
    :island,
    :first_seen,
    :last_seen,
    :generation,
    :sorties,
    :taken_from,
    :score
  ]

  schema "dronex_champions" do
    field :genome_id, :string
    field :island_id, :string
    field :island, :string
    field :first_seen, :integer
    field :last_seen, :integer
    field :generation, :integer
    field :sorties, :integer
    field :taken_from, :string
    field :score, :integer

    timestamps()
  end

  @doc "A reign from an island's vitals, or nil when it names no champion."
  @spec from_vitals(map(), integer()) :: Ecto.Changeset.t() | nil
  def from_vitals(vitals, at) do
    build(Map.get(vitals, "champion_id"), vitals, at)
  end

  # ⚠ AN ISLAND ON THE OLDER FACT VERSION NAMES NOBODY. Islands roll one at a
  # time, so during a deploy some publish a champion and some do not, and a
  # fabricated id would be worse than an absent one.
  defp build(id, _vitals, _at) when not is_binary(id), do: nil
  defp build("", _vitals, _at), do: nil

  defp build(id, vitals, at) do
    %__MODULE__{}
    |> cast(
      %{
        genome_id: id,
        island_id: Map.get(vitals, "island_id"),
        island: Map.get(vitals, "island"),
        first_seen: at,
        last_seen: at,
        generation: Map.get(vitals, "champion_generation"),
        sorties: Map.get(vitals, "champion_sorties"),
        taken_from: Map.get(vitals, "champion_from"),
        score: Dronex.WatchBouts.Board.exam_score(vitals)
      },
      @fields
    )
    |> validate_required([:genome_id, :island_id, :first_seen, :last_seen])
    |> unique_constraint([:genome_id, :island_id])
  end

  @type t :: %__MODULE__{}
end
