defmodule Dronex.RememberVitals.Sample do
  @moduledoc """
  One island, at one instant, as the board saw it.

  ⚠ ONLY `island_id` AND `at` ARE REQUIRED. The sibling schema in
  `Biotope.RecordHistory.Sample` is strict, and its own moduledoc records that
  strictness stopping recording dead TWICE on a renamed field, with no error
  anywhere and a chart quietly going flat. Everything else here is nullable and
  drawn as a gap.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @fields [
    :island_id,
    :at,
    :score,
    :roster,
    :generation,
    :rounds,
    :captures,
    :air,
    :ground,
    :all,
    :volume,
    :entropy,
    :rungs,
    :starts
  ]

  schema "dronex_samples" do
    field :island_id, :string
    field :at, :integer
    field :score, :integer
    field :roster, :integer
    field :generation, :integer
    field :rounds, :integer
    field :captures, :integer
    field :air, :integer
    field :ground, :integer
    field :all, :integer
    field :volume, :integer
    field :entropy, :integer
    # ⚠ A MAP, BECAUSE SQLITE HAS NO ARRAY COLUMN. The list is wrapped on the way
    # in and unwrapped on the way out, in this module, so nothing else has to
    # know that a vector is stored as `%{"wins" => [...]}`.
    field :rungs, :map
    field :starts, :integer

    timestamps()
  end

  @doc "A row from one board sample."
  @spec from_point(binary(), map()) :: Ecto.Changeset.t()
  def from_point(island_id, point) do
    %__MODULE__{}
    |> cast(attributes(island_id, point), @fields)
    |> validate_required([:island_id, :at])
    |> unique_constraint([:island_id, :at])
  end

  defp attributes(island_id, p) do
    p
    |> Map.take([
      :score,
      :roster,
      :generation,
      :rounds,
      :captures,
      :air,
      :ground,
      :all,
      :volume,
      :entropy,
      :starts
    ])
    |> Map.merge(%{
      island_id: island_id,
      at: Map.get(p, :at),
      rungs: %{"wins" => Map.get(p, :rungs, [])}
    })
  end

  @doc "A stored row as the point shape the board and every instrument already read."
  @spec to_point(t()) :: map()
  def to_point(%__MODULE__{} = r) do
    %{
      at: r.at,
      score: r.score || 0,
      roster: r.roster || 0,
      generation: r.generation || 0,
      rounds: r.rounds || 0,
      captures: r.captures || 0,
      air: r.air || 0,
      ground: r.ground || 0,
      all: r.all || 0,
      volume: r.volume || 0,
      entropy: r.entropy || 0,
      rungs: wins(r.rungs),
      starts: r.starts || 0
    }
  end

  # ⚠ INTEGERS ONLY. This came off a network before it went to a disk, and a
  # rung that is not a count is no measurement rather than a measurement of zero.
  defp wins(%{"wins" => wins}) when is_list(wins),
    do: Enum.filter(wins, &(is_integer(&1) and &1 >= 0))

  defp wins(_absent), do: []

  @type t :: %__MODULE__{}
end
