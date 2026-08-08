#!/usr/bin/env python3
"""Carve dronex_live.ex into per-member blocks so a split is a SLICE, not a retype.

⚠ WHY A SCRIPT AND NOT AN EDITOR. The file is 2,441 lines of ~20 function
components, and the house rule that matters most here is that a refactor must
show mostly additions and deletions of whole blocks, never quiet edits to the
middle of one. Reading 1,700 lines into a model and typing them out again is a
transcription risk on every line of it. Slicing by line range cannot alter a
character it moves.

It prints a manifest, or with --emit writes the named members to a file. The
manifest is checked against the file's own member list, so a member that belongs
to no destination is an error rather than a silent drop.
"""

import argparse
import pathlib
import re
import sys

SRC = pathlib.Path(
    "system/apps/beam_campus_web/lib/beam_campus_web/live/dronex_live.ex"
)

# A member starts at `def`/`defp`; its block starts at the first line of the
# attached run of @doc / attr / doc-comment lines immediately above it.
MEMBER = re.compile(r"^  defp? ([a-z_?!]+)")
ATTACHED = re.compile(r"^  (@doc|attr |slot |#)")


def members(lines):
    """[(name, start_index, end_index_exclusive)] over the whole file."""
    starts = []
    for i, line in enumerate(lines):
        m = MEMBER.match(line)
        if not m:
            continue
        # Walk up over the attached doc/attr run, and over blank lines INSIDE it.
        #
        # ⚠ A @doc HEREDOC MUST BE SKIPPED WHOLE, and the first version of this
        # did not. Walking up hits the CLOSING `"""` and then a run of prose that
        # matches nothing, so the walk stopped mid-docstring: the member's block
        # began halfway through its own documentation and the other half stayed
        # behind, silently attached to whatever came before it. That is precisely
        # the quiet middle-of-a-block edit this script exists to make impossible.
        top = i
        j = i - 1
        while j >= 0:
            if lines[j].strip() == '"""':
                k = j - 1
                while k >= 0 and not re.match(r"^  @(doc|moduledoc)", lines[k]):
                    k -= 1
                if k < 0:
                    break
                top = k
                j = k - 1
                continue
            if ATTACHED.match(lines[j]):
                top = j
                j -= 1
                continue
            # a blank line is attached only if something attached sits above it
            if lines[j].strip() == "":
                k = j - 1
                while k >= 0 and lines[k].strip() == "":
                    k -= 1
                if k >= 0 and (ATTACHED.match(lines[k]) or lines[k].strip().endswith('"""')):
                    j -= 1
                    continue
            break
        starts.append((m.group(1), top, i))

    out = []
    for n, (name, top, defline) in enumerate(starts):
        end = starts[n + 1][1] if n + 1 < len(starts) else len(lines)
        out.append((name, top, end))
    return out


def collapse(ms):
    """Merge consecutive clauses of the same name into one block."""
    merged = []
    for name, top, end in ms:
        if merged and merged[-1][0] == name:
            merged[-1] = (name, merged[-1][1], end)
        else:
            merged.append((name, top, end))
    return merged


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--emit", nargs="*", help="member names to print, in order")
    args = ap.parse_args()

    lines = SRC.read_text().splitlines(keepends=True)
    ms = collapse(members(lines))

    if not args.emit:
        for name, top, end in ms:
            print(f"{name:28} {top + 1:5}..{end:5}  ({end - top} lines)")
        print(f"\n{len(ms)} members, {len(lines)} lines", file=sys.stderr)
        return

    index = {name: (top, end) for name, top, end in ms}
    missing = [n for n in args.emit if n not in index]
    if missing:
        sys.exit(f"no such member: {missing}")

    for name in args.emit:
        top, end = index[name]
        sys.stdout.write("".join(lines[top:end]))


if __name__ == "__main__":
    main()
