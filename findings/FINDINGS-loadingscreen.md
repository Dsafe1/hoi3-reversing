# The loading screen: what it draws and when

*Read statically on 2026-11-11, from the install's `hoi3_tfh.exe` and a copy of `Hoi3_v12.1.2`, for OpenHOI3's loading
screen. Fragment `loading-screen.json`. Addresses are rvas unless marked VA (VA = rva + 0x400000). **[exe]** is hardcoded;
**[mod: file]** is changed by a file. Everything is `confirmed` unless marked otherwise.*

**In one line.** The loading screen is not a screen object but one routine, `CGraphics::DrawLoadingText` (0x440E90),
called synchronously by the loading code. Each call clears to black, draws one picture on a width × width square centred
on the screen, draws `gfx/load_textbg.dds` as a 600 × 104 strip near the bottom, writes the line centred over it in
`Loading_Font`, and presents. Nothing moves between calls; a line replaces the one before; there is no bar or percentage.

## 1. Which picture

**Loading** (`CEU3Graphics::LoadLoadingScreens`, 0x440C70), once, as the last act of `CEU3Graphics::CEU3Graphics`: the
folder is listed with `ListFilesWithExtensionSorted(out, "gfx/loadingscreens", "dds", newestFirst = false)` -
`PHYSFS_enumerateFiles` over the whole search path, names ending in `dds` case and all, **not** sorted by date. The union is
the install's `gfx/`, `tfh/gfx/` and a mod's; a name in two places counts once, in name order (PhysFS's semantics,
*inferred*). In TFH that is `load_1` … `load_6` (`gfx/` has 1–5, `tfh/gfx/` 1, 3, 4, 5, 6); BlackICE ships `load_1` …
`load_6` too. Each is loaded by `LoadTextureFromFile` (0x23AB50) at D3DX defaults, so a 1024 × 1024 file stays so; only
those that load are stored, packed from slot 0. The names are found, not hardcoded **[mod: any `*dds` in
`gfx/loadingscreens`]**.

**Choosing one: no random generator.** The constructor sets the index (+0x6BDC8) to 0 just before loading; a call with
`nextPicture` adds 1 and **clamps** at the last picture; every full frame walks the index past null slots, wrapping to 0,
before drawing. Seven call sites pass `nextPicture` (section 3).

**After startup only the first survives.** `CEU3Graphics::ReleaseLoadingScreensButFirst` (0x440DF0), called from
`CFrontEnd::Enter` after `InitialiseGraphicalMap` on every entry to the front end, releases slots 1..n-1; nothing reloads
them (`LoadLoadingScreens` has one caller). **Every loading screen after the first main menu shows slot 0** - `load_1.dds`
- entering a game and every return to the menu; the null walk lands there.

**Placement [exe].** A triangle fan under `D3DXMatrixOrthoLH(width, height, 0, 1)` centred on the origin, its half
extents two function statics (0x1BEBBC4, 0x1BEBBC0) set on the first call and never again - **both `screen_width / 2`**,
integer division. So the picture is **a square whose side is the screen width, centred**, u 0→1 left to right, v 0 at the
top: on a landscape screen it fills the width and is cut equally at top and bottom - at 1920 × 1080 the square is 1920 ×
1920, 420 px cut from each edge, rows 224–800 of a 1024 texture visible; a portrait screen gets black bars. Magnification
LINEAR, minification whatever the device holds (*not read*). The statics go stale on a resolution change mid-run, and
nothing corrects the D3D9 half-texel offset. The second read of the width (VA 0x8411C2, `8b 86 bc b9 06 00`, as for x) looks
like a slip for the height and is the original's behaviour.

## 2. The progress line

`DrawLoadingText(text, fullFrame, nextPicture)`, `__thiscall` on the graphics, `ret 0xC`:

1. Nothing unless `IsDeviceReady` (0x6759D0, `TestCooperativeLevel`) answers true **and** `load_textbg.dds` loaded -
   without that file there is no loading screen at all, and no in-game overlay lines either.
2. Every call logs `Load text  <text>` (eu3graphics.cpp:250).
3. The font `Loading_Font`, looked up once in the `fonts` registry then `bitmapfonts`, kept at +0x6BDA0. The install's, in
   `interface/core.gfx`: `font = { name = "Loading_Font" fontname = "Arial" height = 32 charset = "ANSI" color = 0xffffffff }`
   **[mod: interface/core.gfx]**.
4. **fullFrame**: world and view to identity, `BeginScene`, `Clear` (target, z, stencil) to opaque black; the picture
   (section 1); the projection to `D3DXMatrixOrthoOffCenterLH(0, width, 0, height, 0, 1)` - pixels, y up from the bottom;
   alpha blending on (SRCALPHA / INVSRCALPHA), colour and alpha MODULATE, and `gfx/load_textbg.dds` drawn **from x =
   width/2 − 300 to width/2 + 300, and from 4 to 108 px above the bottom edge** - 600 × 104, the file's own size [exe: 300,
   4 and 108; mod: the file]. Then the text through the font's slot 8: format 2 (centre), orientation 4 (CENTER), x 0, y
   height − 108, maxWidth = width, maxHeight 100, border 0, area {1,1}. `EndScene`, and `Present` while `device_ready` is
   set; a DEVICELOST answer clears it.
5. **Not fullFrame**: only the text, with a zero box, into whatever frame the caller renders (3.3).

**Where the text lands, for a TrueType font** (`TrueTypeFont_DrawText`, 0x71D620, a `font = {}` object's slot 8; a
`bitmapfont` named `Loading_Font` would go through `CEU3BitmapFont::DrawText`, not worked out for this box): the box runs
from (0, height − 108) to (width, height − 8) in top-down pixels, drawn `DT_CENTER | DT_VCENTER | DT_WORDBREAK |
DT_NOCLIP` in the font's colour (+0x70) through a shared `ID3DXSprite` with `ALPHABLEND | SORT_TEXTURE` - **centred across
the whole screen width and vertically in a 100-px band starting at the strip's top edge**; one line's middle is height −
58. Whether `DT_VCENTER` holds for more than one line (CALC_PATHS has a `\n`) is *inferred*. The font is made by
`TrueTypeFont_CreateDeviceFont` (0x71B660): height the file's (32), weight 500, `OUT_TT_ONLY_PRECIS`,
`ANTIALIASED_QUALITY` [exe], face `fontname`, charset EASTEUROPE for l_polish (4) and ANSI otherwise [exe]. Whether the
file's `charset` key is read was not checked; the § colour escapes are the bitmap font's and do nothing here.

**One frame a call.** `CREATING_PROVINCE` ("Creating Province #") is shown **once**, before its loop, with nothing
appended - the `#` stays as written.

## 3. When it shows, and with what

The 30 direct callers, read site by site, flags written (fullFrame, nextPicture); "adv" marks the seven that advance.

### 3.1 Startup

From `CEU3Application::LoadEverything`, then `CFrontEnd::Enter`. The first picture shown is **slot 1**, the first call
advancing.

| # | key (English) | flags | where | picture, TFH's six |
| --- | --- | --- | --- | --- |
| 1 | LOADING_MAP_SPRITES "Loading Map-Sprites..." | 1,1 adv | LoadEverything, the .gfx stage | load_2 |
| 2 | LOADING_GUI_DEF "Loading GUI Definitions..." | 1,0 | the .gui stage | load_2 |
| 3 | LOADING_DATABASES "Loading Databases..." | 1,0 | LoadCommonFiles (0x2348F0) | load_2 |
| 4 | INIT_MAP_LOGIC "Initialising Maplogic..." | 1,0 | the same | load_2 |
| 5 | CALC_PATHS "Calculating paths...\nThis may take several minutes." | 1,0 | CMap::LoadMapFiles, **only with the map cache stale** | load_2 |
| 6 | LOADING_DATABASES2 "Loading Databases II..." | 1,0 | LoadCommonFiles | load_2 |
| 7 | LOADING_HISTORY "Loading History Files..." | 1,1 adv | the same | load_3 |
| 8 | LOAD_EVENTS "Loading Events..." | 1,0 | LoadEverything | load_3 |
| 9 | LOADING_SOUNDS "Loading Sounds..." | 1,0 | the same | load_3 |
| 10 | PROC_FLAGS "Processing Flags..." **or** LOAD_FLAGS "Loading Flags..." | 1,0 | FlagTextureMap_Build, by 0x4417E0's answer (*inferred*: whether the flag atlas is rebuilt) | load_3 |
| 11 | CREATING_CHKSUM "Creating Checksum..." | 1,1 adv | CEU3Application::CreateChecksum | load_4 |
| 12 | LOAD_GFX "Loading Graphics..." | 1,0 | CFrontEnd::Enter | load_4 |
| 13 | CREATING_PROVINCE "Creating Province #" | 1,0 | CProvinceManager_CreateProvinceObjects (0x456AB0) | load_4 |
| 14 | CREATING_BORDERS "Creating Borders..." | 1,0 | CProvinceManager_CreateWorld | load_4 |
| 15 | CREATING_TEXTS "Creating Texts...." | 1,1 adv | the same | load_5 |
| 16 | CREATING_TREES "Creating Trees..." | 1,0 | the same | load_5 |
| 17 | CREATING_RIVERS "Creating Rivers..." | 1,0 | the same | load_5 |
| 18 | CREATING_THE_WORLD "Creating the World..." | 1,1 adv | the same | load_6 |
| 19 | `CREATE_WAVES`, **the raw key** (its localisation "Creating Waves" never looked up) | 1,0 | CProvinceManager_CreateMeshes, only with the `waves` setting on and the manager's +0x4164 set | load_6 |
| — | `Creating texture for Quad <n>`, raw, once per land tile | 1,0 | CreateTerrainOffsetTexture, only where a tile's `quad_texture_<n>.dds` is made (`FINDINGS-mapcache.md`, E) | — |
| 20 | MAP_PROPERLY_INIT "Map Properly Initialised..." | 1,0 | CProvinceManager_CreateWorld | load_6 |

After line 20, `CFrontEnd::Enter` builds the panels and releases pictures 1..n-1, and the run loop's first front-end frame
replaces the loading screen. With the base game's five files alone, lines 18–20 stay on load_5, the advance clamping.

Rows 13–20 run **only on the first front-end entry**: `InitialiseGraphicalMap` builds the world only while the
application's +0x124 is null. Inside `CreateWorld`: beach manager → CREATING_PROVINCE → CREATING_BORDERS (the border
manager, then the 50-px tiles) → CREATING_TEXTS (province names) → CREATING_TREES → CREATING_RIVERS → CREATING_THE_WORLD
(meshes, terrain textures, waves) → MAP_PROPERLY_INIT (the cache stamp, the time file, clean-up). The `.fx` shaders,
terrain textures and beach manager are built **under the LOAD_GFX line**, before CREATING_PROVINCE.

### 3.2 Entering a game, loading a save, returning to the menu

- **Play, or a quickstart**: `CFrontEnd::LaunchGame` installs the in-game screen; while `launch_requested` is set the front
  end's render returns at once, so the last menu frame stays frozen until the in-game screen's Enter. `CInGameIdler::Enter`
  then shows **LOAD_GFX (1,1 adv), LOAD_EVENTS (1,0), ADAPTING_HISTORY "Adapting History..." (1,0)** in that order, on a
  straight path - for a new game and a loaded save alike. The events are read again here (`GetEventList`, `LoadEvents`).
  "Adapting History..." stays for the rest of Enter - the per-country passes, the new game's set-up - until the first
  in-game frame. The picture is load_1 (section 1).
- **Loading a save** happens in the lobby as its row is chosen (`LoadSaveFile` from `CGameSetup::Update`,
  `FINDINGS-frontend.md` B.3), and **no loading screen is drawn** - `LoadSaveFile` has no call to it. `LOADING_LOCAL_SAVE`
  "Loading local savegame copy..." is a line in the lobby's chat (`CGameSetup` 0x312580), not the loading screen's.
- **Back to the menu**: a new `CFrontEnd`, whose Enter shows LOAD_GFX (1,0) over load_1 until the menu's first frame; no
  CREATING_* lines, the world existing.

### 3.3 The overlay lines (not fullFrame)

`CInGameIdler_Render` draws AUTOSAVING, SCREENSHOT_TAKEN and MAP_SAVED, and `CFrontEnd_Render` SCREENSHOT_TAKEN, into the
frame being rendered - centred on the screen in Loading_Font, no picture or strip: the zero box becomes (0, 0, width,
height) with `DT_CENTER | DT_VCENTER`. When each is up was not read. The map editor's `CNudgeIdler` draws the raw
`Nudge nudge... ` as a full frame (1,0).

## 4. What else

- Nothing else is drawn: no version string, no tips, no logo.
- **The intro movies are a separate program.** At the very start, after the user folder is mounted and before the
  application exists, `RunBinkMovie` (0x6563E0) runs `movies\binkplay.exe movies\paradox.bik /C /I2 /R /D508 /B2`, then
  `... game_intro.bik ... /D509 ...`, each time waiting, polling every 2 s, until the player exits it. What might skip them
  was not looked for [exe: the command lines; the files are `movies/`'s].
- **Music**: the title theme is started in LoadEverything's sound stage, before the first loading frame, and plays under
  the startup loading screen (`FINDINGS-music.md`, section 4).

## 5. Corrections

- `CGraphics::DrawLoadingText`'s entry said its flags and drawing were not read, `inferred`; read whole now, `confirmed`.
- Nothing else contradicted: `FINDINGS-startup.md`'s "nine progress keys" and `FINDINGS-frontend.md` A.1's "shows the
  LOAD_GFX line" stand.

## 6. Not established

- `IsDeviceReady`'s reset arm, after "Used video memory before alt tab:".
- Whether `ID3DXFont` centres multi-line text vertically under `DT_VCENTER`.
- The minification filter on screens narrower than 1024.
- What 0x4417E0 tests (PROC_FLAGS or LOAD_FLAGS).
- When the overlay lines show; whether a `font` block's `charset` key is read.
- The two `CGraphics` calls in `CInGameIdler::Enter` between LOAD_GFX and LOAD_EVENTS (0x670D80, 0x670C50).
- A lead for `FINDINGS-startup.md` §12: Ghidra puts the movie calls and `main.cpp`'s log sites in one function from VA
  0xA56470, perhaps `main`'s entry; not recorded.

Frontier: 0x44AFB0, 0x6B8CD0, 0x4417E0, 0x670D80, 0x670C50, 0x30D3E0, 0x240600, 0x656470.

## Mechanics, without addresses

1. **The pictures**: every file ending `dds` in `gfx/loadingscreens`, over the whole layered file system - base, expansion,
   mod - one a name, in name order (*inferred*). Mod-able; the folder's name is hardcoded.
2. **No randomness**: the index starts at 0, seven lines step it, clamping at the last. Hardcoded.
3. **The lines that step it**: LOADING_MAP_SPRITES, LOADING_HISTORY, CREATING_CHKSUM, CREATING_TEXTS and CREATING_THE_WORLD
   at startup, and LOAD_GFX on entering a game - so the first startup frame shows the second picture. Hardcoded.
4. **After the first main menu only the first picture is shown** - entering a game, returning to the menu. Hardcoded.
5. **Geometry**: a square of side the screen's width, centred, the texture stretched over it; a landscape screen cut
   equally top and bottom; black behind. Hardcoded.
6. **The strip**: `gfx/load_textbg.dds`, alpha-blended, 600 × 104, centred across, its bottom edge 4 px above the screen's.
   Place and size hardcoded, the picture mod-able; without the file no loading screen at all.
7. **The text**: `Loading_Font`, among `font` entries first, then `bitmapfont`; the install's Arial, height 32, white,
   antialiased, weight 500. Mod-able in `interface/core.gfx` (`fontname`, `height`, `color`); weight, antialiasing and
   charset (East European for Polish, else ANSI) hardcoded.
8. **The text's box**: the screen's whole width, from 108 px above the bottom to 8 px above it, centred both ways,
   word-wrapped. Hardcoded.
9. **One line at a time**: each line clears and redraws the whole frame; nothing accumulates or animates. Hardcoded.
10. **"Creating Province #"** is shown once with no number. Text mod-able (CREATING_PROVINCE), behaviour hardcoded.
11. **Startup's order**: LOADING_MAP_SPRITES, LOADING_GUI_DEF, LOADING_DATABASES, INIT_MAP_LOGIC, [CALC_PATHS with the map
    cache stale], LOADING_DATABASES2, LOADING_HISTORY, LOAD_EVENTS, LOADING_SOUNDS, PROC_FLAGS or LOAD_FLAGS,
    CREATING_CHKSUM, LOAD_GFX, CREATING_PROVINCE, CREATING_BORDERS, CREATING_TEXTS, CREATING_TREES, CREATING_RIVERS,
    CREATING_THE_WORLD, [the raw `CREATE_WAVES` with waves on], MAP_PROPERLY_INIT. Order hardcoded, texts mod-able.
12. **A map-cache rebuild** shows the raw "Creating texture for Quad N" once per land tile whose texture is made. Hardcoded.
13. **Entering a game**, new or loaded: the menu's frame frozen, then LOAD_GFX, LOAD_EVENTS, ADAPTING_HISTORY, the last
    standing until the game's first frame. Hardcoded.
14. **Loading a save** in the lobby shows no loading screen; the lobby's chat gets status lines. Hardcoded.
15. **Back to the menu**: LOAD_GFX over the first picture, then the menu. Hardcoded.
16. **In-game notices** - AUTOSAVING, SCREENSHOT_TAKEN, MAP_SAVED, and the menu's SCREENSHOT_TAKEN - in the same font,
    centred on the screen, no picture or strip. Font and texts mod-able, placement hardcoded.
17. **Before the loading screen** the Paradox and intro Bink movies play in an outside player. Command lines hardcoded,
    files in `movies/`.
18. **The title theme** starts before the first loading frame (master volume above 0) and plays through the startup load.
    Path hardcoded.
