# What each effect does when it runs

*Read on 2026-10-12, statically, for OpenHOI3's effects, by a wave of three. Addresses are rvas
against `0x400000` unless they say VA. Every `Execute` is slot 11 of its class's own first vftable
- `void __thiscall X::Execute(X*, CEventScope* scope, int unused)`, `ret 8` - so none rests on a
backward walk (trap 2). The slot map, `CContextEffect`, the scalar handlers' scales and the effects
read before are `FINDINGS-effects.md`; every keyword's value form is `FINDINGS-effectgrammar.md`;
the scope is `FINDINGS-triggereval.md` sections 2 and 4.*

**Synopsis.** Before this wave 31 of the 99 effect classes had a recorded `Execute` and 68 did not.
All are now read and recorded, in three sections below, and 13 of the 31 records were completed.
**Corrections**: `CCasusBelli::Activate`'s gate was recorded backwards - an undated casus belli is
attached, not refused; `any_nearby_province`'s distance is `16 x (dx^2 + dy^2)`; `practical` never
runs its child effects, nor do `war`, `undeclared_war` and `add_wargoal`; `release_vassal = REB` is
a branch, not a refusal; `add_wargoal`'s class is `CWarGoalEffect`, not `CWarGoal`; three records
cited their callees by VA. **Found**: the draw `ally`, `local_enemy` and the `random_*` effects make
(3.2); `this` and `from` mean nought to all but a handful of effects (1.1, 2.1);
`change_manpower` and `leadership` change a province, not the country (1.2); `strategic_resource`
and `organisation`/`popularity` can crash the game; `duration = -1` is for ever on a country (1.6);
`war`'s `call_ally` is never read and a misspelt `war` target declares on the province's holder (2.1,
2.4); with the shipped defines an election has no chance in it (1.5).

The function and field tables are in `fragments/merged/effects-country.json`,
`effects-diplomacy.json` and `effects-scopes.json`.

**Terms used throughout.** *v* is the effect's own value at `+0x20`; **int x1000** is `atoi x 1000`
(`CIntEffect`), decimals cut; **thousandths** is read to three places (`CValueEffect`). *Country 0*
is the `---` placeholder country object (`CCountry +0xCA8` says so), and writing to it does not
fault; *province 0* is the placeholder province.

## 1. A country's figures, its government, its goods, a province's things

All 35 `Execute` bodies read end to end off the listing; 20 helpers recorded beside them.

| keyword | what it does | scale | this/from | missing scope part | unknown name | |
| --- | --- | --- | --- | --- | --- | --- |
| `manpower` | the **country's** manpower (`+0xBCC`) += v, floored at 0 | thousandths | ignored: adds 0 | writes country 0 | - | confirmed |
| `war_exhaustion` | `+0xAD0` += v, floored at 0 | thousandths | ignored | country 0 | - | confirmed |
| `officer_pool` | officers (`+0xC4`) += v where v is not 0, floored at 0 | thousandths | ignored | country 0 | - | confirmed |
| `organisation`, `popularity` | the **ruling** party's figure += v, clamped to 0..100000 | thousandths | ignored | no ruling party: **a fault** | - | confirmed |
| an ideology's block | that party's two figures += each; a negative result is **not applied**; **no upper clamp** | thousandths | ignored | country 0 | null ideology: nothing | confirmed |
| `change_manpower` | the **province's** manpower (`+0x320`) through `SetProvinceManpower`, floored at 0, with history | thousandths | ignored | province 0 | - | confirmed |
| `leadership` | the **province's** leadership (`+0x324`), floored at 0, with history | thousandths | ignored | province 0 | - | confirmed |
| `revolt_risk` | the province's revolt risk (`+0x328`), floored at 0, with history | thousandths | ignored | province 0 | - | confirmed |
| `crude_oil`, `metal`, `energy`, `rare_materials` | with a province: its **`max_producing`**; without: the stockpile | int x1000 | ignored | country 0's capital | - | confirmed |
| `fuel`, `money`, `supplies` | with a province: its **pool**; without: the stockpile | int x1000 | ignored | as above | - | confirmed |
| `capital` | declared (`+0xE20`) **and** acting (`+0xE24`) capital = v / 1000 | int x1000 | ignored: **province 0** | country 0 | - | confirmed |
| `change_province_name` | the province's name and its label on the map | text | - | province 0 | - | confirmed |
| `strategic_resource` | the province's resource (`+0x18`); the lists rebuilt | a name | ignored | province 0 | **a crash** | confirmed |
| a government position `= id` | the minister into the post, if he may take it | int x1000 | ignored: id 0 | country 0 | not found: nothing | confirmed |
| `remove_minister` | vacates his changeable post; drops him from the pool | id / post / `yes` | ignored | country 0 | null: nothing | confirmed |
| `coup_by` | a new ruling party; with this/from also the government and half the alignment | an ideology / this / from | **honoured** | country 0 | null: nothing | confirmed |
| `do_election` | `CCountry_HoldElection` | tag / this / from | **honoured** | an unknown tag: country 0 | as missing | confirmed |
| `kill_leader` | unassigns him; out of `active_leaders` | int x1000 | ignored | - | not the scope's leader: nothing | confirmed |
| a building `= N` | built level + v, and a full repair | int x1000 | ignored | province 0: nothing (guarded) | null: nothing | confirmed |
| a technology `= N` | one research step with leadership v | int x1000 | ignored | country 0 | - | confirmed |
| `local_intel_boost` | FROM gets level 8 on units within N km | int x1000 | ignored | no province or no FROM: nothing | - | confirmed |
| `remove_fow` | an entry for THIS on the holder's list, for N **months** | int x1000 | ignored | - | - | confirmed |
| `set_variable`, `change_variable` | set / add; made where missing | thousandths | - | **country 0: nothing** | - | confirmed |
| `add_province_modifier` | attached unless there; the province's modifier rebuilt at once | days | - | province 0 | null: nothing | confirmed |
| `remove_country_modifier`, `remove_province_modifier` | every match removed; **nothing rebuilt** | a name | - | country / province 0 | null: nothing | confirmed |
| `province_event` | a fresh scope with country `---`; the event's trigger asked again | int x1000 | ignored | province 0 | an id nothing has: nothing | confirmed |
| `split_troops` | units and a share of manpower from THIS to the scope's country | thousandths | ignored | - | - | confirmed |

### 1.1 Only two of the 35 read `this` and `from`

A scan of every body (and of `CRemoveMinisterEffect_FindMinister`) for byte reads of `+0x1C`/`+0x1D`
finds them in `CCoupEffect` and `CElectionEffect` only; the same scan finds the scope read
(`[ebp+8]`) in all 35, which is its positive control. The slot-7 handlers clear `+0x20` before
setting a flag, so everywhere else **`X = this` is `X = 0`**: the adding effects do nothing,
**`capital = this` makes province 0 the capital**, and a lookup by id finds nothing. Two effects
reach THIS by themselves whatever the flags: `split_troops` reads the root's country as the giver,
and `remove_fow` targets `EventScope_GetCountryTag`, which is THIS.

### 1.2 A country's figures against a province's

The names mislead. `manpower` is the country's pool; **`change_manpower` and `leadership` write the
scope's province's own figures** (`+0x320`, `+0x324`), through two setters that are twins of the
recorded `SetProvinceRevoltRisk`: each writes `max(value, 0)` and adds a `CManpowerChange`,
`CLeadershipChange` or `CRevoltRiskChange` to the province's history (`+0xD8`), the history's value
`floor((v / 1000 + 0.0005) x 1000)`. None tests the province, so in a country's event they change
province 0.

### 1.3 Goods

With a province in the scope, the seven split four and three, by displacement: **`crude_oil`,
`metal`, `energy` and `rare_materials` add to the province's `max_producing`** (`+0x28C`) - what it
can yield, which `current_producing` then grows towards; no goods are added - while **`fuel`,
`money` and `supplies` add goods to its pool** (`+0x15C`). Without a province all seven add to the
stockpile: `pool_in_exile` (`+0x9F8`) for a government in exile, otherwise the pool of the acting
capital. No clamp anywhere; the value is whole (`metal = 2.5` is 2).

### 1.4 A party's figures

`organisation` and `popularity` act on the **ruling** party alone, clamp to 0..100000 and leave the
other parties as they are. An ideology's block (`fascistic = { }`) has **no upper clamp** and
**skips** a negative result rather than flooring it (the `js` at `0x5B8F29` tests the sum's sign).
All three also add the **new total**, not the change, into slot 1 of the per-party tally at
`CIdeologyData +0x18`, as `CIdeologyData`'s own setter (`0x1284A0`) does; nothing reading the
tallies was found. `organisation` and `popularity` load `ruling_ideology (+0x1140) -> +0x4C` with no
null test: a country with no ruling party faults, where the trigger side tests for it.

### 1.5 The government

**`coup_by`**: the new party is the value, or THIS's or FROM's ruling party; null does nothing. The
ideology's slot 17 is asked and on `CIdeology` is `ReturnTrue` (440 tables), so nothing is refused.
`CCountry_SetRulingIdeology(target, ideology, logged)`. Only with this/from: the alignment
(`+0xE4`/`+0xE8`) becomes the midpoint of target and instigator (`FixedPair_Divide(sum, 2000)`), and
`CCountry_SetGovernment(target, instigator's government, logged)`, which rebuilds the AI strategy.
Always: `CCountry_FillMinisterPosts(target, true, false)`, `last_election` = now,
`CCountry_AllotCabinetSeats`.

**`do_election`** is `CCountry_HoldElection(country, isPlayer)`. Each party scores `popularity x
factor / 1000`, `factor = max(1000 + 1000 x ((t % m) / 100), 0)`, with `t` a draw from the **global**
MT19937 generator (its last tempering step an arithmetic shift) and `m = floor(100000.5) x
ELECTION_RANDOMNESS / 1000 / 1000`. With the shipped 0.15, `m` is 15 and `(t % 15) / 100` is always
0, **so every factor is 1000 and the most popular party wins** - ties to the lower ideology index,
index 0 skipped (`CIdeologyData::GetLeading`). The arithmetic is `confirmed`; that defines are kept in
thousandths is the convention every define reader follows, `inferred` here. The winner becomes the
ruling party, the elected posts are filled again (`FillMinisterPosts(..., true, true)`),
`last_election` is stamped and the seats counted again; a player's country is sent the
`ELECTIONRESULTS` message. Popularity itself is untouched, and each election takes one global draw
per ideology.

**A government position `= id`** looks up minister type `0x26` by id; his `IsValid` and
`CMinister::CanTakePosition` must both hold, and he is put in the post unless its holder has that
id. Not checked: whose minister he is, whether the post may be changed, whether he holds another.

**`remove_minister`** (`0x5B0F40`, its resolver `0x5B13D0`): a positive value is a minister by id,
from any country; a post's name is whoever holds it; `yes` is one changeable post with a real
minister, drawn on the **copied** scope's state, so the parent's state does not advance. `Execute`
then puts the null minister in the first changeable post he holds. **Its guard "keep him if he also
holds a fixed post" reads `positions[outer]`** (`0x5B1246`) and asks that a post already known to be
changeable be not changeable, **so it never matches**, and he is **always** taken out of
`PossibleMinisters` (`+0x160`); a minister who holds no changeable post is only dropped from the
pool and keeps his post. The trigger `has_removable_minister` (`0x5FBFE0`) uses the inner index
correctly. None of the minister effects writes history or rebuilds anything: ministers reach the
country's modifier at its next `RebuildStaticModifiers`.

### 1.6 Modifiers

**`add_province_modifier`** is `add_country_modifier`'s twin: a modifier already there does nothing
- no stacking, no refresh - and otherwise `CProvince_AddTimedModifier` attaches it and **rebuilds
the province's modifier at once**. It expires `now + 24 x days`; **a negative duration gives a date
in year 1** - the day of the year kept, the year replaced by 1 (`0xA07BD` on) - and the country's
attach (`0xDFB90`) has the same arithmetic. `RebuildStaticModifiers` removes an entry only when it
is past **and** its year is above 1, **so `duration = -1` - which BlackICE writes 426 times - is
permanent on a country**. Where a province's modifiers expire was not found.

Both removes take out **every** match, free the list node but not what it holds, and **rebuild
nothing**: the country's or the province's figures keep the modifier until the next rebuild.

### 1.7 Intelligence and the fog

**`local_intel_boost = N`** needs a province and a FROM country. It walks every province
**controlled** by the scope province's controller, keeping those where `16 x dist^2 <= N^2` - centres
in map pixels, x wrapped the short way, so N is in quarter pixels, the game's km - and gives every
unit there, of any owner, `CUnit_GrantIntel(unit, from, SPY_MILITARY_INTEL_LOCAL_TIME_BASE / 1000 =
15, level 8)`, and asks for an intelligence refresh of each province. **It is the writer of `CUnit
+0x2A8`**, the list `FINDINGS-airbattle.md` found the intelligence pass reading.

**`remove_fow = N`**: the holder is the scope's country, or the scope province's **owner** where
there is a province; the target is THIS; the holder's list (`+0xAB8`) gets an entry for the target
ending **N months** from now. An entry already there is reset, not lengthened. Which way the sight
runs was not read.

### 1.8 `split_troops = F` (`0x5BB3A0`)

The giver is THIS (the root's country), the receiver the scope's country. First `pct = F x 100 /
1000`, and two budgets of regiments, `B = sum of regiments_count x F` and `L =
GetTotalNumOfRegiments x F`. Then each of the giver's units, in list order:

- skipped unless slot 9 (land) and slots 11/13 (naval, air) answer an object whose `+0x300`, `+0x304`
  and `+0x2EC` are 0 (not read what they are), a naval unit has no children, it is not fighting, it
  is not a theatre, and it is not on loan;
- **`B <= 0`, or `L <= 0` for a land unit, ends the loop for good**;
- a roll on the scope's state `% 100 < pct`;
- a unit that passes has its children detached, its officers times the giver's officer ratio moved
  to the receiver, the budgets charged, its leader taken away, and moves from the giver's list to the
  receiver's; a land unit then steps into the first neighbour controlled by either side that holds
  no unit of another owner, and where a session flag is set and the old province still holds units a
  `CMoveCommand` back to it is posted.

After the loop, always: `giver's manpower x F / 1000` moves from the giver to the receiver, each
floored at 0, and a full intelligence refresh is asked for.

### 1.9 Buildings, technologies, events, names, resources

**A building `= N`**: `SetProvinceBuildingLevel(province, building, level_max + v, notify)`. The
setter writes the built **and** the working level, so **a level added is a full repair**, and
rebuilds the province's modifiers. No cap at the building's maximum, no owner test, no floor on a
negative result. A naval base in a province with no sea beside it is refused with "...The province
has no port!".

**A technology `= N`** is one `AdvanceResearch` step with leadership v - at most one level, and not a
level given outright.

**`province_event`** advances the parent scope's state first, written back, even when nothing fires;
builds a fresh scope with country `---`, the scope's province, and FROM from the root; and does
nothing, silently, unless the event's own trigger holds.

**`change_province_name`** writes `CProvinceTemplate +0xB0` through `CProvince::SetName` and updates
the label on the map.

**`strategic_resource`**: `none` stores the null resource and so takes one away. **A name no
resource has stores null**, and the `RebuildStrategicResourceProvinces` that follows at once calls
slot 14 on every province's `+0x18` with no null test (`0x28BC40`): **the game crashes**. Established
by putting the slot-7 record beside the rebuild's listing.

### 1.10 Traps hit

- **Trap 1**: every address in the fragment's comments turned into an rva; evidence strings marked
  where they are VAs.
- **Trap 2, four new pairs**: `0x4DD72D`/`0x4DD730` and `0x4A6C2D`/`0x4A6C30` with no padding,
  `0x4A071F`/`0x4A0720` and `0x4DFB8F`/`0x4DFB90` with one `int3`. And a first survey gave
  `remove_minister` a body running to `0x5B1710`, because `0x5B13D0` was unrecorded - four `ret
  0x4C` against `Execute`'s `ret 8` gave it away.
- **Trap 3**: `GetLeading` has two bare `ret`s in one function.
- **Trap 4**: `CIdeology`'s slot 17 is `ReturnTrue`, held by 440 tables, so two tests here never
  refuse.
- **Trap 7**: each keyword's scale settled in the table; `remove_fow`'s is months.
- **Trap 14**: `CVariables::AddVariable` already described the two variable effects;
  `SetProvinceRevoltRisk` and `CAIStrategy::Rebuild` already named these call sites;
  `FINDINGS-airbattle.md` held the `+0x2A8` open item.
- **The decompiler** typed four bodies `__fastcall`, garbled `local_intel_boost` with an
  uninitialised local, and hid the outer index in `remove_minister`; the listing settled each.

### 1.11 Not established

- Which way `remove_fow`'s sight runs (the reader of `+0xAB8` was not read).
- Where a province's modifiers expire.
- Whether a province's new name survives a save.
- In `split_troops`: what `+0x300`, `+0x304` and `+0x2EC` are, and the helpers `0x1B9A30`,
  `0x3A680`, `0xE0830`, `0xE06F0` and `0x1BAC50`; and what the session flag behind its order back
  means.
- `FillMinisterPosts`' order of preference and `AllotCabinetSeats`' arithmetic (decompiler only).
- What reads the `CIdeologyData` tallies.
- What counts down a unit's intelligence grants, and in what unit.
- That defines are kept in thousandths (taken for the election).
- `GetActingCapitalLocation` with a capital of 0.

**Frontier:** `0x1284A0`, `0xDFB90`, `0x5F5E0`, `0x1FDE60`, `0x1FDFB0`, `0x1FE2D0`, `0x1FE270`,
`0x468400`, `0x455BA0`, `0x1B9A30`, `0x3A680`, `0xE0830`, `0xE06F0`, `0x1BAC50`, `0x113680`,
`0x12C1B0`, `0x111E50`, `0x1EE0DB`, `0x1F07C0`, and the reader of `CCountry +0xAB8`.

## 2. Countries among each other, and land changing hands

Every one of the 23 bodies checked as its class's own slot 11 with a single holder, both ends by
`retsBefore` and the bytes either side. Their second argument is unused, as `FINDINGS-effects.md`
section 2 found.

| keyword | what it does | the two parties | this/from | missing or odd parties | |
| --- | --- | --- | --- | --- | --- |
| `casus_belli` | a new `CCasusBelli` (type 0, no end date), filed on the scope's status towards TAG | the scope holds it against TAG | inline (2.1) | one country on both sides refused; `---` gives one on country 0; repeats stack | confirmed |
| `change_controller` | `Province_SetController(scope's province, TAG, now, 1, 1, 0)` | TAG controls the scope's province | resolver | a country's scope: province 0; the setter refuses an unowned province in a running game | confirmed |
| `create_alliance` | a `CAllianceAction { actor scope, recipient TAG, ACCEPT, value 1 }` and its `Apply` | the scope and TAG | resolver | no guard of its own; what `Apply`'s ACCEPT arm checks was not read | confirmed (the arm not read) |
| `create_vassal` | `MakeVassal(scope, TAG)` | the scope overlord, TAG vassal | resolver | skipped if already its vassal or TAG owns nothing; one country on both sides not refused | confirmed; `MakeVassal` inferred |
| `end_guarantee` | the `CGuarantee` deactivated and deleted | only where the scope is the guarantor | resolver | a guarantee TAG gives the scope is untouched | confirmed |
| `end_military_access` | the scope's access byte towards TAG cleared | the scope's access through TAG | resolver | nothing if unset | confirmed (direction inferred) |
| `end_non_aggression_pact` | the `CNap` deactivated and deleted | either side | resolver | no costs | confirmed |
| `end_war` | **TAG** and TAG's vassals leave the war the two share | TAG leaves; the scope stays | resolver | no war: nothing | confirmed |
| `guarantee` | a new `CGuarantee { first scope, second TAG }` | the scope guarantees TAG | resolver | already guaranteeing: nothing; where TAG guarantees the scope, the old object is orphaned | confirmed |
| `inherit` | `AnnexCountry(scope, false, TAG)` | the scope annexes TAG | inline | not guarded: itself, or `---` | confirmed; the annexing inferred |
| `leave_alliance` | the bilateral `CAlliance` deactivated and deleted | either | resolver | factions untouched | confirmed |
| `leave_faction` | leaves the wars led by the faction's leader, then `LeaveFaction(false)` | the scope | none (a faction's name) | not a member: nothing | confirmed |
| `military_access` | the scope's access byte towards TAG set | the scope may pass through TAG | resolver | - | confirmed (direction inferred) |
| `non_aggression_pact` | a new `CNap` where there is none | both | resolver | no change to relation, influence or threat | confirmed |
| `relation` | `ChangeRelation(TAG, scope, value)`, clamped to +-200.000, written both ways | both | resolver | `who = THIS` changes the relation with itself | confirmed |
| `release` | TAG's cores the scope owns, to `ReleaseProvinces` | the scope releases TAG | inline | a dead TAG revived; itself not refused | confirmed; the release inferred |
| `secede_province` | `ChangeOwner(scope's province, TAG)` if the scope owns it, or holds TAG's own | the scope gives it to TAG | inline; `REB` is the scope's rebel faction | province 0 not guarded | confirmed |
| `surrender_inherit` | `AnnexCountry(scope, true, TAG)` | as `inherit` | inline | - | confirmed; the annexing inferred |
| `threat` | `who`: TAG's threat felt from the scope += N, floored at 0, no cap; `all`: `SpreadThreatToAll` | TAG fears the scope | none | an unknown tag: country 0 | confirmed |
| `form_government_in_exile` | land handed to FROM (2.12), then `SetGovernmentInExile(value)` | the scope; FROM the host | FROM read by itself | no FROM: only the flag | confirmed; the exile's body inferred |
| `war` | the enemy gate, the goals stamped, `CDeclareWarAction::Apply`, the goals added | the scope declares on TAG | slot 12 | **no tag, or an unknown one: the controller of the scope's province**; itself not refused | confirmed |
| `undeclared_war` | the pair's `CUndeclaredWar` made or reused, the region added | the scope attacker, TAG defender | slot 12 | the region added again each time; a null region read through | confirmed |
| `add_wargoal` | the embedded goal to `AddToWar` if the two are at war | the scope actor, TAG recipient | slot 12 | no war: nothing | confirmed |

### 2.1 Three ways the target country is resolved

1. **`Effect_ResolveCountryTarget` (`0x5A7C30`)**, for the twelve `CCountryTargetEffect` leaves and
   `CRelationEffect` (27 call sites): THIS is the root's country, or where its id is 0 the owner of
   the root's province, province 0 not tested; FROM is the root's FROM country, or the owner of the
   root's FROM province; otherwise the stored tag, `---` where the loader did not know it.
2. **Inline, in the `CDiplomaticEffect` leaves** (`casus_belli`, `inherit`, `surrender_inherit`,
   `release`, `secede_province`): THIS is `EventScope_GetCountryTag`; FROM the **current** scope's
   FROM country, with no province to fall back on.
3. **Slot 12, `Effect_GetTargetCountryTag`** (`war`, `undeclared_war`, `add_wargoal`), as
   `FINDINGS-effects.md` describes it. Where there is no tag it falls back to **the controller of the
   scope's province**, and an unknown tag counts as none - **so `war = XYZ`, misspelt, declares war
   on whoever holds the scope's province**.

### 2.2 Relations as objects, with none of the diplomatic actions' costs

`guarantee` and `non_aggression_pact` make their own `CRelation` - `first` the scope, `second` TAG,
starting now - whose slot 10 (`Activate`) writes the pointer both ways, and append it to
`CCurrentGameState +0xB2C`. `end_guarantee`, `end_non_aggression_pact` and `leave_alliance` undo it:
slot 11, unlink, delete. Slot 11 is newly named **`Deactivate`**; on `CGuarantee` and `CNap` it only
nulls the pointer both ways and sets `changed`. All then call `RebuildNeighbours` and `0xE39C0` on
both countries. **None costs influence, changes relation or threat, or sends a message** - unlike
`CGuaranteeAction`, `CNapAction` and `CAllianceAction`. `create_alliance` is the exception: it runs
`CAllianceAction::Apply` at ACCEPT (type 2), and gets whatever that arm does, which was not read.

Military access is one byte, one way: the scope's status towards TAG, `+0x4C`. That it means "the
scope may enter TAG" rests on `CMilitaryAccessAction` (a demand) setting the actor's own status
(VA `0xA23998`).

### 2.3 `casus_belli`, and a corrected gate

`AddCasusBelli` (`0xE6640`) refuses only where holder and target are one; otherwise it builds a
`CCasusBelli` of type 0 with no end date, starting now, has `Activate` file it on the holder's status
towards the target (`+0x3C`), and appends it to the relation list. It never looks for one already
there, so every run adds another.

**`CCasusBelli::Activate`'s gate was recorded backwards** (VA `0xA47BD3`-`0xA47C8C`, checked): it
works out `years = (end - 43800000) / 24 / 365.0`, and **below 2 - no end date - it attaches at
once** (`jl` to the filing at `0xA47C8E`); only a dated casus belli whose end is past is refused. The
record had the first branch returning, which would have made every casus belli `AddCasusBelli` makes
invisible. Revised. `casus_belli = TAG` gives **the scope** a casus belli on TAG; `add_casus_belli`
(`0x5A6B10`) is the other way round.

### 2.4 `war`

1. TAG from slot 12.
2. If `CCountry::IsEnemyTag(scope, TAG)` - at war already, or `REB` - **nothing happens, the goals
   included**: an existing war takes `add_wargoal`.
3. The attacker's goals get actor the scope and recipient TAG, the defender's the other way.
4. A `CDeclareWarAction` is built on the stack (`0x611F90`) - actor the scope, recipient TAG, type 0,
   dated now, **`value = !limited`** - and the first attacker goal copied into its own `CWarGoal`.
5. `CDeclareWarAction::Apply` runs (recorded: influence, threat, the calls to allies, faction joins).
6. If the pair now has a war, `AddToWar` for the other attacker goals and all the defender's.

**`call_ally` (`+0x48`) is written by `LoadKey` and read by nothing**: slots 4, 9 and 11 searched,
with `+0x49` (`limited`) read at VA `0x9BC869` as the control. A war on itself is not refused -
`IsEnemyTag` answers false for one country - and what `Apply` then does is not established.

### 2.5 Child effects, and `add_wargoal`'s class

**None of `war`, `undeclared_war` or `add_wargoal` reads the child list at `+8`**, where
`CContextEffect::Execute` does (VA `0x99E2D4`, the control): the children their loaders read are
dead.

**`add_wargoal`'s class is `CWarGoalEffect`**: its case (VA `0x99B141`) is `new(0x54)` and the
constructor `0x5BD3F0`, which writes its own vftable and then the embedded `CWarGoal`'s at `+0x28`.
`switchmap.py`'s class for a case is the last vftable written, which is why `FINDINGS-script.md`
named `CWarGoal`. It acts only where the scope's status towards TAG has a war: it stamps actor the
scope and recipient TAG and calls `AddToWar(goal, war, scope)` - the same embedded object every time.

**`undeclared_war`** makes or reuses the pair's `CUndeclaredWar` (`AddAttacker` the scope,
`AddDefender` TAG), calls `UndeclaredWar_AddRegion` **every time** - the region onto `+0x28`, its
provinces appended to `+0x38`, duplicates kept - links the war into `+0xC10` once, and calls
`OnDiplomacyChanged` on both. No enemy test, no test for one country on both sides.

### 2.6 Who leaves which war

`end_war = TAG` takes **TAG** out of the war they share - from the attackers if it is one, otherwise
`RemoveDefender` unconditionally - and then each of TAG's vassals; the rebuilds and
`OnDiplomacyChanged` run for every vassal, those not in the war too.

`leave_faction` walks every war and takes the scope out where the first-listed member of its own side
is the faction's leader, then `OnDiplomacyChanged` and `LeaveFaction(false)`, which writes no history.

### 2.7 `create_vassal`: `MakeVassal` (`0xD94A0`, inferred)

**Read whole on the listing 2026-10-13: `FINDINGS-surrender.md` B**, which confirms this outline and corrects step 6 - the puppet joins its faction **leader's** wars - and adds that the vassal's own puppets are freed.

1. The vassal's provinces with an overlord's core, controlled by either, go to the overlord (a
   peaceful `ChangeOwner`).
2. The vassal's own cores it owns but the overlord or the overlord's faction holds are given back to
   it.
3. The vassal leaves its faction, and **every war**.
4. With every country, the vassal's relations are deactivated and deleted - alliance, dependency,
   pact, influence, alignment, embargo; military access cleared both ways; **the guarantee pointer
   nulled without the object being deleted**; `allowDebts` cleared.
5. A new `CAlliance` and a `CVassal` (overlord first); the vassal takes the overlord's alignment.
6. Where the overlord's faction is real, `AddCountry(faction, vassal, 0, 1)`: the vassal joins the
   faction's wars. **With no faction the vassal ends at peace with everyone.**
7. The relation set to +500 and clamped, so +200.
8. The vassal takes the overlord's government (`0xE0460`, `0xF06D0`).

### 2.8 `inherit` and `surrender_inherit`: `AnnexCountry` (`0xE7B00`)

**Read whole on the listing 2026-10-13: `FINDINGS-surrender.md` A**, which corrects steps 4, 5, 7 and 8 below (children left behind, two expedition lists, the wars left by the annexed alone, the statuses reset on the other side only).

1. An `ANNEX` message.
2. The annexed country leaves its faction.
3. **Each province it owns**: held by a country other than `REB`, it goes to that occupier;
   otherwise to the annexer - and in surrender, a neighbouring area held by a *candidate*, a
   non-hostile country of the annexed one at war with the annexer, takes **control**.
4. Its constructions deleted; expeditionary units sent home.
5. **Every other unit removed** - in surrender, a unit on a candidate's ground goes over to it on a
   50% roll instead.
6. The land it occupies goes back to the owners.
7. Every country leaves any war with it; spies, alliance, dependency, guarantee and trade routes
   cleared; threat both ways down by 9999, to 0.
8. Pacts, casus belli and embargoes kept.

Only the rule for provinces and the candidates were checked on the listing; the rest is the
decompiler's.

### 2.9 `release`: `ReleaseProvinces` (`0xC1430`, inferred)

Each province collected changes owner to the released country, gets its core if missing, restores
the capital where it is the original one, and has `war_seen_tick` set to 24 hours ago both ways with
the old owner. After them: **the released country is raised to the oppressor's level in every
technology it is behind in**, capped at the technology's `+0x2C4`; **each released province with
`MODIFIER_IC` above 0 makes an army of three infantry brigades** (checked on the listing:
`[mods+0x78]`, id 15), which needs the infantry brigade to be usable; and an `INDEPENDANCE` message.
No vassal relation is made.

### 2.10 Owner and controller

**Read whole on the listing 2026-10-13: `FINDINGS-surrender.md` D** - both setters, the owner setter `0xA2180` (bookkeeping only, no cores) and the acting capital.

`CMapProvince::ChangeOwner` (`0xA36C0`) calls the controller setter first, then the owner setter
`0xA2180` (not read); sets `nationalism` to `YEARS_OF_NATIONALISM` where the old owner was real;
**removes every active province modifier** in a running game; and takes the old owner out of its
faction when it owns nothing any more.

`secede_province` makes two independent tests of the scope's province: controlled by the scope and
owned by TAG, it is given back to TAG; owned by the scope, it is given to TAG.

### 2.11 `threat`

**`who = TAG`**: TAG's threat felt from the scope rises by N, floored at 0, no cap, no `changed`
flag. **`who = all`**: `SpreadThreatToAll(&N or &-N, &+-1000)`, the scope the country feared:

- `base = N x (1000 + feared's THREAT_IMPACT) / 1000`, halved where the feared country has no real
  faction;
- for each other country c: `v = base x f_c / 1000 x alignFactor / 1000 x (1000 - c's
  THREAT_RESISTANCE) / 1000`, raised to at least `base / 20`;
- `f_c = max(1000 - dist x 1000 / min(28 x c's provinces, 4000), 0)`, between the two acting
  capitals; 1000 where c is the feared country's neighbour, and **1001 where c owns nothing**, so the
  dead feel threat too.

The effect calls `GetActingCapitalLocation` first and throws the answer away.

### 2.12 `form_government_in_exile`

**Read whole on the listing 2026-10-13: `FINDINGS-surrender.md` C**, which corrects the acting capital (it becomes the leader's own) and the trade routes (gone exactly when the exile does not own its acting capital).

Only with a FROM: the provinces the scope controls on the continent of FROM's capital, or whose area
borders ground FROM holds, go to FROM where FROM is at war with their owner (or `REB` is concerned),
and otherwise back to their owner. `SetGovernmentInExile(scope, value)` then always runs, so `= no`
ends an exile. Going into exile **cuts manpower and officers to a tenth** (`floor(100.5) / 1000`),
removes units on unfriendly ground, makes a new faction leader if one is needed, and may delete every
trade route.

**Messages and events.** Only `AnnexCountry` (`ANNEX`) and `ReleaseProvinces` (`INDEPENDANCE`) send
messages of their own; `create_alliance` and `war` get theirs through `Apply`. No effect here fires
an event. The control for "no message": `CGuaranteeEffect`'s whole list of calls is the resolver,
`operator new`, the constructor, slot 10, `0x93E10`, `RebuildNeighbours` and `0xE39C0`.

### 2.13 Traps hit

- **Trap 2, four new pairs**: VA `0x9A9A4D`/`0x9A9A50` (`secede_province`'s `Execute` and its slot
  9, no padding), VA `0x9BAE9D`/`0x9BAEA0` (`ret 0x28` straight into the exile's `Execute`, no
  padding), VA `0x9B69EC`/`0x9B69F0` and VA `0x9B4DCE`/`0x9B4DD0` (one `int3` each).
- **Trap 1** in this reading's own work: `findRefs --callers 0x5BD3F0` given an rva answered 0; the
  VA has one caller.
- **Tooling**: `switchmap.classAt` takes the last vftable a case writes, an embedded member's where
  the constructor builds one - hence `CWarGoal` for `add_wargoal`.
- **Trap 14**: `SetMilitaryAccess`'s record already named `CGrantMilitaryAccessEffect::Execute`'s
  call, and `CCasusBelli::Activate`'s comment was wrong.

### 2.14 Not established

- `CAllianceAction::Apply`'s ACCEPT arm, and so what `create_alliance` checks or refuses.
- The owner setter `0xA2180`, `0x4A2FB0`, and `0xE39C0`, the refresh after `RebuildNeighbours`
  everywhere.
- `Province_SetController`, `AnnexCountry`, `MakeVassal`, `ReleaseProvinces` and
  `SetGovernmentInExile`, read off the decompiler, the listing checked only where their evidence says.
- What `CDeclareWarAction::Apply` does with `value = 0` (limited), and with actor and recipient one.
- Whether `UndeclaredWar_AddRegion` with a null region faults.
- The direction of military access, beyond the demand action's.
- `0x47E590`, the nearest candidate in surrender. (A VA: rva `0x7E590`, read 2026-10-13 as
  `COwnerArea_DistanceToProvince`, `FINDINGS-war.md` D.5.)

**Frontier:** `0xA2180`, `0x4A2FB0`, `0x1D6230`, `0xE39C0`, `0xE0460`, `0xF06D0`, `0xE0B80`,
`0xA3B80`, `0xDD730`, `0xDD670`, `0x1020E0`, `0x1ABDD0`, `0x10F820`, `0x7E590`, `0x647F20`,
`0x647370`, `0x221F0`, `0x82190`, `0xBC800`, `0x618D70` (the ACCEPT arm), `0x612030`, `0x611F90`.

## 3. The iterating scopes, `limit`, and the 31 recorded `Execute`s

### 3.1 The shared base and `limit`

`CMultipleTargetEffect` (0x60 bytes) is `CEffect` (0x20) with a `CAndTrigger` by value at `+0x20`.
It has no `Execute` of its own: its slot 11 is `CEffect::Execute` (`0x59C6E0`), so the "11 distinct
bodies that read `[ebp+0xC]`" in `FINDINGS-effects.md` section 2 count one body twice.

`CMultipleTargetEffect::LoadKey` (recorded) sends every `limit = { }` into that one AND, so several
limits join as one AND; every other key becomes a child effect. Each scope asks the limit through
`CAndTrigger` slot 6 against **the member's rebound scope**:

- an absent or empty limit is an empty AND, which is **true**, so no limit means every member;
- the `any_*` forms ask it per member, immediately before that member's children;
- the `random_*` forms ask it inside the candidate builder, **before the draw**.

All `confirmed`.

### 3.2 Per scope

| keyword | set and order | rebinds | limit | draw | empty set | |
| --- | --- | --- | --- | --- | --- | --- |
| `any_owned` | the country's `OwnedProvinces` (`+0xCF0`), list order | province; country kept | per member | - | nothing | confirmed |
| `any_controlled` | `ControlledProvinces` (`+0xD00`), list order | province; country kept | per member | - | nothing | confirmed |
| `any_country` | every database index `0 .. GetCountryCount()-1`, re-counted each step - **countries that do not exist and index 0 included**; skips the scope's own country, after asking its limit | country; **province kept** | per member | - | - | confirmed |
| `any_neighbor_country` | `Neighbours` (`+0xFD8`), list order; skips its own | country; **province kept** | per member | - | nothing | confirmed |
| `any_neighbor_province` | the province's edge records, edge order; **only neighbours with an owner** | province; country kept | per member | - | nothing | confirmed |
| a region's name | the region's province vector, file order; **no ownership filter** | province; country kept | per member | - | nothing | confirmed |
| `any_nearby_province` | the `ControlledProvinces` of the province's controller, list order, kept where **`16 x (dx^2 + dy^2) <= distance^2`** (x wrapped at half the world's width); the province itself is a member | province; country kept | after the distance test | - | nothing | confirmed |
| `random_country` | database order; **existing countries only** (owning a province); not its own | country; province kept | before the draw | one draw | **no draw, the state untouched** | confirmed |
| `random_owned` | `OwnedProvinces`, list order | province | before the draw | one draw | as above | confirmed |
| `random_neighbor_province` | owned edge neighbours, edge order | province | before the draw | one draw | as above | confirmed |
| `random_empty_neighbor_province` | edge neighbours that are land and have no owner | province | before the draw | one draw | as above | confirmed |

**The draw**, shared by the four `random_*` forms, by `release_vassal = random` and by the trigger
side's `ally` and `local_enemy` (`MakeScope`, `0x5C1F14`-`0x5C1F1D`), is
`EventRandom_NextProduct` (`0x6A2E90`):

    s1 = s * 0x343FD + 0x269EC3
    s2 = s1 * 0x343FD + 0x269EC3          ; written back into the scope passed in
    r  = ((s2 >> 16) & 0x7FFF) * ((s1 >> 16) & 0x7FFF)     ; never negative, below 2^30
    index = r % count                     ; cdq; idiv - counted from the head of the list

Checked off the listing (VA `0xAA2E90`-`0xAA2EC0`). **That closes the trigger side's open question**
of how the draw becomes an index. `CSplitTroopsEffect::Execute` (`0x5BB3A0`) is a third caller, with
`% 100`.

The candidate lists live in the effect object (`+0x60`) and are rebuilt from nothing on every
`Execute`, and by slot 8 for the tooltip. The member is taken out of the list before the children
run, so re-entering the same effect cannot disturb a draw.

### 3.3 Which random state a block advances

All `confirmed`, off the copy instructions:

- **`any_owned` and `any_controlled`** copy the whole scope afresh from the parent for **each**
  member, so every member starts from the parent's state: a `random = { chance = 50 }` inside rolls
  **the same number in every province**, and nothing comes back to the parent.
- **`any_country`, `any_neighbor_country`, `any_neighbor_province`, a region and
  `any_nearby_province`** copy once: draws made inside one member's effects, and `ally` or
  `local_enemy` asked in the limit, carry on into the next member. The parent is never advanced.
- **The `random_*` forms** advance the parent by exactly one draw, and only when there is a
  candidate; the member's copy is made after the write-back, and what its children draw stays in
  the copy.
- **A context block** (`owner = { }`, a tag...) runs its children against a copy, so their draws do
  not come back; but resolving `ally` or `local_enemy` advances the **enclosing** scope
  (`FINDINGS-scopetriggers.md` section 13).
- `random`, `random_list` and `country_event` advance the scope they are given, in place.

So the record's comment on `CEventScope +0x8` - "a context does not advance its parent's state" -
is true of everything but `ally` and `local_enemy`. Not revised.

### 3.4 Can a member's effects change the set being walked?

In the list walks (`any_owned`, `any_controlled`, `any_neighbor_country`, `any_nearby_province`)
**the next node is read before the limit and the children run**, so removing the current province -
`secede_province` inside `any_owned` - is safe, and nodes appended to the tail during the walk are
visited. `any_country` re-reads the count at every step. The neighbour forms and a region walk
arrays no effect edits. Whether a change of owner frees or rebuilds the walked list's nodes was not
read; if it frees the saved next node, the walk reads freed memory.

### 3.5 Missing scope parts

No body guards against country 0 or province 0. Country 0 indexes the empty tag's object, whose
lists are empty, so the country walks produce nothing (that the slot holds a real object is
`inferred`: `any_country` dereferences index 0 unguarded and the game does not fall over). Province
0's edges are walked by the neighbour forms, and its controller's lists by `any_nearby_province`.

### 3.6 The 31 recorded `Execute`s

| keyword | what it does | scale | this/from | missing scope part | record complete before? | |
| --- | --- | --- | --- | --- | --- | --- |
| `add_ai_strategy` | merges the block into the country's `ai_event_strategy` (`+0x334`): weights **add up** across firings; copies a non-null personality to `+0x34C`; then `CAIStrategy::Rebuild` (`+0x48C`) | as loaded | - | unguarded | no - revised | confirmed |
| `add_casus_belli` | `0xE6640`: nothing where the two are one country; else a new `CCasusBelli { first = named, second = scope, start = now }`, activated (slot 10) and appended to the relation list. `casus_belli` builds the mirror | - | this by owner; from the scope's FROM | an unknown tag not tested | partly - revised | confirmed |
| `add_core` | `CProvince::AddCore(province, tag, log = 1)`, then `RebuildNeighbours` and `0xE39C0` on the core's country | - | this by owner; **from: the scope's FROM province** | an unknown tag: nothing; **no province: province 0 gets the core** | cited a VA - revised | confirmed |
| `add_country_modifier` | as recorded: nothing if already active, otherwise `0xDFB90` | days | - | - | yes (`0xDFB90` unread) | confirmed |
| `add_division` | as recorded | - | - | the owner falls back to the controller | yes | inferred (not re-read) |
| `any_nearby_province` | section 3.2 | quarter pixels | - | province 0's controller | **wrong formula** - revised | confirmed |
| `clr_country_flag`, `clr_global_flag`, `clr_province_flag` | as recorded; a flag not there: nothing | - | - | the province form uses province 0 | yes | confirmed |
| `country_event` | as recorded; asks the target event's own trigger again | id = value / 1000 | FROM is the root's country | - | yes | confirmed |
| `create_revolt` | the province's **manpower x N** brigades, cut to whole, only where the area's slot 0 and the `simulated` gates pass; the rebel type by `spawn_chance` | int x1000 | - | province 0 | no signature - revised | confirmed |
| `dissent` | as recorded | thousandths | - | - | yes | confirmed |
| `fixed_ai_strategy` | writes `CCountry +0x4A1`, which nothing reads | bool | - | - | yes | inferred (record) |
| `government` | the government (`+0xDFC`) set, a `CGovernmentChange` logged, the AI strategy rebuilt; then `0xF06D0(country, 1, 0)` picks every minister again. **No test that the government changed** | - | this/from: that country's government | a null government: nothing | cited VAs - revised | confirmed |
| `join_faction` | as recorded | - | - | - | yes | confirmed |
| `load_oob` | as recorded | - | - | - | yes | confirmed |
| `modify_spies` | as recorded: nothing configures it | - | - | - | yes | inferred (record) |
| `national_unity`, `neutrality` | as recorded | int x1000 / thousandths | - | - | yes | confirmed |
| `practical` | as recorded, and **its child effects are never run** | thousandths | - | country 0: returns | no - revised | confirmed |
| `random` | as recorded | percent | - | - | yes | confirmed |
| `random_list` | as recorded | plain weights | - | - | yes | confirmed |
| `release_vassal` | section 3.7 | - | this/from read off **the root** | an unresolved target never passes the possible-vassal test | partly, and wrong on REB - revised | confirmed |
| `remove_brigade` | the first regiment of the country whose name (`+0x68`) matches, case and all. With others in its unit: removed from it (`RemoveRegimentFromUnit`, then `0x284CE0`). **The last one: the unit's id is put on `pending_unit_removals` (`CGameState +0xBF4`)** and the hourly tick removes the unit | - | - | - | partly - revised | confirmed |
| `remove_core` | `CProvince::RemoveCore(province, tag, 1)` and the two rebuilds | - | as `add_core` | - | cited a VA - revised | confirmed |
| `set_country_flag`, `set_global_flag`, `set_province_flag` | as recorded; a flag not there is made | - | - | - | yes | confirmed |
| a rebel type's name | the province's **manpower x N** brigades of that type, with no gates | int x1000 | - | province 0 | no signature - revised | confirmed |
| a unit type's name (`CAddSubUnitEffect`) | as recorded, and the cached type is **`hq_brigade`**: a headquarters always gets a new unit, and no other brigade joins a unit led by a headquarters. The brigade arrives at **half strength and half organisation** | a province id x1000 | this/from: the root's province, FROM's province | - | open item - revised | inferred |
| a scope (`CContextEffect`) | narrows; silent where it cannot; its children are given a literal 0 | - | - | - | phrasing - revised | confirmed |

For the 18 rows marked *yes*, the record's account was checked and the bodies were not read again.

### 3.7 `release_vassal`, in order

1. **The target** (`CReleaseVassalEffect::ResolveTarget`, `0x5AF510`): `this` is the root's
   country, or the owner of its province; `from` is the root's FROM country, or the owner of its FROM
   province. Otherwise `CCountry::GetPossibleVassals` of the scope's country is rebuilt every time,
   and with `random` the answer is `---` for an empty list, or else the draw of section 3.2 - **which
   advances the scope's state**; without it, the tag written. An unknown tag is read as `random`, so
   it is a pick among the countries the scope's country could release now.
2. **`REB`**: the scope's rebel faction is found and its release routine `0xBE590(faction, scope
   country)` called, and nothing else. *Inferred*, off the decompilation only: it releases provinces
   through `0xC1430`, sets the faction's government, and declares revolutionary wars only when its
   third argument is 0 - here the scope country's id, so normally none. **`REB` is not refused**,
   which corrects the record.
3. Nothing unless the target is among the possible vassals.
4. The target's cores that the liberator owns **and** controls, but its capital, are handed to
   `0xC1430` (not read; its calls show provinces changing hands, cores, the old capital, new units
   for the released country and the message).
5. A `CVassal { first = liberator, second = target, start = now }` is stored in the diplomacy
   status, appended to the relations and activated.
6. The liberator's alignment is copied to the target.
7. Where the liberator's faction is real, `CFaction::AddCountry(faction, target, false, true)`: the
   vassal joins the faction and its wars.
8. `ChangeRelation(liberator, target, +500000)`, clamped to +200.000.
9. The target takes the liberator's government (logged), then `0xF06D0(target, 1, 0)`.
10. `RebuildNeighbours` and `0xE39C0`, on the target and then on the liberator.

### 3.8 What looks wrong and is what the bytes do

- `any_country` runs on countries that do not exist; `random_country` does not.
- `any_owned` and `any_controlled` give every province the same roll.
- `any_country`, `any_neighbor_country`, a region and `any_nearby_province` keep the outer province.
- `any_country` asks the limit of its own country before skipping it.
- `random_empty_neighbor_province` gives its children a literal 0 for the second argument - with
  `random`, `random_list` and a context, four nodes replace it, against `FINDINGS-effects.md`
  section 2's two.
- `practical` reads its child effects and drops them.
- `government` with the government already in force still logs a change and picks the ministers
  again.
- `add_core = TAG` in a country's scope cores province 0.
- `create_rebels` and `create_revolt` scale with the province's manpower in whole units: N = 1 in a
  province of 0.8 manpower makes nothing.

### 3.9 Traps hit

- **Trap 1, twice**: three records cited their callees by VA (`add_core`, `remove_core`,
  `government`) - rva `0x4A3B80` decodes as the tail of another function; and a scan of this
  reading's own once passed `0x8A3B80` as a VA, caught by decoding it again.
- **Trap 2, three new pairs**: `0x5AB7AD`/`0x5AB7B0` with **no padding** - `functionStart` inside
  slot 8 answers `0x5AB590` - and `0x5ACD1C`/`0x5ACD20` and `0x5AF73C`/`0x5AF740` with one `int3`
  each. A scan for runs of `int3` ran `CAnyNeighborProvinceEffect` and `CRandomCountryEffect` into
  their slot 8; the vftables settled both.
- **Trap 4**: `0x59C480` is slot 0 of three random classes, left unnamed.
- **Trap 14**: the `hq_brigade` cache was already `CSubUnitDataBase +0x78` in the record, and
  `pending_unit_removals` already named in `FINDINGS-schedule.md`.

### 3.10 Not established

- What `0xBE590`, `0xC1430`, `0xE39C0`, `0xF06D0`, `0xDD450`, `0x284CE0` and `0xBC800` do beyond the
  roles their calls suggest.
- What a `CCasusBelli`'s `first` and `second` mean (section 2's).
- Whether editing a list frees its nodes during a walk (3.4).
- Whether one province's edges can name a neighbour twice; each edge is one visit.
- The object at a rebel faction's `+0x30` (`add_core`'s `REB` arm).
- That `countries[0]` is a live object.
- `add_division`, `fixed_ai_strategy` and `modify_spies`, which were not read again.

**Frontier:** `0xBE590`, `0xC1430`, `0xBE150`, `0xE39C0`, `0xF06D0`, `0xE0460`, `0xE6640`,
`0xDD450`, `0x284CE0`, `0xBC800`, `0x59C450`, `0x59C480`, `0x5AF740`.
