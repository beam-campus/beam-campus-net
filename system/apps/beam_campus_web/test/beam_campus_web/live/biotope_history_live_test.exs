defmodule BeamCampusWeb.BiotopeHistoryLiveTest do
  use BeamCampusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BeamCampus.Repo
  alias Biotope.RecordHistory.Sample

  # NO SANDBOX SETUP HERE. ConnCase already calls
  # `BeamCampus.DataCase.setup_sandbox/1`, which starts a shared owner for a
  # non-async case. Checking out a second connection on top of that is not an
  # error and does not raise: the inserts simply land on one connection and the
  # LiveView reads from the other, so the page renders its empty state while the
  # rows sit there. Two of these tests failed exactly that way.
  defp sample(island, tick, population) do
    Repo.insert!(
      Sample.changeset(%{
        "island" => island,
        "tick" => tick,
        "population" => population,
        "plants" => 100,
        "energy_total" => 5000,
        "born" => 200,
        "starved" => 150,
        "aged_out" => 3,
        "eaten" => 800
      })
    )
  end

  # An empty page must say which kind of empty it is. "Nothing is happening" and
  # "nothing is being received" need different responses from whoever is reading.
  test "says nothing has been recorded yet", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/history")

    assert html =~ "Biotope history"
    assert html =~ "No history recorded yet"
  end

  test "draws a series per island", %{conn: conn} do
    sample("beam01", 100, 40)
    sample("beam01", 200, 75)
    sample("beam02", 50, 12)

    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/history")

    assert html =~ "beam01"
    assert html =~ "beam02"
    assert html =~ "<polyline"
    # The window is described by the world's own clock, not this node's.
    assert html =~ "ticks 100 to 200"
    # The legend reports the latest sample, not the first.
    assert html =~ "75"
  end

  test "links back to the live islands", %{conn: conn} do
    sample("beam01", 1, 40)
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/history")
    assert html =~ "/research/workbench/biotope"
  end

  # A single sample is a real state right after an island is first heard from,
  # and the polyline maths divides by (n - 1).
  test "survives an island with exactly one sample", %{conn: conn} do
    sample("beam03", 7, 40)
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/history")
    assert html =~ "beam03"
    assert html =~ "ticks 7 to 7"
  end
end
