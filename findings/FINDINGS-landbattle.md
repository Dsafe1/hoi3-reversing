# A land battle from its first hour to its last

Read out of `hoi3_tfh.exe` on 2026-10-09 for the rewrite's land combat, with no game running.
`FINDINGS-combat.md` has the shape of a combat and how one shot becomes damage,
`FINDINGS-combatmods.md` what decides each modifier, `FINDINGS-shatter.md` shattering and the
search for somewhere to fall back to. This file is what joins them: **what starts a battle, who
stands on the front and who waits, the order of an hour, what ends it, and the delay an attack
leaves behind.** Addresses are virtual (image base `0x400000`) unless they say rva.

Nothing here was checked against a running game or a savegame - none of the twelve saves at
hand has a battle in it. Where a number came out of a static initialiser the float it was made
from is given.

## In one paragraph

A land unit with a path asks each hour whether the province it is walking to holds an enemy
land unit, and if so starts a battle there **without entering it**: it fights from where it
stands, and its walk goes on underneath, held at the far end until the battle is over. The first
hour the battle is looked at, each side's units are ordered and put on the **front** until the
combat width is used up; the rest are **reserves**. Each hour both sides shoot, front against
front; then the damage is settled, and a front unit that can no longer fight falls back on its
own. From the fourth hour a side whose front is empty - or whose front has no organisation left -
has lost: its units fall back, the battle is deleted, and every unit left in the province looks
for a new one. A winner that was attacking arrives in the next hour and takes the province.

## 1. What starts one

### The hourly look: `CUnit::CheckOrderAndCombat`

Already recorded (`0x5BA2F0`, slot 31; `FINDINGS-seaair.md`, section 3, has it in order). Its
sixth step, read through:

    a land unit with a path, next = the first province of the path
    if  CUnit::HasEnemyLandUnitIn(unit, next)            0x5C00F0
    and the unit has no battle in next                   CUnit::HasCombatIn
    and it received supplies (CUnit +0xFC >= 1):
        not retreating:
            attack delay > 0 and movement progress < 1   -> nothing this hour
            otherwise                                    -> CheckForCombat(unit, next)
        retreating:
            HasEnemyLandUnitIn(unit, the province it STANDS in):
                0x5C0060(unit, next) says no             -> the unit is removed from the game
                otherwise                                -> nothing this hour
            no enemy where it stands                     -> `retreat` is cleared, and
                                                            CheckForCombat(unit, next)

So **a retreating unit with enemies both where it is and where it is going is destroyed**
unless the province ahead is its own country's and holds a friend - and one that has shaken its
pursuers off turns and fights whatever is in front of it. (The decompiler shows the two calls
of `HasEnemyLandUnitIn` alike; the province is in EAX, `ebx` the first time and `[esi+0x130]`
the second, `0x5BA599` and `0x5BA5D2`.)

`CUnit::HasEnemyLandUnitIn` (`0x5C00F0`; the province in EAX, the unit on the stack, `ret 4`):
true when the province holds a unit that is a land unit (slot 15), whose byte `+0x158`
(`retreat`) is clear, and whose owner is an enemy of the asking unit's owner there
(`CCountry::IsEnemy(owner, tag, province)`). `0x5C0060` (same convention) is its opposite for a
retreat: the province is controlled by the unit's owner **and** holds a land unit that is not
retreating and whose owner is a friend.

The tenth step is the other caller that matters: **a unit with no path, not retreating and in no
battle calls `CheckForCombat` for the province it stands in**, every hour. That is what lets a
unit that was walked up to join the defence, and what takes an undefended province (below).

### `CCombatManager::CheckForCombat`

`0x430960`, already recorded as where every combat starts. Read through for a land unit:

1. a land unit with something at `+0x300` of its slot 9 object whose `+0x140` is positive, or
   with anything at `+0x304`, does nothing (loaded on a transport, by the fields; not chased);
2. no province, or province 0: nothing;
3. not yet in a battle there: `JoinCombatInProvince(province, unit)` (`0x430690`) - for
   each battle on the province's list (`CMapProvince +0x2EC`) whose kind is the unit's (land
   battle and land unit, and so on), `combat->AddUnit(unit)` (slot 18), stopping at the first
   that takes it. A unit with `+0xA0 > 0` is not offered, nor an air unit whose order's slot 34
   says no;
4. still not in a battle there: `CCombatManager::StartCombat(manager, province, unit)`;
5. **the province changes hands.** Reached when the unit is in no battle at all, its byte
   `+0x1A8` is clear, the province is land and has an owner, the unit is a land unit that is not
   retreating, **the province is the one the unit stands in**, and nothing is at `+0x304`:

       side = the unit's owner (for REB, by the rebel faction - not read)
       if no unit in the province is an enemy's land unit that stands its ground:
           CMapProvince::TakeControl(province, &side)                       0x4A1CD0

   where "an enemy's land unit that stands its ground" is: another unit, another owner, not
   retreating, a land unit with nothing at `+0x300` or `+0x304`, and either side REB or a war
   (or an undeclared war covering the province) between `side` and its owner. Then, where the
   player lost a province it controlled, the message `PROVINCELOST`.
6. an air unit whose order's slot 17 says so goes on to `StartBombing`.

So **a province is taken by a land unit standing in it with no enemy land unit beside it** - on
the hour it arrives (step 11 of `CUnit::AdvanceMovement` calls this) or any hour after.

### `CMapProvince::TakeControl`

`0x4A1CD0`, `(province, CCountryTag* by)`, `ret 8`. Who gets it, in order:

1. `to = by`. While `to` is a subject (`CCountry +0xF34`) and its overlord is at war with the
   province's controller (or either is REB, or an undeclared war covers the province) and is not
   the controller itself: `to = the overlord`. **A puppet's conquests go to its master.**
2. `to` is a government in exile in a faction of more than one member, and is not the faction's
   first member: the first member takes it if that one is an enemy of the province's owner.
3. the province's **controller** is not an enemy of `by` (a friend's ground being walked on):
   `to = the controller` - nothing changes. Otherwise, where the province's **owner** is not an
   enemy of `by` and is not a government in exile: `to = the owner`. **Ground taken back from an
   enemy goes to the friend who owns it.**
4. `to` is still `by` and is not the owner: look at the province's neighbours that can be
   entered. If none of them is controlled by `to`, and one is controlled by a country that is
   not a subject and in whose ground `to` may operate (`CCountry::CanOperateIn`), and that
   country is an enemy of the controller: **that neighbour's controller takes it.** The last
   such neighbour in edge order wins.
5. `to` differs from the controller: `0x4A2400(province, &to, &now, 1, 0, 0)` sets it (not
   read here; the occupation write-up has what follows from a change of controller).
6. where the controller did change: both countries' neighbour lists are rebuilt and the
   province's modifier values with them.

### `CCombatManager::StartCombat`

`0x430760`, already recorded. For land:

    the unit already has a battle in this province            -> 0
    CUnit +0xA0 > 0                                           -> 0
    find the first unit of the province, in list order, with
        CUnit::CanEngage(unit, that, 0, province) and 0x5CE000  -> the defender; none -> 0
    the defender is air -> kind 3; the province is land -> kind 1; else naval, kind 2
    the province already has a battle of that kind            -> that kind, nothing made
    [a counter: where the province has no controller, or its owner is an enemy of the unit's
     owner, 1000 is added to one of three per-country figures at military define slots
     0x3C / 0x3D / 0x3E past `MAX_MANPOWER` - not identified]
    CCombatManager::CreateCombat(manager, province, kind, unit, defender)

`CUnit::CanEngage` (`0x5C01F0`, already recorded) for two land units comes to: different units,
different owners, neither retreating, the attacker's byte `+0x1A8` clear, a war between the two
owners (or an undeclared war covering the defender's province, or either REB), and neither is a
land unit with no path that is loaded (`+0x300` / `+0x304`). `0x5CE000` looks at the
**defender's** order: under order `0x42E` with sub-state 0 yes, with sub-state 2 no, otherwise
by comparing the two units' slot 27 figures; under `0x6E9` or `0x3A8` no; anything else yes.
For a land defender with an ordinary order it is yes.

### `CCombatManager::CreateCombat`

`0x431370`, already recorded in full. The part that decides sides: the starting unit is added to
the **attacker**, the unit it found to the **defender**, and then every other unit in the
province is offered through `CCombat::AddUnit` (slot 18):

    a = attacker->IsHostileTo(unit)        CCombatant slot 17, 0x565500
    d = defender->IsHostileTo(unit)
    d and not a  -> the unit joins the attacker
    a and not d  -> the unit joins the defender
    otherwise    -> it is not taken

`CCombatant::IsHostileTo` is `CUnitList::AllHostileTo(&side->units, unit, isBombing)`
(`0x5D5E20`): **false for a side with no units**, and otherwise true only if **every** unit on
the side passes, against the candidate, the same tests as `CanEngage` (a war or REB, different
owners, neither retreating, the same arm, not loaded). So a unit joins the side whose enemies
are all its enemies - and a third party at war with both joins neither.

`CCombatant::AddUnit` (slot 12, `0x565190`) clears three fields of each of the unit's brigades
(`CSubUnit +0xB8`, `+0xBC`, the byte `+0xC0`), appends the unit to `units` (`+0x40`) if it is
not there, and its owner to `countries` (`+0x54`) and `own_countries` (`+0x64`) likewise.
`CLandCombatant::AddUnit` (`0x5693A0`) calls it and then adds each brigade's men to the side's
count by type (`men[type] += strength * MenPerStrength / 1000`, `+0x74`), and - **where the
side's front has already been set up** (the byte `+0xE0`) and a game is on screen - appends the
unit to the **reserves** (`+0xC0`) unless it is there. A unit that arrives late starts in
reserve.

`CUnit::AttachCombat` (`0x5BFE80`; the combat in EDI, the unit in ESI) is the unit's side of
it: a bombing is stored at `CUnit +0x110`, anything else appended to the unit's list of battles
at `+0x114` (count `+0x11C`). `CUnit::ShowFighting` (`0x5C7970`, `(unit, bool attacking)`)
zeroes the two fields at `+0xA8` and `+0xAC` and is otherwise the avatar: the `attack`
animation, facing the next province, the fighting point of the province.

## 2. The front line

A `CLandCombatant` has three lists of its own: **`front` (`+0xB0`)**, **`reserves` (`+0xC0`)**
and `retreat` (`+0xD0`), and the byte `+0xE0`, "the front has been set up". `FINDINGS-combat.md`
named them from the save keys and left open what fills the first; this is it.

### The width of a battle: `CCombat::GetCombatWidth`

`0x56BC80`, `(combat, int* out)`, `ret 8`:

    width = combat +0x34                       the two tactics' combat_width, section 5
    for each unit of the ATTACKER, in list order:
        from = the province it is in; if that is the battle's province and it has a
               previous province (CUnit +0x134), the previous one
        a paratrooper (CUnit +0x97) after the first paratrooper: skipped
        from already counted: skipped
        width += the first: BASE_COMBAT_WIDTH;  each further: ADDITIONAL_COMBAT_WIDTH

So **the width is 10 for an attack out of one province and 5 more for each further province
the attackers come from** (the base game's defines), all paratroopers together counting as one
direction, plus whatever the tactics add. It is one figure for the battle: the defender's front
is measured against the same width, by the **attacker's** directions.

`CLandCombatant` slot 18 (`0x56BB80`), `CountDirections`, is the number of distinct provinces
this side's units come from - the "provinces the enemy attacks from" of the stacking penalty and
the envelopment penalty in `FINDINGS-combatmods.md`. **It takes a unit's province the other way
about from the width**:

    GetCombatWidth:                        the unit is IN the battle's province and has a
                                           previous one -> the previous one; else where it is
    CountDirections, PickReinforcement:    the unit is NOT in the battle's province and has a
                                           previous one -> the previous one; else where it is

(`cmp esi, [combat+0x18]; jne` at `0x56BCFA` against `cmp eax, [combat+0x18]; je` at `0x56BBE6`
and `0x56BADB`.) So for the width an attacker next door counts by where it stands, which is the
direction it attacks from; for the other two it counts by where it was **before** it stood
there. That reads like a slip in one of the two, and is what the bytes say. *Corrected
2026-10-09: this file first gave the width's rule for all three.*

### The width of a unit: `CUnit::GetCombatWidth`

`0x5CD530` (the unit in EDX, the out pointer in ESI):

    w = sum over its brigades of definition->width (CSubUnitDefinition +0xE8)
    w = w * (1000 + owner.COMBAT_WIDTH) / 1000       the expeditionary owner's where it has one
    at least 1000

**This corrects the record**, whose `CSubUnitDefinition +0xE8` says "no reader in any combat
function": this is the reader, with `CArmy::CanFight` and `CUnit::RebuildDefinition`. The
country modifier is the technology and tactic key `combat_width` (a doctrine in the base game
gives -1 a level to named brigade types - which goes through the brigade's own definition, not
this modifier).

### Setting it up: `CLandCombatant::SetUpFrontLine`

`0x56C470`, `(side)`, `ret 4`. Called from `CLandCombat::Begin` (slot 13, `0x57B6E0`) for each
side whose `+0xE0` is clear - which `CCombatManager::Tick` runs before the round on the first
hour it sees the battle (the combat's byte `+0x29` clear) - and from `CCombat::AttachAndRegister`
after a load.

    side +0xE0 = 1
    for each unit of the side, in list order:
        cannot fight (slot 33)   -> appended to reserves
        otherwise                -> inserted into a sorted list
    for each of the sorted list, best first:
        room = CCombat::GetCombatWidth(combat) - sum of the front's unit widths
        room < 0                 -> stop
        otherwise                -> appended to the front
    everything left in the sorted list -> appended to reserves, in order

**The test is made before the unit is added**, so the front may overshoot the width by one
unit: with width 10 and three divisions of 4, all three stand (0, 4 and 8 used when asked).

The order (`0x56C240` for an attacker through the insert at `0x57D0C0`, `0x56C340` for a
defender through `0x57D190`):

    attacker:  (soft_attack + hard_attack + toughness     + 1000) * average organisation / 1000
                                                                   * total strength / 1000
    defender:  (soft_attack + defensiveness + skill * 1000 + ... + 1000) * the same two

on the unit's own summed definition (`CUnit +0xC8`: `+0x134`, `+0x138`, `+0x120`, `+0x11C`), the
unit with the larger figure first. The attacker's is read off the instructions and is exact. The
defender's adds its leader's skill (`CLeader +0x70`) and was read from the decompiler only,
which lost two of its terms - **`likely` for the shape, not for the terms**.

`CArmy::CanFight` (slot 33, `0x5D35C0`, already recorded): over the brigades with a width, the
average strength is at least 100 (0.1) and the average organisation at least 1000 (1.0).

### Each hour: `CLandCombatant::UpdateFrontLine`

`0x56BE40`, `(side)`, `ret 4`; the first thing `CLandCombatant::Attack` does after the leaders'
hours, so **the attacker's front is seen to before anyone shoots and the defender's after the
attacker has shot**.

1. **Each front unit that cannot fight** (and the combat's slot 12, true for every kind): taken
   off the front, `CUnit::RetreatFromCombat(unit, side)`, and where this side is the
   **defender**, `CCombat::DamageProvinceBuildings(combat)`.
2. `room = width - the front's widths`.
   - `room < 0`: if the width is less than the front's total **without its last unit** and the
     front is not empty, **the last front unit goes back to the reserves** (appended). One an
     hour.
   - otherwise, repeatedly: recompute `room`; stop when it is negative or there are no
     reserves; `pick = CLandCombatant::PickReinforcement(side)`; none: stop; the pick moves from
     the reserves to the end of the front.
3. Each unit on the `retreat` list that can fight goes to the reserves. (Nothing read here puts
   a unit on that list; it may only ever come out of a save.)

### Who comes up from reserve: `CLandCombatant::PickReinforcement`

`0x56B7D0`, `(side)`, `ret 4`, the unit or null.

    used[p] = for every unit of the side (front and reserve alike), by the province p it comes
              from (as CountDirections takes it, above): the sum of its width / 1000
    best = none, bestScore = -1000
    for each reserve, in list order:
        can fight, and the battle's hour counter (CCombat +0x1C) is above 0:
            chance = CUnit::ReinforceChance(unit, isAttacker)          thousandths
            percent = chance * 100000 / 1000 / 1000                    whole
            draw = Random() % 100                                      the game's one generator
            draw <= percent:
                score = CUnit::ReinforceScore(unit)
                if used[its province] >= BASE_COMBAT_WIDTH / 1000:  score = score / 1000
                score > bestScore -> best = this one

**Every reserve that can fight costs one draw of the generator an hour**, whether or not there
is room for more than one. `CUnit::ReinforceChance` (`0x5CDA40`, `(unit, int* out, bool
attacker)`, `ret 0xC`):

    cannot fight -> 0
    c = 10                                              (floor of the float 10.5)
      + owner.technology +0x58                          the `reinforce_chance` technologies
      + owner.ATTACK_REINFORCE_CHANCE or DEFEND_REINFORCE_CHANCE, by the side
    a division (oob level 4) under a corps (level 3) whose headquarters is in the unit's
    province or the one next to it:
        c += corps leader's skill * 1000 * 10 / 1000 * CUnit::CommandReach(unit, 3) / 1000
    chance = c * (average organisation * 1000 / 100000) / 1000

So the chance scales with the unit's organisation over a hundred. `CUnit::ReinforceScore`
(`0x5BACD0`; the unit in EDI, the out pointer in ESI), off the instructions:

    s = soft_attack + hard_attack + defensiveness + toughness          the summed definition
    s = s * (average organisation * 10 / 1000) / 1000
    s = s * (total strength * 10 / 1000) / 1000

## 3. The hour

`CCombatManager::Tick` (`0x42FB70`, already recorded) copies the list of battles and, for each
in list order: `combat->Begin()` (slot 13) where the byte `+0x29` is clear, then
`combat->Tick()` (slot 15), and where that answers 1, `CCombat::Finish`. `CCombat::Begin`
(`0x572580`) is the "battle started" message and nothing else that was found;
`CLandCombat::Begin` runs the two `SetUpFrontLine` first.

`CCombat::Tick` (`0x56EBE0`), for a land battle, in order:

1. `CCombat::StampWars` (`0x56E890`): the war between each attacker country and each defender
   country has its `action` date set to now.
2. **Tactics**, where either side has none or `duration % (TACTIC_SWAP_FREQUENCEY / 1000) == 0`:
   `CCombat::PickTactics` (`0x56E9B0`), section 5.
3. `duration` (`+0x20`) is incremented.
4. The first hour (`+0x1C == -1`): two dice, `attacker.dice = Random() % 10`, then the
   defender's, and `+0x1C = 0`. (The naval and air arms of this block are strategic warfare.)
5. **Every hour, two dice again**: `attacker.dice = Random() % 10`, `defender.dice = Random() %
   10` (`CCombatant +0x50`). What reads them was not found in the land path.
6. `attacker->ApplyCombatModifiers(defender)`, then `defender->ApplyCombatModifiers(attacker)`
   (slot 19; `FINDINGS-combatmods.md`). Each begins by resetting every unit's four products to
   1000 and its `defences_used` to 0.
7. **`attacker->Attack(defender)`, then `defender->Attack(attacker)`** (slot 15).
8. A strategic warfare tally (`0x464E50`).
9. `CCombatant::ApplyLosses(attacker)`, then the defender's: the damage is settled, unit by
   unit, and shattering decided (`FINDINGS-shatter.md`).
10. Each side's units lose sub units under 0.1 strength - **ships only** (`0x5D6620` with 1:
    `0x5C4020` skips a unit that is not naval).
11. **From the fourth hour** (`duration >= 4`), and unless the byte `+0x2B` is set:
    - `attacker->HasLost()` (slot 16): `CCombat::Conclude(combat, true)`, then
      `CUnit::RetreatFromCombat` for each attacking unit. The answer is 1.
    - else `defender->HasLost()`: `CCombat::Conclude(combat, false)`,
      `CCombatant::RetreatAllUnits(defender)`. The answer is 1.
    - else the player's combat status window, where the player is in it.
12. `+0x1C` is incremented; the answer is 0.

**The attacker is asked first**, so where both fronts empty in the same hour the attacker has
lost. **`+0x1C` is recorded as `day`** from its save key; it counts the hours of the battle from
0 and is what `PickReinforcement` tests, so **nobody comes up from reserve in the first hour**.

### One side's shooting: `CLandCombatant::Attack`

`0x56B340`, already recorded. In order: `AccumulateLeaderCombatHours` for the front,
`UpdateFrontLine` (section 2), `GainTechAbility` of `LAND_DOCTRINE_INCREASE` in the category
the defines name for every country on the side (`0x565430`), **one `Random()` that seeds the
side's own generator**, and `CLandCombatant::FireUnit` for each front unit in order. Once a day
(`(tick - 43800000) % 24 == 0`) the allies' help tally of strategic warfare.

`FireUnit` is in `FINDINGS-combat.md`. What that leaves open, settled here:

- **Two generators.** The target, the extra shot and the two damage dice come from the side's
  own stream: `x = x * 0x343FD + 0x269EC3`, twice a draw, and a draw is
  `((x1 >> 16) & 0x7FFF) * ((x2 >> 16) & 0x7FFF)`. `CUnit::RollToHit` draws **twice from the
  game's generator** per shot: `Random() % 100` against the fraction of the defence figure,
  then `Random() % 100` against the chance to avoid.

  **The game's generator is seeded afresh every hour.** `RunHourlyTick` stores the dword at
  `+4` of the hour's tick payload as the seed (`0x681C6B`..`0x681C6E`, into `0x174DA94`),
  zeroes the count of draws, and calls `ReseedGlobalRandom` (`0xAA2ED0`) - which, besides
  initialising the state through `0xAA2BF0` (not read), runs the generator forward by the
  count of draws, so a generator can be put back where a save left it. An hour's rolls
  therefore depend on that figure and on the order of the hour's draws. **The battles are
  not first in that order**: `CCombatManager::Tick` is the last step of the hourly pass,
  after every unit's own hour and the AI's, and `StartAttackDelay` and the reserves draw
  too. Making an hour of a savegame's battle again would need every draw before it.
- **The extra shot**: `shots = n / 1000`; `rest = (n % 1000) * 100000 / 1000`; one more when
  `draw % 100 < rest / 1000`.
- **The two dice of a hit** are drawn in the order organisation, then strength, by four steps of
  the stream: `organisation die = (step1 * step2) % (ORG_DICE / 1000) + 1` and `strength die =
  (step3 * step4) % (STR_DICE / 1000) + 1`, each `* 1000`.
- **The "doctrine figure"** `FINDINGS-combat.md` adds to the damage factor is the **tactics'**:
  `combat +0x38` for a shooting attacker and `+0x3C` for a shooting defender (section 5).
- **`CUnit::StrengthDamageFactor`** (`0x5CD180`): `p = strength * 1000 / (sum of the brigades'
  definition max_strength)`; `n = max(1, p * 10000 / 1000 / 1000)`; the answer is `n * 1000 *
  100 / 1000`. So **1000 at full strength, 100 for each tenth**, never less than 100 - the
  global at rva `0x168874C` is the floor of the float 100.5. A full-strength unit's hit is
  doubled: `factor = tactic + 1000 + 1000`.
- **A brigade's damage is divided by a hundred.** `CSubUnit::SettleDamage` multiplies the
  pending strength and the pending organisation by `g_CombatModifierFloor / 1000` where the sub
  unit's slot 9 or slot 11 answers true - a **brigade** or a **wing**, by `FINDINGS-combat3.md`,
  section 7 - and that global (rva `0x168868C`) is the floor of the float 10.5. A ship takes
  the figure whole. The same factor is in `CUnit::IsOutOfTheFight`. Then both are capped at
  what the sub unit has: `strength -= min(pending, strength)` - **`FINDINGS-combat.md` says the
  strength is taken unclamped; the `cmp`/`mov` before the subtraction clamps it too.**

  So one landed shot of a full-strength unit with no tactic, base game defines:

      organisation: die 1..4 * 2.0 * 7.5 / 100 = 0.15 .. 0.60, split evenly over the brigades
      strength:     die 1..2 * 2.0 * 0.6 / 100 = 0.012 .. 0.024, by each brigade's share of
                    the unit's max_strength

- **`CUnit::TakeDamage`**'s strength share is `brigade GetMaxStrength(false, false) * 1000 /
  the sum of the brigades' definition max_strength`.

### What a unit pays besides: `CUnit::SettleCombatDamage`

`0x5C3820`, already recorded for shattering. Before that, for a land unit that lost strength
`lost` this hour with `n` brigades:

    AddCasualtyTrickleback(unit, lost)                              FINDINGS-manpower.md
    officers -= lost * definition.officers / 1000 * 1000 / (n * 100) * OFFICER_COMBAT_LOSS / 1000
                (the expeditionary owner's pool where there is one; not below 0)

and `CUnit::ShatterThreshold`'s "national value" at `CCountry +0xD4`, which
`FINDINGS-shatter.md` could not name, is the **officer ratio** - the record has had that field
named since the organisation reading: `t = min(1000 - 500 * officerRatio / 1000, 500)`.

## 4. The end

### Has a side lost: `CCombatant::HasLost`

Slot 16, `0x5656F0`:

    the byte CCombatant +0xA8 is set                     -> lost     (set by 0x57F700, 0x7049E0
                                                                       and cleared by 0x703BF0;
                                                                       not read - a withdrawal
                                                                       ordered from outside)
    the side's total strength is under 10 (0.010)        -> lost
    otherwise, where the combat's slot 12 says so (always): this->IsSpent()   slot 23

`CLandCombatant::IsSpent` (`0x568F00`) for a land battle:

    the front is empty                                   -> lost
    otherwise: the average, over the front and the `retreat` list, of each unit's average
               organisation (slot 20) is at most 1000    -> lost

(the 1000 is the dword at `0x170D520`, never written). Because a front unit that cannot fight
leaves in `UpdateFrontLine`, **the usual end is an empty front**: the last unit on it fell back
and no reserve came up. Reserves do not save a side by being there.

### `CCombat::Conclude`

`0x574580`, `(combat, bool attackerLost)`, `ret 8`, 0x69D0 bytes of which nearly all is the
message. It runs once (the byte `+0x28` is set; it does nothing where `+0x28` or `+0x2B` already
is). What it changes:

- for a land battle in a province whose owner is an enemy of the losers: **each winning country
  that is a friend of the owner, and is not the owner, gains 5 relation with the owner**
  (`CCountry::ChangeRelation(.., 5000)`);
- each winner's and each loser's count of land battles (`CCountry` `land_battles_fought`) goes
  up by one, and the on-actions `on_battle_won` / `on_battle_lost` are fired with the country,
  the province and the first enemy country as `FROM`;
- the messages, to the countries involved.

`CCombat::UnitLeaves` (`0x57AF70`; the combat in EDI, `(unit, bool quiet)`, `ret 8`) is how one
unit leaves a battle that goes on: where it was the **only** unit of its side the battle is
concluded against that side first; it is taken off its own list of battles, shown idle unless
`quiet`, and removed from both sides (slot 13).

### Falling back: `CUnit::RetreatFromCombat`

`0x565760`, already recorded (`FINDINGS-shatter.md`). In order, for a land unit:

`CUnit::FindRetreatProvince` asks `CUnit::CanRetreatToProvince` (slot 19, `0x5C5C60`, `ret 4`;
the name is the maintainer's, out of his Ghidra project) of each land province next to the
unit: the target has to be the unit's own province or one it has an edge to, **no enemy land
strength may stand in it** (`EnemyLandStrengthIn` under 1), and either its controller is no
enemy of the unit's owner or the unit's average organisation is at least 1000. So **a unit that
still has an organisation of one may fall back onto an enemy's undefended ground**, and one
that has not may only go to ground that is not an enemy's.

1. `to = CUnit::FindRetreatProvince(unit)`; but **where the unit is not in the battle's
   province** (an attacker, fighting from next door) `to = the province it is in`;
2. the battle is taken off the unit's list and the unit off the side (`RemoveUnit`, slot 13 -
   which for a land side also takes it off the front, the reserves and the retreat list);
3. nowhere to go: the unit is removed from the game;
4. no route to `to` and it is not where the unit stands: removed from the game;
5. its order becomes a null order;
6. `to` is where it stands: `CUnit::CancelMovement(unit, true)` - **a beaten attacker stops
   where it is**, and nothing sets `retreat`;
7. otherwise `SetUnitPath(unit, path, true)`, both dates to null, the movement progress set to
   `RETREAT_PROGRESS` (0.9 in the base game) times the largest share of the way any of the
   **defender's** units has walked (`progress * 1000 / distance`, `0x5CA340`), and
   `retreat = true`.

A retreating unit is no enemy to `HasEnemyLandUnitIn`, `CanEngage` or the hold test of
`CheckForCombat`, walks a tenth faster (`FINDINGS-movement.md`), and stops retreating when it
arrives.

### After the last hour: `CCombat::Finish`

`0x431730`, already recorded: `CCombat::End` (slot 14, `0x57AB00` - the byte `+0x2A` set, every
unit detached from both sides, the battle off the province's list), the history entry, the
delete; and then **`CheckForCombat(unit, province)` for every unit standing in the province**.
That is where a battle between two of three parties starts again as a new one, and where a
winner already standing there takes the province.

A winning attacker is not standing there. Its walk was held at the full distance while it
fought (`CUnit::AdvanceMovement`, step 9), so **in its next hourly pass it arrives**, enters,
and `CheckForCombat` finds no enemy that stands its ground - the defenders are retreating - and
takes the province.

### What it does to the province: `CCombat::DamageProvinceBuildings`

`0x57B2A0`, `(combat)`, `ret 4`; run each time a **defending** front unit falls back. For each
building of the province (`CMapProvince +0x310 .. +0x314`) with a level above 0, one draw:
`Random() % 100 < COMBAT_PUSHBACK_CHANCE_FOR_DAMAGE / 1000` takes `COMBAT_PUSHBACK_DAMAGE` off
its current size (`+0x24`, not below 0) and sets its damaged byte (`+0x28`) where that changed
anything. One level, at 50 per cent, in the base game.

## 5. Tactics, as far as they were read

`CCombat::PickTactics` (`0x56E9B0`), land battles only, and only where both sides have a
country: each side's highest ranked leader gives a skill (0 where its slot 8 says it is no
leader) and a second figure from `0x5D3F10` (an aggressiveness, by the stance set on a
headquarters above it: -1000, the floors of two floats, 1000, or the unit's own `+0x4C`). The
side with the **lower** skill picks first (`CCombatant::PickTactic`, `0x5649A0`, `(side,
aggressiveness, enemy tactic's id, skill difference)`), and the other picks against it with the
difference in skill - which is what `INITIATIVE_PICK_COUNTER_ADVANTAGE_FACTOR` works on. Equal
skill: the attacker first, the defender second, no advantage. `PickTactic` itself, the layout
of a tactic and the conditions of a `trigger` were read later: `FINDINGS-combatview.md`,
section 11.

`CCombat::SumTacticEffects` (`0x56EB00`, the combat in EAX) then fills four figures of the
battle from the two tactics, leaving out a tactic that is **countered** by the other
(`a.countered_by == b`: `a`'s `CCombatTactic +0x78` against `b`'s `+0x80`, its own number -
this said the two offsets the other way round until `FINDINGS-combatview.md`, section 11, read
the loader and the pick):

| `CCombat` | from `CCombatTactic` | key |
| --- | --- | --- |
| `+0x34` | `+0xCC` | `combat_width` - added to the battle's width |
| `+0x38` | `+0xD0` | `attacker` - the attacker's damage factor |
| `+0x3C` | `+0xD4` | `defender` - the defender's damage factor |
| `+0x40` | `+0xD8` | `movement_speed` - how fast the attack delay runs down |

Which of the four is which follows from their readers (`GetCombatWidth`, `FireUnit` by the
side's `is_attacker`, the attack delay below) and the order of the keys in the file; the
`CCombatTactic` offsets themselves are **`inferred`**.

## 6. The attack delay

`CUnit +0xD4`, thousandths of an hour - recorded as `combat_cooldown`, and what
`FINDINGS-movement.md` calls the attack delay - and `+0xD8`, the hours the unit has been
attacking. Both are seen to in `CheckOrderAndCombat` after the look for a battle and before the
unit moves:

    attacking = a land unit in a battle, with a path, whose movement progress is at least 1

    not attacking:
        delay -= 1000, not below 0
        in no battle, delay > 0, hours > 0:
            hours <= UNIT_ATTACK_DELAY_PERIOD / 1000:   delay = delay * hours / that period
            delay is at least 1000;  hours = 0
        delay < 1: hours = 0

    attacking:
        hours += 1
        delay == 0:  CUnit::StartAttackDelay(unit)                       0x5BAE20
        delay > 1000:
            m = the movement_speed of the tactics (CCombat +0x40) * 2000 / 1000, of the first of
                its battles in which it is on the attacker's list, else 0
            delay -= 250 + (1000 + owner.COMBAT_MOVEMENT_SPEED + owner.technology +0x54
                            + the leader's combat_move_speed trait) * m / 1000
            delay is at least 1000

`CUnit::StartAttackDelay`:

    delay = (UNIT_ATTACK_DELAY / 1000) * 1000          PARATROOP_MISSION_DELAY for a paratrooper
          + (Random() % (UNIT_ATTACK_DELAY_MODIFY / 1000)) * 1000
          + (1000 - officerRatio) * 72000 / 1000       the expeditionary owner's ratio if any
          - (owner.technology +0x18 / 1000) * 1000     the `attack_delay` technologies
    at least 12000

So in the base game **an attack starts a delay of 168 to 177 hours** (more for a country short
of officers, 24 less for each level of the doctrine), which runs down by a quarter of an hour
for each hour of fighting - faster under a tactic with a movement speed - and, **once the
battle is over, is cut to `hours / 12` of itself where the unit attacked for twelve hours or
fewer**, then runs down an hour an hour. The 250 is the floor of the float 250.5 (rva
`0x1688744`).

What the delay stops, from the two readings: the hourly look does not start a battle for a
unit with a delay and no progress, and `CUnit::AdvanceMovement` does not let such a unit set
off at all, and zeroes the progress of one that arrives with a delay running
(`FINDINGS-movement.md`, section 5). A unit already walking keeps walking.

## 7. Leaving a battle by order

`SetUnitPath` (`FINDINGS-movement.md`, section 4) for a unit in a battle: `CUnit::MayLeaveCombats`
(`0x5C0000`; the unit in EAX) asks each of its battles' slot 12 and goes on where one says yes
- every kind's slot 12 is the shared "true", so it always may; `CUnit::LeaveAllCombats`
(`0x5BFF70`) is `UnitLeaves(unit, false)` for each and for a bombing; and `0x5C0160(unit, 0)`
says whether it was **holding ground** - in some battle on the defender's list while the
attacker still has a country, or the other way about - in which case the unit is marked
retreating. And in the hourly pass, a unit is taken out (`UnitLeaves(unit, true)`) of any battle
whose province is neither the one it stands in nor next to it.

## 8. The modifiers, as they were read again for the rewrite

`FINDINGS-combatmods.md`, section 5, has what decides each. Reading
`CLandCombatant::ApplyCombatModifiers` (`0x569B50`) through again to build them gave three
things that file does not say, and one it says wrongly.

**How one is applied.** `CUnit::AddCombatModifier` multiplies it into the unit's two products,
`product = product * max(value + 1000, 10) / 1000` - so no single modifier leaves a unit under
a hundredth of what it had. The 10 is the global `Define10` (the floor of the float 10.5).

**The order.** Per unit, in this order - and since each is multiplied in and cut, the order is
what the last thousandth depends on: for an attacker `AddAssaultModifiers` (river, paratroop,
amphibious, fort); then shore bombardment, multiple combats, difficulty, experience, mission
efficiency, combined arms, dissent, lack of supplies, dig-in, the division (stacking) penalty,
terrain, weather, night, leader, envelopment, encirclement, territorial pride.

**Weather and night are against the attack only.** Both pass their figure as the attack delta
and **0** as the defend delta - `0x56A99F`..`0x56A9B5` for the weather, `0x56AA0B`..`0x56AA19`
for the night; `AddTerrainModifier` beside them (`0x565575`, `0x56557B`) stores the one figure
in both. `FINDINGS-combatmods.md` said every land site passes the same number twice, and is
corrected; `FINDINGS-combat.md` had watched the night do exactly this in a running game.

**The directions are the attacker's, for both sides.** The list the stacking penalty and the
envelopment penalty count is built once per call, of the distinct provinces the **attacker's**
units stand in (`CUnit +0x130`): from `this->units` where this side is the attacker
(`0x56A0D2`), from `other->units` where it is the defender (`0x56A037`). So a defender's
stacking is eased by three for each direction it is attacked from, as the attacker's is - and
this count does not use the unit's previous province at all, unlike the three of section 2.

    n   = this side's front + its reserves that can fight - 3 * directions
    f   = 1000;  for i in 1 .. min(n - 1, 99):  f = f * (1000 + BASE_STACKING_PENALTY) / 1000
    raw = 1000 - f

**Dig-in**, which the modifier reads (`CUnit +0x1C8`): `CUnit::UpdateDaily` adds 1000 to it for
a land unit with no path, in no combat and under no bombing, not loaded, whose owner is at war,
while it is under `UNIT_DIGIN_CAP` plus the owner's technology figure at `+0x14`
(`0x5BB09F`..`0x5BB13C`); and `CUnit::CheckOrderAndCombat` zeroes it each hour for a unit with a
path or whose owner is at peace (`FINDINGS-seaair.md`, section 3, step 7).

## What was not read, and what is not established

- **`CCombatant::PickTactic`** and with it what the two dice of each hour are for.
- The defender's ordering figure in `SetUpFrontLine`, beyond its shape.
- `0x4A2400`, the change of controller itself, and the three counters `StartCombat` adds to.
- `CCombatant +0xA8` and its three writers.
- `CCombat +0x2B`: set, a battle never ends by `HasLost` and has no messages. The history entry
  copies it; `CCombatIsConvoyTrigger` suggests a convoy raid. Not chased.
- What puts a unit on the `retreat` list of a side.
- Whether the "loaded" fields at `+0x300` and `+0x304` of a land unit's slot 9 object are what
  they look like.
- Everything about the experience a battle gives (`GrantCombatExperience`,
  `FINDINGS-leaders.md`) was left as it is recorded.
- **None of it was watched.** The orders in sections 2 and 3 decide who is shot at and so the
  course of a battle; the first battle fought in the running game with a probe on `front` would
  confirm or correct them.
