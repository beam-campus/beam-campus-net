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
        "ground_total" => 42_000,
        "still_pct" => 61,
        "ground_spread" => 17,
        "movers" => 70,
        "breeders" => 66,
        "hidden_mean" => 140,
        "absorbed" => 9100,
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
        "sensor_hist" => [40, 20, 10, 5, 2, 1, 0, 0, 0],
        "hidden_hist" => [70, 6, 2, 0, 0, 0, 0],
        "uptake_hist" => [3, 9, 21, 18, 12, 8, 5, 2],
        "sensors_gained" => 812,
        "sensors_lost" => 799,
        "sensors" => %{
          "ground" => %{"carriers" => 54, "reach" => 61, "attention" => 430},
          "self" => %{"carriers" => 12, "reach" => 0, "attention" => 210},
          "creatures" => %{"carriers" => 7, "reach" => 7, "attention" => 0},
          "scent" => %{"carriers" => 0, "reach" => 0, "attention" => 0}
        },
        "econ_id" => "17b90de41d26da0e",
        "econ" => %{"metabolism" => 1, "regrowth_per_tick" => 4}
      },
      overrides
    )
  end

  # THE DISC IS A CANVAS NOW, so these read the numbers the server packed rather
  # than parsing markup. That is a stronger assertion than it was: the values
  # being checked are exactly the values the browser is given, with no rendering
  # in between to agree or disagree with.
  defp packed(html, key) do
    [_, json] = Regex.run(~r/data-#{key}="([^"]*)"/, html)
    json |> String.replace("&quot;", "\"") |> Jason.decode!()
  end

  test "draws the island and its numbers", %{conn: conn} do
    Board.put_stats(stats())

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 20,
      "stride" => 2,
      "creatures" => [0, 0, 1, -1],
      "ground" => [2, 0, 400]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "beam01"
    assert html =~ "78"
    # The board is a canvas fed by packed numbers, not markup. Ground arrives as
    # x, y, colour, alpha, so a single cell is four values.
    assert html =~ "<canvas"
    assert length(packed(html, "ground")) == 4
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

  # A creature is drawn the size of its BODY. It used to be drawn the size of its
  # store, which was right until world 6 split the two: the island decides every
  # contest on structure alone, so a fat small creature loses to a lean large one.
  test "draws creatures at the size of their body", %{conn: conn} do
    Board.put_stats(stats())

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 3,
      "creatures" => [0, 0, 1, 0],
      "structures" => [10, 2500],
      "energies" => [2500, 10],
      "ground" => [],
      "scent" => []
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    # Packed as x, y, radius, colour. The stores are deliberately the opposite
    # way round: every contest here is decided on structure alone, so the lean
    # large creature must draw larger than the fat small one.
    [_id1, _x1, _y1, small, _c1, _id2, _x2, _y2, large, _c2] = packed(html, "creatures")
    assert large > small
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
      "ground" => [],
      "scent" => [0, 0, 30, 1, 0, 10]
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    # Packed as x, y, alpha in hundredths. A fresher mark is stronger, and a
    # trail is faint on purpose: at full strength it reads as a wall.
    [_x1, _y1, fresh, _x2, _y2, faded] = packed(html, "trails")
    assert fresh > faded
    assert fresh < 100
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
      "ground" => [],
      "scent" => []
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "#F2B142"
  end

  # AN ORGAN THAT EXISTS AND AN ORGAN THAT MATTERS ARE DIFFERENT THINGS. Seven
  # creatures carry a creature sensor and not one of them acts on it: it is being
  # paid for every tick and changing nothing. Carriers alone would report that as
  # perception.
  test "separates a carried measurement from an acted-on one", %{conn: conn} do
    Board.put_stats(stats())

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "4.3"
    assert html =~ "0.0"
    assert html =~ "carried and"
  end

  # A census says what the population is built from now; these say whether that
  # is still moving.
  test "shows whether body plans are still changing", %{conn: conn} do
    Board.put_stats(stats())

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "sensors gained"
    assert html =~ "812"
    assert html =~ "799"
  end

  # PALE IS GENTLE AND DEEP IS VORACIOUS, and this is a quantity rather than a
  # label. Feeding slower than the ground returns holds a cell indefinitely;
  # feeding harder strips it and forces a move, so the colour is the
  # prudent-to-greedy axis read straight off a scale.
  #
  # It replaced a signature colouring that was correct and unreadable: kin did
  # share a colour, but at the mutation rate these islands run there are no kin,
  # so it drew every creature differently and showed nothing. A name means
  # something only when there are families to name.
  test "colours creatures by how fast they feed", %{conn: conn} do
    Board.put_stats(stats())

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 3,
      "creatures" => [0, 0, 1, 0],
      "structures" => [200, 200],
      "signatures" => [0, 255],
      "uptakes" => [10, 390],
      "ground" => [],
      "scent" => []
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    # Same body, opposite feeding rates, so the only thing that may differ is
    # the colour. Pale is gentle and deep is voracious, so the greedy one is
    # darker, which as a packed 0xRRGGBB integer means smaller.
    [_id1, _x1, _y1, _r1, gentle, _id2, _x2, _y2, _r2, greedy] = packed(html, "creatures")
    assert greedy < gentle
  end

  # An island still publishing the older chart sends no signatures at all. Amber
  # is what every creature used to be, so an unlabelled one keeps that rather
  # than being given a lineage it never declared.
  test "falls back to amber when no signatures are sent", %{conn: conn} do
    Board.put_stats(stats())

    Board.put_chart(%{
      "island" => "beam01",
      "tick" => 412,
      "radius" => 3,
      "creatures" => [0, 0],
      "energies" => [200],
      "ground" => [],
      "scent" => []
    })

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "#F2B142"
  end

  # A MEAN CANNOT BE SKIMMED PAST WHEN IT IS A DISTRIBUTION. "0.01 sensors per
  # creature" reads as nearly none without saying whether that is one creature in
  # a hundred carrying one or something else, and the difference is between an
  # apparatus being selected away and one being maintained rarely.
  test "shows the shape of the population, not only its average", %{conn: conn} do
    Board.put_stats(stats())

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "sensors carried"
    assert html =~ "hidden nodes"
    assert html =~ "how fast they feed"
  end

  # EVERY CHART NAMES THE ONE QUANTITY IT DRAWS. It used to need a colour key as
  # well, because two quantities shared a canvas and only the swatches said which
  # line was which. They no longer share one: a chart holds a single series and
  # its own title names it, which is why there is no legend on any of them.
  test "names the quantity on every chart", %{conn: conn} do
    Board.put_stats(stats())

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "creatures"
    assert html =~ "energy in the ground"
    assert html =~ "energy from creatures"
    assert html =~ "sensors per creature"
    assert html =~ "burnt as heat"
  end

  # An island that has sent counts but no distribution yet must say so rather
  # than drawing an empty box that reads as a population sitting at zero.
  test "says when there is no shape to draw yet", %{conn: conn} do
    Board.put_stats(stats(%{"hidden_hist" => [], "sensor_hist" => nil}))

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/beam01")

    assert html =~ "nothing yet"
  end
end
