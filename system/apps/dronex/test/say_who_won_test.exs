defmodule Dronex.SayWhoWonTest do
  @moduledoc """
  One vocabulary, in one place. The page used three at once.
  """
  use ExUnit.Case, async: true

  alias Dronex.SayWhoWon

  test "the wire's two words become the two a stranger reads" do
    assert SayWhoWon.said("attacker") == "raider won"
    assert SayWhoWon.said("defender") == "island held"
    assert SayWhoWon.said("draw") == "drawn"
  end

  # ⚠ AN UNKNOWN OUTCOME IS A DRAW, NOT A CRASH. This reads a value off a public
  # realm and a later island may publish a word this one has never heard of.
  test "an outcome nobody here understands is drawn rather than fatal" do
    assert SayWhoWon.said("annihilated") == "drawn"
    assert SayWhoWon.said(nil) == "drawn"
  end

  # The role resolves `--side-<role>`, so the phrase and its colour cannot drift
  # apart. They lived in three files and did exactly that.
  test "every outcome has a side to be coloured by" do
    assert SayWhoWon.role("attacker") == "attacker"
    assert SayWhoWon.role("defender") == "defender"
    assert SayWhoWon.role("draw") == "draw"
    assert SayWhoWon.role("annihilated") == "draw"
  end

  # ⚠⚠ THE ORDER IS THE READING ORDER, raider first, and the histogram stacks in
  # it. A change here silently reorders the legend on the page.
  test "the three outcomes come in reading order, raider first" do
    assert [{"attacker", "raider won", "attacker"}, {"draw", "drawn", "draw"}, {"defender", _, _}] =
             SayWhoWon.every()
  end

  # The consumers that used to spell these out for themselves.
  test "the histogram and the experience lanes take the same words" do
    from_histogram =
      Dronex.TimeTheFights.distribution([
        %{id: "r", parts: %{raid: [%{"ticks" => 100, "winner" => "attacker"}]}}
      ])

    assert [%{name: "raider won"}] = from_histogram.series
    assert [{"raider won", _}, {"drawn", _}, {"island held", _}] = Dronex.WeighTheExperience.lanes([])
  end
end
