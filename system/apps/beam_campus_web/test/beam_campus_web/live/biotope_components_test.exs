defmodule BeamCampusWeb.BiotopeComponentsTest do
  @moduledoc """
  The drawing, checked on its arithmetic rather than on how it looks.

  These charts replaced a pair that drew two quantities on one canvas with no
  axis at all, each scaled to its own invisible maximum. A population of 900 and
  a population of 9 drew identically, and nothing here could have caught that
  because nothing here was tested. The claims worth pinning are the ones a
  reader relies on without being able to check: that zero is on the axis, that a
  gap in the data is a gap in the line, and that a quantity an island does not
  publish is never drawn as nothing.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias BeamCampusWeb.BiotopeComponents

  defp samples(overrides \\ %{}) do
    for i <- 0..20 do
      Map.merge(
        %{
          tick: i * 50,
          population: 100 + i,
          ground_total: 400_000,
          dissipated: i * 1_000_000,
          depth: i,
          from_creatures_pct: 30,
          sensor_mean: 22
        },
        overrides
      )
    end
  end

  defp plot(samples, get, opts \\ []) do
    assigns = %{samples: samples, get: get, opts: opts}

    render_component(
      fn assigns ->
        ~H"""
        <BiotopeComponents.plot
          samples={@samples}
          get={@get}
          label={Keyword.get(@opts, :label, "thing")}
        />
        """
      end,
      assigns
    )
  end

  # HEEX indents an interpolated tag body onto its own line, so matching on the
  # raw string finds the inline x labels and misses the y ones. Pulling the text
  # out and trimming it is the difference between asserting on the axis and
  # asserting on whitespace: the first version of this file passed its
  # zero-on-the-axis test by matching an x tick that happened to read "0".
  defp labels(html) do
    Regex.scan(~r|<text[^>]*>(.*?)</text>|s, html)
    |> Enum.map(fn [_, body] -> String.trim(body) end)
  end

  describe "the y axis" do
    test "starts at zero, so a wobble is not drawn as a mountain range" do
      # Population runs 100 to 120. Cropped to its own range that reads as a
      # crash and a boom; against zero it reads as the flat line it is.
      assert "0" in labels(plot(samples(), & &1.population))
    end

    test "tops out at a round number above the data rather than at the data" do
      found = labels(plot(samples(), & &1.population))

      assert "200" in found
      refute "120" in found
    end

    test "keeps a fractional scale fractional" do
      # Sensors per creature runs at 0.22. Rounding the top to a whole number
      # would put the ceiling at 1 and flatten the only line on the chart.
      assert "0.25" in labels(plot(samples(), fn s -> s.sensor_mean / 100 end))
    end

    test "abbreviates a scale that runs to millions" do
      found = labels(plot(samples(), & &1.dissipated))

      assert "20.0M" in found
      refute "20000000" in found
    end
  end

  describe "a gap in what an island reported" do
    test "breaks the line instead of being joined across" do
      # An island mid-rollout: fact version 4 for the first half of the window,
      # version 5 after, so the entropy column is empty and then present.
      partial =
        samples()
        |> Enum.with_index()
        |> Enum.map(fn {s, i} -> if i in 5..9, do: %{s | dissipated: nil}, else: s end)

      [_, path] = Regex.run(~r/<path d="([^"]*)"/, plot(partial, & &1.dissipated))

      assert length(String.split(path, "M")) - 1 == 2,
             "two reported stretches must draw as two strokes, not one line through the hole"
    end

    test "says so, rather than drawing a quantity the island never sent as zero" do
      html = plot(samples(%{dissipated: nil}), & &1.dissipated)

      assert html =~ "does not publish it yet"
      refute html =~ "<path"
    end
  end

  describe "comparing islands" do
    defp compare(shared) do
      big = Enum.map(samples(), &%{&1 | population: &1.population * 10})

      render_component(
        fn assigns ->
          ~H"""
          <BiotopeComponents.compare
            series={@series}
            get={& &1.population}
            label="creatures"
            shared={@shared}
          />
          """
        end,
        %{series: [{"beam01", samples()}, {"beam02", big}], shared: shared}
      )
    end

    # THE WHOLE POINT OF A FLEET PAGE. Left to itself every plot rounds up to its
    # own ceiling, so an island of 1,200 and an island of 120 draw the identical
    # picture and putting them side by side changes nothing. Divergence between
    # seeds is the fleet's pre-registered question and it is only visible when the
    # axis is the same.
    test "puts every island on one ceiling, so their heights mean something" do
      tops =
        Regex.scan(~r/aria-label="beam\d+: [\d.]+ to ([\d.]+) /, compare(true))
        |> Enum.map(&List.last/1)

      assert length(tops) == 2
      assert Enum.uniq(tops) == ["2000"], "the taller island sets the ceiling for both"
    end

    # TWO ISLANDS WITH DIFFERENT RULES ARE PLAYING DIFFERENT GAMES, and a shared
    # axis is an invitation to read one against the other. When the fingerprints
    # disagree the invitation is withdrawn.
    test "gives each island its own ceiling when they are not comparable" do
      tops =
        Regex.scan(~r/aria-label="beam\d+: [\d.]+ to ([\d.]+) /, compare(false))
        |> Enum.map(&List.last/1)

      assert Enum.uniq(tops) == ["200", "2000"]
    end

    # THE HOOK THAT KEEPS A PANE OPEN IS KEYED ON THE ID, so two panels sharing
    # one would toggle together and a duplicate id is invalid markup besides.
    # Every panel on the fleet page is labelled with its island and the measure
    # is the row, so the id has to carry both.
    test "gives every panel a distinct id for its disclosure" do
      ids = Regex.scan(~r/id="(vals-[^"]*)"/, compare(true)) |> Enum.map(&List.last/1)

      assert length(ids) == 2
      assert Enum.uniq(ids) == ids
      assert Enum.all?(ids, &String.contains?(&1, "creatures"))
    end
  end

  describe "the disc" do
    test "sizes a creature by its body and not by what it is carrying" do
      # Contests are decided on structure alone, so a fat small creature must
      # draw smaller than a lean large one. Same store, opposite bodies.
      chart = %{
        "radius" => 2,
        "creatures" => [0, 0, 1, 1],
        "structures" => [2500, 25],
        "energies" => [25, 2500],
        "uptakes" => [0, 0],
        "ground" => [],
        "scent" => []
      }

      html =
        render_component(
          fn assigns ->
            ~H"""
            <BiotopeComponents.disc id="d" chart={@chart} size={200} />
            """
          end,
          %{chart: chart}
        )

      # THE BOARD IS A CANVAS, so this reads the numbers the server packed rather
      # than parsing markup: exactly the values the browser is given, with no
      # rendering in between to agree or disagree with. Four per creature:
      # x, y, radius, colour.
      [_, json] = Regex.run(~r/data-creatures="([^"]*)"/, html)
      # Five per creature: id, x, y, radius, colour. The id is what lets a
      # viewer animate between frames rather than redraw them.
      [_id1, _x1, _y1, big, _c1, _id2, _x2, _y2, small, _c2] = Jason.decode!(json)

      assert big > small, "the creature with the larger BODY must draw larger"
    end

    # 5,781 svg circles were 85% of a 711 KB page and were rebuilt on every fact.
    # Nothing was wrong with LiveView's diffing: on a board where every mark moves
    # every tick almost nothing is unchanged, so the diff was nearly the whole
    # page. Markup is simply the wrong carrier for a particle field.
    test "carries the board as numbers rather than as markup" do
      chart = %{
        "radius" => 2,
        "creatures" => [0, 0],
        "structures" => [100],
        "uptakes" => [10],
        "ground" => [0, 0, 40, 1, 0, 900],
        "scent" => [0, 0, 20]
      }

      html =
        render_component(
          fn assigns ->
            ~H"""
            <BiotopeComponents.disc id="d" chart={@chart} size={200} />
            """
          end,
          %{chart: chart}
        )

      refute html =~ "<circle"
      assert html =~ "<canvas"

      pull = fn key ->
        [_, json] = Regex.run(~r/data-#{key}="([^"]*)"/, html)
        Jason.decode!(json)
      end

      # Ground is x, y, colour, alpha per cell, and a cell above the ceiling is a
      # grave: rose rather than green, because only a corpse can carry a cell
      # that high.
      [_x, _y, ordinary, _a, _x2, _y2, grave, _a2] = pull.("ground")
      assert ordinary == 0x2F7D52
      assert grave == 0xC2557A

      # Every packed value is an integer. A float would cost more to carry than
      # the precision is worth on a canvas drawing to whole pixels.
      assert Enum.all?(pull.("creatures") ++ pull.("trails"), &is_integer/1)
    end

    # A MARK HAS TO BE RECOGNISABLE ACROSS TWO FRAMES or it cannot be animated,
    # only redrawn. Births and deaths reshuffle the list every tick and the mean
    # creature lives about two of them, so matching by position would slide marks
    # across the board that never moved.
    test "carries who each creature is, so a frame can be animated from the last" do
      chart = %{
        "radius" => 2,
        "creatures" => [0, 0, 1, 1],
        "ids" => [17, 4001],
        "structures" => [100, 100],
        "uptakes" => [10, 10],
        "ground" => [],
        "scent" => []
      }

      html =
        render_component(
          fn assigns ->
            ~H"""
            <BiotopeComponents.disc id="d" chart={@chart} size={200} />
            """
          end,
          %{chart: chart}
        )

      [_, json] = Regex.run(~r/data-creatures="([^"]*)"/, html)
      [first | _] = Jason.decode!(json)
      assert first == 17
      assert Enum.at(Jason.decode!(json), 5) == 4001
    end
  end

  # Which station an island reaches the mesh through.
  describe "door" do
    defp door_html(stats) do
      assigns = %{stats: stats}

      rendered_to_string(~H"""
      <BiotopeComponents.door stats={@stats} />
      """)
    end

    test "names the station and marks the link up" do
      html =
        door_html(%{
          "station_host" => "station-fi-helsinki.macula.io",
          "station_connected" => true,
          "station_id" => "aa11bb22cc33dd44ee55"
        })

      assert html =~ "station-fi-helsinki"
      assert html =~ "bg-success"
      assert html =~ "connected"
    end

    # THE ZONE IS DROPPED, THE NAME IS NOT TRANSLATED. Every station shares
    # `.macula.io`, so it carries no information; the rest is the identity and
    # must survive intact. A renderer that turned `station-de-frankfurt` into
    # "Frankfurt" would be asserting a country, and that exact name spent a long
    # time pointing at a box in another one.
    test "shortens the zone and invents no place" do
      html =
        door_html(%{
          "station_host" => "station-de-frankfurt.macula.io",
          "station_connected" => true,
          "station_id" => "ff"
        })

      assert html =~ "station-de-frankfurt"
      refute html =~ "macula.io"
      refute html =~ "Frankfurt,"
      refute html =~ "Germany"
    end

    # A DOWN LINK IS THE INTERESTING CASE and must be shown, not hidden. An
    # island dialling a station that is not answering is exactly what a reader
    # wants to see, and a renderer that only draws healthy links would make an
    # outage look like a page that had not loaded.
    test "shows a station that is not answering" do
      html =
        door_html(%{
          "station_host" => "station-de-nuremberg.macula.io",
          "station_connected" => false,
          "station_id" => "ff"
        })

      assert html =~ "station-de-nuremberg"
      assert html =~ "bg-error"
      assert html =~ "not connected"
    end

    # ABSENT IS NOT DOWN, and this is the distinction the whole shape exists to
    # keep. An island that cannot read its own link publishes no door at all, and
    # an island on a fact version older than 9 does the same. Both mean "cannot
    # see", not "nobody answered", and drawing either as a red dot would count a
    # rollout as an outage.
    test "an island that publishes no door is blank rather than broken" do
      for stats <- [nil, %{}, %{"population" => 12}] do
        html = door_html(stats)

        refute html =~ "bg-error"
        refute html =~ "bg-success"
        assert html =~ "–"
      end
    end
  end
end
