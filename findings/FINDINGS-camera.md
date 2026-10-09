# The map camera, and what moves it

Worked out to give BiceLib an option that stops the map scrolling when the mouse reaches
the edge of the screen. The patch is `BiceLib/GameState/MapEdgeScroll.cpp`; this is how it
was found and why it lands where it does.

**The game has no setting for it.** `settings.txt` carries `scroll_speed`, but that is the
speed of *all* scrolling - turn it down and the arrow keys and the middle button drag slow
with it. There is no key for the edge on its own, in the game's settings or the mod's.

## Where the camera is

`CInGameIdler::CentreOnProvince` (`0x24C0E0`, virtual slot 48) is what the unit panel's
`unit_location_button` calls, and it was the way in: it takes a province and writes a
camera. The camera it writes comes from slot 28, whose whole body is

    lea eax, [ecx + 0x1938]
    ret

so **the camera is held by value inside the idler**, at `CInGameIdler + 0x1938`, and that
getter hands back its address. It has no vftable, so the RTTI export does not name it;
`MapCamera` is a name given here for what it holds.

| Offset | Holds | |
| --- | --- | --- |
| `+0x324` .. `+0x330` | the screen rectangle the map is drawn in: left, top, right, bottom | read |
| `+0x334`, `+0x338` | where the camera looks, in map coordinates - what all scrolling adds to | read |
| `+0x33C`, `+0x340` | a second copy of the pair above | read, meaning inferred |

The second pair is written by copying the first straight into it, by both
`CentreOnProvince` and the camera's own setup (`0x25CEC1`). Both of those are moves that
should happen at once rather than be eased into, which reads as the settled position
against the one being headed for - **but which of the two the renderer takes has not been
checked**, so nothing should be built on the direction.

Finding it took `--holder` style narrowing rather than a plain search: `+0x334` alone has
610 operands in the image, while `+0x1938`, the camera inside the idler, has twelve.

## What moves it

`UpdateMapCamera` (`0x23C520`) runs once a frame and does all of it. ESI is the camera,
EDI the object the mouse position is asked of, and the first stack argument the one key
states are asked of. In order:

1. dragging with the middle button, which works through the map projection rather than the
   screen;
2. the arrow keys - VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN, each `[keys]->vf_0x24(vk)`;
3. **the four screen edge tests**, below;
4. clamping the result to the camera's limits.

It ends `ret 0x10` but also takes two objects in registers, so it is left without a
signature in `project.json` rather than given a half-placed one - see the entry.

## The four edge tests

From `0x23CE97` to `0x23CFB5`, one per edge, each the same shape:

    mov  edx, [edi]              ; the mouse object's vftable
    mov  edx, [edx + 0x4C]       ; its "where is the mouse"
    lea  eax, [esp + 0x24]
    push eax
    mov  ecx, edi
    call edx
    mov  ecx, [esi + 0x328]      ; edge_top, then bottom, left, right
    add  ecx, 6                  ; the band that counts as "at the edge"
    cmp  [eax + 4], ecx          ; the mouse's y, or x for the other two
    jge  <past it>
    ...                          ; camera y += speed

Six pixels, and the mouse position arrives as a pair of ints with x at `+0` and y at `+4`.

**Nothing else is in that range**, so a five byte jump from the first byte to `0x23CFB5`
removes all four and leaves the keyboard and the drag untouched. The two instructions it
replaces - `mov edx,[edi]; mov edx,[edx+0x4C]` - are exactly five bytes, so nothing is
left half overwritten and no NOP is needed.

**The check that makes jumping over a range safe** is that nothing enters it partway.
`cfg.py --lands-in 0x63ce97 0x63cfb5` says every branch into it targets the first byte:

    0x0063CD01  je  -> 0x0063CE97      0x0063CEB1  jge -> 0x0063CEDF   (a test skipping itself)
    0x0063CD14  jne -> 0x0063CE97      0x0063CEF9  jle -> 0x0063CF27
    0x0063CD25  jne -> 0x0063CE97      0x0063CF40  jge -> 0x0063CF6E
    0x0063CD3D  je  -> 0x0063CE97      0x0063CF87  jle -> 0x0063CFB5   (the end)
    0x0063CE91  jne -> 0x0063CE97

Five ways in, all to the same byte; everything else is one of the four skipping its own
body. That is the fact the whole approach rests on, and it is worth re-running if the
range is ever revisited.

## How high it is, and what that decides

Read on 2026-10-09 for the rewrite, after the maintainer's word that the original has "2
modes, the close and far", and that "in the far only the map shows, no counters or
buildings". Addresses in this section are **VAs**.

**The camera hangs straight over the point it looks at, and its one figure is its height.**
`MapCamera_Construct` (`0x63C1D0`; the graphics object in ECX, the camera on the stack,
`ret 4`) builds it on `Camera_Construct` (`0xABE270`: `(camera, fovY, aspect, near, far)`,
`ret 0x14`), which calls `D3DXMatrixPerspectiveFovLH`:

| | | |
| --- | --- | --- |
| field of view, top to bottom | **0.785 radians** | the float at `0x160AA58` |
| aspect | the screen's width over its height | the graphics object's `+0x6B9BC` / `+0x6B9C0` |
| near, far | 8 and 1200 | `0x160A664`, `0x160AA5C` |

and then fills in:

| offset | | |
| --- | --- | --- |
| `+0x2E8` | the eye, three floats | `(0, height, 0)`: `UpdateMapCamera` writes the height into the middle one and zeroes the others |
| `+0x2F4` | where it looks, three floats | `(0, -8, 0)` with `always_counters` on; `(0, 12, 30)` with it off - `MapCamera_SetAim`, `0x63D400` |
| `+0x344` | the height wanted | 330 at the start (`0x160AA50`) |
| `+0x348` | **the height** | 330; it follows `+0x344` by 0.197 of the difference a frame, or at once where the settings' `+0x188` is set |
| `+0x34C` | the lowest height, an int | **40**: the constructor stores 50 and `MapCamera_SetAim` then overwrites it with the float at `+0x35C`, which is 40 (`0x171DBB4`) |
| `+0x350` | the highest, an int | **1000** |
| `+0x365` | a copy of the settings' `always_counters` | |

So with counters only - `always_counters` - the camera looks **straight down**, and a pixel of
the screen is the same length of map anywhere on it; with figures it leans north, the more
the lower it is. From a height `h` it sees `2 h tan(0.785 / 2)`, which is `0.828 h` map units,
from the top of the screen to the bottom.

**What the height decides**, each a compare of `+0x348`:

| against | where | what |
| --- | --- | --- |
| **500** (the double at `0x160A538`) | `ProvinceGraphics_HitTest` (`0x640F40`): the counters and building pictures of a province are asked about a click only at 500 or under | the far view takes no clicks on them |
| 500 | `0x640DA0`, the same test for a province's battles | |
| 500 | the frame routine `0x656E10`, already recorded: the hierarchy lines are drawn only under 500 | |
| **`counter_distance`** (settings `+0xFC`, 100 in a new game) | `0x641950`, the scene's draw: the figures (`0x85BB60`) are drawn only **under** it, with the settings' `+0x58` and bit 4 of the rendering word | above it a unit is a counter whatever the settings say |
| `counter_distance` | `ProvinceGraphics_HitTest`: above it the province's current unit is taken from its list instead of by its figure | |
| `counter_distance` | the frame routine: the hierarchy lines are drawn above it, or under it with `always_counters` | |
| 100 (the double at `0x160A358`, not the setting) | `0x6418B0`: under it something is drawn with `(height - lowest) / (highest - lowest)` handed to it | not followed |

**So there are three bands**, by the camera's height: under `counter_distance` the near view
- figures, or with `always_counters` the near counter; from there to 500 the counters seen
from far; and **from 500 up the far view**, where nothing on the map answers a click and the
hierarchy is not drawn. That nothing is *drawn* there either is the maintainer's word; the
compare that hides the counters and the buildings was not found, only the ones that stop
their clicks and their lines.

The same arithmetic places the maintainer's screenshot of a near counter
(`FINDINGS-counters.md`, section 8): 14.6 pixels to a map unit is a height of 89 on a screen
1080 high, under 100.

## What is still open

The zoom and rotation arithmetic in the same function, and the two unidentified stack
arguments it takes. Neither matters to the scrolling. Of the height: what draws or hides a
counter and a building's picture by it, who tells a unit's avatar it is seen from far
(`FINDINGS-counters.md`), what `0x6418B0` draws, and the two `large_` pictures a province
keeps for its bases, which `ProvinceGraphics_HitTest` asks at any height.
