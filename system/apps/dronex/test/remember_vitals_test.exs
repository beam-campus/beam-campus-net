defmodule Dronex.RememberVitalsTest do
  @moduledoc """
  A trajectory outlives a restart, including the per-rung vector that
  `REGISTER D.15` needs and that a two-hour memory window cannot hold.
  """
  use ExUnit.Case, async: false

  alias BeamCampus.Repo
  alias Dronex.RememberVitals
  alias Dronex.WatchBouts.Board

  @island "a6b1605a0f8f82d8dde1bfa260e41168"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  defp seen(at, wins) do
    Board.put(@island, :vitals, %{
      "island_id" => @island,
      "island" => "beam01",
      "roster" => 90,
      "benchmark_wins" => wins,
      "benchmark_starts" => 48,
      "tick" => at
    })
  end

  test "a sample on the board is written down" do
    seen(1, [48, 24])

    assert RememberVitals.remember() == 1
    assert RememberVitals.counted() == 1
  end

  # ⚠ THE VECTOR IS THE POINT. A score is one number; the per-rung profile is the
  # only thing that can say what KIND of swing a score made.
  test "the per-rung vector survives the round trip" do
    seen(1, [48, 24, 12])
    RememberVitals.remember()

    for t <- [:dronex_history], do: :ets.delete_all_objects(t)
    assert RememberVitals.recall() == 1

    assert [%{rungs: [48, 24, 12], starts: 48}] = Dronex.history(@island)
  end

  # ⚠⚠ ONLY WHAT IS NEWER. Rewriting the whole window every tick would be 239
  # conflicts a time.
  test "a second pass writes nothing new" do
    seen(1, [48])
    assert RememberVitals.remember() == 1
    assert RememberVitals.remember() == 0
  end

  test "a restore never overwrites a fresher live sample" do
    seen(1, [48])
    RememberVitals.remember()
    # A live sample the disk has never seen.
    Board.remember_samples(@island, [%{at: 999, score: 7, rungs: [1], starts: 48}])

    RememberVitals.recall()

    assert 999 == Dronex.history(@island) |> hd() |> Map.get(:at)
  end

  test "nothing stored is an empty board rather than a crash" do
    assert RememberVitals.recall() == 0
    assert Dronex.history(@island) == []
  end
end
