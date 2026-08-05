defmodule BeamCampusWeb.DronexLiveTest do
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    :ets.delete_all_objects(:dronex_board)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  test "an unconfigured site says so rather than showing an empty chart", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "BEAM_CAMPUS_DRONEX_SEEDS"
    assert html =~ "DroneX"
  end

  # ⚠ THE SITE NAV IS ITS OWN LIST AND A WORKBENCH CARD DOES NOT FEED IT. That is
  # how a sibling page shipped invisible: the card was added, a test asserted the
  # card, and the dropdown listed the other tracks and nothing else.
  test "DroneX is in the site navigation", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research")

    assert html =~ "DroneX"
    assert html =~ "/research/workbench/dronex"
  end

  test "it renders inside the site layout", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ ">Workbench<"
  end

  # ⚠ IT SAYS WHAT IT IS. Nothing crosses the mesh yet, so a fight drawn here is
  # an island against its own drill. Calling it a raid would be the first lie
  # this track told, and the fact carries `kind` precisely so the page cannot.
  test "a published bout is drawn and named as a training bout", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam01",
      "roster" => 24,
      "capacity" => 240,
      "generation" => 9,
      "rounds" => 120,
      "admissions" => 31,
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => [6, 1],
      "benchmark_starts" => 6
    })

    Board.put("aaa", :bout, %{
      "island" => "beam01",
      "kind" => "training",
      "winner" => "attacker",
      "ticks" => 110,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => []}]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "training"
    assert html =~ "won by attacker"
    assert html =~ "beam01"
    refute html =~ "raid"
  end

  # A profile is a curve and never a total. A single number would need weights,
  # and weights are a judgement about which rung matters.
  test "the frozen exam is drawn per rung and never summed", %{conn: conn} do
    Board.put("aaa", :vitals, %{
      "island" => "beam01",
      "benchmark_rungs" => ["hoverer", "sniper"],
      "benchmark_wins" => [6, 1],
      "benchmark_starts" => 6
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "hoverer"
    assert html =~ "sniper"
    assert html =~ "6/6"
    assert html =~ "1/6"
  end

  # An island that has not sat the exam is different from one that sat it and
  # lost everything, and a zero must not be drawn as a flat bar.
  test "an unsat exam says so", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam01", "benchmark_starts" => 0})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex")

    assert html =~ "Not sat yet"
  end
end
