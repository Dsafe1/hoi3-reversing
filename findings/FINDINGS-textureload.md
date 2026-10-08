# Which file a texture's name loads

*Read 2026-10-09 for the rewrite, after the maintainer saw the ship builder's rows run past
their frame there and not in the game. The cause was not a layout rule: the install holds
`select_ship_button` twice, as a `.tga` and as a `.dds`, the two are different pictures, and
the game draws the other one.*

Addresses are virtual, as a disassembler prints them, with the rva after a slash where a
function is named.

## 1. The rule

`TextureHandler_LoadFile`, `0xA607D0 / 0x6607D0`. Five stack arguments, `ret 0x14`: the
handler, the name, two pointers for the picture's width and height (either may be null),
and a byte for whether a missing file is worth a line in the log. The lines it logs name
`texturehandler.cpp`, which is where the name is from; the name is ours.

    shown = name
    tried = name
    in both: every '\' becomes '/'                 ; ReplaceAllInString, 0xA5B730
    at = tried.find(".tga")
    if (at != npos)
        tried.replace(at, 4, ".dds")
        if (FileExists(tried))                     ; 0xB84A20
            shown = tried
    if (!FileExists(shown))
        if (complain) log "Couldn't find texture file: " + shown
        return null
    read the file, D3DXCreateTextureFromFileInMemoryEx

`confirmed` (`0xA60833`..`0xA609DB`)

**So a texture named `.tga` is its `.dds` wherever one exists, and the `.tga` only when
none does.** What follows from the way it is written:

- **It goes one way.** A name written `.dds` is opened as written. A `.dds` that is missing
  is not looked for as a `.tga`; it is reported and nothing is drawn.
- **It is over the whole search path.** `FileExists` is a thin wrapper round a PhysFS
  question (`0xB84660`, which by its `Invalid argument` is `PHYSFS_getRealDir`), so a `.dds`
  in the base game is found before a `.tga` in an expansion or a mod is ever looked at.
  **A mod that ships a `.tga` to replace a picture the base game holds as `.dds` replaces
  nothing.** `likely`: the wrapper and the null test were read, PhysFS's own search was not.
- **It is the first `.tga` in the name, in lower case.** `find`, not a test of the end, and
  no folding of case: a name written `.TGA` is opened as written.
- **No other extension is known.** Not `.png`, not `.bmp`.
- A file of 16 MB or more is refused without a word (`cmp edi, 0x1000000`).
- A name holding `-VOLUME` is made a volume texture.

`TextureHandler_ReloadEntry`, `0xA61370 / 0x661370`, loads one of the handler's textures
again by its index and applies the same swap to its name. `inferred`; what calls it was not
read.

## 2. What it changes in the game's own files

Their Finest Hour's `.gfx` files name 652 textures as `.tga`. Most exist only as `.dds`,
which is the case everybody knows. **Three exist as both, and for each the two differ:**

| name | the `.tga` | the `.dds` | used by |
| --- | --- | --- | --- |
| `gfx/interface/select_ship_button` | 1024 x 24, drawn from 31 to 992 | 964 x 24, drawn from 2 to 963 | `GFX_select_ship_button`, a line of the ship builder's list |
| `gfx/interface/divdesigner_listbutton2` | 572 x 23 | 572 x 24 | `GFX_divdesigner_listbutton2`, an armour line of the brigade picker |
| `gfx/test/factions` | 96 x 32 | 120 x 40 | `country_diplomacy.gfx` |

The first is what was seen. A line of the ship builder's list is at 31 of a window 1024
wide; the `.tga` is an older picture with the line's offset drawn into it and reaches 992
of its own width, 1023 of the window's, which is over the window's frame. The `.dds` ends
at 994 of the window, inside it. *Measured from the files, 2026-10-09.*

## 3. A second sprite family, found on the way

The brigade builder's list is drawn with `GFX_brigade_listbutton` + the type's combined
arms group as a number, exactly as the brigade picker's is with
`GFX_divdesigner_listbutton`: `CPossibleSingleBrigadeEntry`'s constructor
(`0x7DE3B0 / 0x3DE3B0`) is `CPossibleBrigadeEntry`'s with one string changed. It is written
up where it belongs, in `FINDINGS-builders.md`, section 6.

## Not established

- **The object at `0x134DA90`.** `TextureHandler_ReloadEntry` asks it whether a file exists,
  through its slot 9. The record calls it `g_random_object`, from the generator's users
  each making it before a draw. An object asked about files is not the generator's own;
  it wants another look and was not renamed here.
- What `0xA6C1B0` does beyond opening the file, and the handler's own layout - only
  `+0x6B6D4`, the device, and `+0x6B6E0`, the buffer a file is read into, were met.
- Whether fonts and the map's textures come through this routine. Three callers of it
  were found (`0xA60FA3`, `0xABAACA`, `0xABAC36`) and none was read.

## In the record

| rva | name | new or revised | confidence | |
| --- | --- | --- | --- | --- |
| `0x6607D0` | `TextureHandler_LoadFile` | new | confirmed | the rule above |
| `0x661370` | `TextureHandler_ReloadEntry` | new | inferred | the same swap, on a reload |
| `0x65B730` | `ReplaceAllInString` | new | inferred | what to look for arrives in EDI |
| `0x3DE3B0` | `CPossibleSingleBrigadeEntry::CPossibleSingleBrigadeEntry` | new | confirmed | the line's sprite |

No struct field is touched.
