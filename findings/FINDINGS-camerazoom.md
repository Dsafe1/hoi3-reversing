# FINDINGS-camerazoom.md: how the map camera zooms

*Read 2026-11-12, statically, from the install's `hoi3_tfh.exe`. Trap 19's patched sites are not near any of this.
Addresses are **VAs** unless marked rva (rva = VA − 0x400000). **[exe]** means hardcoded in the executable;
**[mod: file/key]** means a file can change it.* The ease's constant, the ease's instructions and the wheel's gate were
checked again off the bytes by the collecting session the same day.

Asked for OpenHOI3, whose zoom was a fixed ×1.25 per notch applied instantly; the maintainer says the original's zoom
is smooth. **It corrects `FINDINGS-camera.md`** twice: the look point's pull is `zoomstep×20/height` of the distance,
not `1 − zoomstep×20/height` (that is the fraction *left*, 0.867, where 0.133 is moved), and there is no rotation in
`UpdateMapCamera` at all, so "the zoom and rotation arithmetic" it lists as open is the zoom alone, settled here. It also
moves `CDirectInputMouse::Poll` in the table: slot 8 of `0x16084D0`, not slot 23 of `0x1608494`.

## 1. One wheel notch

The wheel block is in `UpdateMapCamera` (`0x63C520`), from `0x63C7C3` to `0x63CB43`. ESI is the camera, EDI the mouse.

**It runs only when a wheel event reached the map this frame.** The test is `cmp byte [esi+0x354],0` at `0x63C7C3`; it
also requires `+0x355` to be clear (`0x63C7CF`). `+0x354` has exactly three byte stores in `.text`, found by searching
for `C6 8r 54 03 00 00`:

- `0x65384A`, in `CInGameIdler_HandleInput` (rva `0x252540`), sets it to 1;
- `0x6EE889`, in `CFrontEnd::Update`, sets it to 1;
- `0x63CB43`, in `UpdateMapCamera`, clears it each frame.

Both setters act only for an input event that is a mouse event (`+8 == 0`), is of kind 4 (`+0x14`, the wheel), and is
not already handled by the interface (`+0x18 == 0`). They skip it where `+0x355` is set. **So a wheel turned over a
window that takes it does not zoom.** `+0x355` has one writer: the `CFrontEnd` constructor (`0x6EDAC7`), straight after
`MapCamera_SetHeight(900)`. So the front end's map never zooms.

**Only the sign of the wheel is used** [exe]. The value is the mouse's slot 21 (`[edi]+0x54`), called at `0x63C7DB`,
`0x63C7EC` and `0x63C851`. The code tests only `eax > 0` and `eax < 0`; the size is never read. So it takes at most one
step per frame, however far the wheel turned. The slot is `Mouse_GetWheel` (`0xB4EA80`):
`mov eax,[ecx+0xA8]; imul eax,[ecx+0x84]; ret`.

- **DirectInput mouse** (table `0x16084D0`): `+0x84` is `DIMOUSESTATE.lZ` from the last `Poll`, and the scale `+0xA8`
  is 100.
- **Windowed mouse** (table `0x1608570`): `+0x84` is `WM_MOUSEWHEEL`'s delta / 100, truncated (`0xB4EEA7`..`0xB4EEC4`),
  and the scale is 1.
- The platform factory's slot 3 (`0xB08850`) makes one or the other according to the global at `0x1A857E0`. Its value
  was not read.

**The step** [exe constants, zoom_speed mod-able], read at `0x63C6F9`..`0x63C747`:

    s = float( float(height / 60 * 0.8) * zoom_speed / 100 )

Here `height` is the **current** height (`+0x348`), not the target, and `zoom_speed` is settings `+0x98`. The constants
come from the image: 60 at `0x160A4A8`, 0.8 at `0x160A3E0`, 100 at `0x160A358`.

- **Towards the map** (`eax > 0`, `0x63C7F9`..`0x63C849`): `wanted = wanted − s × 20 × 0.75` (20 at `0x160A318`, 0.75
  at `0x160A638`). If `lowest > wanted`, then `wanted = lowest`.
- **Away** (`eax < 0`, `0x63C85E`..`0x63C8AE`): `wanted = wanted + s × 20 × 1.5` (1.5 at `0x160A6B8`). If
  `wanted > highest`, then `wanted = highest`.

So a notch is **multiplicative on the current height**: −0.2·h·zoom_speed/100 towards the map and +0.4·h·zoom_speed/100
away. **At zoom_speed 50 (the default, and the maintainer's file): −10% and +20% of the current height.** At 100 it is
−20% and +40%. A notch out is twice a notch in. The step is taken off the target but sized by the current height, so
several notches on successive frames during an ease are each about the same absolute size (from the not-yet-moved
height), rather than compounding on the target (derived).

It is **a change of target, not of height.** Only `height_wanted` (`+0x344`) is written here; the height follows by the
ease (section 2). The ease runs later in the same frame, so the first 19.7% of the step lands on the frame of the notch.

## 2. The ease

**Height** (`0x63D25C`..`0x63D2EB`) [exe]:

- If `height == wanted` by an exact float compare (`ucomisd`, then `lahf / test ah,0x44 / jnp`, which skips only on
  equal), nothing happens.
- Otherwise, with `use_legacy_camera` (settings `+0x188`) set: `height = wanted`.
- Otherwise: `height = float( height + (wanted − height) × 0.197 )`, computed in double. 0.197 is the double at
  `0x160AA40`.
- Then the eye (`+0x2E8`) = (0, height, 0), and `+0x360` (moved) is set.

**Position** (`0x63D016`..`0x63D256`) [exe]: the same rule takes the drawn pair (`+0x33C/+0x340`) towards the target
(`+0x334/+0x338`) with the same 0.197. With `use_legacy_camera` set it copies at once. x is then wrapped by the map
width: target and eased both, and the drag anchor `+0x368` while a drag is on. The rule is `x < 0 → x + W`, otherwise
`fmod(x, W)` (`0xC0892A`).

**The ease is per frame and ignores the frame time.** The only time input, the fourth stack argument (`[ebp+0x14]`,
CInGameIdler `+0xA8C`, which is the frame timer's difference, `0x655A14`), is read at `0x63C74D` for the scroll step only.
Nothing between `0x63D016` and the `ret` reads it. So the ease's speed depends on the frame rate. The arithmetic
(derived): the remaining gap is 0.803ⁿ after n frames, so half the way takes 3.16 frames, 90% takes 10.5 and 99% takes
21. At 60 fps that is 53 ms, 175 ms and 350 ms.

**When it stops** (inferred from the arithmetic; not observed): the result is rounded to float. A gap of k units in the
last place moves by round(0.197·k), which is 0 for k ≤ 2. So the height normally stalls one or two ulps short of the
target, and the "differs" branch keeps running (and setting `+0x360`) every frame without visible change. Simulated in
float32 from 330 to 297, it stops at 297.00006, 2 ulps short.

**The renderer draws the eased pair** (this settles `FINDINGS-camera.md`'s open question). `MapGraphics_Update` (rva
`0x45C6F0`) reads `+0x340/+0x33C` at `0x85C7B2/0x85C7BA` and again at `0x85D8AD/0x85D8B9`, and reads `+0x348`. A
displacement search over VA `0x840000`..`0x880000` finds no read of `+0x334`; the positive control in that same search is
the function's reads of `+0x348`. `MapGraphics_DrawScene` hands `+0x33C/+0x340` to `CountryMapNames_Draw` (already
recorded).

## 3. Towards the pointer

At `0x63C8B6`..`0x63CB3B` [exe], with `use_legacy_camera` clear (`0x63C8BB`), the pull happens only if all of these hold:

- After the clamp, the wanted height is still **strictly inside** the limit it moved towards: away needs
  `highest > wanted` (`0x63C8EF`), towards needs `wanted > lowest` (`0x63C920`). So the notch that lands exactly on a
  limit does not pull.
- The pointer is more than 6 px inside all four edges: `y > top+6`, `y < bottom−6`, `x > left+6`, `x < right−6`, against
  `+0x324..+0x330` (`0x63C92A`..`0x63C9A2`).

The calculation:

1. `m` = the ground point under the pointer, from the current (eased) camera: CMap `0x492850`, at `0x63C9F9`.
2. Where the camera leans (the always_counters copy `+0x365` is 0), m's z is lowered by
   `(1 − (height − lowest)/(highest − lowest)) × CMap map_height (+0x2A78, 2160) × 0.02`, using 0.02 at `0x160A7D0`
   (`0x63CA0F`..`0x63CA87`). That is up to 43.2 map units at the lowest height.
3. `f = clamp(1 − s × 20 / height, 0, 1)` (`0x63CA93`..`0x63CAD0`).
4. `target.x = (target.x − m.x) × f + m.x`, and the same for y (`0x63CAD3`..`0x63CB3B`).

So the target moves **towards m by `s × 20 / height` = (4/15)·zoom_speed/100 of the distance**: 0.133 at 50, 0.267 at
100. It is independent of the height, and **the same on a notch out as on a notch in**. It is not an exact "point under
the cursor stays put". Worked arithmetic for the straight-down camera (`always_counters` on, the maintainer's setting): a
point at screen offset d ends at d·(1−p)/(1−a), where p is the pull and a the height change. Towards the map at 50:
0.8667/0.9 = 0.963, so the point under the cursor slides 3.7% of its offset towards the centre. Away at 50:
0.8667/1.2 = 0.722, so zooming out also pans 28% of the offset towards the cursor. Derived from the read formulas, not
observed.

A pull frame sets a local byte (`0x63C9B4`), which jumps from `0x63CB4C` straight to the ease at `0x63D016`. That frame
therefore skips the middle-button drag, the arrow keys, the edge scroll and the y clamp of the target
(`[+0x320, +0x314]`, `0x63CFB5`). The next frame clamps it.

Because target and current height both ease at 0.197 a frame, every intermediate frame is the same fraction of the way
in x, y and height together (derived). The motion is a straight line in (x, y, height), approaching geometrically.

**With `use_legacy_camera` set**: no pull, so the zoom is about the screen centre, and both eases jump at once.

## 4. Limits, and everything else that zooms

- **Lowest 40, highest 1000, start 330** [exe], as `FINDINGS-camera.md` has them. Both limits are ints. The clamps apply
  to **the target only**: at each wheel notch, at each zoom button, and at the always_counters change. The height has no
  clamp of its own and simply follows the target. `MapCamera_SetHeight` does not clamp.
- **`MapCamera_SetAim` runs every frame** (`0x63C6F4`). It sets the lowest height (`+0x34C`) to `int(+0x35C)` each frame,
  so the console's `minzoom N` (which sets `+0x35C`) takes effect on the next frame.
- **The always_counters change** (`0x63C569`..`0x63C5E7`) [exe]: where settings `+0xF9` differs from the copy `+0x365`,
  `wanted += float(float(wanted/20)×20) × 0.2`, held at or below the highest. That is the zoom-out button's step, and it
  eases like any other.
- **PAGE_DOWN / PAGE_UP**, the `map_zoom_in` / `map_zoom_out` buttons. These are `CInGameIdler::ZoomIn` (rva `0x2692A0`,
  re-read at `0x669392`..`0x6693FB`) and `ZoomOut` [exe]: `wanted −/+ float(float(wanted/20)×20) × 0.2`, held to the
  limit. That is a fifth of the **target**, independent of `zoom_speed`, with no pull, eased the same way. The shortcuts
  are [mod: interface `menubar` .gui `shortcut`].
- **'+' and '−' do not zoom.** `CInGameIdler_HandleInput` sends them to slots 25 and 26, recorded as the game speed
  (inferred there). No other key reaches `+0x344`.
- **Instant height changes** go through `MapCamera_SetHeight` (`0x63D350`; height in XMM0, camera in ESI). It sets
  wanted and height together. It has four callers:
  - the tutorial's `zoom` (`zoom = 200` in `tutorial/chapter1.txt`), via `CInGameIdler::DoTutorialAction`, `0x64B90C`;
  - the `CFrontEnd` constructor, 900;
  - `CFrontEnd::SelectBookmark`, 900;
  - `0x6F1D50`, which passes an int at `+0xE8` after setting the position; inferred to be a scenario's `camera_height`,
    not followed.
- `CentreOnProvince` and `MapCamera_JumpTo` write both position pairs, so they jump at once and leave the height alone.
- `UpdateMapCamera` is called by `CInGameIdler::Update` only while the byte at (global VA `0x174DAA8`)`+0xF2` is set and
  idler `+0x1CE0` is 0. It returns immediately while the graphics' device-ready byte (`+0x6BCA0`) is clear. No ease runs
  in those cases.
- `frozen` (`+0x356`) is tested only after the wheel block (`0x63CB52`), so it gates the drag and the scrolling but not
  the zoom. Whether a wheel event reaches the map while a country view is open was not established.

## 5. What a file can change

| figure | where | |
| --- | --- | --- |
| zoom_speed (scales the notch and the pull) | settings `+0x98` | **[mod: settings.txt `zoom_speed`]**, default 50 (constructor). Options slider 0..100, raised to 1 on Apply where ≤ 1; not clamped when read from the file |
| use_legacy_camera (no ease, no pull) | settings `+0x188` | **[mod: settings.txt `use_legacy_camera`]**, default no |
| always_counters (camera leans or not; lean term in the pull) | settings `+0xF9` | **[mod: settings.txt `mapRenderingOptions.alwaysCounters`]** |
| 60, 0.8, 20, 0.75, 1.5, the pull's 20 | `UpdateMapCamera` | [exe] |
| 0.197 ease per frame, both height and position | double at `0x160AA40` | [exe] |
| 0.2 per button / always_counters step | double at `0x160A260` | [exe] |
| lowest 40 | float at `0x171DBB4` → `+0x35C` | [exe]; console `minzoom` changes it live |
| highest 1000, start 330 | `MapCamera_Construct` | [exe] |
| 6 px edge margin for the pull | `UpdateMapCamera` | [exe] |
| lean term 0.02 × map height | `0x160A7D0` × CMap `+0x2A78` | 0.02 [exe]; the map height comes from the map files |

**Negative, with its search:** `grep -i "zoom|camera|height"` over `map/default.map` and `common/defines.lua`, in both the
install root and `tfh/`, finds only `border_heights` and `terrain_sheet_heights` in `default.map`. Neither is read by the
zoom. `UpdateMapCamera` reads the settings object at four offsets only: `+0xF9`, `+0x98`, `+0x90` and `+0x188`. It reads
no define (it never calls `GetDefines`, whose singleton is `0x1A86040`). `camera_rotation_speed` (`+0x94`) is not read
here, which agrees with `FINDINGS-settingswindow.md` C.5's scan.

## 6. Rotation

**There is none.** `UpdateMapCamera`'s only direct calls are `GetGameSettings` (`0x45FF30`); `operator new` and the lazy
`CCurrentGameState` construction (`0x67D070`); `MapCamera_SetAim` (`0x63D400`); the CMap ground-point routines
`0x492850` (the pull) and `0x492B80` (the drag); and `fmod` (`0xC0892A`). The camera then uses its slots 96 (aim,
`+0x2F4`) and 95 (eye, `+0x2E8`). The aim is fixed by `SetAim`.

## 7. The arguments, now all placed

`void __stdcall UpdateMapCamera(MapCamera* camera@ESI, void* input@EDI, void* keyboard@stack:4, int mapWidth@stack:8,
void* events@stack:0xC, float seconds@stack:0x10)`, `ret 0x10`. The in-game call site (`0x656685`..`0x6566AE`) pushes
idler `+0xA8C`, then `&idler+0x1CB0`, then graphics `+0x60D4` (the map width, 5616), then idler `+0x1C`; EDI is idler
`+0x64` and ESI is idler `+0x1938`. The map width is used only for the x wrap. The event list is walked by the arrow-key
block (`0x63CCFD`..`0x63CE91`): for each key event (`+8 == 1`) it moves once per direction held, by **6** scroll steps,
and marks the event handled (`+0x18`). The edge tests move **12** steps. The scroll step is
`min(seconds, 0.2) × scroll_speed/100 × 12 × height/40` (`0x63C74D`..`0x63C7BD`). That "seconds" is seconds is inferred
from the 0.2 cap; the timer's unit was not read.

## 8. The wheel's source, and one oddity

`CDirectInputMouse::Poll` (`0xB4E780`) stores the poll's lZ into `+0x84` as it stands, not summed (`0xB4E81B`), and adds
it to `+0x90` as well. It notifies the observers of its `+0x60` sub-object (`0xA881E0`) **only when the new lZ differs
from the last poll's** (`0xB4E821 cmp edi,eax; je`). That notification is inferred, not read, to be what puts the kind-4
wheel event on the frame's list. If so, a frame whose wheel delta equals the previous frame's raises no wheel event and
does not zoom.

`Poll` is slot 8 of the DirectInput mouse's table `0x16084D0` (its constructor `0xB4E560` writes it at `+0`). The
record's "slot 23 counting from 0x1608494" counted from the keyboard's table, which ends where the mouse's begins.

## 9. Not established

- What the observers at mouse `+0x60` do with a changed wheel. That is the link between `Poll` and the kind-4 event.
- Which mouse class a normal run makes (the global at `0x1A857E0`).
- The game's frame rate, which sets how fast the ease runs in real time.
- `0x6F1D50` (the scenario camera) and the drag's ground-point routine `0x492B80`.
- Whether the wheel reaches the map while a country view is open.

## For OpenHOI3 (prose only)

To match the original with zoom_speed 50 and the legacy camera off: per notch, set target = current height × 0.9 (in)
or × 1.2 (out), using the *current* height, clamped to [40, 1000], at most one notch a frame; move the look target 13.3%
of the way to the ground point under the cursor, in both directions, unless the target landed exactly on a limit or the
cursor is within 6 px of the map's edge; each frame, move both height and position 19.7% of the remaining gap - per frame,
not per second. PAGE_DOWN / PAGE_UP change the target by a fifth of the target, about the centre.

In the record through `fragments/merged/camera-zoom-2026-11-12.json`.
