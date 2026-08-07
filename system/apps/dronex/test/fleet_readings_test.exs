defmodule Dronex.FleetReadingsTest do
  @moduledoc """
  The two analyses are measured once when a recording arrives and accumulate over
  every raid, so the page describes a fleet rather than whichever fight happened
  to be selected.
  """
  use ExUnit.Case, async: false

  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  # One raider (even id) alive at `z`, with or without a track on top of it, and
  # taking `drop` points of damage between the two frames.
  defp raid_with(id, z, drop, tracked?) do
    tracks = (tracked? && [z, z, z]) || []

    frames = [
      %{"t" => 0, "d" => [0, z, z, z, 0, 100, 0], "m" => [], "k" => tracks},
      %{"t" => 2, "d" => [0, z, z, z, 0, 100 - drop, 0], "m" => [], "k" => tracks}
    ]

    Board.put_raid(id, :raid, %{"raid_id" => id, "island_id" => "aaa", "frames" => frames})
  end

  test "a reading is taken at ingest and survives the frames being dropped" do
    raid_with("r1", 20, 25, true)

    # The recording is gone, deliberately — it is the frames that are expensive.
    :ets.delete(:dronex_recordings, {:raid, "r1"})

    r = Dronex.fleet_readings()

    assert r.n == 1
    assert r.damage.quantised == 25
    assert r.coverage.frames == 2
  end

  # ⚠ THE WHOLE POINT. Per selected fight these were n=1 and could not be
  # believed; accumulated they are a distribution with its n printed on it.
  test "readings accumulate across raids" do
    raid_with("r1", 20, 25, true)
    raid_with("r2", 20, 12, true)

    r = Dronex.fleet_readings()

    assert r.n == 2
    assert r.damage.quantised == 25
    assert r.damage.unquantised == 12
    assert r.damage.weapon_share == 68
  end

  # ⚠ FRAMES ARE SUMMED AND THE RATE RECOMPUTED, NEVER AVERAGED. A raid that
  # spent four frames in a band and one that spent four hundred must not carry
  # equal weight, and a mean of percentages does exactly that.
  test "coverage weights a band by time spent in it, not by raid" do
    # One raid held at 20 m; one raid NOT held, four times as long, same band.
    raid_with("held", 20, 0, true)

    long = fn n ->
      frames =
        for _ <- 1..n do
          %{"t" => 0, "d" => [0, 20, 20, 20, 0, 100, 0], "m" => [], "k" => []}
        end

      Board.put_raid("miss", :raid, %{
        "raid_id" => "miss",
        "island_id" => "aaa",
        "frames" => frames
      })
    end

    long.(8)

    band = Dronex.fleet_readings().coverage.bands |> Enum.find(&(&1.from == 0))

    # 2 held of 10 raider-frames. A mean of the two raids' rates would say 50%.
    assert band.frames == 10
    assert band.held == 2
    assert band.coverage == 20
  end

  test "a board with no recordings reports nothing rather than zero" do
    r = Dronex.fleet_readings()

    assert r.n == 0
    assert r.damage == nil
    assert r.coverage == nil
  end

  # A commitment carries no frames, so it must not be mistaken for a reading of
  # zero — a raid still in flight has not been measured.
  test "a commitment does not create an empty reading" do
    Board.put_raid("r1", :committed, %{"raid_id" => "r1", "role" => "attacker"})

    assert Dronex.fleet_readings().n == 0
  end
end
