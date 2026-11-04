# The land orders window: `land_unit_order`, a land unit's Ctrl and right click

*The land orders wave, 2026-11-04, two readers, read statically for OpenHOI3 and set against the maintainer's two
screenshots of the original's window - one on a province of his own country (Reppen), one on an enemy's (Brodnica).
Every address is valid only for this build of `hoi3_tfh.exe`; VAs unless marked rva.*

## In one line

Ctrl and a right click on a province with a land unit selected opens `CLandOrdersView` for the first selected unit:
the province's name, **always three rows - Move Order, Support Attack, Strategic Redeployment - each greyed where any
selected unit's order answers no to its slot 11**, the first of support attack, move and redeployment that may be given
ticked, a date widget giving the hour the order is not to start before, a *Synchronise Arrival* box shown only while Move
Order is ticked, and the day or night at the widget's hour. Accept posts one `CSetOrderCommand` per selected land unit
that is not retreating, with the defensive stance; nothing is remembered between windows, and only the three daytime
elements have a tooltip.

**What can be given where** (section B.2): **Move Order** only to a province beside the unit's, out of battle and
`CanMoveTo`; **Support Attack** only to a province beside it held by an enemy, out of battle - it then waits beside the
province until a land battle begins there, joins it without moving in, and ends with it; **Strategic Redeployment**
anywhere not held by an enemy, out of battle, along a path not through enemy land, both ends in an owner area - and on
the way it restarts the unit's attack delay every hour.

**Corrected**: `CInGameIdler::OpenOrdersView`'s key, "not identified", is Ctrl (`FINDINGS-selection.md` had settled it);
`LandOrdersView_IsMoveOrder`'s `+0x140` is the radio group's ticked checkbox, not an order.

## A. The window

*Reader A's synopsis.* It read the whole of the land orders window, `CLandOrdersView`: the constructor, every slot of
its table (including slots 5 and 6, which sit outside VA 0x73C270-0x73DB50, at 0x747690 and 0x7476B0), AddOrder,
accept, cancel, the unwired third button handler, and the mode-2 arm of `OpenOrdersView`. Every figure on both of the
maintainer's screenshots is accounted for: the rows are always Move Order, Support Attack, Strategic Redeployment; the row
ticked first is the first of support attack, then move, then strategic redeployment that every selected unit's order
slot 11 accepts; the date widget starts at the hour the window opened and is the hour before which the order does not
start (CUnit +0xCC); `sync_checkbox`/`sync_title` are shown only while Move Order is ticked, which is why neither
screenshot has them; the day/night row shows day or night at the date widget's hour. Two existing entries are corrected,
both in their comments only: `CInGameIdler::OpenOrdersView` said the key was "not identified" - it is Ctrl, already
settled in `FINDINGS-selection.md`; and `LandOrdersView_IsMoveOrder`'s +0x140 is the radio group's ticked checkbox, not an
order.

Addresses are VAs unless marked rva (rva = VA - 0x400000). Only valid for this build. Nothing was watched running. The
oracle was the maintainer's two screenshots.

### A.1 Opening it

- **The key.** A land unit's right click with **Ctrl** held opens it. `CUnit::OrderToProvince`'s land arm (0x5C2497) asks
  the keyboard's slot 12, `Keyboard_IsCtrlDown`. Where Ctrl is down it calls `CInGameIdler::OpenOrdersView` with mode 2;
  otherwise the plain move of `FINDINGS-movement.md` follows. That this slot is Ctrl was settled in
  `FINDINGS-selection.md` section A; this reading only confirms the call site. No other test sits between the Ctrl test
  and the call.
- **The first selected unit only.** `OpenOrdersView` returns at once when a view of the same mode is already up. So with
  several units selected the window is made for the first one, as for fleets and air units. Its mode-2 arm makes 0x198
  bytes and calls the constructor (this, idler, unit, province).
- **Nothing is remembered.** The settings restore (0x747300) runs only for mode 1, the air window. Each land window starts
  fresh.

### A.2 What the window holds

| field | what it is |
| --- | --- |
| `+0x04` | the idler |
| `+0x08` | the window `land_unit_order` |
| `+0x0C` | the unit, as a `CRef` (0x28 bytes) |
| `+0x34` | the province |
| `+0x38` | `open` |
| `+0x3C` | the list of the three orders |
| `+0x4C`, `+0x78`, `+0x16C` | three `CButtonObserverGlue<CLandOrdersView>`: accept, cancel, and one wired to nothing |
| `+0xA4` / `+0xA8` | the date widget's window and the date widget |
| `+0xAC` | the radio group of the rows, held by value; its ticked checkbox is `+0x140` |
| `+0x150` | the radio group's observer glue |
| `+0x15C` | the rows' checkboxes |

There is **no stance and no priority**, unlike the naval and air windows.

### A.3 The constructor (0x73C270)

In order:
1. The window `land_unit_order` is made.
2. `accept` is wired to OnAccept and `cancel` to OrdersView_Cancel.
3. The radio group is made.
4. A `datewidget` window (interface/datewidget.gui) is made, with a date widget over it. **Its date is the hour now**
   (CCurrentGameState +0xBDC). It is placed at the positionType `land_mission_timewidget_start` (x 50, y 200,
   tfh/interface/orders.gui) and added to the window as its child `start_widget`.
   - So **the date widget is not an element of `land_unit_order` itself**. It is a separate `datewidget` window placed by
     a positionType, exactly as the air window places its two.
5. **`title` is the province's name.**
6. Three orders are made for the view's unit and the province, each handed to AddOrder, **in this order**:
   - `CMoveOrder` (constructor rva 0x1836A0);
   - `CSupportAttackOrder` (built inline, 0x38 bytes, its `combat` byte false);
   - `CStrategicRedeploymentOrder` (rva 0x183790).
7. **The row ticked first** is chosen by name. AddOrder answers "may be given" for each:

        support_attack              where it may be given
        else move_order             where it may be given
        else strategic_redeployment where it may be given
        else nothing (accept stays greyed)

8. The window is shown and `open` set.

### A.4 The rows (AddOrder, 0x73CBA0)

- **Every order gets a row, whether or not it can be given.** Each row is an `order_entry` window appended to
  `orders_list`; its `name` text is the order's slot 6 key (section B.1).
- The row's `checkbox` is renamed to the order's token key (`move_order`, `support_attack`, `strategic_redeployment`) and
  added to the radio group under that name.
- **Greying.** For every thing in the selection, the order is retargeted to that unit and its slot 11 (MayBeGiven) is
  asked. **One "no" greys the row** (checkbox +0x136 cleared). The function answers whether every unit said yes.
- **Differences from the naval AddOrder:** there is no range test and no name-to-order map.
- **AddOrder runs only from the constructor**, so a row's greying is fixed when the window opens.
- **Picking a row does nothing but tick it.** The radio group's observer glue holds the shared empty stub 0xABF890. The
  ticked row is read only at accept, through +0x140. No order object is remade on a pick, unlike the naval view's
  0x73EC40.
  - Side note, open and not settled: neither the land nor the naval constructor visibly registers its radio observer glue.
    The only references are the stores of the glue's handler (findValue). So how the naval 0x73EC40 is reached is not
    established here.

### A.5 Each frame (Update, slot 2, 0x73CF80)

1. **The sync byte.** `g_LandOrdersSyncArrival` = `sync_checkbox` ticked. The byte has exactly three references in the
   image: this write, a read here, and one in accept.
2. **The day/night row, at the date widget's hour** (not "now", and not the start date as in the air window's reading):
   - The widget's date is turned into a month and an hour of the day: (date - 43800000)/24 days, /365.0 years, then the
     month-length table.
   - `IsNight(province, hour, month)`.
   - `daytime_title` = `ORDER_DAY_TIME` with PROV the province's name: "Locally in $PROV$:".
   - `daytime_icon` (`GFX_prov_daynight`, two frames): frame 2 at night (the moon), frame 1 by day (the sun).
   - `daytime_icondesc` = `ORDER_NIGHT` "Night" or `ORDER_DAY` "Day".
3. **`accept`** is enabled while a row is ticked, and disabled otherwise.
4. **`sync_checkbox` and `sync_title` (`ORDER_SYNC_ARRIVAL`, "Synchronise Arrival") are shown only while the ticked row is
   `move_order`**, and hidden otherwise.
5. **The synchronised arrival.** With `move_order` ticked and the box ticked, `LandOrdersView_EstimateArrival` runs
   (`FINDINGS-weathersim.md` C.4: the latest arrival of all selected units at the province). The widget's date is
   **raised** to it where the estimate is later, **never lowered**.
6. Returns `open`.
- **The sync box's default and persistence.** The box starts unticked: the window is made fresh each time and nothing
  ticks it. That is inferred from the factory making a new window and from no write to its state being found. The global
  byte only mirrors the box each frame, so in effect nothing is kept between windows.

### A.6 The date widget

- The class is the existing `DateWidget_*` family; `DateWidget_Construct` (0x60E000) is new in this reading. It wires
  `year_up`/`_down`, `month_`, `day_`, `hour_` and switches the buttons on. **Nothing in the land window switches them
  off** (the air window does, under "continuous").
- **The steps** are those of `FINDINGS-airorders.md` section 9: 8,760 hours, a month by AddMonths, 24 hours, 1 hour, each
  held between the defines' `start_date` and `end_date`.
- **There is no floor at "now"**, so the date can be stepped into the past. With sync on, it is pushed back up to the
  estimate on the next frame.
- **The text** is written by DateWidget_ShowDate through 0x44CB60 with two flags 1, 1. That formatter was not read; the
  screenshots show it as "1936 Jan 1 0:00".

### A.7 Accept (OnAccept, 0x73D760)

1. Only where the view's unit still resolves and a row is ticked.
2. **The type** is the ticked checkbox's name looked up in the dynamic token map, or 0xC where absent.
3. **The two dates** are:
   - without sync: (the widget's date, the null date);
   - with `move_order` ticked and sync: (the null date, the arrival estimate, computed afresh).
4. **For every selected thing that is a land unit (slot 15) and is not retreating (CUnit +0x158)**: a
   `CSetOrderCommand(unit, type, province id, first, second)` is posted to the command channel. The constructor's
   defaults stay: stance 1 (defensive), stop -1000, time 2. `CSetOrderCommand::Execute` writes the first date into the
   unit's `move_not_before` (+0xCC) and the second into its `end_date` (+0xD0).
5. The window closes (`open` cleared).

**In plain words:**
- **Without sync**, the order does not start before the hour in the date widget.
  - `CMoveOrder::Start` routes only once now >= +0xCC, and `CUnit::AdvanceMovement` does not move a unit before +0xCC.
  - An hour already past holds nothing back.
- **With sync**, every unit starts now and **none arrives before the slowest one's estimated arrival**; +0xD0 holds a
  unit at full progress until that hour (`FINDINGS-movement.md`).
  - The widget's own date is then ignored at accept; it only displays the estimate.
  - `CMoveOrder` routes through `CPathFind::Find` and `SetUnitPath`, not `CMoveCommand::RouteUnit` (which nulls both
    dates). So the dates should survive; that is inferred.
- **No stance is chosen** in this window: every land order goes out with the defensive stance and the defensive
  organisation limit as its stop. That is inferred from the defaults; what an order does with them is section B's.

**Cancel.** `OrdersView_Cancel` (0x742A90) only clears `open`. It is shared with the air window, which
`FINDINGS-airorders.md` section 12 had listed as unread.

**The third glue (+0x16C -> 0x73D8D0, ClearUnitOrder)** is wired to nothing:
- what it does: where the unit has an order whose slot 24 answers yes, it posts `CSetOrderCommand(unit, 0x18D the null
  order, 1, now, now)`;
- it is the same body as the air view's unwired +0x350 glue;
- the search behind "wired to nothing": findValue of the handler finds only the constructor's store, and no `lea` of
  +0x16C appears in the view's code. The same search does find the accept and cancel glues' `lea`s. An image-wide search
  for a `lea` of +0x16C was not run.

### A.8 Tooltips (slot 6, 0x7476B0)

- **Only `daytime_title`, `daytime_icon` and `daytime_icondesc` answer.** They say `ORDER_DAY_TIME_DESC`: "Estimated local
  day time in §Y$PROV$§! when the mission begins is: §Y$TIME$§!". TIME is Night or Day at the date widget's hour.
- **Everything else answers empty**: the rows, accept, cancel, the sync box, the date widget. **So unlike the naval and
  air windows, a row shows no description.** Whether another layer answers for the rows was not looked for.
- **Every `.gui` tooltip in the window is empty.**
- **Other slots.** Slot 3 (IsShown) is the window's shown byte. Slot 4 is the shared `ret 8`, so with the land window up
  a right click on the map does nothing, as with the naval window. Slot 5 tail-jumps to the window's slot 37, taken to be
  "is the pointer over it" (inferred, as for the air view).

### A.9 The two screenshots

**1. "Reppen" (own province).**
- **The three rows** are in the constructor's order, all listed.
- **"Strategic Redeployment" is ticked** because neither support attack nor move may be given there: support attack wants
  the province's controller to be an enemy and an edge from the unit's province; move wants an edge (section B.2). So
  Reppen was not a neighbour of the unit's province (inferred), and those two rows were greyed - which the screenshot
  bears out: both their boxes are filled grey, where an enabled unticked box is an empty outline.
- **No sync box**, because Move Order is not ticked.
- **"1936 Jan 1 0:00"** is the hour the window opened.
- **"Locally in Reppen:" with the moon and "Night".** IsNight at hour 0 in January: local = (x*24/5616 + 0 + 12) % 24.
  With x about 3003 (taken from tfh/map/positions.txt's building positions as a stand-in for the template's x; inferred)
  that is 0, which is night.

**2. "Brodnica" (enemy province).**
- **"Support Attack" is ticked**: the ladder tries it first, so Germany was at war with Poland and the unit stood beside
  Brodnica. Move Order's box is an empty outline - it may be given - and Strategic Redeployment's is filled grey.
- **No sync box**, because Move Order is not ticked.
- **"1936 Jan 4 11:00"** cannot be the arrival estimate, since that raise needs Move Order ticked and sync. So it is the
  hour the window was opened, or it was stepped by hand.
- **The sun and "Day".** x about 3070 gives local (13 + 11 + 12) % 24 = 12. That is day at any January latitude.

### A.10 Not read

- The listbox entry class (0x28 bytes, vftables 0x15FE808 and +0x1C 0x15FE838).
- The radio group's internals beyond select-by-name (0xAD53E0).
- The date formatter 0x44CB60.
- What a checkbox does with +0x136 cleared beyond refusing clicks (0xA81AA0).
- The project's Ghidra copy was not used; everything was read on the listing.

## B. The rows

*Reader B's synopsis.* It set out to account for the three rows of the land orders window: their text, what decides
whether each can be given, and what each does once given. The constructor (section A's) offers Move Order, then Support
Attack, then Strategic Redeployment. The land row adder `0x73CBA0` lists every row and asks each selected unit only the
order's **slot 11**. The default tick is a ladder over those answers: support attack if it can be given, else move, else
redeployment. The order classes' own virtuals explain both screenshots, so the tick follows the orders' slot 11, not
anything in the view. Nothing was corrected; there is one lead about `CreateOrder`'s recorded arguments (B.5).

Addresses are VAs unless marked rva. Only valid for this build. On mod-ability: every key and text below is in the
localisation and can be changed by a mod. Every test is written into the exe and cannot be modded. The figures named as
defines (`UNIT_ATTACK_DELAY`, `STRAT_REDEP_*`) are mod-able in `defines.lua`.

### B.1 Which orders, in which order, and what each row says

The constructor makes three orders and hands each to the land view's row adder (`0x73CBA0`, section A's):

1. `CMoveOrder`, by `CMoveOrder::CMoveOrder` (`0x5836A0`)
2. `CSupportAttackOrder`, by an inlined copy of `0x583710`
3. `CStrategicRedeploymentOrder`, by `0x583790`

That matches both screenshots' order. Each row's `name` comes from the order's slot 6, `COrder::GetNameKey`
(`0x587980`). It is shared by all three and is `OrderMissionIndexToKey(OrderTypeToMissionIndex(type))`:

| order | type | mission index | key | English (`orders.csv`) |
| --- | --- | --- | --- | --- |
| CMoveOrder | 0x255 `move_order` | 3 | `MOVE_ORDER` | "Move Order" |
| CSupportAttackOrder | 0x4E5 `support_attack` | 1 | `SUPPORT_ATTACK` | "Support Attack" |
| CStrategicRedeploymentOrder | 0x5A4 `strategic_redeployment` | 2 | `ORDER_STRATEGIC_REDEPLOYMENT` | "Strategic Redeployment" |

The constructors (this in EAX, unit in ECX, province on the stack, `ret 4`) all write the same COrder defaults:
- CPersistent token `none` (0x18D)
- stance 1, stop -1.0, time 2, priority 0
- no target, `return_to_base` 0
- both dates the null date

Support attack adds `combat` = 0. `CreateOrder` calls the same three constructors (`0x583B60`, `0x583C12`, `0x583D0F`).

### B.2 What decides whether a row can be given: slot 11

**The land row adder asks only slot 11, once per selected unit** (`CInGameIdler +0x1304`). It sets the order's unit
(+0x8) to each unit in turn. If any unit's answer is no, the row's checkbox is disabled (enabled byte +0x136 cleared).
The adder answers true only when every unit said yes.

**Where the land view differs from the naval one:**
- **No range test.** The naval `AddOrder` also asks `COrder::IsTargetInRange`; the land one never does. Slot 8 on
  support attack and redeployment is the folded ReturnTrue anyway.
- **Rows are never left out.** All three are always listed.

The three slot 11 bodies:

- **Move Order** (`CMoveOrder::MayBeGiven`, `0x587A80`, already recorded; re-read): for a land unit, it is in no battle,
  the province it stands in **has an edge to the target**, and then `CanMoveTo` (slot 35).
  - **So the window's Move Order can only be given to a neighbouring province.** A plain right click moves any distance;
    this row does not.
- **Support Attack** (`0x587F30`):
  - `CCountry::IsEnemy(the target's controller, the unit's owner, the target)`. That is at war, REB on either side, or an
    undeclared war covering the province.
  - The unit is in no battle (`+0x11C`).
  - The unit's province **has an edge to** the target.
  - Nothing else: no battle needs to be under way there, no enemy unit needs to be present, and neither `CanMoveTo` nor
    the range is asked.
- **Strategic Redeployment** (`0x5883A0`): false where
  - the target's controller counts the unit's owner an enemy;
  - the path the unit already has crosses enemy-held ground (`CUnit::PathCrossesEnemyProvince`, `0x5D3A30`);
  - the unit is in a battle;
  - either the unit's province or the target has no owner area (`+0x2B4`), or an area with no provinces
    (`COwnerArea +0x2C`).
  - Otherwise true. **No test of distance, of a way existing, of `CanMoveTo`, or of the unit's kind** - a neighbour is
    accepted.
  - **One test is dead.** Where the unit's area has a region group (`+0x6C`), `CList_Contains(group, target's area)` is
    called at `0x588428`, and `mov al,1` follows with nothing in between. The answer is discarded; `CList_Contains`
    writes nothing, so it decides nothing.
  - *Inferred*: a neutral or no-access destination therefore passes slot 11. It then fails only when the very-safe route
    finder finds no way (B.4).

### B.3 The oracle, accounted for

The ladder is section A's to record; reader B only read it, at `0x73C891`-`0x73C8EA`:
- support_attack where its row passed for every unit;
- else move_order;
- else strategic_redeployment;
- else nothing is ticked.

So the default tick is decided by the orders' own slot 11.

- **Reppen** (own province, at peace): Strategic Redeployment is ticked.
  - Support attack fails: the controller is Germany, not an enemy.
  - Move must have failed for at least one selected unit. That is certain from the ladder. *Inferred*: Reppen was not
    beside the unit's province, since at peace and in its own country the battle and `CanMoveTo` tests are unlikely to
    fail.
  - Redeployment passes.
- **Brodnica** (Poland, at war): Support Attack is ticked. So every selected unit stood beside Brodnica and was in no
  battle.
  - Strategic Redeployment **fails** there, because the destination is enemy-held. Move would pass.
- **"All three look enabled"**: by the bytes, Move Order in Reppen and Strategic Redeployment in Brodnica had their
  checkboxes disabled.
  - Whether the original draws a disabled checkbox any differently is a GUI matter not read.
  - Clicking that row in the same situation would show whether a disabled row refuses the tick.

**A row that cannot be given has no tooltip.** The land view's slot 6 (`0x7476B0`, `ret 8`; section A's) answers only
`daytime_title`, `daytime_icon` and `daytime_icondesc`, with `ORDER_DAY_TIME_DESC` built from `ORDER_DAY`/`ORDER_NIGHT`,
`PROV` and `TIME`. There are no other string references in it, and no call to an order slot. Positive control: the naval
view's slot 6 does give rows `OrderMissionIndexToDescription` and `OUT_OF_RANGE`. So unlike the naval window, a land row
shows neither its `_DESC` nor a reason.

### B.4 What the orders do once given (beyond what was recorded)

Already in the record, so not repeated here: redeployment speed (`STRAT_REDEP_BASE_SPEED` times infrastructure), supply
times `STRAT_REDEP_SUPPLY_MOD`, no fuel, organisation regain less `STRAT_REDEP_ORG_LOSS`, the `stratArrow`, the AI's use
of both orders, and `RouteUnit`.

**Support Attack.**
- **Start** (`0x587FB0`): a unit with a path is stopped where it stands (`CancelMovement(unit, false)`). Nothing is
  routed.
- **IsActive** (`0x587FD0`), each hour, in this order:
  1. Before `move_not_before`: wait.
  2. **In a battle**: the first such hour starts the attack delay (`CUnit::StartAttackDelay`) and sets `combat`. Every
     such hour adds 1 to `hours_attacking` (`+0xD8`). Keep going.
  3. Not in a battle with `combat` already set: the battle is over. `CancelMovement(unit, true)` and the order ends.
  4. An attack delay running: wait.
  5. A **land** battle in the target (`HasCombatOfKind(.., 1)`): with no path, a plain `CPathFind` one step in and
     `SetUnitPath` (clear). The hourly `CheckForCombat` on the next province then joins the battle.
  6. No land battle there: a unit with a path has it cancelled *with the order reset*, which drops the order. Otherwise
     wait.
- So **a support attack waits beside the province, indefinitely, until a land battle begins there.** Since
  `AdvanceMovement` adds no progress under 0x4E5, it never enters. That is what `SUPPORT_ATTACK_DESC` says: "help out
  attacking a target, without moving into that province".
- It ends the hour its battle is over. If its battle is gone before it joins, the order is dropped.
- Its save writes `combat=yes` only once it has joined (`0x588370`).
- The unit panel shows `SUPPORT_ATTACK_D`, "Support Attack on $WHERE$." (`0x5881B0`).

**Strategic Redeployment.**
- Start is `RouteUnit_Thunk` (recorded): a `CVerySafePathFind` route straight away.
- **IsActive** (`0x588450`), each hour:
  - In the destination: done.
  - Otherwise **`StartAttackDelay` every hour of the journey**. That is at least 12 hours, from `UNIT_ATTACK_DELAY`
    (mod-able) plus its random part, drawn on the game's generator each hour for each redeploying unit. So the unit
    always arrives with a fresh attack delay. *Inferred*: by the movement rules already recorded, it then cannot set off
    again before the delay runs out.
  - Where the next province is enemy-held (for an expeditionary unit, judged against the country that lent it) or **has
    a battle in it**:
    - if it is the destination, the order ends (path cancelled);
    - otherwise the path is cancelled and re-routed with the very-safe finder, and the order ends if no way is found.
  - In a battle: the order ends.
  - No path: re-route, and the order ends if that fails.
- The panel line is `STRAT_REDEP_D`, "Strategic Redeployment($UNIT$)". **UNIT is the destination province's name**, not
  a unit's.

**Move Order** in the land window is the recorded `CMoveOrder`; nothing new.

### B.5 Leads and gaps

- **`CreateOrder` (rva `0x183AA0`) is recorded `(int typeId, void* arg)` "arg 0 in both sites read".** In the move case
  (`0x583B5D`) it pushes EBX as the constructor's province and hands its EDI over as the unit. So its real arguments look
  like (type, province), with the unit in EDI. *Inferred* from that one case; not revised.
- **`CUnit::StartAttackDelay`'s comment names one caller; there are four**: CheckOrderAndCombat `0x5BA93F`, both
  IsActive bodies, and `0x5D0B00`.
- **`hours_attacking` (`+0xD8`) has another writer**: support attack's IsActive.
- Not read: whether a disabled checkbox is drawn grey or refuses clicks (GUI) - section C has the first; `COrder::SaveContents` (`0x587530`); what
  the dead region-group test was meant to be.

## C. A greyed row's box, and the date widget's text

*Read 2026-11-04 in the collecting session, after the maintainer asked for the greyed boxes.*

**`CCheckBox_ShowState`** (`0xA81AA0`, rva `0x681AA0`; `ret 4`, the checkbox on the stack, ECX unused; 38 direct
callers, among them the ones that set the enabled byte and then call it, `0x650FD9`..`0x650FE0`) **sets a checkbox's
frame from its state**, through its sprite (`+0x64`, slot 23 - the frame setter):

| enabled `+0x136` | state `+0x60` | frame |
| --- | --- | --- |
| set | 0, unticked | 1 |
| set | 1, ticked | 2 |
| set | 2 | 3, with an object at `+0x7C` timed and one at `+0x80` placed at the box's corner plus (30, 10) - not read further |
| **clear** | **any** | **4** |

So **a checkbox that is switched off shows its fourth frame, whether or not it is ticked**. `GFX_checkbox_default`, the
`order_entry` row's, has four frames - an empty box, a ticked one, and two grey filled ones - and no `effectFile`, so
nothing tints it: the grey box of the maintainer's screenshots is frame 4. The second table on the screenshots is
consistent with section B.3: Reppen's Move Order and Support Attack boxes and Brodnica's Strategic Redeployment box are
the grey ones, Brodnica's Move Order an empty outline.

**The date widget's text** (`datewidget.gui`'s `date`, font `timefont`) is not read - the formatter `0x44CB60` was not
opened - but **measured** on the two screenshots: `1936 Jan 1 0:00` and `1936 Jan 4 11:00`, the year, the month's name
cut to three letters, the day and the hour, single spaces, nothing padded. `timefont.fnt` gives every one of its 143
characters an `xadvance` of 10, and on both screenshots each character starts exactly 10 pixels after the last - from
the `J` of `Jan` at x 137 and 125 back to the year and on to the hour - so the characters stand in the cells of
`time_overlay` (176 pixels, under the text 2 to the left of it) by the font's advance alone.
