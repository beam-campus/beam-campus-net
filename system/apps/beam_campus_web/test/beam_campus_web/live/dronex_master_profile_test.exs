defmodule BeamCampusWeb.DronexMasterProfileTest do
  @moduledoc """
  The master profile panel on the landing view.

  What is defended here is the panel's behaviour under a fleet that is half
  rolled, which is the state it will actually be in most of the time, plus the
  one thing the chart cannot enforce for itself: with a single age band measured
  the reading is withdrawn rather than drawn.
  """
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    for t <- [:dronex_board, :dronex_recordings, :dronex_history], do: :ets.delete_all_objects(t)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  defp sat(id, name, eras, wins, draws, losses, archived \\ 40) do
    Board.put(id, :vitals, %{
      "island_id" => id,
      "island" => name,
      "master_eras" => eras,
      "master_wins" => wins,
      "master_draws" => draws,
      "master_losses" => losses,
      "master_flown" => Enum.sum(wins) + Enum.sum(draws) + Enum.sum(losses),
      "master_archived" => archived
    })
  end

  defp older(id, name) do
    Board.put(id, :vitals, %{"island_id" => id, "island" => name, "rounds" => 30})
  end

  defp page(conn) do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")
    html
  end

  test "the profile is drawn per age band and never summed", %{conn: conn} do
    sat("aaa", "beam00", [3, 12, 20], [6, 3, 1], [0, 1, 0], [2, 4, 7])

    html = page(conn)

    assert html =~ "Can the archipelago still beat what attacked it long ago?"
    assert html =~ "a profile, never a score"
    # 6 won of 8 in the newest band, 1 of 8 in the oldest: a per-band rate, not
    # 10 of 24 flown.
    assert html =~ ~s(&quot;won&quot;:[75,)
    assert html =~ ~s(&quot;kind&quot;:&quot;master&quot;)
  end

  # ⚠ THE PANEL GETS THINNER AND SAYS SO. Islands roll one at a time and the
  # master tournament arrived at fact version 7, so a panel that required every
  # island to publish it would disappear for half a fleet mid-deploy.
  test "an island on an older build is named, and the chart still draws", %{conn: conn} do
    sat("aaa", "beam00", [3], [6], [0], [2])
    older("bbb", "beam01")

    html = page(conn)

    assert html =~ "1 of 2 islands contributed"
    assert html =~ "on an older build and publishes none"
    assert html =~ ~s(id="master-profile")
  end

  # ⚠⚠ "HAS NOT SAT IT" AND "SAT IT AND LOST" MUST NEVER LOOK THE SAME, and the
  # whole fleet being on the new build with nothing flown is a third state again.
  test "a fleet that has not sat one says which of the two states it is in", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island_id" => "aaa",
      "island" => "beam00",
      "master_eras" => [],
      "master_wins" => [],
      "master_draws" => [],
      "master_losses" => [],
      "master_flown" => 0,
      "master_archived" => 17
    })

    html = page(conn)

    assert html =~ "none has sat a tournament yet"
    assert html =~ "17 invaders"
    refute html =~ ~s(id="master-profile")
  end

  test "a fleet entirely on an older build says the deploy has not landed", %{conn: conn} do
    older("aaa", "beam00")

    html = page(conn)

    assert html =~ "No island publishes a master tournament yet"
    assert html =~ "fact version 7"
    refute html =~ ~s(id="master-profile")
  end

  # ⚠⚠⚠ A LONE RULE IS TRIVIALLY LEVEL, and level is the word this panel uses for
  # progress. The chart cannot enforce this; the page must.
  test "one age band draws the chart and withdraws the reading", %{conn: conn} do
    sat("aaa", "beam00", [3], [6], [0], [2])

    html = page(conn)

    assert html =~ ~s(id="master-profile")
    assert html =~ "One age band so far"
    refute html =~ "treadmill"
  end

  test "two age bands restore the reading", %{conn: conn} do
    sat("aaa", "beam00", [3, 20], [6, 1], [0, 0], [2, 7])

    html = page(conn)

    assert html =~ "treadmill"
    refute html =~ "One age band so far"
  end

  # An age nothing was drawn from is not an age that was lost.
  test "a band nothing was drawn from ships as null, never as a zero", %{conn: conn} do
    sat("aaa", "beam00", [3, 20], [6, 1], [0, 0], [2, 7])

    assert page(conn) =~ ~s(&quot;won&quot;:[75,null,null,null,13])
  end

  # ⚠ THE ARCHIVE SATURATES AT 96 PER ISLAND AND EVICTS FROM ITS FULLEST BAND, so
  # calling it "faced" is wrong the moment it fills.
  test "the archive depth is called held, never faced", %{conn: conn} do
    sat("aaa", "beam00", [3], [6], [0], [2], 96)

    html = page(conn)

    assert html =~ "96 invaders held"
    refute html =~ "invaders faced"
  end

  # ⚠ EACH EXAM PROFILE GETS ITS OWN ID. `one_world/1` renders that component
  # twice, and a hardcoded id put two elements carrying the same phx-hook on one
  # page the moment both exams had data.
  test "the two exam profiles do not share a DOM id", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island_id" => "aaa",
      "island" => "beam00",
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => [6, 1],
      "benchmark_starts" => 6,
      "trials_rungs" => ["chaser", "duellist"],
      "trials_wins" => [2, 1],
      "trials_starts" => 6
    })

    html = page(conn)

    assert html =~ ~s(id="exam-profiles-held_out")
    assert html =~ ~s(id="exam-profiles-curriculum")
    refute html =~ ~s(id="exam-profiles")
  end
end
