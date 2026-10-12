# The on_actions: when each fires, its scope, and who answers

*Read on 2026-10-12, statically, for OpenHOI3's events, by one brief of the text wave (`WAVE.md`,
brief F). Addresses are rvas unless they say VA. The function table is in
`fragments/merged/on-actions.json`.*

**Synopsis.** All 13 sites of `tfh/common/on_actions.txt` were read off the listing. The battle pairs -
land, air and naval - fire **once for each country of each side**, inside `CCombat::Conclude`, **every
win before every loss**, and their scope never carries the combatant. `on_encirclement`'s gate, the
area byte +0x68, was recorded already as `COwnerArea::landlocked`: it fires on a province's **first
day without a depot, in an area of one controller with no working port**, and the province's
**owner** answers. A coup is only ever a person's order, and its command's `from` is the target.
**The pick never asks the fire-once registry**, so a fired `fire_only_once` event keeps being picked
and dropped and shadows every entry after it for good. **Corrected**: `CCountry::GetSurrenderProgress`
has nine callers, not one - the surrender itself among them - and its signature's storage was
incomplete; `CCombat::Conclude`'s comment gains the on_actions.

`FINDINGS-eventfire.md`, section 1.6, had the sites and the pick (the first entry in file order whose
trigger holds; the weights never read); this is when each site runs and what it builds.

## 0. The machinery, read again

- `FindOnAction` (0x5C8830) finds the on_action by name; `OnAction_PickEvent` (0x5C7E10) walks its
  entries - +0 the event's id, +4 the weight, loaded into a local never read - resolving each id by
  `FindPersistentByIdPair(0x28, id)`, **skipping silently an id that resolves to nothing** (the base
  game's 6000 and 6100), and answers the first event whose `trigger` (+0x30) holds in the site's
  scope, or nothing.
- **Nothing found, nothing happens**: no fall-back, no message, and the site goes on with the rest of
  its work.
- **Not asked**: the fire-once registry, `is_triggered_only`, a person, a multiplayer host - by the
  pick or by any of the 13 sites. The only person and AI logic is `FireEvent`'s own, which answers to
  the scope's country, or to its province's **owner** where the country is 0.
- Every site runs inside the simulation - a battle's hour, a daily pass, a command - so on every peer,
  and every roll they make is the game's own generator's.
- **One reference each**: each of the 13 names has exactly one reference in `.text`, inside its site
  (the positive control: `on_battle_won` at VA 0x576A0B, the known one). So a pride sunk by aircraft
  fires nothing.

## 1. The table

| on_action | where it fires, and when | THIS | province | FROM | FROM province | who answers | |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `on_battle_won` | `CCombat::Conclude` (VA 0x576A6C), a land battle (kind 1): once for each country of the winning side's `countries` (CCombatant +0x54), in order, after its `land_battles_fought` is raised; only where both sides have countries | that country | the battle's (combat +0x18 -> +0xD0) | the losing side's first country | 0 | THIS | confirmed |
| `on_battle_lost` | the same (VA 0x576B7F), **after all the wins**: once for each country of the losing side | that country | the battle's | the winning side's first country | 0 | THIS | confirmed |
| `on_air_battle_won`, `_lost` | the same (VA 0x57864F, 0x578767), kind 3, the same shape (`air_battles_fought`) | as above | as above | as above | 0 | THIS | confirmed |
| `on_naval_battle_won`, `_lost` | the same (VA 0x57A975, 0x57AA9B), kind 2, the same shape (`naval_battles_fought`) - **not** inside the both-sides test (section 3, 2) | as above | as above | as above, `---` where that side is empty | 0 | THIS | confirmed |
| `on_enemy_pride_sunk` | `CNavalCombatant::Attack` (VA 0x568820): a shot takes a target whose `pride` (CSubUnit +0xA5) is set below 0 in strength less the damage pending | the shooting ship's owner (CSubUnit +0x94/+0x98) | 0 | the pride's owner | 0 | THIS | confirmed |
| `on_our_pride_sunk` | straight after it, the same scope with the two countries swapped (VA 0x568918) | the pride's owner | 0 | the shooter's owner | 0 | THIS | confirmed |
| `on_surrender` | `CCountry_Surrender` (VA 0x4E915F), from the country's daily pass: it owns a province, its surrender progress is at least 1000, it is at war, and 30 days or more have passed since its last surrender | the country surrendering | 0 | the best enemy by score (2.2) | 0 | THIS | confirmed |
| `on_coup_success`, `on_coup_fail` | `PerformCoup` (VA 0x4F7DFC, 0x4F7EA3), from `CPerformCoupCommand::Execute`: success where `RandomThousandths()` is below the chance | the target | 0 | the instigator | 0 | THIS | confirmed |
| `on_nuke_dropped` | `CNukeMission::IsActive`, through `FireOnAction` (VA 0x594A91), when the bomb is dropped (2.4) | the bomber's owner (CUnit +0x124/+0x128) | the target | the target's controller | 0 | THIS | confirmed |
| `on_encirclement` | `RunDailyProvincePass` (VA 0x49F122): a simulated province, `out_of_supply_days` exactly 1 straight after `UpdateSupplyDepot`, in a real area that is `landlocked` | **0** (`---`) | the province | 0 | 0 | the province's **owner** (`FireEvent`'s fall-back) | confirmed |

In every scope `this_scope` points at the scope itself, it is resolved, `days_in_month` is 0, and
**no on_action passes a combatant** - so every combat condition (`is_winner` and the like, the combat
modifiers, `enemy = { }`) is false inside an `on_battle_*` event. The seeds:

| sites | the seed and the state of chance |
| --- | --- |
| the battles; the surrender | a draw of the game's generator (`Random()`) |
| `on_encirclement` | a draw of the same generator, inline |
| the pride sunk; the nuke (the constructor given EDX 0) | **0** |
| the coups (the scope made inline) | **0**, and +0xC 0 too |

## 2. Each site

### 2.1 The battle pairs: `CCombat::Conclude` (0x174580)

**When it runs** - three callers: `CCombat::Tick`, **from the fourth hour** - once `duration` is past
3, and not for a convoy's battle, the attacker's `HasLost` is asked and then the defender's, and the
first that has lost is concluded against (both lost: the attacker) - and `CCombat::UnitLeaves`, when
the last unit of a side leaves a battle that goes on.

- **The air**: `CAirCombat::Tick` ends its battle at the fourth hour whatever happens, so `HasLost`
  is asked once, then - **an air battle nobody has lost at its fourth hour ends with no on_action.**
- **At sea**: a battle broken off by `CNavalCombat::Tick`'s roll ends through `CCombat::End`, which
  fires nothing.
- **A raid on a convoy** (+0x2B set) and **a bombing** (kinds 4, 5, 6) fire none.

**The order inside it**: the losses (`FINDINGS-triggerleaves.md` 3.1); for land, the +5 relation; the
messages; then for each winning country a scope of its own, its battles counted, the `*_won` pick
and the firing; then for each losing country the same with `*_lost`. So **`on_battle_won` and
`on_battle_lost` both fire for one battle, in different scopes, the wins first**; every country of each
side gets a pick of its own, THIS being that country and FROM the first of the other side.

### 2.2 `on_surrender`: `CCountry_Surrender` (0xE8E80)

**The gate**, in the country's daily pass (VA 0x4DBCCC): it owns provinces (+0xCF8 above 0),
`GetSurrenderProgress` is at least 1000, it is at war, and 30 days or more since `last_surrender`.

**The victor**, scored over its enemies (+0x1008), itself left out:

    score = 1000, or 2000 where the enemy leads a real faction (its first member)
          + 5000 where it controls our capital
          + for each province we own that it controls:
                1000 + 3000 x victory points + industry (province modifier 15) / 3

A higher score replaces the best, so of equal scores the first in the list wins; no enemy, nothing
happens. **Then** the scope (THIS us, FROM the victor, a seed of `Random()`) is made and
`on_surrender` fired; **then** the capitulation (0xE9220, read by its calls only: `CWar::RemoveAttacker`
and `RemoveDefender`, a `puppet` branch over our vassals, `Province_SetController`, the area groups and
the supply groups made again); then `last_surrender` is now. So **the event fires before the
capitulation**, **again every 30 days** while the progress stays full and the country is at war with
anyone, and in the base game **every `on_surrender` entry is commented out**, so the surrender goes
ahead silently.

### 2.3 The coups: `PerformCoup` (0xF7C80)

**Where one comes from**: `CPerformCoupCommand` is made only by 0x554280 - called by the command's
own copy and by an interface callback (0x629A30) of the window made at 0x61EAE0, which passes the
window's country as `from` and the player (`CCurrentGameState +0xC30`) as `to` - and by 0x5541D0, for
registering the prototype. **A coup is a person's order**; no AI path makes one, nor does the Lua.

**When it runs**: the instigator's espionage entry about the target has its +0 (`spy_allocation`)
set to 0, held under the most spies allowed; its covert operations points (+0xF4) lose
`COUP_COVERT_OPS_COST`, floored at 0; the chance is 0xF7AD0's - not read beyond that it answers 0
where the target leads a real faction; `RandomThousandths()` below it is a success. **The scope**:
THIS the target, FROM the instigator, seed and state 0; the base game's 5057 then does `coup_by = FROM`.
Afterwards `Execute` calls 0x4E21E0 and 0x4E39C0 on both countries.

### 2.4 `on_nuke_dropped`: `CNukeMission::IsActive` (0x193C30)

The gates, in order: the unit has a base (+0x98); the order's +0x80 is set; the target's controller is
an enemy of the unit's owner; the unit is in no battle; it has no move left; it stands in the target.
**Then, before the on_action**: the controller loses `NUKE_UNITY_IMPACT` x a factor of national unity
(1000, more where a province modifier is set, doubled at the acting capital); the province's
buildings and units are damaged; three messages (NUKE_ON_US, WE_NUKE, NUKE_ON_OTHER). **Then**
`FireOnAction(on_nuke_dropped)` with THIS the bomber's owner, FROM the province's controller, the
province the target, seed 0 - as the file's own comment says - and the order's +0x80 cleared. The
damage was read for its shape only.

### 2.5 The pride of the fleet: `CNavalCombatant::Attack` (0x167930)

**A pride** is `CSubUnit +0xA5`, from the order of battle or the save (`pride = yes`, 192 lines in the
base game's history), or from `CMakePrideCommand::Execute` (0x1DB530), which moves it from the
country's present pride (0xE64B0) to the new ship, adding a figure from 0xE6500 to `dissent` where
there was one.

**When it is sunk**: each shot first asks whether strength less the damage pending is below 0 and
**stops if so**, so a target is shot only until it goes under, and the sinking shot is the one that
takes it below 0. Then the target's `sunk_by` is the shooter, and where it is a pride: the shooter
gains 5.000 experience (to at most 100.000); the game state's +0x48 is the pride and +0x4C the
shooter (`last_pride_sunk`, `last_pride_sinker` - what `$PRIDE_SUNK$` and `$PRIDE_SINKER$` show);
`on_enemy_pride_sunk` fires for the shooter's owner (FROM the pride's), then `on_our_pride_sunk` for
the pride's owner (FROM the shooter's). One scope, seed 0, no province.

### 2.6 `on_encirclement`: `RunDailyProvincePass` (0x9EAB0)

The daily pass calls it for **every province** (`CCurrentGameState +0xB8C..+0xB90`), and it works on a
**simulated** one only (template +0x13D). The test stands straight after `CProvince::UpdateSupplyDepot`,
which counts `out_of_supply_days` up where no depot was found and to 0 where one was:
`out_of_supply_days` is exactly 1 - **the first day without a depot**; the area's slot 0 answers true
- a real area, which a province is not in where it is not simulated, has infrastructure of one level
or less, or is sea; and **the area's `landlocked` (+0x68)** is set - 1 unless one of its provinces is
a working port (owned, with a port, a naval base above 0), written by `COwnerArea::RefreshDepotFlags`.
`FINDINGS-eventfire.md` had it as not read; it was in the record. Areas are blocks of one
**controller**, so a pocket with a working harbour never fires it, and **every province of a
landlocked pocket fires its own pick on the same day**. The scope's country is 0, so the province's
**owner** answers - not the controller whose supply failed.

## 3. What looks wrong and is what the bytes do

1. **A fired `fire_only_once` event shadows those after it.** The pick does not skip it and
   `FireEvent` drops it, so the first entry whose trigger holds blocks every later one whose trigger is
   no stricter, for good (`confirmed` from the listing; the consequences `inferred` from the files). In
   the base game 620 can never fire (its trigger is 619's), nor 720 (719's), 870 (869's) or 970
   (969's); 644 and 645 (Kharkov) fire only in a battle where 643's test of losses fails; and on a side
   of several countries a fire-once battle event goes to the first alone.
2. **The naval part of `Conclude` runs where a side has no countries** (VA 0x5745D2, 0x5745DE jump to
   0x578793): the other side still gets its events, FROM `---`, and that battle's losses are not
   written. Land and air skip everything then.
3. **An air battle undecided at its fourth hour, and a battle at sea broken off, fire nothing.**
4. **`on_encirclement` answers to the owner and, by `LocaliseEventText`'s rule, names the controller**
   - its text takes C as the controller of the scope's province where the country is 0 (`inferred`,
   from that function's record).
5. **A seed of 0 for coups, prides sunk and nukes**: every draw those scopes make of their own state
   starts from the same value each time (`inferred`, from the record of the LCG at 0x6A2E90).
6. **`$PRIDE_SUNK$`, `$PRIDE_SINKER$` and the six `last_*_losses` are the world's, read when the text is
   made**, so a later sinking or battle before the window is drawn changes what it says (`inferred`).
   For the trigger, the losses are written in `Conclude` before the pick, so `last_battle_*_losses` in
   an `on_battle_*` trigger is this battle's (`confirmed`) - which answers
   `FINDINGS-triggerleaves.md`'s open question.
7. **The coup command's keys are backwards**: `from` the target, `to` the instigator.
8. **Friendly fire can sink one's own pride** (from `CSubUnit::PickTarget`'s pick of its own side and the
   pride's test having no side; not seen): `on_enemy_pride_sunk` then fires for the pride's own country,
   FROM itself.
9. **A surrender repeats every 30 days** while the progress stays full and the country is at war.

## 4. Not read

The capitulation (0xE9220) in order; the coup's chance (0xF7AD0); the pride helpers (0xE64B0,
0xE6500); the nuke's damage; the other seven callers of `GetSurrenderProgress`; whether anything but
`CNavalCombatant::Attack` writes the game state's +0x48/+0x4C (no scan of the whole image); whether a
raid's throwaway defenders can sink a raider's pride. In the `frontier`: 0xE9220, 0xF7AD0, 0xE64B0,
0xE6500, 0x229A30.

**Trap hit**: `functionStart` answered nothing for `Conclude`'s string references (VA 0x576B22 and
others), so the function was settled by decompiling what holds them.
