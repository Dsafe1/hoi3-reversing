# What each trigger leaf answers

*Read on 2026-10-12, statically, for OpenHOI3's evaluation of event and decision conditions, by a
wave of three. Addresses are rvas against `0x400000` unless they say VA. Every slot-6 entry was
taken from the class's own first vftable, so none rests on a backward walk (trap 2) and none is a
fold (trap 4). How a condition is answered in general - `Evaluate(this, CEventScope*)`, the
scope's layout, `MakeScope`, the four composites - is `FINDINGS-triggereval.md` sections 1 to 5;
the grammar is `FINDINGS-triggergrammar.md`; the numeric and relational leaves read before are
`FINDINGS-numtriggers.md` section 3 and `FINDINGS-scopetriggers.md` sections 4 and 5.*

**Synopsis.** Before this wave 78 of the 153 trigger keywords had no recorded `Evaluate`: 24 were
described in prose and never entered in `project.json`, 54 had never been read. All are now read
and recorded, in three sections below. **Corrections:** `faction_progress` has no division by a
thousand (`FINDINGS-numtriggers.md` said it had); `nationalism` is guarded and strict; **`<unit
type> = N` can only hold for N of nought or less**, comparing the database's definition by pointer
against each sub unit's private copy; **`month` is zero-based**; `CBuildingTrigger` reads the
**built** level, not the working one; `CCountry`'s `active_leaders` is a list and not a vector, as
its field records had it. **Found, not corrected:** `has_building` with an unknown building
dereferences null; `has_empty_adjacent_province` never reads its operand; `is_blockaded` reads a
flag refreshed only when a province's controller is set; the six `last_*_losses` are one world-wide
figure per kind of battle, never saved and never initialised.

The function and field tables are in `fragments/merged/trigger-leaves-recorded.json`,
`trigger-leaves-country.json` and `trigger-leaves-province.json`.

**Terms used throughout.** *The country* is the country database's entry for the scope's
`country_id` (`+0x14`); *the province* is the game state's entry for the scope's `province`
(`+0x28`). A province-only scope carries country `---`, id 0, and province 0 is a placeholder
record: an unguarded country leaf in a province scope reads country 0, an unguarded province leaf in
a country scope reads province 0, and neither crashes. **Int** is a `CIntTrigger` operand, `atoi`,
decimals lost; **Value** a `CValueTrigger` operand in thousandths; **/1000** a thousandths operand
divided back, truncated toward nought, so `2.9` is 2.

## 1. The numeric leaves, recorded and finished

| keyword | what it answers | scope part | missing | comparison | THIS/FROM | |
| --- | --- | --- | --- | --- | --- | --- |
| `capital` | is the **declared** capital (not the acting one) that province | country | country 0 | `==` Int | flags ignored, so `capital = THIS` tests `== 0` | confirmed |
| `faction_progress` | the country's faction's share of all provinces' victory points, a percentage in thousandths | country, its faction (never null) | country 0 | `>=` Value, **no scaling**: `= 50` is 50% | - | confirmed |
| `is_threatend` | any country on the country's neighbour list whose threat **the country feels from it** is at least N | country | country 0 | `>=` Value; an empty list is false | - | confirmed |
| `leadership` | the **province's** leadership, not the country's | province | province 0, unguarded | `>=` Value | - | confirmed |
| `month` | the month, **zero-based**: January is 0 | the clock | - | `>=` Int | - | confirmed |
| `year` | whole years since the epoch, `days / 365.0` truncated | the clock | - | `>=` Int | - | confirmed |
| `nationalism` | the province's nationalism | province | **false**, guarded | **`>`** N x 1000, strict | - | confirmed |
| `num_of_allies`, `num_of_ports`, `total_num_of_ports`, `num_of_vassals` | the country's counts of allies, own ports, all ports, vassals | country | country 0 | `>=` Int | flags ignored, so `= THIS` tests `>= 0` | confirmed |
| `num_of_cities` | the number of provinces the country **owns** - not cities | country | country 0 | `>=` Int | **honoured**: with `THIS`/`FROM` the threshold is that country's own count | confirmed |
| `num_of_convoys` | the country's convoys | country | country 0 | `>=` /1000 | - | confirmed |
| `owns` | is province N owned by the country | country, and N | country 0: "is N unowned" | `==` | flags zero the value, so it asks about province 0 | confirmed |
| `province_id` | is the scope's province N | province | 0 matches nothing | `==` Int | - | confirmed |
| `spies` | the country's spies placed **in THIS's country** - in the country itself where THIS has none | country, and THIS | country 0 | `>=` Value | THIS read implicitly | confirmed |
| `total_amount_of_divisions` | the country's land units with **more than one brigade** | country | country 0 | `>=` Int | - | confirmed |
| `total_amount_of_ships` | its ships, every ship of every fleet | country | country 0 | `>=` /1000 | - | confirmed |
| `total_amount_of_planes` | its wings | country | country 0 | `>=` /1000 | - | confirmed |
| `total_of_ours_sunk` | ships on the game's list of the sunk that were the country's | country | id 0 | `>=` /1000 | - | confirmed |
| `total_sunk_by_us` | ships on that list whose sinker still resolves to a unit of the country **now** | country | id 0 | `>=` /1000 | - | confirmed |
| `<position> = id` | a minister of that id exists, and holds that post in the country | country | country 0 | `==` | - | confirmed |
| `<unit type> = N` | **effectively nothing**: the sum it compares is always 0 (section 1.3) | country | - | `0 >= N x 1000` | dead from script | reading confirmed, conclusion inferred |
| `minister_alive` | the minister exists and the date is within his start and death dates, inclusive | **none** | - | - | - | confirmed |
| `num_in_faction` | how many members the country's faction has; 0 for none | country | country 0 | `>=` Int | - | confirmed |
| `out_of_supply_days` | the province's days out of supply | province | **false**, guarded | **`>`** Int, strict | - | confirmed |
| `units_in_province` | how many units stand in the province, anyone's | province | province 0, unguarded | `>=` Int | **honoured, and it changes the question**: with `THIS`/`FROM` it asks whether that country has any unit there, and the number is ignored | confirmed |
| `last_battle_winner_losses`, `last_battle_loser_losses`, `last_air_battle_winner_losses`, `last_air_battle_loser_losses`, `last_naval_battle_winner_losses`, `last_naval_battle_loser_losses` | **one figure for the whole world**: what the winner or loser of the last land, air or naval battle to end anywhere lost | **none** | - | **`>`** Int, strict | - | confirmed |
| `<building> = N` | the province's **built** level of it - a bombed factory answers its full level | province | province 0, unguarded | `>=` Int | - | confirmed |

### 1.1 The rows `FINDINGS-numtriggers.md` left "not read"

**`spies`** reads the country's espionage record for a target - spies present, in thousandths, the
save's `spy_allocation`, not its spy pool. The target is THIS's country where the root scope has
one, and otherwise the country itself, which is where counter-espionage lives: inside
`GER = { spies = 2 }` in an event for ENG it is Germany's spies in England. THIS is read through
`this_scope` directly, so a province-only THIS falls back to the country.

**`leadership`** is the province's own figure (`+0x324`), not the country's leadership.

**`is_threatend`** walks the country's neighbours (`+0xFD8`) and is true at the first whose
diplomatic status in the country's own array (`+0xE28[n] -> threat +0x5C`) is at least N. Only
neighbours count.

**`total_sunk_by_us` and `total_of_ours_sunk`** walk the game state's list of sunk ships (`+0x20`),
each a ship's sub unit. The first counts those whose owner (`+0x98`) is the country; the second
resolves each ship's sinker (`+0x9C`/`+0xA0`, an id pair, through `FindPersistentByIdPair`) and
counts those whose owner is the country - **a sinker that no longer resolves is not counted**, so
the figure can fall.

**`month`, `year`, `date`.** Days are `(tick - 43800000) / 24`, a year 365 days with no leap years.
`month` takes the day of the year and subtracts the month lengths (the table at VA `0x1713294`)
until it goes negative: **zero-based**. Both compare `>=`, so `month = 5` holds from June to
December, and `year = 1940 month = 5` is false again in January 1941. Neither reads the scope.
`date` is section 2's.

**The six `last_*_losses` fields** are the current game state's `+0x30` to `+0x44`, with one writer,
`CCombat::Conclude` (rva `0x174580`): a land battle writes the winner's losses to `+0x30` and the
loser's to `+0x34`, a naval one `+0x40`/`+0x44`, an air one `+0x38`/`+0x3C`. Each is the side's
losses (`CCombatant +0x84`) over 1000, plus a term when the side's byte `+0xA8` is set - total
strength x100 on land, ships at sea, wings in the air (`inferred`, from the decompilation).

### 1.2 The government position

`CGovernmentPositionTrigger::Evaluate` (`0x5F59E0`, from the listing): false where the registry is
null; false where no minister has the id (`FindPersistentById({0x26, id})`); otherwise whether the
holder of the post (`ministers +0x618[position->index]`) has that id. So `head_of_state = 23050` is
"23050 exists and holds the post". The holder is dereferenced unguarded; what an empty post holds
was not read.

### 1.3 `<unit type> = N` never holds

`CSubUnitTrigger::Evaluate` (`0x5DABE0`) is `Sum(country) >= N x 1000`, the sum
`CUnitList::SumSubUnitsOfDefinition` (`0x1D62B0`): a thousand per matching ship, a brigade's or
wing's strength otherwise, over sub units whose definition pointer (`+0x58`) **equals** the trigger's.
The trigger's is the database's template (`CSubUnitDataBase +0x10`); **every sub unit owns a copy**
(`CSubUnit::CSubUnit` allocates 0x228 bytes and stores it at `+0x58`, `SetType` assigns the template
into it, `ApplyTechnologies` rewrites it). No pointer can match, the sum is 0, and `infantry_brigade
= 1` is never true. `inferred (likely)`: one writer storing a database definition at `+0x58`, or a
live probe answering true, would overturn it. No event or decision of either tree writes the
condition. Its THIS/FROM branch is unreachable, as `FINDINGS-triggergrammar.md` section 2 said.

### 1.4 Corrections to `FINDINGS-numtriggers.md`

1. `faction_progress`: no division by 1000 - both sides are thousandths and the share is a
   percentage in thousandths. Checked: the body calls `GetVictoryPointShare` and holds neither the
   division constant `0x10624DD3` nor an `idiv`.
2. `nationalism`: guarded on the province, and strict - the "(none)" setcc is a `jle`.
3. `<unit type>`: the operand is x1000 against a sum that is always 0 (1.3).
4. Section 4's "honoured by 3": two in effect - `num_of_cities` and `units_in_province`; the third,
   `CSubUnitTrigger`'s, is dead from script, and `units_in_province`'s turns it into a presence test.
5. `spies`: the target is THIS's country, falling back to the country itself (1.1).
6. The "not read" marks on `leadership`, `is_threatend`, `total_sunk_by_us`, `total_of_ours_sunk`,
   `year`, `month`, `minister_alive`, `num_in_faction`, `out_of_supply_days`, `units_in_province`,
   the six `last_*` and the government position are closed here.
7. `CBuildingTrigger` reads `level_max (+0x20)`, the built level (`imul dword [edx+0x20]` at VA
   `0x9DC0F3`, checked) - the record's comment is revised to say so.

### 1.5 Traps hit

- **Trap 2, a new pair**: `CContextTrigger::CountEvaluation` ends `ret 0xC` at `0x5D250D` and
  `CYearTrigger::Evaluate` starts the next byte; `functionStart` answers the wrong one.
- **Trap 1** in the draft, caught before the fragment.
- **A failed positive control caught a scanner bug**: a scan for the game state's `+0x30`..`+0x44`
  first found none of the six known reads - a misaligned decode matched first.
- **Trap 14**: the three unit counters are registered for Lua and already named there.

### 1.6 Not established

- Whether anything stores a database definition in a sub unit's `+0x58` (1.3).
- What an empty cabinet post holds (1.2).
- `CCombatant +0xA8`.
- Whether a sunk ship's sinker stays registered after it is lost, and whether the sunk list is ever
  pruned.

**Frontier:** `0x1A3510` (the sub unit definition's constructor), `CCombatant +0xA8`.

## 2. Country and diplomacy leaves

*Us* is the country; *the status* is our diplomatic status with the other country,
`us->diplomacy (+0xE28)[other.id]`. **GCT** means THIS goes through `EventScope_GetCountryTag` - the
root scope's country, or the owner of its province where it has none - and FROM is the root scope's
`from_country`; **direct** means THIS is the root scope's country with no fall-back. Every body ends
`ret 4` and is its class's own slot 6.

| keyword | answers | scope part | missing | comparison | THIS/FROM | unknown name | |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ai` | nobody plays the country | country | the placeholder | `(played[id] == 0) == value` | - | - | confirmed |
| `can_create_vassals` | the country has a nation it could release (2.6) | country | the placeholder | count `> 0`; **the value is not read**, so `= no` asks the same | - | - | confirmed |
| `casus_belli` | the country could go to war on X now with some casus belli (2.4) | country | the placeholder | - | direct | `---`: id 0 | confirmed |
| `date` | the date has come, looking ahead by the scope's `days_in_month` (2.5) | the scope's `+0x34` | - | `tick + 24 x days >= date`, in hours | - | a date that does not read is before the epoch: always true | confirmed |
| `faction` | the country is in that faction | country | **false - the only leaf here that tests for country 0** | the same faction, after asking that it is a real one | THIS by GCT: THIS's faction | the null faction: false | confirmed |
| `government` | the country's government is that one | country | the placeholder | the same | - | null: false | confirmed |
| `government_in_exile` | the country is a government in exile | country | the placeholder | `== value` | - | - | confirmed |
| `guarantee` | the country guarantees X | the status | the placeholder | `CDiplomacyStatus::IsGuaranting`, inlined | GCT | id 0 | confirmed; the direction `likely`, from its Lua name |
| `has_cb` | **an enemy holds a war goal of that type against the country** (2.3) | country and its wars | the placeholder | - | `actor` direct | **logged at every evaluation**, then false | confirmed |
| `has_country_modifier` | one of the country's modifiers in force is that one | country | the placeholder | the same, **no date tested** | - | null: false | confirmed |
| `has_global_flag` | the global flag is there and set | none | - | - | - | false | confirmed |
| `has_removable_minister` | a minister holds a post that may be changed, and no post that may not | country | the placeholder | `(n > 0) == value` | - | - | confirmed |
| `has_strategic_resource` | the province's strategic resource is a real one | province | the placeholder province | **the value is not read** | - | - | confirmed |
| `has_wargoal` | at war with X, and holding a war goal whose receiver is X | the status and the war | the placeholder | - | direct | id 0 | confirmed |
| `ideology` | the ruling party is that ideology | country | the placeholder | the ideology is not null and is the same | - | false | confirmed |
| `ideology_group` | the ruling party is of that group | country | the placeholder | the group is not null, and **the ruling party is not tested for null** | - | false, tested first | confirmed |
| `is_in_any_faction` | the country is in a real faction | country | the placeholder | `== value` | - | - | confirmed |
| `is_possible_vassal` | X is a nation the country could release | country | the placeholder | X on the list | **ignored**: `THIS`/`FROM` compare `---` | id 0 | confirmed |
| `is_subject` | the country is somebody's subject | country | the placeholder | `== value` | - | - | confirmed |
| `military_access` | **the country may pass through X's land** (this said "gives X military access" until 2026-10-13) | the status | the placeholder | non-zero | GCT | id 0 | confirmed; the direction `confirmed` by the access action setting the same byte for the asker (`FINDINGS-agreements.md`, C.4) |
| `minister_alive` | section 1 | | | | | | |
| `non_aggression_pact` | a pact between the country and X | the status | the placeholder | non-zero | GCT | id 0 | confirmed |
| `num_in_faction` | section 1; `THIS`/`FROM` store 0, so always true | | | | | | |
| `relation` | the country's relation with X is at least N | the status | the placeholder | `>= N x 1000` (relations are thousandths, -200 to 200) | direct, **falling back to the controller** of the root scope's province (THIS) or of `from_province` (FROM) | `---`: the status with country 0 | confirmed |
| `spy_mission_count` | the country's spies on mission T **in THIS's country** are at least N | country and THIS | the placeholder | `allocation x mission[T] / 1000 >= value` | THIS always, implicitly | type 0 | confirmed; the mission array `inferred` |
| `strategic_resource` | the province's strategic resource is that one | province | the placeholder province | the same | - | **null: always false** | confirmed |
| `truce_with` | the country and X are in truce (2.6) | the status | the placeholder | - | GCT | id 0 | confirmed |
| `undeclared_war_with` | an undeclared war between them | the status | the placeholder | non-zero | GCT | id 0 | confirmed |
| `vassal_of` | the country is a subject and X its overlord | country | the placeholder | - | GCT | id 0 | confirmed |
| `war` | the country is at war with anybody | country | the placeholder | `== value` | - | - | confirmed |
| `war_with` | `CCountry::IsEnemyTag`: false for itself; at war with X; or either is `REB` | country and the status | the placeholder | - | GCT | id 0 | confirmed - so **`war_with = REB` holds for any country but REB** |

### 2.1 A missing part of the scope is a placeholder, not an answer

Only `faction` tests for country 0. Every other country leaf reads country 0, the `---` placeholder -
which matters, because a province's number, `capital_scope` and `sea_zone` set the country to `---`:
**`123 = { war = yes }` asks about the placeholder, not about the province's owner.** The province
leaves read province 0 the same way; its strategic resource is not null (every province's is
dispatched through, from index 0, untested, in `RebuildStrategicResourceProvinces`). What the
placeholders' own fields hold is `inferred` to be defaults.

### 2.2 Three ways to read THIS and FROM

- **GCT**: `guarantee`, `military_access`, `non_aggression_pact`, `truce_with`,
  `undeclared_war_with`, `vassal_of`, `war_with`, and THIS in `faction`. A province-only THIS is its
  province's owner.
- **Direct**: `casus_belli`, `has_wargoal`, `has_cb`'s `actor`. A province-only THIS is `---`.
- **`relation`**: direct, but where that country is 0 it falls back to the **controller** of the
  root scope's province, or of `from_province` - the opposite of GCT's owner.
- **Ignored**: `is_possible_vassal`, `minister_alive`, `num_in_faction`.
- `spy_mission_count` has no THIS keyword and always reads the root scope's country; unnested that is
  the country itself, its own espionage entry.

### 2.3 `has_cb = { type = T actor = A }`

1. T is looked up by name among the casus belli types **at every evaluation**; a miss is the null
   type, which logs "Error in has_cb trigger - invalid CB type!" (channel 0x10004) and answers false.
2. If A is a country at war with us, the war's goals filed under A are searched for one whose
   receiver is us and whose type is T.
3. Otherwise, or on no match, the same search runs over every enemy that owns a province and is at
   war with us.

So **`actor` changes the answer only for an actor at war with us that owns no province**, and the
keyword is about war goals held against the country, not about casus belli.

### 2.4 `casus_belli = X`

True when, for some real casus belli type, the country either holds one of that type against X (the
status `+0x3C`) or the type is `always = yes`, **and** the type's `is_valid` block holds - asked in a
fresh scope whose country is X, whose THIS is the country, and whose FROM is empty. A held casus
belli's dates are not looked at.

### 2.5 `date` and `CEventScope +0x34`

`tick + scope->days_in_month (+0x34) x 24 >= date`. The daily event pass leaves `+0x34` at 0, so
there the test is exact; **the building of country event candidates sets it to the month's length**,
so there `date` is true up to 28 to 31 days early - to let next month's dated events become
candidates, `inferred`. `year` and `month` do not read it.

### 2.6 Definitions

- **A truce** (`CDiplomacyStatus::HasTruce`, rva `0x6489A0`): not at war, and the war was last seen
  less than **2400 hours** ago - `add edi, 0x960; setg` at rva `0x648A58`, checked. The war's time
  is refreshed every hour of a war, so a truce is the hundred days after a war ends. The figure is
  in the code, not a define.
- **A nation the country could release** (`CCountry::GetPossibleVassals`, rva `0xEE320`, rebuilt into
  `CCountry +0x11E0` at every call): a country that owns no province, is not us, has a core on a
  province we own and control other than our capital, and whose capital we own.
- **A removable minister**: a real minister in a real post that may be changed, who holds no post that
  may not.
- **Military access**: the effect of the same keyword writes the same byte on the same status, the
  country's towards X - so "the country gives X access".
- **Relation** is in thousandths from -200 to 200, so `value` is whole points.

### 2.7 Hazards and disagreements with the record

- **`ideology_group` faults** on a country with no ruling party: it reads `[0 + 0x50]`
  (`mov edx, [ecx+0x1140]; cmp [edx+0x50], eax` at VA `0x9F47AB`, checked - no test between).
  `organisation`, `popularity` and `ideology` all guard it.
- `CProvince +0x18`'s comment, "null when the province has none", is contradicted by two unguarded
  dispatches, and `CMapProvince +0x18` is recorded `int` where `CProvince +0x18` is `void*`. Reported,
  not revised.
- `CCurrentGameState +0xBCC` (`played_countries_array`, `undefined4`) is used as a pointer indexed by
  country id; probably `int*`. Not revised.
- `CEventScope +0x34`'s comment carried six VAs; they are rvas now.

### 2.8 Traps hit

- **Trap 1**, in the record (above), and through `vtable.py`, which prints the null classes' slots as
  VAs - trap 9 arriving through trap 1.
- **Trap 2**: `findRefs --vftable` gave wrong starts for two constructors; the allocation settles them.
- **Trap 4**: slots 7, 8 and 14 of the real and null classes are the folded `ReturnTrue` and
  `ReturnFalse`, left unnamed.
- **Trap 14**: `GetPossibleVassals` and `HasTruce` existed only as Lua names; `CWar +0x9C` was in
  prose and not a field; the casus belli database was cited by VA and had no entry; the two leaves
  this reading shared with section 1 were dropped here in favour of section 1's.

### 2.9 Not established

- What the `---` placeholder country holds - its diplomacy, ruling party, faction.
- Whether a live country can reach `ideology_group` with no ruling party.
- The direction of a guarantee beyond the Lua name. (Military access's is settled: the asker's own
  status carries it, `FINDINGS-agreements.md`, C.4.)
- The espionage entry's nine dwords at `+0x2C`.
- Whether a province with no resource holds the same null resource `strategic_resource = none` stores.
- The purpose of `date`'s look-ahead.
- Whether `WarGoalMap_Find`'s four other callers (rvas `0x73F3F`, `0x73F56`, `0x741EC`, `0x7BDF3`)
  use the same map, and the case of `has_cb`'s type lookup.

**Frontier:** `0x652750` (`CWarGoal::AddToWar`'s find-or-insert), `0x5BE8F0`, `0x5BD30` (the shared
name database's init), `0x17350` (the casus belli registrar), `0x12CD00` (the government positions'
registrar), `0x5C55F0`, `CGuaranteeAction::Apply` (the guarantee's direction), `CHasCasusBelliTrigger`
slot 8 (`0x5E86A0`), and the eight AI callers of `HasUsableCasusBelli`.

## 3. Province, unit and combat leaves

All 25 slot-6 bodies were read off the listing, each VA checked as the only holder of its class's
slot 6. Eight of them - `out_of_supply_days`, `units_in_province` and the six `last_*_losses` - are
section 1's too. They were read independently and agree line for line, so they are recorded once,
in section 1's fragment. Operand kinds, from each class's slot 7: **bool** is `CBoolTrigger` (`=
yes` gives 1, anything else 0), **int** is `CIntTrigger`, **string** a `Hoi3CString` at `+0x40`,
**tag** `TriggerLoadCountryTagArgument`.

| keyword | what it answers | scope part | missing part | comparison | THIS/FROM | unknown name | |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `port` | the province has a **map port**, not a naval base | province | province 0: false for `yes` and `no` | `(port != null) == bool` | - | - | confirmed |
| `empty` | the province is unowned - true in every sea zone | province | province 0: false for both | `(owner == 0) == bool` | - | - | confirmed |
| `is_blockaded` | the province's stored blockade flag (3.2) | province | province 0: false for both | `flag == bool` | - | - | confirmed |
| `is_capital` | the province is its **owner's declared** capital, not the acting one | province | **no test**: province 0 is unowned, so `= no` is **true** | `== bool` | - | - | confirmed |
| `is_mission_country` | the scope's country is the target country of **THIS's** current mission | THIS's country, the scope's country | no tests | `(target == scope country) == bool` | THIS implicit | - | confirmed |
| `is_mission_province` | the scope's province is THIS's mission province | THIS's country, the scope's province | no tests | `(province == scope province) == bool` | THIS implicit | - | confirmed |
| `has_building` | that building's **built** level is above nought | province | **no test** (reads province 0) | built level `>` 0, strict | - | **null dereferenced: an access violation** | confirmed (the crash: likely) |
| `has_province_flag` | the flag exists and is set | province | no test; province 0's flags are empty, so false | found and set | - | unknown flag: false | confirmed |
| `has_province_modifier` | the modifier is on the province's active list | province | no test; an empty list is false | pointer equality | - | null: false in practice | confirmed |
| `continent` | the province's continent is the argument | province | no province test | pointer `==` | `this`/`from`: the continent of **that country's declared capital** | **null: true in every province `continent.txt` does not list** | confirmed (the null case: likely) |
| `country_units_in_province` | a unit of the tag's country is in the province | province | empty list or province 0: false | owner `==` tag | THIS by owner fallback; FROM from the **root** scope | `---`: false | confirmed |
| `units_in_province` | as section 1 | | | | | | confirmed |
| `has_empty_adjacent_province` | any neighbour is unowned; **the operand is never read** | province | province 0 or below: false | - | - | - | confirmed |
| `has_leader` | a leader **in service** has exactly that name | country | country 0: its list is empty, so false | exact, case-sensitive | - | - | confirmed |
| `brigade_exist` | a regiment of the country has that historical name | country | country 0: false | exact, case-sensitive | - | - | confirmed |
| `brigade_in_combat` | the unit holding the **first** regiment of that name is fighting | country | country 0 or no match: false | that unit's battle count `> 0` | - | - | confirmed |
| `last_mission` | the country's last **ended** mission had that name | country | no test | exact, case-sensitive | - | - | confirmed |
| `remove_fow` | the holder's lifted-fog list has a live entry for THIS's country | the province's owner if there is a province, else the country | unowned province gives `---`, whose list is empty: `= no` is true | `== bool` | THIS implicit, by owner fallback | - | confirmed |
| `out_of_supply_days` | as section 1 | | | | | | confirmed |
| `last_battle_winner_losses` and the five others | as section 1; the writer is 3.1 | | | | | | confirmed |

### 3.1 The six `last_*_losses`: one figure per kind for the whole world

The six Evaluates are one body that differs only in the displacement: the current game state's
figure `>` the operand, strict. The scope is never read, so the figure belongs to **the last battle
of that kind concluded anywhere**, whoever fought it. The base game uses `last_battle_winner_losses
= 1000` and `last_battle_loser_losses = 1000`, beside `province_id`, in `events/BattleWon.txt` and
`BattleLost.txt`.

**The writer.** A resumed sweep of `.text` tracked every register holding the current game state.
It found exactly 12 accesses: the six trigger reads, which serve as the positive control, and six
writes, all inside `CCombat::Conclude` (`0x174580`) at `0x174879`-`0x174C6C`. The writes come before
the relation change, the battle counters, the on-actions and the messages. For each side:

    figure = side's losses (CCombatant +0x84) / 1000                       ; truncated
    if the side lost outright (+0xA8, the byte HasLost treats as an immediate loss):
        land:  figure += trunc(trunc(strength still standing * 100000 / 1000) / 1000)
               ; 100000 is CFixedPoint(100), so this is the strength x 100
        naval: figure += the side's ships
        air:   figure += the side's wings
    loser  = the attacker's figure if the attacker lost, else the defender's
    winner = the other side's

- Land writes `+0x30` (winner) and `+0x34` (loser); air `+0x38`/`+0x3C`; naval `+0x40`/`+0x44`.
  Any other kind of battle, such as a bombing, writes nothing.
- Nothing is written when `Conclude` returns early - the battle was already concluded (`+0x28`) or
  is a convoy battle (`+0x2B`) - or when either side's country count (`+0x5C`) is nought.
- **Units.** The land term is strength still standing x 100, which is men if a brigade's strength is
  in hundreds of men (*inferred*: an infantry brigade's `max_strength` is 30 and `CRegiment` has a
  `MenPerStrength` slot). That `+0x84` is men in thousandths is also *inferred*.
- **Initial value.** The `CGameState` constructor writes `+0x2C` and `+0x48` and skips everything
  between. No recorded game-state method writes them, and their six tokens (`0x745`-`0x74A`) are
  referenced only by the trigger table. So the figures are **not saved, not loaded and not reset**:
  they are whatever the heap held until the first battle of each kind ends, and they carry across a
  load or a return to the menu (*likely*).

### 3.2 `is_blockaded` reads a flag refreshed only when a controller is set

`CMapProvince +0x36C` is written only by province set-up (`0x96D26`) and by
`UpdateProvinceBlockaded` (`0xA65E0`):

- **The rule.** The flag is cleared unless the province has an owner, a map port, a naval base
  whose built level is above nought, and the `simulated` byte of its template. If all four are
  present, the function sums the ships of the units in the port's sea province that
  `UnitBlockadesProvince` (`0x1C8110`) accepts: not fighting, not retreating, at war with the
  province's **controller**, holding at least one ship. A sum of one or more sets the flag. Then it
  calls `UpdateBlockadeLevel(owner)`.
- **When it runs.** A raw rel32 scan of `.text` finds **one** caller, at `0xA3290` in the controller
  setter `0xA2400`, which itself has 24 callers. The same scan reproduces `UpdateBlockadeLevel`'s
  three recorded callers, which serve as the positive control. Nothing references the function by
  absolute address.
- **So** `is_blockaded`, and the country's blockade share that `blockade` reads, reflect enemy
  fleets as they were when the province's controller was last set, not where they are now
  (*inferred*; whether a fleet's arrival reaches the setter is not established).

### 3.3 Smaller things to keep as they are

- **`has_empty_adjacent_province`** never reads its operand, so `= no` behaves as `= yes`. A sea
  neighbour is unowned, so every province with a sea edge answers true (*likely*: sea zones are in
  the edge list, which is why `any_neighbor_province` has to filter them out by owner).
- **`units_in_province = this|from`** asks a different question from the number form: any unit of
  that country, with N ignored. `= 0` is always true. Its FROM reads the current scope's
  `from_country`, where `country_units_in_province` reads the root scope's. The two are equal in
  practice, because `MakeScope` copies `from_*` unchanged.
- **`continent`**'s THIS reads the root scope's country directly, with no province fallback; its
  FROM reads the current scope's. A misspelt name stays null and matches every province without a
  continent, which means the sea zones. Names are case-sensitive.
- **`brigade_exist` and `brigade_in_combat`** walk every unit of the country and each unit's
  regiments, reading a regiment's historical name (`CSubUnit +0x68`, through `CRegiment` slot 8 at
  `0x6C6C50`). That is the walk `remove_brigade` does, and it is case-sensitive.
  `brigade_in_combat` stops at the first match and tests only that unit.
- **`has_leader`** compares the leader's **name**, not an id. It walks `active_leaders`, which is a
  linked list (3.4). The base game never uses the keyword.
- **`last_mission`** is `CCountry +0xF00`. It is saved as `last_mission` (token `0x6A8`) and skipped
  when it is empty or `no_mission`. Only `CCountry_CancelMission` (`0xEE700`, *inferred* name) sets
  it, from the outgoing mission's name; the same function stamps `last_mission_cancel` (`+0xEE0`)
  with the tick. Every country in the maintainer's 1936.4.20 save carries
  `last_mission_cancel="1.1.1.0"`, which means never.
- **`remove_fow`**: when there is a province, its owner overrides the scope's country. Only the
  first list entry with the tag's id is consulted, by its end tick (`+0x10`) against now
  (`CCountry_HasActiveRemoveFoW`, `0xEFF90`).
- **`has_province_flag`** is case-insensitive, because the tree lookup lower-cases the name. The
  string leaves - `has_leader`, `brigade_*`, `last_mission` - are case-sensitive.
- **`is_capital = no`** is true on any country-only scope. **`is_mission_*`** always consult THIS's
  mission, never the nested scope's country.

### 3.4 Correction to the record: `active_leaders` is a list

`CCountry +0xE00`/`+0xE04`/`+0xE08` were recorded as a vector - first, end, capacity - from the
DLL's header. `CHasLeaderTrigger::Evaluate` loads `+0xE00`, reads the leader at a node's `+0` and
follows the node's `+8` until it is null, with no end-pointer comparison (checked off the listing,
VA `0x9EC1C8`-`0x9EC232`). So it is a `CList`: first, last, count, as `FINDINGS-leaderassign.md`
section 2 and four function entries already said. The field records were the stale half and are
revised to `active_leaders`, `active_leaders_last` and `active_leaders_count`. The offsets do not
change; BiceLib's `CCountry.hpp` still uses the old names.

### 3.5 Traps hit

- **Trap 1**: `CCombat::Conclude` was first disassembled at VA `0x974580` for rva `0x174580`, and
  the result began with a `leave`. Redone at `0x574580`.
- **Traps 2 and 3**, in the sweep's owner column, which names the nearest recorded entry: it put
  the blockade write in `MessagePopupCallback` and the `last_mission` write in
  `CollectCountriesWeCanOperateIn`. `functionStart` and `retsBefore` settle both, as `0xA65E0` and
  `0xEE700`.
- **Trap 9**: `findRefs.py --address` could not line up the instruction stream for most token hits.
  The writer search was redone as a resumed full sweep, and the absolute-reference checks as a raw
  classification of opcode bytes.
- **Trap 4**: `CRegiment` slot 8 has five holders, `CEU3DialogGuiType` among them, so it is left
  without a class, as the `remove_brigade` entry left it.
- **Trap 14**: the `+0xE00` field record (3.4).
- **The decompiler** mis-typed several bodies: `CHasEmptyAdjacentProvinceTrigger` as a non-thiscall
  with one argument, the `last_*` as `__fastcall(int)`, `last_mission` with `in_ECX`. Every claim
  here is from the listing.

### 3.6 Not established

- Whether a fleet entering or leaving a port's sea zone reaches the controller setter (`0xA2400`),
  and so how stale `is_blockaded` is in play; and whether every path through the setter reaches
  the call.
- The unit of `CCombatant +0x84`, and so of the `last_*` figures; and what sets `CCombatant +0xA8`
  (writers `0x17F700` and `0x3049E0`, unread).
- Whether `on_battle_won`/`on_battle_lost` events evaluate their triggers before another battle
  overwrites the figures. Only the order of the writes inside `Conclude` was read.
- What the `last_*` figures hold before the first battle.
- The direction of `remove_fow` - which country gains sight of which. Neither the list's loader nor
  the effect was read; the second consumer, `0x272EA4` inside `0x272BE0`, also passes a province
  owner's country.
- The layout of a province modifier list's entries beyond the modifier at `+8`.
- What a mission scope holds when there is no mission.
- `g_FixedZero` (`0x16870F4`, eleven reads, no store in `.text`) is taken to be nought (*inferred*);
  a write through a computed address would not show in the scan.
- Whether `has_building`'s null dereference is caught by an outer exception filter or ends the
  process.

**Frontier:** `0xA2400` (the controller setter, 24 callers), `0x272BE0` (the second `remove_fow`
consumer), `0x5C7150` and `0xD4BE0` (the blank mission state `CancelMission` copies in), `0xDB7EE`
and `0x2D9264` (`CancelMission`'s two callers), `0x17F700` and `0x3049E0` (the writers of
`CCombatant +0xA8`), and the `remove_fow` loader and effect.
