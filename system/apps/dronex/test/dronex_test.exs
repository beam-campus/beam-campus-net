defmodule DronexTest do
  @moduledoc """
  The spectator's contract: it reads, it never runs the fight, and it says which
  of four situations it is in.
  """
  use ExUnit.Case, async: false

  alias Dronex.WatchBouts
  alias Dronex.WatchBouts.Board

  setup do
    Board.init()
    :ets.delete_all_objects(:dronex_board)
    :ets.delete_all_objects(:dronex_recordings)
    :ets.delete_all_objects(:dronex_history)
    :ets.insert(:dronex_board, {:refused, 0})
    :ok
  end

  # A recording's shape as it arrives: a list of flat frames, `stride` floats per
  # drone. Sized in frames because that is what makes one 1.2 MB on the box.
  defp recording(frames, per_frame \\ 70) do
    Enum.map(1..frames, fn f -> Enum.map(1..per_frame, &(&1 * 1.0 + f)) end)
  end

  # ⚠ THE SHAPE THE WIRE ACTUALLY DELIVERS. CBOR encodes an atom and a binary
  # identically, and the SDK decodes a text string to an EXISTING atom when one
  # happens to exist, so the shape a key arrives in depends on the receiving
  # node's atom table. One published map has arrived with four atom keys and
  # eleven string ones.
  test "untag collapses both shapes to strings, keys and values alike" do
    assert WatchBouts.untag(%{:island => {:text, "beam01"}, "tick" => 5}) ==
             %{"island" => "beam01", "tick" => 5}

    assert WatchBouts.untag([{:text, "a"}, :b, 3]) == ["a", "b", 3]
  end

  # Booleans and nil are left alone: CBOR has real ones, so those never came from
  # text and turning them into strings would be a decode that loses a type.
  test "untag leaves booleans and nil alone" do
    assert WatchBouts.untag(%{"a" => true, "b" => nil}) == %{"a" => true, "b" => nil}
  end

  # ⚠ FILED UNDER THE IDENTITY, NEVER THE NAME. Two islands can carry one
  # nickname, and filed under it they overwrite each other while the page shows
  # one place flickering between two rosters.
  test "two islands sharing a name are two rows" do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 5})
    Board.put("bbb", :vitals, %{"island" => "beam01", "roster" => 9})

    assert length(Board.islands()) == 2
    assert Enum.map(Board.islands(), &Board.label/1) == ["beam01", "beam01"]
  end

  # A later fact of one kind must not erase another kind's payload: vitals arrive
  # every second and a bout every twenty, and folding them would drop the fight.
  test "a bout and its vitals live side by side" do
    Board.put("aaa", :vitals, %{"island" => "beam01", "roster" => 5})
    Board.put("aaa", :bout, %{"island" => "beam01", "winner" => "attacker"})

    row = Board.island("aaa")
    assert Dronex.fact(row, :vitals)["roster"] == 5
    assert Dronex.fact(row, :bout)["winner"] == "attacker"
  end

  # ⚠ BOUNDED, AND IT SAYS WHEN IT REFUSES. A public realm is writable by anyone
  # who can reach a station, so an unbounded table is a memory leak with a
  # stranger holding the tap. A silent cap looks exactly like a small fleet.
  test "the board caps islands and counts what it turned away" do
    for n <- 1..70, do: Board.put("id#{n}", :vitals, %{"island" => "i#{n}"})

    assert length(Board.islands()) == 64
    assert Board.refused() == 6
  end

  # An island already held is always updated, cap or no cap: the cap is about
  # admitting NEW islands, and applying it to updates would freeze the ones shown.
  test "a known island is updated even when the board is full" do
    for n <- 1..64, do: Board.put("id#{n}", :vitals, %{"island" => "i#{n}"})
    Board.put("id1", :vitals, %{"island" => "i1", "roster" => 42})

    assert Dronex.fact(Board.island("id1"), :vitals)["roster"] == 42
  end

  # ⚠ WITHOUT THIS A DEAD ISLAND IS INVISIBLE. The board keeps the last fact
  # forever, so an island whose trainer stopped goes on showing its final bout.
  test "quiet_for reports how long an island has been silent" do
    Board.put("aaa", :vitals, %{"island" => "beam01"})
    assert Board.quiet_for(Board.island("aaa")) >= 0
    assert Board.quiet_for(nil) == nil
  end

  # Four states, each wanting a different response from whoever is reading.
  # Collapsing any two sends the reader to look in the wrong place.
  test "an unconfigured site says so rather than looking broken" do
    assert Dronex.state() == :unconfigured
    refute Dronex.configured?()
  end

  # ⚠ THE CONTRACT IS THE FACT, NOT THE ISLAND'S CODE. This app must never gain a
  # dependency on an engine: that is what the removed Robo Rumble page did, and
  # the site and the service ended up pinned to commits that drifted apart with
  # nothing comparing them.
  #
  # ⚠⚠ IT READS THIS APP'S OWN DECLARED DEPS, NOT THE UMBRELLA'S. The first
  # version used `Mix.Project.deps_apps/0`, which returns everything the umbrella
  # resolved, and `faber_tweann` is legitimately in there for the adaptation
  # workbench, which runs its own simulation and is allowed to. The question is
  # not what the umbrella contains; it is what THIS app asked for.
  test "the spectator declares no engine of its own" do
    declared =
      Dronex.MixProject.project()
      |> Keyword.get(:deps, [])
      |> Enum.map(&elem(&1, 0))

    assert declared == [:macula, :beam_campus, :phoenix_pubsub]
    refute :faber_tweann in declared
  end

  # ── The frames, and why they are not in the board ───────────────
  #
  # ⚠ THESE GUARD THE BUG THAT KILLED THE SITE. Recordings were kept inside the
  # rows, one is 1.2 MB, the cap allowed 64 of them, and every reader copied the
  # whole table with `:ets.tab2list/1` — six to eight times per redraw, twice a
  # second, per viewer. A 1.9 GB box ran a BEAM that wanted 6.9 GB and the kernel
  # shot it, about twelve times a day.
  #
  # The first assertion below fails on the old code by roughly two orders of
  # magnitude, which is the whole point of writing it as a size and not as a
  # shape: a test that only checked `Map.has_key?(row, "frames")` would pass the
  # day somebody put the mass back under another name.

  defp board_bytes, do: :ets.info(:dronex_board, :memory) * :erlang.system_info(:wordsize)

  test "a recording's frames never enter the board table" do
    Board.put_raid("r1", :raid, %{
      "island_id" => "aaa",
      "raid_id" => "r1",
      "winner" => "attacker",
      "frames" => recording(2_000)
    })

    assert board_bytes() < 50_000,
           "the board holds #{board_bytes()} bytes — the frames are back in the row"

    assert :ets.info(:dronex_recordings, :size) == 1
  end

  test "the row keeps the frame count, so a reader can say how long it was" do
    Board.put_raid("r1", :raid, %{"raid_id" => "r1", "frames" => recording(37)})

    [fact | _] = Board.raids() |> List.first() |> Map.fetch!(:parts) |> Map.fetch!(:raid)

    assert fact["frame_count"] == 37
    refute Map.has_key?(fact, "frames")
  end

  test "a bout's frames are split off too, under the key the ranking hands out" do
    Board.put("aaa", :bout, %{"island" => "beam01", "frames" => recording(12)})

    assert {:ok, frames} = Dronex.recording({:bout, "aaa"})
    assert length(frames) == 12
  end

  test "a recording round-trips under its raid key" do
    Board.put_raid("r1", :raid, %{"raid_id" => "r1", "frames" => recording(9)})

    assert {:ok, frames} = Dronex.recording({:raid, "r1"})
    assert length(frames) == 9
  end

  # `:gone` is a real answer, not an error. The page draws it as "no longer
  # held" rather than as an empty canvas, which would read as a broken page.
  test "a recording that was never held answers gone" do
    assert Dronex.recording({:raid, "never"}) == :gone
  end

  test "a raid dropped from the board takes its recording with it" do
    for n <- 1..65 do
      Board.put_raid("r#{n}", :raid, %{"raid_id" => "r#{n}", "frames" => recording(5)})
      Process.sleep(1)
    end

    assert length(Board.raids()) == 64
    assert Dronex.recording({:raid, "r1"}) == :gone
    assert {:ok, _still_here} = Dronex.recording({:raid, "r65"})
  end

  # ⚠ ONE RAID IS TWO COMMITMENTS AND ONE RECORDING. The list they append to had
  # no bound, inside a table whose ROW count was capped and whose row SIZE was
  # not, so a republishing island could grow one row without limit.
  test "the parts of a raid are capped" do
    for n <- 1..20,
        do: Board.put_raid("r1", :committed, %{"raid_id" => "r1", "role" => "attacker#{n}"})

    parts = Board.raids() |> List.first() |> Map.fetch!(:parts) |> Map.fetch!(:committed)

    assert length(parts) == 4
    assert List.first(parts)["role"] == "attacker20"
  end

  # A recording far larger than any real one is a publisher fault or a stranger.
  # The fact is still filed — the scoreline is worth having — and only the mass
  # is refused.
  test "an absurd recording is refused while its fact is kept" do
    Board.put_raid("r1", :raid, %{"raid_id" => "r1", "winner" => "draw", "frames" => recording(4_000)})

    assert Dronex.recording({:raid, "r1"}) == :gone
    assert [fact | _] = Board.raids() |> List.first() |> Map.fetch!(:parts) |> Map.fetch!(:raid)
    assert fact["winner"] == "draw"
  end

  # ── Listed and drawable are the same list ───────────────────────
  #
  # ⚠ THESE GUARD A BUG I SHIPPED FIXING THE LAST ONE. The row cap and the
  # recording byte budget were set independently, and they disagreed: measured on
  # the box with five islands raiding, the page ranked 69 fights and held 29
  # recordings, so 40 of them drew nothing and whichever unplayable one scored
  # highest became the default view. A blank canvas reads as a broken site.

  test "a fight whose recording is gone is not offered as watchable" do
    Board.put_raid("r1", :raid, %{"raid_id" => "r1", "island_id" => "aaa", "frames" => recording(8)})
    assert length(Dronex.watchable()) == 1

    :ets.delete(:dronex_recordings, {:raid, "r1"})

    assert Dronex.watchable() == [],
           "a fight the site cannot draw is still being offered as one it can"
  end

  test "latest_fight never answers a fight it cannot draw" do
    Board.put_raid("r1", :raid, %{"raid_id" => "r1", "island_id" => "aaa", "frames" => recording(8)})
    :ets.delete(:dronex_recordings, {:raid, "r1"})

    Board.put("aaa", :bout, %{"island" => "beam01", "frames" => recording(5)})

    entry = Dronex.latest_fight()
    assert entry.kind == :bout, "fell back to a raid whose frames are gone"
    assert {:ok, _} = Dronex.recording(entry.key)
  end

  # ⚠ THE CHEAP QUESTION MUST STAY CHEAP. `recording/1` copies ~1.6 MB, so asking
  # it 69 times to filter a ranked list would copy a hundred megabytes — the
  # exact shape of the bug that OOM-killed the site.
  test "holds? answers without copying, and agrees with recording" do
    Board.put_raid("r1", :raid, %{"raid_id" => "r1", "frames" => recording(6)})

    assert Dronex.holds?({:raid, "r1"})
    refute Dronex.holds?({:raid, "nope"})
    assert match?({:ok, _}, Dronex.recording({:raid, "r1"}))
    assert Dronex.recording({:raid, "nope"}) == :gone
  end

  # ⚠ THE TWO CAPS ARE COUPLED AND WERE SET APART. A board that lists N fights
  # must be able to hold N recordings, or "listed" and "drawable" drift until the
  # second is a minority of the first.
  test "the recording budget can hold a full board" do
    measured_recording_bytes = 1_600_000
    max_raids = 64

    assert Board.max_raids() == max_raids

    assert Board.budget_bytes() >= max_raids * measured_recording_bytes,
           "budget #{Board.budget_bytes()} cannot hold #{max_raids} recordings " <>
             "of #{measured_recording_bytes} — listed and drawable will drift apart"
  end

  # ⚠ ONE SHAPE FOR "A FIGHT". `latest_fight/0` used to answer a bare
  # `{kind, fact}`, which dropped the key the page needs to fetch the frames.
  test "latest_fight answers a ranking entry carrying its key" do
    Board.put_raid("r1", :raid, %{
      "raid_id" => "r1",
      "island_id" => "aaa",
      "frames" => recording(6)
    })

    entry = Dronex.latest_fight()

    assert entry.key == {:raid, "r1"}
    assert entry.kind == :raid
    assert {:ok, _frames} = Dronex.recording(entry.key)
  end
end
