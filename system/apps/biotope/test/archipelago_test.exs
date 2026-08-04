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
    # than hoped for. A grid sized to the population would reshuffle every
    # existing island each time one arrived, and the world would read as being
    # redrawn rather than as growing.
    test "existing islands do not move when another arrives" do
      before = Archipelago.place(["beam01", "beam02"])
      later = Archipelago.place(["beam01", "beam02", "beam03"])

      assert Map.get(before, "beam01") == Map.get(later, "beam01")
      assert Map.get(before, "beam02") == Map.get(later, "beam02")
    end

    test "and an island keeps its cell when a neighbour goes away" do
      full = Archipelago.place(["beam01", "beam02", "beam03"])
      fewer = Archipelago.place(["beam01", "beam03"])

      assert Map.get(full, "beam01") == Map.get(fewer, "beam01")
      assert Map.get(full, "beam03") == Map.get(fewer, "beam03")
    end
  end

  describe "the viewer fits the occupied region, not the whole grid" do
    # Two islands on a 16 by 16 grid would otherwise be two specks in a field of
    # empty ocean, and the page would be mostly nothing.
    test "extent covers exactly what is occupied" do
      placed = %{"a" => {3, 5}, "b" => {7, 5}, "c" => {5, 9}}

      assert {5, 5, {3, 5}} = Archipelago.extent(placed)
    end

    test "an empty world still has an extent rather than crashing" do
      assert {1, 1, {0, 0}} = Archipelago.extent(%{})
    end

    test "pixels are relative to the occupied region, so there is no dead margin" do
      placed = %{"a" => {3, 5}, "b" => {4, 6}}

      assert %{"a" => {0, 0}, "b" => {100, 100}} = Archipelago.pixels(placed, 100)
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
