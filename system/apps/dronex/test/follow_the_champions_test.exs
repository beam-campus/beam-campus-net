defmodule Dronex.FollowTheChampionsTest do
  @moduledoc """
  A controller crossing the mesh, which is the archipelago's central claim and
  was publishable only as a count going up.
  """
  use ExUnit.Case, async: false

  alias BeamCampus.Repo
  alias Dronex.FollowTheChampions
  alias Dronex.WatchBouts.Board

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  defp island(id, name, champion) do
    Board.put(
      id,
      :vitals,
      Map.merge(%{"island_id" => id, "island" => name, "benchmark_starts" => 48}, champion)
    )
  end

  # ⚠ THE CLAIM ITSELF. A genome id is the sha256 of its packed form, so the same
  # id holding two islands IS the crossing. No matching heuristics.
  test "one genome holding two islands is a crossing" do
    island("aaa", "beam00", %{"champion_id" => "g1", "champion_sorties" => 3})
    island("bbb", "beam01", %{"champion_id" => "g1", "champion_from" => "aaa"})

    FollowTheChampions.remember()

    assert [%{genome_id: "g1", islands: 2, crossed?: true}] = FollowTheChampions.ranked()
  end

  test "a genome that never left the island that made it has not crossed" do
    island("aaa", "beam00", %{"champion_id" => "g1"})

    FollowTheChampions.remember()

    assert [%{islands: 1, crossed?: false}] = FollowTheChampions.ranked()
  end

  # Taken from somewhere is a crossing even before it holds a second island.
  test "a captured champion is a crossing on one island" do
    island("aaa", "beam00", %{"champion_id" => "g1", "champion_from" => "bbb"})

    FollowTheChampions.remember()

    assert [%{islands: 1, crossed?: true}] = FollowTheChampions.ranked()
    assert [%{taken_from: "bbb"}] = FollowTheChampions.crossings()
  end

  # ⚠⚠ A REIGN IS A SPAN, NOT A SIGHTING. The champion is republished every
  # second; a row per sighting would be a million rows saying one thing.
  test "seeing the same champion again widens its reign rather than adding one" do
    island("aaa", "beam00", %{"champion_id" => "g1"})

    FollowTheChampions.remember()
    FollowTheChampions.remember()
    FollowTheChampions.remember()

    assert FollowTheChampions.counted() == 1
  end

  test "first seen never moves, so tenure is a subtraction" do
    island("aaa", "beam00", %{"champion_id" => "g1"})
    FollowTheChampions.remember()
    [before] = Repo.all(Dronex.FollowTheChampions.Reign)

    Process.sleep(5)
    FollowTheChampions.remember()
    [now] = Repo.all(Dronex.FollowTheChampions.Reign)

    assert now.first_seen == before.first_seen
    assert now.last_seen >= before.last_seen
  end

  # ⚠⚠⚠ AN ISLAND ON THE OLDER FACT VERSION NAMES NOBODY, and a fabricated id
  # would be worse than an absent one. Islands roll one at a time.
  test "an island publishing no champion is skipped, not invented" do
    island("aaa", "beam00", %{})

    assert FollowTheChampions.remember() == 0
    assert FollowTheChampions.ranked() == []
  end

  # Ranked on structural facts, never on the frozen exam: it is saturated and
  # REGISTER D.15 says it swings a hundred points in a day.
  test "more islands held outranks a longer hold on one" do
    island("aaa", "beam00", %{"champion_id" => "wide"})
    island("bbb", "beam01", %{"champion_id" => "wide"})
    island("ccc", "beam02", %{"champion_id" => "deep"})
    FollowTheChampions.remember()
    Process.sleep(5)
    FollowTheChampions.remember()

    assert [%{genome_id: "wide"}, %{genome_id: "deep"}] = FollowTheChampions.ranked()
  end

  # ⚠ AN ATOM IS A VALUE, NOT AN ABSENCE. The islands published
  # `champion_from => undefined` for a controller they bred, it crossed the wire
  # as something non-nil, and every locally bred champion was recorded as having
  # crossed the mesh — on the one panel whose purpose is to say which travelled.
  test "a champion bred here has not crossed, however the wire spells nothing" do
    for {id, name, spelling} <- [
          {"aaa", "beam00", "undefined"},
          {"bbb", "beam01", ""},
          {"ccc", "beam02", "none"}
        ] do
      island(id, name, %{"champion_id" => "g-" <> id, "champion_from" => spelling})
    end

    FollowTheChampions.remember()

    assert Enum.all?(FollowTheChampions.ranked(), &(&1.crossed? == false))
    assert FollowTheChampions.crossings() == []
  end

  test "nothing recorded is an empty list rather than a crash" do
    assert FollowTheChampions.ranked() == []
    assert FollowTheChampions.crossings() == []
  end
end
