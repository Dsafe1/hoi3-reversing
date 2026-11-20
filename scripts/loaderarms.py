"""What each recorded loader can reach for a key it has no case for.

    python scripts/loaderarms.py                 # every loader, and the totals
    python scripts/loaderarms.py CTrait CLaw     # only the loaders whose name holds one of these

For every function in `project.json` whose name holds `LoadKey` or ends `::LoadEntry`, lists
whether its body reaches

- `ReportUnknownKey` - the queued "Unexpected <key>" that nothing prints for a data file;
- `ReportParseError`;
- the log record builder - a loader that logs has a message of its own for a bad key or value;
- `ParseSkipValue` - **the only routine that steps over a value it was not asked to read**;
- another loader, by call or by jump - a base class or a name-resolved fallback.

Written 2026-11-20 for `findings/FINDINGS-unknownkeys.md`, to answer "may a mod's file carry a
key the original does not know".

**How it looks, and what that can miss.** It does not decode. It takes each loader's bytes from
its entry to the first run of three `int3` or the next recorded function, whichever comes first,
and reads every `E8`/`E9`/`0F 8x` at every byte offset as a rel32 branch, keeping those whose
target is one of the addresses above. That is immune to trap 9 - there is no alignment to lose -
and an exact 32-bit match by chance is not a practical worry. It cannot see an indirect call, a
skip loop written inline, or a branch from a part of the function laid out past an `int3` run.
The last line of the full run is the positive control: `ParseSkipValue`'s callers over the whole
of `.text`, which must include the one in `CCountry::LoadKey` the record already had.

A loader with nothing in any column returns on a key it does not know. Read the rows that matter
in place before quoting them: a count is a pointer to an arm, not a reading of it.
"""
import bisect
import io
import json
import os
import struct
import sys

import image
import roots

REPORT_UNKNOWN = 0x67A7B0
REPORT_ERROR = 0x67A960
LOG_RECORD = 0x2410
SKIP_VALUE = 0x67AC60


def branches(data, base, start, end):
    """(site rva, kind, target rva) for every rel32 call, jmp and jcc pattern in data[start:end]"""
    index = start
    while index < end - 4:
        byte = data[index]
        if byte in (0xE8, 0xE9):
            relative = struct.unpack_from("<i", data, index + 1)[0]
            yield index + base, "call" if byte == 0xE8 else "jmp", index + 5 + relative + base
        elif byte == 0x0F and 0x80 <= data[index + 1] <= 0x8F and index < end - 5:
            relative = struct.unpack_from("<i", data, index + 2)[0]
            yield index + base, "jcc", index + 6 + relative + base
        index += 1


def main():
    record = json.load(io.open(os.path.join(roots.REVERSING, "ghidra", "project.json"),
                               encoding="utf-8"))
    functions = sorted((int(entry["rva"], 16), entry["name"]) for entry in record["addresses"]
                       if entry.get("kind") == "function")
    names = dict(functions)
    entries = [rva for rva, _ in functions]

    textVa, data = image.text()
    base = image.toRva(textVa)

    def extent(start):
        following = bisect.bisect_right(entries, start)
        cap = entries[following] if following < len(entries) else start + 0x8000
        cap = min(cap, start + 0x8000)
        padding = data.find(b"\xCC\xCC\xCC", start - base, cap - base)
        return start - base, padding if padding != -1 else cap - base

    wanted = [word.lower() for word in sys.argv[1:]]
    rows = []
    for start, name in functions:
        if "LoadKey" not in name and not name.endswith("::LoadEntry"):
            continue
        first, last = extent(start)
        unknown = error = log = skip = 0
        others = set()
        for site, kind, target in branches(data, base, first, last):
            if target == REPORT_UNKNOWN:
                unknown += 1
            elif target == REPORT_ERROR:
                error += 1
            elif target == LOG_RECORD:
                log += 1
            elif target == SKIP_VALUE:
                skip += 1
            elif target in names and target != start and (
                    "LoadKey" in names[target] or names[target].endswith("::Load")):
                others.add(("call " if kind == "call" else "") + names[target])
        rows.append((name, start, last - first, unknown, error, log, skip, sorted(others)))

    print("%-50s %-9s %-6s unk err log skip  other loaders" % ("loader", "rva", "bytes"))
    for name, start, size, unknown, error, log, skip, others in rows:
        if wanted and not any(word in name.lower() for word in wanted):
            continue
        print("%-50s 0x%-7X %-6d %-3d %-3d %-3d %-4d  %s"
              % (name, start, size, unknown, error, log, skip, ", ".join(others)))
    if wanted:
        return

    print()
    print("%d loaders; %d reach ReportUnknownKey; %d log; %d reach ParseSkipValue; %d reach "
          "none of the four and no other loader"
          % (len(rows), sum(1 for row in rows if row[3]), sum(1 for row in rows if row[5]),
             sum(1 for row in rows if row[6]),
             sum(1 for row in rows if not (row[3] or row[4] or row[5] or row[6] or row[7]))))

    print("positive control - every rel32 branch to ParseSkipValue in .text:")
    for site, kind, target in branches(data, base, 0, len(data)):
        if target == SKIP_VALUE:
            holder = bisect.bisect_right(entries, site) - 1
            print("    0x%X %s, 0x%X into %s"
                  % (site, kind, site - entries[holder], functions[holder][1]))


if __name__ == "__main__":
    main()
