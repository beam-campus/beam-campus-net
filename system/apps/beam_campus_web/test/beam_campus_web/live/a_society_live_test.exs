defmodule BeamCampusWeb.ASocietyLiveTest do
  @moduledoc """
  The page with no mesh behind it, and the page with islands on the board.

  An unconfigured site must serve a working page: that is how it renders in dev,
  in CI, and for anyone who clones the repo.
  """
  # NOT async. The board is one ETS table for the whole node, so tests that write
  # to it are not independent.
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias ASociety.WatchIslands.Board

  setup do
    if :ets.info(:asociety_board) == :undefined, do: Board.init()
    :ets.delete_all_objects(:asociety_board)
    :ets.insert(:asociety_board, {:refused, 0})
    :ok
  end

  test "renders with nothing at all", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/asociety")

    assert html =~ "A Society"
    # Not configured in test, and the page says which kind of quiet it is rather
    # than one apologetic sentence covering five different situations.
    assert html =~ "not configured to read the society realm"
  end

  # ⚠ THE PAGE MUST NOT DRAW A MAP, AND THIS IS THE ONLY PLACE THAT CAN SAY SO.
  #
  # There is no space inside an island in this design, so a map would be drawing
  # the one thing the model does not have. The page states that in words, and if
  # somebody later adds a hex board because the sibling has one, this fails.
  test "says plainly that it is not a map", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/asociety")

    assert html =~ "Not a map"
    assert html =~ "beliefs, not believers"
  end

  # ⚠ FIVE STATES, AND EACH SENDS THE READER SOMEWHERE DIFFERENT. Collapsing any
  # two of them produces a page that looks helpful and points at the wrong thing:
  # dark is a transport question, no_contract is a statement about the island's
  # build, and unconfigured is neither.
  test "every state has its own words", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/asociety")
    assert html =~ "unconfigured"

    words = Enum.map(states(), &ASociety.explain/1)

    assert length(Enum.uniq(words)) == 5
    assert Enum.all?(words, &(String.length(&1) > 20))
  end

  # The page renders whatever `ASociety.explain/1` returns, so this tests the
  # thing the page shows rather than a copy of the strings kept in a test.
  test "the page shows the explanation for the state it is in", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/asociety")

    assert html =~ String.slice(ASociety.explain(ASociety.state()), 0, 40)
  end

  defp states, do: [:unconfigured, :dark, :no_contract, :silent, :watching]

  test "an island that has not said its name is shown by its identity", %{conn: conn} do
    Board.put(String.duplicate("a", 32), :vitals, %{"island_id" => String.duplicate("a", 32)})

    {:ok, _view, html} = live(conn, ~p"/research/asociety")

    assert html =~ "aaaaaaaa"
  end

  # ⚠ TWO ISLANDS SHARING A NAME MUST NOT MERGE. A name is an environment
  # variable falling back to a hostname and two islands can carry the same one;
  # identity is 128 bits nobody types. Filing under the name would show one
  # island flickering between two populations, and every other assertion on this
  # page would still pass. The sibling shipped exactly that bug.
  test "two islands with one name stay two islands" do
    for id <- [String.duplicate("1", 32), String.duplicate("2", 32)] do
      Board.put(id, :vitals, %{"island_id" => id, "island" => "beam01"})
    end

    assert length(ASociety.islands()) == 2
  end

  test "the board refuses rather than growing without bound, and says it did" do
    for n <- 1..70 do
      id = String.pad_leading(Integer.to_string(n), 32, "0")
      Board.put(id, :vitals, %{"island_id" => id})
    end

    assert length(ASociety.islands()) == 64
    assert ASociety.refused() > 0
  end

  # ⚠ THE STATE TODAY, ASSERTED SO THAT IT CHANGES DELIBERATELY. The island
  # publishes nothing at this commit, so there is no topic to subscribe to. When
  # hecate-society defines its first fact this fails, which is the reminder to
  # update the page's words at the same time.
  test "there is no fact contract yet" do
    assert ASociety.kinds() == []
  end
end
