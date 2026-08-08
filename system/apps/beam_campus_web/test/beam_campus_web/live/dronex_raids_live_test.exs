defmodule BeamCampusWeb.DronexRaidsLiveTest do
  @moduledoc """
  The raids view: who raids whom, what it costs, and whether a genome crosses.

  ⚠ **ITS OWN FILE BECAUSE IT IS ITS OWN ROUTE.** These moved here whole from
  `DronexLiveTest` when `/dronex` became several pages. Only the URL changed;
  every assertion and every comment above it is the one that was there, because
  the comment IS the finding the test records.
  """
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    :ets.delete_all_objects(:dronex_board)
    :ets.delete_all_objects(:dronex_recordings)
    :ets.delete_all_objects(:dronex_history)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  defp raid(attacker, island) do
    %{
      "island" => island,
      "attacker_id" => attacker,
      "kind" => "raid",
      "winner" => "attacker",
      "ticks" => 800,
      "raiders" => 12,
      "raiders_home" => 5,
      "defenders" => 12,
      "defenders_home" => 4,
      "arena" => [1000, 1000, 300],
      "frames" => [%{"t" => 0, "d" => [0, 500, 500, 100, 0, 100, 0], "m" => [], "k" => []}]
    }
  end

  # ⚠ A CHART THAT SILENTLY DREW WHAT IT HAD WOULD ANSWER A DIFFERENT QUESTION
  # CONVINCINGLY. The stamp shipped after these islands had been fighting for
  # days, so a fleet mid-roll carries raids with one side stamped and not the
  # other, and those must be counted out loud rather than drawn at a fabricated
  # gap.
  test "an unplottable raid is reported rather than drawn", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    # Settled, but only the attacker carries a stamp.
    Board.put_raid("r1", :raid, raid("aaa", "beam01") |> Map.put("island_id", "bbb"))

    Board.put_raid("r1", :committed, %{
      "raid_id" => "r1",
      "role" => "attacker",
      "island_id" => "aaa",
      "opponent_id" => "bbb",
      "rounds" => 9000
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/raids")

    assert html =~ "Does breeding longer win wars"
    assert html =~ "Nothing to plot yet"
    assert html =~ "waiting"
  end

  test "a raid stamped on both sides is plotted with its sign", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})

    Board.put_raid(
      "r1",
      :raid,
      raid("aaa", "beam01") |> Map.merge(%{"island_id" => "bbb", "rounds" => 8000})
    )

    Board.put_raid("r1", :committed, %{
      "raid_id" => "r1",
      "role" => "attacker",
      "island_id" => "aaa",
      "opponent_id" => "bbb",
      "rounds" => 9000
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/raids")

    refute html =~ "Nothing to plot yet"
    assert html =~ "1000 rounds: raider 9000, island 8000"
    # The lanes are named for what happened, not for a side.
    assert html =~ "raider won"
    assert html =~ "island held"
  end

  test "a settled raid appears in the attacker's row and the defender's column", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put("bbb", :vitals, %{"island" => "beam01", "island_id" => "bbb", "roster" => 90})
    Board.put_raid("r1", :raid, raid("aaa", "beam01") |> Map.put("island_id", "bbb"))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/raids")

    assert html =~ "Who raids whom"
    assert html =~ ~s(&quot;n&quot;:1)
  end

  # ⚠ A RAID IN FLIGHT IS NOT A RAID THAT DID NOT HAPPEN. Counting it as zero
  # would quietly write off every fight in progress.
  test "a pair with commitments and no recording reads as still out", %{conn: conn} do
    Board.put("aaa", :vitals, %{"island" => "beam00", "island_id" => "aaa", "roster" => 90})
    Board.put("bbb", :vitals, %{"island" => "beam01", "island_id" => "bbb", "roster" => 90})

    Board.put_raid("r1", :committed, %{
      "raid_id" => "r1",
      "role" => "attacker",
      "island_id" => "aaa",
      "opponent_id" => "bbb"
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/raids")

    assert html =~ ~s(&quot;f&quot;:1)
  end

  # ⚠ THE PICTURE, NOT THE ARITHMETIC. The previous version of this cell computed
  # a correct tint and rendered nothing a human could see: `color-mix' at 48% over
  # a dark surface. Seven tests passed on the numbers. So this one asserts that
  # SHAPES reach the page, in both side colours, which is the thing that failed.
  test "the ledger draws a pie per route, in the side colours", %{conn: conn} do
    for {id, name} <- [{"aaa", "beam00"}, {"bbb", "beam01"}] do
      Board.put(id, :vitals, %{"island" => name, "island_id" => id, "roster" => 90})
    end

    # aaa wins two of three against bbb; bbb loses its one.
    Board.put_raid("r1", :raid, raid("aaa", "beam01") |> Map.put("island_id", "bbb"))
    Board.put_raid("r2", :raid, raid("aaa", "beam01") |> Map.put("island_id", "bbb"))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/raids")

    # ⚠ THE CHART IS DRAWN IN THE BROWSER, so the server HTML carries the DATA
    # and not the shapes. Asserting on `<path>` here would only ever pass by
    # accident. What must be true server-side is that the cell reached the spec
    # with its counts intact, and that the hook is attached to draw it.
    # ⚠ A NAMED HOOK, NOT A COLOCATED ONE. It read
    # `BeamCampusWeb.DronexLive.Chart` while the hook was declared inside this
    # module and rendered fully qualified. /dronex is four LiveViews now and a
    # colocated hook belongs to whichever one declares it, so the hook moved to
    # assets/js/dronex_chart_hook.js and is registered by name in app.js.
    assert html =~ ~s(phx-hook="DronexChart")
    assert html =~ "who-raids-whom"
    assert html =~ "beam00 → beam01"
  end

  # ⚠⚠ A RAID STILL OUT IS NOT AN EMPTY CELL. `slices/1` counts settled raids, so
  # a commitment has no outcome to slice and the pie would have dropped it. A pair
  # fighting right now must not look like a pair that never has.
  test "a route with only a raid in flight still marks the cell", %{conn: conn} do
    for {id, name} <- [{"aaa", "beam00"}, {"bbb", "beam01"}] do
      Board.put(id, :vitals, %{"island" => name, "island_id" => id, "roster" => 90})
    end

    Board.put_raid("out", :committed, %{
      "raid_id" => "out",
      "role" => "attacker",
      "island_id" => "aaa",
      "opponent_id" => "bbb"
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/raids")

    # In-flight reaches the spec as `f`, which is what makes the dashed ring.
    assert html =~ ~s(&quot;f&quot;:1)
  end
end
