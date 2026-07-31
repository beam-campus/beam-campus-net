defmodule Biotope.RecordHistoryTest do
  @moduledoc """
  The durable half. Frames are ephemeral, statistics are durable, and these are
  the statistics.
  """
  use ExUnit.Case, async: false

  alias BeamCampus.Repo
  alias Biotope.RecordHistory
  alias Biotope.RecordHistory.Sample

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  defp fact(island, tick, overrides \\ %{}) do
    Map.merge(
      %{
        "island" => island,
        "tick" => tick,
        "population" => 78,
        "plants" => 100,
        "energy_total" => 5882,
        "born" => 249,
        "starved" => 171,
        "aged_out" => 0,
        "eaten" => 900
      },
      overrides
    )
  end

  describe "changeset" do
    test "builds a row from a string-keyed fact off the wire" do
      assert {:ok, row} = Repo.insert(Sample.changeset(fact("beam01", 412)))
      assert row.island == "beam01"
      assert row.tick == 412
      assert row.population == 78
    end

    # A fact missing a field must not become a row with a zero in it. A zero
    # population is a real and alarming value and must never be manufactured by
    # a parser: a chart that dips to nothing has to mean the island died.
    test "refuses a fact with a missing field rather than defaulting it" do
      incomplete = Map.delete(fact("beam01", 1), "population")
      changeset = Sample.changeset(incomplete)

      refute changeset.valid?
      assert {:population, _} = List.keyfind(changeset.errors, :population, 0)
    end

    test "ignores fields it does not declare, so a later fact_version still writes" do
      grown = Map.put(fact("beam01", 5), "some_future_field", 1)
      assert {:ok, _row} = Repo.insert(Sample.changeset(grown))
    end

    # ONE SAMPLE PER ISLAND PER TICK, enforced by the table and not only by the
    # writer's memory, which a restart resets.
    test "the same island and tick cannot be recorded twice" do
      assert {:ok, _} = Repo.insert(Sample.changeset(fact("beam01", 7)))
      assert {:error, changeset} = Repo.insert(Sample.changeset(fact("beam01", 7)))
      refute changeset.valid?
    end

    test "the same tick on a different island is fine" do
      assert {:ok, _} = Repo.insert(Sample.changeset(fact("beam01", 7)))
      assert {:ok, _} = Repo.insert(Sample.changeset(fact("beam02", 7)))
    end
  end

  describe "reading it back" do
    test "history comes back oldest first, ordered by the world's own clock" do
      for tick <- [30, 10, 20], do: Repo.insert!(Sample.changeset(fact("beam01", tick)))

      assert Enum.map(RecordHistory.history("beam01"), & &1.tick) == [10, 20, 30]
    end

    test "history is limited to the most recent, and still oldest first" do
      for tick <- 1..10, do: Repo.insert!(Sample.changeset(fact("beam01", tick)))

      assert Enum.map(RecordHistory.history("beam01", 3), & &1.tick) == [8, 9, 10]
    end

    test "islands with history are listed, distinctly" do
      Repo.insert!(Sample.changeset(fact("beam01", 1)))
      Repo.insert!(Sample.changeset(fact("beam01", 2)))
      Repo.insert!(Sample.changeset(fact("beam02", 1)))

      assert RecordHistory.recorded_islands() == ["beam01", "beam02"]
    end

    test "an island with no history reads as an empty list" do
      assert RecordHistory.history("nowhere") == []
      assert RecordHistory.recorded_islands() == []
      assert RecordHistory.count() == 0
    end
  end
end
