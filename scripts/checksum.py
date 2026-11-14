"""The original's file checksum, computed as CEU3Application::CreateChecksum computes it.

    python scripts/checksum.py                       the base game (TFH), as the install is now
    python scripts/checksum.py --mod "BlackICE 15.1" with that mod, read from tfh/mod/<name>.mod
    python scripts/checksum.py --list                every file summed, with its own checksum

Prints the figure the original logs to setup.log as `Checksum is HoI3 v4.02 (GSKH)    1499173604`, so
the two can be set side by side. Reproduced exactly on 2026-11-13: the base game's 1499173604 (GSKH)
and BlackICE 15.1's -410340735 (ZAUD), each against the log of a run made after the files last
changed. See findings/FINDINGS-checksum.md for the reading.

The search path is modelled as the original mounts it (PhysFS, each later mount in front): the mod's
user folder and the mod, then tfh/, then the install, then the Documents folder. A name is listed
once across all of them and read from the first that has it; a folder a .mod names in replace_path
lists only what the mod (or its user folder) holds. Every offset and address in the write-up is valid
only for this build of hoi3_tfh.exe; this script needs none of them.
"""
import argparse
import os

import roots

# The version name CApplication is constructed with; its own Fletcher sum is added to the total.
VERSION = "HoI3 v4.02"

# CreateChecksum's calls in order: (folder, extension, recurse). Base folders only - a .mod's
# override folders (the second block of the path registry) are empty in every run read, the mod
# entering through the search path instead.
FOLDERS = (
    ("common", ".lua", False), ("common", ".txt", False), ("common/countries", ".txt", False),
    ("events", ".txt", False), ("missions", ".txt", False),
    ("units", ".txt", False), ("units/models", ".txt", False),
    ("units", ".lua", False), ("units/country", ".lua", False),
    ("technologies", ".txt", False), ("decisions", ".txt", False),
    ("history/countries", ".txt", False), ("history/diplomacy", ".txt", False),
    ("history/provinces", ".txt", True), ("history/wars", ".txt", False),
    ("history/leaders", ".txt", False), ("history/units", ".txt", False),
)
FILES = ("map/default.map", "map/cache/time", "map/cache/adjacencies.bin")
LATER_FOLDERS = (("cgm", ".txt", True), ("battleplans", ".txt", True), ("battleplans", ".pln", True))
SKIPPED = (".", "..", ".svn")


def fletcher(data, signed=False):
    """CBinaryStream::Checksum (bytes unsigned) or ChecksumString (bytes signed, movsx): two sums
    from nought, each brought back by subtracting 65535 once when it passes 65535."""
    a = b = 0
    for value in data:
        if signed and value >= 0x80:
            value -= 0x100
        a += value
        if a > 0xFFFF:
            a -= 0xFFFF
        b += a
        if b > 0xFFFF:
            b -= 0xFFFF
    return ((a << 16) | b) & 0xFFFFFFFF


def letters(value):
    """The label's four letters: the signed total, >>4, >>8 and >>12, each C's remainder by 26
    made positive and added to 'A'."""
    return "".join(chr(65 + abs(part) % 26) for part in (value, value >> 4, value >> 8, value >> 12))


class SearchPath:
    def __init__(self, mounts, replaced, replaceLimit):
        self.mounts = mounts
        self.replaced = replaced
        self.replaceLimit = replaceLimit

    def first(self, path):
        for index, mount in enumerate(self.mounts):
            if os.path.exists(os.path.join(mount, path)):
                return index
        return None

    def names(self, directory):
        seen = []
        for mount in self.mounts:
            full = os.path.join(mount, directory)
            if os.path.isdir(full):
                for name in os.listdir(full):
                    if name not in seen:
                        seen.append(name)
        return seen

    def isDirectory(self, path):
        index = self.first(path)
        return index is not None and os.path.isdir(os.path.join(self.mounts[index], path))

    def checksum(self, path):
        index = self.first(path)
        if index is None or os.path.isdir(os.path.join(self.mounts[index], path)):
            return 0
        with open(os.path.join(self.mounts[index], path), "rb") as handle:
            return fletcher(handle.read())


def folder(search, directory, extension, recurse, listed):
    """CVersion::ChecksumFolder: every file of the folder ending in the extension, then, when asked,
    every subfolder the same way."""
    total = 0
    for name in search.names(directory):
        path = directory + "/" + name
        if not name.endswith(extension) or any(ord(c) >= 0x80 for c in name) or search.isDirectory(path):
            continue
        if name in SKIPPED:
            continue
        if directory in search.replaced and search.first(path) > search.replaceLimit:
            continue
        value = search.checksum(path)
        listed.append((path, value))
        total += value
    if recurse:
        for name in search.names(directory):
            if name in SKIPPED or any(ord(c) >= 0x80 for c in name):
                continue
            if search.isDirectory(directory + "/" + name):
                total += folder(search, directory + "/" + name, extension, recurse, listed)
    return total


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--mod", help="the mod's name, as its tfh/mod/<name>.mod file is called")
    parser.add_argument("--documents", default=os.path.join(os.path.expanduser("~"), "Documents",
                                                            "Paradox Interactive", "Hearts of Iron III"))
    parser.add_argument("--list", action="store_true", help="print every file summed")
    args = parser.parse_args()

    game = roots.root("GAME")
    mounts = [os.path.join(game, "tfh"), game, args.documents]
    replaced = set()
    limit = 0
    if args.mod:
        modFile = os.path.join(game, "tfh", "mod", args.mod + ".mod")
        userDir = None
        path = None
        for line in open(modFile, encoding="cp1252"):
            key, _, value = line.partition("=")
            key, value = key.strip(), value.strip().strip('"')
            if key == "path":
                path = os.path.join(game, value.replace("/", os.sep))
            elif key == "user_dir":
                userDir = os.path.join(args.documents, value)
            elif key == "replace_path":
                replaced.add(value.replace("\\", "/"))
        mounts = [userDir, path] + mounts
        limit = 1

    search = SearchPath(mounts, replaced, limit)
    listed = []
    total = 0
    for directory, extension, recurse in FOLDERS:
        total += folder(search, directory, extension, recurse, listed)
    for path in FILES:
        value = search.checksum(path)
        listed.append((path, value))
        total += value
    for directory, extension, recurse in LATER_FOLDERS:
        total += folder(search, directory, extension, recurse, listed)
    total += fletcher(VERSION.encode("cp1252"), signed=True)
    total &= 0xFFFFFFFF
    signed = total - 0x100000000 if total >= 0x80000000 else total

    if args.list:
        for path, value in listed:
            print("%08X  %s" % (value, path))
    print("%d files" % len(listed))
    print("Checksum is %s (%s)    %d" % (VERSION, letters(signed), signed))


if __name__ == "__main__":
    main()
