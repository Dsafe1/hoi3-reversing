# A battle in a save: what it holds and what a load rebuilds

*The saved-battle wave, 2026-11-05: two readers, read statically out of `hoi3_tfh.exe` with `scripts/disasm.py`,
`scripts/findRefs.py`, `scripts/vtable.py` and a copy of the Ghidra project, and set against the maintainer's 33 saves in
`Documents\Paradox Interactive\Hearts of Iron III\save games`. Only valid for this build. For OpenHOI3, whose savegame
loader had read everything but the top-level `combat` block and `sunk_ships`. `FINDINGS-savegame.md` is the wave this
completes.*

**The wave in one paragraph.** **A live battle** (section A) is made blank by the battle manager, put on its list - land,
naval and air battles at the back, bombings at the front, so **a load reverses the bombings' order** - and read side by
side: each `unit` key runs the side's own join step as in play, `size` (one figure per sub-unit type, `---` first, then
the `units/*.txt` files in byte order of their names) then overwrites what the joins added, `tactic` is a place in
`common/combat_tactics.txt` counting from 1, and the land lists are appended as given. As its block closes the battle
is marked begun - so its start step never runs again - each unit and the province get it back, and a land battle's
**attacker** front is set up twice and its defender's never. Game entry then zeroes every battling unit's `disengage`
and `possible_retreat` and applies each side's modifiers; a naval battle's ships are all rolled a fresh distance about
100 out. **A bombing** (section B) has a bomber side saving four tallies besides the shared keys - strength dealt,
buildings (`nobuilding` and then `buildings.txt`), stockpile and production (seven goods each) - and a bombed side that
saves as a plain one. **The finished battles** are kinds 1 to 6 (land, naval, air, ground, land and naval bombing),
appended on load and pruned at the first hour to a week; the session reset never empties them. **`sunk_ships`** is every
ship that has left the game this session, sunk or disbanded or removed, never pruned, read before `combat` so that a
side's `sunk_ship` ids resolve into it.

**Corrected in the record**: `CLandCombatant::LoadKey` has three keys - `retreat` too; naval `positioning` is fixed point;
the `sunk_ship` id is the ship's own pair; `CCombat::AttachAndRegister` is the combat's AfterLoad and nothing else;
`CCombatHistoryEntry +0x20` is the convoy-battle bool, not an int flag; rva `0x15FE90` is
`CBomberCombatant::SaveContents`; `CCombatHistory_BuildEntry_A` is `CCombatHistory_LoadEntries`; and the "second
`type=`" `FINDINGS-savegame.md` left open in a history entry was a census artefact - no entry has two.

| section | reader | fragment |
| --- | --- | --- |
| A, a live battle and what a load rebuilds | A | `fragments/merged/saved-battle.json` |
| B, bombings, finished battles and sunk ships | B | `fragments/merged/saved-bombing.json` |

## A. A live battle in a save, and what a load rebuilds of it

*Reader A, saved-battle wave, 2026-11-05. Read statically from `hoi3_tfh.exe` with disasm.py, findRefs.py, vtable.py and a headless Ghidra 12.1.4 copy. Checked against all 33 saves in `Documents\Paradox Interactive\Hearts of Iron III\save games`, field by field on `Ireland1938_08_03_14` (four land battles), `Ireland1936_02_02_04` (an air battle), `Ireland1937_07_05_02` and `Ireland1937_11_02_21` (a naval battle each). Only valid for this build. **[exe]** means hardcoded; **[mod: …]** means a file can change it. Reader B has the bombings, the finished-battle `history` and `sunk_ships`.*

**Synopsis.** How a save holds a live land, naval or air battle and what a load does with it: every key and the field it fills, the writers' order and conditions, and what a load rebuilds, leaves at default or gets wrong - settled from the bytes and checked against all 33 saves, which hold 27 live battles with 54 sides (24 land, 2 naval, 1 air). **Corrected rather than added**: `retreat` is loaded as well as saved - `CLandCombatant::LoadKey` has three keys, not two (definitions.py missed one because the switch opens with a `sub`); naval `positioning` is fixed point, read with ParseFixedPoint, not the `%d` FINDINGS-combat.md has; the `sunk_ship` id is the ship's own pair, not "[node+0xC]"; `CCombat::AttachAndRegister` is the combat's AfterLoad and nothing else, and its land tail sets up the attacker's front twice and never the defender's; and a load rolls every ship's `current_distance` again, about 100 further out, and zeroes every battling unit's `disengage`/`possible_retreat`.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x165010 | CCombatant::SaveContents | new | confirmed | slot 2: dice, unit*, sunk_ship*, losses, size, tactic (only when held) |
| 0x1692D0 | CLandCombatant::SaveContents | new | confirmed | base, then front*, reserves*, retreat* |
| 0x168D00 | CNavalCombatant::SaveContents | new | confirmed | base, then positioning (fixed point) |
| 0x16DEC0 | CAirCombatant::SaveContents | new | confirmed | a jump to the base; never writes positioning |
| 0x169010 | CLandCombatant::AfterLoad | new | confirmed | slot 5: clears front_set_up when the side has units but no list |
| 0x91E40 | CMap::FindTerrainByName | new | confirmed | terrain by exact name from the map's terrain vector, else null |
| 0x2FC60 | CCombatManager::LoadKey | revised | confirmed | each battle arm: new, ctor, AddCombat before the block, slot 6, slot 3 |
| 0x16E0B0 | CCombat::LoadKey | revised | confirmed | the field each key fills; `location` has no bounds check |
| 0x164DD0 | CCombatant::LoadKey | revised | confirmed | each key; `unit` runs the side's AddUnit; `size` overwritten in place |
| 0x169040 | CLandCombatant::LoadKey | revised | confirmed | corrected: three keys incl. `retreat`; sets +0xE0 on every call; no dedupe, no AddUnit |
| 0x168D80 | CNavalCombatant::LoadKey | revised | confirmed | corrected: positioning is ParseFixedPoint, not %d |
| 0x16DED0 | CAirCombatant::LoadKey | revised | confirmed | positioning matched and dropped, value unread |
| 0x16E360 | CCombat::AttachAndRegister | revised | confirmed | AfterLoad only; begun=1/ended=0 as one word; attacker front set up twice, defender never; SumTacticEffects |
| 0x166F20 | CNavalCombatant::AddUnit | revised | confirmed | on load it rolls every ship's distance again, +100 |
| 0x1693A0 | CLandCombatant::AddUnit | revised | confirmed | `in_game` is clear on load, so no reserve append |
| 0x1C7970 | CUnit::ShowFighting | revised | inferred (kept) | +0xA8/+0xAC are disengage/possible_retreat; Enter zeroes them for every unit in a battle |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CCombat | 0x18 | province | CMapProvince* | revised (comment: load path, no bounds check) |
| CCombat | 0x20 | duration | int | revised (comment: hours begun; relation to day) |
| CCombat | 0x24 | terrain | CTerrain* | revised (comment: by name, null if unknown) |
| CCombat | 0x29 | begun | uint8_t | revised (comment: written as a word on load) |
| CCombatant | 0x28 | sunk_ships | void* | revised (comment: corrected, the ship's own id pair) |
| CCombatant | 0x50 | dice | int | revised (comment) |
| CCombatant | 0x64 | own_countries | CList<CCountryTag> | revised (comment: rebuilt from units on load) |
| CCombatant | 0x74 | men_begin | int* | revised (comment: `size`, index order, meaning) |
| CCombatant | 0x84 | losses | int | revised (comment) |
| CCombatant | 0xAC | tactic | CCombatTactic* | revised (comment: numbering, out-of-range) |
| CNavalCombatant | 0x10B4 | positioning | int | revised (comment) |
| CNavalCombatant | 0x10B8 | positioning_roll | int | revised (comment) |
| CLandCombatant | 0xD0 | retreat | CList<CUnit*> | revised (comment: corrected, loaded too) |
| CLandCombatant | 0xE0 | front_set_up | uint8_t | revised (comment: load behaviour) |
| CSubUnit | 0xC8 | current_distance | int | revised (comment: rolled again on load for ships) |

No name or type was changed in either table. The fragment also carries `vftable_slots` for every holder: slot 2/4 of CCombatant, the three target combatants and the land, naval and air sides; slot 5 of CLandCombatant; slot 4/5 of all seven combat classes; slot 4 of CCombatManager. Frontier: 0x17D000, 0x6DE3A0, 0x64E50, 0x394A40. `0x45140` and `0xC8050`, the fixed-vector reader and writer that also carry `size`, are reader B's entries.

### A.1 How the manager makes a battle on load

The top-level `combat` block is read by the battle manager's own key reader. Three of its keys make a live battle [exe]:
- `land_combat` makes a land battle (kind 1).
- `naval_combat` makes a naval battle (kind 2).
- `air_combat` makes an air battle (kind 3).

Each arm does the same five steps, in this order [exe]:
1. Allocate the battle and construct it blank: no sides' contents, no province, `day` = -1, everything else zero.
2. **Put it on the manager's list of live battles.** This happens **before any key of its block is read**. A land, naval or air battle goes to the back of the list, so these battles come back in their saved order. A bombing goes to the front (B.2).
3. **Make both sides** (the kind's create-sides virtual). The attacker side is marked as attacking, the defender side not, and each points back at the battle. The sides exist before anything is known about the battle.
4. **Read the battle's block** into the battle.
5. As that block closes, run **the battle's after-load step** (A.5).

The province is **not** set the way a live battle sets it. `location` and `terrain` fill the province and the terrain separately. `history` goes to the finished-battle list. Any other key in `combat` is dropped silently, its value unread [exe].

### A.2 A battle's keys, in the writer's order

The writer is the same for all seven battle classes. Every key below agrees with all 27 battles in the saves:

1. **`location`** — the province's id.
   - Load: the number is taken as an integer and **looked up directly in the map's province table, with no range check** [exe]. Only the province is set; the terrain is not.
2. **`day`** — integer (A.2.1).
3. **`duration`** — integer (A.2.1).
4. **`attacker`** and **`defender`** — each side's own block (A.3). On load each is read **into the side the manager already made**; a second `attacker` block would load into the same side again.
5. **`terrain`** — the terrain's name, quoted.
   - Written **only when the battle has a terrain**; every save has one.
   - Load: looked up by exact, case-sensitive name in the map's terrain list. **No match gives no terrain** [exe].
   - A writer must always write it, since nothing else sets the terrain on load.

#### A.2.1 `day` against `duration`

They are different counters [exe]:
- **`duration` counts hours begun.** The battle's hourly step adds one at its very start. Before that add, the step only stamps the wars' action dates and, where a side has no tactic or the duration is a multiple of `TACTIC_SWAP_FREQUENCEY`/1000, picks tactics [mod: defines.lua `TACTIC_SWAP_FREQUENCEY`, 24]; the multiple test uses the value before the add.
- **`day` counts rounds fought.** It is -1 until the first hour. The first hour sets it to 0, and **one is added at the end of every hour that does not end the battle**.

So after any whole hour the two are equal, as in all 27 saved battles. They differ only for a battle saved **before its first hour**: `day` -1 and `duration` 0.

What each counter decides [exe]:
- `duration` decides when a side may lose (only from 4 on), when an air battle ends (at 4), when a naval battle may break off (from its third hour) and when a fleet may leave one (above 3).
- `day` decides whether a land reserve may come up (only above 0) and whether a ship joining a naval battle is set 100 further out (whenever it is not -1).

### A.3 One side's keys

Base order, for every side [exe]:

1. **`dice`** — the side's last die, an integer.
   - Every hour the battle sets it to a random number 0..9 from the game's generator, the attacker's first; the first hour rolls the pair twice.
   - So the saved figure is overwritten before the next hour's shooting. Nothing in the land path was found reading it.
2. **`unit = { id type }`** — one per unit of the side, in the side's own list order (the order units joined).
3. **`sunk_ship = { id type }`** — one per ship this side has lost, written only when there are any.
   - The id is **the ship's own id**.
   - On load it is found among the ships the top-level `sunk_ships` block made (earlier in the file, each registered by its own after-load step). Not found: dropped.
   - A plain number instead of a block is ignored.
   - The battle-end message names these ships.
4. **`losses`** — a fixed-point decimal of thousandths.
   - Land and air: strength lost.
   - Naval: 1000 per ship sunk.
   - The battle-end message and the "last battle" loss figures use it divided by 1000.
5. **`size`** — see A.3.1.
6. **`tactic`** — an integer, written **only when the side holds a tactic**.
   - In the saves: every land side, and no naval or air side, since only land battles pick tactics.
   - The number is the tactic's place in `common/combat_tactics.txt`, counting from 1; entry 0 is a built-in null tactic [mod: common/combat_tactics.txt]. In Their Finest Hour: 1 basic_attack, 2 basic_defend, 3 assault, 4 reckless_assault, 6 delay, 8 shock, 9 counterattack, 13 ambush.
   - The numbering is the same for both sides. The saved attackers hold 1/3/4/8 and the defenders 2/6/9/13.
   - On load, a number outside the list gives the null tactic. **That counts as a tactic held**, so the side gets no real one until the next swap hour [exe].

Then by kind [exe]:
- **Land:** `front = {id type}` per unit on the front, then `reserves` per unit in reserve, then `retreat` per unit on the retreat list, each only when non-empty. No save has `retreat`. In all 48 land sides, front ∪ reserves ∪ retreat is exactly the side's `unit` set, but the front's order may differ from the unit order (7 sides).
- **Naval:** `positioning`, a fixed-point decimal (e.g. `0.560` = 560 thousandths).
- **Air:** nothing more. `positioning` is never written; the loader accepts it and throws it away.

Not saved: which side is attacking, the countries list, the side's own-countries list, the destroyed-by-type and damage-by-type figures, the "modifier in play" flags, the land side's front-set-up flag, the naval positioning die, and every side's target list.

#### A.3.1 `size`

- **What it holds** [exe]: one figure per sub-unit type, in thousandths. A side adds to it as each unit joins:
  - land: each brigade's strength × its men per strength point / 1000, which comes out as men (a full infantry division reads about 9000.000). **Men per strength point is a constant 100.000** [exe] (`CRegiment::MenPerStrength`, which reads neither the brigade nor its type; `max_strength` [mod: units/*.txt] only caps the strength). The product is 64-bit and the divide truncates towards nought, but since 100000/1000 is exact a brigade adds exactly its strength × 100: in `Ireland1938_08_03_14`'s battle at 5638 an anti-tank brigade at 9.975 reads 997.500 and an armoured car brigade at 10.000 reads 1000.000;
  - naval: 1000 per ship, whatever its strength [exe];
  - air: 1000 per wing, whatever its strength [exe] - the air battle of `Ireland1936_02_02_04` has three interceptors, one at 99.512, reading 3.000.
  - Nothing in the battle code takes from it, and **the land join adds a unit's men every time it is called, even for a unit already on the side**, so a unit that leaves and joins again is counted again [exe]. So **it is everything that ever joined the side, counted at the moment each join was made.** The battle at 5638's attacker reads 29985.000 of infantry, which is 299.850 strength, where its eight infantry brigades of at most 30 hold 230.503: somebody was counted twice, and the save cannot say who. The battle-end message adds it up (÷1000) as the force engaged.
- **Index order** [exe, checked against the saves]: entry 0 is the sub-unit database's null type `---`. Then one entry per type in the order the database loaded them:
  - the `units/*.txt` files in **byte order of their file names** (upper-case names first: `Alpini_brigade.txt` is 1, `anti_air_brigade.txt` is 6, `infantry_brigade.txt` is 28), one type per top-level block [mod: units/*.txt];
  - where two search folders are in use, files of the second folder whose names the first lacks come first, then the first folder's (inferred from the loader; in Their Finest Hour every file comes from `tfh/units`).
  - Checked on real units: bergsjaeger 14, battlecruiser 12, destroyer 19, light_cruiser 32, interceptor 29, submarine 50, tactical_bomber 53.
- **Length:** 58 is the database count (57 TFH unit files + the null). The vector is sized to it when a side is made, and the writer writes the whole vector.
- **Load:** the list is read **in place**, up to the vector's current length. Extra figures are dropped; missing ones keep what the `unit` keys added. Because `size` comes after the `unit` keys, **the saved figures replace what those keys just added**.

### A.4 What loading a side does

- **`unit`**: the id is looked up among loaded objects. The units already exist, since country blocks come before `combat`. Where found, the unit goes through **the side's own join step**, exactly as a unit joining in play [exe]:
  - its owner goes onto the side's countries list and own-countries list;
  - every brigade's remembered target is cleared;
  - its men, ships or wings are added into `size`;
  - **land:** no reserve placement, because a save is loaded in the lobby where `in_game` is 0;
  - **naval:** the side's positioning is recomputed (later overwritten by the `positioning` key), and **every ship is given a fresh distance** (A.6).
  - The unit's own record of being in this battle is **not** set here; that waits for the battle's after-load step. An id that matches nothing is dropped silently.
- **`front` / `reserves` / `retreat`**: each id is looked up the same way and simply appended to that list. There is **no join step and no duplicate test**; an id that matches nothing is dropped [exe].
- **The land front-set-up flag**: set to 1 by every key a land side reads. Then the side's after-load step **clears it again where the side has units but none on any of the three lists**, which is a side saved before its battle's first hour [exe].

### A.5 The battle's after-load step

It runs as the battle's block closes, after both sides' own after-load steps and after `terrain`. It runs on load and nowhere else: nothing calls it directly [exe]. In order:
1. **`begun` = 1 and `ended` = 0**, written together as one 16-bit word. So the battle's start step **never runs for a loaded battle**: no "battle started" message, no naval positioning die, no land Begin.
2. **Each unit on each side's unit list gets the battle back**: a bombing goes in the unit's single bombing slot, anything else is appended to the unit's list of battles. This is **the only place on the load path where a unit learns it is in a battle**; the unit's own block carries no battle key.
3. **The province gets the battle**: appended to the province's battle list (no duplicates); a bombing goes in the province's single bombing slot if that is empty.
4. **Land only:**
   - The attacker's front is set up if its flag is clear. **Then the same test and call are made on the attacker again.** The land battle's Begin reads the attacker and then the defender; this step reads the attacker twice. **A defender's front is never set up here** [exe].
   - Then the tactic sums (width, attacker and defender damage, speed) are rebuilt from the two loaded tactics, leaving out a tactic the other side counters, and only where both sides have a country [mod: common/combat_tactics.txt].

Then, in the game entry step for both kinds of game (FINDINGS-savegame A.5) [exe]:
- **Every unit whose battle list is not empty** has the "fighting" display step run on it, with whether its owner is attacking here. That step also **zeroes the unit's `disengage` count and `possible_retreat` province**, so a fleet that was counting towards breaking off starts again from zero after a load (`Ireland1937_07_05_02`'s submarine flotilla had `disengage=1`).
- For **every battle**, each side's combat modifiers are applied against the other, attacker first. The hour does this again anyway; done here, the battle window shows valid modifiers before the first hour.
- Then the AI pass.

### A.6 Naval and air specifics

**Naval.** The positioning die is not saved, so it is 0 after a load and is never rolled again, because `begun` is set. Positioning is recomputed (without the die) as each `unit` joins, then **the saved `positioning` key restores it**. A fleet that joins later recomputes it without the die [exe].

**Ship distances are not kept.** The ship's join step runs for every `unit` key, after `day` has been read. Where `day` is not -1 [exe; consequence inferred, not seen in a running game]:
- Each ship gets half its firing distance plus a new random roll, **plus 100.000**:
  - a capital ship stands at that figure;
  - any other ship stands at that figure taken before or behind (even odds) the first capital ship found on the side, plus the 100. For the side's first fleet that is the saved distance; for later fleets it is a distance just rolled.
- Never under 1.000.
- So **every saved `current_distance` is overwritten** with ships about 100 out, and the fleets must close again. Every roll uses the game's generator, which a load does not restore anyway.

**Air.** No positioning. The remembered target of each wing is cleared on join, so each wing picks anew; the target list is refilled every hour [exe].

### A.7 Everything not saved, after a load

| state | after a load | made so by |
| --- | --- | --- |
| begun / ended | 1 / 0 | after-load step |
| concluded | 0 | construction |
| convoy-battle flag | 0 | construction (a convoy battle is fought and destroyed inside one call, so no save can hold one; inferred) |
| tactic sums on the battle | land: rebuilt from the tactics; others 0 | after-load step |
| the two battle-status markers and the selection byte | none / 0 | made at the first status refresh: a land battle the player is in, from its fourth hour |
| side countries list | the owners of the loaded units, in unit order | join step; the same as play |
| side own-countries list | **only owners of units still on the side**; play also keeps countries whose units left | join step (readers not looked for) |
| destroyed / damage by type | all 0 | construction (readers not looked for) |
| "modifier in play" flags | set | the game-entry modifier pass |
| side "lost" byte | 0 | construction (what sets it in play is not settled) |
| land front-set-up flag | 1, or 0 for a side with units but no lists (then set again for an attacker only) | A.4 / A.5 |
| land front / reserves / retreat | as saved | key reader |
| naval positioning die | 0, never re-rolled | — |
| target lists | empty; refilled every hour | the hour |
| ship distances | rolled again | A.6 |
| unit battle list / province battle list | rebuilt | after-load step |
| unit disengage / possible_retreat | **zeroed** for units in a battle | game entry |
| brigade remembered targets | cleared | join step |

### A.8 Three ways a load differs from play

1. **A land battle saved before its first hour** (`day=-1`) [exe; consequence inferred]. Such a save is possible: a battle made after the manager's hourly snapshot, e.g. by the re-check when a battle ends, or by a command while paused, waits for the next hour. On load:
   - the defender's front is never set up, and Begin never runs;
   - the attacker's shots find no target (the empty-front pick answers nothing, and the shooter skips);
   - the defender's front stays empty, so **it loses at the fourth hour without firing**, its units retreating.
   - No save of the maintainer's has such a battle.
2. **A side emptied in play.** Two saved land sides have no units at all (`Germany1936_09_02_21` and `Ireland1938_02_03_02`); the second case was checked at `day=2`. In play, the last unit leaving decided the battle once. That once-only flag is not saved, so **after a load the fourth hour's "has lost" test decides it again** [exe]. The land and air win/lose events and battle counts sit behind a test that both sides have a country, so they should not repeat; whether the message and the last-battle figures repeat was not traced.
3. **Naval distances and disengage counts restart** (A.5, A.6).

### A.9 For an OpenHOI3 loader

**Reading a save:**
- For each `land_combat` / `naval_combat` / `air_combat`, make the battle with both sides, put it at the back of the battle list, then read its keys.
- `location` sets the province only; `terrain` is looked up by exact name.
- For each side: every `unit` goes through the side's join step:
  - owner onto the countries lists, brigade remembered targets cleared;
  - `size` additions;
  - naval: a recomputed positioning and freshly rolled ship distances;
  - land: no reserve placement.
- After a side's units, read the side's other keys:
  - `size` overwrites in place, by type index (A.3.1);
  - `losses` and naval `positioning` are fixed point;
  - `tactic` is looked up by number, with the null tactic for one out of range;
  - `front`/`reserves`/`retreat` are appended as given;
  - `sunk_ship` resolves to the ship in `sunk_ships`.
- A land side with units and no lists: clear its front-set-up flag.
- At the block's end:
  - `begun` 1, `ended` 0;
  - each unit gets the battle added to its battle list, and the province gets it on its battle list;
  - land: set up the **attacker's** front if not set up (and, to be the original, not the defender's), then sum the tactic effects.

**Then, entering the game:**
- For every unit in a battle, zero `disengage` and `possible_retreat`.
- For every battle, apply both sides' modifiers.
- The first hour is then an ordinary hour: tactic swap test, `duration`+1, dice, fire, losses, the has-lost test from hour 4, `day`+1.

**Writing a save:** follow A.2 and A.3 exactly. Always write `terrain`. `tactic` only when held. Land lists only when non-empty. `size` must be the full database-length vector, with 0 for `---`.

Being faithful to the original means reproducing items 1-3 of A.8. Deliberately not doing so belongs in OpenHOI3's compatibility list.

### A.10 Not established

- Readers of the own-countries list, the destroyed-by-type and damage-by-type figures, and the side's "lost" byte.
- That the session reset empties each province's battle list and bombing slot (inferred).
- When the province-entry step, run during a load, puts a fleet's passengers ashore and checks them for combat (not followed).
- Air units' "no battle for N hours" count on the unit is not saved (per FINDINGS-savegame C.2's key list); what that does to a loaded air battle was not followed.

### A.11 The side's `retreat` list is filled by nothing but a load

*Added 2026-11-05 by the collecting session, statically, after the maintainer ordered a division in a battle to retreat
by hand and saved (`Soviet_Union1941_07_16_19` to `_21`, province 1529) and no `retreat` key appeared.*

**Nothing in the executable puts a unit on a land side's retreat list (+0xD0) but CLandCombatant::LoadKey** [exe]. Three
scans of the whole `.text`:

1. **Inlined appends** - the list append the loader uses is open-coded: a 0x10-byte node, the tail at +0xD4 replaced,
   the count at +0xD8 raised. Every `mov [reg+0xD4], r` followed within 48 bytes by `mov [reg+0xD8], r` on the same
   base register: 58 functions in the image, of which the only ones on a combatant are CLandCombatant's constructor
   (the empty list) and CLandCombatant::LoadKey's `retreat` arm - **the positive control**.
2. **Through a helper** - every `lea reg, [reg+0xD0]` whose function is named for combat, a retreat, the front or the
   reserves, or lies in the battle code (VA 0x55E000-0x580000): only CLandCombatant::RemoveUnit (twice, to
   CList_RemoveNode); the rest are another class's field at that offset in the battle window's views.
3. **Every read** of +0xD0, +0xD4 or +0xD8 and every `add reg, 0xD0` in the battle code: the list's own touches are
   CLandCombatant::UpdateFrontLine (the list walked, a unit that can fight unlinked, freed and the count lowered at
   0x56C1A9), CLandCombatant::IsSpent (averaged with the front), RemoveUnit, SaveContents, AfterLoad and LoadKey. The
   +0xD0 CUnit::RetreatFromCombat reads (0x565823) is a province's id, not the list.

**So the list is a vestige**: in a game it is always empty, a save never holds one, and a retreat ordered by hand -
which takes the unit off its side at once and marches it out with the unit's own `retreat=yes`, as the maintainer's
saves show - never touches it. A loaded save that held one would have its units moved to the reserves at the next
hour where they can fight. A rewrite that holds no such list behaves as the original does in every game that can
arise; it needs only to read `retreat` without fault.

**What is not settled**: an append through a pointer computed some other way - a stack copy of `this + 0xD0`, or an
offset reached by a register sum - is not excluded by these scans; none was seen in the functions read.

## B. Bombings, finished battles and sunk ships in a save

*Reader B, saved-battle wave, 2026-11-05. Read statically out of `hoi3_tfh.exe` with `disasm.py`, `findRefs.py` and `vtable.py`, and set against the 33 saves in the maintainer's `save games` folder. **[exe]** is hardcoded in the executable, **[mod: file]** a file may change it. Reader A has the shared combat keys (`location`, `day`, `duration`, `terrain`, `dice`, `unit`, `losses`, `size`, `tactic`) and the general rebuild of a battle; this section says where a bombing differs.*

**Synopsis.** How a save holds the three bombing kinds, the list of finished battles and the top-level `sunk_ships` block, and how a load takes each back - all three settled from the bytes and checked against the 33 saves. A bombing's attacker is always a `CBomberCombatant`, saving the shared combatant keys plus `strength` and three tallies - `building` (1 + buildings.txt's entries), `pool` (7) and `current_producing` (7); the bombed side is a target combatant that saves exactly as a plain `CCombatant`. Finished battles' kinds are 1 to 6; a load appends and never prunes, the first hour does, and the session reset never empties the list. `sunk_ships` holds every ship that has left the game, not only sunk ones, and a combatant's `sunk_ship` id points into it. **Corrected**: the "second `type=`" in a history entry was a census artefact; the `sunk_ships` writer is inline in `CGameState::SaveContents` and the reader inline in `CGameState::LoadKey` (VA `0x5ADD30` is `CShip::SaveContents`); `CCombatHistoryEntry +0x20` is `is_convoy_battle` bool, not `flag` int; rva `0x15FE90` is `CBomberCombatant::SaveContents`, not a getter; a `sunk_ship` id comes from the ship the node holds; `CCombatHistory_BuildEntry_A` is `CCombatHistory_LoadEntries`.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x15FE90 | CBomberCombatant::SaveContents | new | confirmed | slot 2: CCombatant's keys, then `strength`, `building`, `pool`, `current_producing`, all unconditional |
| 0x15E030 | CBomberCombatant::ReportBombingEnd | new | inferred | slot 10: the end-of-bombing report (BOMBENDTHEM/BOMBENDUS) that reads the four tallies; scales +0x10E4 by 10/1000 |
| 0x2FE20 | CGroundBombing::CGroundBombing | new | confirmed | constructor, receiver in EAX; called by LoadKey and CreateCombat |
| 0x2FE70 | CLandBombing::CLandBombing | new | confirmed | same body, different tables |
| 0x2FEC0 | CNavalBombing::CNavalBombing | new | confirmed | same body, different tables |
| 0x2FDB4 | CCombatManager_LoadKey_GroundBombingController (instruction) | new | confirmed | a loaded ground bombing gets the province's controller put back on the defender's `countries` |
| 0x2802E2 | CGameState_LoadKey_SunkShipsArm (instruction) | new | confirmed | `sunk_ships` read: tag key, a fresh CShip, owner set from the key, appended, loaded |
| 0x27F6C8 | CGameState_SaveContents_SunkShips (instruction) | new | confirmed | always written (`sunk_ships={ }` when empty), `<owner tag>={ship}` in list order |
| 0x164F46 | CCombatant_LoadKey_SunkShipArm (instruction) | new | confirmed | `sunk_ship={id type}` resolved by id pair; dropped if not found |
| 0x1ADB60 | CShip::CShip | new | confirmed | receiver in ESI; sets the byte DisposeSubUnit tests |
| 0x1DA350 | CDisbandRegimentCommand::Execute | new | confirmed | slot 6: RemoveRegimentFromUnit + DisposeSubUnit, so a lone disbanded ship goes on the sunk list |
| 0x33FE0 | CCombatHistory_SaveEntries | new | confirmed | nothing when empty, else `history={` and each entry followed by a one-space token |
| 0x34140 | CCombatHistory_LoadEntries | revised | confirmed | was CCombatHistory_BuildEntry_A (inferred); the read whole: stack temporary, append at the end, no prune |
| 0x2F5F0 | CCombatHistoryEntry::LoadKey | revised | confirmed | where each key lands, and that ResetSession never clears the history |
| 0x2F410 | CCombatHistoryEntry::SaveContents | revised | confirmed | "1 to 5" becomes the 1-6 kind table; convoy only when set; the "second type" explained |
| 0x15FDF0 | CBomberCombatant::LoadKey | revised | confirmed | destinations, the in-place fill rule and what is not saved |
| 0x45140 | ReadFixedVectorInPlace | new | confirmed | fills a pre-sized int vector; figures past its length consumed and dropped. Also CCombatant's `size` loader |
| 0xC8050 | SaveWriteFixedVector | new | inferred | `key={ a b c }`, nothing when empty; register convention inferred |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CCombatHistoryEntry | 0x20 | is_convoy_battle | bool | revised (was `flag` int) |
| CBomberCombatant | 0x10E4 | strength_damage_dealt | int | revised (comment) |
| CBomberCombatant | 0x10B4 | buildings_destroyed | int* | revised (comment: index 0 nobuilding, saved as `building`) |
| CBomberCombatant | 0x10C4 | stockpile_destroyed | int* | revised (comment: goods order, saved as `pool`) |
| CBomberCombatant | 0x10D4 | production_destroyed | int* | revised (comment: goods order, saved as `current_producing`) |
| CCombatant | 0x28 | sunk_ships | void* | revised (comment: holds CSubUnit*, the id is the ship's own) |
| CGameState | 0x20 | sunk_ships | void* | revised (comment: every disposed ship, never pruned) |
| CCurrentGameState | 0x20 | sunk_ships | void* | revised (same) |

### B.1 Which bombing is which

The `combat` block names each live battle by its own key, and three of the keys are bombings. Each bombing kind is a combat class with its own number, and that number is the `type` its history entry carries [exe]:

| key | class | kind | made by (FINDINGS-bombing.md sections 1 and 5) | the bombed side |
| --- | --- | --- | --- | --- |
| `ground_bombing` | CGroundBombing | 4 | an order that bombs the ground, against a land province whose controller is an enemy: strategic bombing, logistical strike, runway cratering, installation strike, port strike | the ground itself, needing no unit. Its country is the province's controller. Fleets in the port join it for a port strike, and aircraft at their base join it where the order goes for aircraft at their base (runway, installation) |
| `land_bombing` | CLandBombing | 5 | an order that goes for land units: ground attack, interdiction | the land units in the province |
| `naval_bombing` | CNavalBombing | 6 | an order that goes for ships: naval strike (at sea), carrier protection, or a port strike where the controller is not an enemy | the fleets |

The other kinds are 1 land, 2 naval (a convoy raid's battle among them, by sea or from the air) and 3 air. In the saves, kind 4 is England bombing German industry (Germany1936_09_02_21) and kind 5 is Japan's ground attacks on China (Ireland 1938). Across all 33 saves the history entries split by kind as 1: 131, 2: 29, 3: 22, 4: 35, 5: 309, 6: 1.

**The two sides of a bombing are different classes** [exe]:
- **The attacker is a `CBomberCombatant`, always.** It is fixed as the attacker when built.
- **The defender is a target combatant**: CGroundTargetCombatant, CLandTargetCombatant or CNavalTargetCombatant, one per kind. All three are a plain combatant plus a list of the bombers' wings, which is filled each hour and never saved. Their save and load are exactly `CCombatant`'s.

That is why, in Ireland1938_08_03_14, the land bombings' attacker carries `strength`, `building`, `pool` and `current_producing` while the defender carries only `dice`, `unit`, `losses` and `size`. No side of a bombing ever has a `tactic`: none of the five live bombings in the saves has one, and a bombing never picks one (the code that picks tactics was not read).

A ground bombing's defender normally has no `unit` keys. Germany1936_09_02_21's has only `dice`, `losses` and `size`.

### B.2 The bomber side: what it writes and what it reads back

**Written** [exe], in this order:
1. The shared combatant keys: `dice`, one `unit={ id type }` per unit, one `sunk_ship={ id type }` per ship its bombs finished, `losses`, `size`.
2. `strength=`: a thousandths figure, the strength damage this side's shots have put on their targets, summed over the bombing. It counts damage as it lands, before it is settled, so it stands a little above the bombed side's `losses` (46.039 against 45.900, 3.847 against 3.800, 7.696 against 7.600 in Ireland1938_08_03_14). Where nothing was hit it is 0: Germany's strategic bombing has no targets and shows `strength=0.000`.
3. `building={ ... }`: one figure for each building of the building database, in the database's order. **Index 0 is the engine's built-in `nobuilding`, then `common/buildings.txt` in file order** [mod: common/buildings.txt]. That gives 12 figures in Their Finest Hour, which has 11 buildings. Each figure is the levels taken off that building, in thousandths, summed over the bombing.
   - Check: in Germany1936_09_02_21, province 2558 has index 5 = 0.426. That is anti_air (buildings.txt's 5th entry), and the province stands at `anti_air={ 0.574 1.000 }`. Index 10 = 0.421 is industry.
4. `pool={ ... }`: seven figures, taken out of the province's stockpile.
5. `current_producing={ ... }`: seven figures, taken off the province's day's production.
   - Both are in the goods order supplies, fuel, money, crude oil, metal, energy, rare materials [exe].
   - Check: the same save's `current_producing` holds `0 0 0 0 2.300 2.300 2.300`, and the province's metal, energy and rare materials stand exactly 2.300 under their maximums (4.7/7, 3.7/6, 1.7/4).

All four bomber keys are written unconditionally. Which tallies fill depends on the order: a strategic bombing fills buildings and production, a logistical strike the supplies and fuel of the pool, and ground attack and interdiction nothing.

**The vector format** [exe], text save:
```
\t\t\tbuilding=\r\n\t\t\t{\r\n0.000 ... 0.421 0.000 \t\t\t}\r\n
```
- The figures sit on one line at column 0, each followed by one space.
- The closing brace follows on the same line, after the writer's indentation.
- An empty vector writes nothing at all; these three never are empty.

**Read back** [exe]:
- `strength` is read as a fixed-point number.
- The three vectors are **filled in place**. The bomber's constructor already sized them: one per database building, seven, and seven.
  - The reader stores figure i only while i is inside that length. Any further figures are read and dropped, and any figures the block lacks stay at nought.
  - So a save made under a buildings.txt of another length loads without complaint. The figures move to whatever building now stands at each index.
- Every other key goes to the shared combatant reader.

**Not saved, and what a load leaves:**
- **The bombers' target list and its count.** They are refilled for every unit, every hour, before any wing fires, so nothing needs rebuilding.
- **The side's country lists.** They are rebuilt as the `unit` keys load (each unit added puts its owner on both lists), as for any combatant.
- **A ground bombing's defender, which has no unit, is a special case** [exe]. Right after the bombing is loaded, the combat manager's `ground_bombing` arm puts the province's controller on the defender's `countries` list. It does not touch `own_countries`, which is exactly what creating a ground bombing in play does. The controller is the one the save's province block gave it, because provinces come before `combat` in the file.
- **Land and naval bombings get nothing extra.** Their defenders' countries come back with their units.
- **The tallies are saved so the end-of-bombing report covers the whole bombing.** That report runs when the bombing ends and lists every building, good, production and ship it destroyed. It also multiplies `strength` by 10 and divides by 1000, writing the result back, for a "men" line [exe]; the condition on that line was not read.

**List order.** The combat manager puts a new bombing at the **front** of the live list and every other battle at the back, both in play and on load [exe]. The saves bear this out: every save with a live bombing lists it first. Because the writer walks the list front to back and the loader prepends each bombing again, **the bombings come back in reverse order after a load**; the land, naval and air battles keep theirs. The hourly loop walks the list in order, so the order decides whose dice are drawn first. That last consequence is *inferred*.

A loaded bombing is attached as any battle is: marked begun, its units told they are in it (a bombing is held on the unit's single bombing slot, not its list of battles), and stored on its province's one bombing slot. The battle-started message is not shown again (reader A has the general case).

### B.3 The list of finished battles

**Shape** [exe]: `combat={ ... history={ history={ {entry} {entry} } } }`. The outer `history` is the combat manager's key for its embedded history object; the inner one is the history's only key. An empty history writes no inner key, so it reads `history={ }`, as in the 1936-01-01 save.

**An entry**, in this order:
1. `location=`: the province id, a plain number.
2. `attacker=` and `defender=`: three-letter tags, quoted. `"---"` means that side had no country left when the battle ended.
3. `end_date=`: the hour the battle ended, quoted, as `year.month.day.hour`.
4. `convoy=yes`: **only when set**.
5. `type=`: the kind, 1 to 6 as in B.1.

**Every entry has exactly one `type`.** All 630 entries in the 33 saves are `location attacker defender end_date type` or `location attacker defender end_date convoy type`. The "second `type=`" that FINDINGS-savegame.md B.5 left open came from a census that counted the `type` inside the `{ id= type= }` blocks of the live battles above the history.

**Between entries a text save writes one space.** It is a one-space string token written after each entry, which gives the lone-space line between two entries and the space before the final brace [exe]. A binary save writes none. The bytes, from Ireland1937_07_05_02:
```
\t\thistory=\r\n\t\t{\r\n\t\t\t\r\n\t\t\t{\r\n\t\t\t\tlocation=11932\r\n...\t\t\t\ttype=2\r\n\t\t\t}\r\n \r\n\t\t\t{\r\n ... \t\t\t}\r\n \t\t}\r\n
```
Note the line of three tabs before the first entry.

**What fills each field** [exe]: the entry is made when a battle ends.
- **`end_date`** is the hour it ended.
- **`type`** is its kind.
- **`location`** is its province.
- **`attacker` and `defender`** are the first country on each side's list of countries still in the fight, or `---` where that list is empty. A side whose units were taken off one by one is emptied; a ground bombing's defender keeps the controller unless a unit leaves that side (FINDINGS-airmap.md section 3). In the saves, kind 4 never shows `---`, and kinds 1, 2, 3 and 5 sometimes do.
- **`convoy`** is the battle's convoy-raid flag. That flag is set only on the throwaway battle a raid on a convoy fights, whose entry is recorded directly by the raid, so `convoy=yes` appears only on kind 2: 20 of the 29 kind-2 entries.

**How long an entry lives** [exe]:
- **Pruning happens at the start of every hour.** Before any battle is fought, the history drops entries from the front of the list: first those that ended after now, then those that ended more than 168 hours before now. Only the front is looked at.
- **New entries are appended**, so the list is in end order. All 21 non-empty histories in the saves are in order, and their oldest entry is at most 167 hours old.
- **Nothing else empties the list but the game state's destructor.** In particular the session reset that every load runs **does not touch it**: it frees the live battles and leaves the history alone.
- The entry's `pruned` byte is set only in a mode that nothing switches on (FINDINGS-airmap.md).

**What a load does** [exe]:
- **Each entry is read into a temporary and appended at the end, in file order.** No sorting, no pruning, no check.
- The temporary starts with the hour at the engine's null date (year 5000), the province, ids and convoy byte at nought, and the kind and the two tag texts uninitialised. A complete entry overwrites all of these.
- `location` stays a number. `attacker` and `defender` go through the tag lookup, and the text `---` reads back as no country. `convoy` reads back as yes or no.
- **The first hour after the load prunes the list.**
- *Inferred consequence:* because the reset leaves the list alone, entries from the session before a load stay in front of the loaded ones until that first prune. If they ended after the loaded date they go at once. If they ended within the week before it, a game from another session can keep them for up to a week, and they are written into a save made in that time.

**What reads the list** (the readers the record names; a scan for others through the game-state global was tried and is unreliable, so this is not proven complete):
- the hourly prune;
- the air map mode's icons and the air map tooltip, which count kinds 3 to 6 per province over the week (FINDINGS-airmap.md);
- the naval AI, which hands provinces of recent raids on its convoys to its fleets, using kind 2 with the convoy flag, at most a month old;
- the save writer.

### B.4 `sunk_ships`

**What it is** [exe]: the game state keeps a list of **every ship that has left the game this session**. Whenever a sub unit is disposed of, a ship is kept on this list and anything else is deleted. That covers:
- a ship sunk in a sea battle;
- a ship finished by bombs;
- a ship disbanded on its own;
- every ship of a fleet disbanded or removed for any other reason, such as a country's units removed when it is annexed;
- a few other cases not read (an upgrade command, a custom-game path, a ship type the bombing report disposes of).

A carrier's air groups are taken off it and sent to an air base first, so **a sunk carrier is never saved with `air`**. Germany1936_03_31_19's two Polish ships stand at full strength with no `sunk_by`: they were removed, not sunk. Spain's 18 ships in the Ireland saves likewise have no `sunk_by`. China's sunk ships do have one.

**How long an entry lives:** for the whole session. There is no pruning; only the session reset (a load, or leaving to the menu) deletes the ships. The record's live count was 1,295 ships in a 1942 game.

**What refers to it:**
- **The script conditions `total_of_ours_sunk` and `total_sunk_by_us`.** The first counts ships on the list owned by the scope country. The second counts ships whose `sunk_by` sinker still exists and is now that country's. **A disbanded ship counts as "ours sunk"** [exe, from both readings together].
- **A live battle's `sunk_ship` keys.** Each side keeps a list of the ships it has lost, or for bombers the ships its bombs finished. These are the same ship objects, and the save names each by the ship's own id. In Ireland1937_11_02_21 the sea battle's defender has `sunk_ship={ id=4775 type=41 }`, which is the last entry of that save's `sunk_ships`: the Chinese destroyer "Di 2 Quzujian Dadui", `sunk_by={ id=2090 type=41 }`.
- **The pride of the fleet last sunk.** The game state keeps it, with its sinker, for the event text. It is not saved, and the reset clears it, so after a load it is empty until the next pride is sunk.

**Written** [exe], after the countries and before `weather`:
- `sunk_ships=` and a block, **always**: 26 of the 33 saves have `sunk_ships=\r\n{\r\n}\r\n`.
- One entry per ship in list order, which is the order they left the game. The key is the ship's **owner tag**; the value is the ship's own block.
- The block is the same one a ship in the unit tree writes: `id`, `name`, `type`, `organisation`, `strength`, `highest`, `experience`, then `sunk_by` and `pride` where set, then one `<technology>={level progress}` per technology (FINDINGS-savegame.md C.4).
- The 7 saves with entries hold 2 to 30 each, and their key sequences are exactly that.

**Read** [exe], by the game state's own loop:
- Each key's text goes through the tag lookup; an unknown tag gives `---`. A new ship object is appended to the list and **given the key's tag as its owner before its block is read**, so the owner comes from the key and nowhere else. The block is then read with the ship's own reader.
- As the ship's block closes, its saved id is registered (raising the unit counter past it), or a new id is minted where it has none.
- **The block precedes `combat` in the file, so every ship is registered before the battles are read.** A combatant's `sunk_ship` pair is looked up by id. A ship found goes back on that side's list; **one not found is dropped in silence**.
- The `sunk_ships` block itself, read by its own loop, gets no after-load step.

### B.5 For an OpenHOI3 loader and writer

- **Load `sunk_ships` before `combat`**, register each ship by its saved id, and take its owner from its key. When reading a combatant's `sunk_ship` list, resolve by id against those ships and drop any that do not resolve.
- **Size a bomber's three tallies first, then fill them in place**: 1 + buildings.txt entries with `nobuilding` at index 0, then 7, then 7. Ignore extra figures and leave missing ones at nought. Write all four bomber keys always, after `size`.
- **Rebuild a loaded ground bombing's defender country list** from the province's controller, on `countries` only. Rebuild every other side's country lists from its units.
- **Put each loaded bombing at the front of the live list**, as the original does, which reverses their saved order.
- **Append history entries in file order.** Do not prune on load; prune at the start of the first hour: the leading entries that end after now, then those more than 168 hours before now, front only. Write `convoy=yes` only when set, and the one-space token after each entry in a text save. Write nothing inside `history` when the list is empty.
- **Write `sunk_ships={ }` even when empty.** Never prune it in play. Put every disposed ship on it: sunk, disbanded or removed with its unit.

### B.6 Not established

- What the "men" line of the end-of-bombing report requires of the other side, and what the sub-unit type byte +0x33 is that makes the report dispose of a unit's brigades.
- The paths that pick tactics were not read. That bombings never pick a tactic rests on all five live bombings in the saves having none.
- Whether a new game, as opposed to a load, empties the combat history: the new-game reset was not read.
- `CUpgradeRegimentCommand::Execute` and a custom-game path both dispose of sub units. What they put on the sunk list was not read.
- The register convention of the fixed-vector writer (key in ECX, writer in EDI) is inferred from its callers.

Frontier: rva `0x1DA7C0` (CUpgradeRegimentCommand slot 6, which also disposes a sub unit), rva `0x1B7D0` (a custom-game caller of DisposeSubUnit), the sub-unit type byte +0x33 in ReportBombingEnd's disposal loop (VA `0x55FC00`).
