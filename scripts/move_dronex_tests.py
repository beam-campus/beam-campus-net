#!/usr/bin/env python3
"""Move whole test blocks between DroneX test files, by test name.

⚠ WHY BY NAME AND NOT BY LINE RANGE. The tests for one view are scattered
through `dronex_live_test.exs` in three separate runs, and every deletion shifts
every range below it. Hand-counted ranges that go stale mid-move take the tail of
one test and the head of the next, which very often still compiles and passes.

A block is the `test "..." do ... end` plus the run of comment lines directly
above it, because in this repository that comment IS the finding the test
records. Moving the assertion and leaving the reason behind would strip the
tests of the thing that makes them worth keeping.

Usage:
  move_dronex_tests.py SOURCE TARGET OLD_URL NEW_URL "test name" ["test name" ...]
"""

import pathlib
import re
import sys


def block_of(lines, name):
    """(start, end) of the test block for `name`, comments included."""
    needle = f'  test "{name}"'
    start = next((i for i, l in enumerate(lines) if l.startswith(needle)), None)
    if start is None:
        sys.exit(f"no such test: {name}")

    # Up over the attached comment run.
    top = start
    j = start - 1
    while j >= 0 and lines[j].lstrip().startswith("#"):
        top = j
        j -= 1

    # Down to the `end` at the test's own indentation.
    end = next(
        (i for i in range(start + 1, len(lines)) if lines[i].rstrip() == "  end"), None
    )
    if end is None:
        sys.exit(f"unterminated test: {name}")
    return top, end + 1


def main():
    src_path, dst_path, old_url, new_url, *names = sys.argv[1:]
    src = pathlib.Path(src_path)
    dst = pathlib.Path(dst_path)

    moved = []
    for name in names:
        lines = src.read_text().splitlines(keepends=True)
        top, end = block_of(lines, name)
        moved.append("".join(lines[top:end]))
        src.write_text("".join(lines[:top] + lines[end:]))
        print(f"moved  {name}", file=sys.stderr)

    body = "\n".join(moved)
    n = body.count(old_url)
    if n != len(names):
        sys.exit(f"expected {len(names)} occurrences of {old_url}, found {n}")
    body = body.replace(old_url, new_url)

    text = dst.read_text()
    assert text.rstrip().endswith("end"), "target must end with the module's end"
    text = text.rstrip()[: -len("end")].rstrip("\n") + "\n\n" + body + "\nend\n"
    dst.write_text(text)
    print(f"{len(names)} tests appended to {dst}", file=sys.stderr)


if __name__ == "__main__":
    main()
