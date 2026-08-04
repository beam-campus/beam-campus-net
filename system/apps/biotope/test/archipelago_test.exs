defmodule Biotope.ArchipelagoTest do
  use ExUnit.Case, async: true

  alias Biotope.Archipelago

  describe "the layout is a pure function of the island set" do
    # ⚠ THE WHOLE DESIGN RESTS ON THIS ONE PROPERTY. Positions are derived from
    # the names rather than claimed by the nodes, which is what removes the need
    # for an authority, a claim protocol and conflict resolution. If two viewers
    # holding the same islands could compute different maps, all of that comes
    # back.
    test "the same islands give the same map, whatever order they arrive in" do
      names = ["beam00", "beam01", "beam02", "beam03"]

      assert Archipelago.place(names) == Archipelago.place(Enum.reverse(names))
      assert Archipelago.place(names) == Archipelago.place(Enum.shuffle(names))
    end

    test "and duplicates change nothing" do
      assert Archipelago.place(["beam01", "beam02"]) ==
               Archipelago.place(["beam01", "beam02", "beam01"])
    end

    test "no two islands share a cell" do
      names = for n <- 0..40, do: "island#{n}"
      placed = Archipelago.place(names)

      assert map_size(placed) == length(names)
      assert placed |> Map.values() |> Enum.uniq() |> length() == length(names)
    end
  end

  describe "a new island ADDS land rather than rearranging it" do
    # ⚠ THIS IS THE MESSAGE THE MAP EXISTS TO CARRY, so it is asserted rather
    # than hoped for.
    test "an island keeps its grid cell when others come and go" do
      before = Archipelago.place(["beam01", "beam02"])
      later = Archipelago.place(["beam01", "beam02", "beam03"])
      fewer = Archipelago.place(["beam01"])

      assert Map.get(before, "beam01") == Map.get(later, "beam01")
      assert Map.get(before, "beam01") == Map.get(fewer, "beam01")
    end

    # ⚠ AND THE DRAWN POSITION IS A WEAKER PROMISE THAN THE CELL, DELIBERATELY.
    # Squeezing out the empty ocean means an island arriving BETWEEN two others
    # pushes them apart, so pixel positions are not fixed for ever. What must
    # never change is the ORDER: nothing jumps past anything else, so a new node
    # reads as land appearing in the right place rather than as a reshuffle.
    test "relative order survives an arrival, even one that lands in between" do
      names = for n <- 0..30, do: "island#{n}"
      grown = Archipelago.place(names)
      fewer = Archipelago.place(Enum.drop(names, 10))

      order = fn placed ->
        placed
        |> Enum.sort_by(fn {_n, {c, r}} -> {c, r} end)
        |> Enum.map(&elem(&1, 0))
      end

      kept = order.(fewer)
      assert kept == Enum.filter(order.(grown), &(&1 in kept))
    end

    test "the world gets BIGGER when an island joins, never smaller" do
      small = Archipelago.place(["beam01", "beam02"])
      large = Archipelago.place(["beam01", "beam02", "beam03", "beam00"])

      {sc, sr} = Archipelago.extent(small)
      {lc, lr} = Archipelago.extent(large)

      assert lc * lr > sc * sr
    end
  end

  describe "the viewer fits the occupied region, not the whole grid" do
    # Two islands on a 16 by 16 grid would otherwise be two specks in a field of
    # empty ocean, and the page would be mostly nothing.
    # ⚠ MEASURED ON THE REAL FLEET BEFORE THIS EXISTED: beam00, beam01, beam02
    # and beam03 hash to columns 4, 7, 11 and 13, which spans TEN columns. Drawn
    # raw that is 2,960 pixels, 2.1 screens, and 10% land. Squeezed, it is four
    # columns and fits one screen.
    test "empty ocean between islands is squeezed out" do
      placed = %{"a" => {3, 5}, "b" => {7, 5}, "c" => {5, 9}}

      assert {3, 2} = Archipelago.extent(placed)
      assert %{"a" => {0, 0}, "b" => {200, 0}, "c" => {100, 100}} =
               Archipelago.pixels(placed, 100)
    end

    test "an empty world still has an extent rather than crashing" do
      assert {1, 1} = Archipelago.extent(%{})
    end

    # ⚠ BUT NOT SQUEEZED TO NOTHING. Collapsing every gap made the map compact
    # and made every island exactly as far from every other, which throws away
    # the only spatial information there is. A skipped column is worth a sliver
    # of open water, so islands the hash threw far apart are drawn further apart.
    test "a skipped column is a sliver of sea rather than nothing" do
      # a and b are adjacent; c is three columns further on.
      placed = %{"a" => {1, 0}, "b" => {2, 0}, "c" => {5, 0}}

      %{"a" => {ax, _}, "b" => {bx, _}, "c" => {cx, _}} =
        Archipelago.pixels(placed, 100, 10)

      # b sits one island from a, with nothing skipped.
      assert bx - ax == 100
      # c sits one island from b PLUS the two columns skipped on the way.
      assert cx - bx == 100 + 2 * 10
    end

    test "and with no open sea it collapses exactly as before" do
      placed = %{"a" => {1, 0}, "b" => {9, 0}}

      assert %{"a" => {0, 0}, "b" => {100, 0}} = Archipelago.pixels(placed, 100)
    end
  end

  # A layout with no islands is what every viewer starts with, and a page that
  # crashes before the first fact arrives is worse than one that draws an empty
  # sea.
  test "an empty world places nothing and does not crash" do
    assert Archipelago.place([]) == %{}
    assert Archipelago.pixels(%{}, 100) == %{}
  end
end
