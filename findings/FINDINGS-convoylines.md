# Convoy lines: transports and escorts in the build queue

Read statically on 2026-10-15 for OpenHOI3, as the convoy-line wave (`WAVE.md`, landed in `CANDIDATES.md`): the
queue's third kind of line, after a unit's (`FINDINGS-buildqueue.md`) and a building's (`FINDINGS-buildingqueue.md`).
Section A is the command, the line and its delivery; section B what the production screen shows of it and how it is
ordered. Addresses are `VA / rva`.

## A. The convoy line: ordered, priced and delivered

It extends `FINDINGS-buildingqueue.md` section A, which it follows in shape, and `FINDINGS-oob.md`, "On a convoy
construction". Checked against the maintainer's twelve saves of one game, 1 January to 20 April 1936.

**What it corrects:**

- `CConvoyConstruction::Deliver` (`0x486770`) is slot 9. It was recorded `likely` and "not reached from a vftable slot".
  It answers a `bool`, and keeps the progress paid past the duration.
- The convoy command reserves `1 + 2 x amount` ids; the building command reserves `1 + 3 x amount`.
- The `country` key in a `convoy_construction` block counts for nothing. `CCountry::LoadKey` reads a convoy block
  *before* enqueueing it, the reverse of a military line (`FINDINGS-buildqueue.md` section 10), so the enqueue writes the
  loading country's tag over it.

### A.1 The command, `CConstructConvoyCommand`

Type id 0x4DF (`construct_convoy`), 0x54 bytes, base `CCommand`, vftable `0x15C37D4`.

| field | what it holds | saved as |
| --- | --- | --- |
| `+0x3C` | the country's tag | `country` |
| `+0x44` / `+0x48` | the id the new line will take | `id` |
| `+0x4C` | escorts (1) or transports (0) | `status`, `yes` / `no` |
| `+0x50` | how many in series: the line's `size` | `amount` |

**The constructor** (`0x5496A0 / 0x1496A0`, `ret 0x10`) takes `this`, the escorts byte and the 8-byte tag on the stack,
and **the amount in EDI**: there is an amount, and it becomes the line's `size`. The id is minted as for a building line -
type `0x1268 + word[0x1A857EC]` (4713 in every save), serial the counter at `0x1A857F8` plus one - and **the counter then
moves on by `1 + 2 x amount`**; nothing uses the extra numbers. *Measured* on 4 January, one country's consecutive AI
lines step by exactly that: Britain 666 (size 5) -> 677; Japan 1079, 1084, 1089, 1094, 1099 (size 2) -> 1104; Cuba 1538
(size 1) -> 1541.

| slot | address | what it does |
| --- | --- | --- |
| 2 | `0x5499B0` | SaveContents: `country id amount status` |
| 4 | `0x549B00` | LoadKey: the same four (already recorded) |
| 6 | `0x549770` | Execute (below) |
| 7 | `0x5499A0` | GetTypeId: 0x4DF |
| 13 | `0x549C40` | Clone: copies every field, id included |
| 14 | `0xA92590` | the folded `mov al,1; ret`: **the order is always valid** |

The prototype constructor (`0x5495F0`) is called only by `RegisterCommandTypes`.

**`Execute`** (`0x549770 / 0x149770`, slot 6, bare `ret`):

    country = countries[cmd.country.id]
    line = new CConvoyConstruction            ; status 1000, size 1, builder "---"
    line.id      = cmd.id                     ; CReferenceObject::SetId
    line.country = cmd.country
    line.escorts = cmd.escorts                ; +0x58
    line.size    = cmd.amount                 ; uncapped, unchecked
    if (escorts) cost = GetEscortBuildCost(country) ; days = GetEscortBuildTime(country)
    else         cost = GetConvoyBuildCost(country) ; days = GetConvoyBuildTime(country)
    line.cost     = cost                      ; +0x30
    line.duration = days / 1000 * 1000        ; +0x34, whole days, truncated
    CCountry::EnqueueConstruction(line, country)   ; appended at the TAIL
    if the country is played: in-game screen slot 60 (0x674ED0)
    CCountry::RebuildNeighbours(country) ;  CCountry_AfterDiplomacyChange(country)
    CDistributeProduction::UpdateNeeded(country's production share)

The four getters (`0x4FD590`, `0x4FD600`, `0x4FD670`, `0x4FD6E0`; already recorded) have one shape:

    value = define * (1000 + technology_status.field) / 1000     ; 64-bit, truncated
    if (value < 10) value = 10                                   ; (int)floor(10.5f): 0.010

| | define (economy block) | Their Finest Hour | technology status field |
| --- | --- | --- | --- |
| transport cost | `CONVOY_BUILD_COST` (+0x14) | 2 | `+0x44` `convoy_build_cost` |
| transport time | `CONVOY_BUILD_TIME` (+0x18) | 100 | `+0x48` `convoy_build_time` |
| escort cost | `ESCORT_BUILD_COST` (+0x1C) | 4 | `+0x4C` `escort_build_cost` |
| escort time | `ESCORT_BUILD_TIME` (+0x20) | 240 | `+0x50` `escort_build_time` |

**No file in either install sets any of the four technology keys** (a grep of every `.txt` under the install; the same
grep finds `allow_escorts`, in `sea_lane_defence`). So in Their Finest Hour a transport line costs **2.000 IC a day for
100 days an item** and an escort line **4.000 for 240**: 200 and 960 IC-days for ten ships. Every one of the 868 convoy
lines in the saves has exactly those figures.

- **Nothing refuses the order** - not escorts without `allow_escorts`, not a size of nought or less, not a country with no
  ports. *Measured*: 36 countries without `sea_lane_defence` have escort lines on 4 January (Argentina, Belgium, Brazil
  and others), and 36 on 20 April. Only the disabled `escort` button stops a player (B.1).
- **Nothing is charged and nothing is said**: no AddProgress, no IC, no message.
- **The order rebuilds the country's neighbour lists and runs the tail of a diplomatic change** - NAP force balances, the
  AI strategy timer and the diplomacy view, as `CCountry_AfterDiplomacyChange` (`0x4E39C0`) records; the pair a pact's
  change calls. A side effect on timing, not on the line.
- **A line is never merged into another.** Each order makes a new line, at the tail.

### A.2 Who posts it

- **The confirm dialog.** `CConfirmBuild::OnAccept` posts `CConstructConvoyCommand(escorts, country)` with **amount = the
  dialog's serial count** (`+0x13C`, loaded into EDI at `0x7F3AF9` and `0x7F3BB4`), once per `parallel`: mode 2 escorts 1
  (`0x7F3B04`), mode 1 escorts 0 (`0x7F3BBE`). **Parallel 3 and serial 2 make three lines of two items each.**
- **The AI's Lua**, `tfh/script/ai_production_minister.lua`, `ConstructConvoys` and `BuildTransportOrEscort`:
  `CConstructConvoyCommand(ministerTag, vbConvoyOrEscort, liSerial)`, true for escorts, then `ministerAI:Post` with no
  `IsValid`. It asks for `math.ceil(needed / defines.economy.CONVOY_CONSTRUCTION_SIZE)` items, split into runs of at most
  `maxSerial` - 2 for transports, 5 when more than 100 are needed, 5 for escorts - which is where the saves' sizes 1, 2, 4
  and 5 come from. The base game's `script/ai_production_minister.lua` (line 2135) makes the same call.

### A.3 The line, `CConvoyConstruction`

0x5C bytes, vftable `0x15BDD04`. **The constructor** (`0x486630 / 0x86630`; this in EAX, bare `ret`) sets status 1000,
size 1, location null, country and builder `---`, and escorts 0; its one caller is `CCountry::LoadKey`, and `Execute`
builds the same object inline. `+0x40` (`size`) is **how many items are still to deliver**; `+0x58` (saved as the second
`status`) is **escorts**.

| slot | address | what it does |
| --- | --- | --- |
| 2 | `0x4866F0` | SaveContents: the shared contents, then `status = yes/no` |
| 4 | `0x4866B0` | LoadKey: `status = yes` sets +0x58; anything else goes to the base |
| 8 | `0xA92590` | folded `mov al,1`; EnqueueConstruction calls it, no effect |
| 9 | `0x486770` | Deliver, A.4 |
| 10 | `0x486850` | GetSaveToken: 0x4DE, `convoy_construction` |
| 11 | `0x592360` | ReturnFalse: not the underground |
| 12 | `0x4831C0` | `CConstruction::CanStillBeBuilt`; the location is always null, so it never cancels |
| 13 | `0x486860` | GetName: `CC_CONVOY` "Convoy" or `CC_ESCORT` "Escort". **No count**: a line of five reads "Convoy" |
| 14 | `0xABF890` | **bare `ret`: the line is never priced again** (A.5) |
| 15 | `0xA92590` | `mov al,1`: "is a convoy" (`CBuildQueueEntry`, the `transports_value` sum) |
| 16, 17 | `0x592360` | ReturnFalse: not a building, not a unit |
| 20 | `0x60CD50` | `ret 4`: AddProgress's hand-off does nothing |

**The shared writer.** `CConstruction::SaveContents` (`0x4834A0 / 0x834A0`) is not a virtual, like
`CConstruction::LoadKey`; all three kinds of line call it. It writes `id size cost duration progress status`, then
`location` only where there is one, `country` only where its id half is not 0, and `builder` only where its id half is not
0 - which is why no convoy line in a save has a `location` or a `builder`.

### A.4 `CConvoyConstruction::Deliver` (`0x486770 / 0x86770`, slot 9)

Bare `ret`; it answers a `bool`. In order:

    country = countries[line.country.id]                       ; no test that it exists or owns land
    n = CONVOY_CONSTRUCTION_SIZE / 1000                         ; [defines + 0x9C] + 0x34, truncated: 10
    if (line.escorts)  country.Escorts    (+0xB4) += n
    else               country.Transports (+0xB0) += n          ; saved as `convoys`
    progress -= min(duration, progress)
    size -= 1
    (custom game, stage 2, the country on the settings' list: settings +0x6C = 1)
    return size <= 0

1. **One finished item is `CONVOY_CONSTRUCTION_SIZE` ships, 10 in Their Finest Hour.** Items come one at a time, each a
   full `duration`: a line of five transports gives 10 every 100 days for 500 days at 2 IC a day. `transports_value`'s
   `(+N)`, `size x CONVOY_CONSTRUCTION_SIZE`, counts every item still to come (B.2).
2. **What was paid past the duration carries over** to the next item, as on a building line.
3. **Nothing else happens**: no practical (no `GainTechAbility`), no message, no re-pricing (slot 14 is empty), no "owns
   no province" test, which both the other lines have. A line of size 0 or less still gives one item before it is removed.

*Measured*, 1 April -> 20 April (one session, ids stable): 47 transport lines at 81.4 to 90.0 of 100 on 1 April are gone
(38) or one item shorter (9) by 20 April. The 19 countries whose only change was one such line gained exactly **+10
`convoys`**; the rest moved by other amounts as convoys were assigned to routes. Japan's five lines of size 2 at 90.000
are size 1 at **9.000**, which is 90 + 19 days - 100; Italy's two went the same way; Britain's 89.097 -> 8.097 and
87.702 -> 6.702. No escort line was old enough to finish.

### A.5 The price never changes

Slot 14 is the folded bare `ret` (`0xABF890`), and all six places that re-price the queue call slot 14 - `Distribute`
after a line finished, `CChangeLawCommand::Execute`, `CInGameIdler::Enter`, `ApplyCustomGameSettings` and the two unit
commands - so none touches a convoy line. The only code that works out a convoy price is the four getters, whose callers
are `Execute` (`0x549884`, `0x549897`, `0x54986A`, `0x54987D`), the only one writing into a line; `CConfirmBuild::Update`
(`0x7F296F`-`0x7F29AD`, for display); `0x41A9D0` and `0x41AA50`, which give IC-days a ship, `time x cost / 1000 /
CONVOY_CONSTRUCTION_SIZE`, into an out pointer, called from the custom-game region `0x41A...0x428`; and `0x4635B0`
(escorts only, into an out pointer). `luabind.json` gives `CConstruction` only `GetCost` and `GetSize`. So **a convoy
line's `cost` and `duration` are set once, when it is ordered or loaded**; a technology researched, a law changed or a
finished line leaves them as they were. *Measured*: all 868 lines carry the define figures exactly.

### A.6 The day's work

`CDistributeProduction::Distribute` (`0x519D10`) calls only slots 12, 9, 14 and 0 on a line and never asks slots 15 to 17,
so **a convoy line is paid exactly as a unit or building line is**: its need is `cost`, paid in queue order from the share
and then from resources; `AddProgress(amount)`, 1.000 a day when paid in full; `Deliver` once `progress >= duration`; the
line removed when Deliver answers 1. AddProgress's slot-20 hand-off does nothing. A finished item of a series (Deliver
answering 0) does not set off the day's re-pricing; a finished *line* does - `RebuildStaticModifiers` and slot 14 on every
line left - and every other line is re-priced and the convoy lines are not. *Measured*: the share, `status`, takes the
expected values (1.000 for most lines; 0.000 and fractions where the pool ran out).

### A.7 History and the save

**Loading.** `CCountry::LoadKey`'s `convoy_construction` arm (`0x4CD6AA`) makes the line (`0x486630`), **reads its block
first** (slot 3, `0x4CD6CE`), and then calls `CCountry::EnqueueConstruction` (`0x4CD6D4`), which nulls `location`, calls
slot 8 and **writes the loading country's own tag over `country`**. So a block's `country` key counts for nothing:
BlackICE's `history/units/POL/Polish_convoys.txt` writes `country = ENG`, which changes nothing.

**In a new game**, `CInGameIdler::Enter`'s loop (`0x65B749`, `FINDINGS-buildqueue.md` section 1) sets `progress =
duration_after - duration_before` around slot 14. Slot 14 is empty, so for a convoy line **progress becomes 0, and `cost`
and `duration` stay as the file wrote them**. Their Finest Hour's history has no convoy lines; BlackICE's have
`size = 2 cost = 0 progress = 3 duration = 3` - free lines, at need 0 (`AddProgress(1000)` a day), each item done in
three days.

**The save grammar**:

    convoy_construction = { id = { id type } size cost duration progress status country status }

The first `status` is the day's share and the second `yes` (escorts) or `no` (transports); every line in the saves has
both. **On loading, the second `status = no` goes to `CConstruction::LoadKey`, which parses it as a number
(`TokenToFixedPoint("no")` = 0) over the share**, so a transport line loaded from a save shows a share of 0 until its next
day; an escort line keeps its share, `yes` being taken first. Nothing but the queue line's colour, speed and ETA reads the
share (`FINDINGS-buildqueue.md` section 8).

The country's counts are saved as `escorts` (`+0xB4`) and `convoys` (`+0xB0`, the Lua API's `Transports`); the writer at
`0x4C56C9` reads them at `+0x9C`/`+0x98` from a pointer to the country +0x18 (the pointer's offset *inferred*).

### A.8 The Lua constructor

`LuaConstruct_CConstructConvoyCommand` (`0x98A050 / 0x58A050`, `ret 0x14`) is luabind's `__init(argument, CCountryTag,
bool, int)`: in Lua **`CConstructConvoyCommand(tag, escort, amount)`**, escort true for escorts, amount the line's size; it
calls the constructor with amount in EDI. The AI's counters are `CAIProductionMinister::CountTransportsUnderConstruction`
and `CountEscortsUnderConstruction` (VA `0x8A24D0`, `0x8A25E0`, not read); the script sets them,
`GetTotalConvoyTransports` and `GetEscorts` against `GetTotalNeededConvoyTransports`, orders `ceil(missing /
CONVOY_CONSTRUCTION_SIZE)` items, and does not check `allow_escorts`.

### A.9 What looks wrong but is what the bytes do

1. Escorts are ordered and built without `allow_escorts`: only the production screen's button stops a player, and the AI
   orders them freely.
2. A convoy line is priced once. Technology, laws and ministers never reach a line already queued, and the line takes no
   part in the queue's re-pricing.
3. The duration is cut to whole days after the 0.010 floor: a technology taking the time to nought would give a 0-day
   line, finished the first day.
4. A finished item gives no practical and raises no message.
5. Deliver does not ask whether the country still owns anything.
6. A size of 0 or less still delivers one item.
7. The command reserves `2 x amount` ids nothing uses.
8. Ordering convoys rebuilds the country's neighbour lists and runs the diplomacy-change tail.
9. A convoy block's `country` key is ignored; a military line's is not.
10. A new game zeroes a history convoy line's progress and keeps the file's cost and duration.
11. A transport line loaded from a save has its share zeroed by its own second `status`.
12. A line's name has no count.

### A.10 Not settled

- **That a loaded save shows transport lines at a share of 0 until the next day** - read, not seen. *A screenshot would
  settle it*: a save with a part-built transport line, loaded and paused - the queue line should read red, 0% and ETA
  `---` (`GetEtaText` returns `---` at pace 0 where progress > 0), and an escort line beside it keep its colour.
- What the in-game screen's slot 60 (`0x674ED0`) does: it tail-calls `0x7C1D30` on the window at `+0x1CE0`, which the
  record takes for the ledger; not read.
- Whether rebuilding the neighbour lists on an order has any visible effect beyond timing.
- That `convoys` is `+0xB0` in the save: it rests on the writer's `+0x98`/`+0x9C` pair being the country +0x18 and on the
  save's `escorts`/`convoys` order.
- Who uses a per-ship price (`0x41A9D0`, `0x41AA50`, `0x4635B0`); they look like the custom game's and an AI's.

**Frontier** (rvas): `0x274ED0` (`CInGameIdler` slot 60), `0x3C1D30` (its callee), `0x1A9D0` and `0x1AA50` (IC-days a
transport and an escort), `0x635B0` (an escort price in fixed 15), `0x4A24D0` and `0x4A25E0`
(`CAIProductionMinister::CountTransports`/`CountEscortsUnderConstruction`), `0x584800` (the luabind invoker).

---

## B. The convoy line on the production screen

What the player sees and presses. It continues `FINDINGS-buildingqueue.md` A.2 and A.5 (the same dialog and the same
queue line, read for a building), `FINDINGS-countryviews.md` section 4 and `FINDINGS-productiontooltip.md`.

**What it corrects:**

- `CConfirmBuild::OnAccept` gives each `CConstructConvoyCommand` the dialog's `serial` as its amount, in EDI. The record
  had `CConstructConvoyCommand(0 or 1, country)` with no amount; the decompiler drops the EDI argument.
- `CBuildQueueEntry::Update` shows `production_queue_division`, `_naval` or `_air` only on a unit line, and never shows
  `production_queue_buildings`. On a building or convoy line all four icons are left as the file has them. This
  corrects "shows one of the four" in `FINDINGS-buildqueue.md` section 8 and `FINDINGS-buildingqueue.md` A.5.

### B.1 The two buttons

`tfh/interface/country_production.gui` has `convoy` (418, 178, `GFX_production_button_convoy`) and `escort` (487, 178,
`GFX_production_button_escort`). Neither has a text or a tooltip of its own.

`CProductionView::AttachButtons` (`0x7FBE20`) attaches them to the view's observers at `+0x224` and `+0x250`, and the
constructor (`0x7FB4A5`, `0x7FB4EB`) gives those observers their handlers: `convoy` -> **`CProductionView::OnConvoyButton`**
(`0x8023F0 / 0x4023F0`), `escort` -> **`CProductionView::OnEscortButton`** (`0x8024E0 / 0x4024E0`). Each press:

1. destroys any confirm dialog already open (`+0x318`);
2. makes a new `CConfirmBuild` on the `confirm_build` window (`interface/confirmbuild.gui`): **mode 1** for transports,
   **mode 2** for escorts, no building;
3. keeps it at `+0x318` and calls the view's slot 5.

Nothing is ordered by the button itself.

**When each can be pressed:**

- **`convoy` always.** Nothing enables or disables it. The string `convoy` has three references in the image:
  `AttachButtons`, `BuildTooltip`, and a save-token registration. Positive control: `escort` has a reference inside
  `Update` at `0x7FDDFF`, which is its enabling.
- **`escort` only once a technology has given `allow_escorts`.** `CProductionView::Update` (`0x7FD350`) disables it every
  frame unless the technology status's `allow_escorts` (`+0x80`) is set. In Their Finest Hour the only technology with
  `allow_escorts = yes` is `sea_lane_defence`, "Sea Lane Defence" (`tfh/technologies/Naval Doctrines.txt`).

**Their tooltips** (`CProductionView::BuildTooltip`, `0x7FFD30`), no delayed half, no variables:

| element | tooltip |
| --- | --- |
| `convoy` | `CONVOYS` "Convoys". Nothing else, ever |
| `escort` | `LEDGER_ESCORTS` "Escorts". **Where the button is disabled**, followed by `"\n"` + `NEED` "Need" + `" §Y"` + the name of the first technology in the database with `allow_escorts` - in Their Finest Hour "Escorts" / "Need §YSea Lane Defence" |
| `transports_value`, `escorts_value`, `icon_transport_small`, `icon_escort_small`, `available_label`, `convoys_label` | nothing; none is among `BuildTooltip`'s names (`FINDINGS-productiontooltip.md` section 2) |

**While a confirm dialog exists, it answers every tooltip of the production screen.** `BuildTooltip` hands the whole
tooltip to the dialog's slot 6 whenever `+0x318` is not null (`0x7FFDBF`), and returns. Slot 6 says something only for
the four steppers (`BUILD_ADD_REM_BUNDLE`, "Ctrl + LMB to add or remove 10"), so while the dialog is up the buttons and
queue lines behind it say nothing.

### B.2 The counts beside them

`CProductionView::Update` writes `transports_value` as the country's `transports` (`+0xB0`) and `escorts_value` as its
`escorts` (`+0xB4`), plain integers, each followed by `" (+N)"` where N is not nought:

    k = CONVOY_CONSTRUCTION_SIZE / 1000          ; the define divided first, truncated: 10
    for each line of the queue (+0xF40) whose slot 15 says "convoy line":
        N_escorts    += size * k   where the line's +0x58 (escorts) is set
        N_transports += size * k   otherwise

So a transport line of size 5 shows as `"... (+50)"`. The labels beside the counts are static: `PW_AVAILABLE_TRANSPORT_ESCORT`
"Available transports/escorts" and `PW_CONVOYS` "Convoys". `convoy_button` ("Create convoy") opens the convoy-route
window at `+0x314` (`0x8024D0`), not the building of convoys.

### B.3 The confirm dialog for transports and escorts

`CConfirmBuild` (`0x7F1800`) in mode 1 or 2:

| element | mode 1 (transports) | mode 2 (escorts) |
| --- | --- | --- |
| `photo` | sprite `picture_convoy`, shown | sprite `picture_escort`, shown |
| `label` | `CONVOYS` "Convoys" | `ESCORTS` "Escorts" |
| `serial_value`, `paralell_value` | start at 1 | start at 1 |

Both pictures are 188 by 108 and exist in both installs. The steppers behave exactly as for a building: 1 to 99, 10 with
Ctrl, repeating while held.

**Update, every frame** (`0x7F2490 / 0x3F2490`). The country is the screen's.

    mode 1:  time = CCountry::GetConvoyBuildTime(country)     cost = CCountry::GetConvoyBuildCost(country)
    mode 2:  time = CCountry::GetEscortBuildTime(country)     cost = CCountry::GetEscortBuildCost(country)

    each getter = define x (1000 + the technology status's field) / 1000, 64-bit, truncated, never below 0.010
        convoy cost  CONVOY_BUILD_COST  (2)    + convoy_build_cost (+0x44)
        convoy time  CONVOY_BUILD_TIME  (100)  + convoy_build_time (+0x48)
        escort cost  ESCORT_BUILD_COST  (4)    + escort_build_cost (+0x4C)
        escort time  ESCORT_BUILD_TIME  (240)  + escort_build_time (+0x50)

    ic_cost_value    = parallel x cost, two decimals                          ; IC a day
    days             = serial x time / 1000, truncated
    build_time_value = days <= 365 ? days + " " + DAYS ("Days")
                                   : days / 30 (truncated) + " " + MONTHS ("Months")

- **This is the building's arithmetic** (`FINDINGS-buildingqueue.md` A.2) with the convoy's or escort's figures: the
  cost multiplied by `parallel`, the time by `serial`.
- No technology in either install carries the four `convoy_build_*` / `escort_build_*` keys, so in Their Finest Hour
  the dialog reads **2.00 and 100 Days** for transports and **4.00 and 240 Days** for escorts at 1 x 1. Transports at
  serial 3 read 300 Days; at serial 4, 400 days, "13 Months"; escorts at serial 2, 480 days, "16 Months"; three
  parallel transports, IC "6.00".
- **The colour is the same test as for a building.** Exactly one of `selected_brigade_green`, `_orange`, `_red` is shown.
  Spare = the production slider's IC (share x factor x TotalIC) less the summed `cost` of every queued line: green where
  `spare - parallel x cost >= 0`, orange where `spare > 0`, red otherwise.
- **`on_complete_icon` and `on_complete_impact` are not touched in modes 1 and 2.** Their block runs only where the
  dialog holds a building (`+0x140`, null here, `0x7F334A`). Both stand as `confirmbuild.gui` declares them - the icon
  with the sprite `icon_tech_unknown`, `on_complete_impact` with empty text, and `on_complete_frame` beside them, a name
  the executable never mentions. That they are therefore drawn is *inferred* (B.7).
- `accept` ("Start Production") is never disabled.

**`OnAccept`** (`0x7F3980 / 0x3F3980`) sets the close byte, then posts `parallel` separate commands:

    mode 1:  CConstructConvoyCommand(escorts = 0, the screen's country tag)   amount = serial, in EDI
    mode 2:  CConstructConvoyCommand(escorts = 1, the screen's country tag)   amount = serial, in EDI

The constructor (`0x5496A0`, section A) keeps the amount at `+0x50`. **So parallel 3 and serial 2 makes three commands of
amount 2**, the same shape as a building order. `cancel` ("Close") posts nothing.

### B.4 The line in the build queue

`CBuildQueueEntry`'s constructor (`0x7F4140`) asks the line slot 17 (a unit), then slot 15 (a convoy line), then slot 16
(a building). For a convoy line:

- **`counter_type`** takes the sprite **`icon_build_convoy`** (`gfx/interface/icon_build_transport.dds`, 64 x 63), or
  **`icon_build_escort`** where the line's `+0x58` (escorts) is set. Both exist in both installs. There is no further
  call on the icon, where a building line gets one.
- **`unit_name`** is the line's slot 13 (`0x486860`): `CC_CONVOY` "Convoy" or `CC_ESCORT` "Escort", with no number and no
  place.
- **`unit_target`** is not written, so it keeps the file's empty text.
- **`original_country`** is hidden. Its builder is never set: none of the convoy lines in the maintainer's saves of
  4 January to 20 April 1936 (73 to 107 a save) has a `builder` key.

**Update** (`0x7F4C90 / 0x3F4C90`) does for a convoy line what it does for any line:

| element | what it shows |
| --- | --- |
| `production_queue_green` / `_orange` / `_red` | by `status`: above 990, above 0, otherwise |
| `production_speed` | `status x 100` and `%` |
| `ic_cost` | `cost` to two places and the text of `IC` (2.00 a transport line in the saves, 4.00 an escort line) |
| `eta_date` | `CConstruction::GetEtaText`: the date the current item is due |
| `prodqueue_progress` | `progress x 1000 / duration` as a whole percentage |
| `series_info` | `+` and `size - 1` where size > 1, else empty: a size-5 line shows "+4" |

**The four category icons are decided only on a unit line.** On a convoy line (or a building line) Update neither hides
nor shows `production_queue_naval`, `_division`, `_air` and `_buildings`. They stand as the file declares them - all four
at (223, 0), all 256 x 40, in the order naval, division, air, buildings - so a convoy line is drawn over the **buildings**
background, last in the file. That is *inferred* from the file order, as it was for building lines;
`production_queue_buildings` is never shown by code anywhere on this screen.

**Its tooltip** (`BuildQueueLineTooltip`, `0x7F5A40`):

| element | tooltip |
| --- | --- |
| `cancel`, `max_prio`, `prio`, `non_prio`, `max_non_prio` | as on any line (`FINDINGS-buildingqueue.md` A.5) |
| `original_country` | `PW_ORIGINAL`, but it is hidden |
| `counter_type`, `series_info`, `unit_target`, `production_queue_division`, `_air`, `_naval` | **an empty tooltip** - the brigades part needs slot 17 |
| anything else, `unit_name`, `ic_cost`, `eta_date` and `production_queue_buildings` among them | the status sentence: `PEN_FULL_SPEED` "This production is going ahead at full speed." at status 1000 or more; `PEN_PARTIAL_PROGRESS` "This production is only progressing at §Y$PERC$%§W. You need to invest more IC for it to progress faster." with PERC = status x 100, cut, above 0; `PEN_NO_PROGRESS` "There is currently no progress at all on this project." otherwise |

The five buttons behave as on any line.

### B.5 Compiled in, and from the files

- **Compiled in:** the 365-day threshold between "Days" and "Months" and the 30 days to a month; the 1 to 99 range of
  the counts and the step of 10; the 0.010 floor on each figure; `CONVOY_CONSTRUCTION_SIZE` divided by 1000 before
  multiplying; the 990 threshold for green on a queue line.
- **From the files:** the five defines in `tfh/common/defines.lua`'s `economy` block - `CONVOY_BUILD_COST` 2,
  `CONVOY_BUILD_TIME` 100, `ESCORT_BUILD_COST` 4, `ESCORT_BUILD_TIME` 240, `CONVOY_CONSTRUCTION_SIZE` 10; the technology
  keys `convoy_build_cost`, `convoy_build_time`, `escort_build_cost`, `escort_build_time` and `allow_escorts`; the
  sprites, the element names and the localisation keys.

### B.6 What looks wrong but is what the bytes do

1. **The `convoy` button can always be pressed**; the `escort` button is gated on `allow_escorts`.
2. **The escort dialog's `accept` is never disabled**, and `OnAccept` checks nothing: the button is the only gate on the
   screen.
3. **The dialog multiplies the time by `serial`** and shows it as one figure.
4. **`on_complete_icon`, its frame and an empty `on_complete_impact` are left as the file has them** for transports and
   escorts.
5. **`transports_value`'s "(+N)" divides the define by 1000 first**, so a fractional `CONVOY_CONSTRUCTION_SIZE` would be
   cut.
6. **A convoy line's category background is never chosen**; the four icons stand stacked as the file has them.
7. **While the confirm dialog is open, nothing else on the production screen has a tooltip.**
8. **`unit_name` is just "Convoy" or "Escort"**, with no count; the count is in `series_info` ("+4").

### B.7 Not settled

- **Whether `on_complete_icon` (the tech-unknown picture), `on_complete_frame` and an empty `on_complete_impact` are
  drawn in the transports and escorts dialogs.** Nothing in code hides or shows them in modes 1 and 2; in mode 0 Update
  shows the icon explicitly, so it may be hidden by default somewhere not found. *A screenshot of the dialog after
  pressing `convoy` would settle it.*
- **Which category background a convoy line shows.** Inferred `production_queue_buildings`, last in the file. *A
  screenshot of a queue with a convoy line beside a unit line would settle it.*
- **What slot 73 of `counter_type` does**; Update calls it on every line.
- **Whether `build_queue` is handed exactly the country's construction list.** The list sync `0x806460` makes one entry
  a line it is handed, with no filter by kind; the call site was read, not the whole function, and its cap of 128
  entries a call was seen and not explained.
- **How the close byte becomes a destroyed dialog that nulls `+0x318`** (open since `FINDINGS-buildingqueue.md` A.8).

### B.8 Frontier

`0x406460` (the build-queue list sync, cdecl, three arguments, called once at `0x7FD0EC`); `0x3FCF60` (its caller, which
decides which list `build_queue` is handed); `0x4024D0` (`convoy_button`, the dialog at `+0x314` slot 2); `0x21DD40` /
`0x21DF68` (the other namespace's `CBuildQueueEntry`, which also chooses among the four category icons).
