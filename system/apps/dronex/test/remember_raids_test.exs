defmodule Dronex.RememberRaidsTest do
  @moduledoc """
  A raid outlives a restart, and the numbers taken from its frames outlive the
  frames.
  """
  use ExUnit.Case, async: false

  alias BeamCampus.Repo
  alias Dronex.RememberRaids
  alias Dronex.RememberRaids.Raid
  alias Dronex.WatchBouts.Board

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  defp fact(id) do
    %{
      "raid_id" => id,
      "attacker_id" => "aaa",
      "island_id" => "bbb",
      "winner" => "attacker",
      "ticks" => 640,
      "rounds" => 9000,
      "generation" => 12,
      "raiders" => 6,
      "raiders_home" => 4
    }
  end

  defp readings do
    %{losses: %{quantised: 75, unquantised: 12}, coverage: %{frames: 40, held: 9}}
  end

  defp store(id) do
    {1, _} =
      Repo.insert_all(
        Raid,
        [
          Raid.from_fact(id, fact(id), readings())
          |> Map.fetch!(:changes)
          |> Map.put(:inserted_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
          |> Map.put(:updated_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
        ]
      )
  end

  # ⚠ THE WHOLE POINT. The site redeploys whenever anything is pushed, and raids
  # are rare enough that an empty board is not a gap in the data, it is all of it.
  test "a stored raid is on the board again after a restart" do
    store("r1")

    assert RememberRaids.recall() == 1

    assert [%{id: "r1", parts: %{raid: [got]}}] = Dronex.raids()
    assert got["winner"] == "attacker"
    assert got["ticks"] == 640
  end

  # ⚠⚠ THE READINGS SURVIVE THOUGH THE FRAMES DO NOT. Damage and coverage are
  # walked out of the frames once at ingest and the frames are 150 KB each, so
  # they are not persisted. A remembered raid has its numbers and no film.
  test "the readings come back with it" do
    store("r1")

    assert RememberRaids.recall() == 1

    assert %{losses: %{quantised: 75}, coverage: %{frames: 40}} =
             Dronex.raids() |> hd() |> Map.get(:readings)
  end

  test "a settled raid on the board is written down" do
    Board.put_raid("r1", :raid, fact("r1"))

    assert RememberRaids.remember() == 1
    assert RememberRaids.counted() == 1
  end

  # Both sides publish a commitment and the defender publishes the recording, so
  # the same raid arrives repeatedly. A second sighting must be free.
  test "seeing the same raid twice writes one row" do
    Board.put_raid("r1", :raid, fact("r1"))

    assert RememberRaids.remember() == 1
    assert RememberRaids.remember() == 0

    assert RememberRaids.counted() == 1
  end

  # A raid with no recording is still out. It has no outcome, and writing one
  # would mean a row that has to be corrected later.
  test "a raid still in flight is not written" do
    Board.put_raid("r1", :committed, %{"raid_id" => "r1", "role" => "attacker"})

    assert RememberRaids.remember() == 0
    assert RememberRaids.counted() == 0
  end

  # ⚠⚠⚠ A RAID THE MESH HAS ALREADY DELIVERED IS FRESHER THAN THE DISK, and may
  # carry frames the stored row cannot.
  test "rehydration never overwrites a live raid" do
    Board.put_raid("r1", :raid, Map.put(fact("r1"), "ticks", 999))
    store("r1")

    assert RememberRaids.recall() == 0

    assert [%{parts: %{raid: [got]}}] = Dronex.raids()
    assert got["ticks"] == 999
  end

  test "nothing stored is an empty board rather than a crash" do
    assert RememberRaids.recall() == 0

    assert Dronex.raids() == []
  end
end
