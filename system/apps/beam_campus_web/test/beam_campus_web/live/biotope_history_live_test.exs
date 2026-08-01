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
  # `econ_id` is fixed across the fixture on purpose: `history/2` draws only
  # samples sharing one fingerprint, because an island before and after a rules
  # change is two different games and splicing them makes a deploy look like
  # something the world did.
  defp sample(island, tick, population) do
    Repo.insert!(
      Sample.changeset(%{
        "island" => island,
        "tick" => tick,
        "econ_id" => "0badc0ffee123456",
        "population" => population,
        "energy_total" => 5000,
        "ground_total" => 42_000,
        "born" => 200,
        "starved" => 150,
        "aged_out" => 3,
        "consumed" => 800,
        "absorbed" => 1200,
        "from_creatures_pct" => 42,
        "sensor_mean" => 130,
        "still_pct" => 61,
        "ground_spread" => 17
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

  test "offers both faces and a way back up", %{conn: conn} do
    sample("beam01", 1, 40)
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/history")

    assert html =~ ~s|href="/research/workbench/biotope"|
    assert html =~ ~s|href="/research/workbench"|
    assert html =~ ~s|aria-current="page"|
  end

  # A single sample is a real state right after an island is first heard from,
  # and the polyline maths divides by (n - 1).
  test "survives an island with exactly one sample", %{conn: conn} do
    sample("beam03", 7, 40)
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/history")
    assert html =~ "beam03"
    assert html =~ "ticks 7 to 7"
  end

  # THE PAGE MUST CARRY THE SITE, not just its own content. Both biotope pages
  # shipped without `<Layouts.app>`, so they rendered with no header, no nav, no
  # theme toggle and no footer: the content looked right in a curl and the page
  # was a dead end in a browser. Asserting on a nav item that belongs to the
  # layout and not to this page is what catches that.
  test "renders inside the site layout", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/research/workbench/biotope/history")

    assert html =~ "Robo Rumble"
    assert html =~ ">Workbench<"
  end
end
