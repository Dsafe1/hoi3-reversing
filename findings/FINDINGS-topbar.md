# The top bar: what it writes into each of its elements, and when

Read statically off `hoi3_tfh.exe` on 2026-10-08, for the rewrite's first screen
(`OpenHOI3/docs/mechanics/topbar.md`). The game was not running; the one live observation
used is `FINDINGS-guilive.md` §6, the sixteen strings read out of a running top bar, which
is what every format below was checked against. Addresses are **virtual** (image base
`0x400000`) with the rva beside anything the record needs. Listings are in the session
scratchpad (`factbase/topbar_slot*.txt`).

`FINDINGS-uinumbers.md` §7 already had the top bar's *tooltip* builder (`CTopBar` slot 5,
41 keys). What it did not have is the routine that fills the bar itself, which is slot 4.

## In one line

`CTopBar` (vftable `0x15D2C90`, six slots, `0x384` bytes) is rebuilt by slot 0, which finds
the window `topbar` and hangs an observer on each of thirteen buttons, and refreshed by
slot 4, which sets fifteen text boxes, the flag, the country name and the speed indicator's
frame; every resource figure is the stockpile truncated to a whole number behind a colour
escape chosen from the day's ledger - red when more goes out than comes in even with trade,
yellow when only trade covers it, green otherwise; `ic_number` is three plain integers,
wasted / used / before the resource cap; `leadership_number` is not leadership but the
**officer ratio**, red under 50% and yellow under 90%; `espionage_number` is the spies not
yet placed, capped in print at `99+`; and `diplomacy_number` works out a colour and then
**throws it away**, appending it to a string that has already been used.

---

## 1. The class

`CTopBar` has one RTTI vftable, `0x15D2C90`, with six slots:

| slot | VA | what |
| --- | --- | --- |
| 0 | `0x6CBBC0` | **Build**: find the window, attach the button observers, set the pause tooltip. §2 |
| 1 | `0x6C9B30` | writes the vftable back at `0x6C9B7F`; the destructor. Not read further |
| 2 | `0x6C9C90` | **Show**: `window->Show()` on the `CGuiObject` subobject (`+0x18`, slot 13), then `0x6CB920` |
| 3 | `0x42E160` | a body shared with other classes; not read |
| 4 | `0x6C9FA0` | **Update**: everything in §3 |
| 5 | `0x6CCB80` | `CTopBar::BuildTooltip`, already recorded |

It is allocated with `push 0x384; call operator new` at `0x65D705` and constructed by
`0x6C9530`, whose one caller is `0x65D727`. The
vftable is written at `0x6C95D4`.

Fields, from the two routines read:

| offset | what | evidence |
| --- | --- | --- |
| `+0x20` | the live `topbar` window (`CFixedWindow*`) | slot 0 stores what the gui's by-name window factory returns for `'topbar'`, `0x6CBC81`; every element lookup goes through it |
| `+0x24` | the `CInGameIdler` | slot 14 (`+0x38`, the gui), slot 16 (`+0x40`), slot 23 (`+0x5C`, the played country's tag) and slot 95 (`+0x17C`, is the game paused) are all called on it |
| `+0x28` | the tick the date was last drawn for | compared with game state `+0xBDC` at `0x6CAA06`, stored at `0x6CAAA6` |
| `+0x2C`, `+0x30` | the country last drawn: tag, then id | compared at `0x6CB43D`, stored at `0x6CB533`/`0x6CB539` |
| `+0x34` ... `+0x34C` | thirteen button observers, `0x2C` apart | §2 |
| `+0x378` | an `0x80`-byte object, rebuilt on every Build (`0x6CC5C1`) | something of the outliner's: `0x6CB920` asks it a yes/no (`0x6A7D60`) and drives `topbar_outlinerbutton` from the answer. Unidentified |
| `+0x37C` | a byte `0x6CB920` sets and clears around `0x6CFEA0` | unidentified |
| `+0x380` | an `0x17C`-byte object built by `0x466060` with the idler | its slots 4, 2, 3 and 6 are called; `0x466060` is 0xDF0 before `BuildStratWarfareTooltip`. **Likely** the strategic warfare window |

## 2. Build - slot 0, `0x6CBBC0`

`void __thiscall`, bare `ret` at `0x6CCB72`. Element lookups are two virtual calls on the
window: **slot 13 (`+0x34`) finds a button by name, slot 14 (`+0x38`) finds a text box**
(§3 uses the second throughout), and slot 17 (`+0x44`) finds an icon. A button's
observable half is at `+0x48`, and its slot 1 attaches an observer, slot 2 detaches one.

| button | observer at | note |
| --- | --- | --- |
| `topbarbutton_diplo` | `+0x34` | these five are attached only while no tutorial runs (`tutorial_active`, game state `+0xD9D`); with one running the same five observers are *detached* if present |
| `topbarbutton_prod` | `+0x60` | |
| `topbarbutton_tech` | `+0x8C` | |
| `topbarbutton_politics` | `+0xB8` | |
| `topbarbutton_intelligence` | `+0xE4` | |
| `topbarbutton_theatre` | `+0x110` | |
| `topbar_menubutton` | `+0x13C` | |
| `topbarbutton_statistics` | `+0x270` | |
| `swm_open` | `+0x29C` | disabled (slot 47, `+0xBC`) when the game state has a scenario at `+0xD0C` |
| `button_speeddown` | `+0x2C8` | attached only when the byte at `+0x34` of what idler slot 18 returns is set; otherwise both speed buttons are disabled. The byte is unidentified - the host, by the shape of it |
| `speed_indicator` and `pause_bg` | `+0x2F4` | **one observer for both**, which is why clicking either pauses |
| `button_speedup` | `+0x320` | as `button_speeddown` |
| `topbar_outlinerbutton` | `+0x34C` | its frame is set here too: 2 or 1 on `0x6A7D60`'s answer |

`pause_bg` gets frame 1 and the tooltip `PAUSE_RESUME` when the game is paused, frame 2 and
`FE_PAUSED_TEXT` when it is not (`0x6CC80E`..`0x6CCA4E`).

What each observer *does* was not read. The handlers are the functions each observer's
glue points at.

## 3. Update - slot 4, `0x6C9FA0`

`void __thiscall`, bare `ret` at `0x6CB918`. The country is the played one: idler slot 23
gives the tag, and the country comes out of the database vector at `[0x1A855A4] + 0x16C`.
Every text box is found by name with window slot 14 and set through `0x687F30`
(`SetText`, the box in ESI and the string in EDI, which does nothing when the text is
unchanged).

### The seven resources

`0x6C9CB0` builds each one: `FormatGoodsNumber(goods@ECX, topBar, out)`, `ret 8`. The
goods indices are the pool's own: 0 supplies, 1 fuel, 2 money, 3 crude oil, 4 metal,
5 energy, 6 rare materials.

| element | goods |
| --- | --- |
| `energy_number` | 5 |
| `metal_number` | 4 |
| `raremat_number` | 6 |
| `oil_number` | 3 |
| `fuel_number` | 1 |
| `supplies_number` | 0 |
| `money_number` | 2 |

**A government in exile shows `-` for fuel and for supplies** (`CCountry +0x95`, tested at
`0x6CA29D`; the literal is `0x15C49C4`). The other five are drawn as usual.

The colour, from the day's ledger - the same fifteen per-goods arrays
`FINDINGS-uinumbers.md` §5 names:

    out      = sent_to - repaid_away - tribute_sent + usage + conversion_used
               + convoyed_out + traded_away
    in       = home_produced (+ convoyed_in, unless the goods are supplies or fuel)
               + sent_back + the pool at +0xA64 + income_from_debt + conversion_made
               + tribute_received
    red      if out > in + traded_for          (0x6C9D80, '§R' at 0x15B5C58)
    green    else if out < in                  (0x6C9DC0, '§G' at 0x15B5C50)
    yellow   otherwise                         ('§Y' at 0x15B5C54)

`in` for the second test is not recomputed inline: it is `CCountry::GetDailyIncome`, which
is that sum. So **red is a deficit even after trade, yellow is a deficit that trade
covers, and green is a surplus without it**. `repaid_away` and `tribute_sent` are
subtracted, which fits the record's note that `tribute_sent` is held negative.

The number is the stockpile - the exile's own pool at `+0x9F8`, or the pool on the acting
capital at `+0x15C` otherwise - through `FormatFixedPoint(value, 0)`, so truncated to a
whole number. **Above 99999 it is shown in thousands with a `K`** (`cmp ..., 0x5F5DD18` at
`0x6C9DF7`, which is 99999000; the `K` is `0x15C7718`): the value is divided by a thousand
first and then truncated, so 123456.7 reads `123K`. The two arms at `0x6C9E5D` are the same
division with and without a 64-bit intermediate.

Checked against the live strings: `§G3804`, `§G1906`, `§G951`, `§R1870`, `§G462`, `§G391`,
`§G591`.

### `ic_number`

Three integers and two colours, built at `0x6CA5EC`..`0x6CA872`:

    {§R if wasted > 0, else §G} wasted / {§R if before_cap > used, else §G} used / before_cap

- `wasted` is `CCountry::GetAvailableIC` - IC a slider has been given and does not need.
- `used` is `CCountry +0x604`, `TotalIC`.
- `before_cap` is `CCountry +0x60C`, `max_ic`, the day's IC before the resource cap.

All three go through `_itoa`, so `TotalIC` and `max_ic` are **whole numbers here, not
thousandths** - which the dissent step agrees with, multiplying `+0x604` by 1000 before
handing it on. Live: `§R10/§G21/21`.

### `DateText`

Redrawn only when the tick changes (`+0x28`). The format string is the literal
`h :00 w d , w mw w y` (`0x15D2794`), handed to `0x6AAF30` with sixteen bytes copied from
the game settings at `+0x6C` - the same sixteen the record calls `CTextRenderColours` and
`FINDINGS-effecttext.md` saw passed to the text renderer, so `0x6AAF30` may be more than a
formatter. It was not read; read as a token list the string
is hour, `:00`, space, day, comma, space, month as a word, space, year - and the live text
is `0:00 1, January 1936`. **`likely`** on that fit.

### `dissent_number`

The colour is the sign of `CDistributeConsumerGoods::GetDissentChange` for the consumer
goods slider as it stands (`0x6CAB60`): **red when dissent is rising, green when falling,
yellow when still**. The number is `CCountry +0x10B4`: one decimal above 1.000, two at or
below it (`cmp eax, 0x3E8` at `0x6CABAC`). Live: `§G0.00`.

### `national_unity_number`

The colour is the sign of what is moving it (`0x6CACC2`..`0x6CACF8`):

    strat_bomb_impact + strat_allies_impact + strat_convoy_impact
        + the country's MODIFIER_NATIONAL_UNITY (modifier 44, values +0x160)

green when positive, yellow at zero, red when negative. The number is `+0x10B8` with no
decimals and a `%` (`0x15BC248`). Live: `§Y80%`.

### `diplomacy_number`, and its lost colour

The routine works out a colour from the day's balance (`0x6CAE69`..`0x6CAF26`): what the
diplomacy share of leadership makes, less `CCountry::GetInfluenceUpkeep`; green, yellow,
red on its sign. **It then appends that colour to the string national unity has just
finished with** (`lea ecx, [esp+0xC0]` under two pushes, the same `esp+0xB8` the unity
text was set from), builds the number in a different string (`esp+0x12C`) and sets the
text box from that one. So the colour never reaches the screen, and the live string is a
bare `9`. `confirmed` as instructions; that it is an oversight rather than intent is
inference.

The number is `CCountry +0xA88` over 1000, truncated to an integer through a float
(`cvttss2si`) and `0x65AB40`.

**A global at `0x1BEA410` replaces it with 100 when set** (`0x6CAF37`). The same test is
in `CCountry +0xA88`'s accessor at `0x4F4E20` and in 26 other places, most of them between
`0xA15000` and `0xA34000`. Unidentified; it reads like a switch that gives every country
unlimited influence.

### `manpower_number`

`CCountry +0xBCC` through `FormatFixedPoint(value, 0)`. No colour. Live: `115`.

### `leadership_number` is the officer ratio

    value  = CCountry +0xD4, OfficerRatio
    red    if value < 500      (floor(500.5), the float at 0x160A5E8)
    yellow else if value < 900 (floor(900.5), the float at 0x160AAC8)
    green  otherwise
    text   = colour + FormatFixedPoint(value * 100000 / 1000, 0) + '%'

The two thresholds are computed once and kept in statics (`0x1BEBDDC`, `0x1BEBDD8`, guard
bits in `0x1BEBDE0`). Live: `§G108%`. The element's name and its icon,
`GFX_icon_leadership`, both say leadership; the figure is officers.

### `espionage_number`

`CCountry +0x1170`, `spy_pool`, over 1000 (the `0x10624DD3` multiply): the whole spies
bought and not yet placed. **Above 99 the text is `99+`** (`0x15D27B8`). No colour. This
one reads the played country through game state `+0xC34` rather than through the idler.
Live: `0`.

### The flag and the name

Only when the played country differs from `+0x30`: the icon `player_flag` (window slot 17)
is handed the country id through its slot 53 (`+0xD4`), and `CountryName` is set from
`0x518730`, a wrapper over `0x518620`. Neither callee was read.

### `speed_indicator`

    frame = 1                    if the game is paused   (idler slot 95)
    frame = game_speed + 2       otherwise               (game state +0xBEC)

set through the button's slot 18 (`+0x48`). `GFX_speed_indicator` declares `noOfFrames =
6`, so with five speeds the frames run 1 to 6 and **a frame number is one-based** - which
`pause_bg`'s 1 and 2 against its two frames agrees with. `likely`: the sprite's draw was
not read, the fit is on the counts.

### And when there is a scenario

With a scenario at game state `+0xD0C`, Update disables `topbarbutton_diplo`, `_prod`,
`_tech`, `_politics`, `_intelligence`, `_statistics` and `_theatre` on every pass
(`0x6CB638`..`0x6CB7F2`). The field's comment says it is null in a loaded save; what sets
it in an ordinary campaign was not checked.

## 4. Orientation keywords

`0xB29CC0` (rva `0x729CC0`) turns the string a `.gui` file gives `orientation` into a
number. The string arrives in EDI; the compare is **exact and case-sensitive**:

| keyword | value |
| --- | --- |
| `UPPER_LEFT` | 0 |
| `UPPER_RIGHT` | 1 |
| `LOWER_LEFT` | 2 |
| `LOWER_RIGHT` | 3 |
| `CENTER` | 4 |
| `CENTER_UP` | 5 |
| `CENTER_DOWN` | 6 |
| anything else | 0 |

So a misspelt or lower-case orientation is silently the upper left. Their Finest Hour's
`.gui` files use six of the seven - never `CENTER_DOWN` - and never misspell one; four
write `CENTER` unquoted, which is the same string.

## What is not established

1. **What the button observers do.** Thirteen are attached; none of their handlers was
   read. *Cheapest check:* each observer is a glue object holding a handler pointer; read
   the constructor `0x6C9530`, which writes them.
2. **The date formatter `0x6AAF30`** and its token grammar. The reading above is a fit on
   one string.
3. **`0x1BEA410`.** What sets it. `image.findValue` gives 28 sites; the writer is among
   them.
4. **`+0x378` and `0x6CB920`.** The outliner-side object and the routine that keeps
   `topbar_outlinerbutton` in step with it.
5. **Whether a frame number of 0 draws the first frame or nothing.** One-based is read off
   three uses and two frame counts, not off the draw.
6. **How a text box lays its text out.** `SetText` hands the string, the font name
   (`+0x70`), two words at `+0xA8`/`+0xAA`, and the fields at `+0xAC`, `+0xB0`, `+0xC4`
   and `+0xC8` to slot 61 of the object at `+0x4C`. Which of those is `maxWidth`,
   `maxHeight`, `borderSize` and `format` was not read.
7. **Nothing here was watched running.** The live strings are another session's, playing
   Ireland on 1 January 1936.
