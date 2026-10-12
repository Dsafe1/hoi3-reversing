# Every effect and every condition as words

*Read on 2026-10-12, statically, for OpenHOI3's event option tooltips, the description of an event's
`immediate` block, and a decision's two tooltips, by a wave of five (`WAVE.md`, "The text wave").
Addresses are rvas unless they say VA.*

The machinery around the leaves was already read: an effect's three text slots and how a run of one
keyword is folded onto one line (`FINDINGS-effects.md`), the trigger renderers - `and`, `or`, `not`,
`any_owned_province`, the asterisks and the indent - and four trigger leaves
(`FINDINGS-techtext.md`), `kill_leader`'s line and the localisation calls (`FINDINGS-effecttext.md`),
and in which scope each tooltip is asked (`FINDINGS-eventfire.md`, 3.4 and 3.7). This is the leaves:
every effect's `GetText` (slot 9) and every trigger's `GetText` (slot 8), and the scope blocks' own
headers. The function tables are in `fragments/merged/effect-text-add-to-metal.json`,
`effect-text-modify-to-war.json`, `trigger-text-active-to-war-goal.json`,
`trigger-text-ideology-to-supply.json` and `trigger-text-owned-to-year.json`.

## 0. How to read the tables

- **T(KEY)** is the key's localised text: the localisation's `GetText` and then `Render`.
- **Literal strings** that join the pieces, by VA:

  | string | VA |
  | --- | --- |
  | `§Y` | 0x15B5C54 |
  | `§W` | 0x15B6700 |
  | `§W\n` | 0x15B6B88 |
  | `\n` | 0x15B57D0 |
  | `'§Y` | 0x15F6540 |
  | `§W'\n` | 0x15F6544 |
  | ` §Y` | 0x15C3004 |
  | `§W ` | 0x15C73CC |
  | `: ` | 0x15B6B80 |

- **A name**: a country's is `CountryNameOfTag` / `CountryNameOfCountry`; a province's is
  `CProvince::GetName`, its template's name.
- **Numbers**: `itoa` is whole; **trimmed** is `FormatFixedPointTrimmed`, thousandths with no
  trailing noughts; `FormatFixedPoint(v, n)` cuts to n places.
- A `\n` inside a localisation table is the two characters backslash and n as the CSV holds it; the
  reader turns it into a break.
- **Missing** means the key is in neither `localisation/*.csv` nor `tfh/localisation/*.csv`. **A
  missing key renders as the key itself** (section 6), not as `NO_TEXT_FOR_KEY`.

## 1. Effect leaves, `add_core` to `metal`

*Brief A.* 39 slot 9 bodies and the two slot 10 overrides in the range. `kill_leader` and `load_oob`
were recorded and are confirmed. **Corrected**: `CAddDivisionEffect::GetText` (0x5B5FA0), named from
its slot only, renders the empty key - **`add_division` says nothing**; `CContextEffect::GetText`
(0x59E300), "not read past the gate", writes `"(" + name + "): "` or nothing.

**How a variable is filled**: a plain string, through `Replace` or its inlined 0x40-byte object
(constructor 0x6832B0, vftable VA 0x11FE32C), rendered as it is; **a nested text** - the text of a
string built for it, a 0x38-byte replacement (vftable VA 0x11FE340; 0x683050 where not inlined, key
in ESI) rendered in place with the same colours; a whole number through 0x682FB0, rendered by `_itoa`,
**signed**. Most bodies colour a name by **looking up `"§Y" + name + "§W"` as a key**, which only works
because a missing key renders as itself (section 6).

**The arguments**: `group` is read by two bodies only, `add_core` and the unit type's effect
(`lea ..,[ebp+0x10]` at VA 0x9A035C and 0x9A8CB6); every other frees it. **The trailing int is read
by none** - no `[ebp+0x2C]` in all 42 bodies, where the same scan finds the group's `[ebp+0x24]`
capacity test in each.

**Resolving a country**: *ResolveTarget* is `Effect_ResolveCountryTarget` (0x5A7C30); *this/from as
it stands* is THIS by `EventScope_GetCountryTag(scope)`, FROM the scope's FROM tag (+0x18/+0x1C) **with
no fall-back to FROM's province**, else the effect's tag (+0x20/+0x24). "The province" is
`scope->province` (+0x28), never guarded - a country's effect speaks of province 0. A province's name
is `CProvince::GetName`.

### 1.1 Diplomacy

| keyword | class, rva | line | keys, in the localisation? |
| --- | --- | --- | --- |
| `create_alliance` | CCreateAllianceEffect, 0x5AD920 | nothing where already allied; else T(ALLIANCE_EFFECT){$WHO$ = `"§Y"` + the target's name + `"§W"`}, the target by ResolveTarget | "Alliance with §Y$WHO$§W.\n" |
| `leave_alliance` | CLeaveAllianceEffect, 0x5B7AC0 | nothing where **not** allied; else T(LEAVE_ALLIANCE_EFFECT){$COUNTRY$ = the scope's country, $TARGET_COUNTRY$ = the target, both plain} | "§Y$COUNTRY$§W will end its alliance with §Y$TARGET_COUNTRY$§W.\n" |
| `guarantee` | CGuaranteeEffect, 0x5B62E0 | written where there is no guarantee, or the guarantee's `first` is the target (they guarantee us); nothing where we already guarantee them | START_GUARANTEE_EFFECT: "§Y$COUNTRY$§W will start guaranteeing §Y$TARGET_COUNTRY$§W.\n" |
| `end_guarantee` | CEndGuaranteeEffect, 0x5B6740 | only where we guarantee them | END_GUARANTEE_EFFECT: "... will end its guarantee to ..." |
| `end_non_aggression_pact` | CEndNonAggressionEffect, 0x5B76A0 | nothing where there is no pact | END_NON_AGGRESSION_PACT_EFFECT: "... will end a non-aggression pact with ..." |
| `end_war` | CEndWarEffect, 0x5B8290 | nothing where there is no war | END_WAR_EFFECT: "§Y$COUNTRY$§W and §Y$TARGET_COUNTRY$§W will no longer be enemies§W.\n" |
| `military_access` | CGrantMilitaryAccessEffect, 0x5B6AA0 | nothing where access is already granted | GRANT_MILITARY_ACCESS_EFFECT: "§Y$TARGET_COUNTRY$§W will grant §Y$COUNTRY$§W military access§W.\n" |
| `create_vassal` | CCreateVassalEffect, 0x5B85A0 | nothing where the target is already the scope country's vassal or owns no province; names plain | CREATE_VASSAL_EFFECT: "§Y$TARGET_COUNTRY$§W becomes a puppet of §Y$COUNTRY$§W.\n" |
| `casus_belli` | CCasusBelliEffect, 0x5A67E0 | always; $WHO$ = the nested `"§Y"` + name + `"§W"`; the country this/from as it stands | GAIN_CB: "Gain casus-belli on §Y$WHO$§W.\n" |
| `inherit` | CInheritEffect, 0x5AA180 | always; $WHO$ as `casus_belli`'s | INHERIT: "Inherit §Y$WHO$§W.\n" |
| `change_controller` | CChangeControllerEffect, 0x5A7EA0 | nothing where the province's controller is the target; else $WHERE$ = the nested `"§Y"` + province + `"§W"`, $WHO$ = `"§Y"` + target + `"§W"` | CHANGE_CONTROLLER_EFFECT: "§Y$WHO$§W takes control over §Y$WHERE$§W.\n" |

### 1.2 Politics

| keyword | class, rva | line | keys |
| --- | --- | --- | --- |
| `government` | CGovernmentEffect, 0x5A1110 | the government +0x20, or with `REB` the one of the scope's rebel faction; nothing where null or already had; $GOV$ = the nested `"§Y"` + its slot 6 (its key, localised) + `"§W"` | GOV_CHANGE: "The type of government changes to §Y$GOV$§W.\n" |
| `coup_by` | CCoupEffect, 0x5A17D0 | the ideology +0x20, or THIS's / FROM's ruling ideology (+0x1140); nothing where null, where its slot 17 says no (for an ideology the answer-true stub) or where the scope's country already rules by it; $PARTY$ = the nested `"§Y"` + its slot 14 for the **scope's** country + `"§W"` | PERFORM_COUP: "$PARTY$ overthrows the current government" - **no break** |
| `do_election` | CElectionEffect, 0x5AAEF0 | the country this/from as it stands; **nothing where it owns a province**; else $WHO$ = the nested name | ELECTION_EFFECT: "Election in §Y$WHO$§W" - **no break** |
| `join_faction` | CJoinFactionEffect, 0x5A1CC0 | nothing where already a member; $FACTION$ = the nested `"§Y"` + the faction's slot 6 + `"§W"` | JOIN_FACTION_EFFECT: "Join $FACTION$.\n" |
| `leave_faction` | CLeaveFactionEffect, 0x5A2390 | only where a member and **not its leader** (its first member); $FACTION$ as above. Its extent runs to 0x5A26DF, past its one `ret 0x28` (trap 3) | LEAVE_FACTION_EFFECT: "Leave $FACTION$.\n" |
| `form_government_in_exile` | CFormGovernmentInExileAction, 0x5BB1D0 | the value set: FORM; clear: REVOKE; nothing asked | FORM_GOVERMENT_IN_EXILE "Form a Government in Exile.\n", REVOKE_GOVERMENT_IN_EXILE "Revoke the Government in Exile.\n" |
| an ideology `= { organisation popularity }` | CAllOrganisationPopularityEffect, 0x5B9000 | nothing where the ideology is null. **ADD where either figure is at least 0**, each trimmed, a negative one wrapped `"§R"`..`"§W"` with its minus; **REMOVE where both are below 0**, with their minus signs. $IDEOLOGY$ = the ideology's slot 14 for the scope's country, plain | ADD_ORGANISATION_POPULARITY_EFFECT: "§Y$IDEOLOGY$§W gains §G$ORGANISATION$§W in organisation and §G$POPULARITY$§W in popularity§W.\n"; REMOVE_...: "... loses §R$ORGANISATION$§W ..." |
| `country_event` | CCountryEventEffect, 0x5AE520 | always; the event by id value/1000; found, $WHICH$ = its title through `LocaliseEventText` in a copy of the scope **with FROM the scope's own country**; not found, $WHICH$ is never filled | SPAWN_EVENT: "will get the '$WHICH$' event.\n" |

### 1.3 Provinces and goods

| keyword | class, rva | line | keys |
| --- | --- | --- | --- |
| `add_core` | CAddCoreEffect, 0x5A0240, and slot 10 0x5A0040 | slot 10's label is the province's name - empty where there is no country or it has the core already; the line is nothing where the label is empty, else $NEW$ = the nested `"§Y"` + **group** + label + `"§W"` | NEW_CORE_EFFECT: "Gain core on §Y$NEW$§W.\n" |
| a unit type `= province` | CAddSubUnitEffect, 0x5A8BC0, and slot 10 0x5A8B40 | $WHERE$ = the nested `"§Y"` + **group** + province + `"§W"`, $UNIT$ = `"§Y"` + the type's localised name + `"§W"`; **then `\n`** | ADD_SUB_UNIT_EFFECT: "Get $UNIT$ in §Y$WHERE$§W." |
| `add_division` | CAddDivisionEffect, 0x5B5FA0 | **nothing**: the empty key | - |
| `capital` | CCapitalEffect, 0x59F080 | nothing where the capital already is province value/1000; else $NEW$ = the nested `"§Y"` + its name + `"§W"`; THIS and FROM ignored | CAPITAL_CHANGE: "§Y$NEW$§W will become the new capital.\n" |
| a building `= N` | CBuildingEffect, 0x5B8940 | **REMOVE where the value is below the building's working level** (+0x24), else ADD; $BUILDING$ = its name (+0x38), $PROVINCE$, $VALUE$ = trimmed(value), plain | ADD_BUILDING_EFFECT: "Gain §Y$BUILDING$§W with level §Y$VALUE$§W in §Y$PROVINCE$§W.\n"; REMOVE_...: "Lose ..." |
| `add_country_modifier` | CAddCountryModifierEffect, 0x5A3940 | nothing where the modifier is null or already on; $WHERE$ = the country's name, plain; $WHAT$ = the nested modifier's slot 6, its name; $DATE$ = `FormatHourDate` of its end - the end date where `duration` is below 1, else now + duration x 24 hours - **with a leading space**; $EFFECT$ = the nested modifier's slot 7, every value a line | MODIFIER_ADDED: "$WHERE$ gets '§Y$WHAT$§W' until §Y$DATE$§W, giving the following effects:\n$EFFECT$\n\n" |
| `add_province_modifier` | CAddProvinceModifierEffect, 0x5A3170 | the same on the scope's province; $WHERE$ its nested name, uncoloured | MODIFIER_ADDED |
| `change_manpower` | CChangeManpowerEffect, 0x5A5780 | always; $DIRECTION$ = the nested GAIN (value at least 0) or LOSE; $VALUE$ = `§G` (above 0), `§R` (below) or `§Y` (0) + **FormatMen(value)** + `§W`; $WHERE$ = the nested province | PROV_MANPOWER: "$DIRECTION$ $VALUE$ manpower in $WHERE$.\n"; GAIN "Gain", LOSE "Lose" |
| `leadership` | CLeadershipEffect, 0x5A5FF0 | as `change_manpower`, $VALUE$ = colour + FormatFixedPoint(value, **2**) + `§W` | PROV_LEADERSHIP: "$DIRECTION$ $VALUE$ leadership in $WHERE$.\n" |
| `create_revolt` | CCreateRevoltEffect, 0x5A4F50 | always; $WHERE$ the nested province; $SIZE$ = the nested `"§R"` + itoa(value x the province's manpower (+0x320) / 1000 / 1000) + `"§W"` | CREATE_REVOLT: "§R$SIZE$§W regiment(s) rises up in revolt in §Y$WHERE$§W.\n" |
| a rebel type `= N` | CCreateRebelsEffect, 0x59F5D0 | as `create_revolt`, and $TYPE$ = the nested `"§R"` + T(the rebel key + `_title`) + `"§W"` | CREATE_REBELS: "§R$SIZE$§Y $TYPE$§W regiment(s) rise up in revolt in §Y$WHERE$§W.\n" |
| `local_intel_boost` | CLocalIntelBoost, 0x5BE6C0 | nothing where there is no scope province or no FROM country; else $PROVINCE$ = its name; the figure is never shown | LOCAL_INTEL_BOOST, **Their Finest Hour's only**: "Increased intel levels in the area around §Y$PROVINCE$§!" - **no break** |
| `energy`, `metal`, `fuel` | CEnergyPoolEffect 0x5B2BB0, CMetalPoolEffect 0x5B24B0, CFuelPoolEffect 0x5B40B0 | with no scope province ADD_X_EFFECT where the value is above 0, else REMOVE_X_EFFECT; with one, the _PROVINCE_ pair and $PROVINCE$; $VALUE$ = value/1000 whole, **signed** | ADD_ENERGY_EFFECT "Gain §G$VALUE$§W energy§W.\n", REMOVE_... "Lose §R..."; _PROVINCE_: "... in §Y$PROVINCE$§W.\n" |
| `manpower` | CManpowerEffect, 0x59EAA0 | below 0: REMOVE with `"§R"` + FormatFixedPoint(-value, 1) + `"§W"`; else ADD with `"§G"` + FormatFixedPoint(value, 1) + `"§W"` | ADD_MANPOWER_EFFECT: "Gain §G$VALUE$§W manpower§W.\n"; REMOVE_...: "Lose §R..." |
| `dissent` | CDissentEffect, 0x5BA110 | below 0: REMOVE with trimmed(-value); else, 0 too, ADD with trimmed(value) | ADD_DISSENT_EFFECT: "Gain §R$VALUE$§W in dissent§W.\n"; REMOVE_...: "Lose §G..." |

### 1.4 Scopes, and the two recorded

| keyword | class, rva | line | keys |
| --- | --- | --- | --- |
| any scope `X = { }` | CContextEffect, 0x59E300 | `MakeScope`; where it resolved (+0x3C), its country id (+0x14) is not 0 and **is not the player's** (`CCurrentGameState +0xC34`): `"(" + the country's name + "): "`; otherwise nothing. No break; the children follow through slot 8 | none (the literals at VA 0x15B6C90, 0x15F39E4) |
| `kill_leader` | CKillLeaderEffect, 0x5ADD30 | as recorded; nothing where the leader is not found among the scope country's | KILL_LEADER_EFFECT: "Leader §Y$NAME$§W will die.\n" |
| `load_oob` | CLoadOOBEffect, 0x5BBE40 | as recorded: the path used as a key, so the bare path shows | - |

Every key these bodies name is in the base game's localisation but LOCAL_INTEL_BOOST, which is Their
Finest Hour's.

### 1.5 Kept as read, though they look odd

1. **`do_election` says something only for a country that owns no province** (VA 0x9AAF56).
2. **A building's Gain or Lose compares the value with the working level, though `Execute` adds the
   value** - `industry = 1` where industry works at 3 reads "Lose Industry with level 1".
3. **Signed figures beside a direction word**: "Lose §R-5§W energy", and 0 reads "Lose 0";
   `change_manpower` and `leadership` "Lose -500", "Lose -0.50"; the ideology's REMOVE "loses -5".
   `manpower` and `dissent` turn theirs round.
4. **`change_manpower`'s figure is a hundred times the value** (FormatMen): `change_manpower = 5`
   reads 500.
5. **PERFORM_COUP, ELECTION_EFFECT and LOCAL_INTEL_BOOST have no break**, so the next line runs on;
   ADD_SUB_UNIT_EFFECT has none either but its code appends one.
6. **SPAWN_EVENT begins in lower case**; with an unknown event, $WHICH$ is left as written.
7. **Colours doubled** where a key colours a variable the code already wrapped - `§Y§YName§W§W` -
   harmless on screen.
8. **The organisation and popularity ADD line is chosen where either figure is at least 0**, so a
   negative partner shows as `§G§R-5§W§W`.
9. **`casus_belli`, `inherit`, `do_election` and `coup_by` take FROM's tag as it stands**, with no
   fall-back to FROM's province's owner; `capital` ignores THIS and FROM.
10. **A country's effect that names a province names province 0**: `change_manpower`, `leadership`,
    the revolts, the rebels, buildings, province modifiers, `change_controller`.
11. **MODIFIER_ADDED's $DATE$ has a leading space**, and $WHERE$ is its one uncoloured variable.
12. **`add_division` shows nothing at all.**
13. **A context writes no head for the player's own country**, a province's scope or an unresolved
    one.

### 1.6 Not read

- The render path of a missing key (0x683A20) - section 6; whether the base slot 8's fold ever joins
  *different* unit types; what `REB` resolves to in `add_core`'s slot 10; the name of country 0.
- `remove_core`'s slot 10 (0x5A08D0, brief B's class) was decompiled here: **the same code as
  `add_core`'s**, empty where the country *already has* the core - so for `remove_core` the label is
  empty exactly where the effect would act. Its fields are 4 bytes on (+0x24 tag, +0x28 id, +0x2C
  province).
- Helpers left in the `frontier`: 0x683050, 0x683220, 0x6832B0, 0x682D70 and 0x682D00 (copying and
  freeing a text's replacements), 0x686DA0 (a key to its holder; length 0 to a fixed entry - the empty
  key renders empty), 0x683D90 (the text parser), 0x685F20, 0xBF3F0 (a rebel type's title), 0x1A38A0,
  0xB6730 (a building's slot 6).

## 2. Effect leaves, `modify_spies` to `war_exhaustion`, and the effect blocks

*Brief B.* 38 slot 9 bodies and the 13 slot 8 bodies of the scope and iteration effects, each body
its class's alone (`vtable.py --holding`). `war_exhaustion` (0x59E9A0) and `revolt_risk` (0x5A5600)
were recorded and are confirmed; `CContextEffect::GetText` is brief A's (section 1.4) and reads the
same here. **Corrected**: `CEffect::GetBlockText` - the indent is conditional and doubles with depth
(2.2, checked in transcription off the decompiled C); `CContextEffect::GetBlockText` - its children's
depth, its empty case and its break; `CPracticalEffect::GetText`, "not read", is read.

The trailing int is read by no leaf (no `[ebp+0x2C]`; the same scan finds the blocks' `[ebp+0x30]`
pushes); only `remove_core` reads `group`'s characters. A whole-number replacement's slot 2 chooses a
plural (1 against anything else).

### 2.1 Leaves

| keyword | class, rva | line | keys, in the localisation? |
| --- | --- | --- | --- |
| `money`, `crude_oil`, `rare_materials`, `supplies` | CMoneyPoolEffect 0x5B47B0, COilPoolEffect 0x5B1DB0, CRareMaterialsPoolEffect 0x5B32B0, CSuppliesPoolEffect 0x5B39B0 | **no scope province**: ADD_X_EFFECT where the value is above 0, else REMOVE_X_EFFECT; **with one**: REMOVE_PROVINCE_X_EFFECT where it is below 1, else ADD_PROVINCE_X_EFFECT, $PROVINCE$ its name, plain. $VALUE$ = value/1000 whole, signed | all: "Gain §G$VALUE$§W money§W.\n" / "Lose §R$VALUE$§W money§W.\n" / "... in §Y$PROVINCE$§W.\n", and the like for the others |
| `national_unity` | CNationalUnityEffect, 0x5B1A10 | v = value x (1000 + the country's NATIONAL_UNITY_EFFECT) / 1000; ADD_UNITY_EFFECT where v is above 0, else REMOVE_UNITY_EFFECT; $VALUE$ = v/1000 whole | "Gain §G$VALUE$§W unity§W.\n" / "Lose §R$VALUE$§W unity§W.\n" |
| `neutrality` | CNeutralityEffect, 0x5B9780 | ADD_NEUTRALITY_EFFECT where the value is at least 0, else REMOVE_; $COUNTRY$ = the scope country's name, $VALUE$ = the **raw** value trimmed | "§Y$COUNTRY$§W gains §R$VALUE$§W in neutrality§W.\n" / "... loses §G$VALUE$§W ..." |
| `officer_pool` | COfficerPoolEffect, 0x5B9C40 | as `neutrality`, with ADD_ and REMOVE_OFFICERS_EFFECT | sf_2_04.csv: "... gains §G$VALUE$§W officers§W.\n" / "loses §R..." |
| `organisation`, `popularity` | COrganisationEffect 0x5BA4A0, CPopularityEffect 0x5BA9E0 | ADD_RULING_PARTY_ORG (POP)_EFFECT where the value is above 0, else REMOVE_; $NAME$ = the ruling ideology's (+0x1140) slot 14 for the country; $VALUE$ = the value trimmed, for a loss its negation | "$NAME$ gains §Y$VALUE$§W organisation." (**no break**), "$NAME$ loses §Y$VALUE$§W organisation.\n"; popularity's both with a break |
| `modify_spies` | CModifySpiesEffect, 0x5BE1B0 | the target its slot 12, the count +0x28: above 0 ADD_SPIES_EFFECT{$VAL$ = itoa(count), $TARGET$ = the name}; below 0 REMOVE_SPIES_EFFECT with -count; 0 nothing | tfh.csv: **both** "Add §Y$VAL$§! spies to §Y$TARGET$§!" (no break) |
| `practical` | CPracticalEffect, 0x5BDDB0 | the value (+0x24) above 0 ADD_PRACTICAL_EFFECT, below 0 REDUCE_PRACTICAL_EFFECT with -value, 0 nothing; $VAL$ trimmed; **$TARGET$ = the category's +0x40, its short name's raw key** | tfh.csv: "§Y$TARGET$§! practical increased by §G$VAL$§!" / "... decreased ..."; no `*_practical_short` key exists, so $TARGET$ shows `carrier_practical_short` |
| `province_event` | CProvinceEventEffect, 0x5AE8D0 | SPAWN_EVENT{$WHICH$ = the event's title through `LocaliseEventText` in a copy of the scope, owner `---`}; not found, no $WHICH$ is added | "will get the '$WHICH$' event.\n" |
| `relation` | CRelationEffect, 0x5A71F0 | the scope not the player's: RELATION_CHANGE{$ACTIVE$ = the nested scope country's name, $PASSIVE$ = the nested target's}; the player's: RELATION_CHANGE_SHORT. $MUCH$ = `§G` (above 0), `§R` (below) or `§Y` (0) + FormatFixedPoint(value, 0) + `§W` | "Relation between §Y$ACTIVE$§W and §Y$PASSIVE$§W changed by $MUCH$.\n" / "Relation with §Y$PASSIVE$§W changed by $MUCH$.\n" |
| `release` | CReleaseEffect, 0x5AAA80 | T = THIS's country (`this_scope`), FROM, or +0x20; **only where T owns no province**: RELEASE{$WHO$ = the nested `"§Y"` + name + `"§W"`}; else nothing | "Release §Y$WHO$§W as a independent state.\n" |
| `release_vassal` | CReleaseVassalEffect, 0x5AF1C0 | ResolveTarget; `REB` the scope's rebel faction's country; id 0 nothing; RELEASE_VASSAL_EFFECT{$TARGET$ = `"§Y"` + name + `"§W"`} | v3.csv: "§Y$TARGET$§W will no longer be a puppet.\n" |
| `remove_core` | CRemCoreEffect, 0x5A0AD0, slot 10 0x5A08D0 | the label is slot 10's - **the province's name only where the country is not among its cores**; an empty label, nothing; else LOSE_CORE_EFFECT{$LOSE$ = the nested `"§Y"` + **group** + label + `"§W"`} | "Lose core on §Y$LOSE$§W.\n" |
| `remove_brigade` | CRemoveBrigadeEffect, 0x5BC1E0 | REMOVE_BRIGADE{$NAME$ = the string, plain} | "Remove brigade: $NAME$\n" |
| `remove_country_modifier` | CRemoveCountryModifierEffect, 0x5A4640 | only where the scope's country has it: MODIFIER_REMOVED{$WHERE$ = the country's name, plain, $WHAT$ = the nested modifier's slot 6} | "$WHAT$ will be removed from $WHERE$.\n" |
| `remove_province_modifier` | CRemoveProvinceModifierEffect, 0x5A4160 | only where the scope's province has it: the same, $WHERE$ its nested name | the same |
| `remove_fow` | CRemoveFoWEffect, 0x5A9230 | the country the scope's, or **the scope province's owner** where it has one; REMOVE_FOW{$COUNTRY$ = `"§Y"` + name + `"§W"`, $MONTHS$ = `"§Y"` + trimmed + `"§W"`} | "Lift Fog of War from $COUNTRY$ for $MONTHS$ months." (**no break**) |
| `remove_minister` | CRemoveMinisterEffect, 0x5B1820 | the minister found, else nothing; REMOVE_MINISTER_EFFECT{$NAME$} | "§Y$NAME$§W Will be removed§W.\n" |
| `change_province_name` | CRenameProvinceEffect, 0x5B0B50 | RENAME_PROV_EFF{$OLD$ = the province's name, $NEW$ = +0x20} | **missing** - the line is the key itself |
| `replace_minister` | CReplaceMinisterEffect, 0x5B7E60 | the minister by id value/1000, any country's; nothing where not found, where the post is not one of his, or where he holds it already; $NAME$ (+0x30), $POSITION$ = the post's display name | "§Y$NAME$§W will become §Y$POSITION$§W.\n" |
| `add_casus_belli` | CReversedCasusBelliEffect, 0x5A6B70 | $ACTIVE$ = the nested `"§Y"` + T + `"§W"` (T as `release`'s), $PASSIVE$ = the nested scope country | REV_GAIN_CB: "§Y$ACTIVE$§W gains a casus-belli on §Y$PASSIVE$§W.\n" |
| `end_military_access` | CRevokeMilitaryAccessEffect, 0x5B6DE0 | only where the scope's country has access with T: $COUNTRY$, $TARGET_COUNTRY$, plain | "§Y$COUNTRY$§W will revoke military access with §Y$TARGET_COUNTRY$§W.\n" |
| `revolt_risk` | CRevoltRiskEffect, 0x5A5600 | recorded, confirmed: slot 12 `FormatValueText` with REVOLTRISK_EFFECT | "$DIRECTION$ $VALUE$ revoltrisk in $WHERE$.\n" |
| `secede_province` | CSecedeProvinceEffect, 0x5A9A50 | T as `release`'s; `REB` the faction's country, none nothing; only where the province's owner is not T: $WHERE$ and $WHO$ nested and coloured | "Cede §Y$WHERE$§W to §Y$WHO$§W.\n" |
| `split_troops` | CSplitTroopsEffect, 0x5BBA90 | $NAME$ = **`this_scope`'s** country, $VALUE$ = trimmed(value x 100) | "Gain §Y$VALUE$%§W of all military forces of §Y$NAME$§W.\n" |
| `non_aggression_pact` | CStartNonAggressionEffect, 0x5B7280 | only where there is no pact: $COUNTRY$, $TARGET_COUNTRY$ | "... will be in a  non-aggression pact with ...\n" (two spaces) |
| `strategic_resource` | CStrategicResourceEffect, 0x5BDA70 | the resource's slot 14 true (`none`): EFF_NO_MORE_RES; else `AppendLocalisedLine`(EFF_STRAT_RES, $WHICH$ = its display name) | Motherland.csv: "Will no longer have a strategic resource.\n" / "Will now have §Y$WHICH$§W.\n" |
| `surrender_inherit` | CSurrenderInheritEffect, 0x5AA520 | $WHO$ = the nested `"§Y"` + T + `"§W"` | SemperFi.csv: "§Y$WHO$§W Capitulates\n" |
| `<technology> = N` | CTechnologyInvestmentEffect, 0x5A2760 | TECH_INVEST{$TECH$ = the nested technology's key (+0x228), $DIRECTION$ = the nested T(LOSE) below 0, else T(GAIN), $VALUE$ = colour + trimmed + `§W\n`} | sf_2_04.csv: "$TECH$ $DIRECTION$ $VALUE$"; GAIN "Gain", LOSE "Lose" |
| `threat` | CThreatEffect, 0x5B4FC0 | REMOVE_THREAT_EFFECT where the value is below 1, else ADD_; $COUNTRY$; $TARGET_COUNTRY$ = `who`'s name or **the literal `ALL`**; $VALUE$ = the raw value, trimmed | "§Y$COUNTRY$§W gains §R$VALUE$§W threat on §Y$TARGET_COUNTRY$§W.\n" / "loses §G..." |
| `undeclared_war` | CUndeclaredWarRegionEffect, 0x5BD220 | nothing where already enemies; else T(ADD_UNDECLARED_REGION_EFFECT) + the region's name | Motherland.csv: "Enemy units will be engaged if found in: " (**no break**) |
| `war` | CWarEffect, 0x5BC9A0 | nothing where already enemies; WAR_EFFECT{$WHO$ = `"§Y"` + name + `"§W"`} | "Declare War on §Y$WHO$§W.\n" |
| `add_wargoal` | CWarGoalEffect, 0x5BD650 | **writes the actor and recipient into the effect's own war goal**; $GOAL$ = its description (0x79D40: `<type>_setup` with ACTOR, RECIPIENT, THIRD, STATE) | Motherland.csv: "Wargoal added: $GOAL$" (no break) |
| `war_exhaustion` | CWarexhaustionEffect, 0x59E9A0 | recorded, confirmed: slot 12 with WAREXHAUSTION_EFFECT | "$DIRECTION$ $VALUE$ war exhaustion.\n" |

### 2.2 The blocks, and how an option's tooltip is put together

**The base, `CEffect::GetBlockText`** (0x59C710), corrected: I is three spaces x `depth`; T is its own
slot 9. The text starts empty and gets **I + T only where T is longer than one character**. Then for
each child, its label L (slot 10) is asked; where the **next** child has the same keyword (slot 6) and
L is not empty, the group G gets L + `§W,§Y ` and nothing is written; otherwise the text gets
**I + the child's slot 8 (the scope, the same depth, G, the trailing int)**, and G is emptied. So **I
is put before every child's block as well as its own line, and the child indents its own lines again**
- a leaf at depth d stands 6d spaces in. (Checked in transcription: the indent is built once,
`local_c0`, and joined to the own text where its length is above 1 and to each child's block.)

**An option and a decision ask it at depth 0 with an empty group, and the result is trimmed.** The
trailing int is the option's index (0 for `immediate` and for decisions).

| keyword | class, rva | block |
| --- | --- | --- |
| `random_list` | 0x5B0000, its GetText 0x5B0120 | the indent and its own GetText only: T(RANDOM_LIST_EFFECT){$SIZE$ = the number of entries} - "One of §Y$SIZE$§W options will happen.\n" - then for each entry T(RANDOM_EFFECT){$CHANCE$ = weight x 100 / the total, whole} - "§Y$CHANCE$§W% chance of " - + the entry's block **at depth 0** (or T(NO_EFFECT), "No Effect", where it is a character or less) + `\n` |
| `random` | 0x5AF9A0 | `§Y` + the chance trimmed + `§W% chance of ` + (` (\n` where it has more than one child) + I + the base on itself **at depth 0** + (`)` where more than one) + `\n`; only the first child's line is indented |
| `any_owned`, `any_controlled`, `any_nearby_province`, `any_neighbor_province` | 0x5AC810, 0x5ACAD0, 0x5ABC60, 0x5AB7B0 | **no header**: the base on itself at the same depth, **once for each member** passing the `limit`, each against that member's province |
| `any_country`, `any_neighbor_country` | 0x5AC370, 0x5ABF30 | for each member but the scope's own country: `"(" + name + "): \n"` + the base; `any_country` **skips countries that own no province** (its `Execute` does not) |
| `random_country`, `random_owned`, `random_neighbor_province`, `random_empty_neighbor_province` | 0x5ACD20, 0x5AD100, 0x5AD440, 0x5AE040 | no candidate, nothing; else **two LCG steps written back to the caller's scope**, then the base against the one member drawn; no header |
| a region | 0x5AB320 | the region's name (its slot 6, or T(REGION_NAME)) + `": "` - **not indented**: the indent is made and not used - then `\n` where the base (depth + 1, **province 0**) splits into more than two pieces at `\n`, then that block |
| a context, `FROM`, `owner`, a tag... | 0x59E520, its GetText 0x59E300 | GetText is `"(" + name + "): "` where the scope resolves to a country not the player's, else nothing. The block: I + that head; the children in the new scope **at depth + 1**, each with I before it; **where the children say nothing, the whole block is nothing**; where they have no `\n`, the head gets one |

**Composed**: an option with `money = 5`, `FROM = { relation = ... }`, `any_owned = { supplies = 1 }`
and `random = { chance = 30 national_unity = 2 }` is the option block's base at depth 0 - no line of
its own, no indent, each child flush:

1. "Gain §G5§W money§W.\n";
2. the context: "(France): " + "   Relation between ...\n" - the head and the first child on one line,
   the child three spaces in;
3. `any_owned`: "Gain §G1§W supplies in §YBerlin§W.\n" for each owned province;
4. `random`: "§Y30§W% chance of Gain §G2§W unity§W.\n" + "\n".

### 2.3 Kept as read, though they look odd

1. **`remove_core`'s label is the province only where the country has no core there**, so the line
   shows exactly when there is nothing to lose (brief A found the same, section 1.6).
2. REMOVE_SPIES_EFFECT's English says "Add".
3. RENAME_PROV_EFF is not in the localisation.
4. `practical`'s $TARGET$ is a raw key.
5. **A negative figure keeps its minus inside a "Lose"** - pools, unity, neutrality, officers, threat,
   technology ("Lose §R-5§W money"); 0 takes the loss key for the pools, unity, organisation,
   popularity and threat, and the gain key for neutrality and officers.
6. **No break**: ADD_RULING_PARTY_ORG_EFFECT, both spies keys, both practical keys, REMOVE_FOW,
   WARGOAL_EFFECT, ADD_UNDECLARED_REGION_EFFECT; TECH_INVEST carries its break inside $VALUE$.
7. `national_unity` shows the amount the modifier scales.
8. **`add_wargoal`'s tooltip writes into the effect's own war goal.**
9. **The `random_*` tooltips move the caller's state of chance on.**
10. A region's block describes province 0.
11. `any_country`'s tooltip skips countries its `Execute` still visits.
12. `random_list`'s chances do not match `Execute`'s off-by-one.
13. An unknown `strategic_resource` is called through with no test (a fault, `inferred`).

### 2.4 Not read

Whether the loader turns a table's `\n` into a break, which the context's and the region's tests of
`\n` hang on; how 0x65B520 splits (whether an empty last piece counts); how the renderer treats an
unfilled $WHICH$; the ideology's slot 14, a post's display name, a modifier's slot 6, a region's slot
6, `modify_spies`'s slot 12 and the war goal's description, read only to their keys. In the
`frontier`: 0x682FB0, 0x682D70, 0x682D00, 0x6832B0, 0x10E4C0 (`std::string::find`), 0x6C310,
0xAD150, 0x140AE0, 0x134180, 0x79D40, 0x65B520, 0xBC800, 0x685F20.

## 3. Trigger leaves, `active_mission` to `has_wargoal`

*Brief C.* Every body is `(out, scope, redWhen, depth)`, `ret 0x10`. **All 49 read `redWhen`**
(`[ebp+0x10]`, the positive control) **and none reads `depth`** (`[ebp+0x14]`). Each body is the only
holder of its slot (`vtable.py --holding`) but 0x5F94B0, shared by `base_neutrality` and
`neutrality`. `has_building` (0x5E4150) and `has_country_flag` (0x5E2110) were recorded and are
confirmed as `FINDINGS-techtext.md` section 3 has them.

### 3.1 The yes/no leaves: the wording follows the value as well as `redWhen`

| keyword | class, rva | line (value yes, `redWhen` 0) | line (`redWhen` 1) | keys, in the localisation? |
| --- | --- | --- | --- | --- |
| `always` | CAlwaysTrigger, 0x5D3930 | T(ALWAYS_TRUE) + `\n` | T(ALWAYS_FALSE) + `\n` | both: "Always", "Never" |
| `war` | CAtWarTrigger, 0x5D3670 | T(ATWAR) + `\n` | T(ATPEACE) + `\n` | both: "At War.", "At Peace." |
| `remove_fow` | CFoWRemovedTrigger, 0x5F2290 | T(FOW_IS_LIFTED) + `\n` | T(FOW_IS_NOT_LIFTED) + `\n` | both |
| `frontage_full` | CFrontageFullTrigger, 0x606700 | T(HAS_FULL_FRONTAGE) + `\n` | T(HAS_NO_FULL_FRONTAGE) + `\n` | **both missing** |
| `has_hostile_spy_mission` | CHasHostileSpyMissionTrigger, 0x606130 | T(HAS_HOSTILE_MISSION) + `\n` | T(HAS_NO_HOSTILE_MISSION) + `\n` | both (tfh.csv) |
| `has_strategic_resource` | CHasStrategicResourceTrigger, 0x605050 | T(HAS_STRATEGIC_RESOURCE) + `\n` | T(HAS_NO_STRATEGIC_RESOURCE) + `\n` | both: "Has a strategic resource.\n" / "Has NO strategic resource.\n" |
| `empty` | CEmptyTrigger, 0x5E1570 | `§Y` + the scope's province + `§W` + T(IS_EMPTY) + `§W\n` | `§Y` + province + `§W` + T(IS_NOT_EMPTY) + `\n` | **both missing** |
| `has_removable_minister` | CHasRemovableMinisterTrigger, 0x5FC260 | **T(HAS_NO_REMOVABLE_MINISTER)**, nothing after | **T(HAS_REMOVABLE_MINISTER)** | **both missing** |
| `can_create_vassals` | CCanCreateVassalsTrigger, 0x5EE070 | T(CAN_CREATE_VASSAL) + `\n` | T(CANT_CREATE_VASSAL) + `\n` | **both missing** |
| `has_empty_adjacent_province` | CHasEmptyAdjacentProvinceTrigger, 0x5EBEF0 | T(HAVE_EMPTY_ADJACENT_PROVINCE) + `\n` | T(HAVE_NO_EMPTY_ADJACENT_PROVINCE) + `\n` | **both missing** |

**Most take the negative key where `redWhen` equals the value** (`+0x40`), so `= no` at the top reads
as `= yes` inside a `not`. `has_removable_minister` is the other way round from the rest;
`can_create_vassals` and `has_empty_adjacent_province` do not read the value - `redWhen` alone
decides; `has_hostile_spy_mission`'s value byte is never set by its constructor, so its wording is
whatever the heap held.

### 3.2 Numbers and values

| keyword | class, rva | line (`redWhen` 0) | line (`redWhen` 1) | keys, in the localisation? |
| --- | --- | --- | --- | --- |
| `air_battles_fought` | CAirBattlesFoughtTrigger, 0x601B00 | T(AIR_BATTLES_FOUGHT_MORE) + `§Y` + itoa(+0x40) + `§W\n` + T(CURRENT_NUMBER_OF_DIVISIONS){$CURRENT$ = itoa(the scope country's +0x1084)} + `\n` | ... AIR_BATTLES_FOUGHT_LESS ... | all: "Air Battles Fought at least " / "... less than ", "(Currently §Y$CURRENT$§W)\n" |
| `total_amount_of_brigades` | CAmountOfBrigadesTrigger, 0x5F3F80 | T(AMOUNT_OF_BRIGADES_IS_ATLEAST_TRIGGER){$COUNTRY$ = the scope's country, $VALUE$ = itoa(+0x40)} + T(CURRENT_NUMBER_OF_DIVISIONS){$CURRENT$ = the brigades of its land units, headquarters left out} | ... _IS_NOT_TRIGGER | all (SemperFi.csv): "§Y$COUNTRY$§W Number of brigades is at least §Y$VALUE$§W.\n" |
| `total_amount_of_divisions` | CAmountOfDivisionsTrigger, 0x5F3720 | the same with AMOUNT_OF_DIVISIONS_IS_ATLEAST_TRIGGER; $CURRENT$ = `CUnitList::GetTotalAmountOfDivisions` | ... _IS_NOT_TRIGGER | all (triggers.csv) |
| `base_neutrality`, `neutrality` | `NeutralityTrigger_GetText`, 0x5F94B0 | T(NEUTRALITY_IS_ATLEAST_TRIGGER){$VALUE$ = trimmed(+0x40)} | T(NEUTRALITY_IS_NOT_TRIGGER) | both: "Neutrality is at least §Y$VALUE$§W.\n" / "Neutrality is below ..." |
| `crude_oil` | CCrudeOilTrigger, 0x5F65C0 | T(CRUDE_OIL_IS_ATLEAST_TRIGGER){$VALUE$ trimmed} | T(CRUDE_OIL_IS_NOT_TRIGGER) | both |
| `energy` | CEnergyTrigger, 0x5F6250 | T(ENERGY_IS_ATLEAST_TRIGGER){$VALUE$ trimmed} | T(ENERGY_IS_NOT_TRIGGER) | both |
| `dissent` | CDissentTrigger, 0x5F9130 | T(DISSENT_IS_ATLEAST_TRIGGER){$VALUE$ trimmed} | T(DISSENT_IS_NOT_TRIGGER) | both |
| `blockade` | CBlockadeTrigger, 0x5D4140 | T(BLOCKADE_PENALTY_MORE_THAN) + `§Y` + FormatFixedPoint(+0x40, 1) + `§W\n` | T(BLOCKADE_PENALTY_LESS_THAN) ... | **both missing** |
| `faction_progress` | CFactionProgressTrigger, 0x5FD3C0 | T(FACTION_PROGRESS_MORE) + `§Y` + FormatFixedPoint(+0x40, 1) + `§W\n` | T(FACTION_PROGRESS_LESS) ... | both |
| `enemy_ic_ratio` | CEnemyIcRatioTrigger, 0x6081D0 | T(ENEMY_IC_RATIO_DESC){$RATIO$ = FormatFixedPoint(+0x40 x 100, 2)} + `\n` | T(ENEMY_IC_RATIO_NOT_DESC) ... | both (tfh.csv): "IC ratio against enemies is less than §Y$RATIO$%§!." |
| `<building> = N` | CBuildingTrigger, 0x5DC120 | `§Y` + the building's display name + `§W` + T(BUILDING_AT_LEAST) + `§Y` + itoa(+0x40) + `§W\n` | ... T(BUILDING_LOWER_THAN) ... | both: " at least " / " lower than " |
| `<ideology> = { organisation popularity }` | CAllOrganisationPopularityTrigger, 0x5FA7C0 | T(ALL_ORG_POP_IS_ATLEAST_TRIGGER){$IDEOLOGY$, $ORGANISATION$ = trimmed(+0x44), $POPULARITY$ = trimmed(+0x48)} | T(ALL_ORG_POP_IS_NOT_TRIGGER) | both (triggers.csv) |

- `enemy_ic_ratio`'s factor is `floorf(100000.5f)` = 100000 (the float at VA 0x160A718), times the
  value, over 1000 in 64 bits: 0.5 is written "50.00".
- **$IDEOLOGY$** is the ideology's slot 14 (0x129120): the text of `<ideology>_<the scope country's
  tag>`, the party's name - `national_socialist_GER` is "NSDAP". With no ideology it is `§R` + the
  literal `NO_SUCH_IDEOLOGY` + `§W`, not looked up.
- `CURRENT` in the two amount triggers goes through the whole-number replacement (0x682FB0), `_itoa`
  base 10 when rendered.

### 3.3 Countries, provinces and names

| keyword | class, rva | line (`redWhen` 0) | line (`redWhen` 1) | keys, in the localisation? |
| --- | --- | --- | --- | --- |
| `active_mission` | CActiveMissionTrigger, 0x5F1710 | `§Y` + the mission's name + `_title` (**not localised**) + `§W ` + T(IS_MISSION_OF) + ` §Y` + the scope's country + `§W\n` | ... T(IS_NOT_MISSION_OF) ... | **both missing** |
| `alliance_with` | CAllianceWithTrigger, 0x5EF620 | T(HAVE_ALLIANCE_WITH) + `§Y` + country + `§W\n` | T(HAVE_N0T_ALLIANCE_WITH) ... | both: "Allied with " / "Not allied with " |
| `brigade_exist` | CBrigadeExistsTrigger, 0x5ECEC0 | T(BRIGADE_EXISTS) + `§Y` + the name as written + `§W\n` | T(BRIGADE_NOT_EXISTS) ... | **both missing** |
| `brigade_in_combat` | CBrigadeInCombatTrigger, 0x5EC890 | T(BRIGADE_IN_COMBAT) + `§Y` + name + `§W\n` | T(BRIGADE_NOT_IN_COMBAT) ... | both: "Brigade in combat: $NAME$" - **the $NAME$ is never filled** |
| `capital` | CCapitalTrigger, 0x5F1C90 | T(THE_CAPITAL_IS) + `§Y` + the province + `§W\n` | T(THE_CAPITAL_IS_NOT) ... | **both missing** |
| `casus_belli` | CCasusBelliTrigger, 0x5E7CF0 | T(HAVE_CASUS_BELLI_AGAINST) + `§Y` + the tag's country + `§W\n` | T(HAVE_NOT_CASUS_BELLI_AGAINST) ... | both: "Have claims against " / "Have no claims against " |
| `continent` | CContinentTrigger, 0x5E4CA0 | `§Y` + the scope's province + `§W` + T(IS_ON_THE_CONTINET) + `§Y` + the continent's slot 6 (its string at +0x34) + `§W\n` | ... T(IS_NOT_ON_THE_CONTINET) ... | both: " is on the continent " / " is NOT on the continent " |
| `controlled_by` | CControlledByTrigger, 0x5DFC30 | T(CONTROLLED_BY) + `§Y` + who + `§W\n` | T(NOT_CONTROLLED_BY) ... | both; `owner` is T(ITS_OWNER), "its owner" |
| `controls` | CControlsTrigger, 0x5D6020 | T(HAVE_CONTROL_OVER) + `§Y` + the province + `§W\n` | T(HAVENT_CONTROL_OVER) ... | both: "Control " / "Do NOT control " |
| `country_units_in_province` | CCountryUnitsInProvinceTrigger, 0x5FB5D0 | T(COUNTRY_HAS_UNITS_IN_PROVINCE_TRIGGER){$COUNTRY$, $PROVINCE$ = the scope's province} | T(COUNTRY_HAS_NO_UNITS_IN_PROVINCE_TRIGGER) | both |
| `date` | CDateTrigger, 0x5D31C0 | T(THE_DATE_IS_AFTER){$DATE$} | T(THE_DATE_IS_BEFORE){$DATE$} | both (v4.csv): "It is at least §Y$DATE$§\n " / "It is before §Y$DATE$§\n" |
| `exists` | CExistsTrigger, 0x5DA210 | `§Y` + country + `§W` + T(EXISTS) + `\n` | ... T(DOSNT_EXISTS) ... | both: " exists" / " does NOT exist" |
| `faction` | CFactionTrigger, 0x5FC970 | T(IS_MEMBER_OF_FACTION_TRIGGER){$FACTION$} | T(IS_NOT_MEMBER_OF_FACTION_TRIGGER) | both; NO_FACTION "No Faction" |
| `<position> = <id>` | CGovernmentPositionTrigger, 0x5F5A60 | T(GOVERNMENT_POSITION_TRIGGER){$NAME$ = the minister's name as written, $POSITION$ = the position's key localised} | T(GOVERNMENT_POSITION_NOT_TRIGGER) | both: "§Y$NAME$§W is §Y$POSITION$§W.\n" |
| `government` | CGovernmentTrigger, 0x5D9BD0 | T(HAVE) + `§Y` + the government's display name + `§W\n` | T(HAVE_NOT) ... | both: "Have " / "Do NOT have " |
| `military_access` | CGrantsMilitaryAccessTrigger, 0x5F78A0 | T(MILITARY_ACCESS_WITH_TRIGGER){$COUNTRY$ = the scope's country, $TARGET_COUNTRY$} | T(NO_MILITARY_ACCESS_WITH_TRIGGER) | both |
| `guarantee` | CGuaranteeTrigger, 0x5F8C50 | T(IS_GUARANTEEING_TRIGGER){$COUNTRY$, $TARGET_COUNTRY$} | T(IS_NOT_GUARANTEEING_TRIGGER) | both |
| `has_cb` | CHasCasusBelliTrigger, 0x5E86A0 | T(HAVE_CB_FROM){$CB$, $ACTOR$}, or with no actor T(HAVE_CB_FROM_ANYONE){$CB$} - **no line break** | HAVE_NO_CB_FROM / HAVE_NO_CB_FROM_ANYONE | all four (tfh_4_01.csv): "Have §Y$CB$§! from §G$ACTOR$§!" |
| `has_country_modifier` | CHasCountryModifierTrigger, 0x5E3370 | T(HAVE_THE_MODIFIER) + `§Y` + the modifier's display name + `§W\n` | T(DONT_HAVE_THE_MODIFIER) ... | both |
| `has_global_flag` | CHasGlobalFlagTrigger, 0x5E27B0 | T(HAVE_GLOBAL_FLAG) + `'§Y` + the flag as written + `§W'\n` | T(HAVE_NOT_GLOBAL_FLAG) ... | both |
| `has_province_flag` | CHasProvinceFlagTrigger, 0x5E2D10 | T(HAVE_PROVINCE_FLAG) + `'§Y` + the flag as written + `§W'\n` | T(HAVE_NOT_PROVINCE_FLAG) ... | both |
| `has_leader` | CHasLeaderTrigger, 0x5EC250 | T(HAVE_THE_LEADER) + `§Y` + the name as written + `§W\n` | T(HAVE_NOT_THE_LEADER) ... | both |
| `has_province_modifier` | CHasProvinceModifierTrigger, 0x5E3AF0 | T(HAVE_THE_PROVINCE_MODIFIER) + `§Y` + name + `§W\n` | T(DONT_HAVE_THE_PROVICEN_MODIFIER) ... | both, the typo too |
| `has_wargoal` | CHasWarGoalTrigger, 0x5EDB70 | T(HAS_WAR_GOAL_AGAINST) + `§Y` + the tag's country + `§W\n` | T(HAS_NO_WAR_GOAL_AGAINST) ... | **HAS_WAR_GOAL_AGAINST missing**; the negative is there: "Has no wargoal against " |
| `<group> = yes` | CCombinedArmsTrigger, 0x607A90 | the group's name, localised twice + `: ` + T(NO) + `\n` (the value is always clear) | ... T(YES) ... | YES and NO there; the second lookup's key ("Infantry") is missing |
| `has_building`, `has_country_flag` | 0x5E4150, 0x5E2110 | as `FINDINGS-techtext.md` section 3, confirmed | | |

**Where the country comes from:**

| keyword | THIS | FROM | otherwise |
| --- | --- | --- | --- |
| `alliance_with`, `country_units_in_province`, `military_access`, `guarantee` (the target) | `EventScope_GetCountryTag(scope)` | `scope->this_scope (+0x38)->from_country (+0x18/+0x1C)` | the tag |
| `controlled_by` | `EventScope_GetCountryTag(scope)` | **the scope's own** `from_country (+0x18)` | the tag; `owner` gives T(ITS_OWNER) |
| `continent` | the continent of THIS's country's capital | the continent of the scope's FROM country's capital | +0x40 |
| `casus_belli`, `has_wargoal` | **not used**: only +0x40 is named | **not used** | +0x40 |

- `exists` with `yes`/`no` names the scope's country (+0x10), DOSNT_EXISTS where `redWhen` equals the
  value; with a tag, EXISTS at `redWhen` 0 and DOSNT_EXISTS at 1.
- `faction`: $FACTION$ is the faction's slot 6 - a faction's is the text of its key (+0xC, 0x122590),
  no faction's T(NO_FACTION) (0x123690). With THIS it is the faction (+0xD8) of
  `EventScope_GetCountryTag(scope)`'s country.
- `has_cb`: the type at +0x48 is looked up in the casus belli types, falling back to the first; with
  no type, or one whose slot 7 answers false, the line is the literal `§R(Trigger error)§!`. $CB$ is
  the text of the type's key (+0x14, through 0x16960); the actor from `HasCbTrigger_ResolveActor`, id
  0 choosing the `_ANYONE` keys. The keys go in ECX/EDX to `AppendLocalisedLine2`/`AppendLocalisedLine`,
  and neither appends a break.
- `date`: $DATE$ is `sprintf("%d %s, %d")` (VA 0x15F5F70) - "1 January, 1936": days = (date -
  43800000) / 24, year = (int)(days / 365.0), the day of the year walked down the month lengths,
  the day counted from 1, the month the text of its English name as key (0x6AA670, ECX 0; non-zero
  gives the short forms). The hour is dropped.

### 3.4 Oddities, kept as read

1. **`has_removable_minister` is turned round** - it writes HAS_REMOVABLE_MINISTER where `redWhen`
   equals the value, so `= yes` at the top reads "has no removable minister" - and appends nothing,
   not even a break.
2. **`active_mission` writes the raw key `<mission>_title`**: `DecisionTitleKey` (0x5C5260) makes the
   key and nothing localises it. An unknown mission leaves +0x40 null and the body reads address 8.
3. **`has_cb`'s line has no break**, in the code or the table, so it runs into the next condition;
   so does `has_removable_minister`'s. The other "nothing appended" lines rely on their table's text
   ending in `\n`.
4. **`brigade_in_combat`'s text holds a `$NAME$` never replaced**; the name is appended after it.
5. **`can_create_vassals` and `has_empty_adjacent_province` ignore the value**: `= no` reads as `= yes`.
6. **`casus_belli` and `has_wargoal` ignore THIS and FROM in their text**, though their `Evaluate`
   honours them.
7. **`combined_arms` localises the group's name twice**; the second lookup is of "Infantry" and the
   like, which is no key.
8. **`air_battles_fought` and `has_strategic_resource` add a break after texts that end in one**, which
   leaves a blank line.
9. **The `date` texts close with a bare `§` before the break**, and THE_DATE_IS_AFTER ends in an extra
   space.
10. **The flags differ**: `has_global_flag` and `has_province_flag` print the flag as written;
    `has_country_flag` passes it through the localisation.
11. **Spellings as in the image and the tables**: `HAVE_N0T_ALLIANCE_WITH` (a nought),
    `DONT_HAVE_THE_PROVICEN_MODIFIER`, `IS_ON_THE_CONTINET`, `DOSNT_EXISTS`.
12. **Nineteen keys are missing from the base game's localisation**: BLOCKADE_PENALTY_MORE_THAN and
    _LESS_THAN, BRIGADE_EXISTS and _NOT_EXISTS, CAN_CREATE_VASSAL and CANT_CREATE_VASSAL,
    HAS_FULL_FRONTAGE and HAS_NO_FULL_FRONTAGE, HAS_REMOVABLE_MINISTER and HAS_NO_REMOVABLE_MINISTER,
    HAS_WAR_GOAL_AGAINST (its negative is there), HAVE_EMPTY_ADJACENT_PROVINCE and HAVE_NO_...,
    IS_EMPTY and IS_NOT_EMPTY, IS_MISSION_OF and IS_NOT_MISSION_OF, THE_CAPITAL_IS and
    THE_CAPITAL_IS_NOT.
13. **Values used unguarded, each a crash where it is bad**: an unknown minister id in
    `<position> = id` reads the name off a null pointer; a null modifier is dereferenced by
    `has_country_modifier` and `has_province_modifier`, a null continent by `continent`; the
    province ids of `capital` and `controls` are indices unchecked.
14. **`has_hostile_spy_mission`'s value is never set**, so its wording is what the heap held.
15. **`country_units_in_province` names its province through a temporary province** made from the
    scope's province id (0x94700), so the name is that template's.

### 3.5 Not read

- The continent's slot 6 string (+0x34): whether it is a localised name or a second copy of the key
  (the lookup matches the key at +0x18 through slot 7).
- When `NO_TEXT_FOR_KEY` actually shows (the condition at VA 0xA86036) - not for a missing key
  (section 6).
- The bodies of `AppendLocalisedLine2` and `AppendLocalisedLine`, beyond their calls - GetText,
  Replace, Render - which add no break.
- What a tag of id 0 is named (`casus_belli = THIS` naming +0x40); `CountryNameById`'s entry 0.

**Helpers met** (in the fragment's `frontier`): 0x60730, a `char*` key in ECX localised into the out
on the stack; 0x682FB0, the replacement by a whole number (a 0x28-byte object, vftable VA 0x15FE318,
the value at +0x24); 0x6AA670, a date's month as a text; 0x16960, the text of a casus belli type's
key; 0x129120, an ideology's slot 14; 0x122590 and 0x123690, a faction's and no faction's slot 6;
0x86CA0, a continent's slot 6; 0x94700, a province made from an id. Brief D entered four of them -
0x60730, 0x682FB0, 0x6AA670 and 0x129120 (section 4.6).

## 4. Trigger leaves, `ideology_group` to `out_of_supply_days`

*Brief D.* The same shape, `ret 0x10`; **`depth` is read by none of the 49** (no `[ebp+0x14]`; the
same scan finds `[ebp+0x10]` in each of eight bodies it was run on as a control). `num_of_ports`
(0x5D8510) was recorded and is confirmed; `neutrality` is brief C's shared body (section 3.2).

Joins besides section 0's: `§R` (VA 0x15B5C58), ` §W` (0x15F64F8), `%§W\n` (0x15B5E34), `§W%\n`
(0x15C76F8). **x100** is `v * 100000 / 1000`, two bodies taking the 100000 as `floor(100000.5f)`.
**The yes/no triggers choose by `redWhen` equal to the value**, the negative key where they are equal;
the tables show `= yes`.

### 4.1 Yes or no

| keyword | class, rva | line (`redWhen` 0) | line (`redWhen` 1) | keys, in the localisation? |
| --- | --- | --- | --- | --- |
| `ai` | CIsAiTrigger, 0x5ED480 | T(IS_AI) + `\n` | T(IS_NOT_AI) + `\n` | both: "Is AI", "Is NOT AI" |
| `is_attacker` | CIsAttackerTrigger, 0x606410 | T(IS_ATTACKER) + `\n` | T(IS_NOT_ATTACKER) + `\n` | **neither** |
| `is_subject` | CIsSubjectTrigger, 0x5ED770 | T(IS_SUBJECT) + `\n` | T(IS_NOT_SUBJECT) + `\n` | both: "Is a subject nation", "Is not a subject nation" |
| `is_in_any_faction` | CIsInAnyFactionTrigger, 0x5FC450 | T(IS_IN_FACTION_TRIGGER), nothing after | T(IS_NOT_IN_FACTION_TRIGGER) | both: "Is a member of a faction.\n", "Is not a member of any faction.\n" |
| `government_in_exile` | CIsGovernmentInExileTrigger, 0x5E0FE0 | `§Y` + the scope country's name + ` §W` + T(IS_IN_EXILE) + `\n` | ... T(IS_NOT_IN_EXILE) ... | both: "is a government in exile.\n", "is NOT a government in exile.\n" |
| `is_blockaded` | CIsBlockadedTrigger, 0x5E0290 | `§Y` + the scope province's name + `§W ` + T(HAVE_BLOCKADE_IN) + `\n` | ... T(HAVE_NO_BLOCKADED) ... | both (SemperFi): " under blockade", " NOT under blockade" |
| `is_capital` | CIsCapitalTrigger, 0x5F2640 | `§Y` + the scope province's name + `§W` + T(IS_CAPITAL) + `\n` | ... T(IS_NOT_CAPITAL) ... | both: " is a Capital Province", " is not a Capital Province" |
| `is_mission_country` | CIsMissionCountryTrigger, 0x5F0B20 | `§Y` + the scope country + `§W ` + T(IS_MISSION_TARGET) + ` §Y` + THIS's country (`this_scope` +0x38) + `§W\n` | ... T(IS_NOT_MISSION_TARGET) ... | **neither** |
| `is_mission_province` | CIsMissionProvinceTrigger, 0x5F10B0 | `§Y` + the scope province + `§W ` + T(IS_MISSION_TARGET) + ` §Y` + THIS's country + `§W\n` | ... T(IS_NOT_MISSION_TARGET) ... | **neither** |

### 4.2 Numbers

| keyword | class, rva | line (`redWhen` 0) | line (`redWhen` 1) | keys, in the localisation? |
| --- | --- | --- | --- | --- |
| `manpower` | CManpowerTrigger, 0x5D49C0 | T(HAVE_MORE_MANPOWER_THAN) + `§Y` + 1 place + `§W\n` | T(HAVE_LESS_MANPOWER_THAN) ... | both: "Manpower at least ", "Have less manpower than " |
| `max_manpower` | CMaxManpowerTrigger, 0x5D4660 | **the literal** `HAVE_LESS_MANPOWER_THEN_MAXIMUM` + `§Y` + 1 place + `%§W\n` | the literal `HAVE_MORE_MANPOWER_THEN_MAXIMUM` + the same | the keys exist ("Have less then max manpower" / "Have at least max manpower") and are **never looked up** |
| `max_manpower_greater_than` | CMaxManpowerGreaterThanTrigger, 0x5EFC60 | T(HAVE_MAX_MANPOWER_GREATER_THAN) + `§Y` + 1 place + `§W\n` | T(HAVE_MAX_MANPOWER_LESS_THAN) ... | **neither** |
| `manpower_percentage` | CManpowerPercentTrigger, 0x5D4F10 | T(HAVE_MORE_MANPOWERPERCENT_THAN) + `§Y` + x100 to 1 place + `%§W\n` | T(HAVE_LESS_MANPOWERPERCENT_THAN) ... | **neither** |
| `revolt_percentage` | CNumOfRevoltsFractionTrigger, 0x5D7A20 | T(THE_NUMBER_OF_REVOLT_FRACTION_IS_MORE_THAN) + `§Y` + x100 to 1 place + `§W%\n` | ..._LESS_THAN | both: "Number of provinces in revolt at least ", "Fewer provinces in revolt than " |
| `leadership` | CLeadershipTrigger, 0x5D5500 | `AppendLocalisedLine`(HAVE_MORE_LEADERSHIP_THAN, $VAL$ = `§Y` + 1 place + `§W`) | T(HAVE_LESS_LEADERSHIP_THAN) + ` §Y` + 1 place + `§W\n` | both (Motherland): "Has at least §Y$VAL$§W leadership.\n", "Has less leadership than" |
| `nationalism` | CNationalismTrigger, 0x5E7050 | T(NATIONALISM_HIGHER_THAN) + `§Y` + itoa + `§W\n` | T(NATIONALISM_LOWER_THAN) ... | both |
| `num_of_allies` | CNumOfAlliesTrigger, 0x5D9010 | T(HAVE_MORE_ALLIES_THAN) + `§Y` + itoa + `§W\n` | T(HAVE_LESS_ALLIES_THAN) ... | both: "Number of allies at least ", "Have fewer allies than " |
| `num_of_cities` | CNumOfCitiesTrigger, 0x5D7FE0 | T(HAVE_MORE_CITIES_THAN) + `§Y` + itoa, **or under THIS or FROM that country's name** + `§W\n` | T(HAVE_LESS_CITIES_THAN) ... | both |
| `num_of_convoys` | CNumOfConvoysTrigger, 0x5FD8F0 | T(TOTAL_NUM_OF_CONVOYS_MORE) + `§Y` + itoa(value / 1000) + `§W\n` | ..._LESS | both: "Total convoys at least ", "Total convoys fewer than " |
| `num_of_ports` | CNumOfPortsTrigger, 0x5D8510 | as `FINDINGS-techtext.md` section 3, confirmed | | |
| `num_of_revolts` | CNumOfRevoltsTrigger, 0x5D7410 | T(THEN_NUMBER_OF_REVOLTS_ARE_MORE_THAN) + `§Y` + itoa + `§W\n` | ..._LESS_THAN | both |
| `num_of_vassals` | CNumOfVassalsTrigger, 0x5D9590 | T(HAVE_MORE_VASSALS_THAN) + `§Y` + itoa + `§W\n` | T(HAVE_LESS_VASSALS_THAN) ... | **neither** in the base game (BlackICE has the first) |
| `last_air_battle_loser_losses`, `last_air_battle_winner_losses`, `last_battle_loser_losses`, `last_battle_winner_losses`, `last_naval_battle_loser_losses`, `last_naval_battle_winner_losses` | 0x603480, 0x602E90, 0x6028A0, 0x6022B0, 0x604060, 0x603A70 | T(LAST_..._LOSSES_MORE) + `§Y` + itoa + `§W\n` | ..._LESS | all, in SemperFi: "Loser Air Losses at least " and the like |
| `land_battles_fought` | CLandBattlesFoughtTrigger, 0x601760 | T(LAND_BATTLES_FOUGHT_MORE) + `§Y` + itoa + `§W\n` + T(CURRENT_NUMBER_OF_DIVISIONS){$CURRENT$ = itoa(the scope country's +0x1080)} + `\n` | _LESS | both, and "(Currently §Y$CURRENT$§W)\n" |
| `naval_battles_fought` | CNavalBattlesFoughtTrigger, 0x601EA0 | the same with NAVAL_BATTLES_FOUGHT_* and +0x1088 | | both |
| `out_of_supply_days` | COutOfSupplyDaysTrigger, 0x604680 | T(OUT_OF_SUPPLY_DAYS_MORE) + `§Y` + itoa + `§W ` + T(DAYS) + `\n` | _LESS | both: "Out of Supply for at least ", "Days" |
| `month` | CMonthTrigger, 0x5D2C40 | T(THE_MONTH_IS_AFTER) + `§Y` + the month's name + `§W\n` | T(THE_MONTH_IS_BEFORE) ... | both, and January to December |
| `num_in_faction` | CNumInFactionTrigger, 0x5FC660 | T(IS_NUM_IN_FACTION_TRIGGER){$VAL$ whole} | T(IS_BELOW_NUM_IN_FACTION_TRIGGER) | both: "Is a member of a faction of at least §Y$VAL$§W members.\n" |

`month`'s name is the null date with its month set to the value (`Date_SetMonth`, 0 is January),
through `Date_MonthName` for the full name.

### 4.3 A text with variables and nothing after (the text holds its own break)

| keyword | class, rva | line (`redWhen` 0) | line (`redWhen` 1) | keys, in the localisation? |
| --- | --- | --- | --- | --- |
| `is_threatend` | CIsThreatendTrigger, 0x5FB030 | T(IS_THREATEND_TRIGGER){$COUNTRY$ = the scope country's name, $VALUE$ trimmed} | T(IS_NOT_THREATEND_TRIGGER) | both |
| `lost_IC` | CLostICTrigger, 0x5F8710 | T(LOST_IC_IS_ATLEAST_TRIGGER){$COUNTRY$, $VALUE$ = x100 to 1 place} | T(LOST_IC_IS_NOT_TRIGGER) | both: "§Y$COUNTRY$§W has lost at least §Y$VALUE$%§W IC §W.\n" |
| `lost_national` | CNationalProvinceTigger, 0x5F7D70 | T(LOST_NATIONAL_PROVINCES_ATLEAST_TRIGGER), the same | ..._NOT_TRIGGER | both |
| `metal` | CMetalTrigger, 0x5F6CA0 | T(METAL_IS_ATLEAST_TRIGGER){$VALUE$ trimmed} | T(METAL_IS_NOT_TRIGGER), "Metal is not §Y$VALUE$§W.\n" | both |
| `money` | CMoneyTrigger, 0x5F5EE0 | T(MONEY_IS_ATLEAST_TRIGGER) | T(MONEY_IS_NOT_TRIGGER) | both |
| `national_unity` | CNationalUnityTrigger, 0x5F33E0 | T(UNITY_IS_ATLEAST_TRIGGER){$VALUE$ trimmed} | T(UNITY_NOT_TRIGGER), "National Unity below §Y$VALUE$%§W\n" | both |

### 4.4 A country, a province, a minister or a law

| keyword | class, rva | line (`redWhen` 0) | line (`redWhen` 1) | keys, in the localisation? |
| --- | --- | --- | --- | --- |
| `ideology` | CIsIdeologyEqualTrigger, 0x5F4ED0 | T(IDEOLOGY_IS_EQUAL_TO_TRIGGER){$NAME$ = the ideology's (+0x5C) name for the scope's country (0x129120)}; $COUNTRY$ filled and unused | T(IDEOLOGY_IS_NOT_TRIGGER) | both: "Ruling party is §Y$NAME$§W.\n" |
| `ideology_group` | CIdeologyGroupTrigger, 0x5F4890 | T(IDEOLOGYG_IS_EQUAL_TO_TRIGGER){$NAME$ = the group's localised name (+0x34)} | T(IDEOLOGYG_IS_NOT_TRIGGER) | both (gold.csv) |
| `<law group> = <law>` | CLawTrigger, 0x5FBD90 | T(IS_LAW_TRIGGER){$LAW$ = the law's name for the scope's country (0x129120), $GROUP$ = the group's localised name} | T(IS_NOT_LAW_TRIGGER), "§Y$LAW$§W is NOT the $GROUP$.\n" | both |
| `minister_alive` | CIsMinisterAliveTrigger, 0x5F5690 | T(MINISTER_ALIVE_TRIGGER){$NAME$ = the minister's name as written (+0x30)} | T(MINISTER_IS_NOT_ALIVE_TRIGGER) | both |
| `is_core` = a province | CIsCoreTrigger, 0x5D6910 | T(HAVE_CORE_IN) + `§Y` + the province's name + `§W\n` | T(HAVENT_CORE) ... | both: "Have a core in ", "Do NOT have a core in " |
| `is_core` = a tag, THIS, FROM, REB | CIsCoreTrigger, 0x5D6910 | T(IS_COUNTRY_CORE){$COUNTRYADJ$ = `§Y` + the adjective + `§W`} + `\n` | T(IS_NOT_COUNTRY_CORE) ... | both: "Is a $COUNTRYADJ$ core", "Is NOT a ..." |
| `is_possible_vassal` | CIsPossibleVassalTrigger, 0x5EE3E0 | `§Y` + the name of the trigger's own tag (+0x40) + `§W` + T(IS_A_POSSIBLE_VASSAL) + `\n` | ... T(IS_NOT_A_POSSIBLE_VASSAL) ... | **neither** |
| `neighbour` | CNeighbourTrigger, 0x5E9070 | T(IS_NEIGHBOUR_WITH) + `§Y` + the name of the tag (+0x40) + `§W\n` | T(IS_NOT_NEIGHBOUR_WITH) ... | both: "Neighbours ", "Does NOT neighbour " |
| `non_aggression_pact` | CNonAgggressionPactTrigger, 0x5F7390 | T(NON_AGGRESSION_PACT_WITH_TRIGGER){$COUNTRY$ = the scope country, $TARGET_COUNTRY$ = the tag, or THIS (+0x18), or FROM (+0x19, `this_scope` +0x18)} | T(NO_NON_AGGRESSION_PACT_WITH) | both |
| `last_mission` | CLastMissionTrigger, 0x5E1C60 | T(PREVIOUS_MISSION_WAS) + `'§Y` + the value as written + `§W'\n` | T(PREVIOUS_MISSION_WASNT) ... | **neither** |

### 4.5 When the target is missing

- `ideology_group` with no group and `ideology` with no ideology: $NAME$ is `§R` + the **literal**
  `NO_SUCH_IDEOLOGY` + `§W` - not a key.
- `minister_alive` with no such minister: `§R` + the literal `COULD_NOT_FIND_MINISTER`, for both
  wordings, with no `§W` and no break.
- `is_core` with a tag of id 0 (REB with no rebel faction, or no country): **an empty string**, both
  wordings.
- `is_capital`, `is_blockaded` and `is_mission_province` name the scope's province - under a country
  scope, province 0, as `has_building` does.

### 4.6 Helpers

- `Modifier_GetNameForCountry` (0x129120), slot 14 of an ideology, a law and their nulls: the text of
  `<key>_<TAG>`, and **where that comes back as the key itself, slot 13, the plain name** - so a
  country may name a law or an ideology of its own.
- `Group_GetLocalisedName` (0x127110): an ideology group's or a law group's +0x34, which its
  constructor (0x526C60, 0x529530) fills from the localisation and leaves empty for the null group.
- `CInternationalizedText_ReplaceInt` (0x682FB0), whose render (0x683220) is itoa;
  `LocaliseKeyToString` (0x60730); `Date_SetMonth` (0x4C420); `Date_MonthName` (0x6AA670).

### 4.7 Kept as read, though they look wrong

1. **`max_manpower`**: the plain condition is worded LESS, the body never localises - the raw key
   shows - and the figure is followed by `%`.
2. **Fourteen keys in seven triggers are missing from the base game**: IS_ATTACKER and
   IS_NOT_ATTACKER, IS_MISSION_TARGET and IS_NOT_MISSION_TARGET, IS_A_POSSIBLE_VASSAL and
   IS_NOT_A_POSSIBLE_VASSAL, PREVIOUS_MISSION_WAS and _WASNT, HAVE_MORE and HAVE_LESS_VASSALS_THAN,
   HAVE_MAX_MANPOWER_GREATER_THAN and _LESS_THAN, HAVE_MORE and HAVE_LESS_MANPOWERPERCENT_THAN.
3. **`num_of_cities` under THIS or FROM writes the country's name where the number goes** - "Number of
   cities at least §YGermany§W".
4. **`is_possible_vassal` and `neighbour` name the tag at +0x40** and never resolve THIS or FROM.
5. **`government_in_exile` ends in two breaks** (the text's and the code's), and its join is ` §W`,
   the space before the colour.
6. **`is_blockaded` has two spaces**: the code's `§W ` and the text's leading space.
7. **`leadership` builds its two wordings two ways**, the first doubling the `§Y`/`§W` round $VAL$.
8. **The percent sign stands differently**: `revolt_percentage` writes `§W%`, `manpower_percentage`
   `%§W`.
9. **`neutrality` and `base_neutrality` read the same**, though they test different figures.
10. **`num_of_convoys` cuts its value to whole convoys.**
11. **`metal` and `money` say "is not"** where the condition means "below".

### 4.8 Not established

- **What a missing key shows.** Brief C takes `FINDINGS-effecttext.md`'s `NO_TEXT_FOR_KEY <key>`;
  brief D notes that `Modifier_GetNameForCountry`'s fallback only works if a missing key comes back as
  the key itself, and that `NO_TEXT_FOR_KEY` is written by 0xA85F20 on a path not tied to `Render`.
  Settled in section 6 below.
- The rest of `is_core`'s REB arm past `FindPersistentByIdPair`; 0x4BC800 gives the placeholder tag
  `---` with id 0.
- What the null law's and the null ideology's slot 14 says.
- Not recorded: 0x6832B0 (the string replacement's constructor) and 0x683220 (the whole number's
  render), left in the `frontier` with 0x4BC800 and 0xA85F20.

## 5. Trigger leaves, `owned_by` to `year`, and the scope blocks

*Brief E.* The same shape; each of the 46 is its own class's alone at slot 8 (`vtable.py --holding`);
**no leaf reads `depth`**. Every leaf chooses its key by `redWhen` (`cmp byte [ebp+0x10]`) but
`port` and `reserves`, which compare it with their own value. The technology leaf (0x5DB480) is
recorded and confirmed. Joins besides section 0's: `§!\n` (VA 0x15B5E18).

Two shapes: most are **KEY + `§Y` + value + `§W\n`**; the **$VAR$ leaves** render the text with its
replacements straight into the line and **append nothing** - the break is the table's own `\n`. The
replacement objects are 0x40 bytes, made through 0x6832B0 and pushed by the function recorded as
`SubWindowMap_Add` (below). **v/1000** is the value over 1000, whole.

### 5.1 Leaves

| keyword | class, rva | line (`redWhen` 0) | line (`redWhen` 1) | keys, in the localisation? |
| --- | --- | --- | --- | --- |
| `owned_by` | COwnedByTrigger, 0x5DF3A0 | T(OWNED_BY) + `§Y` + country + `§W\n` | T(NOT_OWNED_BY) ... | both: "Owned by " / "Is NOT owned by " |
| `owns` | COwnsTrigger, 0x5D5A30 | T(OWNS) + `§Y` + the name of province `value` + `§W\n` | T(DO_NOT_OWN) ... | both: "Owns " / "Does NOT own " |
| `port` | CPortTrigger, 0x5E09C0 | `= yes`: T(HAVE_A_PORT_IN) + `§Y` + the scope's province + `§W\n` | `= yes`: T(HAVE_NOT_A_IN) ...; `= no` swaps the two | HAVE_A_PORT_IN "Have a port in "; **HAVE_NOT_A_IN missing** |
| `province_id` | CProvinceIdTrigger, 0x5EE950 | T(PROVINCE_IS) + `§Y` + the province's **name** + `§W\n` | T(PROVINCE_IS_NOT) ... | both: "Province ID is " / "Province ID is NOT " |
| `pure_revolt_risk` | CPureRevoltRiskTrigger, 0x5E6A30 | T(PURE_REVOLT_RISK_HIGHER_THAN) + `§Y` + itoa + `§W\n` | T(PURE_REVOLT_RISK_LOWER_THAN) ... | both |
| `rare_materials` | CRareMaterialsTrigger, 0x5F6930 | T(RARE_MATERIALS_IS_ATLEAST_TRIGGER){$VALUE$ trimmed} | T(RARE_MATERIALS_IS_NOT_TRIGGER) | both |
| `region` | CRegionTrigger, 0x5E56C0 | `§Y` + the scope's province + `§W` + T(IS_IN_REGION) + `§Y` + the region's name + `§W\n` | ... T(IS_NOT_IN_THE_REGION) ... | both: "Is in the region" (no spaces) / "Is NOT in the region " |
| `relation` | CRelationTrigger, 0x5DDF50 | `§Y` + the scope's country + `§W ` + T(HAVE_DIPLOMATIC_RELATION) + ` ` + `§Y` + n + `§W ` + T(WITHG) + ` ` + `§Y` + who + `§W\n` | the same with HAVE_LESS_DIPLOMATIC_RELATION and WITHL | "has a relation of", "or greater with", "with"; **HAVE_LESS_DIPLOMATIC_RELATION missing** |
| `reserves` | CReservesTrigger, 0x606A00 | `= yes`: T(HAS_RESERVES) + `\n` | T(HAS_NO_RESERVES) + `\n` | **both missing** |
| `revolt_risk` | CRevoltRiskTrigger, 0x5E7690 | T(REVOLT_RISK_HIGHER_THAN) + `§Y` + itoa + `§W\n` | T(REVOLT_RISK_LOWER_THAN) ... | both |
| `organisation` | CRulingOrganisationTrigger, 0x5F9820 | T(ORGANISATION_IS_ATLEAST_TRIGGER){$IDEOLOGY$, $VALUE$ trimmed} | T(ORGANISATION_IS_NOT_TRIGGER) | both: "§Y$IDEOLOGY$§W has at least §Y$VALUE$§W in organisation§W.\n" |
| `popularity` | CRulingPopularityTrigger, 0x5F9F60 | T(POPULARITY_IS_ATLEAST_TRIGGER), the same | T(POPULARITY_IS_NOT_TRIGGER) | both |
| `skill_advantage` | CSkillAdvantageTrigger, 0x606D10 | T(SKILL_ADVANTAGE_MORE) + `§Y` + itoa + `§!\n` | T(SKILL_ADVANTAGE_LESS) ... | **both missing** |
| `skill` | CSkillTrigger, 0x607280 | T(SKILL_MORE) + `§Y` + itoa + `§!\n` | T(SKILL_LESS) ... | **both missing** |
| `spies` | CSpyCountTrigger, 0x6055F0 | T(SPIES_INFILTRATED_MORE) + `§Y` + trimmed + `§W\n` | T(SPIES_INFILTRATED_LESS) ... | present, **English "Grk"** (tfh.csv) |
| `spy_mission_count` | CSpyMissionCountTrigger, 0x605BF0 | T(ALLOCATED_SPIES_FOR_MISSION_TRIGGER_MORE){$MISSION$, $VALUE$} | ..._LESS | present, **the English swapped**: _MORE says "less than", _LESS "at least" (the German too) |
| `strat_bomb_impact` | CStatBombImpactTrigger, 0x5FFB80 | T(TOTAL_BOMB_IMPACT_MORE) + `§Y` + FormatFixedPoint(v, 1) + `§W\n` | ..._LESS | both |
| `strat_allies_impact` | CStratAlliesImpactTrigger, 0x5FF660 | T(TOTAL_ALLIED_IMPACT_MORE), 1 place | ..._LESS | both |
| `strat_convoy_impact` | CStratConvoyImpactTrigger, 0x5FF140 | T(TOTAL_CONVOY_IMPACT_MORE), 1 place | ..._LESS | both |
| `strategic_resource` | CStrategicResourceTrigger, 0x6054C0 | T(DOES_HAVE_STRATRES){$NAME$ = the resource's slot 6 name} | T(DOES_NOT_HAVE_STRATRES) | both: "Has §Y$NAME$§W.\n" |
| `<unit type> = N` | CSubUnitTrigger, 0x5DACA0 | T(HAVE_MORE) + ` §Y` + the type's name + `§W ` + T(THAN) + `§Y` + n + `§W\n` | T(HAVE_LESS) ... | **HAVE_MORE, HAVE_LESS and THAN all missing** |
| `supplies` | CSuppliesTrigger, 0x5F7010 | T(SUPPLIES_IS_ATLEAST_TRIGGER){$VALUE$ trimmed} | T(SUPPLIES_IS_NOT_TRIGGER) | both |
| `surrender_progress` | CSurrenderProgressTrigger, 0x5F8270 | T(SURRENDER_PROGRESS_ATLEAST_TRIGGER){$COUNTRY$ = the scope's country, $VALUE$ = FormatFixedPoint(v, 1)} | ..._NOT_TRIGGER | both: "§Y$COUNTRY$§W surrender progress at least §Y$VALUE$%§W.\n" |
| `tag` | CTagTrigger, 0x5E89B0 | T(IS) + `§Y` + country + `§W\n` | T(IS_NOT) ... | both: "Is " / "Is NOT " |
| `threat` | CThreatTrigger, 0x5F2D20 | T(THREAT_IS_ATLEAST_WITH_TRIGGER){$COUNTRY$ = the scope's, $TARGET_COUNTRY$ = `which`, $VALUE$ = itoa(+0x48)} | T(THREAT_IS_NOT_TRIGGER) | both |
| `total_amount_of_planes` | CTotalAmountOfPlanesTrigger, 0x5FCFF0 | T(TOTAL_NUM_OF_PLANES_MORE) + `§Y` + v/1000 + `§W\n` + T(CURRENT_NUMBER_OF_DIVISIONS){$CURRENT$ = the country's planes} + `\n` | ..._LESS | both |
| `total_amount_of_ships` | CTotalAmountOfShipsTrigger, 0x5FCC10 | the same with ships | ..._LESS | both |
| `total_defensives` | CTotalDefensivesTrigger, 0x6011C0 | T(TOTAL_LAND_DEFENSE_BATTLES_MORE) + `§Y` + v/1000 + `§W\n` | ..._LESS | both |
| `total_ic` | CTotalICTrigger, 0x5FEBA0 | T(TOTAL_IC_MORE), v/1000 | T(TOTAL_IC_LESS) | both |
| `total_num_of_ports` | CTotalNumOfPortsTrigger, 0x5D8A90 | T(HAVE_MORE_TOTAL_PORTS_THAN) + `§Y` + itoa + `§W\n` | T(HAVE_LESS_TOTAL_PORTS_THAN) ... | **both missing** |
| `total_of_ours_sunk` | CTotalOfOursSunkTrigger, 0x5FE5F0 | T(TOTAL_LOST_SHIPS_MORE), v/1000 | ..._LESS | both |
| `total_offensives` | CTotalOffensivesTrigger, 0x600660 | T(TOTAL_LAND_OFFENSIVES_MORE), v/1000 | ..._LESS | both |
| `total_sea_battles` | CTotalSeaBattlesTrigger, 0x6000B0 | T(TOTAL_SEA_BATTLES_MORE), v/1000 | ..._LESS | both |
| `total_sunk_by_us` | CTotalSunkByUsTrigger, 0x5FDF90 | T(TOTAL_SUNK_BY_US_MORE), v/1000 | ..._LESS | both |
| `total_we_bomb` | CTotalWeBombTrigger, 0x600C10 | T(TOTAL_BOMBINGS_MORE), v/1000 | ..._LESS | both |
| `trait` | CTraitTrigger, 0x6078C0 | T(HAS_TRAIT){$NAME$ = the trait's name} | T(DOESNT_HAVE_TRAIT) | **both missing** |
| `truce_with` | CTruceWithTrigger, 0x5EB120 | T(HAS_TRUCE_WITH) + `§Y` + country + `§W\n` | T(HAS_NO_TRUCE_WITH) ... | both |
| `undeclared_war_with` | CUndeclaredWarWithTrigger, 0x5EA500 | T(IS_AT_UNDECLARED_WAR_WITH) + ... | T(IS_AT_PEACE_WITH) ..., `war_with`'s | both |
| `unit_has_leader` | CUnitHasLeaderTrigger, 0x5EBB00 | T(HAVE_A_UNITS_WITH_A_LEADER) + `\n` | T(HAVE_NO_UNITS_WITH_A_LEADER) + `\n` | both |
| `unit_in_battle` | CUnitInBattleTrigger, 0x5EB750 | T(HAVE_UNITS_IN_BATTLE) + `\n` | T(HAVE_NO_UNITS_IN_BATTLE) + `\n` | both |
| `units_in_province = N` | CUnitsInProvinceTrigger, 0x5E9700 | T(HAVE_MORE_UNITS_IN_THAN){$PROVINCE$ = `§Y` + name + `§W`} + `§Y` + n + `§W\n` | T(HAVE_LESS_UNITS_IN_THAN) ... | both: "Units in $PROVINCE$ at least " |
| `units_in_province = THIS/FROM` | the same body | T(HAVE_UNITS_IN){$PROVINCE$, $COUNTRY$, each `§Y`..`§W`} + `§W\n` | T(HAVE_NO_UNITS_IN) ... | both: "$COUNTRY$ have units in $PROVINCE$." |
| `check_variable` | CVariableTrigger, 0x5F02C0 | T(VARIABLE) + the name as written + T(IS_GREATER_THAN) + `§Y` + FormatFixedPoint(v, 2) + `§W\n` | ... T(IS_EQUAL_OR_LESS_THAN) ... | all: "Variable ", " is greater than ", " is equal to or less than " |
| `vassal_of` | CVassalOfTrigger, 0x5EEFC0 | T(IS_VASSAL_OF) + `§Y` + the stored tag's name + `§W\n` | T(IS_NOT_VASSAL_OF) ... | both: "Is a puppet of " |
| `war_with` | CWarWithTrigger, 0x5EAAC0 | T(IS_AT_WAR_WITH) + ... | T(IS_AT_PEACE_WITH) ... | both |
| `war_exhaustion` | CWarexhaustionTrigger, 0x5D3C20 | T(WAR_EXHAUSTION_MORE_THAN) + `§Y` + FormatFixedPoint(v, 1) + `§W\n` | T(WAR_EXHAUSTION_LESS_THAN) ... | both |
| `year` | CYearTrigger, 0x5D25F0 | T(THE_YEAR_IS_AFTER) + `§Y` + itoa + `§W\n` | T(THE_YEAR_IS_BEFORE) ... | both: "The year is at least " / "The year is before " |

**Where the names come from:**
- **The scope's country** (+0x10/+0x14): `relation`, `threat`'s $COUNTRY$, `surrender_progress`,
  and the ruling ideology of `organisation` and `popularity`.
- **THIS and FROM**: `owned_by` - THIS by `EventScope_GetCountryTag`, FROM the scope's **own**
  +0x18/+0x1C; `tag` - THIS `this_scope`'s country read directly, FROM `this_scope`'s FROM;
  `truce_with`, `war_with`, `undeclared_war_with` and `threat`'s `which` - THIS by
  `EventScope_GetCountryTag`, FROM `this_scope`'s; `relation` - THIS `this_scope`'s country, else the
  **controller** of `this_scope`'s province, FROM `this_scope`'s, else the controller of the FROM
  province, as its `Evaluate` falls back; `units_in_province` and `<unit type>` - THIS by
  `EventScope_GetCountryTag`, FROM the scope's own +0x18.
- **$IDEOLOGY$**: section 4.6's `Modifier_GetNameForCountry`; with no ruling ideology `§R` +
  `NO_SUCH_IDEOLOGY` + `§W`.
- **A region's name**: its slot 6 (0xAD150), the string at +0x34 - but where that equals the key
  (+0x18) and the region has provinces, T(REGION_NAME) ("$NAME$ Region") with its first province's
  name. That +0x34 is the localised name is `inferred`.
- **A unit type's name**: its slot 6 (0x5A38A0), the text of its key (+8).
- **$MISSION$**: `SpyMissionTitle` (0x12D7A0), by index - 0 SPYMISSION_COUNTER_ESPIONAGE_TITLE,
  1 _MILITARY_, 2 _TECH_, 3 _BOOST_RULING_PARTY_, 4 _BOOST_OUR_PARTY_, 5 _LOWER_NATIONAL_UNITY_,
  6 _INCREASE_THREAT_, 7 _RAISE_NATIONAL_UNITY_, 8 _COVERT_OPS_, else SPYMISSION_NONE_TITLE.

**Where the target is missing**: `owns` and `province_id` index the province by the value unchecked,
and `owns = this`/`from` leaves it 0, naming province 0; an unknown `region` or `strategic_resource`
leaves a null the text calls through - a fault; a trait cannot be null (the null trait);
`vassal_of` prints the stored tag even for THIS and FROM, which the loader never writes; a scope of a
country alone names province 0 (`port`, `region`, `units_in_province`), and an unresolved country the
name of id 0 - **neither name was read**.

### 5.2 The scope blocks

- **`and`** (0x5D0720), as `FINDINGS-techtext.md` section 2. **`enemy = { }` (CEnemyScopeTrigger) and a
  mean time to happen's `modifier` (CMTTHModifier) hold the same body**: no header at depth 0,
  AND_TRIGGER_STARTS ("All of the below") deeper, and their children's asterisks asked in the
  **outer** scope, not the enemy's.
- **`any_core`** (0x5E64F0): `indent(depth)`; its own asterisk only at depth 0 (red where its
  `Evaluate` on the scope it was given equals `redWhen`); T(ANY_CORE_STARTS) + `":\n"` ("Any Core
  Country"); then the base for its children in **the same scope**, the same `redWhen`, at depth + 1 -
  so they have no asterisks. One indent; no country named.
- **`any_neighbor_country`** (0x5E5FD0): the same with T(NEIGHBOR_COUNTRY_STARTS) ("Neighboring
  country").
- **`any_neighbor_province`** (0x5DCED0): `indent(depth)`, the asterisk at depth 0, **`indent(depth)`
  again** + T(NEIGHBOR_PROVINCE_STARTS) ("Any neighboring province") + `":\n"`, then the base at
  depth + 1 in the scope unchanged - `any_owned_province`'s shape without "(country)".
- **A region** (0x5DCA10): `indent(depth)`, the asterisk at depth 0, the region's name + `":\n"` (no
  key); then, **where the region has a province, it writes 0 into the caller's `scope->province`**
  (`mov [eax+0x28], ebx`, `eax = [ebp+0xC]`, VA 0x9DCBBA); then the base at depth + 1. Every sibling
  drawn after it, and every asterisk asked for one, sees province 0.
- **A context, every `X = { }`** (0x5D1590):
  1. **The name**: a literal tag (+0x148/+0x14C) first, the country's name; otherwise by the token -

     | token | keyword | name written | English |
     | --- | --- | --- | --- |
     | 0xC | a province's number | the province's name | |
     | 0x1EC | `owner` | T(TRIGGER_OWNER) | "Province Owner" |
     | 0x1ED | `controller` | T(TRIGGER_CONTROLLER) | "Province Controller" |
     | 0x2F3 | `emperor` | T(TRIGGER_EMPEROR) | missing |
     | 0x34F | `FROM` | T(TRIGGER_FROM) | "From" |
     | 0x359 | `ally` | T(TRIGGER_ALLY) | "Any Ally" |
     | 0x377 | `THIS` | T(TRIGGER_THIS) | "This" |
     | 0x3B4 | `capital_scope` | T(TRIGGER_CAPITAL) | "Capital" |
     | 0x3E8 | `sea_zone` | T(TRIGGER_SEA_ZONE) | "Sea Zone Outside" |
     | 0x621 | `local_enemy` | T(TRIGGER_LOCAL_ENEMY) | "Local Enemy" |
     | 0x623 | `revolution_target` | T(TRIGGER_REVOLUTION_TARGET) | missing |
     | 0x631 | `overlord` | T(TRIGGER_OVERLORD) | "Liege" |
     | other | | nothing | |

     `MakeScope` resolves neither `emperor` nor `revolution_target`.
  2. `indent(depth)`, its own asterisk at depth 0 (its `Evaluate` on the outer scope), the name.
  3. The children are drawn once by the base **at depth 0** in the rebound scope (whether it resolved
     is not asked) and the result split at `\n`:
     - **more than two pieces** - two lines or more: `":\n"` + the base again at depth + 1;
     - **otherwise, one line**: the child's line loses a leading `(§R*§W)` or `(§G*§W)` where it is
       longer than 8 characters, its first byte is lower-cased (`CharLowerBuffA`), and `" "` + it is
       appended to the name - `GER = { war_with = FRA }` reads "Germany is at war with §YFrance§W\n";
     - a block with no condition leaves the name and a space, and no break.
- **`CAndTrigger::GetText`** (0x5E64C0): `out = ""`, `ret 0x10`, **held by 18 tables** - `and` and its
  heirs (any_core, any_neighbor_country, any_neighbor_province, any_owned_province, the context,
  `enemy`, the mean time's modifier, the region); `or` and `not`, which **derive from `CTrigger`, not
  from `and`** as the record had it; four boolean combat conditions (CCombatHasArmourUnit,
  CCombatIsConvoy, CCombatIsWinner, CHasCombinedArmsBonus); and CCombatModifier, CCombatTerrain,
  CCombatTemperature. A fold among `CTrigger`'s heirs: **those seven tactic conditions have no text**.
  The name is kept; a class-free name would be the trap 4 answer, and is left to the record's owner.

### 5.3 BiceLib's account (`FINDINGS-techtext.md` section 4) against the bytes

- **Point 1 holds**: the six header patch sites (VA 0x5D1F1E, 0x5DD60B, 0x5DCA61, 0x5DCF25, 0x5E6025,
  0x5E6545) are each the `jle` over that renderer's indent loop; for `any_owned_province` and
  `any_neighbor_province` the loop's string is used twice, so skipping it removes both indents.
- **Point 5 holds and is short**: VA 0x5D20A1..0x5D20A5 (`mov edx,[ebp+0x10]; inc ecx; push ecx`) is
  the depth + 1 of the many-line form only; **the one-line form** - a context with one one-line
  condition - is untouched and was never described.
- **"A country scope" is every context keyword above**, not a tag, an owner and a controller alone.
- **Nothing in the account** covers the region writing the caller's province to 0, or the scope
  blocks drawing their children in the scope unchanged.

### 5.4 Kept as read, though they look odd

1. `region`'s line has no spaces round "Is in the region".
2. `province_id` says "Province ID is " and gives the name.
3. `port` and `reserves` choose by `redWhen` equal to the value, so `port = no` reads HAVE_NOT_A_IN,
   a missing key.
4. `check_variable` says "is greater than" for at least.
5. `undeclared_war_with`'s negation is "Is at peace with".
6. `total_amount_of_planes` and `_ships` make two lines and a blank; the second is unindented and has
   no asterisk.
7. `skill` and `skill_advantage` end in `§!`, not `§W`.
8. `vassal_of` ignores THIS and FROM, which its `Evaluate` resolves.
9. `owned_by`'s FROM is the scope's own, where `tag` and `war_with` take `this_scope`'s.
10. **Fifteen keys missing**: HAVE_NOT_A_IN, HAVE_LESS_DIPLOMATIC_RELATION, HAS_RESERVES,
    HAS_NO_RESERVES, SKILL_ADVANTAGE_MORE and _LESS, SKILL_MORE and _LESS, HAVE_MORE, HAVE_LESS, THAN,
    HAVE_MORE and HAVE_LESS_TOTAL_PORTS_THAN, HAS_TRAIT, DOESNT_HAVE_TRAIT; and TRIGGER_EMPEROR and
    TRIGGER_REVOLUTION_TARGET in the context's names; "Grk" for SPIES_INFILTRATED_*; ALLOCATED_SPIES_*
    swapped.

### 5.5 For the record, and not read

- **`SubWindowMap_Add` (0x6C44F0) has 538 callers** (`findRefs --callers`), against its comment's "only
  caller"; one is inside `CInternationalizedText::Replace` (VA 0xA82F97). It is the general push of a
  {string, pointer} pair onto a vector in EDI - the `$VAR$` push - and its name and comment are wrong.
  Not touched by the brief.
- `CTrigger`'s slot 8 `vftable_slots` signature still says `unknown1`/`unknown2`.
- Not read: 0x60730 (section 4.6 enters it) and 0x6832B0; the null strategic resource's slot 6
  (`strategic_resource = none`); the names of country 0 and province 0; how a missing key renders
  (section 6); where a table's `\n` becomes a break.

## 6. A key nobody wrote shows itself

Briefs C and E took `FINDINGS-effecttext.md`'s word that a missing key renders as `NO_TEXT_FOR_KEY
<key>`; briefs A and D found it renders as the key. **A and D are right**, read in transcription off
the decompiled C:

- `GetText` (0xA82490 VA) looks the key up (0xA86F70); **where it is not there**, it takes the key's
  holder (0xA86DA0), and calls `AddTextEntry(holder, key, "")`;
- `AddTextEntry` (0xA84D30 VA) makes the entry's text by **running the key itself through the text
  parser** (0xA83D90 on the key, the parts moved into the new entry by 0xA83830);
- so the text object's entry is the key, parsed: **a missing key renders as the key**, its colour codes
  working - which is how the effects colour a name by looking up `"§Y" + name + "§W"` (section 1), and
  how `Modifier_GetNameForCountry` knows a `<key>_<TAG>` is missing (its text equals the key).
- `NO_TEXT_FOR_KEY ` (VA 0x15FE204) belongs to 0xA85F20, a lookup by key in another table, reached
  through a vftable (no direct caller), which logs "Failed to find text key" first. What that table
  is was not read.

So each of the missing keys in sections 3 to 5 shows **as its own name**, `HAS_FULL_FRONTAGE` and the
rest. The record's comment on `AddTextEntry`, which said the opposite, is revised
(`fragments/merged/missing-key-text.json`). **A key of no length** goes to a fixed entry (0x686DA0)
and renders empty - `add_division`'s nothing (section 1).
