# What two countries hold of each other: relation, threat and neutrality

Read out of the executable on 2026-10-12 for OpenHOI3's diplomacy, in three briefs of one wave
(`WAVE.md`, the diplomatic state wave): **A**, the start of a game; **B**, threat; **C**, relation and
neutrality over time. The screen that shows them is `FINDINGS-diplomacyview.md`. Addresses are
**virtual**, based `0x400000`, unless a line says rva.

What was known before and is not redone here: the offer as an object (`FINDINGS-diploaction.md`), the
Lua bridge (`FINDINGS-diplomacy.md`), the country's daily pass call by call with neutrality's clamp,
drift and `EffectiveNeutrality` (`FINDINGS-politics.md`, section 4), and the `relation`, `threat` and
`neutrality` effects and conditions (`FINDINGS-effectrun.md`, `FINDINGS-triggerleaves.md`,
`FINDINGS-numtriggers.md`).

## A. The start of a game

**In one line**: every country holds one `CDiplomacyStatus` towards every country in the database;
the history sets relations **one side only**; a new game then asks **the mod's Lua**,
`AI_GenerateNonHistoricalRelation` in `script/ai_country.lua`, for every pair whose relation is still
exactly 0, again one side only; and the **month pass** that runs before the first hour makes each pair
the same on both sides, from the side of the country that comes first. That reproduces the start save
**7,878 pairs of 7,878**. Threat starts at 0 everywhere and nothing at the start touches it or
neutrality but the history.

### A.1 In order

1. **Construction.** When the country database is built (`InitCountryPerCountryArrays`, rva
   `0xD4C50`), each country gets one `CDiplomacyStatus` of `0x80` bytes per database country, REB and
   itself included - `diplomacy[id]` is the status towards that id. Relation, threat and the rest are
   0, the three dates null. A session reset runs `CDiplomacyStatus::Reset` on every one.
2. **The history**, replayed up to the start date before the session. `ReadDiplomaticHistoryFile`
   (rva `0x1F1F40`) turns each block of a `history/diplomacy` file into an entry at its `start_date`,
   and an inverse entry at its `end_date` where one is given:
   - **`relation`**: `countries[first]->diplomacy[second] = clamp(value)`, **that side only**
     (`CRelationChange::Apply`, rva `0x1F2CA0`). GER->ITA 200 and SOV->CHI 100; ITA->GER and CHI->SOV
     stay 0. An end date sets that side to 0, not back to what it was.
   - **`alliance`, `guarantee`, `nap`, `vassal`, `casus_belli`**: the relation object is handed to the
     game state and its `Activate` hangs it on both sides (`+0x14`, `+0x1C`, `+0x28`, `+0x18`; a vassal
     also sets `isSubject` and `Overlord`). **No relation, threat or neutrality is written.** The
     in-game tails of `CAlliance` and `CNap` `Activate` do not run, `in_game` being clear.
   - **A war** (`history/wars`): `CWar::AddAttacker` and `AddDefender` with both flags false - none of
     `ChangeRelation`'s callers is on this path. `UpdateAtWarAndEnemies` stamps `last_war` (`+0x54`)
     with the tick, and `CWarGoal::AddToWar` sets `next_wargoal_date` (ITA->ETH 1936.2.1, the month's
     cooldown).
   - **A country's history**: `neutrality = N` goes through `CCountry::SetNeutrality` (rva `0xFC0E0`),
     floored at 0 and not capped; **`threat = N` writes `CCountry +0x20`**, a country-level figure whose
     reader was not found, and never a pair (`CThreatChange::Apply`, rva `0x1F1B20`) - no country has one
     in force on 1936.1.1; a faction join is `CFaction::AddCountry(..., 0, 0)`, so no war sweep and no
     relation change.
3. **`CInGameIdler::Enter`**, for each country: `UpdateAtWarAndEnemies`; **EffectiveNeutrality =
   clamp(neutrality - diplomacy[highest_threat]->threat, 0, 100000)**, neutrality itself not clamped
   here; and for a new game `LoadOobFile` and then `SetUpCountryForNewGame` (rva `0xD6230`). That runs
   the history's decisions first - a decision's `relation` effect would set both sides before the Lua
   and so keep it out; the base game has none - and then:
   - a `last_war` later than now is made null;
   - **the relations**, skipped for REB and for a country owning no province. For each database
     country B in order, REB and itself included: `v = 25` where B is REB or owns no province, else
     `v = AI_GenerateNonHistoricalRelation(country, B)` in whole points; **where `diplomacy[B]->relation
     == 0` it becomes `clamp(v x 1000)`, this side only**, and `changed` (`+0x59`) is set.
   - **the first spy allocation**, in the same loop: for each existing B but REB,
     `espionage (+0x1160)[B].+0 = clamp(1000 x score, 0, 10000)`, where score = [v < -100] + [v < 0] +
     neighbour + capitals on one continent + 2 x [both in real, different factions] + [ruling ideology
     differs] + 2 x war - 2 x alliance + 3 x [B is itself], halved toward zero for a country that is not
     a major (`CCountry::IsMajor`, rva `0xF8AB0`, not read). Germany's row in the save agrees except its
     own entry for the seven majors, 5 where this gives 4 - **unexplained**.
4. **Day one, the filling of supply, day two**: of diplomacy only the country's daily pass - the
   neutrality clamp to [0, 100], the drift by `NEUTRALITY_CHANGE`, EffectiveNeutrality. A scan of every
   store to `+0x38` (below) finds no relation writer on the daily path.
5. **The month pass** - `RunMonthlyPass`, then `CCountry::UpdateMonthly` for every country from index
   1, **those that do not exist included**. For each country C and each country B that owns a
   province: `v = C->B + MonthlyRelationDrift(C, B) x 1000 / 2000`, and **C->B = B->C = clamp(v)**. This
   is what makes the matrix symmetric, from the side of the country first in the order, and it adds the
   drift - about the whole of `MonthlyRelationDrift` per month for a pair, over its two visits (section
   C has the drift itself). The fractions never reach a save, which truncates: ITA-ETH is -125.100 in
   memory at the start and written -125.
6. **One hour**, and the first screen.

### A.2 The Lua

`script/ai_country.lua`, the same in the base game and BlackICE but for whitespace:

    desired = 25
    an alliance: +125, and +75 more if both are at war
    a war: -200
    a truce: -100
    the same government: +10
    the same faction: +50, else -25

**Every country in no faction points at one shared null faction**, so two such countries are "the same
faction". So: two unaligned countries 75, with the same government 85; a country with itself 25 + 10 +
50 = 85; a faction member and anybody outside it 0, or 10 with the same government; an alliance 200
(JAP-MAN 210, clamped); a war -125 (ITA-ETH: 25 - 200 + 50). **A guarantee does nothing to the start
relation** - the 10s that looked like ENG's guarantees are a member and a non-member of one government.
The countries in a faction on 1936.1.1 are eleven: GER; ENG, FRA, IRQ, OMN, YEM, BHU, NEP; SOV, MON,
TAN.

### A.3 Checked against the start save

A rebuild of the rule gives **7,878 of 7,878** pairs of `Germany1936_01_01_00.hoi3`. The controls:
leaving out the month pass gets exactly ITA->GER and CHI->SOV wrong; leaving out "only where 0" gets
those two and GER->ITA and SOV->CHI wrong; treating two unaligned countries as different factions gets
4,489 wrong. Threat is 0.000 in all 7,878 (the key does carry values: the 20 April save has 632 that
are not). Neutrality equals the history's for 100 countries of 100 with one; REB's 50.000 is the
constructor's default (`[0x170CDE8]` = 50000). EffectiveNeutrality equals neutrality everywhere.

### A.4 A pair in the save

`CDiplomacyStatus::SaveContents` (rva `0x648430`, slot 2) and `LoadKey` (rva `0x648190`):

| key | field | written |
| --- | --- | --- |
| `value` | `+0x38` | relation / 1000 **truncated toward zero**, `%d`; read back as whole points through the clamp in `SetValue` (rva `0x648160`), so a save and a load drop the fraction |
| `threat` | `+0x5C` | three decimals, exact |
| `military_access=yes` | `+0x4C` | only where set |
| `last_send_diplomat` | `+0x50` | only where not null - the field the record calls `next_offer_allowed` |
| `next_wargoal_date` | `+0x7C` | only where not null |
| `last_war` | `+0x54` | only where not null |
| `occupation_policy` | `+0x10` | only where not the default policy |
| `debtaction_action` | `+0x78` allowDebts | only where true - the game's spelling |
| `debt`, `dailyrepay` | `+0x70`, `+0x74` | only where not zero |

`CCountry::SaveContents` writes a pair block **for every country owning a province, itself included**:
78 in each of the 101 country blocks, none for REB and none for the 23 that do not exist. Their pairs
are kept in memory and not saved, and are 0 after a load.

### A.5 What looks wrong and is what the bytes do

- `relation.txt` sets one side, and survives only because GER and SOV come before ITA and CHI in the
  country order: the other way round, the month pass would copy the Lua's value over it.
- "Only where exactly 0" overwrites a history relation of 0.
- Until the month pass every existing country holds 25 towards REB and towards every country that does
  not exist; the month pass sets the latter to 0 (inferred; no save can show it). **It sets REB's to 0
  too** - this line said it left REB, and that rested on REB being the vector's index 0, which the month
  skips: index 0 is the `---` placeholder country (`FINDINGS-effectrun.md`, "country 0"), so REB's own
  `UpdateMonthly` runs, finds a drift of 0 towards everyone (no war, no neighbour, no province), and
  copies its own side - 0, `SetUpCountryForNewGame` having skipped it - over every country's 25 towards
  it. Inferred the same way; corrected 2026-10-12 while building it.
- The month pass runs for countries that do not exist.
- `CNAPChange`'s slot 6 is `CAllianceChange`'s body and answers the `alliance` token; what follows from
  it was not followed.

### A.6 Evidence

- **Every store to `+0x38`.** All 669 `[reg+0xE28]` sites in `.text` decoded `0x100` bytes on; the
  positive control finds both of `ChangeRelation`'s stores. Found: `SetUpCountryForNewGame` `0x4D7316`
  (`imul eax, 0x3E8`, clamped between `[0x1710C38]` and `[0x1710C34]`, `mov [ecx+0x38], eax`, with
  `mov byte [ecx+0x59], 1` before it); `UpdateMonthly` `0x4DCCF0` and `0x4DCD27`; `MakeVassal`;
  `CCreateVassalCommand`; `CRelationChange::Apply` `0x5F2D0B`. The constructor (`0xA47E28`), `Reset`
  (`0xA47F51`) and `SetValue` (`0xA4817F`/`0xA48186`) lie outside the window and were found from the
  vftable and from callers.
- **The Lua name** is the string `AI_GenerateNonHistoricalRelation` at `0x15C0F10`, pushed by
  `PrepareLuaCall_AI_GenerateNonHistoricalRelation` (`0x5100D0`).
- **The drift's constants** are `.rdata` floats 250.5, -99.5, 50.5, 80.5 and 25.5, each through
  `floorf` (`MonthlyRelationDrift`, rva `0xE78D0`).
- **The order of a new game**: `SetUpCountryForNewGame` at `0x65B4F2`, before the first day at
  `0x65CB2E` (`FINDINGS-supplypass.md`, section 7).

### A.7 Not read

The spy self-entry's extra point; what reads `CCountry +0x20`; the diplomatic content of
`RunHourlyPass`; the tail of `InitCountryPerCountryArrays`; the luabind call and its cleanup
(`0x50D2F0`, `0x50D260`); `CCountry::IsMajor`; the drift's two display callers (`0x4E7518`,
`0x6C3CD5`), which are the screen's.

## B. Threat

**In one line**: `countries[a]->diplomacy[b]->threat` (`CDiplomacyStatus +0x5C`) is how much threat a
feels from b, in thousandths, never below 0 and never capped, the two directions independent; it is
raised through two spreaders by war, mobilisation, a broken pact, an embargo, a war goal enforced, a
battle or a strategic bombing started, convoys sunk, spies and **every unit put on the map**; and
**nothing decays it** - it falls only by a negative `threat` effect, demobilising, lifting an embargo
or an annexation.

### B.1 The two spreaders

Every division below is a 64-bit truncation toward zero.

**`SpreadThreatToAll(amount, scale, feared)`** (rva `0xF4E80`) reaches every country of the game
state, the dead included:

    base  = amount * (1000 + feared.THREAT_IMPACT) / 1000
    if feared is in no real faction:  base = base * 1000 / 2000
    floor = base * 50 / 1000                                   ; base/20, floor(50.5f)
    for every country c but feared:
        reach = min(28 * c.provinces, 4000)
        d     = distance between the two acting capitals
        f     = reach ? max(1000 - d*1000/reach, 0) : 1001     ; 1001 for a country with no province
        f     = 1000 where c is on feared's neighbour list
        t     = base * f / 1000
        g     = c's faction's ideology group, else the group nearest c's alignment (first of equals)
        t     = t * ((distance from feared's alignment to g) / FACTION_THREAT_DIST)^2 x1000 / 1000   ; no cap
        t     = t * (1000 - c.THREAT_RESISTANCE) / 1000
        t     = max(t, floor)
        c.threat[feared] += scale * t / 1000, floored at 0

**`SpreadThreat(feared, amount, scale, origin)`** (rva `0xF50A0`) walks the province graph from
`origin`; base and floor as above:

    every province: dist = 99999;  every country: mark = 0
    feared.mark = 1;  origin.dist = 0;  FIFO queue = [origin]
    pop cur; for each neighbour nb:
        d = cur.dist + nb.size_class (1-4)
        if nb.dist <= d: next
        a = max(base - 130*d, floor)                           ; floor(130.49998f), 130 a size unit
        c = nb.controller
        if c is unmarked and a > 0 and c is not 0:
            a = a * (1000 - c.THREAT_RESISTANCE) / 1000
            c.threat[feared] += (a * scale / 1000) * ideologyFactor(feared, c's group) / 1000, floored at 0
            c.mark = 1
        nb.dist = d;  if a > 0: push nb

`ideologyFactor` is `CAlignment::GetFactionThreatDistanceFactor` (rva `0xC4D70`): (distance /
`FACTION_THREAT_DIST`)^2 x 1000, uncapped. **This corrects the record**, which had the 50.5 as a scale
on the base rather than the floor and `0xC4D70` as a cost per edge; the fall-off is linear in
`CProvinceTemplate +0x24`.

### B.2 What looks wrong and is what the bytes do

- A controller is charged once, at the first of its provinces the FIFO walk relaxes - the fewest steps,
  not necessarily the shortest distance.
- The floor keeps every amount at least base/20, so the walk covers the whole connected map, sea
  included; a sea province is walked through and charged to nobody. `origin` itself is never charged.
- A country with `THREAT_RESISTANCE` of 1000 or more stops the walk at its first province.
- `SpreadThreat` takes the floor before resistance, `SpreadThreatToAll` after.
- The ideology factor is 0 for a country of feared's own group, and can pass 1000 for a far one.
- The dead get the most from `SpreadThreatToAll`: their reach is 0 and f 1001.

### B.3 Every source

**Through `SpreadThreat`:**

| at | when | amount | feared | origin | scale |
| --- | --- | --- | --- | --- | --- |
| `CDeclareWarAction::Apply` `0xA128FC` | a declaration of war | `WARDEC_BELIGERENCY` (33) | the actor | the recipient's acting capital | +1000 |
| `CNapAction::Apply` `0xA2BFFB` | a pact broken | `LEAVE_NAP_THREAT_COST` (5) | **the recipient** | the recipient's capital (`GetCapitalLocation`) | +1000 |
| `CEmbargoAction::Apply` `0xA2F099` / `0xA2F57B` | an embargo imposed / lifted | `EMBARGO_THREAT_COST` (1) | **the recipient** | its acting capital | +1000 / -1000 |
| `CToggleMobilizationCommand::Execute` `0x551565` | mobilising / demobilising | `MOBILIZE_THREAT_IMPACT` (2.5) | the country | its own acting capital | +1000 / -1000 |
| `CWarGoal::Enforce` `0x47B280` | a capitulation only | the casus belli type's `threat` (conquer and puppet 5, vichy 10, barbarossa 20), where above 0 | the goal's actor, the winner | the winner's acting capital | +1000 |
| `CInGameIdler::Enter` `0x65B64C` | a new game | the history threat, `CCountry +0x20`, where not 0 | the country | its own acting capital | +1000 |

For a pact and an embargo the influence and relation are charged to the actor, and the threat lands on
the recipient - the tags traced to `this+8` and `this+0x10` at each call.

**Through `SpreadThreatToAll`:**

| at | amount | feared | when |
| --- | --- | --- | --- |
| `CCombatManager::StartCombat` `0x430937` | `LAND`/`NAVAL`/`AIR_COMBAT_THREAT_IMPACT` (0.01) by kind | the owner of the unit starting it | only when a new combat of that kind is made, and only where the province's controller is 0 or its owner the attacker's enemy |
| `CCombatManager::StartBombing` `0x4304DA` | `BOMBING_THREAT_IMPACT` (0.01) | the bomber's owner | strategic bombing (`0x6F9`) only |
| `CConvoy::LoseShips` `0x4C5AA1` | (transports + escorts lost) x `THREAT_FROM_CONVOYS_MODIFIER` (0.005) | the raider | |
| `CSpyPresence::RunDailyMissions` `0x53027C` | `SPY_THREAT_INCREASE_ACTION` x level / 1000 x the mission's share / 1000 / 10 | **the target** | daily |
| `CUnitDeployment::DeployAt` `0x57DE3B` | `REGULAR_CONSTRUCTION_THREAT_IMPACT` (0.1); a reserve's first regiment x (1000 + `RESERVES_PENALTY_SIZE`) / 1000 / 5 | the owner | every unit put on the map |
| `CThreatEffect::Execute` | `who = all`, value x 1000 | the scope | the sign carried by the scale |

**Written directly**: `threat = { who = TAG value = N }` adds N to TAG's threat from the scope, with no
modifier; **an annexation** sets both directions between the annexed and every other country down by
9999.000, floored at 0, then resets the other's status towards the annexed; the constructor and
`Reset` set it to 0; `CDiplomacyStatus::LoadKey` reads it. A peace, a white peace or leaving a war
touches nothing; only a surrender enforces war goals and their threat.

### B.4 No decay

A sweep of all of `.text` (2,755,112 instructions, in chunks split at runs of two or more `int3`) finds,
among the chunks that mention `0xE28`, these stores to a status's `+0x5C` and no others:
`SpreadThreatToAll` `0x4F505C`, `SpreadThreat` `0x4F551B`, `CThreatEffect` `0x9B4EAF`, `AnnexCountry`
`0x4E8D0E`/`0x4E8D28` - the three known writers among them, which is the positive control. The status
held as `this`: its vftable's six slots (only `LoadKey` writes it), the constructor, `Reset`, every
`+0x5C` store in `0xA40000`-`0xA56000`. `RunCountryDailyPass` and `CCountry::UpdateMonthly` write no
`+0x5C` and call neither spreader. **Not covered**: a helper elsewhere handed a status pointer.

The saves of one game agree: 1 February to 1 March 1936, 145 pairs unchanged and none lower; 1 to 20
April, 521 unchanged and none lower; 4 to 8 January, 100 unchanged. Falls seen *between* files
(every ITA pair down about 92% between 8 January and 1 February; FRA's 3.0 from GER gone by 1 April)
are between playthroughs: the 20 April save and the 1 April `olderautosave` were written on 8 October,
the January saves and the February and March autosaves on 9 October.

The 20 April save fits the account: its 632 pairs fall on eight feared countries - ENG (ALB 0.015 is
three deployments at the floor, base 100 and floor 5; the dead VIC 0.297 is 3 x 99), USA (in no
faction, so base 50 and floor 2: AFG 0.002, the dead ISR 0.049), ETH (base 10 halved to 5, so a floor
of 0 and only the dead and the near at 0.001 to 0.002, 21 countries - ETH starting land battles
against ITA), BEL (11 at 0.001, one combat's spread; its cause not found). TFH's history `threat`
entries begin in 1938.

### B.5 The most-threatening country (`CCountry +0x11D8` tag, `+0x11DC` id)

Written by `CCountry::RebuildNeighbours`: reset to `---`/0, then the database walked in order. **Who
may be it**: not itself, not id 0, not REB, owning a province, with no `alliance` (`+0x14`) and no
`dependency` (`+0x18`) on the pair, and not in its faction where that is a real one; a guarantee does
not exclude. **The rule**: `if best < 0 or threat > best: take`, best starting at -1000.000 - so the
first who may be it is taken even at threat 0, and of equals the earliest stays. Against the saves: on
1 January, threat 0 everywhere, 99 countries hold GER and Germany holds ENG; the rule gives 100 of 100
on 1 January and on 20 April, and on 1 March 95 of 100, the five misses (IRQ, OMN, YEM, BHU, NEP) each
with a vassal or alliance block with ENG - the exclusion at work when left out of the check. REB holds
`---`, why not checked. **Rebuilt** daily in `ProcessCountriesPreDailyUpdate` for countries whose byte
`+0x44` is set, and from 65 call sites after diplomatic actions and effects; whether that is before
`RunCountryDailyPass`, which reads it for EffectiveNeutrality, was not checked.

### B.6 The head of the daily pass, the month, `is_threatend`

`0x4DD8D0` is `CCountry::EnsureCapital`: it moves a lost capital to the owned province with the
highest `manpower / 1000 + 1`, times 100 for a core. `0x4D8070` is `UpdateTriggeredModifiers` and
`0x4DDD80` `CCountry::RebuildStaticModifiers`, both already recorded - `FINDINGS-politics.md` section
4's "unread" is stale; neither writes threat, and the second reads effective neutrality. The month
touches no threat. `is_threatend` walks `CCountry +0xFD8`, which `RebuildNeighbours` fills
(`0x4E2C8D`-`0x4E2CE6`, kept unique by the byte at `+0xF58`).

### B.7 Not read

The capitulation `0x4E9220` (two `ret 8`, trap 3 owed); the mobilisation toggle `0x507A20` and
`0x4E39C0`; `CWarGoal::Enforce`'s option arms and its `+0x280` block; `CThreatChange` slot 2
(`0x5F1BB0`); who else reads `CCountry +0x20`. `CMapProvince +0x10`, recorded as
`weather_pressure_distance`, is a general walk-distance scratch slot that `SpreadThreat` shares.

## C. Relation and neutrality over time

**In one line**: relation moves through `CCountry::ChangeRelation`'s 24 call sites, three inlined copies,
the history and the new game's one-sided writes (A), and **a monthly drift the record did not have**;
neutrality moves by the daily `NEUTRALITY_CHANGE`, a month's war exhaustion paid back once at peace,
the `neutrality` effect and a console command. The two `NEUT_*` defines move no neutrality: they shift
the ceiling under which war may be declared. **No war, peace, puppet or annexation writes neutrality.**

### C.1 How relation is changed

`ChangeRelation(A, B, delta)` (rva `0xE65C0`) adds delta to A's view of B, clamps it to
-200.000..200.000 and writes **that one result to both sides** - so a pair whose sides differ is made
equal from A's. It has 24 callers, not the 18 "all in slot 7" the record had, and is not the only writer
of `+0x38` (A.6).

| when | between | change | define (`diplomacy` block offset) | at |
| --- | --- | --- | --- | --- |
| an alliance accepted | actor-recipient | +15 | `ALLIANCE_RELATION_CHANGE` (+0x40) | `0xA19617` |
| an alliance declined | | **0** | - | |
| an alliance left (value 0) | actor-recipient | -50, **then -30** | `ALLIANCE_REJECT_RELATION_CHANGE` (+0x44), then a constant -30000 | `0xA19B73`, `0xA19F12` |
| a guarantee given | | 0 | - | |
| a guarantee revoked | actor-recipient | -20 | `REVOKE_GUARANTEE_RELATION_CHANGE` (+0x70) | `0xA1CBEA` |
| military access accepted | actor-recipient | +10 | `MILACC_ACCEPT_RELATION_CHANGE` (+0x64) | `0xA239D0` |
| military access declined | actor-recipient | -10, **only where either country is played** | `MILACC_DECLINE_RELATION_CHANGE` (+0x68) | `0xA23E8F` |
| military access cancelled | actor-recipient | -10 | **`MILACC_DECLINE`** (+0x68); `MILACC_CANCEL` (+0x6C) has no reader | `0xA24295` |
| offered access accepted | actor-recipient | +10 | a constant | `0xA25FBF` |
| offered access declined | | 0 | - | |
| offered access withdrawn | actor-recipient | -20, only where either is played | a constant | `0xA26879` |
| a call to arms declined | ally-caller | -50 | `ALLIANCE_REJECT` (+0x44); the caller also gets a casus belli | `0xA296B5` |
| a call to arms accepted | enemy-ally | -100 | -`WARDEC_WAR_DIPLOMACY_HIT` (+0x4) | `0xA289C6` |
| a NAP accepted | actor-recipient | +50 | `NAP_RELATION_CHANGE` (+0x4C) | `0xA2BB00` |
| a NAP declined | actor-recipient | -20 | `NAP_REJECT_RELATION_CHANGE` (+0x58) | `0xA2C433` |
| a NAP broken (value 0) | actor-recipient | -30 | `LEAVE_NAP_RELATION_CHANGE` (**+0x50**; the record had +0x4C) | `0xA2C031` |
| an embargo imposed | actor-recipient | -30 | `EMBARGO_RELATION_CHANGE` (+0x80) | `0xA2EFF8` |
| an embargo lifted | | 0 | - | |
| a trade accepted | actor-recipient | +15 | `TRADE_RELATION_CHANGES` (+0x9C) | `0xA35F15` |
| a trade declined | | 0 | - | |
| a trade cancelled | actor-recipient | -15 | -`TRADE_CANCEL_RELATION_COST` (+0xA8) | `0xA36A13` |
| a war declared, new or widened | actor-recipient | -100 | -`WARDEC_WAR_DIPLOMACY_HIT` | `0xA12849` |
| a faction joined that brings its wars | the joiner and each new enemy | -100 | -`WARDEC_WAR_DIPLOMACY_HIT` | `0x4F62CE`, `0x4F6342` |
| a government in exile liberated, the two in different factions | liberator-liberated | +500, so to 200 | a constant | `0x54CE38` |
| `release_vassal` | releaser-released | +500 | a constant | `0x9AF101` |
| a vassal made | overlord-vassal | +500 | a constant, `ChangeRelation` inlined | `MakeVassal` `0x4DA37D`; `CCreateVassalCommand` `0x54C219` |
| **a land battle concluded** | each winning country friendly to the province's owner, and not it, where the owner is an enemy of the losers' first country | +5 | a constant | `0x574D74`, in `CCombat::Conclude` (rva `0x174580`) |
| the `relation` effect | `who` and the scope's country | the script's value | - | `0x9A71DC` |
| the month | every pair | below | constants | `UpdateMonthly` `0x4DCCF0`/`0x4DCD27` |

`type` is 0 PROPOSE, 1 DECLINE, 2 ACCEPT and `value` the bool at `+0x24` (`FINDINGS-diploaction.md`).
**A proposal changes no relation in any of the nine.**

### C.2 The month's drift

`CCountry::UpdateMonthly` (rva `0xDC840`), for every country, for every country i owning a province:
`d = MonthlyRelationDrift(this, i)` (rva `0xE78D0`), and `trunc(d x 1000 / 2000)` - half of d - added
to both sides of the pair (A.1, 5). The drift in thousandths, in this order:

1. +250 where the pair has a dependency (an assignment, but the first);
2. -100 where they are at war;
3. +50 where they are neighbours and neither is at war;
4. +80 where there is a guarantee;
5. +25 where there is military access;
6. where the relation is above 100 and the drift so far positive, it becomes 0;
7. then, where neither country is played and one is the other's overlord, `max(d + 2000, 2000)`.

The figures are floats folded by `floor(x x 1000 + 0.5)` - 0.25, -0.1, 0.05, 0.08, 0.025 - and no define
feeds them. A pair is visited twice a month, once from each side, so a month moves it by about d, less
the truncation: military access alone gives 12 + 12 = 24. The terms that are one country's (being
neighbours, access) can differ between the two visits.

**What the April save shows**: its relations moved in multiples of 15 - trades and alliances, +15
accepted and -15 for a trade cancelled - but for two of +325, ITA-ETH from -125 to 200, the vassal's
+500. **`last_send_diplomat` is `next_offer_allowed`**, the date seven days ahead every proposal sets;
**there is no "send a diplomat" or improve-relations action in the image**, and
`RELATION_INFLUENCE_COST` has no reader (by the shape a block's defines are loaded in; the same scan
found the defines of all 24 call sites).

**An influence or an alignment costs no relation.** `DAYS_OF_INFLUENCE_RELATION_CHANGE` and
`DAYS_OF_ALIGN_RELATION_CHANGE` are **durations in days**: how long the `align_towards_<faction>`
modifier lasts, the timeout in `CInfluence::IsOver` and `CAlign::IsOver` (rvas `0x64AC30`,
`0x64B2F0`), and the TIME line of their messages ("UNLIMITED" where negative). At -1 the modifier is
permanent and the influence never times out. Nothing daily touches relation.

### C.3 Neutrality

`CCountry +0xA8C`, thousandths. **It starts** at `g_CountryDefaultNeutrality`, 50.000 (`CCountry::CCountry`
and `CCountry_Reset`), and the history sets it (A). **Each day**, in order: clamped to [0, 100000];
effective neutrality made; later in the pass `ChangeNeutrality(+NEUTRALITY_CHANGE)` with no history
entry. In Their Finest Hour only two things carry `neutrality_change`: the static modifier
`spy_lower_neutrality`, -0.003 a day (how espionage puts it on was not read), and the event modifier
`prepare_for_war`, -0.2 a day. Laws and ideologies do not: their `neutrality =` lines are triggers, and
a faction's `neutrality = 25` is `CFaction +0xB0`. The other modifier, `NEUTRALITY` (id 83, `+0x298`),
has no reader; the same scan finds exactly one of id 78, the daily drift.

**Each month** (`CCountry::UpdateMonthly`, every country but REB): `war_exhaustion += mod[WAR_EXHAUSTION]`,
floored at 0 - the `war` static modifier gives 0.041 a month; capped at `mod[MAX_WAR_EXHAUSTION]` (100);
and **where the country is not at war (`+0xACC`) and the balance is positive,
`ChangeNeutrality(+war_exhaustion)` and war exhaustion back to 0**. REB's is zeroed every month. So the
first month of peace pays back all that was banked at once - about 0.041 a month of war. BiceLib
patches this out (and see C.6).

**Otherwise**: the `neutrality` effect (`ChangeNeutrality` with a history entry), the console's
`noneutrality` (rva `0x3D200`, -1000000 for the player), and the custom game's two writers, outside the
one start. `ChangeNeutrality` floors at 0 and **has no ceiling**; only the next day caps it at 100.

**Effective neutrality** = clamp(neutrality - threat from the most-threatening country, 0, 100000),
written by the daily pass, by `ChangeNeutrality`, as the in-game screen is entered for every country
(`0x65B3E3`) and by the custom game's two writers.

**The ceiling for war**: a country may declare war while its effective neutrality is at most
`GetMaxNeutralityForWarWith(target)` (rva `0x105D00`; equal is allowed; refused with `DIP_WAR_NEUTR`, at
`0xA1596E` and `0xA16109`):

1. the larger of the two threats between the pair, both directions, floored at 0;
2. + `NEUT_REDUCTION_AT_CLAIMS` (20) where the `aquire_all_cores` casus belli may be used;
3. - `NEUT_INCREASE_DIFF_CONTINENT` (10) where the capitals are on different continents and the two
   are not neighbours;
4. + the declarer's faction's neutrality (`CFaction +0xB0`; the Axis 25);
5. floored at 0.

These are the only readers of the two `NEUT_*` defines. Its tooltip is `BuildWarNeutralityTooltip`
(rva `0x105F20`, `FINDINGS-diplomacyview.md` E.7).

### C.4 What looks wrong and is what the bytes do

- Declining an alliance costs nothing; `ALLIANCE_REJECT_RELATION_CHANGE` is charged for *leaving* one,
  with a hidden -30 after it.
- `MILACC_CANCEL_RELATION_CHANGE` is dead - cancelling uses the decline's; offered access uses a
  constant +10 and -20.
- Declining access and withdrawing an offer of it cost relation only where a person is involved.
- Revoking a guarantee *adds* `REVOKE_GUARANTEE_INFLUENCE_COST` to the revoker's influence
  (`add [eax+0xA88]` at `0xA1CC19`); declining military access also gives back its cost.
- Both `DAYS_OF_*_RELATION_CHANGE` are durations; `CAlign::Activate` and `CCountry_StopAlign` use the
  INFLUENCE one, and the influence's messages date their end with the ALIGN one.
- The drift never pulls a pair above 100, but a war goes on pulling it down; an overlord and subject
  nobody plays gain at least +2 a month all the way to 200.
- The save truncates relation to whole points, so a fraction of drift is lost across a save and a load
  (inferred from the format).

### C.5 Not read

The claims test inside the war ceiling (`0x47BC60`, `0x4797C0`); how `spy_lower_neutrality` is put on;
event or script writers of `war_exhaustion`; the agreements beyond their relation arms; the drift's two
display callers.

### C.6 The install's executable is patched

**The `hoi3_tfh.exe` in the install, which `roots.py` finds and `image.py` reads, is not the shipped
build.** Set against `Downloads\hoi3_tfh_imperium.exe` (the same size, dated 2013), it differs in 17
bytes in two runs: VA `0x4DCBD4`-`0x4DCC1E`, the three `Patch_WarExhaustionNeutralityReset_*` sites,
and `0x4DE3EE`, `Patch_MinisterTechDecay` - BiceLib's patches, written to disk. The Downloads copy has
the compiler's own bytes there. So a static reading of those sites from the install sees the mod's
behaviour, not the original's; C.3's war exhaustion was read from the other copy. `TRAPS.md` has it.
