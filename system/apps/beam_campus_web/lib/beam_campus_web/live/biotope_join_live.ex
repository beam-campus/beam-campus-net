defmodule BeamCampusWeb.BiotopeJoinLive do
  @moduledoc """
  How to run an island of your own.

  WRITTEN AGAINST WHAT IS ACTUALLY TRUE, which is a shorter list than it looks.
  An island dials out to a station, publishes what it is doing on a public topic,
  and that is the whole of it: no inbound ports, no account, no key from us. The
  realm is the sha256 of a public name, so it needs no provisioning, and the
  macula SDK generates an ephemeral identity for a client that brings none.

  Until this week that was not true in practice: the service demanded a fleet
  realm it then discarded, so nobody outside could publish at all. Fixed, and
  worth remembering that the page describing a thing is what found the thing.

  NOTHING HERE PROMISES INVASION. Islands will eventually exchange migrants and
  they do not yet, so the page says so plainly rather than implying a mesh that
  already trades. `accepts_migrants` rides on every fact and defaults to false.

  AND NO STATION IS RENDERED AS A PLACE. `station-de-frankfurt` was for a long
  time physically the Nuremberg box, left misnamed because renaming breaks seeds,
  and it has moved again since. These are identities on a mesh.
  """
  use BeamCampusWeb, :live_view

  # The doors that resolve today, verified rather than remembered. Each is a
  # distinct network: an island picks one and the spectator receives it either
  # way, because routing is the mesh's job and not the reader's.
  # ALL SEVEN VERIFIED BY DIALLING THEM, not by resolving them. Each completed a
  # signed HELLO and returned a distinct key, which is the only thing that proves
  # a station is really there. `macula-demo/scripts/probe-stations.escript`.
  #
  # DNS alone would have listed thirty names, twenty three of which no longer
  # resolve at all: the entire Belgian parksim era plus six other cities.
  @stations [
    {"station-fi-helsinki.macula.io", "beam00 dials this one"},
    {"station-de-frankfurt.macula.io", "beam01 dials this one"},
    {"station-de-nuremberg.macula.io", "beam03 dials this one"},
    {"station-de-falkenstein.macula.io", ""},
    {"station-fr-paris.macula.io", ""},
    {"station-it-milan.macula.io", ""},
    {"station-se-stockholm.macula.io", ""}
  ]

  @realm "7f73d3d9361bb16d4bed2812428ea6e6257a6f50c9de7ac8c581665dc0d01171"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, stations: @stations, realm: @realm, page_title: "Run an island")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-3xl px-4 py-10">
        <.link navigate={~p"/research/workbench/biotope"} class="link link-hover text-sm opacity-60">
          ← All islands
        </.link>

        <.header>
          Run an island
          <:subtitle>
            One container. It dials out to a station, publishes what its creatures
            are doing, and appears on this page beside the others. No account and
            no key from us.
          </:subtitle>
        </.header>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide opacity-60">
          What you are joining
        </h2>
        <ul class="mt-3 space-y-2 text-sm opacity-80">
          <li>
            Your island publishes what it is doing to a <span class="font-medium">public topic</span>.
            Anyone can read it, including this page.
          </li>
          <li>
            What is published is about <span class="font-medium">the creatures</span>, plus
            the island name you choose and which station you dial. Not about you.
          </li>
          <li>
            Islands will eventually exchange migrants, so a population that did not
            start on your island may one day live there. <span class="font-medium">That is opt-in and it is not built yet</span>, and
            every island says whether it would accept one.
          </li>
          <li>
            It is research. <span class="font-medium">Worlds die</span>, often within
            the hour, and that is a result rather than a fault. Yours may end while
            you are watching it.
          </li>
          <li>
            There is no funding and no company. Running an island costs you a
            little electricity; <span class="font-medium">the doors cost real money</span>,
            because a station is a machine somebody rents every month so that
            islands like yours have somewhere to dial.
          </li>
        </ul>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide opacity-60">
          What it opens on your machine
        </h2>
        <p class="mt-2 text-sm opacity-70">
          <span class="font-medium">The mesh side is outbound only.</span>
          Your island dials a station and keeps that connection open. Nothing ever
          dials in, there is no port to forward, and it works from behind a
          domestic router untouched. Other islands reach yours by publishing to a
          topic you are already listening on, never by connecting to you.
        </p>
        <p class="mt-2 text-sm opacity-70">
          <span class="font-medium">
            There is one listener, and `--network host` puts it on your machine.
          </span>
          The container serves a health endpoint on TCP <code class="font-mono text-xs">8483</code>
          so that Docker can tell whether it is alive. It answers a small status
          JSON, the same thing this page could tell you, and nothing else. Move it
          with <code class="font-mono text-xs">HECATE_HEALTH_PORT</code>, or set that
          to <code class="font-mono text-xs">0</code>
          to switch the listener off entirely if you would rather have nothing
          bound at all.
        </p>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide opacity-60">
          If you want to help beyond running one
        </h2>
        <p class="mt-2 text-sm opacity-70">
          <span class="font-medium">Run a station of your own.</span>
          That is the backbone rather than the leaves: a station carries other
          people's islands as well as yours, and every one of them makes the mesh
          less dependent on the handful we pay for.
          <.link href="https://macula.io" class="link" target="_blank" rel="noopener">
            macula.io
          </.link>
          has what it takes.
        </p>
        <p class="mt-2 text-sm opacity-70">
          <span class="font-medium">Or buy us a coffee.</span>
          There is a button in the corner of every page on this site. It pays for
          the doors, which is the only line item here that is not somebody's spare
          machine.
        </p>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide opacity-60">
          Pick a door
        </h2>
        <p class="mt-2 text-sm opacity-70">
          Every island reaches the mesh through a station. They are <span class="font-medium">identities on the mesh and not locations</span>: one of
          these spent a long while pointing at a machine in a different country
          from the one in its name, and one of them carries a German city name on
          a network in another country today. Pick any: all seven answered when
          they were last dialled.
        </p>
        <div class="mt-3 overflow-x-auto">
          <table class="w-full text-sm">
            <tbody>
              <tr :for={{host, note} <- @stations} class="border-b border-base-content/5">
                <td class="py-2 pr-4 font-mono text-xs">{host}</td>
                <td class="py-2 opacity-50">{note}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide opacity-60">
          Run it
        </h2>
        <p class="mt-2 text-sm opacity-70">
          Substitute your own island name and the station you picked.
        </p>
        <pre class="mt-3 overflow-x-auto rounded-lg bg-base-300 p-4 text-xs leading-relaxed"><code>docker run -d --name biotope --restart unless-stopped \
    --network host \
    -e HECATE_BIOTOPE_ISLAND=your-island-name \
    -e HECATE_BIOTOPE_REALM={@realm} \
    -e MACULA_STATION_SEEDS=https://station-fi-helsinki.macula.io:4433 \
    -e HECATE_BIOTOPE_TICKS_PER_SLOT=1 \
    -e HECATE_BIOTOPE_SLOT_MS=500 \
    ghcr.io/hecate-services/hecate-biotope:latest</code></pre>

        <p class="mt-3 text-sm opacity-70">
          <span class="font-medium">`--network host` is not optional.</span>
          Every station is reachable over IPv6 only, and Docker's default bridge
          network has no IPv6 unless you have gone and configured it. Without this
          the container starts, looks healthy, and never reaches anything. The
          fleet's own islands run this way for the same reason.
        </p>

        <p class="mt-3 text-sm opacity-70">
          The realm above is the sha256 of <code class="font-mono text-xs">net.beamcampus.biotope</code>.
          It is public on purpose and needs no provisioning: it is a routing
          namespace, not a permission.
        </p>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide opacity-60">
          Pin a world, or take the newest
        </h2>
        <p class="mt-2 text-sm opacity-70">
          <code class="font-mono text-xs">:latest</code>
          is whatever the physics currently is, and the physics changes. Every build
          is also tagged with the world it implements, so
          <code class="font-mono text-xs">:world-14</code>
          keeps running world 14 after the rest of the fleet has moved on. An island
          publishes which world it is, so two of them disagreeing is visible rather
          than confusing.
        </p>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide opacity-60">
          What to expect
        </h2>
        <p class="mt-2 text-sm opacity-70">
          It draws a random world, runs several candidates through their founding
          phase and keeps one that survives, so it can take a minute before
          anything appears. Then it ticks about twice a second and publishes once a
          second. If your world ends, the island leaves the corpse on show for a
          while and begins another, because extinction is a result and hiding it
          would be the one dishonest thing a page like this could do.
        </p>
      </div>
    </Layouts.app>
    """
  end
end
