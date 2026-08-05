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
    {:ok, _view, html} = live(conn, ~p"/research/workbench/asociety")

    assert html =~ "ASociety"
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
    {:ok, _view, html} = live(conn, ~p"/research/workbench/asociety")

    assert html =~ "Not a map"
    assert html =~ "beliefs, not believers"
  end

  # ⚠ FIVE STATES, AND EACH SENDS THE READER SOMEWHERE DIFFERENT. Collapsing any
  # two of them produces a page that looks helpful and points at the wrong thing:
  # dark is a transport question, no_contract is a statement about the island's
  # build, and unconfigured is neither.
  test "every state has its own words", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/asociety")
    assert html =~ "unconfigured"

    words = Enum.map(states(), &ASociety.explain/1)

    assert length(Enum.uniq(words)) == 4
    assert Enum.all?(words, &(String.length(&1) > 20))
  end

  # The page renders whatever `ASociety.explain/1` returns, so this tests the
  # thing the page shows rather than a copy of the strings kept in a test.
  test "the page shows the explanation for the state it is in", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/asociety")

    assert html =~ String.slice(ASociety.explain(ASociety.state()), 0, 40)
  end

  defp states, do: [:unconfigured, :dark, :silent, :watching]

  test "an island that has not said its name is shown by its identity", %{conn: conn} do
    Board.put(String.duplicate("a", 32), :vitals, %{"island_id" => String.duplicate("a", 32)})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/asociety")

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

  # ⚠ RULE 9 ON THE PAGE, WHICH IS THE LAST PLACE IT COULD BE SMUGGLED IN. The
  # axes are incommensurable, so any single number would be a weighting, and a
  # weighting is somebody's culture rather than a measurement. A panel wants a
  # headline and whoever writes one will be tempted.
  test "the panel shows all nine axes and no total", %{conn: conn} do
    id = String.duplicate("f", 32)

    Board.put(id, :vitals, %{
      "island_id" => id,
      "island" => "beam00",
      "tick" => 42,
      "persons" => 96,
      "capacity" => 120,
      "births" => 3,
      "deaths" => 3,
      "axes" => ~w(subsistence protection affection understanding participation
                   leisure creation identity freedom),
      "needs" => [500, 510, 490, 505, 495, 500, 502, 511, 499],
      "synergic" => 5,
      "singular" => 4,
      "inhibiting" => 0,
      "pseudo" => 0,
      "violator" => 0
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/asociety")

    for axis <- ~w(subsistence protection affection understanding participation
                   leisure creation identity freedom) do
      assert html =~ axis
    end

    assert html =~ "tick 42"
    assert html =~ "96 / 120 persons"
    assert html =~ "5 synergic"
    assert html =~ "0 violator"

    refute html =~ "welfare"
    refute html =~ "wellbeing"
    refute html =~ "happiness"
    refute html =~ "overall"
  end

  test "the board refuses rather than growing without bound, and says it did" do
    for n <- 1..70 do
      id = String.pad_leading(Integer.to_string(n), 32, "0")
      Board.put(id, :vitals, %{"island_id" => id})
    end

    assert length(ASociety.islands()) == 64
    assert ASociety.refused() > 0
  end

  # ⚠ THE MESSAGE SHAPE, PUSHED THROUGH THE REAL HANDLER. THIS IS THE ONE THAT
  # WOULD HAVE SAVED AN HOUR.
  #
  # The SDK sends `{:macula_event, ref, topic, payload, meta}`. The first version
  # of the subscriber matched four elements, so every fact fell through the
  # catch-all `handle_info(_msg, s)` and was dropped in silence: subscription
  # live, island reporting 226 published and 0 failed, page saying "subscribed,
  # and nothing has arrived".
  #
  # Nothing else could have caught it. Every unit test passed, the island's own
  # suite passed, both ends agreed on realm, topic and station, and the fault
  # was a tuple one element short in a clause that had a catch-all underneath it.
  test "a fact in the SDK's real message shape reaches the board" do
    id = String.duplicate("e", 32)
    ref = make_ref()

    :sys.replace_state(ASociety.WatchIslands, fn s ->
      %{s | refs: Map.put(s.refs, ref, :vitals)}
    end)

    send(
      ASociety.WatchIslands,
      {:macula_event, ref, "society/vitals",
       %{"island_id" => id, "island" => "beam09", "tick" => 7}, %{}}
    )

    # A cast through the GenServer, so the send above has been handled by the
    # time this returns.
    _ = :sys.get_state(ASociety.WatchIslands)

    assert Enum.any?(ASociety.islands(), &(&1.id == id))
  end

  # And the shape that announces a dropped link, which was two elements short in
  # the same way and would have left the reader deaf after any reconnect.
  test "a gone subscription is handled rather than ignored" do
    ref = make_ref()

    :sys.replace_state(ASociety.WatchIslands, fn s ->
      %{s | refs: Map.put(s.refs, ref, :vitals), subscribed: [:vitals]}
    end)

    send(ASociety.WatchIslands, {:macula_event_gone, ref, :link_down})
    state = :sys.get_state(ASociety.WatchIslands)

    refute Map.has_key?(state.refs, ref)
    refute :vitals in state.subscribed
  end

  # ⚠ THE SITE NAV IS ITS OWN LIST, AND A WORKBENCH CARD DOES NOT FEED IT.
  # That is how this page shipped invisible: the card was added, a test asserted
  # the card, and the dropdown in `layouts.ex` listed the other tracks and
  # nothing else. A page absent from the menu is a page nobody finds, whatever
  # else points at it.
  test "ASociety is in the site navigation", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research")

    assert html =~ "ASociety"
    assert html =~ "/research/workbench/asociety"
  end

  # ⚠ IT DID FAIL THE DAY THE ISLAND PUBLISHED, which was its whole job. It used
  # to assert there was no contract at all. Now it pins what the contract IS, so
  # that adding a second topic is a deliberate act on both sides rather than a
  # reader quietly listening to something the island never agreed to send.
  test "the contract is one topic" do
    assert ASociety.kinds() == [:vitals]
  end

  # ⚠ THE READER DOES NOT MIRROR THE ORDER OF THE NINE AXES. The island sends
  # their names beside the vector precisely so that an island a version ahead,
  # with a tenth axis, renders correctly here without this app being redeployed.
  # The sibling had to mirror a field order in its own source and drifted.
  test "the axis names come off the wire, not out of this app" do
    fact = %{
      "axes" => ["subsistence", "protection", "a_tenth_axis"],
      "needs" => [500, 250, 900]
    }

    assert ASociety.needs(fact) == [
             {"subsistence", 500},
             {"protection", 250},
             {"a_tenth_axis", 900}
           ]
  end

  # Network input from a public realm. Two lists of different lengths is a
  # version difference or a truncated frame, and it must cost the panel rather
  # than the page.
  test "a fact whose lists disagree costs the panel and not the page" do
    assert ASociety.needs(%{"axes" => ["a", "b"], "needs" => [1]}) == []
    assert ASociety.needs(%{}) == []
    assert ASociety.needs(nil) == []
  end
end
