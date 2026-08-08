defmodule Dronex.WeighTheRadioTest do
  @moduledoc """
  What the ablation measured, as opposed to how often the board sampled it.
  """
  use ExUnit.Case, async: true

  alias Dronex.WeighTheRadio

  defp samples(list) do
    for {at, air} <- Enum.with_index(list) |> Enum.map(fn {v, i} -> {i, v} end),
        do: %{at: at, air: air, ground: 0, all: 0}
  end

  defp air(list), do: WeighTheRadio.weigh(samples(list)) |> hd()

  # ⚠ THE WHOLE POINT. The wire republishes one exercise until the next runs and
  # the board samples every 30s, so 240 samples were three measurements drawn
  # eighty times each, and the panel looked like a distribution.
  test "a republished reading counts once" do
    assert %{n: 1, readings: [25]} = air([25, 25, 25, 25, 25])
  end

  # ⚠⚠ CONSECUTIVE ONLY, NEVER `Enum.uniq/1`. The same value measured again after
  # something else is a second measurement, and agreement is the one thing that
  # could ever settle this.
  test "the same value measured again after another is two measurements" do
    assert %{n: 3, readings: [25, -25, 25]} = air([25, 25, -25, -25, 25])
  end

  test "the spread is reported, not just the middle" do
    r = air([25, 50, -25])

    assert r.low == -25 and r.high == 50
    assert r.mean == 16.7
  end

  # A channel that matters sits off zero and stays there; noise scatters.
  test "agreement is the share pointing the same way as the average" do
    assert %{agree: 100} = air([25, 50, 25, 50])
    assert air([25, -25, 50, -50]).agree < 60
  end

  test "a channel nobody has measured says so" do
    assert %{n: 0, mean: nil} = air([])
    assert WeighTheRadio.reading(air([])) == "not measured yet"
  end

  # ⚠⚠⚠ IT REFUSES TO CONCLUDE ON A HANDFUL. One engagement changing hands is a
  # whole step of about 25, so a claim off three readings would be invented.
  test "a handful of readings is refused, however consistent" do
    said = WeighTheRadio.reading(air([25, 25, 25, 50, 25, 50, 25]))

    assert said =~ "too few to say"
    refute said =~ "needs it"
  end

  test "enough readings leaning one way is allowed to say so" do
    said = WeighTheRadio.reading(air([25, 50, 25, 50, 25, 50, 25, 50, 25]))

    assert said =~ "needs it"
    assert said =~ "9 exercises"
  end

  test "enough readings leaning the other way says the opposite" do
    assert WeighTheRadio.reading(air([-25, -50, -25, -50, -25, -50, -25, -50, -25])) =~
             "flies better silent"
  end

  test "enough readings that scatter say there is no lean" do
    assert WeighTheRadio.reading(air([25, -25, 50, -50, 25, -25, 50, -50, 25])) =~ "no lean yet"
  end

  test "all three channels are weighed" do
    assert [%{channel: :air}, %{channel: :ground}, %{channel: :all}] =
             WeighTheRadio.weigh(samples([25, 50]))
  end
end
