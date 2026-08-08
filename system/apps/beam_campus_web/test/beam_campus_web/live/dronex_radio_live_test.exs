defmodule BeamCampusWeb.DronexRadioLiveTest do
  @moduledoc """
  The ablation view: the only causal instrument this track owns.

  ⚠ **ITS OWN FILE BECAUSE IT IS ITS OWN ROUTE.** These five moved here whole
  from `DronexLiveTest` when `/dronex` became four pages. Only the URL changed;
  every assertion is the one that was there, because a refactor that quietly
  weakens a test is how a refactor loses a feature.
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

  # ⚠ THE ONLY CAUSAL NUMBER ON THE WIRE. Every other figure on this page is an
  # observation; this is an experiment — the same genome against the same
  # opponents with one channel silenced — so it is the only one immune to the
  # hardware differences between these machines.

  defp with_ablation(id, name, extra) do
    Board.put(
      id,
      :vitals,
      Map.merge(
        %{
          "island" => name,
          "island_id" => id,
          "ablations" => 12,
          "ablation_void" => false,
          "signal_volume" => 500,
          "signal_entropy" => 1200,
          "ablation_delta_air" => 0,
          "ablation_delta_ground" => 0,
          "ablation_delta_all" => 0
        },
        extra
      )
    )
  end

  test "the sign convention is stated, because a reader cannot guess it", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_delta_air" => 25})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/radio")

    assert html =~ "Does the radio matter"
    assert html =~ "+ means the swarm got worse without it"
    # ⚠ ONE READING IS ONE EXERCISE, AND THE CELL SAYS SO. It used to print the
    # value alone, which invited a single ±25 exercise to be read as a state.
    assert html =~ "1 exercises, too few to say"
    assert html =~ "n1"
  end

  # ⚠ VOID IS NOT ZERO. Nothing was transmitted, so there is no measurement — and
  # three empty bars would read as "the channel does not matter", which is the
  # one thing this cannot say.
  test "a void measurement is drawn as unmeasurable, never as zero", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_void" => true, "signal_volume" => 0})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/radio")

    assert html =~ "nothing transmitted · not measurable"
    refute html =~ "points of attacker score"
  end

  # ⚠ SCALED TO THE FULL RANGE, NEVER TO THE DATA. The score is a percentage, so
  # ±100 is the honest half-width; fitting the axis to the ±25 actually observed
  # would draw one fight changing hands as a full bar.
  # ⚠ SCALED TO THE POSSIBLE RANGE, NEVER TO THE OBSERVED ONE. The score is a
  # percentage, so ±100 is the honest half-width. Fitting the track to the ±25
  # actually seen would draw one fight changing hands as the full width, which is
  # the single most flattering lie this panel could tell.
  #
  # The spread renderer places by position rather than by width now, so the same
  # property is asserted on where the mark sits: 25 of ±100 is an eighth right of
  # centre, at 62.5%, not hard against the end.
  test "a reading is placed against the possible range, not the observed one", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_delta_air" => 25})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/radio")

    assert html =~ "left: 62.5%"
    refute html =~ "left: 100.0%"
  end

  # The panel must say the resolution out loud: one fight changing hands moves
  # this a whole step, and the run count is exercises run, not samples averaged.
  test "the coarse resolution is stated rather than left to the bar", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_delta_all" => -25})

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/radio")

    assert html =~ "one fight changing hands is a whole\nstep" or html =~ "changing hands"
    # The caption now says the sharper version of the same thing: a dot is an
    # exercise, not a sample, and the wire republishes one until the next runs.
    assert html =~ "Each dot is one exercise, not one sample"
  end

  # ⚠ ONE READING CANNOT TELL SIGNAL FROM ONE FIGHT CHANGING HANDS. What can is
  # the SHAPE of many, so the cell becomes a spread once readings accumulate —
  # every one drawn rather than summarised, because whether they AGREE is the
  # thing worth seeing.
  #
  # ⚠⚠ AND IT COUNTS MEASUREMENTS, NOT SAMPLES. The wire republishes one exercise
  # until the next runs and the board samples every 30s, so the panel was drawing
  # 240 dots off three measurements: a cloud whose weight came from the sampling
  # rate. The three points below are 25, 0, 25 in time order, which is THREE
  # exercises because the repeat is not consecutive.
  test "the comms cell becomes a spread once readings accumulate", %{conn: conn} do
    with_ablation("aaa", "beam00", %{"ablation_delta_air" => 25})

    # Reach past the sampler's throttle: it takes one point per 30s and this
    # would otherwise need a test that sleeps.
    [{_id, [p]}] = :ets.lookup(:dronex_history, "aaa")

    :ets.insert(
      :dronex_history,
      {"aaa",
       [%{p | air: 25}, %{p | air: 0, at: p.at - 60_000}, %{p | air: 25, at: p.at - 90_000}]}
    )

    {:ok, _view, html} = live(conn, ~p"/research/workbench/dronex/radio")

    # Three exercises, and the panel refuses to conclude on that many.
    assert html =~ "3 exercises, too few to say"
    assert html =~ "n3"
  end
end
