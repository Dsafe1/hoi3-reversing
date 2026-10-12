# The grammar of triggers

*Read on 2026-10-12, statically, for OpenHOI3's loading of event and decision script. Addresses
are VAs where a listing is quoted and rvas where the record is cited: `CTrigger::LoadKey` is VA
`0x9C8D10`, rva `0x5C8D10`. Nothing was tried in a running game. `FINDINGS-script.md` has the
keyword table, `FINDINGS-numtriggers.md` the five shared slot-7 bases and the scales,
`FINDINGS-scopetriggers.md` the scopes; this is the parse side those three left open. The
effects are `FINDINGS-effectgrammar.md` and the containers `FINDINGS-eventfiles.md`.*

**Synopsis.** What `CTrigger::LoadKey` does with a key that is not one of its keywords, what the
fifteen unrecorded slot-7 `LoadArgument` bodies accept, what the block triggers' own keys take,
and which keywords take a block - all settled. **Seven corrections:** the default branch is not
"a province id, an ideology, then the technology database" but six database lookups (government
position, building, technology, unit type, law group, combined-arms group), then an ideology, a
region and a scope - and **an unknown key is reported only directly inside a block the engine
made; inside a block the script wrote it is queued and silently dropped**;
`CAllOrganisationPopularityTrigger` has two keys, scaled x1000 at load, and its `Evaluate` is an
**OR**; `has_cb` and `relation` have two keys each, not four (`definitions.py` read the
`this`/`from` value compares as keys); `owned_by` has three argument forms, not four;
`controlled_by`'s owner arm is the keyword `owner` and its flag is `+0x48`, not `+0x44`;
`CSubUnitDataBase +0x0` is the vector of unit groups, not a `CList`; and the switch has **153**
keywords - `FINDINGS-script.md`'s table lacks `port`.

The function and field tables are in `fragments/merged/trigger-grammar.json`: 47 address entries
(36 new, 11 revised, each revision checked off the bytes before the merge), 25 struct declarations
and 44 field records. Five helper lookups are shared with the effect reading and carry its names
(`StringHashFind_At18`/`_At1C`/`_At44`/`_At20C`, `FindFactionByName`).

## 1. In one paragraph

`CTrigger::LoadKey` runs once per `key = value` in a trigger block. A key whose token is one of
the 153 keywords builds that keyword's class: a **leaf** takes its value through slot 7,
`LoadArgument`; a **block** reads `{ ... }` through slot 3, `CPersistent::Load`, which calls the
block's own slot 4 per pair - this same `LoadKey` for every `CAndTrigger` heir. Any other key goes,
in order, to: six databases by name; an ideology name (a `{ organisation popularity }` block); a
region name (a scope block); a trial scope - a country tag, a province number, or `this` `from`
`owner` `controller` `ally` `capital_scope` `sea_zone` `local_enemy` `overlord`; and failing all
four, `Unknown trigger-type`, **but only when the enclosing block was not written by the script**.

Keywords and `yes`/`this`/`from` are case-insensitive. Every name looked up as text - buildings,
technologies, laws, regions, modifiers and the rest - is **case-sensitive**. Country tags are a
case of their own (section 4).

## 2. The switch, its two tails, and the default arm

`python scripts/switchmap.py 0x9C8D10` prints 153 cases; every one ends in one of two tails.

**The leaf tail (`0x9C8E04`)** appends the new trigger to the parent's child list (a 16-byte
node), copies the value `CToken` at `parse +0x228` (0x104 bytes, `{token; text[0x100]}`) and calls
slot 7 with it. **The value's token class is never tested.**

**The block tail (`0x9C914E`; `and` joins at `0x9C9184`)** appends the child, sets its
`is_script_block` (`+0x3C`) to 1, and calls `child->Load(parse)` (slot 3, rva `0x67C050`): peek;
stop on `}` (token 4) or the end (0x13); `ParseReadKeyValue`; slot 4 with the key token; then one
token is consumed, the `}`. **Nothing checks that the value was `{`.** So, `confirmed`:

- **a block keyword written with a scalar** (`and = yes`) reads its parent's following pairs as its
  own children, eats the parent's `}`, and the parent goes on reading its grandparent's keys;
- **a leaf written with a block** (`money = { ... }`) takes `{` as its value, its contents are
  read as the parent's own, and its `}` ends the parent early;
- **a missing `=`**: `ParseReadKeyValue` (rva `0x67ACB0`) reads a key and one token, and reads a
  value only if that token is `=`; otherwise the token is lost and the value keeps the previous
  pair's.

**The default arm (`0x9CAD19`..`0x9CAFA2`)**, read again for this file:

1. The key text (`parse +0x24`) and the value text (`parse +0x22C`) are copied, and
   `Trigger_LoadDatabaseKey(this, &key, &value, this->is_script_block)` is called (rva
   `0x5CFD60`, `ret 0x10`, section 3) - the flag is the **parent's** `+0x3C`
   (`movzx eax, byte [ebx+0x3c]` at `0x9CAD4F`). Its answer is kept at `[esp+0xC]`; above 0, done.
2. An ideology: `GetIdeologies()` and `CNameDataBase::GetByName(key)`; a hit builds
   `CAllOrganisationPopularityTrigger(ideology)` (0x4C bytes) through the block tail -
   `social_conservative = { organisation = 60 popularity = 60 }`, base game `Coups.txt` line 11.
3. A region: `StringHashFind_At18(CMap +0x2A50, key)` builds a `CRegionScopeTrigger`, block tail.
4. The trial scope (rva `0x5CAE62`) builds a `CContextTrigger`, block tail.
5. All failed: `0x9CAEE3 cmp [esp+0xC], 0; jne end`. So `Unknown trigger-type <key> in <file>`
   (`trigger.cpp` line 0x10B, channel 0x10004) is written **only when step 1 answered 0**; a -1
   (deferred) is silence.

`Trigger_LoadDatabaseKey` tries the key text in this order. A hit allocates 0x48 bytes, appends the
leaf and calls slot 7 with a **`CToken` whose class is forced to 0xF**:

| # | lookup | builds | value |
| --- | --- | --- | --- |
| 1 | a government position (`CNameDataBase::GetByName`) | `CGovernmentPositionTrigger` | a minister's id, `atoi` - `minister_of_security = 11189` |
| 2 | a building (`StringHashFind_At1C`) | `CBuildingTrigger` | a level, `atoi` |
| 3 | a technology (`GetTechnologyDataBase() +0x10`, `StringHashFind_At20C`) | `CTechnologyTrigger` | a level, `atoi` |
| 4 | a unit type (`CSubUnitDataBase +0x10`) | `CSubUnitTrigger` | a count, `atoi` |
| 5 | a law group (`GetLawDataBase() +0xC`, `StringHashFind_At18`) | `CLawTrigger` | **a law's name** - `conscription_law = service_by_requirement` |
| 6 | a combined-arms group (`CSubUnitDataBase_FindUnitGroup`, index above 0) | `CCombinedArmsTrigger` | a bool, but see below |

Because the token is forced to 0xF, `THIS`/`FROM` never set the flags through these arms (`atoi`
of "this" is 0), which leaves `CSubUnitTrigger::Evaluate`'s THIS/FROM branch unreachable from
script (`inferred`: this is its only constructor's caller). And `CCombinedArmsTrigger` holds
`CBoolTrigger`'s slot 7, `token == yes`, so **its value is always false**, and its `Evaluate` then
means "this side has no unit of the group": `armor_unit_type = yes` tests for *no* armour. No event,
decision or `common` file of either tree uses a `*_unit_type` key outside `combined_arms.txt`.

## 3. Deferred keys: `is_script_block` (`+0x3C`) and `+0x1C`/`+0x2C`

Where all six lookups miss, `Trigger_LoadDatabaseKey` looks at its `defer` argument, the parent's
`+0x3C`. Set, it pushes the key onto `parent +0x1C` and the value onto `parent +0x2C`
(`StringVector_PushBack`, rva `0x17620`, vector in EDI) and answers -1; clear, it answers 0. The two
are the 0x10-byte `std::vector<std::string>`s the constructor's `__ehvec_ctor` builds, which closes
`FINDINGS-scopetriggers.md` section 16.

Who sets `+0x3C`: the block tail and the default arm's tail (rva `0x5C915B`, `0x5CAE09`), and
`CTechnology`'s constructor (rva `0x1339A0`, unrecorded), by its stores, on its embedded triggers at
`+0x248` (`allow`) and `+0x2D8` (rva `0x133B39`/`0x133B32`). Every constructor clears it.

**An event's own `trigger` block does not set it.** `CEvent::LoadKey`'s arm (`0x9BF47B`) calls the
embedded `CAndTrigger` at `+0x30` through its slot 3 directly - `mov edx,[esi+0x30]; mov
edx,[edx+0xc]; lea ecx,[esi+0x30]; push parse; call edx` - with no store to `+0x3C`. So an unknown
key **at the top of an event's `trigger`** is reported, and one inside any `and`/`or`/`not`/scope/
region/ideology block under it is not. The decision's `potential` and `allow` and an MTTH
`modifier` were not looked at in the same way (`inferred` alike).

`CTrigger::ResolveDeferredKeys` (rva `0x5D0130`) recurses into the children and, where `+0x3C` is
set, replays each pair through `Trigger_LoadDatabaseKey(this, k, v, 0)`, logging `Fixed trigger
dependency for K = V` (line 365, channel 0x10002) or `Failed to post process trigger dependency
K = V` (line 363, channel 0x10004), and clears both vectors. **Its only outside caller is
`CTechnologyDataBase::LoadTechnologies`** (rva `0x14195C`), over each technology's `allow` - the
mechanism exists for one technology naming another not yet loaded.

**Positive control, from the maintainer's logs:** `Documents/Paradox Interactive/Hearts of Iron
III/logs/game.log` has 38 `[trigger.cpp:365]: Fixed trigger dependency for ...` lines under the
base game, and BlackICE 16.1's `logs/game.log` 3306 (`infantry_activation = 1`, written straight in
an `allow` in `technologies/ArtilleryTechnologies.txt` line 11); neither has a "Failed" line.

**So for events and decisions**: an unknown key directly inside an engine-made block gets the error;
one inside any script-written block is dropped silently, and nothing ever replays it.

## 4. Tokens and case

The text tokenizer's next-token (rva `0x66A2E0`, `TextTokenizer_NextToken`, recorded by the effect
reading): `=` 1, `"` 2, `{` 3, `}` 4, `(` 5, `)` 6, `,` 8; `#`, `!` and `;` each start a comment to
the end of the line (class 9); each of `!"#(),;={}` ends a word. The character classes are a
byte-indexed jump table, read as a table. A **quoted string** is class 0xF and never looked up as a
keyword - `"yes"` is not `yes`, `"THIS"` not `this`. A **bare word starting with a digit or `-`**
is a number, 0xC, with no lookup. **Any other bare word** is looked up in `g_dynamic_tokens`
(VA `0x1710DF0`) through `TernarySearchTreeFind`, which lower-cases the query, as
`TernarySearchTreeInsert` lower-cases what it stores; a hit is that token, a miss 0xC if every
character is a digit, `.` or `-`, else 0xF.

Hence keywords are case-insensitive - the base game writes `OR` 401 times, `NOT` 156 and `AND` 3 -
and so are `yes`/`no`, `this`, `from`, `owner` and the other value keywords. Names registered as
dynamic tokens (buildings, technologies, laws, positions, ideologies, traits, resources, unit types)
also *tokenise* case-insensitively, but the trigger loader looks them up by their **text**, exactly:
`Industry = 3` misses. Every lookup in sections 2 and 5 is byte-exact - the engine hash
`(h+c)*61` and `MemCompareRegs`, or a byte compare.

**Country tags are the exception** (`CCountryDataBase::GetTag`, rva `0x118480`): the bucket is
`(c0 + c1 + c2) mod 64` on the raw characters, then **three** characters are compared with
`_strnicmp` (VA `0xB97CF0`, the CRT body). Flipping a letter's case moves its code by 32, so only
an even number of flips keeps the bucket: `GER`, `Ger` and `gEr` resolve, and `gER`, `GEr` and `ger`
do not. (The agent's report gave `gER` as resolving, which its own rule contradicts - one flip;
corrected 2026-10-12, arithmetic only, not tried.) And **any text whose first
three characters are a tag is that tag**: `war_with = GERMANY` is GER, and `GERMANY = { }` a GER
scope. An unknown tag gives `---`, with no message. `confirmed`.

## 5. The fifteen slot-7 bodies

All `void __thiscall X::LoadArgument(X*, CToken value)`, `ret 0x104`, each the only holder of its
body.

| keyword | accepts | looked up in | stored | special words | on a miss |
| --- | --- | --- | --- | --- | --- |
| `active_mission` | a mission's name | the `CMission` database, `StringHashFind` | `+0x40` | - | null, silent |
| `continent` | a continent's name | `CMap_FindContinent` (`CMap +0x2A30`) | `+0x40` | `this` `+0x18`, `from` `+0x19` | null, silent |
| `controlled_by` | a tag | `GetTag` | `+0x40`/`+0x44` | `this`, `from`, **`owner` sets `+0x48`** | `---` |
| `date` | `y.m.d[.h]` | `Date_SetFromString` | `+0x40` | - | unchecked `sscanf`: a date before the epoch |
| `exists` | `yes` / `no` / a tag | `GetTag` | `+0x40` bool, `+0x44` tag | `yes`, `no`; no this/from | `---` |
| `faction` | a faction's name | `FindFactionByName` | `+0x40` | `this` only; `from` is looked up as a name | `CNullFaction` |
| `government` | a government's name | `StringHashFind_At44` | `+0x40` | - | null, silent |
| `has_building` | a building | `StringHashFind_At1C` | `+0x40` | - | null, silent |
| `has_country_modifier` | a modifier | `CTraitDataBase_Find` on `g_static_modifiers` | `+0x40` | - | null, and `Unknown modifier '..' referred to in has_country_modifier trigger.` |
| `has_province_modifier` | a modifier | the same | `+0x40` | - | null, and the same message, its own line |
| `ideology_group` | a group's name | `IdeologyGroup_FindByName` | `+0x40` | - | null, silent |
| *a law group* | a law's name | `GetByName` on the law database | `+0x44` | - | `CNullLaw`, and `Unknown law '..' in trigger.`; **the law is not checked against the group** |
| `region` | a region's name | `StringHashFind_At18` on `CMap +0x2A50` | `+0x40` | - | null, silent |
| `strategic_resource` | a resource | `GetByName` on `g_strategic_resources` | `+0x40` | `none` is `CNullStrategicResource` | **null**, over the null resource |
| `trait` | a trait | `CTraitDataBase_Find` | `+0x40` | - | `CNullTrait`, silent |

`controlled_by = owner` asks "not occupied", which closes `FINDINGS-scopetriggers.md` section 10
item 1. **`owned_by` has no such arm**: `COwnedByTrigger` is 0x48 bytes and its `Evaluate` has three
exits returning true, none reading `+0x48`; so `owned_by = owner` is a tag lookup giving `---`, and
holds only for an unowned province. That event modifiers resolve through `g_static_modifiers` is
`inferred`: the base game's `has_country_modifier = us_new_deal` names an `event_modifiers.txt`
entry, and the loader filling the table was not read.

## 6. The block triggers' own keys

None of these goes back to `CTrigger::LoadKey` but `CMTTHModifier`.

| keyword | keys | values | other keys |
| --- | --- | --- | --- |
| *an ideology* (`CAllOrganisationPopularityTrigger`) | `organisation`, `popularity` | `atoi` x1000 **at load**, `+0x44`/`+0x48` | ignored |
| `has_cb` | `type`, `actor` | `type` raw text, not looked up; `actor` a tag / `this` / `from` | ignored |
| `relation` | `who`, `value` | `who` a tag / `this` / `from`; `value` `atoi` (x1000 in `Evaluate`) | ignored |
| `threat` | `which`, `value` | `which` through slot 7 (`TriggerLoadCountryTagArgument`); `value` `atoi` (x1000 in `Evaluate`) | ignored |
| `spy_mission_count` | `type`, `value` | `type` `SpyMissionTypeFromName`, 0..8, unknown 0 (counter-espionage); `value` thousandths | `ReportUnknownKey` (queued, not logged) |
| `check_variable` | `which`, `value` | `which` raw text; `value` thousandths | ignored |
| an MTTH's `modifier` (`CMTTHModifier`) | `factor` | thousandths | **every other key is a condition**, through `CTrigger::LoadKey` |

**The ideology block is an OR**: `CAllOrganisationPopularityTrigger::Evaluate` (rva `0x5FA6B0`) is
`organisation[i] >= organisation OR popularity[i] >= popularity`. Both default to 0, so a block
naming one of them is always true; `Coups.txt`'s `{ organisation = 60 popularity = 60 }` holds when
either reaches 60. The same function confirms `+0x10C4` as organisation and `+0x10FC` as
popularity, open in `FINDINGS-numtriggers.md` section 8.

## 7. Which keywords take a block

**A block of child triggers**, through `CTrigger::LoadKey`: `and`, `or`, `not`, `any_core`,
`any_neighbor_country`, `any_neighbor_province`, `any_owned_province`, `enemy`, every region's
name, and every context form - a tag, a province number, the nine scope words.

**A block with keys of its own**: `check_variable`, `has_cb`, `relation`, `threat`,
`spy_mission_count`, every ideology's name, and an MTTH's `modifier` (its key and conditions).

None of them accepts a scalar: one is read as the start of a block (section 2).

**`has_hostile_spy_mission` is an anomaly.** Its case (`0x9CAAA1`) ends in the block tail although
its class is a `CBoolTrigger`: slot 7 is never called, the constructor (rva `0x5CF4E0`) never writes
`+0x40`, so `Evaluate` compares against an uninitialised heap byte; `= yes` swallows the enclosing
block, and the contents of `{ }` are loaded as children nothing evaluates. Neither tree uses it.

## 8. Every keyword

The value form is read off each case's tail and its class's slot 7, `confirmed` for every row.
**int** is `atoi`; **thousandths** keeps three decimals; **tag** is section 4; **this/from flags**
are set by token and on the classes noted ignored.

| keyword | value | notes | class |
| --- | --- | --- | --- |
| `active_mission` | a mission's name | null if unknown | `CActiveMissionTrigger` |
| `ai` | bool, `yes` only | | `CIsAiTrigger` |
| `air_battles_fought` | int, this/from flags | | `CAirBattlesFoughtTrigger` |
| `alliance_with` | tag / this / from | | `CAllianceWithTrigger` |
| `always` | bool, `yes` only | `always = no` and `= 1` are both false | `CAlwaysTrigger` |
| `and` | block of triggers | | `CAndTrigger` |
| `any_core` | block of triggers | a province scope over the coring countries | `CAnyCoreTrigger` |
| `any_neighbor_country` | block of triggers | | `CAnyNeighborCountryTrigger` |
| `any_neighbor_province` | block of triggers | owned neighbours only | `CAnyNeighborProvinceTrigger` |
| `any_owned_province` | block of triggers | | `CAnyOwnedProvinceTrigger` |
| `base_neutrality` | thousandths | | `CBaseNeutralityTrigger` |
| `blockade` | thousandths | | `CBlockadeTrigger` |
| `brigade_exist` | string | `Evaluate` not read | `CBrigadeExistsTrigger` |
| `brigade_in_combat` | string | `Evaluate` not read | `CBrigadeInCombatTrigger` |
| `can_create_vassals` | bool | | `CCanCreateVassalsTrigger` |
| `capital` | int, this/from flags | a province; the flags are ignored | `CCapitalTrigger` |
| `casus_belli` | tag / this / from | | `CCasusBelliTrigger` |
| `check_variable` | block, own keys | | `CVariableTrigger` |
| `continent` | a continent / this / from | null if unknown | `CContinentTrigger` |
| `controlled_by` | tag / this / from / `owner` | `owner` is "not occupied" | `CControlledByTrigger` |
| `controls` | int, this/from flags | a province | `CControlsTrigger` |
| `country_units_in_province` | tag / this / from | | `CCountryUnitsInProvinceTrigger` |
| `crude_oil` | thousandths | | `CCrudeOilTrigger` |
| `date` | `y.m.d[.h]` | bad text is silently before the epoch | `CDateTrigger` |
| `dissent` | thousandths | | `CDissentTrigger` |
| `empty` | bool | | `CEmptyTrigger` |
| `enemy` | block of triggers | combat scope only | `CEnemyScopeTrigger` |
| `enemy_ic_ratio` | thousandths | tests `<=` | `CEnemyIcRatioTrigger` |
| `energy` | thousandths | | `CEnergyTrigger` |
| `exists` | `yes` / `no` / tag | `exists = THIS` gives `---` | `CExistsTrigger` |
| `faction` | a faction / this | `= FROM` gives `CNullFaction` | `CFactionTrigger` |
| `faction_progress` | thousandths | | `CFactionProgressTrigger` |
| `frontage_full` | bool | | `CFrontageFullTrigger` |
| `government` | a government | null if unknown | `CGovernmentTrigger` |
| `government_in_exile` | bool | | `CIsGovernmentInExileTrigger` |
| `guarantee` | tag / this / from | | `CGuaranteeTrigger` |
| `has_armour_unit` | bool | | `CCombatHasArmourUnitTrigger` |
| `has_building` | a building | null if unknown | `CHasBuildingTrigger` |
| `has_cb` | block, own keys | | `CHasCasusBelliTrigger` |
| `has_combat_modifier` | string | | `CCombatModifierTrigger` |
| `has_combined_arms` | bool | the value is never read (`FINDINGS-battlegains.md`) | `CHasCombinedArmsBonus` |
| `has_country_flag` | string | | `CHasCountryFlagTrigger` |
| `has_country_modifier` | a modifier | logged on a miss | `CHasCountryModifierTrigger` |
| `has_empty_adjacent_province` | bool | | `CHasEmptyAdjacentProvinceTrigger` |
| `has_global_flag` | string | | `CHasGlobalFlagTrigger` |
| `has_hostile_spy_mission` | block (section 7) | the value is uninitialised | `CHasHostileSpyMissionTrigger` |
| `has_leader` | string | `Evaluate` not read | `CHasLeaderTrigger` |
| `has_province_flag` | string | | `CHasProvinceFlagTrigger` |
| `has_province_modifier` | a modifier | logged on a miss | `CHasProvinceModifierTrigger` |
| `has_removable_minister` | bool | | `CHasRemovableMinisterTrigger` |
| `has_strategic_resource` | bool | | `CHasStrategicResourceTrigger` |
| `has_wargoal` | tag / this / from | | `CHasWarGoalTrigger` |
| `ideology` | string | also looked up as an ideology, `+0x5C`, null if unknown | `CIsIdeologyEqualTrigger` |
| `ideology_group` | a group | null if unknown | `CIdeologyGroupTrigger` |
| `is_attacker` | bool | | `CIsAttackerTrigger` |
| `is_blockaded` | bool | | `CIsBlockadedTrigger` |
| `is_capital` | bool | | `CIsCapitalTrigger` |
| `is_convoy` | bool | | `CCombatIsConvoyTrigger` |
| `is_core` | a province / tag / this / from / `REB` | `FINDINGS-numtriggers.md` section 9 | `CIsCoreTrigger` |
| `is_in_any_faction` | bool | | `CIsInAnyFactionTrigger` |
| `is_mission_country` | bool | | `CIsMissionCountryTrigger` |
| `is_mission_province` | bool | | `CIsMissionProvinceTrigger` |
| `is_possible_vassal` | tag / this / from | | `CIsPossibleVassalTrigger` |
| `is_subject` | bool | | `CIsSubjectTrigger` |
| `is_threatend` | thousandths | | `CIsThreatendTrigger` |
| `is_winner` | bool | | `CCombatIsWinnerTrigger` |
| `land_battles_fought` | int, this/from flags | | `CLandBattlesFoughtTrigger` |
| `last_air_battle_loser_losses`, `last_air_battle_winner_losses`, `last_battle_loser_losses`, `last_battle_winner_losses`, `last_naval_battle_loser_losses`, `last_naval_battle_winner_losses` | int | | `CLast...Trigger` |
| `last_mission` | string | | `CLastMissionTrigger` |
| `leadership` | thousandths | | `CLeadershipTrigger` |
| `lost_IC` | thousandths | | `CLostICTrigger` |
| `lost_national` | thousandths | | `CNationalProvinceTigger` |
| `manpower` | thousandths | | `CManpowerTrigger` |
| `manpower_percentage` | thousandths | a ratio, 0..1 | `CManpowerPercentTrigger` |
| `max_manpower` | thousandths | | `CMaxManpowerTrigger` |
| `max_manpower_greater_than` | thousandths | tests current manpower | `CMaxManpowerGreaterThanTrigger` |
| `metal` | thousandths | | `CMetalTrigger` |
| `military_access` | tag / this / from | | `CGrantsMilitaryAccessTrigger` |
| `minister_alive` | int | | `CIsMinisterAliveTrigger` |
| `money` | thousandths | | `CMoneyTrigger` |
| `month` | int | | `CMonthTrigger` |
| `national_unity` | thousandths | | `CNationalUnityTrigger` |
| `nationalism` | int | x1000 in `Evaluate` | `CNationalismTrigger` |
| `naval_battles_fought` | int | | `CNavalBattlesFoughtTrigger` |
| `neighbour` | tag / this / from | | `CNeighbourTrigger` |
| `neutrality` | thousandths | effective neutrality | `CNeutralityTrigger` |
| `non_aggression_pact` | tag / this / from | | `CNonAgggressionPactTrigger` |
| `not` | block of triggers | a NOR (`FINDINGS-triggereval.md` section 5) | `CNotTrigger` |
| `num_in_faction` | int | | `CNumInFactionTrigger` |
| `num_of_allies` | int | | `CNumOfAlliesTrigger` |
| `num_of_cities` | int, this/from | honours this/from | `CNumOfCitiesTrigger` |
| `num_of_convoys` | thousandths | | `CNumOfConvoysTrigger` |
| `num_of_ports` | int | | `CNumOfPortsTrigger` |
| `num_of_revolts` | int | | `CNumOfRevoltsTrigger` |
| `num_of_vassals` | int | | `CNumOfVassalsTrigger` |
| `or` | block of triggers | | `COrTrigger` |
| `organisation` | thousandths | the ruling party's | `CRulingOrganisationTrigger` |
| `out_of_supply_days` | int | | `COutOfSupplyDaysTrigger` |
| `owned_by` | tag / this / from | no `owner` arm | `COwnedByTrigger` |
| `owns` | int | a province | `COwnsTrigger` |
| `popularity` | thousandths | the ruling party's | `CRulingPopularityTrigger` |
| `port` | bool | missing from `FINDINGS-script.md`'s table | `CPortTrigger` |
| `province_id` | int | | `CProvinceIdTrigger` |
| `province_temperature` | int | x1000 in `Evaluate` | `CCombatTemperatureTrigger` |
| `pure_revolt_risk` | int | x1000 in `Evaluate` | `CPureRevoltRiskTrigger` |
| `rare_materials` | thousandths | | `CRareMaterialsTrigger` |
| `region` | a region | membership; `<region> = { }` is the scope | `CRegionTrigger` |
| `relation` | block, own keys | | `CRelationTrigger` |
| `remove_fow` | bool | | `CFoWRemovedTrigger` |
| `reserves` | bool | | `CReservesTrigger` |
| `revolt_percentage` | thousandths | a ratio, 0..1 | `CNumOfRevoltsFractionTrigger` |
| `revolt_risk` | int | x1000 in `Evaluate` | `CRevoltRiskTrigger` |
| `skill`, `skill_advantage` | int | | `CSkillTrigger`, `CSkillAdvantageTrigger` |
| `spies` | thousandths | | `CSpyCountTrigger` |
| `spy_mission_count` | block, own keys | | `CSpyMissionCountTrigger` |
| `strat_allies_impact`, `strat_bomb_impact`, `strat_convoy_impact` | thousandths | | `CStrat...Trigger` |
| `strategic_resource` | a resource / `none` | an unknown name gives null | `CStrategicResourceTrigger` |
| `supplies` | thousandths | | `CSuppliesTrigger` |
| `surrender_progress` | thousandths | 0..100 | `CSurrenderProgressTrigger` |
| `tag` | tag / this / from | | `CTagTrigger` |
| `terrain` | string | | `CCombatTerrainTrigger` |
| `threat` | block, own keys | | `CThreatTrigger` |
| `total_amount_of_brigades`, `total_amount_of_divisions` | int | | `CAmountOf...Trigger` |
| `total_amount_of_planes`, `total_amount_of_ships`, `total_defensives`, `total_of_ours_sunk`, `total_offensives`, `total_sea_battles`, `total_sunk_by_us`, `total_we_bomb` | thousandths | | |
| `total_ic` | thousandths | the operand /1000 | `CTotalICTrigger` |
| `total_num_of_ports` | int | | `CTotalNumOfPortsTrigger` |
| `trait` | a trait | `CNullTrait` if unknown; combat scope | `CTraitTrigger` |
| `truce_with`, `undeclared_war_with`, `vassal_of`, `war_with` | tag / this / from | | |
| `unit_has_leader`, `unit_in_battle` | **ignored** | `= no` is not a negation | `CUnitHasLeaderTrigger`, `CUnitInBattleTrigger` |
| `units_in_province` | int, this/from | honours this/from | `CUnitsInProvinceTrigger` |
| `war` | bool | | `CAtWarTrigger` |
| `war_exhaustion` | thousandths | | `CWarexhaustionTrigger` |
| `year` | int | | `CYearTrigger` |

**Keys that are not keywords**, in the order tried: a government position (int, a minister's id), a
building (int), a technology (int), a unit type (int), a law group (a law's name), a combined-arms
group (bool, always stored false), an ideology (block `{ organisation popularity }`), a region
(block of triggers), a tag, a number or a scope word (block of triggers). All `confirmed`.

`THIS`/`FROM` are token compares; a quoted value is never a keyword; `TokenToFixedPoint` and `atoi`
give 0 on text that is no number, with no message.

## 9. Corrections

1. `CTrigger::LoadKey`'s comment and `FINDINGS-script.md`'s account of the default branch were
   wrong in order and in list (section 2); that file's table lacks `port`.
2. `CAllOrganisationPopularityTrigger::LoadKey` has two keys and scales at load;
   `FINDINGS-numtriggers.md` sections 1 and 4 and `CThreatTrigger::Evaluate`'s comment grouped it
   with `relation`/`threat` as "x1000 in `Evaluate`". The no-decimals conclusion stands.
3. `CHasCasusBelliTrigger::LoadKey` and `CRelationTrigger::LoadKey` have two keys each: the keys
   are `type` (0xD9) and `actor` (0x2E9), `who` (0x376) and `value` (0x2A6), and the `this` (0x377)
   and `from` (0x34F) compares are against `[parse+0x228]`, the value. **`definitions.py` reports a
   token compared against the value as a key** - the effect reading hit the same five times; fix it
   before its key lists are trusted again.
4. `COwnedByTrigger::Evaluate` has three forms; `CControlledByTrigger::Evaluate`'s flag is `+0x48`
   (`cmp byte [ecx+0x48]` at `0x9DFBCC`, set by `owner`, token 0x1EC, at `0x9DFA30`).
5. `CSubUnitDataBase +0x0` is the unit-group vector; `FINDINGS-builders.md` already said so and its
   field table disagreed (trap 14).
6. Closed: `CTrigger +0x3C` and `+0x1C` (`FINDINGS-numtriggers.md` section 9,
   `FINDINGS-scopetriggers.md` section 16); which keyword picks `controlled_by`'s fourth arm
   (`FINDINGS-scopetriggers.md` section 10.1); `+0x10C4`/`+0x10FC` as organisation and popularity.

## 10. Traps hit

- **Trap 1**, in the fragment, caught before landing: five comments carried VAs.
- **Trap 2**: `CIsIdeologyEqualTrigger`'s constructor ends `ret 0x20` at `0x9F4E7D` and two `ret 4`
  follow with no padding; an `int3`-bounded read gives it three exits.
- **Trap 14**, three ways: `FINDINGS-builders.md` against its own field table, `CThreatTrigger`'s
  comment carrying a claim about another class, and five helpers named in parallel by the effect
  reading - this one took that one's names.
- The tokenizer's character classes are a byte-indexed jump table, read as a table and not decoded
  as code.

## Not established

- Whether the decision's `potential`/`allow` and an MTTH `modifier` set `is_script_block` - an
  event's `trigger` does not (section 3).
- Whether channel 0x10004 reaches a file. All four `error.log`s on the maintainer's machine are
  empty while 0x10002 lines reach `game.log`, so `Unknown trigger-type`, `Unknown law` and
  `Unknown modifier` may never be seen (`inferred`).
- What `Evaluate` does with the null an unknown name leaves: `government`, `has_building`,
  `ideology_group`, `region`, `active_mission`, `continent`, `strategic_resource`.
- `Evaluate` of the string leaves (`has_leader`, `brigade_exist`, `brigade_in_combat`,
  `last_mission`), of `CGovernmentPositionTrigger` (`0x5F59E0`, the decompilation garbled) and of
  `CSubUnitTrigger` (`0x5DABE0`).
- Whether a dynamic token's id can equal a compiled case's (`inferred` not: they are allotted after
  the compiled table).
- The fourth dword of each deferred vector (`+0x28`, `+0x38`), and what `CTechnology`'s second
  embedded trigger at `+0x2D8` is.

**Frontier:** `0x1339A0` (`CTechnology`'s constructor), `0x5C7D10` (the `CMission` database's
setter), `0x1D62B0` (the unit counter behind `subunit`), `0x5F59E0`, `0x5DABE0`, `0x6060C0`
(`CHasHostileSpyMissionTrigger::Evaluate`), `0x669CA0` (`RegisterDynamicToken`'s ids).
