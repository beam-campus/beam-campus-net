defmodule BeamCampusWeb.BiotopeIslandLiveTest do
  @moduledoc """
  One island in detail: the last frame, the numbers, the rules, and the curve.
  """
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Biotope.WatchIslands.Board

  setup do
    if :ets.info(:biotope_board) == :undefined, do: Board.init()
    :ets.delete_all_objects(:biotope_board)
    :ok
  end

  defp stats(overrides \\ %{}) do
    Map.merge(
      %{
        "island" => "beam01",
        "tick" => 412,
        "population" => 78,
        "plants" => 100,
        "energy_total" => 5882,
        "born" => 249,
        "starved" => 171,
        "aged_out" => 3,
        "births_refused" => 0,
        "ticks_per_second" => 2,
        "econ_id" => "17b90de41d26da0e",
        "econ" => %{"metabolism" => 1, "regrowth_per_tick" => 4}
      },
      overrides
    )
  end

  test "draws the island and its numbers", %{conn: conn} do
    Board.put_stats(stats())

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 20,
      "stride" => 2,
      "creatures" => [0, 0, 1, -1],
      "plants" => [2, 0]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "beam01"
    assert html =~ "78"
    assert html =~ "<svg"
    assert html =~ "#F2B142"
  end

  # TWO ISLANDS SHARING A FINGERPRINT ARE COMPARABLE; two that do not are
  # different games. Showing it is what stops someone reading two population
  # curves against each other and turning a configuration difference into a
  # finding about ecology.
  test "shows which rules the island runs", %{conn: conn} do
    Board.put_stats(stats())
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "17b90de41d26da0e"
    assert html =~ "regrowth_per_tick"
  end

  # A non-zero refusal count means the population is sitting on a safety valve
  # rather than at a natural ceiling, and a page that does not say so is showing
  # a stable-looking number that means something else entirely.
  test "warns when births are being refused", %{conn: conn} do
    Board.put_stats(stats(%{"births_refused" => 137}))
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "137"
    # Not "safety cap": the formatter wraps that phrase across a line, and an
    # assertion on text the renderer is free to reflow is a brittle one.
    assert html =~ "births refused"
  end

  # NOTHING HERE INVENTS A WORLD. An island nobody has heard from is a real
  # state, and the honest response is to say so rather than draw an empty disc
  # that reads as an island where everything died.
  test "says so for an island it has never heard from", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/nowhere")

    assert html =~ "nowhere"
    assert html =~ "Nothing has arrived from an island by this name"
    refute html =~ "<svg"
  end

  test "links back to all the islands", %{conn: conn} do
    Board.put_stats(stats())
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")
    assert html =~ ~s|href="/research/workbench/biotope"|
  end

  test "renders inside the site layout", %{conn: conn} do
    Board.put_stats(stats())
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")
    assert html =~ "Robo Rumble"
  end

  # AN EXTINCT ISLAND PUBLISHES PERFECTLY WELL: plants regrow, the tick advances,
  # every fact arrives on time. Without naming it the page shows a healthy-looking
  # island whose only tell is a population of zero.
  test "names an extinct island rather than showing it as live", %{conn: conn} do
    Board.put_stats(stats(%{"population" => 0, "extinct_at" => 4213}))
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "extinct at tick 4213"
    refute html =~ ">live<"
  end
end
