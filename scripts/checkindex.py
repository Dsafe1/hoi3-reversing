"""Every findings file, checked against the index that is supposed to list them all.

    python scripts/checkindex.py           # exits 1 if the index is incomplete or miscounted
    python scripts/checkindex.py --list    # every file, and whether it is indexed

**Written 2026-10-07, after the index was found 6 files behind with a count 18 out.** It listed
79 of the 85 `FINDINGS-*.md` on disk and its own header said "67 findings files". Four of the six
it was missing were wave 15's, transcribed into `findings/` the previous session and never added
here.

That drift is structural rather than careless. A write-up is finished when it reaches
`findings/`; `CANDIDATES.md`'s index is a separate hand edit afterwards, and nothing failed when
it did not happen. The index is how anyone finds the evidence for a claim - `CLAUDE.md` and both
other repositories point at it - so an unlisted file is a write-up that exists and cannot be
found. This is the check that makes the omission loud.

It is deliberately not part of `checkrefs.py`. That script answers "does every reference
resolve", which is about paths that are written down; this one answers "is anything missing from
a list", which is about something that was never written down at all. The second question cannot
be asked of a reference, because an absent reference is exactly what there is nothing to check.
"""

import argparse
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import roots  # noqa: E402 - needs HERE on the path first

REVERSING = roots.REVERSING
CANDIDATES = os.path.join(REVERSING, "CANDIDATES.md")
FINDINGS = os.path.join(REVERSING, "findings")

# The index is the last section of the queue page; everything before it is the queue itself and
# mentions findings files constantly, so counting those would make the check vacuous.
INDEX_HEADING = "## What has already been read"

NAME = re.compile(r"FINDINGS-([a-z0-9]+)\.md")
COUNT = re.compile(r"(\d+) findings files")


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--list", action="store_true",
                        help="print every findings file and whether the index lists it")
    args = parser.parse_args()

    text = io.open(CANDIDATES, encoding="utf-8").read()
    if INDEX_HEADING not in text:
        print("! cannot find %r in %s" % (INDEX_HEADING, os.path.basename(CANDIDATES)))
        return 1
    index = text[text.index(INDEX_HEADING):]

    listed = set(NAME.findall(index))
    onDisk = {name[len("FINDINGS-"):-len(".md")]
              for name in os.listdir(FINDINGS)
              if name.startswith("FINDINGS-") and name.endswith(".md")}

    missing = sorted(onDisk - listed)
    ghosts = sorted(listed - onDisk)

    stated = COUNT.search(index)
    statedCount = int(stated.group(1)) if stated else None

    if args.list:
        for name in sorted(onDisk):
            print("   %-6s findings/FINDINGS-%s.md"
                  % ("ok" if name in listed else "MISSING", name))

    print("%d findings files on disk, %d listed in the index" % (len(onDisk), len(listed)))

    problems = []
    if missing:
        problems.append("%d on disk are not in the index:" % len(missing))
        for name in missing:
            problems.append("   findings/FINDINGS-%s.md" % name)
    if ghosts:
        problems.append("%d in the index do not exist:" % len(ghosts))
        for name in ghosts:
            problems.append("   findings/FINDINGS-%s.md" % name)
    if statedCount is None:
        problems.append("the index does not state a count - expected a '<n> findings files' line")
    elif statedCount != len(onDisk):
        problems.append("the index says %d findings files; there are %d"
                        % (statedCount, len(onDisk)))

    if problems:
        print()
        for line in problems:
            print(line)
        print()
        print("A write-up is not finished until the index lists it - that is how anyone finds the")
        print("evidence for a claim. Add it under the heading its subject belongs to.")
        return 1

    print("all listed, and the count matches")
    return 0


if __name__ == "__main__":
    sys.exit(main())
