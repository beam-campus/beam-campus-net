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
        "consumed" => 4321,
        "plants_eaten" => 1200,
        "breed_at_mean" => 298,
        "from_creatures_pct" => 39,
        "sensor_mean" => 104,
        "scent_tags" => 26,
        "scent_spread" => 44,
        "sensors" => %{
          "plants" => %{"carriers" => 54, "reach" => 61},
          "creatures" => %{"carriers" => 0, "reach" => 0},
          "scent" => %{"carriers" => 0, "reach" => 0}
        },
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

  # THE NUMBERS THIS WORLD IS ACTUALLY ABOUT. Predation is most of the energy
  # here and perception is being selected out, and neither was visible on the
  # page until the island started publishing them.
  test "shows what the population turned out to be", %{conn: conn} do
    Board.put_stats(stats())

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "energy from creatures"
    assert html =~ "39%"
    assert html =~ "what they measure"
    assert html =~ "deaths, by cause"
    assert html =~ "signatures"
  end

  # A field at zero carriers has been selected out of this island entirely, which
  # is a finding rather than a gap and must be drawn as a zero rather than
  # omitted.
  test "shows a measurement nobody carries", %{conn: conn} do
    Board.put_stats(stats())

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "creatures</dt>"
    assert html =~ "scent</dt>"
  end

  # A creature is drawn the size of its energy, because the stronger consumes the
  # weaker on contact and so energy is armour. Two creatures with very different
  # energies must not come out the same size.
  test "draws creatures at the size of their energy", %{conn: conn} do
    Board.put_stats(stats())

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 3,
      "creatures" => [0, 0, 1, 0],
      "energies" => [10, 300],
      "plants" => [],
      "scent" => []
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    radii = Regex.scan(~r/<circle[^>]*fill="#F2B142"[^>]*r="([\d.]+)"/, html)
    radii = radii ++ Regex.scan(~r/<circle[^>]*r="([\d.]+)"[^>]*fill="#F2B142"/, html)
    assert length(radii) == 2
    [a, b] = Enum.map(radii, fn [_, r] -> String.to_float(r) end)
    assert a != b
  end

  # Scent is the only thing in this world that outlives the moment it was made,
  # and it was entirely invisible until now.
  test "draws scent trails", %{conn: conn} do
    Board.put_stats(stats())

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 3,
      "creatures" => [],
      "energies" => [],
      "plants" => [],
      "scent" => [0, 0, 30, 1, 0, 10]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "#8B7CE8"
    assert html =~ "scent marks"
  end

  # An island still publishing the older chart has no energies at all. That must
  # cost accurate sizing and not the page.
  test "survives a chart with no energies", %{conn: conn} do
    Board.put_stats(stats())

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 3,
      "creatures" => [0, 0, 1, 0],
      "plants" => [],
      "scent" => []
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "#F2B142"
  end
end
