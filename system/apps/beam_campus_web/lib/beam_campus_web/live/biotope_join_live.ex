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
  @stations [
    {"station-fi-helsinki.macula.io", "the one beam00 dials"},
    {"station-de-frankfurt.macula.io", "the one beam01 dials"},
    {"station-de-nuremberg.macula.io", "the one beam03 dials"}
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
            are doing, and appears on this page beside the others. No inbound
            ports, no account, and no key from us.
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
            There is no funding, no company and nothing to buy. The most useful
            thing you can contribute is <span class="font-medium">a node</span>.
          </li>
        </ul>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide opacity-60">
          Pick a door
        </h2>
        <p class="mt-2 text-sm opacity-70">
          Every island reaches the mesh through a station. They are <span class="font-medium">identities on the mesh and not locations</span>: one of
          these spent a long while pointing at a machine in a different country
          from the one in its name. Pick any.
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
    -e HECATE_BIOTOPE_ISLAND=your-island-name \
    -e HECATE_BIOTOPE_REALM={@realm} \
    -e MACULA_STATION_SEEDS=https://station-fi-helsinki.macula.io:4433 \
    -e HECATE_BIOTOPE_TICKS_PER_SLOT=1 \
    -e HECATE_BIOTOPE_SLOT_MS=500 \
    ghcr.io/hecate-services/hecate-biotope:latest</code></pre>

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
