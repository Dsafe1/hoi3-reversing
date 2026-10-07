"""The five roots the fact base resolves things against, found rather than counted.

    python scripts/roots.py            # what resolved, and how each one was found
    python scripts/roots.py --json

**Written 2026-10-07, for the split of the fact base into its own repository.** Until then
every script that needed something outside `reversing/` counted `..` levels to reach it -
`os.path.join(REVERSING, "..", "..", "..", "..", "..")` appears verbatim in three scripts and
was the whole of `checkrefs.py`'s root list. Counting works exactly as long as nothing moves,
which makes it the one thing a move is guaranteed to break, and silently: the join still
produces a path, it just produces the wrong one, and a wrong root in `checkrefs.py` means
every reference it should have caught now resolves against somewhere else.

So the roots are found by **marker**: a folder is the mod if it holds `history/countries`, the
install if it holds `hoi3_tfh.exe`. A marker survives a move, a rename and a differently
nested checkout, and when it finds nothing it says so instead of guessing.

## The five

| root | marker | who needs it |
| --- | --- | --- |
| `REVERSING` | `ghidra/project.json` | everything; this is the fact base itself |
| `BICE` | `BiceLib.sln` | the record cites `GameClasses` headers - the seam |
| `MOD` | `history/countries` | `dupekeys.py`, `definesMap.py` read the mod's own data |
| `GAME` | `hoi3_tfh.exe` + `tfh` + `common` + `history` | `image.py` and friends read the executable |
| `OPENHOI3` | `project.godot` | `luabindExtract.py` reads its recovered class list |

`MOD` is derived from `BICE` by walking up rather than searched for, because the install also
has a `common/` and a `history/` and would match a looser marker. The DLL project sits inside
the mod, so the mod is the nearest ancestor of `BICE` carrying the marker - which is what the
old `..` count meant, said in a way that survives the project moving.

## Precedence, highest first

1. an environment variable - `HOI3_REVERSING`, `HOI3_BICE`, `HOI3_MOD`, `HOI3_GAME`,
   `HOI3_OPENHOI3`. `HOI3_EXE` is still honoured and names the executable, not its folder.
2. `roots.json` beside `ghidra/`, which is git-ignored because it is machine-specific.
   `roots.example.json` is committed and shows the shape.
3. discovery by marker, over this tree's ancestors and their immediate children - which is
   what finds a sibling repository, and needs no configuration on a fresh clone.

A root that nothing finds is `None` rather than a wrong path. Ask for it with `root("GAME")`
and the error names the marker, the places that were searched and the variable that overrides
it, because the alternative is a `FileNotFoundError` on a path nobody recognises.
"""

import argparse
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REVERSING = os.path.dirname(HERE)

# What identifies each root: relative paths that must *all* exist inside the folder.
#
# `GAME` needs four of them, and the first run of this module is why. With `hoi3_tfh.exe`
# alone it answered `DaveStuff/Podcat's LAA` - a folder holding one large-address-aware copy
# of the executable and nothing else - because that copy sits nearer this tree than the
# install does. Nearest-first ordering does not protect against a stray copy; only a marker
# specific enough to describe the real thing does. An install has the content beside the
# executable, so that is what gets asked for. OpenHOI3's own `CDirectorySettings.IsGameRoot`
# takes the same approach for the same reason.
MARKERS = {
    "REVERSING": (os.path.join("ghidra", "project.json"),),
    "BICE": ("BiceLib.sln",),
    # `.git` is half of what tells the mod from the install: both hold game data in the same
    # shape, so `history/countries` alone matches either, and which one won would come down
    # to the order folders happened to be visited in. The mod is a working tree; the install
    # is not. That is the difference, so that is what gets asked.
    "MOD": (os.path.join("history", "countries"), ".git"),
    "GAME": ("hoi3_tfh.exe", "tfh", "common", "history"),
    "OPENHOI3": ("project.godot",),
}

# Folders not worth descending into when searching *inside* an identified root: the mod's and
# the install's bulk, build output, and anywhere a stray second copy would sit. Without this
# the search for `BiceLib.sln` walks 45,000 textures to reach one file at depth five.
PRUNE = {".git", ".vs", ".godot", "__pycache__", "venv", "node_modules", "ReleaseDebug",
         "x64", "bin", "obj", "gfx", "history", "localisation", "map", "units", "events",
         "decisions", "WIP", "tfh", "mod", "scenarios", "music", "sound", "save games"}

# How deep that inner search goes. `BiceLib.sln` sits at depth five under the mod; eight
# leaves room for a differently nested checkout without turning this into a disk scan.
DEPTH = 8


def _describe(name):
    """\p name's markers, for a message a person can act on."""
    return " + ".join(MARKERS[name])

ENV = {name: "HOI3_" + name for name in MARKERS}

CONFIG = os.path.join(REVERSING, "roots.json")

# How far up to look, and the names worth trying as siblings. The ancestor walk alone finds
# everything in the pre-split layout; the children of each ancestor are what find a sibling
# repository after the split, and that is the case this module exists for.
ANCESTORS = 8


def _marked(folder, name):
    """True when \p folder carries every one of \p name's markers, so it is that root."""
    if not folder or not os.path.isdir(folder):
        return False
    return all(os.path.exists(os.path.join(folder, marker)) for marker in MARKERS[name])


def _candidates():
    """This tree's ancestors nearest-first, then each one's immediate children.

    Nearest-first matters: in the pre-split layout `BICE` is `REVERSING`'s own parent, and in
    the post-split layout it is a child of a grandparent several levels up. Both are found,
    and the nearer one wins.

    Nearest-first is an ordering and not a safeguard: a stray copy *nearer* than the real
    thing wins, which is what happened to `GAME` on this module's first run. Specific markers
    are the safeguard; this only decides ties between folders that all look right.
    """
    seen = []
    folder = REVERSING
    ancestors = []
    for _ in range(ANCESTORS):
        if folder in ancestors:
            break
        ancestors.append(folder)
        parent = os.path.dirname(folder)
        if parent == folder:
            break
        folder = parent

    for folder in ancestors:
        if folder not in seen:
            seen.append(folder)
    for folder in ancestors:
        try:
            names = sorted(os.listdir(folder))
        except OSError:
            continue
        for name in names:
            child = os.path.join(folder, name)
            if child not in seen and os.path.isdir(child):
                seen.append(child)
    return seen


def _inside(root, name):
    """\\p name's folder somewhere under \\p root, breadth-first and pruned.

    Breadth-first so the shallowest match wins, which is what makes a copy buried deeper
    unable to shadow the real one - the mistake `GAME` made on this module's first run, here
    avoided by construction rather than by hoping.
    """
    level = [root]
    for _ in range(DEPTH):
        nextLevel = []
        for folder in level:
            try:
                names = sorted(os.listdir(folder))
            except OSError:
                continue
            for entry in names:
                child = os.path.join(folder, entry)
                if entry in PRUNE or not os.path.isdir(child):
                    continue
                if _marked(child, name):
                    return child
                nextLevel.append(child)
        if not nextLevel:
            return None
        level = nextLevel
    return None


def _fromConfig():
    if not os.path.exists(CONFIG):
        return {}
    try:
        with io.open(CONFIG, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return {}
    return {k: v for k, v in data.items() if k in MARKERS and v}


def _discover():
    """Each root, with a note on how it was found, in precedence order."""
    config = _fromConfig()
    found = {}
    how = {}

    for name in MARKERS:
        value = os.environ.get(ENV[name])
        if not value and name == "GAME" and os.environ.get("HOI3_EXE"):
            # Honoured because `luabindExtract.py` has read it since before this module, and
            # it names the executable rather than the folder holding it.
            value = os.path.dirname(os.environ["HOI3_EXE"])
        if value:
            found[name] = os.path.abspath(value)
            how[name] = "$" + ENV[name]
            continue
        if name in config:
            found[name] = os.path.abspath(config[name])
            how[name] = "roots.json"

    # This tree is the fact base, whatever a variable says - it is where this file lives.
    found["REVERSING"] = REVERSING
    how["REVERSING"] = "this file"

    # One folder cannot be two roots, so a folder already claimed is not offered again. That
    # matters where two roots look alike - the mod and the install both hold `history/` - and
    # it means a wrong answer needs two markers to collide, not one.
    for folder in _candidates():
        for name in MARKERS:
            if name in found:
                continue
            if folder in found.values():
                continue
            if _marked(folder, name):
                found[name] = folder
                how[name] = "found by " + _describe(name)

    # The two that the ancestors-and-their-children sweep cannot reach, each found from the
    # other end. `BiceLib.sln` lives five levels inside the mod, so it is nobody's immediate
    # child and the sweep never sees it; before the split it was this tree's own parent and
    # the sweep always did. Both layouts have to work, so both directions are tried.
    if not found.get("BICE") and found.get("MOD"):
        inside = _inside(found["MOD"], "BICE")
        if inside:
            found["BICE"] = inside
            how["BICE"] = "inside MOD, by " + _describe("BICE")

    if not found.get("MOD") and found.get("BICE"):
        folder = found["BICE"]
        for _ in range(ANCESTORS):
            if _marked(folder, "MOD"):
                found["MOD"] = folder
                how["MOD"] = "above BICE, by " + _describe("MOD")
                break
            parent = os.path.dirname(folder)
            if parent == folder:
                break
            folder = parent

    for name in MARKERS:
        found.setdefault(name, None)
        how.setdefault(name, "not found")
    return found, how


_FOUND, _HOW = _discover()

REVERSING = _FOUND["REVERSING"]
BICE = _FOUND["BICE"]
MOD = _FOUND["MOD"]
GAME = _FOUND["GAME"]
OPENHOI3 = _FOUND["OPENHOI3"]


def root(name):
    """\p name's folder, or an error that says what to do about it."""
    name = name.upper()
    if name not in MARKERS:
        raise KeyError("no such root: %s (have %s)" % (name, ", ".join(sorted(MARKERS))))
    value = _FOUND[name]
    if value:
        return value
    raise RuntimeError(
        "cannot find the %s root.\n"
        "  Looked for a folder containing %s,\n"
        "  under %s and its %d ancestors and their immediate children.\n"
        "  Set %s, or name it in %s - see roots.example.json."
        % (name, _describe(name), REVERSING, ANCESTORS, ENV[name], CONFIG))


def exe():
    """The executable every disassembling script reads."""
    if os.environ.get("HOI3_EXE"):
        return os.environ["HOI3_EXE"]
    return os.path.join(root("GAME"), "hoi3_tfh.exe")


def have(name):
    """True when \p name resolved, for a script that can carry on without it."""
    return _FOUND.get(name.upper()) is not None


def resolveRoots():
    """Every root that resolved, for a caller wanting to try several."""
    return [value for value in _FOUND.values() if value]


def report():
    lines = []
    for name in sorted(MARKERS):
        lines.append("%-10s %-28s %s"
                     % (name, _HOW[name], _FOUND[name] or "-"))
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true", help="print the roots as JSON")
    args = parser.parse_args()

    if args.json:
        print(json.dumps(_FOUND, indent=2, sort_keys=True))
    else:
        print("%-10s %-28s %s" % ("root", "how", "where"))
        print(report())
        missing = [name for name in sorted(MARKERS) if not _FOUND[name]]
        if missing:
            print("\n%d not found: %s" % (len(missing), ", ".join(missing)))
            print("Set $HOI3_<NAME> or write %s - see roots.example.json."
                  % os.path.relpath(CONFIG, REVERSING))
            return 1
        print("\nall five resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
