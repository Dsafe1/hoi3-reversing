# How a tooltip is shown

Read for OpenHOI3's tooltips, 2026-10-11: the box a tooltip is drawn in, what is asked each
frame, the delay before the second half of a tooltip, the separators, the wrapping, where the box
goes and what keeps it on screen. **What each screen's tooltips say is not here** - that is a
reading per screen, and the routines it starts from are listed in section 9.

Every address is a VA of this build; the record holds rvas.

## 1. The box

One text box, made once, shows every tooltip. `interface/core.gui` declares it, in the base
game's copy and in `tfh`'s:

    textBoxType={
        name = "ToolTip"
        textureFile = "gfx\\interface\\tiles_dialog.tga"
        font = "Arial14"
        borderSize = { x=16 y=16 }
        position = { x= 560 y=10 }
        maxWidth = 400 #320
        maxHeight = 256
    }

`CEU3Idler::Enter` (`0x6444E0`, `CEU3Idler` slot 3) makes it by that name through the gui's slot 14
(`"ToolTip"` is pushed at `0x644508`), keeps it at **idler `+0x5C`**, and hides it. Both idlers
make their own this way: `CInGameIdler::Enter` calls it at `0x65D416` and the front end's slot 3
at `0x6EF7BE`. `confirmed`.

Its font is not `ToolTip_Font` - that is the console's (`FINDINGS-text.md`).

## 2. Each frame: `CEU3Idler::UpdateTooltip` (`0x644B60`)

`void __stdcall (CEU3Idler* idler)`, `ret 4`. Called from `CInGameIdler::Update` at `0x656702`
and from the front end's slot 1 at `0x6EE8F9`, so it runs every frame of either. In order, `confirmed` off
the listing:

1. **The mouse** is read from the input object at idler `+0x64` (its slot 19, twice - y off the
   first answer, x off the second) and turned into two floats.
2. **The tooltip** is asked for: idler slot 20 into a local `GuiTooltipText` (section 7). Its
   `text` is copied out.
3. **The still time.** When the mouse is not where it was last frame (`0x1BEBA80`/`0x1BEBA84`,
   compared as doubles), the idler's clock (slot 21, then the clock's slot 5) is read and
   **truncated to a whole number** (`_ftol2_sse`) into `0x1BEA464`. The position is then saved.
4. **The delayed half.** The clock is read again and the stored whole number subtracted
   (`fisub`). Where that is **above 1** and `delayed` is not empty:

       text += "\n--------------\n" + delayed

   and again, where it is above 1 and `delayed_extra` is not empty:

       if text is not empty:  text += "\n--------------"
       text += "\n" + delayed_extra

   The dashes are fourteen, the literals at `0x15CD8A4` and `0x15CD8B8`.
5. **Nothing new, nothing done.** The result is compared (`0x4173C0`, string equality) with the
   string kept at idler `+0x40`; when equal, the box is left as it is and only placed (step 9).
6. Otherwise the result is **trimmed** of `\n`, `\t`, `\r` and space at both ends (`0xA5B4B0`, the
   set at `0x15FC548`) and kept at `+0x40`.
7. **Empty hides the box** (its slot 14).
8. Otherwise the text is **wrapped**: a text layout over the box's font (`0xACBB90`, the font found
   by name in the graphics' two font tables) is given a width of

       box +0xA8  -  3 * box +0xAC

   and a height of **2000**, lays the text out (its slot 21) and hands back the wrapped string
   (`0xACD050`). That string is set into the box with `0xA87FD0`,
   `GuiObject_textBoxType::SetTextToFit` - which, unlike `GuiObject_textBoxType::SetText`
   (`0xA87F30`), passes **0 for the height** where SetText passes
   the declared `+0xAA`, so the box grows to its text and is not held to `maxHeight`. The box is
   shown (slot 13). `+0xA8` is the word SetText passes as the width, `maxWidth`, and is not written
   here; that `+0xAC` is the border is `inferred` - it is passed beside it to both setters, and the
   tooltip's formula reads as "the width less the border on each side and some". With `core.gui`'s
   figures the text wraps at **352**.
9. **Placing it.** The tooltip's `position` (two shorts, x low) is the point. Where `below` is
   **false** the box's height is taken off y, so the box stands **above** the point; otherwise it
   hangs below. Then, against the screen's size (idler slot 22, `+8` and `+0xC`):

       if x + width  > screen width:   x = screen width  - width
       if y + height > screen height:  y = screen height - height

   **Nothing keeps it off the left or top edge.** The box is moved there (`0xA87D80`).

The local tooltip is destroyed at `0x644FB5`.

## 3. The clock behind the delay

Idler slot 21 returns a clock - the in-game idler's at `+0x192C`, the front end's at `+0x39C` -
made in `Enter` through slot 1 of the object at `0x174DA90` and started at once (slot 1 at
`0x65A928`). That global is **a platform factory**, and two kinds are put in it:

- `0xA56470`, called once from the runtime's start-up code (`0xB9882F`), builds a 0x18-byte object
  with vftable `0x1605328` (`0xB08500`) and stores it there at `0xA57374`. Its slot 1 (`0xB087A0`)
  makes a 0x30-byte clock (`0xB4F730`, vftable `0x16086C8`, the source file named
  `highprefwinclock.cpp`) that reads the performance counter: slot 5 (`0xB4FE80`) answers

      (counter now - counter at start) * scale + base

  with `scale = 1 / frequency` set in the constructor (`fld1; fdivrp` at `0xB4FA6C`) - **seconds**.
  A stopped clock answers its base, and a new one is stopped at 0 until its slot 1 runs.
- Every other writer of the global - **317 of them**, inlined into every user of the random
  generator - makes a 4-byte stand-in (vftable `0x15FDF60`) only **when the global is empty**. Its
  slot 1 (`0xA803C0`) makes a clock whose slot 5 is `fldz; ret` - always 0. With the real factory
  installed first, the stand-in is never made in a running game.

So **the record's `g_random_object` is that factory**, not "a lock or a debug hook holder": the
random functions only make sure it exists, `TextureHandler_ReloadEntry` asks it whether a file
exists (slot 9), and the idlers get their clocks from it. Its name is kept.

**The delay, then.** Step 3 truncates the moment the mouse stopped to a whole second of the clock;
step 4 asks whether the clock is now more than one past that. So the delayed half appears when
the clock passes the next whole second after the mouse came to rest - **anywhere from just after
the stop to one second after it**, depending on where in its second the stop fell. `confirmed`
for the arithmetic; it reads as a bug, and is what the original does.

## 4. What is under the mouse: `CInGameIdler::GetTooltip` (`0x6627D0`, slot 20)

`GuiTooltipText* __thiscall (CInGameIdler* this, GuiTooltipText* out)`, `ret 4`. `confirmed`:

1. **Tooltips switched off** - the byte `0x170AD31` is 0 - gives an empty tooltip. The byte starts
   at 1, and the console command **`tooltips`** flips it and says "Tooltips are now turned OFF." or
   "... ON." (`0x441723`).
2. **An interface element under the mouse** - the gui's `+0x98` - is asked for its tooltip through
   **slot 109** (section 5). Then, **when its `delayed_extra` is empty** and the element's slot 39
   answers a non-empty string - the button's shortcut - `delayed_extra` becomes the localised
   `SHORTCUT` followed by that string. `SHORTCUT` is "§WShortcut: §Y" in English; it is rendered
   once and kept at `0x1BEBD28`.
3. **Otherwise, the mouse over the map** (the input's slot 17): where a province is under the mouse
   (`+0x1DD4`) its own tooltip - slot 3 of `CProvince`'s second table, `ProvinceTooltip_Build`, the
   one that switches on the map mode - with **`below` false** and the point **50 to the left of the
   mouse and 20 above it** (the map camera's slot 24, then `-0x32` and `-0x14`). So a province's
   tooltip stands above the mouse, its bottom 20 short of it. The argument it is given is the
   `+0xC` of a row of the unit list when `+0x1DD0` is set; when it is not, the code reads `+0xC` of
   a null pointer - never reached, presumably, since the two are set together (`inferred`).
   Nothing under the mouse: an empty tooltip at 60 left, 20 up.
4. The result is kept in a static `GuiTooltipText` (`0x1BEBD48`) and returned; `0x1BEA490` and
   `0x1BEA494` keep the element or the province it came from. Nothing read here reads those two.

## 5. An element's tooltip: `CInGameIdler::GetElementTooltip` (`0x6C5290`, slot 109)

`GuiTooltipText* __thiscall (CInGameIdler* this, GuiTooltipText* out, CGuiObject* element)`,
`ret 8`. Gated on `0x170AD31` as well. It keeps the element at `+0x184` and asks, in order -
**each of these is a screen's own routine and none is read here**:

1. the list at `+0xD20`, for an entry whose slot 22 says the element is its own - that entry's
   slot 13;
2. the window at `+0x1358`, when shown, whose element test (slot 37 of `+0x18`) passes -
   `0x764F40`;
3. the window at `+0x135C`, likewise - `0x762670`;
4. `0x73BF20` on the window at `+0x1360`, `0x6D2E80` on `+0x1D48`'s, `0x6D1DE0` on `+0x1D4C`'s -
   each answers whether it filled the tooltip;
5. the view at `+0xD10`'s `+0x14`, through its slots 4, 6 and 8;
6. the orders view (`+0x160`), through its slots 5 and 6;
7. then **the element's name**, against some sixty literals - `strat_resources_label`,
   `player_flag`, `closebutton` ("CLOSE"), `mapmode_1` to `mapmode_16` (`MAPMODE_1` ...,
   `MAPMODE_7G` for the seventh), `zoom_in`, `zoom_out`, `button_home`, `button_goto`,
   `ledger_button`, `menu_button`, the multi-unit buttons and more;
8. and, when none matches, `0x6C43B0`: `topbar` (the top bar's own), the message categories, the
   speed buttons, `trait_icon` (the trait's name with its description in `delayed`), the practical
   icon `on_complete_icon` and `on_complete_impact` ("TC_BUILD_COST_AND_TIME" - "technology icons"
   here until `FINDINGS-buildertooltips.md`, section 3), `message_dialog` (`0x6446D0`, the open
   dialogs at idler `+0xA0`), and last `0x662C50` - the ledger's column headers (`+0x1CE0`; "the
   builder window's sort column" here until `FINDINGS-buildertooltips.md`, section 4), or the open
   country view's slot 10 - after which `text` and `delayed` are trimmed.

**The point** (`0x6C9471`), `confirmed` off the decompilation:

    point = element's slot 24 + the tooltip's own position     (most leave it 0)
    if below and point.y > 0.8 * screen height:   below = false      (the box stands above)
    else:                                          point.y += 64

The 0.8 is the double at `0x160A3E0` (`0.800000011920929`, a float widened). Slot 24 of a button
(`0xAA27A0`) truncates the float pair of the object at its `+0x88` - the drawable a button places
at its own `+0x90`/`+0x92` as it is set up - so **the point is the element's corner, not the
mouse**: a tooltip hangs 64 below the top of the element it belongs to, from its left edge, unless
that is in the lowest fifth of the screen, when it stands on the element's top. That the corner is
in screen coordinates and not its parent's is `inferred` - a tooltip would be misplaced on every
nested element otherwise.

## 6. The front end

`CFrontEnd` slot 109 (`0x6C4230`) answers only `gamesetup` (the game setup view's slot 6) and
`micro`, and places the point the same way. Its slot 20 (`0x6F0330`) was not read.

## 7. `GuiTooltipText`, with its fields' meaning

The record had the layout and placeholder names (`FINDINGS-uinumbers.md`, section 2). What each is:

| offset | was | is |
| --- | --- | --- |
| `+0x00` | `text` | shown at once |
| `+0x1C` | `second` | **`delayed`**: after the still time, under a line of fourteen dashes |
| `+0x38` | `third` | **`delayed_extra`**: after the still time too, under its own line when anything precedes it; where a button's shortcut goes |
| `+0x54` | `number` | **`position`**: two shorts, x low, y high - an offset the element's corner is added to, or the point itself on the map |
| `+0x58` | `flag` | **`below`**: true, the box hangs below the point; false, it stands above it |

## 8. The interface files' own tooltip keys

Every element accepts `pdx_tooltip` and `pdx_tooltip_delayed` (`CGuiType::LoadKey`, `0xAC8710`).
Each is **looked up in the localisation as the file is read** (`0xA86E40`) and the entry kept on the
type: `pdx_tooltip` at **`CGuiType +0x5C`**, `pdx_tooltip_delayed` at **`+0x60`**. A key the
localisation lacks builds the message "Couldn't find localization string: <key>" - **and frees it
without logging it**, so a misspelt key is silent. Buttons also take `tooltip`, `tooltipText` and
`delayedTooltipText` (`0xCF5390` registers them).

**Not one of those keys is given a value** in any `.gui` file of Their Finest Hour's or of
BlackICE's - every one is `""` or commented out (searched 2026-10-11). Every tooltip a player sees
is made by code, chosen by the element's name or the window it is in. Who reads `+0x5C` and `+0x60`
when the mouse is over an element was not read.

## 9. Where each screen's tooltips start

For the readings that follow, by screen - those already in the record by name, and the ones this
reading reached:

- the map: `ProvinceTooltip_Build` (`0x4973E0`), one arm per map mode;
- the top bar: `CTopBar::BuildTooltip` (`0x6CCB80`), through `0x6C43B0`'s `topbar`;
- the country views (production, technology): their slot 10 through `0x662C50` -
  `CProductionView::BuildTooltip` (`0x7FFD30`), `CTechTreeEntry::BuildTooltip` (`0x8193C0`),
  `CCurrentResearchEntry::BuildTooltip` (`0x816A10`);
- the builder windows: their slot 6, through `CProductionView::BuildTooltip` - read in
  `FINDINGS-buildertooltips.md`;
- a unit's panel and the battle's window: `0x764F40`, `0x762670`, `CCombatView::BuildTooltip`
  (`0x731120`), `CCombatView::BuildUnitTooltip` (`0x729D40`);
- the orders windows: `CNavalOrdersView::GetTooltip` (`0x73F660`), `CAirOrdersView::GetTooltip`
  (`0x7456C0`);
- the leader window: `0x7681C0`, `CLeaderAssignmentEntry::ElementTooltip` (`0x766060`),
  `CLeader::BuildTooltip` (`0x580220`).

## Not established

- **What the gui's `+0x98` is, exactly.** It is read as the element under the mouse because that is
  what is asked for its tooltip and its shortcut; its writer was not read.
- **Whether slot 24's corner is in screen coordinates** (section 5) - `inferred`.
- **What `+0xAC` of a text box is** - `inferred` the border.
- **How the layout at `0xACBB90` breaks lines** - at spaces, presumably, as the box's own layout
  does; not read.
- **Who reads `CGuiType +0x5C`/`+0x60`** at hover time. Moot while no file sets them.
- **`CFrontEnd` slot 20**, and the branches of section 5's steps 1 to 6.
