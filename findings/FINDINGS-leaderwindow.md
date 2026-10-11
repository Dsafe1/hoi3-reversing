# The window a leader is chosen in

Read on 2026-10-11 for the fourth piece of OpenHOI3's leaders. Static reading of `hoi3_tfh.exe`;
**every address is a VA** (image base `0x400000`) unless it says rva. `FINDINGS-leaders.md` had
promotion's command (`CPromoteLeaderCommand`), `FINDINGS-leaderassign.md` the choice and
`CUnit::SetLeader`, `FINDINGS-commands.md` the "remove all" command and its dialog's confirm; this
reads the window between them and the unit panel's button that opens it.

**Synopsis.** The window is `CLeaderAssignmentPanel` (no RTTI of its own; named from its
`CButtonObserverGlue<CLeaderAssignmentPanel>` members), the `.gui` window
`leader_selection_panel`, made fresh by the unit panel's `leader_button` (and `leader_photo`) and
destroyed by the panel's next update once its window is hidden. It lists **the unit's owner's
leaders in service, of the unit's kind, who command nothing or this unit, and who pass the trait
filter**, sorted by one of four keys held in two process-wide statics - **name ascending, the
other three descending**, by the runtime's `std::sort`, so the order of equals is the
introsort's - and reversed on a second click of the same key. A row's button posts
`CAssignLeaderCommand(unit, leader, 1)`; "no leader" the same with the null leader; "remove
all" a confirmation and then `CRemoveAllLeadersCommand` for the **player's** country; the two
promotion buttons `CPromoteLeaderCommand` of one rank either way; the checkbox
`CToggleAutoAssignLeadersCommand` for the player's country. The trait filter is a set per leader
type kept in the current game state, all on to begin with. **Corrected on the way**: the unit
panel's rule for when `leader_button` can be pressed (`FINDINGS-unitpanel.md` section 4, point 7)
- what it called "an enemy's unit" is a unit **standing where an enemy of the player holds the
province**, what it called "an air or sea unit without the base it needs" is **a land unit
aboard a ship or an aircraft**, and the expeditionary force's disabling is **undone in the same
pass**.

## 1. Opening and closing

`CUnitView`'s constructor registers `leader_button` and `leader_photo` with one glue at `+0x128`
whose ordinary click is **`CUnitView::OnLeaderButton` (`0x76E2E0`)**: unless a custom game's
setting forbids changing leaders (`0x4208B0`), it destroys any panel at `+0x34` (`0x769010` and
`free`) and **always makes a new one**, `new(0x1FC)` and the constructor `(unit, screen)`. Ghidra
shows the destroy as the whole of the else branch; the listing (`0x76E321`..`0x76E3D9`) falls
through into the construction and stores it at `+0x34`. The same glue's other event is
`0x76E3F0`, which hands the unit's leader to `0x73AF60` - not read.

`CUnitView::Update` (`0x76C7F0`) calls the panel's update every frame (`0x76CC90`) and then, where
the panel's window is hidden (`+0x5B` zero), destroys it and clears `+0x34` (`0x76CC95`..`0x76CCB7`).
So every handler below that ends by hiding the window ends the panel.

`0x769010`, the teardown: save the filters (`0x769230`), destroy the window, destroy the filter
window, free the filter map.

## 2. The constructor, `0x7671A0`

`(storage, unit, screen)`, `ret 0xC`; `0x1FC` bytes.

- `+0x1E4` **the leader type of the window**: the unit's slot 17 (air) gives 2, else slot 15
  (land) 0, else slot 16 (naval) 1, else 3.
- `+0x04` the unit; **`+0x1E0` the unit's leader (`+0x12C`) as the window opens**, kept for its
  life - the promotion buttons of the head act on him.
- the window `leader_selection_panel`, and handlers for `back_button`, `noleader_button`,
  `removeall_button`, `promote`, `demote`, `sort_name`, `sort_skill`, `sort_rank`, `sort_traits`,
  `filter_traits` (two events) and the checkbox `auto_assign` (both its events).
- the head, from that leader: `selected_leader_name` his name (`+0x4C`; the null leader's is the
  localised `NO_LEADER`, set by `CNullLeader`'s constructor `0x57F380`); `selected_leader_skill`
  his skill (`+0x70`) as a decimal - the site BiceLib hooks; `selected_leader_traits` a
  `CTraitEntry` (`0x765210`, the window `trait_entry`, its `trait_icon` the sprite `icon_` + the
  trait's key where it exists) for each of his traits in order.
- **with the null leader** (slot 8 false): `promote` and `demote` **disabled** (`+0xBC`); and
  for a land unit with `5 - oob_level` above 0, `selected_leader_rank`'s frame is that - the rank
  the unit asks for. The first update overwrites it (section 3).
- **with a real leader**: `selected_photo` the sprite `GFX_empty_position` with the file
  `gfx/pictures/portraits/` + his picture (`+0xA8`) + `.tga`; `promote` and `demote` enabled.
- `auto_assign` ticked where **the player's** country's `auto_assign_leaders` (`+0x74B`) is set -
  not the unit's owner's.
- then the filters loaded (`0x769100`, section 6), the list filled (`0x768950`), the filter
  window made (`0x766ED0`) and hidden, the panel shown.

## 3. The update, `0x7697A0`

`selected_leader_rank`'s frame is the remembered leader's rank (`+0x6C`; icon frames count from 1,
so the null leader's 0 is frame 0 - what the icon then draws was not read); each row's slot 8; and
where a custom game's setting forbids changing leaders, the panel saves and hides itself.

## 4. The list, `0x768950`

    leaders = a copy of the unit's owner's (+0x128) active_leaders (+0xE00), in order
    keep l where
        l.rank (+0x6C) != 0
        and (unit is not land  or l.type == 0)
        and (unit is not naval or l.type == 1)
        and (unit is not air   or l.type == 2)
        and (l.unit (+0x40) is null or is this unit)
        and the trait filter passes:
            l has no traits (+0x38 < 1):  filter[null trait]
            otherwise:                    any of his traits t with filter[t]
    sort by g_LeaderListSortKey, then reverse the whole where g_LeaderListSortReversed
    leaderlist: rows whose leader is still in the same place kept, the rest made (0x7703E0)

`filter[t]` is `std::map::operator[]` (`0x76FC20`), so **a trait the map does not hold is added
as off**. A row is the window `leader_entry_land`, `leader_entry_naval` or `leader_entry_air` by
the **leader's** type.

**The sort** (`0x7709C0`, `0x770AA0`, `0x770C60`, `0x770B80` - the runtime's `std::_Sort`, one
instantiation per key, each with its own insertion sort and partition):

| key | button | order | compared |
| --- | --- | --- | --- |
| 0 | `sort_name` | ascending | the name as a `std::string`: bytes unsigned, then the shorter first (`0x7717B0`, `0x770D40`; the byte compare `0x415F70` takes its two pointers in `edx` and `ecx`) |
| 1 | `sort_skill` | descending | skill `+0x70` (`0x771BA0`: `first.skill < x.skill` moves `x` to the front) |
| 2 | `sort_traits` | descending | the count of traits `+0x38` (`0x772220`) |
| 3 | `sort_rank` | descending | rank `+0x6C` (`0x771EE0`) |

`std::_Sort` is the one this runtime ships: below 33 elements an insertion sort; above, the
three-way partition `_Unguarded_partition` (`0x770D40`, `_Median` `0x7715C0` - a median of three,
of nine over 40) recursing into the smaller part, the depth budget `n` cut to three quarters at
each step, and a heap sort when it runs out. **The sort is not stable**, so leaders of one skill
come out in whatever order the partition leaves them, from the order the country put them in
service.

**Checked by running it.** The four instantiations (`0x7709C0`, `0x770AA0`, `0x770C60`,
`0x770B80`) were run under an x86 emulator (unicorn), the image's sections mapped and synthetic
leaders laid out with the four fields they compare, on 1,360 lists of 1 to 300 leaders with many
equal keys; a copy of the runtime's `std::sort` written from the library's source gave the same
order every time. The heap-sort fallback was never reached at those sizes, so it rests on the
library's source alone.

**The sort buttons** (`0x768DC0` name, `0x768E00` skill, `0x768E40` rank, `0x768E80` traits): the
key already chosen flips `g_LeaderListSortReversed` (rva `0x168560B`); another key sets it and
clears the flag. Both statics (`g_LeaderListSortKey`, rva `0x1685624`) are in zeroed data and
nothing else writes them, so **every game of the process starts sorted by name, ascending, and a
choice outlives the game**.

## 5. A row, `CLeaderAssignmentEntry`

Constructor `0x765490`, `(storage, panel, screen, leader, unit, windowName)`, `ret 0x18`; the
panel at `+0x78`.

- `leader_name`, `leader_skill` (the decimal - BiceLib's other hook site), `leader_rank`'s frame
  his rank, `leader_traits` a `CTraitEntry` per trait, `photo` his portrait as the head's.
- **`leader_button` is disabled unless `CUnit::MayTakeLeader(unit, leader, onlyFree = 1)`**
  (`0x76587B`) - so a leader listed whom the unit cannot take (the wrong rank for a land unit's
  level, a division of one brigade) shows and cannot be chosen.
- `promote` and `demote` are left as the file has them.
- three handlers: `leader_button` `0x7664E0`, `promote` `0x7662E0`, `demote` `0x7663E0`.
- slot 8, the update (`0x766680`): where the leader's rank is not the frame shown, the frame is
  set again and `leader_button` re-tested as above.

## 6. The trait filter

**The state is per leader type, in the current game state**: `CCurrentGameState +0xD6C + 0x10 x
type`, a vector of the traits that are on (four, for the four types of section 2).

- **Load** (`0x68C550`, called from `0x769100`): an empty vector - the first time - turns on
  **every trait in `CTrait::database()` that is real** (slot 13: `mov al,1` on `CTrait`,
  `xor al,al` on `CNullTrait`) and the null trait where its allowed byte for the type
  (`+0x2B0 + type`) is set; otherwise every entry off and the saved ones on.
- **Save** (`0x68C450`, from `0x769230`, every time the panel hides or is destroyed): the vector
  becomes the entries that are on.
- **`LoadTraits` (`0x5B46B0`) clears the database and pushes the null trait first**
  (`0x5B4783`..`0x5B478D`, through the same `0x45C500` that adds each trait of the file at
  `0x5B488D`), and `CTrait`'s constructor sets all three allowed bytes (`mov eax,0x1010101` at
  `0x5B289E`). So the null trait - "a leader with no trait" - is on to begin with for every type.
- **The filter window** (`0x766ED0`, `leader_trait_filters`, list `filterslist`) has a
  `CTraitFilterEntry` (`0x766920`, `leader_trait_filter_entry`) for each trait of the database
  allowed for the type (every one for type 3), in the database's order: the null trait first,
  as the text `NO_TRAIT_FILTER`, then the file's. Its checkbox `background` shows the map's flag.
- a row's checkbox: ticked (`0x766D20` -> `0x768120`) turns its trait on, unticked (`0x766D30` ->
  `0x768150`) off, each refilling the list; a third event (`0x766D10` -> `0x768ED0`, the glue's
  slot 5, which takes an argument) **shows only that trait** - every other off - or, where it is
  already the only one on, **turns every trait on**. Which mouse event slot 5 is was not read
  in the bytes; it was inferred a right click, and **the maintainer confirmed it on 2026-10-11**
  from the running game.
- `filter_traits`: its glue's slot 2 (`0x768FE0`) shows the filter window where it is hidden and
  hides it where it is shown; its slot 9 (`0x768EC0` -> `0x768050`) turns every trait on and
  refills. Slot 1 is the ordinary click on every other button of the panel; **which events slots
  2 and 9 are was not read** - `inferred` from use: slot 2 is the plain click on the economy
  slider's and the statistics ledger's buttons, so the left click opens the filter, and slot 9 a
  right click - **which the maintainer confirmed on 2026-10-11**: a right click on the filter
  button turns every trait on.

## 7. What each button posts

| element | handler | what |
| --- | --- | --- |
| `back_button` | `0x7692F0` | save the filters, hide |
| `noleader_button` | `0x769510` | `CAssignLeaderCommand(unit, CLeader::null(), 1)`; save, hide |
| `removeall_button` | `0x769630` | the dialog `CConfirmRemoveAll` (`0x748610`: the window `DefaultConfirm`, `CONFIRM_REMOVEAll_TITLE`, `CONFIRM_REMOVEALL_DESC`); save, hide **at once**, whatever the dialog is answered |
| `promote`, `demote` | `0x769310`, `0x769410` | `CPromoteLeaderCommand(the remembered leader, 0 / 1, 1)` - up or down one |
| `auto_assign` | `0x7687D0` | `CToggleAutoAssignLeadersCommand(the player's country)` |
| a row's `leader_button` | `0x7664E0` | `CAssignLeaderCommand(unit, that leader, 1)`; save, hide |
| a row's `promote`, `demote` | `0x7662E0`, `0x7663E0` | `CPromoteLeaderCommand(that leader, 0 / 1, 1)` |

**The dialog's two answers**: `CEU3Dialog`'s slots 5 and 6 are one body, `0x670BC0`, `mov byte
[ecx+0x64], 1; ret` - the dialog marked done - and `CConfirmRemoveAll` overrides slot 5 alone, with
`OnConfirm`, which posts the command and then sets `+0x64` itself. So slot 5 is the agreeing answer
and slot 6, left to the base, only closes - `inferred`: which button reaches which slot was not
followed past the generic registration at `0x4355B0`. The record had said `CConfirmRemoveAll` put
one body in both slots; it is the base that does.

The window stays up after a promotion: the head's rank is redrawn by the update, a row's by its
slot 8. A land leader promoted or demoted while he commands a unit is taken off it
(`FINDINGS-leaders.md`), and the list is not refilled - **his row stays in the list with its
button tested against the window's unit as before**.

## 8. The commands

- **`CAssignLeaderCommand::IsValid`** (slot 14, `0x5D79F0`): false where the unit does not resolve;
  the leader is resolved, null becoming `CLeader::null()`; **true where the leader is not real**,
  otherwise `CUnit::MayTakeLeader(unit, leader, the command's flag +0x8C)` (`0x5D7A8B`). The window
  always sets the flag. Execute is `FINDINGS-commands.md`'s: off his old unit with `SetLeader(old,
  null, 0, 0)`, then `SetLeader(unit, leader, 1, 1)` - his banked trait hours thrown away and the
  unit's brigades left `NEW_LEADER_ORG_HIT` of their organisation, both only where he is real.
- **`CToggleAutoAssignLeadersCommand::Execute`** (slot 6, `0x5D8230`): the country's (`+0x40`, an
  id) `auto_assign_leaders` flipped. Its slot 14 is the shared `mov al,1; ret`.
- `CRemoveAllLeadersCommand::Execute` (recorded): every unit of the country not on loan,
  `SetLeader(unit, null, 1, 0)` - no organisation lost.

## 9. When the unit panel's `leader_button` can be pressed

`CUnitView::Update`, `0x76D54D`..`0x76D814`, in this order:

    expeditionary_owner_id (+0x290) set          -> disabled, and go on
    retreat (+0x158)                              -> disabled, stop
    combats_count (+0x11C) >= 1                   -> disabled
    else a fleet (slot 16) in a province that is not land
        (+0x130 -> +0xD4 -> is_land +0x22 zero)  -> disabled
    else the province's controller (+0x338) an enemy of the player (CCountry::IsEnemy)
                                                  -> disabled
    else a land unit (slot 15) whose slot 9 object has +0x300 set, or +0x304 set
        (aboard a ship, aboard an aircraft - FINDINGS-counters.md, inferred)
                                                  -> disabled
    else                                          -> enabled

**The first test's disabling is undone by the last line**: an expeditionary force's button can be
pressed whenever none of the others holds. Nothing asks whose unit it is. And **only the button is
disabled**: `leader_photo` is registered with the same glue (section 1) and nothing here touches
it, so a click on the portrait opens the window where the button cannot be pressed - `inferred`
that an icon's click reaches its observers as a button's does, `CIcon` deriving from `CButton`. Then `leader_types`'
frame is the leader's type plus 1 - the null leader's 0 gives frame 1.

## Not established

- `0x73AF60`, which the unit panel's second event on `leader_button` hands the unit's leader to.
- Which mouse events the button glue's slots 2 and 9 and the checkbox glue's slot 5 are **in the
  bytes**: the maintainer confirmed the right clicks of this window from the running game, which
  says what these three handlers answer to, not how the glue dispatches in general.
- What an icon draws for frame 0.
- `0x7681C0`, the panel's tooltip routine, and `0x766060`, a row's tooltip of an element - the
  gainable-trait progress for `gaintrait_info` (through `0x765D40`), the trait's two texts for a
  `trait_icon`, the leader's tooltip for `photo`. Read for its shape only; the tooltips are their
  own piece.
- Whether `CCurrentGameState +0xD6C` is saved with a game.
- Nothing here was watched in a running game.
