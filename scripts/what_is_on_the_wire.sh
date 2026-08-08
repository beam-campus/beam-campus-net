#!/usr/bin/env bash
# What did each island ACTUALLY publish about its champion?
#
# ⚠ THE SITE-SIDE nil PROVES NOTHING ON ITS OWN. Reign.came_from/1 normalises the
# string "undefined" to nil as well, so a clean read model is consistent BOTH with
# islands that fixed the fact and with islands that did not and are being cleaned
# up on arrival. Only the raw received map separates those two.
#
# So this prints, per island, whether champion_from is present at all and what it
# holds. Absent beside a present champion_id is the fix. Present-and-"undefined"
# is an island that has not rolled.
#
# ⚠ rpc, not eval: the question is what the LIVE node received.
# ⚠ No backticks in the remote body; it is one double-quoted string.
#
# Usage:  scripts/what_is_on_the_wire.sh
set -uo pipefail

BOX="${BOX:-178.105.157.209}"
KEY="${KEY:-$HOME/.ssh/id_hetzner}"
CONTAINER="${CONTAINER:-beam-campus-site}"
RELEASE="${RELEASE:-beam_campus}"

ssh -n -i "$KEY" -o ConnectTimeout=10 -o BatchMode=yes "root@${BOX}" "
  docker exec ${CONTAINER} /app/bin/${RELEASE} rpc '
    Enum.each(Dronex.islands(), fn row ->
      v = Dronex.fact(row, :vitals) || %{}

      IO.puts(
        [
          String.pad_trailing(to_string(Map.get(v, \"island\", \"?\")), 20),
          \"fact_v=\", String.pad_trailing(to_string(Map.get(v, \"fact_version\")), 4),
          \"sitter=\", String.pad_trailing(to_string(Map.get(v, \"benchmark_sitter\")), 10),
          \"champion_id=\",
          String.pad_trailing(String.slice(to_string(Map.get(v, \"champion_id\", \"-\")), 0, 12), 14),
          \"champion_from \",
          (if Map.has_key?(v, \"champion_from\"),
             do: \"PRESENT \" <> inspect(Map.get(v, \"champion_from\")),
             else: \"absent\")
        ]
        |> Enum.join()
      )
    end)
  ' 2>&1 | grep -v '^\$'
" 2>&1 | grep -v "post-quantum\|store now, decrypt later\|openssh.com/pq\|may need to be upgraded"
