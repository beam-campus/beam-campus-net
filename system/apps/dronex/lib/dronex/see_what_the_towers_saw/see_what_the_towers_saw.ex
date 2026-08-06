defmodule Dronex.SeeWhatTheTowersSaw do
  @moduledoc """
  How much of a raid the defender's ground network actually had located.

  ## The claim this tests, which the design makes and had never checked

  A defender fights at home with a network of sensor towers; a raider flies in
  with none. `REGISTER D.12` says **height buys silence** — a tower tests slant
  range, so its reach shrinks with altitude, and a raider that climbs should be
  harder to hold. That is a claim about the world and the recordings have carried
  the evidence for it all along: every frame publishes what the network BELIEVED
  alongside where the drones actually were.

  ## ⚠ COVERAGE BY ALTITUDE, NEVER DEATHS BY ALTITUDE

  The tempting chart is where drones die against how high they were. It is
  misleading and must not be drawn: the towers stand on the ground and the
  objective is on the ground, so deaths pile up low from pure exposure geometry,
  and the picture would read as confirming "height buys silence" when it shows
  only that the fighting happens where the fighting happens.

  What is honest is a RATE with the right denominator: of all the time raiders
  spent at this altitude, what fraction of it was the network holding them? Time
  at altitude is the denominator, so a band nobody flies in cannot flatter or
  damn itself.

  ## ⚠⚠ A TRACK IS ANONYMOUS BY CONSTRUCTION, SO THIS IS A BOUND

  `dronex_bout` publishes tracks with **no id and no confidence**, deliberately:
  "a spectator that could pair a track with a drone would be shown something the
  network never knew". So this cannot say *this drone was tracked*. It says a
  track existed within `gate` metres of it, which is a nearest-neighbour bound
  and is an over-count — two raiders close together are both "covered" by one
  track. The figure is a ceiling on coverage, and the page says so.

  ## Sides come from the id, and nothing else in the frame carries them

  `dronex_bout:index_of/1` is `{attacker, K} -> K * 2` and
  `{defender, K} -> K * 2 + 1`, so an **even** drone index is a raider. Only
  raiders are counted: the network is the defender's and it exists to find
  intruders, so including the home side would measure a thing nobody built.
  """

  # Metres. The unguided weapon is effective inside about fifteen, so a network
  # holding a raider to within this has it located well enough to cue a shot.
  # Stated rather than tuned: a gate chosen to make the answer come out is not a
  # measurement.
  @gate 25

  # Six bands over the 300 m ceiling. Coarse on purpose — a band needs enough
  # drone-frames in it to mean anything, and the arena is only 300 m tall.
  @band 50

  @doc "Coverage per altitude band, oldest frame to newest, raiders only."
  @spec coverage([map()], keyword()) :: map()
  def coverage(frames, opts \\ []) when is_list(frames) do
    gate = Keyword.get(opts, :gate, @gate)

    frames
    |> Enum.flat_map(&raiders_against_tracks(&1, gate))
    |> Enum.reduce(%{}, &bucket/2)
    |> present(gate)
  end

  @doc "The gate this was measured at, so a caption can name it."
  @spec gate() :: pos_integer()
  def gate, do: @gate

  defp raiders_against_tracks(frame, gate) do
    tracks = rows(frame, "k", 3)

    frame
    |> rows("d", 7)
    |> Enum.filter(&raider_in_the_fight?/1)
    |> Enum.map(fn [_id, x, y, z, _yaw, _hp, _state] ->
      {band(z), nearest(tracks, x, y, z) <= gate}
    end)
  end

  # ⚠ ALIVE AND NOT WITHDRAWN. A dead drone is not being tracked or not tracked;
  # it is not there, and counting its frames would pad every band with the
  # wreckage of whoever died earliest.
  defp raider_in_the_fight?([id, _x, _y, _z, _yaw, _hp, state]),
    do: rem(trunc(id), 2) == 0 and trunc(state) == 0

  defp raider_in_the_fight?(_row), do: false

  defp nearest([], _x, _y, _z), do: :infinity

  defp nearest(tracks, x, y, z) do
    tracks
    |> Enum.map(fn [tx, ty, tz] -> :math.sqrt(sq(tx - x) + sq(ty - y) + sq(tz - z)) end)
    |> Enum.min()
  end

  defp sq(n), do: n * n

  defp band(z), do: min(trunc(max(z, 0) / @band), 5)

  defp bucket({band, tracked?}, acc) do
    {frames, held} = Map.get(acc, band, {0, 0})
    Map.put(acc, band, {frames + 1, held + ((tracked? && 1) || 0)})
  end

  defp present(buckets, gate) do
    bands =
      Enum.map(0..5, fn n ->
        {frames, held} = Map.get(buckets, n, {0, 0})

        %{
          from: n * @band,
          to: (n + 1) * @band,
          frames: frames,
          held: held,
          # ⚠ NIL AND NOT ZERO for a band nobody flew in. No time at an altitude
          # is not "never tracked there", it is a question with no answer, and a
          # zeroed bar answers it anyway.
          coverage: rate(held, frames)
        }
      end)

    %{gate: gate, band: @band, bands: bands, frames: Enum.sum(Enum.map(bands, & &1.frames))}
  end

  defp rate(_held, 0), do: nil
  defp rate(held, frames), do: round(held * 100 / frames)

  defp rows(frame, key, stride) do
    frame
    |> Map.get(key, [])
    |> Enum.chunk_every(stride)
    |> Enum.filter(&(length(&1) == stride))
  end
end
