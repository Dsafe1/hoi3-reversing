# A battle at sea, from the first sighting to the last ship

Read statically out of `hoi3_tfh.exe` on 2026-10-10, for the rewrite's battle between fleets.
Addresses are **VAs** unless a line says rva; `rva = VA - 0x400000`. Only valid for this build.
**Nothing here was watched in a running game**, and no savegame at hand has a naval battle in it.

It joins and finishes three earlier readings: `FINDINGS-navaldetection.md` for the sighting, the
positioning figure and the roll that breaks a battle off, `FINDINGS-combatmods.md` (sections 6
and 9) for what an hour makes of a ship and the first reading of a ship's shooting, and
`FINDINGS-landbattle.md` for the hour all battles share. What was not known before is in bold in
the one-line summary; the corrections are collected at the end.

**In one line.** A fleet in a sea province looks at the first enemy fleet there and rolls to see
it; a battle then puts both fleets' ships **at a distance from the enemy**, each its own, and
every hour each ship that has a target in reach shoots at it and then **closes or opens that
distance**. A ship picks its target by its side's positioning: a good roll gets it a choice among
the enemy ships **in range** - mostly at random, now and then the most valuable - and a bad one
gets it nothing, or **one of its own side's ships**. Damage is two dice divided by the target's
hull; a ship whose notes pass its strength is sunk. A battle is over when a side's ships average
under one organisation, when a side has left, or when the hourly roll to break off has passed
often enough - and **a fleet told to leave needs four hours of counting before it goes**.

---

## 1. What starts one

`CCombatManager::CheckForCombat` (`0x430960`) and its callers are in `FINDINGS-landbattle.md`,
section 1: every unit that enters a province, and every unit with no path, not retreating and in
no battle, once an hour for the province it is in. For a fleet it comes to
`JoinCombatInProvince` - a naval battle already in the province takes the fleet on the side whose
enemies are all its own, **with no sighting asked** - and then `CCombatManager::StartCombat`
(`0x430760`), read again in full:

    the unit already has a battle in this province            -> 0
    CUnit +0xA0 > 0                                           -> 0
    an air unit whose order's slot 34 says no                 -> 0
    the first unit of the province, in list order, with
        CUnit::CanEngage(unit, that, false, province) and
        DefenderAcceptsBattle(that, unit)                     -> the defender; none -> 0
    the defender is air -> kind 3; the province is land -> kind 1; else, kind 2:
        ours = unit->AsNavy(), theirs = defender->AsNavy()
        ours has no ship                                      -> 0
        ShouldStartNavalCombat(ours, theirs) says no          -> 0
    the province already has a battle of that kind            -> that kind, nothing made
    CCombatManager::CreateCombat(manager, province, kind, unit, defender)

**Only the first enemy found is tried**: a failed sighting of it ends the hour's look, whoever
else is there.

`CUnit::CanEngage` (`0x5C01F0`; the asking unit in EDI, `(other, bool bombing, province)`,
`ret 0xC`), without the bombing flag, wants: a war between the two owners (or an undeclared war
covering the other's province, or either REB - `0x42EFD0` is the three-letter test); different
units and owners; neither retreating; **the same arm** - a land unit only a land unit, a fleet
only a fleet, an air unit only an air unit; for air units the order tests of
`FINDINGS-airnaval.md`; **a fleet in a land province only where the other's order answers its
slot 27**; and neither a loaded land unit that is going nowhere. So two fleets fight at sea, and a
fleet in port is not reached by one outside it.

**`DefenderAcceptsBattle`** (`0x5CE000`; the unit found in EAX, the asking unit in EDI, bare
`ret`) looks at the **found unit's** order:

    patrol (0x42E):  its stance (slot 19) 0, aggressive  -> yes
                     2, passive                          -> no
                     otherwise                           -> asker's GetPower < its own GetPower
    convoy_raid (0x6E9) or transport (0x3A8)             -> no
    anything else                                        -> yes

A fleet on a defensive patrol is only made the defender of a battle by a weaker fleet, and
raiders and transports never are. `CUnit::GetPower` is slot 27, already recorded.

`ShouldStartNavalCombat` is in `FINDINGS-navaldetection.md` in full. Three things about it bear
repeating, because they decide who ever fights:

- **gate 4: a fleet of a country no person plays does not start a battle while its order is
  none, a rebase, an invasion or a transport.** An idle fleet of the AI's waits to be found; an
  idle fleet of the player's looks every hour.
- gate 5: a fleet with submarines does not attack one with more screens than a third of its
  submarines.
- the roll is per pair of ships, against 10000 for a fleet, and its figure is scaled by the
  **intelligence level** the asking fleet's country has of the sea province.

### The intelligence level of a sea province

`UpdateIntelFunctor_SerialBody` (`0x6883B0`) was read as far as this needs. For each province,
each unit standing in it whose owner is not the controller:

    a land province                                      -> the owner's level there is 9
    a sea province: a battle of kind 1 on its list       -> 9      (never, at sea)
                    the unit's order is a patrol (0x42E)
                    whose reference at order +0x48
                    resolves                             -> 9
                    otherwise                            -> at least 2

and then every country with a radar technology flag (`CTechnologyStatus +0xDC`) gets, in the
provinces within reach of its radar stations (`CCountry +0x1148`, each province's modifier 48,
`MODIFIER_RADAR_LEVEL`), a level between 0 and 8 made of the difference of two technology
figures and a country modifier - one level for the nearer ring, one less for the farther. The
radar part was read for its shape only.

So **a fleet that is merely in a sea province knows it at level 2** - which multiplies its
sightings by 1.25 - **a fleet on patrol there at 9**, which `ShouldStartNavalCombat` takes for a
sighting with no roll at all, and radar gives up to 8, ten times the bare figure.

## 2. The two sides, and where each ship starts

`CCombatManager::CreateCombat` adds the asking fleet to the attacker and the fleet it found to
the defender, and offers everyone else in the province (`FINDINGS-landbattle.md`, section 1; the
tests of `CUnitList::AllHostileTo` keep it to fleets).

**`CNavalCombatant::AddUnit`** (slot 12, `0x566F20`, `ret 4`), read through:

    CCombatant::AddUnit(this, unit)          the unit on `units`, its owner on the two country
                                             lists, every ship's remembered target cleared
    CNavalCombatant::UpdatePositioning(this)
    for each ship: this->size[type] += 1000                          (+0x74)

    base = 0;  capitals = 0
    the battle has had a round (CCombat +0x1C is not -1) and the side has a unit:
        base = 100000                                                a hundred
        capitals = the current_distance of the first capital ship found among the side's
                   fleets, fleet by fleet, stopping at the first that is above 0

    spread = (5 - the unit's leader's skill) * 1000, not under 0
    for each ship of the unit, in order:
        half = definition.firing_distance (+0x14C) * 1000 / 2000
        f    = max(300 - GetTraitEffect(unit, 13 spread_out), 100)   0x1A881A8 is floor(300.5)
        x    = f * half / 1000 * spread / 1000
               * (1000 - definition.positioning (+0x184)) / 1000
        x    = max(x, 2000)
        d    = half + (Random() % (x / 1000)) * 1000
        a capital ship (+0x2F):  capitals == 0 -> capitals = d
        any other:               Random() % 100 < 50 -> d = -d
                                 d += capitals
        current_distance (+0xC8) = max(d + base, 1000)

So **every ship has a distance of its own**, in the units of the unit files' `distance` times a
hundred (a battleship's 0.32 is held as 32.000). A capital ship starts at half its own reach or
up to `0.3 * 5 * (1 - positioning)` times that further out; the first capital ship of a fleet
sets a line, and **every other ship is put in front of that line or behind it at even odds**, by
half its own reach and its own roll. A ship can come out nearer than 1, and is put at 1. A fleet
that joins a battle already begun starts a hundred further out. A leader of skill 5 draws his
ships up at exactly half their reach.

`CCombat::Begin` for a naval battle is `CNavalCombat::RollPositioning` (already recorded): the
two positioning rolls, the attacker's first, and both sides' positioning made again with them.

## 3. The hour

`CCombat::Tick` (`0x56EBE0`) is the hour of every kind of battle, in the order
`FINDINGS-landbattle.md`, section 3, gives it; the naval and air ticks call it first. For a
naval battle its steps are: the wars' dates; (no tactics); `duration` counted; the two dice of
the first round and the two of every round; **`ApplyCombatModifiers` for the attacker and then
the defender; `Attack` for the attacker and then the defender; `ApplyLosses` for both; the ships
under 0.1 strength taken out of both; from the fourth round `HasLost` of the attacker and then
the defender**; and the round's count.

### What the hour makes of a ship: `CNavalCombatant::ApplyCombatModifiers`

`0x566480`, slot 19, in `FINDINGS-combatmods.md`, section 6, and read again against the
decompiled C: it agrees. Each thing is put on the **ship**, and a ship's attack product
(`CSubUnit +0x50`) is the only one of the two that anything in the fight reads. One thing that
section leaves out, about the submarines' surprise:

    surprised = the flag byte of BM_SURPRISE_BONUS (CCombatant +0x25) as the LAST round left it
    for each fleet of the side:
        this is the attacker, the round is the first (CCombat +0x1C < 1), the fleet has a
        submarine, and flag == 0:
            Random() % 100 < NAVAL_COMBAT_SUB_SURPRISE_CHANCE / 1000  -> surprised = true
        surprised, and CCombat +0x1C < NAVAL_COMBAT_SUB_SURPRISE_ROUNDS / 1000:
            every submarine of the fleet gets +NAVAL_COMBAT_SUB_SURPRISE_BONUS on its attack,
            and the flag byte is set again

So **the surprise is rolled in the first round only, once for each attacking fleet with a
submarine until one roll succeeds, and then holds for the first rounds** (three in the base game)
because each round finds the last round's flag; and a later fleet of the same side shares an
earlier one's success.

### One side's shooting: `CNavalCombatant::Attack`

`0x567930`, slot 15, `(other)`, `ret 4`. Now read from end to end.

**The head**: `AccumulateLeaderCombatHours`; `NAVAL_DOCTRINE_INCREASE` of a practical to every
country on the side (`0x565430`); the positioning creep of `FINDINGS-navaldetection.md`; then

    theirPenalty = other is a naval side (slot 7) ? NavalStackingPositionPenalty(other.units) : 0
    ourSpeed     = AverageMaxSpeedOfEngaged(this.units)                       0x5D6AC0

`0x5D6AC0` (the list in EAX, the out in ESI): over the fleets of the list whose `disengage`
(`CUnit +0xA8`) is under 1, the sum of every ship's `max_speed` over the count of those ships.

**Each fleet, each ship, in order**:

    target = null
    sea_attack == 0 or organisation < 1:   the remembered target is cleared
    otherwise: target = CSubUnit::PickTarget(ship, this, other)              section 4
    with a target:
        a = sea_attack
        the battle's byte +0x2B is set and this side attacks:  a = convoy_attack
        the target is a submarine:
            a = sub_attack * (1000 + GetTraitEffect(fleet, 11 submarine_attack)) / 1000
        n = a * the ship's attack product / 1000
        shots = n / 1000,  one more where Random() % 100 < (n % 1000) * 100 / 1000
        for each shot:
            the target's strength less its notes is under 0          -> no more shots
            orgDie = NAVAL_COMBAT_ORG_DICE_SIZE / 1000 + whole(5.0 * theirPenalty),
                     one more where Random() % 100 < the fraction of that, as a percentage
            strDie = NAVAL_COMBAT_STR_DICE_SIZE / 1000 + whole(3.0 * theirPenalty),
                     one more likewise                               (a draw each)
            one draw that nothing reads
            Random() % 100 < min(CHANCE_TO_AVOID_HIT_AT_NO_DEF, 99) -> a miss
            organisation = (Random() % orgDie + 1) * 1000
            strength     = (Random() % strDie + 1) * 1000
            Random() % 100 < NAVAL_COMBAT_CRITICAL_HIT_DAMAGE_CHANCE / 1000:
                strength = strength * NAVAL_COMBAT_CRITICAL_HIT_DAMAGE_MUL / 1000
            the target's hull > 0:  both * 1000 / hull
            strength     = strength * NAVAL_COMBAT_STR_DAMAGE_MODIFIER / 1000
            organisation = organisation * NAVAL_COMBAT_ORG_DAMAGE_MODIFIER / 1000
            the battle's byte +0x2B is set and this side defends:
                strength = strength * 1000 / 80000;  organisation = organisation * 2
            both are added to the target's notes (+0xA8, +0xAC)
            the target's strength less its notes is now under 0:
                the target's `sunk_by` is this ship
                the target is a pride: this ship gains 5 experience, to 100 at most, and the
                on-actions on_enemy_pride_sunk and on_our_pride_sunk are fired

    then, whether or not it shot, the ship moves:
        v = max_speed * 1000 / 2000
        its fleet is not disengaging (CUnit +0xA8 < 1) and it has organisation above 0:
            its fleet has a carrier (a ship with carrier_size above 0):        v = 0
            it has a target:   its distance <= CSubUnit::FiringRange / 2  ->   v = 0
                               v = v * 1000 / 2000
            it has none:       v = v * 2000 / 1000
            theirSpeed = AverageMaxSpeedOfEngaged(other.units)
            theirSpeed > ourSpeed:  v += theirSpeed - ourSpeed
            distance -= v
        otherwise:
            v = v * 1000 / the ship's own hull
            distance += v
        distance = max(distance, 1000)

**The dice are the game's**: every `Random()` above is a draw of the one generator (inlined at
most of the sites), and none comes from a side's own stream as on land. A shot costs five draws
when it misses and eight when it lands.

**What the constants are**: `5.0` and `3.0` are the floats 5000.5 at `0x160A9F8` and 3000.5 at
`0x160A948`, floored; the percentage is the float 100000.5 at `0x160A718`.
`FINDINGS-combatmods.md` has "the same term" for both dice. It is five times the enemy's
penalty on the organisation die and three times on the strength die.

**So a ship closes at a quarter of its speed while it has a target and is further out than half
its reach, at its whole speed while it has none**, not at all in a fleet with a carrier, and
faster by whatever the enemy's ships are faster on average. A ship with no `sea_attack` - a
transport - never has a target and so runs in at its whole speed until it is at 1. A ship of a
disengaging fleet, or one with no organisation left, opens the distance by half its speed over
its hull.

**The tail**, for each fleet of the side:

    its `disengage` (+0xA8) is above 0:  one more
    WantsToDisengage(fleet) and it has somewhere to go (CUnit +0xAC is a province id):
        a path there (CPathFind::Find), SetUnitPath(fleet, path, true), both dates to null
        and - unless the battle's byte +0x2B is set - a null order

### Settling: `CCombatant::ApplyLosses`

`0x565FD0`, already recorded. Its naval arm (kind 2, and kind 6 on the side that is a naval
target), read through:

    for each ship of each fleet:
        strength less notes under 0:  destroyed[type] += 1000,  losses += 1000
        otherwise:                    damage[type] += CSubUnit::SettleDamage(ship)
    CUnit::SettleCombatDamage for each fleet

A ship's notes are taken off it **whole** - `CSubUnit::SettleDamage` divides them by a hundred
only for a brigade or a wing - and neither more than the ship has. `SettleCombatDamage` settles
the ships that were only counted, which leaves them at no strength; for a fleet it does nothing
else, but for **a transport's damage**: the notes its transports took this round are shared out
over the brigades of the land units the fleet carries - organisation by `notes * 1000 / (brigades
* 2000)`, strength by `notes * 1000 / (brigades * 1000)` each - and settled on them at once.

Then `CUnitList::RemoveSpentSubUnits(side, true)`: **every ship under 0.1 strength**
(`Define100`) is taken out of its fleet, out of both sides' target lists, onto its side's list
of sunk ships, and reported to the game state (`0x684CE0`); and `CheckTransportOverload` sees to
what the fleet can no longer carry.

## 4. Who a ship shoots at: `CSubUnit::PickTarget`

`0x5675D0`; the ship in ECX, `(its own side, the other side)`, `ret 8`. The record has its head.
The whole:

    p = (definition.positioning + side.positioning) * 100
        * (1000 + country.CTechnologyStatus +0x70) / 1000 / 1000        a whole number
    pNight = the battle's province is at night ? p / 2 : p

    the ship remembers a target (+0xB8/+0xBC, a persistent id) and it still exists:
        Random() % 50 > p + 10                          -> forget it
        at night: Random() % 100 > 80                   -> forget it     (drawn only at night)
        still remembered:
            it is another country's ship: its fleet is on the other side -> keep it;
                                          it is not                      -> forget it
            it is one of its own country's:  Random() % 100 < 75         -> forget it
                                             otherwise                   -> keep it
    with none remembered:
        Random() % 80 > pNight:                         the ship has lost the enemy
            c = 7, less the skill of the side's highest ranked leader
            Random() % 100 < c:
                n = the count of ships on its own side
                r = Random() % n
                going through its own side's ships but itself, in order, with r counted down:
                the target is the last ship gone through once r is under 1
            otherwise: no target
        otherwise:
            CNavalCombatant::CollectTargets(other, side, ship)           below
            q = CSubUnit::TargetingSkill(ship) / 10                      a whole number
            r = Random() % 100
            no ship was collected                       -> no target
            r > q:   targets[Random() % count]
            r <= q:  CNavalCombatant::PickBestTarget(side)
    the target's id is remembered (+0xB8/+0xBC, and the byte +0xC0 set), or cleared

- **A ship keeps its target from hour to hour** while its roll holds, and loses it more easily at
  night. `p + 10` against a roll of fifty: with a positioning of 0.4 the target is always kept.
- **Friendly fire is in the game.** A ship whose side's positioning fails it - `Random() % 80`
  over `p`, so always possible under a positioning of 0.8 - has seven chances in a hundred, one
  fewer for each point of its admiral's skill, of taking one of its own side for the enemy. The
  walk that picks which one does not stop at the ship it drew: **it ends on the last ship of the
  side's last fleet**, whatever was drawn, unless the draw was past every ship. And such a target
  is kept, a quarter of the time each hour. Checked against the instructions on 2026-10-10, the
  decompiled C having been the first reading: the inner loop is `0x567846`..`0x56785A` - `cmp
  edi, ecx; je` skips the shooter, `test edx, edx; jg` skips the store while the count is above
  nothing, `mov [esp+0x10], ecx` is the store, `dec edx` follows, and **the only ways out are the
  ends of the two lists** (`0x56785A`, `0x56785E`); nothing leaves after the store. With `n` ships
  on the side the draw is `0..n-1` over `n-1` other ships, so one draw in `n` stores nothing and
  every other ends on the last.
- **`CSubUnit::TargetingSkill`** (`0x5AC3C0`; the ship in EDI, the out in ESI): ten times the
  skill of the leader of the ship's fleet, plus `CTechnologyStatus +0x74` of the ship's owner
  for a ship, or `+0xC8` and `+0xCC` for a wing. So the chance of the best target instead of a
  random one is the admiral's skill and a tenth of a technology figure, in a hundred - and one
  in a hundred with neither, since the roll may equal it.

**`CNavalCombatant::CollectTargets`** (`0x567250`; the side whose ships are looked at in ECX,
`(the side whose list is filled, the ship)`): the list is emptied, and each ship of each fleet
of the looked-at side is added, up to 1024, where

    its distance + the shooter's distance <= the shooter's reach
        reach = definition.firing_distance
                * (1000 + precipitation * FIRINGRANGEMODIFIER / 1000) / 1000
    a submarine with no target of its own remembered:
        Random() % 100 <= the shooter's sub_detection * 5 / 1000, or it is not seen
    its strength less its notes is not under 0
    it is no submarine, or the shooter has a sub_attack

So **range is the two ships' distances added together** against the shooter's own reach, a
submarine that is not itself shooting at anything is found by five times the shooter's
`sub_detection` in a hundred, and a ship with no `sub_attack` cannot shoot at one at all.

**`CNavalCombatant::PickBestTarget`** (`0x567510`, `(side)`, `ret 4`): of the collected ships,
the one with the largest

    priority * 1000 * ((its most strength - its strength) * 10 / 1000 + 250) / 1000

the first of equals; `priority` is the unit file's key (`CSubUnitDefinition +0x194`), the most
strength slot 12 with both flags false, and 250 the floor of the float 250.5 (`0x1A881A4`). The
most valuable ship, and of two alike the more damaged.

## 5. The end

**Has a side lost** - `CCombatant::HasLost` (slot 16, already recorded), asked from the fourth
round: its withdrawal byte, or under 0.010 strength in all, or - where the battle's slot 12 says
so - `IsSpent`. For a naval side `IsSpent` is the base (`0x5656D0`): the figure of slot 22
(`0x565670`, which is `CUnitList::AverageOrganisation`, `0x5D6710`) under 1000. That figure is
**the average organisation of the side's ships**, each fleet's own average weighted by its count
of ships. The loser's fleets fall back (`CUnit::RetreatFromCombat`, below) and the battle is
over.

**May a unit leave** - `CCombat` slot 12, which `CUnit::MayLeaveCombats` asks before
`SetUnitPath` gives a fighting unit a path. The base is the shared `true`. **`CNavalCombat` has
its own, `0x564010`: `duration > 3`.** A fleet cannot be taken out of a sea battle in its first
four hours; `SetUnitPath` does nothing until then.

**Leaving by order** - `CMoveCommand::RouteUnit` (`0x5D88C0`, already recorded), for a fleet in a
battle that does not yet want to disengage:

    CUnit +0xAC = the province it was sent to
    its `disengage` is 0:  it becomes 1
    and nothing else - no path, no order

So **the order is kept and the count started**. The tail of the side's `Attack` adds one each
hour, and when the count reaches `5 * (1 + disengage_timer)` (`WantsToDisengage`) the fleet is
given its path - four hours after the order, with no trait. `SetUnitPath` then takes it out of
its battles and marks it retreating where the other side still has somebody. From the first
hour of the count its ships open the distance instead of closing it.

**Breaking off** - `CNavalCombat::Tick` (`0x57BA00`), after the shared hour, from the third:

    Random() % 1000 < (duration * 1000 + 10000 + (night ? 11000 : 1000)
                       + wind speed * NAVALWINDSPEEDMODIFIER / 1000
                       + precipitation * NAVALRAINMODIFIER / 1000) / 1000:
        each fleet of the attacker, then of the defender:
            disengage = 1 where it was 0, else one more
            WantsToDisengage(fleet)  ->  the battle is over

The answer is 1 the moment one fleet has had enough: the listing ends each loop in a jump to the
`mov al, 1` at `0x57BA19`. So the first roll that passes sets every fleet counting, the hours add
to the count through `Attack`, and **the battle ends at the next roll that passes once a fleet has
counted to five** - nobody is beaten, nobody falls back, and `CCombat::Finish` lets everyone go.
With the base figures the first roll passes after about a day by day and sooner by night.

**Falling back** - `CUnit::RetreatFromCombat` (`0x565760`) for a fleet: it is taken out of the
battle; with nowhere to go, or no way there, it is removed from the game; a fleet still in
another battle that does not yet want to disengage only has `+0xAC` set to where it would go, its
count started and `retreat` set; otherwise it is given the path and marked retreating. **It keeps
its order**, and its progress is not set: both of those are for land units alone.

`CUnit::FindRetreatProvince` (`0x5C5D50`) for a fleet, over the provinces next to its own that
it may stand in (slot 34) by an edge that is not closed to it:

    a land province: it is the port the fleet's sea province belongs to (its sea_province_id is
                     the fleet's province) and CUnit::CanRetreatToProvince agrees  -> 10000
    a sea province:  1000, and 2000 for each of ITS neighbours, by an edge that is not
                     impassable, that is land with a naval base of a whole level or more that
                     the fleet may stand in
    the first found is kept, and replaced only by one worth more

**A beaten fleet runs for the port it lies off**, and with none for the water with the most
friendly harbours around it.

**The wait** - `CUnit::ShowCombatOver` (`0x5C7E10`, already recorded) gives a fleet let out of
a battle that was no bombing `8 + (Random() & 7)` hours at `CNavy +0x2F8`, which
`ShouldStartNavalCombat` will not start a battle under and `CUnit::EnterProvince` clears. Both
ways out of a battle reach it: `CCombat::UnitLeaves` and the end of the battle
(`CCombatant::DetachAllUnits`).

`CNavalCombat::End` (slot 14, `0x57B850`, shared with `CNavalBombing`) is a strategic warfare
call and then `CCombat::End`. `0x57B570`, slot 7 of the land, naval and air battles alike, takes
the battle off every unit of both sides and frees its two billboards.

`CNavy`'s slot 31 calls `0x5C7C70` for a fleet in a battle: for each of its carriers, each air
unit aboard under order `0x56C` that is in the fleet's province, in no battle, going nowhere and
able to fight is sent to `CheckForCombat` there. That is how a carrier's aircraft come into a
sea battle; the air side of it was not read.

## 6. The byte `CCombat +0x2B`

Read in five places now, and never yet seen written:

- `CCombat::Tick` does not ask `HasLost` of either side while it is set;
- an attacking ship shoots with `convoy_attack` in place of `sea_attack`;
- a defending ship's hit does an eightieth of its strength damage and twice its organisation
  damage;
- a fleet that disengages keeps its order;
- the history keeps it.

A battle between a raider and what escorts a convoy fits all five; **`inferred`**, and its
writer is the reading the convoy raid needs.

## Corrections to the record

- **`CNavalCombat::Tick`'s entry says it "never reaches CCombatant slot 19"** and makes no
  virtual call. Its first instruction after the prologue is `call CCombat::Tick`, which calls
  slot 19 of both sides; `FINDINGS-airnaval.md` had corrected the write-up and the entry kept
  the old text.
- **`CUnit::MayLeaveCombats`'s entry says slot 12 is "the shared `true` in every combat
  class".** `CNavalCombat` holds `0x564010` there, `duration > 3`.
- **`FINDINGS-combatmods.md`, section 9**: the two dice are widened by different amounts, five
  and three times the enemy's penalty; and what it gives as "a hit roll ... not followed" is
  one unread draw and the plain roll against `CHANCE_TO_AVOID_HIT_AT_NO_DEF`.
- **`CNavalCombatant::CollectTargets`** is called on the side whose ships are collected, and
  fills the list of the side handed to it.

## What was not read

- **The writer of `CCombat +0x2B`**, and with it how a convoy is attacked.
- **`CUnit +0xA0`**, the count that keeps a unit out of `StartCombat` and `JoinCombatInProvince`
  and runs down by one an hour; and **`CUnit +0x95`**, still.
- **The radar part of the intelligence level** beyond its shape, and the reference at a patrol
  order's `+0x48`.
- **`CTechnologyStatus +0x74`** and `+0xC8`/`+0xCC`: technology figures named here by their one
  use.
- **`0x684CE0`**, which is told of each ship removed, and **`0x464EE0`**, the strategic warfare
  call at a naval battle's end.
- **`0x5D6540`**, which `ApplyLosses` calls for each type in a battle that is not naval.
- **A fleet with no ship left**: `RemoveSpentSubUnits` empties it, and what then removes the
  fleet was not followed.
- **A carrier's aircraft** in the battle, and the whole of a naval bombing.
