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
            <BiotopeComponents.disc chart={@chart} size={200} />
            """
          end,
          %{chart: chart}
        )

      radii =
        Regex.scan(~r/<circle[^>]*\sr="([\d.]+)"/, html)
        |> Enum.map(fn [_, r] -> String.to_float(r) end)

      [big, small] = Enum.take(radii, 2)
      assert big > small, "the creature with the larger BODY must draw larger"
    end
  end
end
