"""Every reference to a file in the reversing tree, checked against the tree.

    python scripts/checkrefs.py              # the whole repository
    python scripts/checkrefs.py --list       # every reference it resolved, with its target
    python scripts/checkrefs.py --tree       # the reversing folder only, which is quick

Exit code 1 if anything does not resolve, so it can gate a commit.

**Written because the folders were split on 2026-10-02** and about six hundred references had to
move with them. The split is the kind of change where a broken reference does not announce itself:
nothing imports a markdown link, so a wrong path sits there until somebody follows it and gives up.
This is the check that the split worked, and it is worth running after any later move.

## The rule it enforces, which is not "every name must be a path"

**A name without a folder is a name.** The prose cites documents and scripts the way someone
standing in `reversing/` would - `` `CLASSES.md` ``, `` `project.json` ``, `` `vtable.py` ``,
`` `FINDINGS-combat.md` `` - and `README.md`'s layout table is what resolves them. There are about
three hundred of those and prefixing them would make the writing worse to settle what one table
settles, so this script does not look at them. It checks what claims to be a path:

1. a `FINDINGS-x.md` reference **with a folder on it**, against the citing file's own folder
2. a `python <something>.py` command line **inside the reversing tree**, against `reversing/` -
   because that is where commands are documented to be run from
3. a backticked path naming one of the tree's folders, against the citing file's folder or the tree

## Two things that will otherwise look like failures

**`scratchpad/...` is meant to be absent.** Several findings files name scripts that were written
into a session scratchpad and never lived here - `scratchpad/power/annfp.py`,
`scratchpad/forceneeds/enrich.py`. The prose describes what each did precisely so the work does not
depend on them, and they are marked with that prefix for exactly this reason. Anything under
`scratchpad/` is skipped.

**A reference resolves against several roots.** `progress.py` holds the strings it writes into
`PROGRESS.md`, which sits in `reversing/`, so `findings/FINDINGS-script.md` in that script is
correct even though the script is in `scripts/`. A C++ header writes `reversing/findings/...` from
the solution directory. So a reference counts as resolved if it resolves from any of: the citing
file's folder, `reversing/`, the solution folder, or the repository root. That is looser than ideal
and still catches every real breakage, because a moved file resolves from *none* of them.
"""

import argparse
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import roots  # noqa: E402 - needs HERE on the path first

# These were counted `..` levels until 2026-10-07. Counting is exactly what moving this tree
# out of the mod's repository breaks, and it breaks it silently: the join still yields a path,
# so every reference that should have been reported instead resolves against the wrong place.
# `roots.py` finds each one by marker; see its docstring.
REVERSING = roots.REVERSING
BICE = roots.BICE
MOD = roots.MOD

# Only a reference carrying a folder is a path; see the rule above.
FINDING = re.compile(r"`?([\w./-]+/FINDINGS-[a-z0-9]+\.md)`?")
COMMAND = re.compile(r"python ([\w./-]+\.py)")
PATHISH = re.compile(
    r"`((?:findings|scripts|ghidra|fragments|probes|reversing|BiceLib)/[\w./-]+)`")
# `BiceLib` was added 2026-10-05, and it caught three dangling references the same minute.
# The seam between the two halves is that the record cites the headers - a fact becomes code
# by being written into `project.json` and into a `GameClasses` constant - so a reference
# pointing the other way is exactly as load-bearing as one pointing inward, and it was the
# only kind not being checked. `ROOTS` already resolves from the BiceLib root, so nothing
# else had to change. Note the brace form `CBiceCommand.{hpp,cpp}` is still not a path and is
# still not checked; it reads well and there is no file of that name to find.

# Build output, dependencies and the mod's bulk - nothing in them cites the tree.
SKIP_DIRS = {".git", ".vs", "__pycache__", "venv", "ReleaseDebug", "x64", "Debug",
             "gfx", "history", "localisation", "map", "pyPdxParser", "old scripts",
             "node_modules"}
READ = (".md", ".py", ".hpp", ".cpp", ".h", ".java", ".json")

# `.json` was added 2026-10-05, for `ghidra/project.json`. It is a third of the fact base and
# its comments cite paths constantly - a finding's `source`, a header it pairs with, the
# findings file that established an offset - and none of it was being checked, which is how a
# reference to a deleted header survived a full pass.
#
# `bicelib_findings.json` is **generated** from `project.json` by `buildFindings.py`, so every
# reference in it is a copy of one already checked in the source. Reading both would report
# each breakage twice and, worse, invite someone to fix the generated copy. Skipped by name.
SKIP_FILES = {"bicelib_findings.json"}

# Where a reference may resolve from. Loose on purpose - see the docstring. A root that
# `roots.py` could not find is dropped rather than joined, because joining `None` throws and
# joining a guess is worse than reporting the reference.
ROOTS = [folder for folder in (REVERSING, BICE, MOD) if folder]

# A reference carrying the tree's own name on the front used to resolve because that name was
# a real folder inside the BiceLib project, one level under `BICE`. Once the tree is its own
# repository that stops being true: it may sit anywhere and be called anything on disk. So the
# prefix is read as the *logical* name of the fact base and mapped to wherever it was found.
# (No example here, for the reason the loop below gives: an illustrative path in this file is
# a reference this script then reports against itself. Adding one cost two phantom references
# the first time this comment was written.)
#
# The alternative was rewriting all 110 distinct references that are written this way. Most of
# them are in `GameClasses` headers, citing the evidence for an offset - the single most
# load-bearing kind of reference in either half - and a rename there buys nothing a mapping
# does not. It also means the repository can be renamed again without touching the prose.
PREFIXES = {"reversing/": REVERSING}


def resolves(reference, folder):
    for prefix, mapped in PREFIXES.items():
        if mapped and reference.startswith(prefix):
            if os.path.exists(os.path.join(mapped, reference[len(prefix):])):
                return True
    for root in [folder] + ROOTS:
        if os.path.exists(os.path.join(root, reference)):
            return True
    return False


def rel(path):
    """\\p path against whichever root holds it, so the report stays readable across repos."""
    full = os.path.abspath(path)
    for root in sorted(ROOTS, key=len, reverse=True):
        if full.startswith(os.path.abspath(root) + os.sep):
            return os.path.relpath(full, root)
    return path


def trees():
    """The roots to walk: the fact base and the mod, minus either if nested in the other.

    Before the split the fact base is inside the mod, so this is the mod alone and the walk is
    exactly what it always was. After the split it is both, which is the point - the seam
    references live in `GameClasses` headers, and a check that only read the fact base would
    stop seeing the half of the record that points outward. That blind spot is the one that
    cost a hundred stale references on 2026-10-02.

    `OPENHOI3` joins this list when the rewrite starts citing findings; nothing there does yet.
    """
    wanted = [folder for folder in (MOD, REVERSING) if folder]
    kept = []
    for folder in wanted:
        full = os.path.abspath(folder)
        if any(full.startswith(os.path.abspath(other) + os.sep) for other in wanted
               if os.path.abspath(other) != full):
            continue
        if full not in kept:
            kept.append(full)
    return kept


def sources(root):
    for base, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in names:
            if name.endswith(READ) and name not in SKIP_FILES:
                yield os.path.join(base, name)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--list", action="store_true",
                        help="print every reference that resolved, and to what")
    parser.add_argument("--tree", action="store_true",
                        help="only the reversing folder, rather than the whole repository")
    args = parser.parse_args()

    walk = [REVERSING] if args.tree else trees()
    inTree = os.path.abspath(REVERSING)

    broken = []
    skipped = set()
    checked = 0
    seenFiles = set()

    for path in (name for root in walk for name in sources(root)):
        if os.path.abspath(path) in seenFiles:
            continue
        seenFiles.add(os.path.abspath(path))
        folder = os.path.dirname(path)
        try:
            text = io.open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue

        found = [(hit.group(1), "findings reference") for hit in FINDING.finditer(text)]
        found += [(hit.group(1), "path") for hit in PATHISH.finditer(text)]
        if os.path.abspath(path).startswith(inTree):
            found += [(hit.group(1), "command line") for hit in COMMAND.finditer(text)]

        # A backticked findings path matches both FINDING and PATHISH, so the same reference would
        # otherwise be counted and reported twice; the first pattern wins. Written without an
        # example on purpose - an illustrative path in a comment here is a reference this script
        # then reports against itself, which it did once.
        seen = set()
        for reference, kind in found:
            reference = reference.rstrip("/.")
            if reference.startswith("scratchpad/"):
                skipped.add(reference)
                continue
            if reference in seen:
                continue
            seen.add(reference)
            checked += 1
            # A command line is documented as run from reversing/, so that is its only root.
            ok = (os.path.exists(os.path.join(REVERSING, reference)) if kind == "command line"
                  else resolves(reference, folder))
            if ok:
                if args.list:
                    print("   ok   %-44s %s" % (reference, rel(path)))
            else:
                broken.append((path, reference, kind))

    # Distinct per file, not total occurrences - the same reference repeated in one file gets one
    # verdict, so counting it twice would only inflate the number.
    print("%d distinct references checked under %s"
          % (checked, ", ".join(os.path.basename(folder) or folder for folder in walk)))
    if skipped:
        print("%d scratchpad references skipped, which is what that prefix is for"
              % len(skipped))

    if not broken:
        print("all resolve")
        return 0

    print("\n%d do not resolve:" % len(broken))
    for path, reference, kind in sorted(set(broken)):
        print("   %-44s %-16s %s" % (reference, kind, rel(path)))
    print("\nA name without a folder is a name, not a path - this only reports things that claim")
    print("to be paths. See the layout table in reversing/README.md.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
