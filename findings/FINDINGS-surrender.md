# The surrender wave: annexation, the puppet, the government in exile, a province changing hands

Read 2026-10-13 for OpenHOI3's second piece of war and peace, peace and the capitulation (`WAVE.md`, the
surrender wave). `FINDINGS-war.md` C and D read the peace and the capitulation themselves; what they call to
do the work - `AnnexCountry`, `MakeVassal`, `SetGovernmentInExile`, `Province_SetController` and
`CMapProvince::ChangeOwner` - was recorded only as `inferred`, read off the decompiler with the listing checked
at a few gates (`FINDINGS-effectrun.md` 2.7 to 2.12). Here each is read whole on the listing and raised to
`confirmed`, one section a brief, with a last section of the collector's own.

**What this corrects:**

- **Annexation** (A): in the surrender mode a unit going over leaves its children behind; expeditionary units
  are two lists, the lent-in going home shattered and the lent-out recalled to be destroyed;
  `CDiplomacyStatus::Reset` runs on every other country's side only, so the annexed country's own NAPs, casus
  belli and debts outlive it; the `surrender` console command uses the surrender mode, the second tag annexing
  the first.
- **The puppet** (B): a puppet joins its **faction leader's** wars, not its overlord's; the vassal's own puppets
  are freed; its relation is overwritten with the overlord's +500, clamped; no message is sent.
- **The exile** (C): `+0xA08` is `pool_in_exile`'s money; the government sits **in** the faction leader's acting
  capital, not toward it; trade routes go exactly when the exile does not own its acting capital; `CCountry
  +0xA64` is `received_from_exiles`, not unused.
- **A province changing hands** (D): a fallen capital loses 25% of money and resources only, never supplies or
  fuel; based air and naval units go to the old controller's faction's nearest base, and are deleted only when
  idle; "0x4A2FB0" is an AI notification; `UpdateOwnerAreaOfProvince`'s caller is `Province_SetController`.
- **The AI's intel** (E): the draw `CAIIntel::CalculateTheirPercievedMilitaryStrengh` takes for each unit is never
  negative.

The four readers' `revised` rows were spot-checked off the bytes by the collector: `MakeVassal`'s setter flags
(`0x4D958D`, `0x4D961A`: owner (0, 0, 1), controller (1, 0, 1)); the capital's loot gated on the acting capital
and reading `[0x1A86CEC]` (`0x4A2622`-`0x4A2630`); the exile's supplies and fuel added at `+0xA6C`/`+0xA70`, a
pool at `+0xA64` with its eight-byte head, of the acting capital's controller (`0x4DB44E`-`0x4DB48D`).

## A. Annexation

Fragment `fragments/merged/annex.json`. Texts are the base game's English. Their Finest Hour has no copy of the
`ANNEX` or `EXPRETURNED*` keys, and its `messagetypes.txt` entries are the same as the base game's.

### A.1 In one line

- **The world is told first.** Every player gets an `ANNEX` popup at the annexed country's capital, whether or not
  he is involved.
- **The annexed country then leaves its faction.**
- **Its land goes to whoever occupies it, and to the annexer where nobody does.** In surrender mode a nearby
  co-belligerent at war with the annexer may take control of the annexer's new land.
- **Its constructions are deleted.** Units lent to it go home; units it lent out are recalled.
- **Every unit it has is destroyed.** In surrender mode a unit standing with a co-belligerent goes over to it on an
  even draw instead.
- **What it occupied goes back to the owners.**
- **It is taken out of every war.** Every other country's status toward it is wiped, and threat falls by 9999 both
  ways.
- **Nothing marks it dead.** It keeps its stockpile, manpower, technology, leaders, ministers, capital and its own
  view of everyone else.

### A.2 Who calls it, and with which flag

`void __stdcall AnnexCountry(CCountry* annexer, bool surrender, char annexedTag[4], int annexedId)`, `ret 0x10`.
`findRefs --callers` (on the VA) finds five calls:

| call | caller | `surrender` |
| --- | --- | --- |
| VA `0x9AA169` | `CInheritEffect::Execute` (`inherit = TAG`) | 0 |
| VA `0x9AA509` | `surrender_inherit = TAG` | 1 |
| VA `0x47ADCE` | `CWarGoal::Enforce` (`0x47A950`, rva `0x7A950`), `po_annex` | 0 (EBX, zero) |
| VA `0x47AE20` | `CWarGoal::Enforce`, the faction's other governments in exile | 0 |
| VA `0x440522` | `ConsoleCmd_Surrender` (`0x4401E0`, rva `0x401E0`) | **1** |

**The console command is `surrender`**, described as "Annex the other country". Its name, description and handler
(`0x4401E0`) sit in the static command table at `0x170BAEC`. Given `surrender A B` it calls
`AnnexCountry(countries[B], 1, A)`, so **B annexes A**, and answers "Country B annexed A". So the surrender mode is
reached only by the `surrender_inherit` effect and this console command, never by a capitulation
(`FINDINGS-war.md` D.4 stands).

### A.3 `AnnexCountry` (`0x4E7B00`, rva `0xE7B00`), in order

**1. The message** (0x4E7B97-0x4E805F), before anything changes.

- **Variables:** the local player's own set (`CCountry::BuildMessageVariables` of `CCurrentGameState +0xC30`:
  COUNTRY, MONARCHTITLE, TITLE, his ministers). Then ACTOR, the annexer's name (`CountryNameOfCountry`), and
  RECIPIENT, the annexed country's name (`CountryNameOfTag`).
- **Province:** the annexed country's **capital** (`CCountry::GetCapitalLocation`, not the acting capital).
- **Countries:** the first country (+0x34) is the annexer and the second (+0x3C) is `---`, so both shields show
  the annexer.
- **Posting:** `PostMessage_CMessageHandler` with the callback `0x6995D0`, the Goto. The first block of `0x6995D0`
  was read: it takes the message's province, else the first country's acting capital, else the second's; the
  centring itself was not read.
- **Who is told:** nothing asks whether the local player is involved, so **every player in every game is told**.

`ANNEX` (base game and TFH `messagetypes.txt`) is log, onmap, popup, option, not pausepopup, `cat_diplomacy`. Its
texts:

| key | English |
| --- | --- |
| `_HEADER` | "$foreign_minister$ reports" |
| `_1` | "$ACTOR$" |
| `_2` | "$MONARCHTITLE$," |
| `_3` | "$ACTOR$ annexed $RECIPIENT$" |
| `_4` | "which now is part of their country." |
| `_5`, `_6` | "*" (empty) |
| `_LOG` | "$ACTOR$ annexed $RECIPIENT$." |
| `_MAP` | "*" (an empty map text is still made) |
| `_BTN2` / `_BTN3` | "OK" / "Goto" |

The foreign minister and monarch title are the player's own, not either party's.

**2. The candidates, surrender mode only** (0x4E80A9-0x4E8183).

- The list starts as a copy of the annexed country's `non_hostile_countries` (+0xF98), made with
  `CCountryList_AppendAll`. That list is itself plus its co-belligerents, as of the last daily `RebuildNeighbours`.
- A country stays on it only if it is neither the annexer nor the annexed, **and** the annexer's status toward it
  has a war, or it or the annexer is `REB`.
- So the candidates are **the annexed country's war partners who are at war with the annexer**.

**3. The faction** (0x4E8186-0x4E81E0). This runs only where `faction` (+0xD8) answers slot 7, that is, a real
faction:

- `CFaction::RemoveMember(faction, &tag)`, which unlinks the member, sets `members_changed` and clears the allied
  objectives for that id;
- `faction = CFaction::null()`;
- `CCountry::RebuildStaticModifiers`, then `CCountry::RebuildRules`;
- the per-country display dirty byte (`[0x1A8C388] + id*0x14 + 0x10`) is set.

There is no `LeaveFaction`, no history and no message. **A new leader is not chosen**: the faction's leader is its
first member (`FINDINGS-war.md` C.3), so if the annexed country led it, the next member in list order simply
becomes the leader.

**4. Each province it owns**, in `OwnedProvinces` (+0xCF0) order, dated now (`CCurrentGameState +0xBDC`):

- **Held by somebody else, not `REB`:** `CMapProvince::ChangeOwner(p, its controller, now, applyConsequences 1,
  rebuildAreas 0, peaceful 0)` (0x4E8330). **The occupier keeps it**, whoever it is: the annexer, an ally of the
  annexed, anyone.
- **Held by the annexed country itself, or by `REB`:** `ChangeOwner(p, annexer, now, 1, 0, 0)` (0x4E8580). The new
  owner takes control too (`ChangeOwner`'s record), so rebels lose it.
- **Surrender mode, with candidates:** a controller is looked for in the areas that neighbour the province's
  **area** (`COwnerArea +0x34`). Every province of one area sees the same neighbours.
  - Each neighbouring area's holder is taken as **the controller of its first province** (+0x24), as it stands at
    that moment. Areas are not rebuilt inside this loop, so control handed out earlier in the same loop counts.
  - The distinct candidates among those holders are collected. With one, it is chosen. With several, the one whose
    area is nearest by `COwnerArea_DistanceToProvince` wins: the best starts at 1,000,000 and only a strictly
    nearer one replaces it, so of equals the first in the neighbour list keeps it.
  - Then `Province_SetController(p, candidate, now, 1, 0, 0)` (0x4E8597) runs **after** the `ChangeOwner`. **The
    annexer owns the province and its enemy holds it.**

**Cores:** `AnnexCountry` touches none. The annexer does not gain the annexed country's cores, and the annexed keeps
its own on the land.

**5. Constructions** (+0xF40, 0x4E85A5-0x4E85D5). Each is deleted through its slot 0 (the scalar deleting
destructor) and the list freed. **Nothing is refunded or handed over.**

**6. The active mission** (+0xE38, a `CActiveMission` held by value) is overwritten with a fresh one
(0x4E85DA-0x4E85F0). The record types +0xE38 as `CPersistent*`, but `CActiveMission_Assign` copies 0xA8 bytes into
+0xE3C onward, so the field is the object itself. Its `type` is the null mission (`no_mission`), its owner `---`.

**7. Expeditionary units**, two lists:

- **Units lent to it**: those in `units` (+0xBAC) whose `expeditionary_owner_id` (+0x290) is set. They are
  collected first, then each goes through `CUnit::ReturnFromExpedition(unit, annexed)` and then
  `CCountry::ShatterUnit(lender, unit)`. **They go home shattered**, back at the lender's acting capital or at a
  non-enemy depot where they stand (`ShatterUnit`'s record).
- **Units it lent out** (+0xBBC, `expeditionary_units_lent`): each goes through `CUnit::ReturnFromExpedition(unit,
  its current host)`. **They come back to the annexed country and are destroyed in step 8.**
- **`ReturnFromExpedition` in order:** it detaches the unit from its parent, unlinks it from the lender's +0xBBC,
  clears `expeditionary_owner`, releases the AI agent, then moves the unit from the host's list to the lender's with
  `CCountry::AddUnit`. It then calls `0x5D3840` (not read), rebuilds the counter and re-enters the province.
- **The message:** only where the local player is the host or the lender, at the unit's province.
  - The host's player gets **`EXPRETURNEDWE`**. Log: "We returned an expeditionary force to $RECIPIENT$." Popup:
    "Expeditionary Force sent home! / The Expeditionary force $NAME$ / that we had received from / $RECIPIENT$ /
    have returned to their contol." (sic).
  - The lender's player gets **`EXPRETURNED`**. Log: "$ACTOR$ returned an expeditionary force to us." Popup:
    "Expeditionary Force Returns! / … earlier sent by us to $ACTOR$ / have returned to our contol. A parade for our
    brave troops is in order."
  - Both types are log, onmap, popup, option, not pausepopup, `cat_diplomacy`; `_MAP` reads "Force returned.".

**8. Every unit of `units` (+0xBAC)**, which holds every level of the order of battle, in list order
(0x4E86EC-0x4E88BE):

- **`inherit`'s mode, or surrender mode with no candidates:** `CGameState::RemoveUnit(state, unit, 0, 1)` for every
  one. The unit is destroyed. `RemoveUnit` is not fully read; what follows comes from the parts of it that were:
  - **Leader:** taken off with `CUnit::SetLeader(unit, CLeader::null(), 0, 0)` (0x6856C8-0x6856FE). He is not
    killed or deleted and stays in the annexed country's list.
  - **Battles:** `CUnit::LeaveAllCombats` runs first.
  - **Officers:** with the first flag clear, as here, the unit's share of officers (strength / max strength x its
    regiments' `officers`) x `OfficerRatio` is taken off the country's `officers`, floored at 0.
  - **Carried units:** a fleet's carried units are detached and entered into the fleet's province.
- **Surrender mode with candidates.** A unit's candidate is:
  1. for anything but an air unit (slot 17, `IsAir`), the controller of the province it stands in (+0x130), if that
     is a candidate. So an army on candidate ground, or a fleet in a candidate's port;
  2. otherwise, for an air unit with a base (+0x98), the controller of the base's province, if a candidate. **An air
     unit is judged by its base, never by where it is**;
  3. otherwise, for a naval unit (slot 16, `IsNavy`) in a sea province (`is_land` clear), **the first candidate in
     the list**.
- **The roll.** A unit with a candidate takes **one draw of `Random()`**, the game's own MT19937 at
  `g_random_seed`. On an even draw (`and 0x80000001` with the sign fix):
  - `CUnit_LeaveParent(unit, 1)`;
  - `CUnit_LeaveParent(child, 1)` for each direct child, **so the children are detached and stay behind**, each
    judged in turn when the walk reaches it;
  - the unit is unlinked from the annexed country's list;
  - `CCountry::AddUnit(candidate, unit)`, which appends it and sets the owner of the unit and its regiments. It keeps
    its leader, who still belongs to the annexed country.

  On an odd draw, `RemoveUnit`. **A unit with no candidate takes no draw.**
- Slots 15, 16 and 17 are `IsArmy`, `IsNavy` and `IsAir`. This was checked on `CArmy`, `CNavy` and `CAir`'s
  tables: `mov al,1` (0xA92590) sits in slot 15, 16 and 17 respectively.

**9. The land it occupied** (`ControlledProvinces` +0xD00, 0x4E88C4-0x4E89CD). Its own provinces have already
passed in step 4, so this is what it held of others. Each province gets `Province_SetController(p, X, now, 1, 0,
0)`:

- X is the owner;
- or, where the owner is a government in exile (+0x95) whose faction's first member has an id, X is **that first
  member**, the faction's leader.

**10. Rebuilds:** `DeleteAreaGroups`, `RebuildAreaGroups`, `DeleteSupplyGroups`, `RebuildSupplyGroups`, once.

**11. Every other country c**, in database order from index 0. Only the annexed is skipped; the annexer is included
(0x4E8A3C-0x4E8E34):

1. **Wars.** Where c's status toward it has a war, **the annexed country is taken out of that war**:
   `CWar::RemoveAttacker` if it is among the attackers, else `RemoveDefender`, with **recordHistory 1**. Once it is
   out, the war's other members find no war with it, so each war is left once. A side it led gets the next member as
   its first. A side it was alone on empties, and the war stays in `active_war` (`FINDINGS-war.md` C.13).
   `UpdateAtWarAndEnemies` clears `at_war` and mobilisation (C.9, C.8).
2. **Spies.** c's espionage entry on it (+0x1160 + id x 0xF8, entry +0) is set to 0. Only the level; c's mission
   shares are not touched.
3. **Alliance, dependency, guarantee** on c's status (+0x14, +0x18, +0x1C): each is unlinked from
   `CCurrentGameState +0xB2C`, deactivated (slot 11) and deleted. **The annexed country's puppets are set free and
   its overlord loses it**, with no message.
4. **Threat.** c's threat from it, and its threat from c (+0x5C), each **-9999.000, floored at 0**.
5. **Trade routes.** Every trade route on c's status: slot 11, unlinked, deleted.
6. **`CDiplomacyStatus::Reset(c->diplomacy[annexed])`.** This zeroes c's side only: the NAP, influence, alignment
   and embargo pointers (the objects stay in the relation list), relation, military access, `co_belligerent`, debt,
   `daily_repay`, `allowDebts` and `last_war`; it frees c's casus-belli list nodes (the objects are not deleted) and
   resets the occupation policy.

**12.** `CSupplyGroup::PickDepot` on each of **the annexer's** supply groups (+0xD50).

**What it does not do.** A store sweep of the body finds no write to the annexed country but +0xD8; the threat and
spy stores are found, which is the positive control. Among its calls there is **no** `RebuildNeighbours`, no
`0xE39C0` and no `OnDiplomacyChanged` for anyone, so allies, vassals and non-hostile lists everywhere are stale
until the next daily rebuild. There is also no interface refresh.

### A.4 Relations: cleared and kept, by side

| | c's status toward the annexed | the annexed's status toward c |
| --- | --- | --- |
| war | left (RemoveAttacker/RemoveDefender, history 1) | the same war, both ways |
| alliance, dependency, guarantee | object deactivated and deleted | the pointer is cleared by Deactivate (`CGuarantee`'s is recorded as both ways; the alliance's and dependency's not read) |
| trade routes | deleted | both lists (`CTradeRoute::Activate` appends to both) |
| NAP, embargo, influence, alignment | pointer nulled, object **left** in the relation list | **kept**, still pointing at it |
| casus belli | list nodes freed, objects left | **kept** |
| relation, access, debts, allowDebts, `last_war` | zeroed | **kept**, so the annexed's debts to others survive |
| threat | -9999, floor 0 | -9999, floor 0 |
| spies | c's level on it = 0 | kept |

### A.5 What is left of the annexed country

**Untouched by `AnnexCountry`:** stockpile, manpower, technology and research, leaders (those taken off units stay
in its list), ministers, laws, government, convoys, capital and acting capital (the capital province is now the
annexer's), its own diplomatic statuses as in A.4, and its AI. Its officers are lower by the destroyed units' share.

**Nothing marks it dead.** A dead country is one that owns no province. The record shows what that means
elsewhere:

- its units would be destroyed every hour unless it is in exile or `REB` (`RunCountryHourlyPass`, 0x4D8FFD), but it
  has none left;
- `RemoveLandlessCountriesFromWars` runs as a session is entered;
- `SpreadThreat` gives it factor 1001;
- the surrender gate needs a province.

**The savegames.** The 20 April 1936 save has 23 tags that own nothing: `REB` and 22 never-born ones (ICL, VIC, CRO,
DDR, DFR, SLO, RSI, SPA, ISR, JOR, LEB, PAL, SYR, IND, PAK, KOR, MEN, PRK, IDC, INO, EGY, GUY). None was annexed in
play, so no save shows an annexation. They do show that a landless country keeps a full block: `capital` and
`acting_capital`, its pools (KOR's `home` holds supplies 747.040 and money 17.982), technology, officers, manpower,
government, ministers, laws, `last_surrender`, and a diplomacy block toward each country that owns land. No key
marks it dead.

**What a later `release` revives** is all of the above, the one-sided leftovers of A.4 included. That is inferred,
since `ReleaseProvinces` is still `inferred` (`FINDINGS-effectrun.md` 2.9).

### A.6 The annexer's gain

The annexer gains **the provinces nobody else occupies, and nothing else from `AnnexCountry`**: no money, manpower,
technology, units or cores. The candidates in surrender mode are the annexed country's partners, never the annexer.
Whatever the province changes bring is `ChangeOwner`'s and `Province_SetController`'s (section D).

### A.7 Order, and what the player sees

- The message comes first, so its capital is still the annexed country's when it is shown.
- The faction exit comes before the land changes hands, so the "leaves its faction when it owns nothing" step inside
  `ChangeOwner` finds the null faction.
- The provinces change hands before the units go and **before the wars end**. With `peaceful` 0 and the two still at
  war, the controller setter's pushback damage and its rebasing of enemy air and naval units can apply (section D).
- In surrender mode the candidate controllers are decided province by province over stale areas.
- In a capitulation, `Enforce` calls `AnnexCountry` before `CCountry_Capitulate` takes the country out of the war
  itself. The capitulation's removal (0x4E9893-0x4E9905) searches both sides first and finds nothing, so the war
  removal with history 1 is the one that counts.

### A.8 The outline in `FINDINGS-effectrun.md` 2.8, checked

| step | verdict |
| --- | --- |
| 1 (message) | Right. It goes to everyone. |
| 2 (faction) | Right. |
| 3 (provinces) | Right; flags `(1, 0, 0)`. A candidate's area is judged by its first province's controller. |
| 4 (constructions; expeditionary units) | Constructions right. Expeditionary units incomplete: two lists, as in step 7 above. |
| 5 (units) | The rule is right. Wrong on "goes over with its children". Incomplete on fleets in port, on air units being judged only by their base, and on the draw being taken only for a unit with a candidate. |
| 6 (occupied land) | Right, with the exile's faction leader. |
| 7 (wars and relations) | The annexed country leaves the wars, not "every country leaves". The rest is right, but applied to the other side only. |
| 8 (pacts kept) | Wrong as stated; see A.4. |

### A.9 What looks wrong and is what the bytes do

1. Every player is shown `ANNEX`, with his own foreign minister and monarch title, and the map text is empty.
2. Any occupier keeps the annexed country's land, an ally of the annexed or a neutral included. The annexer gets only
   what nobody else holds.
3. In surrender mode the annexer owns land that its enemy controls. The chooser reads a neighbouring area's first
   province as it stands mid-loop, so control can spread from one of the annexed country's own areas to the next.
4. A fleet at sea goes to the *first* candidate in the list, wherever that candidate is.
5. A transferred unit leaves its children behind, and each child gets its own draw.
6. A transferred unit keeps a leader who belongs to the dead country.
7. Units it lent out are recalled only to be destroyed. Units lent to it are shattered on the way home.
8. Threat falls by a flat 9999.000, not to zero.
9. The other side's NAP, embargo, influence, alignment and casus belli are dropped from its status but never
   deleted; the dead country's side keeps them, and its debts.
10. Nothing refreshes anybody's neighbour or alliance lists until the next day.
11. A faction it led gets a new leader only by list order, silently.
12. The `surrender` console command annexes the *first* tag to the *second*, in surrender mode.

### A.10 Not settled

- **Callees' deactivation:** whether slot 11 of `CAlliance`, `CDependency` and `CTradeRoute` clears both directions
  (only `CGuarantee`'s is recorded), and what a `CConstruction`'s destructor undoes in its province.
- **Objects left behind:** whether any daily or monthly pass acts on the NAP, embargo, influence, alignment and
  casus-belli objects left in the relation list with a dead party.
- **`RemoveUnit`:** its second flag (here 1), and its carried-unit branch, read only in outline.
- **`ReturnFromExpedition`'s unread callees:** `0x5D3840` and `0x8A2E00`.
- **The Goto callback `0x6995D0`:** only its first block was read.
- **No savegame holds an annexation.**

### A.11 Frontier (rvas)

`0x5F300` (list destructor, 94 callers), `0x4BA2A0` and `0x499F70` (AI agent release on detach), `0x4A2E00`,
`0x1D3840`, `0x1D37D0` (in `ReturnFromExpedition`), `0x5C5500` (null mission), `0xD4BE0` (`CEventScope` assign),
`0x2999E0`, `0x2995D0` (message Goto), `0x284CE0` (`RemoveUnit` tail). Also slot 11 of `CAlliance`, `CDependency`
and `CTradeRoute`, and `CConstruction`'s destructor.

**Traps and record notes:** trap 14 - `CCountry +0xE38` is typed `CPersistent*` but is an embedded `CActiveMission`;
its `mission` (+0xE40) and `mission_scope` (+0xE44) are that object's +8 and +0xC; the type is left for the
collector. `FINDINGS-distribute.md` gives `0x4DB418` as "`0x5020E0(country)`"; the unit is in ECX. No trap 2 or 3
in this function: one `ret 0x10` and seven `int3` after it.

Function table: `0xE7B00` AnnexCountry revised confirmed; `0x401E0` ConsoleCmd_Surrender new confirmed;
`0x1020E0` CUnit::ReturnFromExpedition new inferred; `0x1B9A30` CUnit_LeaveParent new confirmed; `0xE06F0`
CCountry::AddUnit new confirmed; `0x1BC460` CUnit_SetOwner new confirmed; `0x10F820` CCountryList_AppendAll new
confirmed; `0x5C7150` CActiveMission_Construct new confirmed; `0xD4B90` CActiveMission_Assign new confirmed. Fields:
CCountry 0xBBC expeditionary_units_lent CUnitList new; CCountry 0xD50 supply_groups CList<CSupplyGroup*> new.

## B. The puppet, and the tail of a diplomatic change

Fragment `fragments/merged/vassal.json`. Texts are Their Finest Hour's English.

### B.1 In one line

A puppet is made in one call, `MakeVassal` (`0x4D94A0`, rva `0xD94A0`), in this order:

1. The vassal's provinces carrying an overlord core go to the overlord.
2. Its own cores the overlord's side holds come back to it.
3. It leaves its faction and every war.
4. Every bilateral agreement it has with anyone is torn down.
5. It gets a fresh alliance with the overlord, the overlord's alignment, membership of the overlord's faction
   (joining the faction leader's wars), a `CVassal`, relation +200, and the overlord's government with a
   refilled cabinet.

No message, no threat, no event. The tail every diplomatic change runs, `CCountry_AfterDiplomacyChange`, only
re-measures NAP borders, rebuilds the AI strategy at most every ten days, and refreshes the diplomacy screen.

### B.2 `MakeVassal` (`0x4D94A0`-`0x4DA447`, rva `0xD94A0`)

**Calling convention.** `void __cdecl (CCountryTag overlord, CCountryTag vassal)`: both tags by value, overlord
first (stack +4/+8), vassal second (+0xC/+0x10). It ends in a bare `ret` and the caller cleans (`add esp, 0x10`
at `0x50C223`). There is no guard of its own: one country on both sides is not refused, and neither is an
existing bond. `create_vassal` makes its own checks (already its vassal, or TAG owns nothing,
`FINDINGS-effectrun.md` 2.7); `po_puppet` and the exile swap make none.

**Callers (VAs):**

- `CCreateVassalEffect::Execute`, `0x9B8586`.
- `CWarGoal::Enforce`'s `po_puppet`, `0x47B244` (`FINDINGS-war.md` D.4).
- `0x50C21E`, in rva `0x10C0B0`, unnamed: **the government-in-exile swap.** It counts the share of the exile's
  owned provinces held by the controller of its capital. At or above a threshold read from the global at VA
  `0x1A87488` (0 in the file, so filled at run time), it calls `MakeVassal(capital's controller, exile)`, then
  `SetGovernmentInExile(exile, 0)`, then sends one of three messages:
  - `GIESWAP`: "Regime Change" / "$VICTIM$ is now a puppet of the $FACTION$." / "We have installed a loyal
    $GOVERNMENT$ government in $CAPITAL$."
  - `GIESWAPFORUS`
  - `GIESWAPOTHER`: "...$BOSS$ have installed a loyal $GOVERNMENT$ government in $CAPITAL$."; log "$BOSS$ has made
    $VICTIM$ into a new $FACTION$ puppet."
  - All three are log, popup and on the map, `cat_diplomacy`.
  - This function is brief C's ground. Only its call to `MakeVassal` and its message keys were read here.

**In order:**

1. **`now`** is the game tick, kept in a local and passed by address to every setter below.
2. **Provinces to the overlord.** For each province the vassal owns (`OwnedProvinces`, list order), the
   province's core list is walked to the **first** node whose id is the overlord's.
   - If the province's controller is **the vassal or the overlord**: `CMapProvince::ChangeOwner(p, overlord, now,
     applyConsequences 0, rebuildAreas 0, peaceful 1)`. The overlord takes ownership and control.
   - A province of the vassal's that a third country occupies stays the vassal's.
3. **Cores given back to the vassal.** For each of the vassal's own cores (`CoreProvinces`) that **the vassal
   owns**, where the controller is the overlord, or the overlord's faction is real and the controller is a member
   of that same faction: `Province_SetController(p, vassal, now, applyConsequences 1, rebuildAreas 0, peaceful 1)`.
   What those flags do inside the two setters is section D's.
4. **The vassal leaves its faction**, inline rather than through `CCountry::LeaveFaction`.
   - If its faction is real: `CFaction::RemoveMember`, `faction = CFaction::null()`, `RebuildStaticModifiers`,
     `RebuildRules`, and the per-country display dirty byte.
   - **No history entry.**
   - If it was already in the overlord's faction, it is taken out here and put back at the tail in step 9.
5. **The vassal leaves every war** in `active_war`: `CWar::RemoveAttacker` if it is an attacker, else
   `RemoveDefender`, with recordHistory 0. Leaving deletes its war goals and every goal against it, and ends
   influence and trade routes with each enemy (`FINDINGS-war.md` C.9).
6. **Every bilateral agreement torn down.** For every country X, on the vassal's own status toward X:
   - Each non-null relation object is deactivated (slot 11), unlinked from the game's relation list and deleted,
     in this order: alliance, dependency, NAP, embargo, align, influence.
     - Alliance, dependency, NAP and embargo are one object for both directions, so these end both ways. In
       particular **every puppet the vassal itself had is freed**, along with any old overlord bond.
     - Align and influence are one-way objects. What ends is the vassal's own aligning of others and **others'
       influence on the vassal**. The vassal's influence on others, and others' aligning of it, are kept.
   - Military access is cleared both ways (`SetMilitaryAccess(0)` on each side).
   - **The guarantee pointer is nulled both ways, but the `CGuarantee` is neither deactivated nor deleted.** It
     stays in the relation list.
   - `allowDebts` is cleared both ways.
   - X runs over every country, the overlord included, so their old alliance is deleted here before a new one is
     made.
7. **A new `CAlliance`**: first the overlord, second the vassal, start date now, no end date. It is activated
   (both directions) and then appended to the relation list.
8. **Alignment:** the vassal's triangle position (`+0xE4`/`+0xE8`) is set to the overlord's.
9. **If the overlord's faction is real:** `CFaction::AddCountry(faction, vassal, recordInHistory 0,
   joinOngoingWars 1)`. The vassal is not yet a subject at this point (its old dependency was just deleted and the
   `CVassal` comes next), so `AddCountry`'s overlord filter does not apply. Its war sweep (re-checked on the
   listing at `0x4F6183`-`0x4F6355`) puts the vassal into **every war the faction leader is in**:
   - as an attacker where the leader attacks and the war is not limited;
   - as a defender where the leader defends;
   - each time with `CCountry::ChangeRelation` of `-WARDEC_WAR_DIPLOMACY_HIT` (100.0 in Their Finest Hour) toward
     every enemy.

   **These are the faction leader's wars, not the overlord's:** a puppet of a faction member does not join a war
   the member fights without its leader.
   - **With no real faction the vassal joins no war at all** and ends at peace with everyone, including the
     overlord's enemies.
   - In a running game, `AddCountry` also runs `OnDiplomacyChanged`, the modifier and rules rebuilds, and the AI
     rebuilds on the vassal and its neighbours.
10. **A new `CVassal`**: first the overlord, second the vassal, start date now. It is written onto the overlord's
    status toward the vassal, appended to the relation list, then activated. Activation writes both directions
    and runs `CCountry::UpdateSubjectStatus` on both, which sets `isSubject` and `Overlord`.
11. **Relation:** `r = clamp(overlord's relation toward vassal + 500.000, -200.000, +200.000)`, written to
    **both** directions. So it is +200, and the vassal's own previous figure is discarded.
12. **Government:**
    - `CCountry_SetGovernment(vassal, overlord's Government, logHistory 1)`: the government type, a history entry,
      and an AI strategy rebuild.
    - `CCountry_FillMinisterPosts(vassal, refillAll 1, electedOnly 0)`: every post refilled from the vassal's own
      possible ministers.
    - Nothing else is copied: not laws, not the ruling party, not ideology. Only the government and the alignment
      position.
13. **Refreshes:**
    - `CCountry_RefreshDiplomacy` (`RebuildNeighbours` + `AfterDiplomacyChange`) on the vassal, then the overlord.
    - `CCountry::OnDiplomacyChanged` on the overlord, then the vassal.
    - Then the area groups and supply groups are deleted and rebuilt.

**Untouched:** threat, neutrality, national unity, laws, casus belli, debt (only the `allowDebts` byte), trade
routes other than with former enemies, spies, occupation policy, technology. **No message and no event.** At a
capitulation the player hears of a puppet only through `Enforce`'s `THEYSURRENDER*`/`WESURRENDER`.

**The start-date save agrees with the shape.** Its `diplomacy=` list holds 9 `vassal` blocks and 9 `alliance`
blocks, each pair with the overlord as `first` (e.g. SOV/TAN, SOV/MON).

### B.3 Where the old outline (`FINDINGS-effectrun.md` 2.7 and the record) stands

| step | verdict |
| --- | --- |
| 1 | Right. Add: the test stops at the first overlord core node, and the flags are (0, 0, 1). |
| 2 | Right. Add: only cores the vassal owns; the flags are (1, 0, 1). |
| 3 | Right. Add: the exit is inline, with no history. |
| 4 | Right, but incomplete: the vassal's own dependencies end too, so its puppets go free; and align and influence each end in one direction only. |
| 5 | Right. The alignment copy comes **before** `AddCountry`. |
| 6 | Right on the call, wrong in its gloss "joins the faction's wars": it joins the **faction leader's** wars, not limited ones as an attacker, with the -100 relation hit. And "with no faction ... at peace with everyone" is right. |
| 7 | Right. |
| 8 | Right in effect. The vassal's side is overwritten with the overlord's figure. |
| 9 | Right as far as the calls go. |
| 10 | Right, with the order RefreshDiplomacy vassal/overlord, then OnDiplomacyChanged overlord/vassal. |

### B.4 What a capitulation does with it (from composing D.3 with B.2; inferred, both halves read on the listing)

- A `po_puppet` goal takes the surrendering country out of **every** war inside `MakeVassal`, so "it stays in the
  war" (`FINDINGS-war.md` D.3 step 8) cannot hold for a country that was puppeted, even when another goal handles
  peace. D.3's step 7 then removes it again from a war it is no longer in.
- `MakeVassal` deletes the surrendering country's own dependencies and rebuilds its `Vassals` list
  (`RebuildNeighbours` builds `+0xF78` from `+0x18`). So D.3 step 7's "copy of `Vassals`", taken after the goals,
  should be empty. **A puppeted country's former puppets would then be freed, neither released nor puppeted to the
  victor, and left in the war.** This rests on step 7 copying `Vassals` after `Enforce` runs, which is D.3's order.

### B.5 `CCountry_AfterDiplomacyChange` (`0x4E39C0`-`0x4E3EA0`, rva `0xE39C0`)

`void __stdcall (CCountry*)`, `ret 4`, 65 direct callers, most through `CCountry_RefreshDiplomacy` after
`RebuildNeighbours`.

0. **Gates:** the country has an id, is not `REB`, and has its byte `+0x44` set. That byte is unnamed; it is the
   same one the hourly and daily country loops skip on.
1. **NAP force balances.** For every country C in the country database (count `+0x168`) that is not this country,
   not id 0, not `REB`, and owns a province: if the NAP between them exists and has **this** country as `first`,
   `CNap_UpdateForceBalance`.
   - Outside a running game, always.
   - In a running game, only on a day of the year divisible by 7, or where the pact's balance is negative.
   - A pact whose `first` is the other party waits for that party's call.
2. **AI:** in a running game, if 10 or more whole days have passed since the strategy was last rebuilt,
   `CAIStrategy::Rebuild` and `theatres_dirty = 1`, so the theatres are rebuilt next hour.
3. **The screen:** if the in-game screen exists and the game is running, its slot 101 (`RefreshDiplomacyView`)
   with `(tag, 0)`.

**It does not recompute** at-war lists, neighbours, allies, area or supply groups, factions or relations. Those
come from its callers: `RebuildNeighbours` just before it, `UpdateAtWarAndEnemies` inside the war functions, and
the group rebuilds `MakeVassal` and the capitulation call themselves. So for a peace, a capitulation or a new
puppet, what this tail makes visible is:

- the NAP balance that `CanBreakNap` reads;
- a fresh AI strategy and theatres, at most once in ten days per country;
- a redrawn diplomacy view.

### B.6 What looks wrong and is what the bytes do

1. The orphaned `CGuarantee` stays in the relation list. The loader activates every relation it reads, so **after
   a save and load the guarantee comes back** (inferred from the loader's record).
2. A puppet joins the **faction leader's** wars, not its overlord's. With no faction it joins none, and stays at
   peace with the overlord's enemies.
3. The vassal's own puppets are freed, and their alliances with it deleted, without a word.
4. Influence on the vassal ends; the vassal's influence on others continues. Its own align drifts end; others'
   aligning of it continues.
5. Casus belli, debt and trade routes with non-enemies survive the change of masters.
6. A vassal province held by a third country stays the vassal's, even with an overlord core.
7. The cabinet is refilled whole from the vassal's own ministers under the overlord's government type. Laws and
   ruling party are kept.
8. `MakeVassal` sends no message of its own.

### B.7 Not settled

- What the setter flags (0, 0, 1) and (1, 0, 1) do inside `ChangeOwner` and `Province_SetController`: section D.
- Byte `+0x44` (unnamed).
- `+0xB38`, the relation list's no-unlink byte, was read only as such.
- The exile swap `0x10C0B0`: its threshold global `0x1A87488` and its `GIESWAPFORUS` text were not read
  (section C).
- B.4's consequences are composed, not observed. No save holds a capitulation.
- `CCountryDataBase +0x168` rests on two of the 61 candidate readers.

### B.8 Frontier (rvas)

`0x10C0B0` (the exile swap), `0x5F5E0` (the refresh-request push), `0x122650` (`CFaction::AddMember`, not
re-read).

**Traps met:** trap 1 - `0x47B244` is a VA; `functionStart(0x47B244)` answers `0x47AC98`, which is not
`Enforce`'s entry (`0x47A950`), so the caller was attributed from D.4. Decompiler: Ghidra prints
`free(node); return;` inside each relation-deletion block; the listing continues to the delete and the next field
(`0x4D9979`-`0x4D9987`); there is no early return.

Function table: `0xD94A0` MakeVassal revised, confirmed (inferred -> confirmed; setter flags, inline faction exit,
deletion order and directions, the vassal's puppets freed, the leader's wars via AddCountry, the relation
overwrite, the third caller, no message); `0xE39C0` CCountry_AfterDiplomacyChange revised, confirmed (the loop is
the CCountryDataBase count, the 7-day throttle only in a running game, the 10-day count in whole days, the screen
refresh slot 101 (tag, 0)). Field: `CCountryDataBase +0x168 country_count int` new.

## C. The government in exile

Fragment `fragments/merged/exile.json`. Texts are Their Finest Hour's English.

### C.1 In one line

- **Going into exile** (`SetGovernmentInExile(country, 1)`): manpower and officers are *cut* to a tenth; the
  country's own money goes and its whole build queue is deleted; every unit standing on ground held by a non-friend
  is destroyed, except lent units, which go home; a faction leader hands the lead to its biggest member; the
  government moves into the faction leader's acting capital, and with it every trade route goes.
- From then on, the exile keeps a stockpile of its own (`pool_in_exile`) and hands its supplies and fuel to its host
  every day; never surrenders, never has occupied land returned by the daily pass, and never loses its land to the
  capture rule; gets anything it conquers taken by its faction leader; builds at its leader's technology; draws
  supply from friends for free; may not ally, join a faction, take or give debt, lend-lease, or trade unless it owns
  its acting capital.
- **It ends** in any of five ways: **liberation** (a faction member holding its capital posts
  `CLiberateCountryCommand`); **the puppet swap** (a non-enemy outside its faction holds half its land); **leading
  its faction** (it leaves the faction); **`form_government_in_exile = no`**; **a history line**.
- **Coming back** resets the acting capital to the capital and turns partisan brigades into militia. Nothing that
  was cut is restored.

### C.2 `SetGovernmentInExile` (`0x502BC0`, rva `0x102BC0`)

`void __stdcall (CCountry* country, bool inExile)`, `0x502BC0` to the `ret 8` at `0x5033AD`. All four `ret 8`
(`0x50315F`, `0x503376`, `0x503393`, `0x5033AD`) belong to one frame. Read whole on the listing. Seven callers:

| caller | site | value |
| --- | --- | --- |
| CWarGoal::Enforce, the po_annex exile | `0x47ADAF` | 1 |
| RunCountryDailyPass (C.5) | `0x4DBE6E` | 0 |
| CCountry_ReplaceExileWithPuppet (C.4) | `0x50C228` | 0 |
| CLiberateCountryCommand::Execute | `0x54D8FE` | 0 |
| CExileStatusChange::Apply, forward | `0x5F1EDD` | the history value |
| CExileStatusChange::Apply, back | `0x5F1EF9` | the history value |
| CFormGovernmentInExileAction::Execute | `0x9BB1AB` | the effect's value |

**1. Convention, and a repeated call.** Both arguments are on the stack. Already in exile with 1: the flag is stored
again and nothing else happens (`0x503396`). Not in exile with 0: only the flag is stored; the acting capital is
**not** reset. Any byte other than 0 or 1: stored as the flag, nothing else (`0x503379`).

**Going into exile (`inExile` 1), in order:**

1. **Money and the flag.** `pool_in_exile.money` (`+0xA08` = `+0x9F8 + 0x10`) is set to 0, then
   `government_in_exile` (`+0x95`) to 1. From now on every stockpile read and write goes to `pool_in_exile`, which
   normally holds nothing. What lay in the old acting capital's province pool stays in that province. The other six
   goods of `pool_in_exile` are not touched.
2. **Manpower and officers to a tenth.** Each is `x * f / 1000`, a 64-bit product through `__alldiv`, so it
   **truncates toward zero** in thousandths; `f = _ftol2_sse(floorf(100.5f)) = 100`, from the float at `0x160A684`
   (bytes `0000c942`). The outline's "floor(100.5) / 1000" is right.
3. **The build queue is deleted.** Every line of `Constructions` (`+0xF40`) - units, buildings, convoys - is
   destroyed through slot 0 (the scalar deleting destructor, with 1), then the list is freed.
4. **Units on unfriendly ground.** The walk covers every unit of `Units` (`+0xBAC`), at every level and in list
   order. A unit is tested only if its province (`+0x130`) has a controller (`controller_id +0x338` non-zero). **So
   a unit at sea is never tested and always survives.** A fleet in port, or an air unit at a base, is tested like a
   land unit. Its ground is unfriendly when `CCountry::IsFriend(controller, exile, includeRequested 1)` is false.
   IsFriend is true when the controller is the exile itself; the exile's overlord, or its puppet; another puppet of
   the same overlord; in the same real faction; its ally; co-belligerent (`+0x58`) and not its enemy; or the
   controller's status toward the exile has military access (`+0x4C`). Anything else is unfriendly, `REB` included.
   On unfriendly ground, a unit with no expeditionary owner (`+0x290 == 0`) is destroyed on the spot by
   `CGameState::RemoveUnit(unit, 0, 0)`. A unit **lent to** the exile is set aside.
5. **Lent units go home.** Each one set aside goes through `CUnit::ReturnFromExpedition(unit, exile)` (`0x5020E0`;
   section A) and back to its lender's units. The message goes only where the local player is the exile or the
   lender (ACTOR the exile, RECIPIENT the lender, NAME the unit, at the unit's province): `EXPRETURNEDWE` to the
   exile's player, `EXPRETURNED` to the lender's. Then `CCountry::ShatterUnit(lender, unit)`: the unit goes to the
   lender's acting capital, or to its current province's depot where that depot's controller is no enemy.
6. **A new faction leader** (`0x502E2A`-`0x502F39`), only where the faction is real, the exile is its first member
   and the faction has two or more members. The new leader is the member with the **strictly** greatest `max_ic`
   (`+0x60C`) x 1000, among members not in exile and not the exile itself. The best starts at 0, so a member with
   `max_ic` 0 is never chosen, and of equals the first in member order wins. That member is taken out
   (`CFaction::RemoveMember`) and pushed to the front (`CountryTagList_PushFront`); `members_changed` is set. The
   rest of the order is untouched, so the exile becomes second. If nobody qualifies, the exile stays leader, and C.5
   ends the exile the next day.
7. **The acting capital**, only where the faction is real and its first member is not the exile:
   `CCountry_SetActingCapital(exile, leader->acting_capital_province_id (+0xE24))` - **the exile's government sits
   in the leader's own acting capital province.** Otherwise the acting capital does not change. The real capital
   (`+0xE20`) never changes.
8. **Trade routes.** Where `GetActingCapitalLocation(exile)->owner_id (+0x330)` is then not the exile, every route
   on every one of the exile's diplomacy statuses (`+0xE28[i]->trade_routes`, `+0x60`) is deactivated (slot 11),
   unlinked from the relation list (`+0xB24`, head `+0xB2C`) and freed - only *marked* while that list's byte
   `+0x14` is set - and deleted through slot 0. So routes go exactly when step 7 moved the government into the
   leader's land. A factionless exile, or one that stays leader, keeps its routes as long as it still owns its own
   capital - which it usually does, because `Enforce`'s exile arm takes control of its land, not ownership.
9. The flag is stored again.

**There is no message of the exile's own** - only the expedition messages above.

**Coming back (`inExile` 0, while in exile):** every unit for which slot 15 answers true - land units only (CArmy's
slot is `mov al,1`, CNavy's and CAir's `xor al,al`) - has every regiment (`+0x38`) whose type's
`supply_consumption` (`+0x110`) is **0 or less** changed to the type named by `CDefines +0x80`, if the subunit
database knows that name. `+0x80` is defines.lua's top-level `base_militia = 'militia_brigade'`, assigned by
`LoadDefines` at `0x4468D2`. In Their Finest Hour only `partisan_brigade` has 0, so **an exile's partisans become
militia**. The conversion is `CSubUnit_ConvertType` (`0x5ABDD0`): SetType, technology levels kept where the new
type shares them, then ApplyTechnologies; after the regiments, `CUnit::RebuildDefinition(unit, 0)`. Then
`acting_capital = capital` (`+0xE20` -> `+0xE24`) and the flag is cleared. Nothing else is restored: not
manpower, officers, money, the queue, the routes or the faction place.

### C.3 What the outline had wrong or missed

`FINDINGS-effectrun.md` 2.12 and the old record: the tenth is right. "Units on unfriendly ground" is right but
incomplete: sea is exempt, the friend test is IsFriend with military access, and lent units are returned rather
than removed. "Moves the acting capital toward the faction leader's" is wrong: it *becomes* the leader's own
acting capital province, and only when the exile is not the leader. "May delete every trade route" is now exact -
when the acting capital is not the exile's own. `+0xA08` is `pool_in_exile.money`. Land regiments with supply
consumption of 0 or less are converted to `base_militia`, which the record did not name.

### C.4 The puppet swap - `CCountry_ReplaceExileWithPuppet` (`0x50C0B0`, rva `0x10C0B0`)

**The daily gate** in RunCountryDailyPass, `0x4DA6B9`-`0x4DA722` (`ExileDaily_PuppetSwapGate`): the game state's
`+0xD0C` (scenario) is null; the country is in exile; C, the controller of its **real** capital, is not
`IsEnemyTag` of it; C's faction pointer differs from the exile's; and the exile's status toward C has no truce
(`HasTruce`). Two countries in no faction share the null faction object, so **a factionless exile is never swapped
to a factionless holder**.

**The test.** `share = 1000 x (owned provinces C controls) / owned count`, truncated; 0 with nothing owned. **Where
`share >= 500`** (`(int)floorf(500.5f)`, a static at `0x1A87488`):

1. `MakeVassal(C, exile)`, with C as overlord.
2. `SetGovernmentInExile(exile, 0)`.
3. One message to every player. Variables: FACTION = C's faction's name, BOSS = C, VICTIM = the exile, CAPITAL =
   the exile's capital province, GOVERNMENT = the exile's government after MakeVassal. All three types are log, on
   the map, popup and `cat_diplomacy`, and show "Puppet Created!" on the map.

| who | key | what it says |
| --- | --- | --- |
| C's player | `GIESWAP` | "Regime Change / $VICTIM$ is now a puppet of the $FACTION$. / We have installed a loyal $GOVERNMENT$ government in $CAPITAL$." |
| the exile's player | `GIESWAPFORUS` | "...We are now a puppet of the $FACTION$. / $BOSS$ have installed..." |
| anyone else | `GIESWAPOTHER` | "...$BOSS$ have installed a loyal $GOVERNMENT$ government in $CAPITAL$." |

### C.5 The daily pass and the hourly pass

- **An exile that leads its faction** (`0x4DBE24`), every day the country does not surrender - always, for an
  exile: if the faction is real, has at least one member, and the exile is its first member, `CCountry::LeaveFaction
  (country, 0)`, then `SetGovernmentInExile(country, 0)`. **So a faction leader is never an exile for longer than a
  day.**
- **Supplies and fuel to the host** (`0x4DB44E`). First the day's `CollectDailyProduction`, `RunDailyTradeRoutes`,
  `UpdateIC` and `ConvertCrudeOilToFuel` run, for a country that owns land **or** is in exile. Then
  `pool_in_exile`'s supplies and fuel are added to the `received_from_exiles` ledger (`+0xA64`) of the country
  controlling the exile's acting capital - income in its `GetDailyIncome`, likely the ledger line
  `LEDGER_FROM_EXILES` "From Exiles" - and to that province's pool. The exile's two are then zeroed. Money, crude
  oil, metal, energy and rare materials stay in `pool_in_exile`.
- **The supply cap is skipped** (`0x4DBE73`): a country not in exile has its supplies at `+0xA24` held at most to
  the `SupplyCapacity` of its acting capital; an exile skips this.
- **The rest of the day for a landless exile**: the daily espionage pass (`0x4DB934`) and the stockpile clamp
  (`0x4DB73E`, every good between 0 and 999,999) run against `pool_in_exile`.
- **Every hour** (`0x4D90CB`): if an enemy controls an exile's acting capital, and its faction is real and led by
  someone else, the acting capital becomes the leader's.
- **Every hour, the units of a landless country** (`0x4D8FEC`) are destroyed - but not an exile's.

### C.6 Where it is saved, loaded and set

- **Savegame:** `government_in_exile=yes` inside the country's block, written only when set (`SaveContents`,
  `0x4CFED0`; token `0x583`), loaded by `CCountry::LoadKey` through ParseBool. None of the maintainer's 12 saves
  contains one.
- **History:** `government_in_exile = yes` on a dated line, through `CExileStatusChange`, whose Apply calls
  `SetGovernmentInExile` in full. The base game has it for ten countries: POL 1939.9.28, BEL 1940.5.28, DEN
  1940.4.10, NOR 1940.5.10 and 1941.6.22, GRE 1941.4.30, YUG 1941.4.17, FRA 1941.6.22, PHI 1942.4.9, HOL 1942.6.4,
  ALB 1943.9.8. None applies at a 1936 start.
- **Lua:** `CCountry::IsGovernmentInExile` (`0xB4EAE0`, `mov al,[ecx+0x95]; ret`).
- **Effect and trigger:** `form_government_in_exile` sets it; `government_in_exile = yes|no` tests it (`0x9E0F90`).

### C.7 Every reader of `+0x95`, and what being in exile changes

**How they were found.** `.text` swept in int3-separated chunks with resume, two chunkings unioned, every
byte-sized memory operand with displacement `0x95`: 190 sites, 5.5 M instructions. Both controls were found:
`0x9E0FB4` and `0x4FCB87`. Not `CCountry`: `0x431ED6` and `0x59CED5`/`0x59D17F` (CUnit `+0x95`, the patrol-shadow
byte), `0x4B6D78` (CBuilding), `0x63FA66` (the building type's visibility), `0xB4EDB2`/`0xB4EDDD` (a GUI class),
`0x7E85FB`, `0xBE4D2F`/`0xBE4D36` (stack slots). The rest, about 170 sites in 85 functions, are `CCountry`;
Ghidra's typed decompile names them `isGovernmentInExile`; the important ones were spot-checked on the listing.

**Surrender and war**

- `GetSurrenderProgress` `0x4FCB87` (rva `0xFCB80`): answers 0, so **an exile never surrenders**.
- `BuildSurrenderDetails` `0x4FCD19`: the tooltip is `WE_ARE_GOV_EXILE` "We are a government in exile and cannot
  surrender again.", or the name plus `IS_IN_EXILE` "is a government in exile."
- `CWarGoal::Enforce` `0x47AAC8`: an exile cannot host another exile. `0x47AE00`: with no host, every exile in the
  annexed country's faction is annexed as well.
- `CCountry_Capitulate` `0x4E9EFB`: land the capitulating country occupied is returned to an exiled owner when their
  war is this one.
- `AnnexCountry` `0x4E896B`: land the annexed country controlled goes back to its owner, but to the faction leader
  where the owner is an exile.
- `RemoveLandlessCountriesFromWars` `0x689EF8`: a landless exile stays in its wars and its faction.

**Land changing hands**

- `RunDailyProvincePass` `0x49F1B1`: **land occupied from an exile is never returned by the daily pass.**
- `CMapProvince::TakeControl` `0x4A1DF9`: when an exile that is not its faction's leader (in a faction of two or
  more) takes a province, the **faction leader** takes it instead. `0x4A1ED9`: a province freed from an enemy goes
  back to its owner, unless the owner is an exile - then the liberator keeps it.
- `CreateRebelsForFaction` `0x4BAA9D`: the pre-revolt owner/controller pair is not recorded for an exile.

**The stockpile is `pool_in_exile`.** These read or write the pool (GetPool, inlined or called): the economy -
`GetPool` `0x4F4DE1`, `UpdateIC` (`0x4F1001`/`107D`/`109A`), `GetResourceLimitedIC` (x3), `ConsumeIcResources`
(x3), `ConvertCrudeOilToFuel` (x8), `CollectDailyProduction` (x7, debt repayments included), `RunDailyTradeRoutes`
(x4); convoys and lend-lease - `CConvoy::RunDelivery` `0x4C6D24`/`0x4C71C8`; the distributions -
`CDistributeConsumerGoods` `0x518CB2`, `CDistributeSupply` `0x51AD76`; supply - `CUnit::ConsumeSuppliesAndFuel`
(`0x5BBA55`...`0x5BC26C`), `CUnit::CarrySupplies` `0x5BEDAC`, `RunSupplyAndConvoyIterations` `0x678E54`/`0x678FF4`;
diplomacy and laws - `CLicenceTechnologyAction::Apply` (`0xA3C31B`/`C5C4`/`C5FD`), `CChangeLawCommand::Execute`
`0x54EFFC`, the law entries `0x6B9743`/`0x6BA00D`; script - the seven goods effects (`0x9B1D7C`...`0x9B477C`) and
the six goods triggers (`0x9F5E98`...`0x9F6FC8`); the interface and tools - `CTopBar::FormatGoodsNumber` (x3),
`CTopBar::Update` `0x6CA29D` and `CTopBar::BuildTooltip` `0x6CCE3A`/`87` (fuel and supplies shown as "-"),
`CProductionView::SetGoodsText` `0x7FD251`, `CAlertManager_Update` `0x604944`,
`CLicenceTechnologyDialog::GetOfferedMoney` `0x77BC47`, the espionage view's perturbed stock `0x61D446`,
`CResourceValues` `0x8EA9FE` (AI Lua), the console's resource commands `0x43E2C8`-`0x43F4FE`. Puppet tribute (rva
`0xF25E0`, unnamed; called from CollectDailyProduction): `0x4F268F` a puppet pays nothing while in exile;
`0x4F2771`/`0x4F27B7` the tribute's source and destination pools.

**Supply.** `CUnit::ConsumeSuppliesAndFuel` `0x5BBD8B`: **an exile's units draw on a friend's depot for free** - the
payment (the price, `TradedAway`, `TradedFor`) is skipped.

**Manpower.** `GetMonthlyManpowerGain` `0x4E1EAC`: the exile block walks ControlledProvinces looking for ones it
does not control, so in a consistent state it never fires (dead in practice; inferred). The monthly gain is
otherwise as normal, from the provinces it controls.

**Units, production, research.** `CConstructUnitCommand` `0x5459F9`: **a new brigade takes each technology at the
higher of the exile's level and its faction leader's.** `CDistributeUpgrade::Distribute` `0x51D158`: units are
upgraded toward the leader's level where that is higher. The text shows the leader's level:
`CSubUnit::EquipmentText` `0x5AB0A8`, `0x5AB444`, `UnitStatsWindow_Construct` `0x7255C9`, `CCurrentModelEntry`
`0x80710A`, `CPossibleModelEntry` `0x807499`, `CShipBuilder::OpenModelSelection` `0x80A699`, `CShipBuilder::Update`
`0x80B1B4`. No research function reads the flag.

**Diplomacy - what an exile cannot do.** `GetDiplomaticActionsToward` `0x4E4A8A`: no alliance row offered by an
exile; `0x4E5301`/`0x4E5316`: no debt row if either side is an exile. `CAllianceAction::IsValid` `0xA1ADE3`: the
actor may not be an exile; `IsSelectable` `0xA1AFFE`: the recipient may not be. `CFactionAction::IsValid`
`0xA33C17`/`0xA33C2D`: neither side may be an exile, inviting or joining. `CDebtAction` IsValid `0xA3EB19`/`2B` and
IsSelectable `0xA3EB99`/`AF`: neither side. `LendLease_GetRoute` `0xA101B3`/`0xA101C4`: neither side
(`ACT_LENDLEASE_ANY_GOI` "$ACTOR$ and $RECIPIENT$ must be non-exiled countries"). `CTradeAction::IsValid`
`0xA387F1`/`0xA38834`: an exile side must own its acting capital. `CCountry::RebuildNeighbours` `0x4E3649`: an exile
is never a "strong ally at war". Lua `CCountry::IsNonExileNeighbour` `0x4C8704`, and `IsLandSafeToJoin`
`0x5078FE`: exile neighbours are ignored. **Nothing refuses an exile a war declaration, a peace offer, a NAP, a
guarantee, military access, influence or a licence**: none of their functions reads the flag.

**Liberation, which ends an exile.** `CCountry::GetPossibleLiberations` `0x4EE034`: any exile that owns land, whose
capital this country controls, that is not itself and is not its enemy. `CLiberateCountryCommand` vf_14
`0x54DB1D`: valid only for an exile. `CPoliticsView` `0x6BF0AC`: `POL_LIB_C_WE_EXILE` "We are a government in exile,
so we can't liberate others."; `0x6BF284`: the list of exiles. `CLiberateCreationDialogDialogue` vf_07
`0x6B8E9C`. AI: `CAIPoliticsMinister::IsCapitalSafeToLiberate` `0x8A1BAD`.

**The underground.** `CCountry_CanTrainUnderground` `0x50936E` and `GetUndergroundUnavailableText` `0x509726`: an
exile cannot train underground. `GetMobilizeUndergroundsAvailability` `0x50AFF5`, `0x50AE61` and
`CSpawnFullRevoltCommand` vf_14 `0x55C821`: **only an exile may mobilise**, and only where an owned province's
underground is above `SPAWN_PARTISAN_LIMIT` (0.5); otherwise "We are not a government in exile". `0x509233`: in an
exile's own provinces the underground starts at the full `UNDERGOUND_INITIAL_STRENGTH` (0.4) instead of falling with
distance (`MAX_UNDERGROUND_DISTANCE` 1000). `0x6BB559`: the outliner shows the "mobilize" text for an exile instead
of "revolt".

**Modifiers.** `RebuildStaticModifiers` `0x4DF8A5` adds the static modifier `government_in_exile`, empty in both the
base game and Their Finest Hour.

**AI.** `ProcessAI` `0x8895F8` and `0x899A10`: a landless country that is **not** in exile only lends its units to
faction members that are not exiles, then stops; an exile's AI runs in full. `CAIUnit::ManageExpeditions`
`0x8B3389`: an exile is never sent its expeditions back. `AreaMayWidenFrontSearch` `0x8951FB`: always true for an
exile. `CAIStrategy::IsPreparingWar` `0x8ADDA7`, `IsPreparingWarWith` `0x8ADE50`, the war-target pass `0x8AD75F`
(rva `0x4AD6E0`), and `0x8950D9`, `0x8E19E2`: exiles counted, skipped or excluded as war targets or in front values.
`0x8B99F6`/`0x8B9C6D`: a USA-specific area test, which holds back while Germany owns land and is not an exile.

**Lua scripts.** `IsGovernmentInExile` is used in `ai_diplomacy.lua` 57 (no embargo by or of an exile) and 823 (an
exile is not a target), `ai_intelligence_minister.lua`, `ai_production_minister.lua`, `ai_support_functions.lua`
163, and the country files `FRA.lua`, `ENG.lua`, `FIN.lua`.

**Other.** Save and load (C.6); custom game `0x418E81`, `0x426E5C`; the puppet-swap gate and the faction-leader
return (C.4, C.5).

### C.8 What looks wrong and is what the bytes do

1. Units at sea always survive the exile; ships in a foreign port do not.
2. Lent units are shattered toward the lender's acting capital, which happens before the exile's own acting capital
   moves.
3. A promoted leader needs `max_ic` above 0. With nobody qualifying the exile stays leader, and the next day it
   leaves its own faction and comes back from exile.
4. Trade routes survive for an exile that stays in its own still-owned capital.
5. Coming back restores nothing that was cut, and turns every partisan brigade into militia.
6. A factionless exile is never swapped to a factionless holder, because two countries in no faction share the null
   faction object.
7. The puppet swap needs no truce, which after a peace exists only if the war's membership changed in its last 100
   days (`FINDINGS-war.md` C.11).
8. Occupied land is never returned to an exile by the daily pass, and land it liberates is held by the liberator.
9. An exile's units draw supply from friends without paying.
10. The `GetMonthlyManpowerGain` exile block is dead in practice and assigns rather than adds.
11. The exile's supplies and fuel go to whoever controls its acting capital, every day, even an enemy holding it -
    the hourly move happens after.

### C.9 Not settled

- What `RemoveUnit(unit, 0, 0)` does with the destroyed units' leaders; `RemoveUnit` (rva `0x284E40`) and its two
  flags were not read.
- What sets or clears `CCurrentGameState +0xD0C` (scenario) in a normal new game, and so whether the puppet swap runs
  in an ordinary game.
- Which ledger line shows `received_from_exiles`: `LEDGER_FROM_EXILES` sits beside "Into Network" at `0x7A1002`, not
  traced.
- The other four CDefines strings (`+0x10`-`+0x64`).
- The minor AI readers (`0x894CC0`, `0x8AD6E0`, `0x8B9710`, `0x8E1160`), read only at the gate.
- The `0x4DB400` daily return of an expedition (in RunCountryDailyPass, not exile-specific).
- No savegame here holds an exile.

### C.10 Frontier (rvas)

`0x4A2E00`, `0x1D3840`, `0xF25E0` (puppet tribute), `0x109230` (underground initial strength), `0x10AE40`,
`0x18BC0`, `0x26D90`, `0x494CC0`, `0x4AD6E0`, `0x4B9710`, `0x4E1160`, `0x21D410`, `0x2B9D80`, `0x284E40`
(RemoveUnit).

**Traps met.** Trap 2: `functionStart(0x5F1EDD)` answers `0x5F1EC0`, mid-instruction; the real entry is the
vftable's `0x5F1EA0`. Trap 14: section A had already taken `0x1020E0`, so the duplicate was dropped. Trap 8:
`0x1A87488` and `0x160A684` are `floor(N.5)` statics rather than defines.

Function table: 0x102BC0 SetGovernmentInExile revised confirmed; 0x10C0B0 CCountry_ReplaceExileWithPuppet new
confirmed; 0x1F1EA0 CExileStatusChange::Apply new confirmed; 0x1F1E50 CExileStatusChange::CExileStatusChange new;
0x1F1E80 CExileStatusChange::SetValue new; 0x1ABDD0 CSubUnit_ConvertType new inferred; labels 0xDA6C1, 0xDB44E,
0xDBE24, 0xD90CB, 0x1BBD8B new. Fields: CCountry 0xA64 received_from_exiles CGoodsPool revised (was
unused_pool_A64; BiceLib/GameClasses/CCountry.hpp:244 still has the old name); CCountry 0x95 government_in_exile
bool revised (comment); CDefines 0x80 base_militia Hoi3CString new.

## D. A province changing hands, and a capital lost

Fragment `fragments/merged/hands.json`. Addresses are VAs, with the rva beside each named function.

### D.1 In one line

- **A change of controller** (`Province_SetController`, `0x4A2400`, rva `0xA2400`) has two parts.
  - **With `applyConsequences`**: buildings may be damaged, and only by an enemy. The province's current production
    of money and resources is zeroed. If the province was the old controller's acting capital, a quarter of the old
    controller's money and resources goes to the new controller. Radar moves. Air and naval units based there go to
    the old side's nearest base, or are deleted. A history entry is filed. The old controller's acting capital is
    chosen again at once.
  - **Always**: the controlled lists, the occupation policy, REB's faction, the underground, the blockade, the areas,
    the AI's theatres, the depot, an AI notification. The supply and area groups are rebuilt only with
    `rebuildAreas`.
- **A change of owner** (`CMapProvince::ChangeOwner`, `0x4A36C0`, rva `0xA36C0`) sets the controller first with the
  same flags, then the owner, which is only bookkeeping. It sets nationalism to 20 years and marks trespassers. The
  old owner leaves its faction if it now owns nothing. In a running game every active province modifier is wiped.
- **Nothing here** sends a message, fires an event, moves threat, relation or `war_seen_tick`, gives a core, moves
  the declared capital, or touches convoys, trade routes, constructions or land units (except REB's faction).
- **A capital lost.**
  - The **acting capital** (`+0xE24`) moves at once when its province's controller changes with consequences, and is
    checked again every hour. It goes back to the original capital the moment that is held again. Otherwise it goes
    to the best owned and held province: victory points and IC, weighted by the size of the province's area, tripled
    on the current capital's continent. A country holding nothing takes its faction leader's acting capital.
  - The **declared capital** (`+0xE20`) moves only when its province's **owner** changes, at the next daily pass,
    to the most populous owned core.

### D.2 `Province_SetController` in order

`void __stdcall (province, CCountryTag* controller, int* date, bool applyConsequences, bool rebuildAreas, bool
peaceful)`, ending `ret 0x18` at `0x4A36AE`. Below, *old* is the controller on entry and *new* is the argument.

1. **No-ops.**
   - `new.id == old.id`: return.
   - An unowned province (`owner_id +0x330 == 0`) given to a real country, while `in_game` (`CCurrentGameState
     +0xDA4`) is set: return. In a running game, unowned land can only be given to nobody.
2. **`applyConsequences`** gates everything from here to the history entry (`0x4A250D` jumps to `0x4A2CF8`).
   - **a. Unless `peaceful`** (`0x4A2526`):
     - **Building damage**, only where `CCountry::IsEnemy(new, &old, province)` holds (war, REB, or an undeclared war
       covering the province). Each building of `+0x310..+0x314` in order whose `level_max` is above 0 takes one
       `Random()` draw. Where `draw % 100 < COMBAT_PUSHBACK_CHANCE_FOR_DAMAGE / 1000` (50 in Their Finest Hour, so
       50%), it loses `COMBAT_PUSHBACK_DAMAGE` (1.0, one level) off its current level, through
       `CProvinceBuilding_Damage` (`0x494490`, rva `0x94490`). This is the arithmetic
       `CCombat::DamageProvinceBuildings` inlines.
     - **Production zeroed**, enemy or not: `current_producing` money, crude oil, metal, energy and rare materials are
       set to `[0x1A87818]`. That is a `.bss` dword with 434 readers in `.text` and no writer found by address, so it
       is 0. Supplies and fuel are kept.
     - **The capital's loot**, enemy or not. Where the province is the old controller's **acting capital**,
       `CGoodsPool::TakeResources(old's GetPool, 250)` takes **25% of money, crude oil, metal, energy and rare
       materials** out of the old controller's national stockpile and adds them to the new controller's (its own
       acting capital's pool). The share is the static `[0x1A86CEC] = floorf(250.5)`. **Supplies, fuel and the other
       75% stay in the fallen province's pool.**
   - **b. Radar.** Let `v` = the province's `MODIFIER_RADAR_LEVEL` (id `0x30`).
     - Where `v != 0`, `CCountry::AddRadarProvince(new)` (rva `0xDD250`).
     - Always `CCountry_RemoveRadarProvince(old)` (rva `0xDD370`), then `radar_level_applied (+0x378) = v`. Each asks
       for the hourly intelligence refresh.
   - **c. Air**, where the air base's `level_max` is above 0.
     - **The candidate bases** are the `AirBases (+0xD70)` of the old controller, or of every member of its faction if
       the faction is real. The nearest province other than this one wins (`CMap::DistanceBetweenProvinces` x 1000,
       strictly nearer, first of equals).
     - **Each unit based here** whose owner is an enemy of the new controller:
       - with no candidate, it leaves its base, and is **deleted** (`CGameState::QueueUnitRemoval`) where it is not
         moving (`+0x140 <= 0`) and not fighting (`combats_count <= 0`);
       - otherwise `CUnit::SetBase`, and, if it is standing in this province, a `CRebaseAirOrder` to the new base.
   - **d. Naval**: the same with the naval base, `NavalBases (+0xD80)` and a `CRebaseOrder`.
   - **e.** A `CControllerChange` dated `*date` is filed in the province's history.
3. **The old controller's lists.** The province leaves its `ControlledProvinces`, and its per-country display byte is
   set. Where the old controller is REB, the rebel faction holding the province (`FindRebelFactionHoldingProvince`,
   rva `0x286C60`) drops it.
4. **The occupation policy** (only where new != old). If the new controller's `diplomacy[old]->occupation_policy` is
   the null policy (slot 14 is ReturnFalse on `CNullOccupationPolicy`):
   - `civil_war` is taken where its `allow` holds, with country = new controller and FROM = old controller;
   - otherwise the first policy in the file, which is `collaboration_government` in Their Finest Hour.
   - A policy already set is kept.
5. **The controller is written.**
6. **The new controller's side.** For a real new controller:
   - `CCountry_AddControlledProvince`, and its display byte is set.
   - **REB takes it** (REB new, old not REB, province owned): the first REB unit here whose faction does not already
     hold the province makes that faction take it (`RebelFaction_TakeProvince`, rva `0xBCBB0`, inferred). That runs
     `siege_won_trigger` and `siege_won_effect`, and sends the owner, if he is the player, `REVOLTSIEGE`, a key with
     no message type in either install.
   - **The underground is dissolved** where its level is above 0 and its owner is the new controller **or is not at
     war with it**. Both levels go to 0, it leaves its owner's underground list, and `underground_owner = ---`.
7. **An unowned province** given to a real, non-REB country is owned by it: `SetOwner(province, new, date, 0, 0)`,
   with no history entry.
8. `UpdateProvinceBlockaded`, always.
9. **In a real area:**
   - `UpdateOwnerAreaOfProvince(province, new, old)`, whatever the flags;
   - **only with `rebuildAreas`**: `DeleteAreaGroups`, `RebuildAreaGroups`, `DeleteSupplyGroups`,
     `RebuildSupplyGroups`;
   - then `theatres_dirty (+0x580) = 1` on the old controller, the new one, and every distinct owner of a simulated
     neighbouring province. **Their AI rebuilds its theatres at the next hour.**
10. `CProvince::UpdateSupplyDepot`.
11. **With `applyConsequences`: `CCountry::UpdateActingCapital(old)`** (rva `0xE0B80`, D.5).
12. A refresh of the interface object at `+0xCC`: the province is queued (under 110 entries), and -1 is pushed onto
    the intelligence refresh list.
13. `AISubscribers_NotifyControllerChanged(old, province)` (rva `0x4A2F10`, VA `0x8A2F10`): subscriber slot 32. Only `CAIUnit`
    overrides it (`0x8B0E60`, not read).

### D.3 `CMapProvince::ChangeOwner` and `CMapProvince::SetOwner`

**`ChangeOwner`** is `(this, owner, date, applyConsequences, rebuildAreas, peaceful)`, ending `ret 0x14`. It takes
the old owner first, then:

1. **`Province_SetController(this, owner, date, the same three flags)`.** The new owner takes control, with every
   consequence in D.2.
2. **`SetOwner(this, owner, date, recordHistory = applyConsequences, 0)`.**
3. **Where the old owner was a real country:**
   - `AISubscribers_NotifyOwnerChanged(old owner, province)` (rva `0x4A2FB0`, VA `0x8A2FB0`, slot 33; no `CAIAgent` subclass
     overrides it);
   - `nationalism = YEARS_OF_NATIONALISM` (20 in Their Finest Hour). It runs down by 83 thousandths a month. It feeds
     the `nationalism` static modifier, Their Finest Hour's `local_revolt_risk = 0.3` per year, where the owner
     controls the province. That last part is inferred from `FINDINGS-revolt.md` and was not read here.
4. **`UnitList_MarkTrespassers`** on the province's units.
5. **The old owner leaves its faction** (`LeaveFaction(false)`, no history) where its faction is real and it owns no
   province.
6. **In a running game, every active province modifier is unlinked and freed**, then
   `RebuildProvinceModifierValues`.
   - The decompiler's `free; return` is wrong: the listing loops.
   - Where the list's deferred-delete byte `+0x148` is set, the loop only marks the head and never ends.
   - **Nothing tests whether the owner changed.** A repeated `ChangeOwner` to the same owner resets nationalism and
     wipes the modifiers again and is otherwise harmless, which settles `FINDINGS-war.md` C.17's question.

**`SetOwner`** is `(this, owner, date, recordHistory, skipCountryLists)`, ending `ret 0x10`. It is pure
bookkeeping:

1. Nothing at all where the owner is unchanged or is **REB**.
2. With `recordHistory`, a `COwnerChange` is filed in the province's history.
3. Unless `skipCountryLists`, the province leaves the old owner's `OwnedProvinces`.
4. The owner is written.
5. Unless `skipCountryLists`, `CCountry_AddOwnedProvince` on the new owner.
6. A province with no controller is given to the new owner as controller: `SetController(..., 0, 0, peaceful 1)`.
7. A map refresh.

**There is no core, no capital, no building or construction, no unit, no nationalism and no modifier in it.** A new
owner never gains a core by any of these functions.

### D.4 The flags, and who passes what

- **`applyConsequences`** gates D.2 step 2 and step 11, and in `ChangeOwner` the `COwnerChange` entry as well.
- **`peaceful`** gates only the damage, the zeroing of production and the capital's loot. Unit rebasing and radar
  happen anyway.
- **`rebuildAreas`** gates only the four group rebuilds; `UpdateOwnerAreaOfProvince` always runs.

Known passes (apply, rebuild, peaceful):

| caller | flags |
| --- | --- |
| `change_controller` | (1, 1, 0) |
| the daily return of occupied land (`0x49F1C5`) | (1, 1, 0), its `esi` read as 0 from its use beside |
| the daily pass stripping control of an unowned province (`0x49F1F0`) | `---`, (0, 0, 0) |
| the peace's returns, the capitulation's returns, `po_demand_region` | (1, 0, 0) |
| `MakeVassal` step 3 | (1, 0, 1), section B |
| `SetOwner`'s own call | (0, 0, 1) |
| `0x49EA3D` (rva `0x9E600`, not read) | (1, 1, 1) |

### D.5 A capital lost

**The two fields.**

- `capital_province_id (+0xE20)` is the declared capital. `capital = ` and `is_capital` read it.
- `acting_capital_province_id (+0xE24)` is where the government sits. These read it: `GetPool` - **the national
  stockpile is the acting capital province's pool**; production, supply and depots, convoys, trade; `SpreadThreat`'s
  distance; every diplomatic action's message placement; the AI.
- **Save keys**: the country's `capital=` and `acting_capital=`, and the province's `capital=yes` (the
  daily-rewritten `+0x2B0` byte).
- No save holds a living country whose acting capital differs from its capital. The 17 dormant tags all keep a
  capital that another country owns.

**The declared capital: `CCountry::EnsureCapital` (`0x4DD8D0`, rva `0xDD8D0`).**

- **When it runs**: at the head of every country's daily pass, at session entry, and from `0x6490BF`.
- **Capital 0**: it logs "<TAG> has NO capital defined."
- **Its province still owned by the country**: nothing happens. **Occupation never moves the declared capital.**
- **Otherwise, if the country owns anything**: every owned province scores `trunc(manpower / 1000) + 1`, times 100
  where the province is the country's core. The first strictly highest becomes the capital through
  `CCountry_SetCapital(..., logHistory 1)`. A country owning nothing keeps its old capital.

**The acting capital: `CCountry::UpdateActingCapital` (`0x4E0B80`, rva `0xE0B80`).** It runs every hour from
`RunCountryHourlyPass`, for a country owning a province, and at once from `Province_SetController` with
`applyConsequences`, on the old controller. What it does:

1. **The acting capital is held by the country.** If the **original capital** (`GetOriginalCapital`: the history's
   first `capital` entry, else the declared capital) differs and is held by the country, the government moves back
   there. Otherwise nothing happens. The `IsEnemyTag` test beside it can never be true for a country's own tag.
2. **It is lost and the country holds no province.** The acting capital becomes the faction leader's acting capital,
   where the faction is real and the leader is not the country. Otherwise nothing changes.
3. **Otherwise, the best province.** Over the provinces the country both owns and holds, in a real area, in
   `OwnedProvinces` order:

       score = trunc((VP * 1000 + province MODIFIER_IC) * (provinces in its area * 1000) / 1000)
       score *= 3 where the province is on the current acting capital's continent

   The strictly highest wins, so the first of equals; the score starts from -1000. If none qualifies, the same
   scoring runs over held provinces in a real area whatever their owner. If still none, nothing changes. The choice
   is written raw.

**The hourly pass, just before.** A **government in exile** whose acting capital is held by an enemy takes its
faction leader's acting capital, where the faction is real and the leader is someone else.

**So a fallen capital, in order:** the occupier loots 25% of money and resources; the government moves at once
(step 3, or step 2 to the faction leader's acting capital if the country holds nothing); **the old pool's supplies,
fuel and remaining 75% stay in the fallen province**; retaking the original capital brings the government back
within the hour; the declared capital moves only if ownership is lost, at the next day.

### D.6 Where the existing outlines were right, wrong or incomplete

- **The record's `Province_SetController`** had the main lines right. It was wrong on the loot (it is 25% of money
  and resources, not "a share of the stockpile"), on "the nearest friendly air base" (it is the old controller's
  faction's nearest), and on removal (only of idle units). It missed production zeroing, radar, the underground,
  REB's faction, theatres, `UpdateActingCapital`, the AI notification and the interface refresh. Its step "(2)
  refuses an unowned province" is right, for a real new controller.
- **`FINDINGS-effectrun.md` 2.10** is right as far as it goes. It is incomplete on: the controller being set first
  with all three flags; `UnitList_MarkTrespassers`; the AI notification (what "rva 0x4A2FB0" is); and the owner
  setter (bookkeeping only, no cores).
- **`FINDINGS-war.md` C.16.2** ("buildings may take pushback damage as peace returns them") is now **confirmed**. At
  the peace's step 5 the wars are still set, so `IsEnemy` holds and the 50% roll applies. The capitulation's returns
  (D.3 step 10) happen only once there is no war, so they take no damage, but they still zero the province's current
  production of money and resources.
- **`UpdateOwnerAreaOfProvince`'s comment** (and `FINDINGS-supplynetwork.md` section 2) puts the call at `0x4A32C2`
  in `CMapProvince::TakeControl`. It is in `Province_SetController`; `TakeControl` reaches it only through that
  function. The fragment revises the entry; the supplynetwork prose needs the same fix.

### D.7 What looks wrong and is what the bytes do

1. Taking a capital loots a quarter of the national money and resources. Supplies, fuel and the rest are stranded in
   the fallen province's pool.
2. A change of controller with consequences that is not `peaceful` zeroes the province's current production of money
   and resources even between friends.
3. Air and naval units are sent to the **old controller's** faction's nearest base whoever owns them. One with
   nowhere to go is deleted only if idle; one that is moving or fighting merely loses its base.
4. A province returned at a peace takes the pushback roll as if conquered.
5. A first occupation gets `civil_war` where allowed, otherwise the file's first policy.
6. An underground is dissolved when **any non-enemy** of its owner takes the province.
7. `ChangeOwner`'s modifier wipe never ends if the list's deferred-delete byte is set.
8. Nationalism is reset to 20 years on every `ChangeOwner`, including puppet hand-backs, releases and a same-owner
   repeat.
9. A new owner gets no core. Occupation never moves the declared capital, and a country owning nothing keeps its old
   one for good.
10. The government returns to the **original (history) capital**, not to the declared one.
11. A country holding nothing shares its faction leader's acting capital, **and so its stockpile pool**, unless it is
    in exile, where `GetPool` answers `pool_in_exile`.
12. `UpdateActingCapital`'s `IsEnemyTag` test is dead.
13. `REVOLTSIEGE` has no message type in the base game or Their Finest Hour (a whole-install key search;
    `PEACEACCEPT` found as the control).
14. Slot 33, the owner-change notification, has no listener in the `CAIAgent` family.

### D.8 Not settled

- Whether `current_producing` is rebuilt the next day, so that the zeroing is cosmetic.
- What the daily pass does with goods left in a pool that is no country's acting capital.
- What the subscriber slots do: `CAIUnit`'s slot 32 (`0x8B0E60`), and any non-`CAIAgent` listeners on either channel.
- The interface object at province `+0xCC`, and the template's byte `+0x20` that the underground's dissolution sets.
- Whether a game-made `CCountryCapitalChange` can become `GetOriginalCapital`'s answer.
- `RebelFaction_TakeProvince` stays inferred: its type offsets were matched to `siege_won_trigger` and
  `siege_won_effect` by shape.
- `0x49E600`'s (1, 1, 1) call, and whether the loaders pass `skipCountryLists` 1.
- No save holds an occupied capital.

### D.9 Frontier (rvas)

`0x4B0E60` (CAIUnit slot 32), `0x244620` and `0x2434C0` (the interface refresh), `0x6694A0` (tag to string),
`0x1FE450`/`0x1FE4B0`/`0x1FE8B0`/`0x1FE910` (the `COwnerChange` and `CControllerChange` builders), `0x9E600`.

**Traps met.** Trap 1: "0x4A2FB0" is an rva (VA `0x8A2FB0`). Treating it as a VA puts it inside
`Province_SetController`, which is how the first decompile run went. Trap 14: the record's prose put
`UpdateOwnerAreaOfProvince`'s caller in the wrong function. Decompiler lies: the modifier loop's `return`, and the
subscriber loops' lost arguments.

Function table: 0xA2400 Province_SetController revised confirmed; 0xA36C0 CMapProvince::ChangeOwner revised
confirmed; 0xA2180 CMapProvince::SetOwner new confirmed; 0xE0B80 CCountry::UpdateActingCapital new confirmed;
0xDD8D0 CCountry::EnsureCapital revised confirmed; 0x4A2F10 AISubscribers_NotifyControllerChanged new confirmed;
0x4A2FB0 AISubscribers_NotifyOwnerChanged new confirmed; 0x94490 CProvinceBuilding_Damage new confirmed; 0xDD150
CCountry_AddOwnedProvince new; 0xDD1D0 CCountry_AddControlledProvince new; 0xDD250 CCountry::AddRadarProvince new;
0xDD370 CCountry_RemoveRadarProvince new; 0x10A090 CCountry_RemoveUnderground new; 0x286C60
FindRebelFactionHoldingProvince new; 0xBCBB0 RebelFaction_TakeProvince new inferred; 0x7F540
UpdateOwnerAreaOfProvince revised inferred (caller attribution). Fields: CCountry 0x1148 radar_provinces CList<int>
new; CCountry 0xD60 underground_provinces CList<int> new.

## E. The AI's intel: the draw is never negative (collector)

Fragment `fragments/merged/intel-unsigned-draw.json`.

`FINDINGS-war.md` C.6 and C.16 item 7 had the draw `CAIIntel::CalculateTheirPercievedMilitaryStrengh`
(`0x89F4B0`, rva `0x49F4B0`) takes for each of their units as signed, "so about half of all units are seen
whatever the odds". **It is never negative.** The generator is inlined at `0x89F731`-`0x89F761`:

    y ^= y >> 11 (sar);  y ^= (y & 0xFF3A58AD) << 7;  y ^= (y & 0xFFFFDF8C) << 15;  y ^= y >> 18 (sar)

and the last step XORs y with its own arithmetic shift, whose sign bit is y's, so bit 31 of the answer is always
clear - as the land combat's reading of `MT19937Next` found, and as OpenHOI3's generator, checked against the
original's rolls, answers. The remainder by 100 (`0x89F775`-`0x89F78B`, the magic `0x51EB851F`) is so the plain
0 to 99, and a unit is seen exactly where its province is known at 2 or more or the remainder is under the
threshold.

Made exact at the same time (`0x89F6BA`-`0x89F8B1`): the hidden sum is the frame's `+0x10` local and the seen sum
`+0x14`; the threshold is land% where the unit's province's `+0xD4 -> +0x22` byte is set, else sea%; K in the
per cents is `floor(100000.5f)`, the float at `0x160A718`; and the guess at the hidden strength is
`RandomPerturbAtLeast(base hidden, floor 0, scale, spread U)` with

    scale = trunc(floor((float)((float)(U + 1.0) + 0.0005) x 1000) x hidden / 1000)     (64-bit)

the doubles 1.0, 0.0005000000237 and 1000.0 read out of `0x160A248`, `0x160A460` and `0x160A300`. The answer is
`(seen + that) / 1000.0` as a float.
