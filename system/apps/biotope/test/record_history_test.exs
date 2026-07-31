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
        "econ_id" => "17b90de41d26da0e",
        "population" => 78,
        "plants" => 100,
        "energy_total" => 5882,
        "born" => 249,
        "starved" => 171,
        "aged_out" => 0,
        "consumed" => 900,
        "plants_eaten" => 1200,
        "from_creatures_pct" => 39,
        "sensor_mean" => 104
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

  describe "telling a page" do
    setup do
      # The subscriber owns this table and creates it at application start, so it
      # already exists here. Creating it again raises.
      :ets.whereis(:biotope_board) == :undefined and Biotope.WatchIslands.Board.init()
      :ets.delete_all_objects(:biotope_board)
      :ok
    end

    # THE WRITER KNOWS WHEN A ROW APPEARS; the page should not have to guess. The
    # first version had the page poll on its own thirty-second timer against a
    # writer sampling on a thirty-second timer, unsynchronised, so a new point
    # could sit unshown for another thirty seconds.
    #
    # Driven through the real writer rather than by broadcasting by hand, because
    # what is being asserted is WHEN it speaks, and a hand-rolled broadcast would
    # test only that PubSub works.
    test "announces when it records, and stays quiet when it does not" do
      RecordHistory.subscribe()
      Biotope.WatchIslands.Board.put_stats(fact("beam09", 100))

      send(RecordHistory, :sample)
      assert_receive {:biotope_history, :written}, 1_000

      # A FROZEN ISLAND MUST NOT REDRAW ANYTHING. Its last fact stays on the
      # board forever, so every later wake sees the same tick and writes nothing.
      send(RecordHistory, :sample)
      refute_receive {:biotope_history, :written}, 200

      # And it moves again as soon as the world does.
      Biotope.WatchIslands.Board.put_stats(fact("beam09", 160))
      send(RecordHistory, :sample)
      assert_receive {:biotope_history, :written}, 1_000

      assert Enum.map(RecordHistory.history("beam09"), & &1.tick) == [100, 160]
    end
  end

  describe "history/2 and the rules a sample was taken under" do
    # TWO ISLANDS SHARING A FINGERPRINT ARE COMPARABLE AND TWO THAT DO NOT ARE
    # PLAYING DIFFERENT GAMES, and the same is true of one island before and
    # after its economy changes. Without this filter a deploy that alters the
    # rules bends the existing curve instead of starting a new one, and the
    # discontinuity reads as something the world did.
    test "draws only samples that share the island's current rules" do
      Repo.insert!(Sample.changeset(fact("beam01", 10, %{"econ_id" => "old00000000000a"})))
      Repo.insert!(Sample.changeset(fact("beam01", 11, %{"econ_id" => "old00000000000a"})))
      Repo.insert!(Sample.changeset(fact("beam01", 12, %{"econ_id" => "new00000000000b"})))

      ticks = Enum.map(RecordHistory.history("beam01"), & &1.tick)

      assert ticks == [12]
    end

    # A short line is an honest answer to "what has happened under these rules".
    # A long one spliced from two rulebooks is not an answer at all.
    test "a rules change shortens the chart rather than corrupting it" do
      for tick <- 1..5 do
        Repo.insert!(Sample.changeset(fact("beam01", tick, %{"econ_id" => "aaaaaaaaaaaaaaaa"})))
      end

      assert length(RecordHistory.history("beam01")) == 5

      Repo.insert!(Sample.changeset(fact("beam01", 6, %{"econ_id" => "bbbbbbbbbbbbbbbb"})))

      assert length(RecordHistory.history("beam01")) == 1
    end

    test "an island with no history at all draws nothing" do
      assert RecordHistory.history("nowhere") == []
    end
  end
end
