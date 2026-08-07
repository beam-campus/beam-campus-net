defmodule Dronex.TellIslandsApartTest do
  @moduledoc """
  Two islands that call themselves the same thing must not look the same.

  The board already kept them apart; only the screen merged them. These tests are
  about the screen.
  """
  use ExUnit.Case, async: false

  alias Dronex.TellIslandsApart, as: Apart
  alias Dronex.WatchBouts.Board

  @first "a6b1605a0f8f82d8dde1bfa260e41168"
  @second "e649229946edce4883dec30091566da5"

  setup do
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  # ⚠ `put/3', NOT `put_raid/3'. An island row is keyed by its island_id; a raid
  # row is keyed `{:raid, raid_id}'. Using the raid path here stored a raid whose
  # id happened to look like an island and `Dronex.island/1' found nothing.
  defp publish(id, name) do
    Board.put(id, :vitals, %{"island_id" => id, "island" => name, "tick" => 1})
  end

  # ⚠ THE WHOLE POINT. Both call themselves beam01, the board keeps them apart,
  # and before the mark existed the page showed one island contradicting itself.
  test "two islands with one name are told apart on screen" do
    publish(@first, "beam01")
    publish(@second, "beam01")

    first = Apart.named(Dronex.island(@first))
    second = Apart.named(Dronex.island(@second))

    assert first == {"beam01", "a6b1"}
    assert second == {"beam01", "e649"}
    refute first == second
  end

  test "the mark is the first four characters of the id" do
    assert Apart.mark(@first) == "a6b1"
  end

  test "nothing that is not an id gets a mark" do
    assert Apart.mark(nil) == nil
    assert Apart.mark("abc") == nil
  end

  # ⚠ ALWAYS, NOT ONLY WHEN AMBIGUOUS. A stranger taking the name of an island
  # that is currently offline produces no collision to detect, and a bare name
  # must never come to mean "verified unique".
  test "an island alone on the board still carries its mark" do
    publish(@first, "beam01")

    assert Apart.named(Dronex.island(@first)) == {"beam01", "a6b1"}
  end

  # An island that has published no name is already shown by its id, so adding
  # the mark would print the same characters twice.
  test "an unnamed island is shown once, not twice" do
    Board.put(@first, :bout, %{"island_id" => @first, "tick" => 1})

    assert {"a6b1605a", nil} = Apart.named(Dronex.island(@first))
  end

  test "an island nobody has heard of is somebody" do
    assert Apart.named(nil) == {"somebody", nil}
    assert Apart.spoken(nil) == "somebody"
  end

  # ⚠ SPOKEN, NOT PUNCTUATED. A screen reader should say "beam01 a6b1", never
  # "beam01 middle dot a6b1".
  test "the spoken form is a plain string with no separator to read out" do
    publish(@first, "beam01")

    assert Apart.spoken(Dronex.island(@first)) == "beam01 a6b1"
  end

  test "an unnamed island speaks its short id alone" do
    Board.put(@first, :bout, %{"island_id" => @first, "tick" => 1})

    assert Apart.spoken(Dronex.island(@first)) == "a6b1605a"
  end

  # A raid fact carries `attacker_id` and no attacker name, so the name has to
  # come off the board and the attacker may never have been heard from.
  test "an id resolves through the board when the island is known" do
    publish(@first, "beam01")

    assert Apart.spoken_id(@first) == "beam01 a6b1"
  end

  test "an unknown attacker is its short id, not nil and not somebody" do
    assert Apart.spoken_id(@second) == "e6492299"
  end

  test "a missing attacker is somebody" do
    assert Apart.spoken_id(nil) == "somebody"
  end
end
