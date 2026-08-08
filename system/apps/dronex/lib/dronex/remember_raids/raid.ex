defmodule Dronex.RememberRaids.Raid do
  @moduledoc """
  One settled raid, as it was, in a row that survives a restart.

  A row is written from a raid RECORDING, which arrives with string keys because
  `untag/1` collapses the wire's atom-or-text ambiguity at the edge. This
  changeset is where network input becomes a typed row.

  ## ⚠ ONLY `raid_id` IS REQUIRED, AND THAT IS DELIBERATE

  The sibling schema in `Biotope.RecordHistory.Sample` is strict, and its own
  moduledoc records that the strictness stopped recording dead twice: a field was
  renamed, every arriving fact failed validation, and the only symptom was a
  chart going flat while the islands were perfectly healthy.

  Raids are rarer than samples by three orders of magnitude, so the same mistake
  here would not flatten a curve, it would lose the entire dataset. A raid we
  cannot fully parse is still a raid that happened, and the id is the only field
  without which the row cannot be deduplicated.

  Everything else is nullable and drawn as a gap. `Dronex.WeighTheExperience`
  already refuses to read a missing stamp as a zero, and every instrument here
  counts what it has rather than assuming what it does not.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @fields [
    :raid_id,
    :attacker_id,
    :island_id,
    :winner,
    :ticks,
    :generation,
    :rounds,
    :raiders,
    :raiders_home,
    :defenders,
    :defenders_home,
    :attacker_rounds,
    :attacker_generation,
    :readings
  ]

  schema "dronex_raids" do
    field :raid_id, :string
    field :attacker_id, :string
    field :island_id, :string
    field :winner, :string
    field :ticks, :integer
    field :generation, :integer
    field :rounds, :integer
    field :raiders, :integer
    field :raiders_home, :integer
    field :defenders, :integer
    field :defenders_home, :integer
    # ⚠ THE RAIDER'S HALF, WHICH LIVES ONLY IN ITS COMMITMENT. The recording is
    # the defender's and carries the defender's stamp; without these two the
    # experience plot loses every restored raid.
    field :attacker_rounds, :integer
    field :attacker_generation, :integer
    field :readings, :map

    timestamps()
  end

  @doc """
  A row from a raid recording, its readings, and the attacker's own commitment.

  The commitment may be absent: the board evicts, and a raid seen only as a
  recording never had one here. Then the raider's stamp is NULL and the
  experience plot excludes that raid, which is the truth about it.
  """
  @spec from_fact(binary(), map(), map(), map() | nil) :: Ecto.Changeset.t()
  def from_fact(raid_id, fact, readings, commitment \\ nil) do
    %__MODULE__{}
    |> cast(attributes(raid_id, fact, readings, commitment), @fields)
    |> validate_required([:raid_id])
    |> unique_constraint(:raid_id)
  end

  defp attributes(raid_id, fact, readings, commitment) do
    stamp = commitment || %{}

    %{
      raid_id: raid_id,
      attacker_id: fact["attacker_id"],
      island_id: fact["island_id"],
      winner: fact["winner"],
      ticks: fact["ticks"],
      generation: fact["generation"],
      rounds: fact["rounds"],
      raiders: fact["raiders"],
      raiders_home: fact["raiders_home"],
      defenders: fact["defenders"],
      defenders_home: fact["defenders_home"],
      attacker_rounds: stamp["rounds"],
      attacker_generation: stamp["generation"],
      readings: readings
    }
  end

  @doc """
  A stored row turned back into the shape the instruments already read.

  ⚠ THE SAME SHAPE, ON PURPOSE. `ReadTheLedger`, `TimeTheFights` and
  `WeighTheExperience` all take `%{id: _, parts: %{raid: [fact]}}`, and none of
  them should learn that a database exists. Rehydrating into the board rather
  than teaching every instrument a second source is what keeps them pure.
  """
  @spec to_fact(t()) :: {binary(), map(), map(), [map()]}
  def to_fact(%__MODULE__{} = row) do
    fact =
      %{
        "raid_id" => row.raid_id,
        "attacker_id" => row.attacker_id,
        "island_id" => row.island_id,
        "winner" => row.winner,
        "ticks" => row.ticks,
        "generation" => row.generation,
        "rounds" => row.rounds,
        "raiders" => row.raiders,
        "raiders_home" => row.raiders_home,
        "defenders" => row.defenders,
        "defenders_home" => row.defenders_home
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {row.raid_id, fact, atomised(row.readings), commitments(row)}
  end

  # ⚠ REBUILT AS A COMMITMENT, NOT BOLTED ONTO THE RECORDING. `WeighTheExperience`
  # reads the raider's rounds from `parts.committed` and is pure and tested; it
  # should not learn that a database exists in order to keep working.
  defp commitments(%__MODULE__{attacker_rounds: nil}), do: []

  defp commitments(%__MODULE__{} = row) do
    [
      %{
        "role" => "attacker",
        "island_id" => row.attacker_id,
        "opponent_id" => row.island_id,
        "rounds" => row.attacker_rounds,
        "generation" => row.attacker_generation
      }
    ]
  end

  # Readings go to jsonb as atom keys and come back as strings, and every reader
  # of them matches on atoms. Converted here, at the boundary, rather than making
  # each instrument handle both shapes.
  defp atomised(nil), do: %{}

  defp atomised(readings) when is_map(readings) do
    Map.new(readings, fn {k, v} -> {key(k), deep(v)} end)
  end

  defp deep(v) when is_map(v), do: atomised(v)
  defp deep(v) when is_list(v), do: Enum.map(v, &deep/1)
  defp deep(v), do: v

  # ⚠ `to_existing_atom`, NEVER `to_atom`. These keys come off a disk that took
  # them off a network, and a reader that mints atoms from foreign input can be
  # made to exhaust the atom table by whoever is publishing.
  defp key(k) when is_binary(k) do
    String.to_existing_atom(k)
  rescue
    ArgumentError -> k
  end

  defp key(k), do: k

  @type t :: %__MODULE__{}
end
