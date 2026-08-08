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

  # Every counter the board keeps, which is every field that is a plain number.
  @counters [
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
  ]

  @doc """
  A stored row as the point shape the board and every instrument already read.

  ⚠ ONE RULE, NOT ELEVEN COPIES OF IT. This was written as a literal map with
  `|| 0` after every field, which credo counted at a cyclomatic complexity of 12
  and which is eleven chances to forget one. A NULL column is a field the island
  did not publish, and the board's readers all expect a number.
  """
  @spec to_point(t()) :: map()
  def to_point(%__MODULE__{} = r) do
    @counters
    |> Map.new(&{&1, Map.get(r, &1) || 0})
    |> Map.merge(%{at: r.at, rungs: wins(r.rungs)})
  end

  # ⚠ INTEGERS ONLY. This came off a network before it went to a disk, and a
  # rung that is not a count is no measurement rather than a measurement of zero.
  defp wins(%{"wins" => wins}) when is_list(wins),
    do: Enum.filter(wins, &(is_integer(&1) and &1 >= 0))

  defp wins(_absent), do: []

  @type t :: %__MODULE__{}
end
