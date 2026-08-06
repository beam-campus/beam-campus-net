defmodule Dronex.AccountForLosses do
  @moduledoc """
  What actually destroyed the drones in one engagement, read back off the frames.

  ## The question this exists to answer

  Twenty-four drones enter a raid and at most five come out, usually none or one,
  and the winner is a coin flip: 30 attacker to 34 defender over 64 recordings.
  A fight that always ends in mutual annihilation and picks its winner at random
  is not obviously a fight. It could be a swarm shredding itself.

  That is not idle worry. **Munitions cannot hit a friendly** — `hostile/2` in
  `airspace.erl` filters same-side before any geometry is tested — but
  **collisions ignore sides entirely**: `touching/2` excludes only self, dead and
  withdrawn, and damage scales with closing speed. So flying in tight formation
  costs airframes, and nothing on the island records which deaths were weapons
  and which were rams. `hurt/2` has a single `damage_taken` accumulator with no
  source in it.

  ## ⚠ THE METHOD: WEAPON DAMAGE IS QUANTISED AND COLLISION DAMAGE IS NOT

  This works by arithmetic rather than by guessing, and the arithmetic is exact:

    * `START_HEALTH` is 10000 and a frame publishes `H * 100 div 10000`, so
      health arrives as whole percent.
    * `HIT_DAMAGE` is 2500 and `INTERCEPTOR_DAMAGE` is 5000 — **exact multiples
      of 100** — so a weapon always shows as a drop of precisely 25 or 50 points,
      whatever fractional health the drone was carrying. Writing `h = 100a + b`,
      a 2500 hit takes it to `100(a-25) + b`, and the floor divides identically.
      The quantum survives the truncation.
    * A ram is `START_HEALTH * closing_speed div KILL_SPEED`, which is continuous
      and lands on a multiple of 25 only by coincidence.

  So the part of a health drop that is `rem 25` **cannot** be weapon damage, and
  is collision or the arena edge.

  ## ⚠⚠ WHAT THIS CANNOT DO, SAID BEFORE THE NUMBER IS SHOWN

  **It cannot separate a ram from the ground.** The obvious next step is to
  confirm a collision by finding another live drone within `2 × DRONE_RADIUS` at
  that moment. The published frames will not support it: `metres(U) -> U div
  20480` and `DRONE_RADIUS` is 10240 units, so the collision diameter is **one
  metre** and positions arrive as **whole metres**. At that resolution "they were
  touching" and "they were two metres apart" are the same reading. Separating
  them needs finer positions on the wire, not cleverer analysis here.

  **A collision of exactly 25% is counted as a weapon.** That is the one
  direction this errs in, it is a floor on the collision share rather than a
  ceiling, and it is not corrected because correcting it would mean guessing.

  **Aliasing.** Frames are every second tick (`?EVERY = 2`), so two unguided hits
  inside one window are indistinguishable from one interceptor. This counts
  damage rather than events for exactly that reason: 50 points is 50 points
  either way, and only an event count would have to choose.
  """

  @weapon_quantum 25

  @doc """
  Account for every point of damage in one recording.

  Returns damage in percentage-points of a drone's health, which is the unit the
  frames arrive in. `unquantised` is the part that cannot be a weapon.
  """
  @spec account([map()]) :: map()
  def account(frames) when is_list(frames) do
    frames
    |> Enum.map(&healths/1)
    |> pairs()
    |> Enum.reduce(blank(), &tally/2)
    |> finish(frames)
  end

  defp blank, do: %{quantised: 0, unquantised: 0, drops: 0, deaths: 0}

  # ⚠ A DROP IS SPLIT, NOT LABELLED. A fall of 30 is a weapon hit AND five points
  # of something else, and calling the whole event "collision" or the whole event
  # "weapon" would throw away the half that is certain.
  defp tally({before, now}, acc) do
    Enum.reduce(before, acc, fn {id, was}, inner ->
      dropped(was - Map.get(now, id, was), inner)
    end)
  end

  defp dropped(drop, acc) when drop <= 0, do: acc

  defp dropped(drop, acc) do
    %{
      acc
      | quantised: acc.quantised + div(drop, @weapon_quantum) * @weapon_quantum,
        unquantised: acc.unquantised + rem(drop, @weapon_quantum),
        drops: acc.drops + 1
    }
  end

  defp finish(acc, frames) do
    total = acc.quantised + acc.unquantised

    Map.merge(acc, %{
      total: total,
      deaths: deaths(frames),
      shots: shots(frames),
      # Nil rather than zero: no damage at all is not "0% weapons", it is a
      # question with no answer, and a zeroed bar chart would answer it anyway.
      weapon_share: share(acc.quantised, total),
      other_share: share(acc.unquantised, total)
    })
  end

  defp share(_part, 0), do: nil
  defp share(part, total), do: round(part * 100 / total)

  # State 2 is dead. Counted at the end rather than by watching transitions,
  # because a drone that dies in the last frame still died.
  defp deaths([]), do: 0

  defp deaths(frames) do
    frames
    |> List.last()
    |> rows("d", 7)
    |> Enum.count(fn row -> Enum.at(row, 6) == 2 end)
  end

  # Every munition seen in flight, counted once per frame it appears in. A rate
  # of fire rather than a shot count — the frames cannot tell one munition from
  # the next, since a munition row carries its OWNER and not its own identity.
  defp shots(frames), do: Enum.sum(Enum.map(frames, &length(rows(&1, "m", 5))))

  defp healths(frame) do
    frame
    |> rows("d", 7)
    |> Map.new(fn row -> {Enum.at(row, 0), Enum.at(row, 5)} end)
  end

  defp pairs(list), do: Enum.zip(list, tl(list ++ [%{}])) |> Enum.drop(-1)

  # A frame's drones arrive as ONE flat list, stride 7, because that is how a
  # canvas wants them. Nothing here reshapes the wire; it reads it.
  defp rows(frame, key, stride) do
    frame
    |> Map.get(key, [])
    |> Enum.chunk_every(stride)
    |> Enum.filter(&(length(&1) == stride))
  end
end
