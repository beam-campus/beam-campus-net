defmodule Dronex.SeeWhatTheTowersSawTest do
  @moduledoc """
  Coverage is a RATE with time-at-altitude underneath it, counted over raiders
  only, and it never claims a track belongs to a drone.
  """
  use ExUnit.Case, async: true

  alias Dronex.SeeWhatTheTowersSaw, as: Towers

  # drones: {id, x, y, z, state} — an EVEN id is a raider, `index_of/1` in
  # dronex_bout being {attacker, K} -> K*2 and {defender, K} -> K*2+1.
  defp frame(drones, tracks \\ []) do
    %{
      "t" => 0,
      "d" => Enum.flat_map(drones, fn {id, x, y, z, st} -> [id, x, y, z, 0, 100, st] end),
      "m" => [],
      "k" => Enum.flat_map(tracks, fn {x, y, z} -> [x, y, z] end)
    }
  end

  defp band_at(result, altitude) do
    Enum.find(result.bands, &(altitude >= &1.from and altitude < &1.to))
  end

  test "a raider with a track on top of it is held" do
    r = Towers.coverage([frame([{0, 100, 100, 20, 0}], [{100, 100, 20}])])

    assert band_at(r, 20).coverage == 100
    assert band_at(r, 20).frames == 1
  end

  test "a raider with every track far away is not held" do
    r = Towers.coverage([frame([{0, 100, 100, 20, 0}], [{900, 900, 200}])])

    assert band_at(r, 20).coverage == 0
  end

  test "a raider with no tracks at all is not held" do
    r = Towers.coverage([frame([{0, 100, 100, 20, 0}], [])])

    assert band_at(r, 20).coverage == 0
  end

  # ⚠ THE NETWORK IS THE DEFENDER'S AND EXISTS TO FIND INTRUDERS. Counting the
  # home side would measure a thing nobody built.
  test "defenders are not counted, however well tracked they are" do
    r = Towers.coverage([frame([{1, 100, 100, 20, 0}], [{100, 100, 20}])])

    assert band_at(r, 20).frames == 0
    assert band_at(r, 20).coverage == nil
    assert r.frames == 0
  end

  # ⚠ A DEAD DRONE IS NOT UNTRACKED, IT IS ABSENT. Counting its frames would pad
  # every band with the wreckage of whoever died earliest.
  test "dead and withdrawn raiders leave the denominator" do
    r =
      Towers.coverage([
        frame([{0, 100, 100, 20, 2}, {2, 100, 100, 20, 1}, {4, 100, 100, 20, 0}], [])
      ])

    assert band_at(r, 20).frames == 1
  end

  # The whole point of the denominator: a band flown for one frame and a band
  # flown for a hundred must not read alike.
  test "coverage is a rate over time at that altitude" do
    low = for _ <- 1..4, do: frame([{0, 0, 0, 10, 0}], [{0, 0, 10}])
    high = [frame([{0, 0, 0, 260, 0}], [{900, 900, 0}])]

    r = Towers.coverage(low ++ high)

    assert band_at(r, 10).coverage == 100
    assert band_at(r, 10).frames == 4
    assert band_at(r, 260).coverage == 0
    assert band_at(r, 260).frames == 1
  end

  # ⚠ NIL, NOT ZERO. No time at an altitude is a question with no answer, and a
  # zeroed bar answers it anyway.
  test "a band nobody flew in has no coverage rather than no coverage" do
    r = Towers.coverage([frame([{0, 0, 0, 10, 0}], [])])

    assert band_at(r, 280).frames == 0
    assert band_at(r, 280).coverage == nil
  end

  test "the gate is a parameter and is reported, not hidden" do
    far = [frame([{0, 0, 0, 10, 0}], [{0, 0, 40}])]

    assert Towers.coverage(far).bands |> Enum.at(0) |> Map.get(:coverage) == 0
    assert Towers.coverage(far, gate: 50).bands |> Enum.at(0) |> Map.get(:coverage) == 100
    assert Towers.coverage(far).gate == Towers.gate()
  end

  test "an empty recording measures nothing rather than crashing" do
    r = Towers.coverage([])

    assert r.frames == 0
    assert Enum.all?(r.bands, &(&1.coverage == nil))
  end
end
