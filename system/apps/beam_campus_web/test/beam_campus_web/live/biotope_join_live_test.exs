defmodule BeamCampusWeb.BiotopeJoinLiveTest do
  @moduledoc """
  The page that tells a stranger how to run an island.

  Two claims on it are the kind that rot: that migrants are not built yet, and
  that a station name is not a place. Both are true today and both would be
  quietly wrong later if nothing watched them.
  """
  use BeamCampusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "gives a runnable command with the public realm", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/research/workbench/biotope/join")

    assert html =~ "docker run"
    assert html =~ "HECATE_BIOTOPE_REALM"
    assert html =~ "ghcr.io/hecate-services/hecate-biotope"
    assert html =~ "7f73d3d9361bb16d4bed2812428ea6e6257a6f50c9de7ac8c581665dc0d01171"
  end

  # NOT YET BUILT, and the page must keep saying so. Implying a mesh that
  # already trades populations would be the one dishonest thing here.
  test "says invasion is opt-in and not built" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    assert html =~ "not built yet"
  end

  # A station name is an identity, never a location.
  test "offers stations without claiming they are places" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    assert html =~ "station-fi-helsinki.macula.io"
    assert html =~ "not locations"
    refute html =~ "Finland"
    refute html =~ "Germany"
  end

  # THE DOORS ARE NOT FREE, and the page should say what the two ways to help
  # are rather than only asking for a node. A station carries other people's
  # islands, which is the part that costs money every month.
  test "names both ways to support it" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    assert html =~ "macula.io"
    assert html =~ "coffee"
    assert html =~ "cost real money"
  end

  # WITHOUT THIS THE CONTAINER STARTS, LOOKS HEALTHY AND REACHES NOTHING. The
  # stations are IPv6 only and Docker's default bridge has no IPv6.
  # ASSERTED INSIDE THE COMMAND, not anywhere on the page. The first version of
  # this checked `html =~ "--network host"` and passed while the flag was missing
  # from the command entirely, because the paragraph explaining the flag
  # satisfied it. A silent edit failure and a test that could not see it.
  test "the runnable command actually carries host networking" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    assert command(html) =~ "--network host"
    assert html =~ "IPv6"
  end

  # And the command has to be one runnable thing: every line but the last
  # continued, and nothing lost to HEEx.
  test "the command is a single runnable invocation" do
    # ⚠ `String.split(trim: true)` DROPS EMPTY STRINGS AND NOT BLANK ONES, so the
    # indentation left after the closing `</code>` survived as a line of six
    # spaces and became `List.last/1`. The test then asserted the command's last
    # line was the image and was comparing against whitespace. A selector that
    # matches something, just not the thing.
    lines =
      command(html_of())
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    assert hd(lines) =~ "docker run"
    assert List.last(lines) =~ "ghcr.io/hecate-services/hecate-biotope"

    for line <- Enum.drop(lines, -1) do
      assert String.ends_with?(String.trim_trailing(line), "\\"),
             "continuation missing on: #{line}"
    end
  end

  defp html_of do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")
    html
  end

  # THE PRE BLOCK ONLY, matched as `<pre …><code>`. Splitting on bare `<code>`
  # caught the first inline one in the prose instead, which is the same mistake
  # in a smaller place: a selector that matches something, just not the thing.
  defp command(html) do
    [[_, block]] = Regex.scan(~r{<pre[^>]*><code>(.*?)</code></pre>}s, html)
    block |> String.replace("&amp;", "&") |> String.replace("&quot;", "\"")
  end

  test "offers every station that answered when last dialled" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    for host <- ~w(helsinki frankfurt nuremberg falkenstein paris milan stockholm) do
      assert html =~ "station-" <> String.slice(host, 0, 3) or html =~ host
    end
  end

  # THE PAGE ONCE SAID "no inbound ports" AND THAT WAS FALSE: the container binds
  # a health endpoint on 8483, and with --network host that lands on the reader's
  # own machine. Saying outbound-only about the MESH is true; saying it about the
  # container was not, and a reassurance that is not true is worse than none.
  test "does not claim there are no inbound ports" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    refute html =~ "No inbound ports"
    refute html =~ "no inbound ports"
  end

  test "says what it listens on and how to turn it off" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope/join")

    assert html =~ "outbound only"
    assert html =~ "8483"
    assert html =~ "HECATE_HEALTH_PORT"
  end

  test "the overview links to it" do
    {:ok, _live, html} = live(build_conn(), ~p"/research/workbench/biotope")

    assert html =~ "/research/workbench/biotope/join"
  end
end
