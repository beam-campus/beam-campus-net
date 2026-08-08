#!/usr/bin/env bash
# What is in the champion read model on the live box, and is `crossed?' honest?
#
# ⚠ THE ROWS WRITTEN BEFORE THE FIX DO NOT HEAL THEMSELVES. `FollowTheChampions'
# widens a reign with `on_conflict: [set: [last_seen, sorties, score]]', which
# deliberately never touches `taken_from' — a reign's origin is a fact about when
# it began, not something a later sighting may rewrite. So the five rows written
# while the islands published `champion_from => undefined' keep that string for
# ever, and keep reading as crossings, no matter how correct the new code is.
#
# That is exactly what this asks: not "does the new code work" but "what does the
# table on the box actually say", which is what the page renders.
#
# ⚠ IT ASKS THE LIVE NODE, VIA rpc AND NOT VIA eval. The eval subcommand boots a
# bare VM with the application merely LOADED, so the Repo is never started and
# every query dies with "could not lookup Ecto repo" — which reads like a broken
# database and is only a broken command.
#
# ⚠ AND THE REMOTE BODY CARRIES NO BACKTICKS. It is one double-quoted string, so
# a backtick in a comment is command substitution and the script dies at parse
# time with "unexpected EOF".
#
# Usage:  scripts/what_do_the_champions_say.sh
set -uo pipefail

BOX="${BOX:-178.105.157.209}"
KEY="${KEY:-$HOME/.ssh/id_hetzner}"
DB="${DB:-/data/beam_campus.db}"
# ⚠ THE CONTAINER IS `beam-campus-site' AND THE RELEASE IS `beam_campus'. Neither
# is the repository name, and guessing either one gives "No such container" or
# "no such file", both of which read like the box is broken when it is not.
CONTAINER="${CONTAINER:-beam-campus-site}"
RELEASE="${RELEASE:-beam_campus}"

ssh -n -i "$KEY" -o ConnectTimeout=10 -o BatchMode=yes "root@${BOX}" "
  set -u
  echo '── image'
  docker ps --format '{{.Names}}\t{{.Status}}\t{{.Image}}' | grep -i campus
  docker inspect -f '{{.Created}} {{.Config.Image}}' \$(docker ps -q --filter name=${CONTAINER}) 2>/dev/null

  echo
  echo '── every reign on disk'
  docker exec ${CONTAINER} /app/bin/${RELEASE} rpc '
    alias Dronex.FollowTheChampions.Reign
    import Ecto.Query

    rows = BeamCampus.Repo.all(from r in Reign, order_by: [asc: r.island])

    IO.puts(\"count=#{length(rows)}\")

    Enum.each(rows, fn r ->
      IO.puts(
        [
          String.pad_trailing(to_string(r.island), 22),
          String.pad_trailing(String.slice(to_string(r.genome_id), 0, 12), 14),
          \"gen=\", String.pad_trailing(to_string(r.generation), 6),
          \"score=\", String.pad_trailing(to_string(r.score), 6),
          \"taken_from=\", inspect(r.taken_from)
        ]
        |> Enum.join()
      )
    end)

    IO.puts(\"\")
    IO.puts(\"-- what the panel computes\")

    Enum.each(Dronex.FollowTheChampions.ranked(20), fn c ->
      IO.puts(
        [
          String.pad_trailing(String.slice(c.genome_id, 0, 12), 14),
          \"islands=\", to_string(c.islands),
          \" crossed?=\", to_string(c.crossed?),
          \" held_ms=\", to_string(c.held_ms)
        ]
        |> Enum.join()
      )
    end)

    IO.puts(\"\")
    IO.puts(\"crossings=#{length(Dronex.FollowTheChampions.crossings(50))}\")
  ' 2>&1 | grep -v '^$'
" 2>&1 | grep -v "post-quantum\|store now, decrypt later\|openssh.com/pq\|may need to be upgraded"
