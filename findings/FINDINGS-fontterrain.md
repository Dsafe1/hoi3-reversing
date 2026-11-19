# Font colour escapes, terrain.txt's unused keys, country_colors.txt and graphical cultures

Read statically off `hoi3_tfh.exe` on 2026-11-19, for OpenHOI3, which reads none of these (a subagent's reading; the
collecting session checked the two colour cases of `CEU3BitmapFont::LoadKey` and the block reader's "unset" test off
the listing before merging). Addresses are **virtual** (image base 0x400000), with rvas where the record needs them.
Nothing was watched in a running game. Each figure is tagged [exe] (hardcoded) or [mod] (in the file named).

## 1. Bitmap fonts: `color`, `color_override`, `colorcodes`

### The grammar (CEU3BitmapFont::LoadKey, VA 0xAF9CF0, slot 4) - confirmed

| key | token | where it goes |
| --- | --- | --- |
| `name` | 0x1A | font +0xC, a string |
| `fontName` | 0x21 | font +0x78, the stem of gfx/fonts/<name>.tga and .fnt |
| `effect` | 0x58 | font +0x8, yes/no; 1 by default (the base constructor, VA 0xAF9889) |
| `color` | 0x55 | font +0x38: the token's text read with sscanf "%x", so a packed 0xAARRGGBB. 0 until given. A text that does not scan goes to the error reporter 0xA7A960 |
| `colorcodes` | 0x150 | **the global table g_FontColorCodes (VA 0x1B211A8)**, shared by every font |
| `color_override` | 0x19A | **this font's own table at +0x4A8** |

So the `FINDINGS-fieldmap.md` row "colorcodes -> nothing" missed a store to a global. And **`FINDINGS-textdraw.md`
section 4 was wrong** where it said the font's +0x4A8 table is what `colorcodes` fills. That table is
`color_override`'s.

### The tables (confirmed)

Each table is 256 FontColorCode entries of 0x20 bytes, one per byte value: `+0 letter` (0xA7 while unset) and `+4` a
CColor held by value (table, token, r g b a, opaque byte). FontColorCode_Construct (VA 0xAF97E0) makes each entry
unset: byte 0xA7, white, alpha 1.

- The global table is built once by a static initializer (InitGlobalFontColorCodes, VA 0xD1EF90). Nothing clears it.
- Each font's table is built by the bitmap font's base constructor (VA 0xAF9929-0xAF994F).

### Reading a block (BitmapFont_ReadColorCodes, VA 0xAF9DD0) - confirmed

Each line `X = { r g b [a] }` until the closing brace:

- The entry is `table + (signed char)X * 32` (`movsx eax, cl; shl eax, 5`). Only the **first byte** of the key is
  used, so `Wx` counts as `W`. A byte above 0x7F indexes *before* the table (movsx). The consequence of that is
  inferred, not observed.
- The value is read by CColor::Load: r, g and b are each **divided by 255 where above 1.0** (so 1 stays 1.0 = 255,
  and 0.5 stays 0.5); alpha is 1.0 unless a fourth number is given.
- **The entry is written only while it is still unset** (`cmp byte [eax], 0xA7` at VA 0xAF9E5D), so the first value
  a letter gets wins.
  - Within one font's `color_override`: a letter listed twice keeps its first value.
  - In the global table: the **first font parsed** that gives a letter keeps it, for every font.

### Drawing (slots 6, 7 and 8) - confirmed

Slot 6 (DrawTextToTexture, VA 0xAFB5A6), slot 8 (DrawText, VA 0xAFCDA3) and slot 7 (DrawTextWithAlpha, VA 0xAFEB73)
handle the colour escape the same way:

- `§` (0xA7) followed by `!`: back to the font's `color` (+0x38).
- `§` followed by a letter L:
  1. If the font's own +0x4A8[L] is set, that colour.
  2. Else if g_FontColorCodes[L] is set, that colour.
  3. Else **no change**: the letter is swallowed and the colour stays as it was.
- The chosen CColor is packed to ARGB by CColor::ToPackedArgb, each part times 255, truncated.
- Slots 6 and 8 take the packed colour whole, alpha included. Slot 6 sets it as the device's texture factor (render
  state 0x3C).
- **Slot 7 is new** (VA 0xAFE5B0, `ret 0x28`). It draws at an opacity argument, the 8th stack argument: the font's
  colour gets alpha `(int)(alpha * 255)`, and every escape keeps that alpha (`(colour & 0xFFFFFF) | alpha`). Its
  callers were not looked for; it is reached by a virtual call.

### What the shipped files make of this

TFH's `tfh/interface/core.gfx` has seven `colorcodes` blocks and four `color_override` blocks. All eleven carry the
same eight colours (W B G R r b g Y), and `color_override` is on the four `_black` fonts. `tfh/interface/chatfonts.gfx`
also has two `colorcodes` blocks, which differ: G = { 0 159 3 }, no `r`, and an extra P = { 200 30 170 }.

**Which file is parsed first decides the global table** (inferred). `.gfx` files are taken in folder-listing order.
That listing is sorted byte by byte, which is confirmed in `FINDINGS-localisation.md` section 3. So `chatfonts.gfx`
comes before `core.gfx`. That the two files fall in the same listing, and so in that order, is not read. If so:

- **TFH's global table:** W, B, R, b, g, Y as core.gfx; **G = (0, 159, 3)** and **P = (200, 30, 170)** from
  chatfonts.gfx; `r` from core.gfx's first font.
- So every font without `color_override` draws `§G` as (0, 159, 3), not core.gfx's (0, 255, 0). The four `_black`
  fonts draw (0, 255, 0) from their own blocks.
- **BlackICE** changes core.gfx's colours (G (13,128,13), R (179,32,32), Y (37,37,15), and Arial14_black's
  Y (0,0,180)), but has no chatfonts.gfx of its own, so TFH's is listed and parsed first. Its **`colorcodes` edits
  would then do nothing** except where chatfonts.gfx lacks the letter (`r`, which BlackICE leaves at TFH's value).
  Only its five `color_override` fonts show its colours.

The check: in BlackICE, a `§Y` in a tooltip is (255, 189, 0) if this reading holds, and (37, 37, 15) if core.gfx is
parsed first.

### What a reimplementation needs

1. Two levels of table: one global, filled by all fonts' `colorcodes` in .gfx parse order with the first value per
   letter winning; and one per font, filled by its `color_override` with the first value per letter winning.
2. The lookup: font table, then global table, then no change.
3. CColor::Load's scaling: divide by 255 only where above 1.0.
4. `color` is hex ARGB; `§!` resets to it.

[mod: every .gfx's `bitmapfont` blocks; the parse order is the listing's, exe]

## 2. terrain.txt's `has_texture` and `altitude` - read by nothing (confirmed)

CTerrainGraphical::LoadKey (VA 0x4AE7E0) stores `has_texture` at +0x40 (yes/no, default 1) and `altitude` at +0x3C
(float, default 0).

**The search.** Palette entries are reached only two ways: CMap +0x2220[palette index] and the list
CMap +0x2A20..+0x2A28. Every disp32 use of 0x2220 (27 sites) and of 0x2A20, 0x2A24 and 0x2A28 (19 sites) read in
place:
- CMap's constructor and destructor, and CMap_LoadTerrainDefinitions;
- VA 0x48A99F and 0x4AA1EE, which read only +0xC;
- MapTrees_BuildTilePoints (VA 0x863856), which reads +0x68 and +0x2C/+0x30;
- CreateTerrainOffsetTexture (VA 0x869080), which reads +0xC and +0x64;
- the rest are other structures.

The `+0x3C` reads inside CreateTerrainOffsetTexture are off the graphics object in EDI, not an entry.

**Positive control:** the same search finds every known reader of +0xC, +0x2C/+0x30, +0x44, +0x64 and +0x68. The
table's own slots (0, 4, 6, 7) do not read them either.

**This would be wrong if** an entry pointer were copied somewhere else first; none of those sites stores one.

A reimplementation may parse both keys and ignore them. [mod: map/terrain.txt; dead in the exe]

## 3. common/country_colors.txt - stored, read by nothing (confirmed)

**The reader.** LoadCountryColors (VA 0x518200) runs once, just after countries.txt. For each
`TAG = { color1 = {..} color2 = {..} color3 = {..} }`:

- The tag is found by CCountryDataBase::GetTag. An unknown tag answers `---`, id 0, and its colours land on the
  placeholder country.
- The keys are tested **in that fixed order**, each optional (tokens 0x3E3, 0x3E4, 0x3E5). Out of order is not
  supported (inferred).
- Each value is read by CColor::Load (the same divide-by-255 rule) and stored in **CCountry +0xC50, +0xC6C and
  +0xC88**: three CColor of 0x1C built together by CCountry::CCountry (VA 0x4C9580).

**Other writers.** CCountry::LoadKey's `color` copies the country colour (+0xC30) into +0xC50 as well (VA 0x4CCE93),
and the country file's `color2` (token 0x3E4) sets +0xC6C (VA 0x4CD49A), both through CColor_CopyValue
(VA 0x4685B0).

**Readers: none.** The search:
- fieldchain over every dword from +0xC50 to +0xCA0;
- findRefs on the immediates 0xC50, 0xC6C and 0xC88;
- every hit read in place.

Each hit is one of: these writers, CCountry::CCountry, the exception unwinds' array destructors (VA 0xC24315,
0xC9C7D0), CGameState / CCurrentGameState fields (difficulty +0xC98, arcade_mode +0xC9C and the like), stack slots, or
an image-codec routine at VA 0xB61290.

**Positive control:** the same scan on +0xC38 (the red of the country's own `color`) finds both of its getters
(VA 0x4CCCC1, 0x4CCD0E). No Lua binding names them.

The colours the map and the counters use are the country file's `color` (+0xC30), read through CCountry_GetColour.
The file's own heading, "Country unit colors", is inherited from EU3.

**This would be wrong if** a reader walked from a pointer to +0xC30 with small displacements, which a disp32 search
cannot see.

[mod: common/country_colors.txt; dead in the exe]

## 4. common/graphicalculturetype.txt (confirmed unless noted)

### The reader

LoadGraphicalCultureTypes (VA 0x849750, `ret 8`) is called once, at VA 0x6311E8 in CEU3Application::LoadEverything,
on the path `<common>/graphicalculturetype.txt` built at VA 0x62FBDA. TFH has no copy of its own; the base game's and
BlackICE's list German, British, Soviet, Us, Japanese, French, Italian, Generic.

- The file is a **plain list of names**, one per token, no keys.
- The database (g_GraphicalCultureTypeDataBase, VA 0x1A8C71C, 0x1C bytes) gets first the null type `noCultureType`
  (CNullGraphicalCultureType, index 0, a shared singleton at VA 0x1685638), then one CGraphicalCultureType (0x2C
  bytes) per name: name at +0xC, hash at +8, **index at +0x28 = 1, 2, 3 ... in file order**.
- Each is put in a name hash and in a vector at +0xC.
- A name given twice was not followed into the hash insert.

### A country's `graphical_culture` (CCountry::LoadKey, VA 0x4CCF0C)

- The name is looked up **exactly and case-sensitively** (StringHashFind_AtC, key at +0xC).
- If found, it is stored at CCountry +0xF20. **An unknown name is dropped without a word**, and the field keeps what
  it had.
- CCountry::AfterLoad (VA 0x4D2528): where +0xF20 is still null it looks up `Generic` and logs
  `No gfxculturetype set for <TAG>`.
- If the file lacked `Generic`, that lookup would answer null and CUnit_PictureCultureName would dereference it
  (inferred).
- +0xF20 has five uses in the image (constructor, LoadKey, AfterLoad x2, one reader), so it is **not saved** and comes
  from the country file.

### The one reader: CUnit_PictureCultureName (VA 0x5BDBE0)

1. The country is the first brigade's builder, else its owner, overridden by the unit's expeditionary owner (+0x290)
   where set.
2. It answers `country->graphical_culture->name`.
3. With no brigade or no country id it answers the global string `Generic` (g_GenericCultureName, VA 0x170D8C8).

Its one caller, CUnit::RebuildAvatar (VA 0x5BDD21), hands that name on:

- **The 3D figure** (CUnit::CreateAvatar, VA 0x5BC550). The tries, in the order the code makes them:
  1. `<TAG>_<brigade type>_<model>_actor`, down through the earlier models;
  2. **`<culture><sprite>`**, where sprite is the first brigade's unit type `sprite` (CSubUnitDefinition +0x198):
     `GermanInfantry`;
  3. `Generic<sprite>`;
  4. `GenericInfantry`, with the log line "Missing avatar graphics for type".

  All are looked up among the graphics' object types, which `tfh/interface/avatars.gfx` declares (GermanInfantry,
  BritishInfantry ... GenericInfantry). The order of the first tries is read from the literals (inferred).
- **The gun and helmet** (CHoiAvatar_SetCulturePart, VA 0x84A990): `<culture><part>`, else `Generic<part>`. It is
  reached through wrappers at VA 0x84A890 (`GunNode`, slot 1) and VA 0x84A910 (`HelmetNode`, slot 0); RebuildAvatar
  passes parts such as `Gun2`. avatars.gfx declares GermanGun1/2, GermanEliteGun1, GermanCavalryHelmet1, GenericGun1-3
  and the rest. What happens after the lookup was not read (inferred).

**Not used:** the counters. Their sprite is `GFX_small_counter_<key>` / `GFX_map_counter_<key>` with no culture in it
(FINDINGS-counters.md). Nothing else reads +0xF20, and no Lua binding mentions a culture. The index at +0x28 has no
reader found; it was not looked for, being a disp8 offset.

### What this means for OpenHOI3

The map always shows counters there (compatibility entry 12), so a graphical culture changes nothing on screen. A
reimplementation that wanted to report bad data could warn on an unknown `graphical_culture` name, which the original
drops silently.

[mod: common/graphicalculturetype.txt, a country file's `graphical_culture`, interface/*avatars*.gfx; exe: the naming
patterns and the `Generic` fallback]

## Not established

- That chatfonts.gfx and core.gfx fall in the same folder listing, and so the global table's contents in TFH and
  BlackICE (section 1). The BlackICE `§Y` check above settles it.
- DrawTextWithAlpha's callers and its arguments other than text, format, maxWidth and alpha.
- CGraphicalCultureType's slot 6 (VA 0x849510), which builds some text from the name; it was not read to its end.
- What 0xA78690 does with a name given twice in graphicalculturetype.txt.

## In the record

Entered in `ghidra/project.json` by `fragments/merged/font-terrain-colours.json`: ten functions new, six revised -
`CEU3BitmapFont::DrawText` and `::LoadKey` (where `colorcodes` and `color_override` go), `LoadCountryColors` (stored,
read by nothing), `CUnit_PictureCultureName` (the 3D figure's, not the counter's; `inferred` to `confirmed`) and
`CUnit::CreateAvatar` (the `<culture><sprite>` lookup) - four globals, three structs declared and fifteen fields.
