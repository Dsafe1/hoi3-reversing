# The closed list of modifier kinds, an order of battle's unknown leader, and where `extra_amphibious_defence` goes

*Read 2026-11-14 by the `smallgaps` agent for three loose ends of OpenHOI3's readme; the three callers of
`ModifierDefinitionDatabase::Add` checked by the collecting session (`findRefs --callers 0x45C5D0`: four sites at `0x4592xx`,
one in `CIdeologyGroup::LoadKey` at `0x527086`, one at `0x5839E2`). The fragment is `fragments/merged/modifier-kinds-closed-list.json`. Addresses are rvas unless written as `0x4...`/`0x5...`
virtual addresses, which the disassembly quotes.*

## In short

- **A modifier block's keys are a closed list of 142 in Their Finest Hour**: the engine's 108 definitions (107 keys -
  `naval_intel_boost` is made twice), the 32 mission efficiencies by the **order's own key** (`convoy_raid`, not
  `convoy_raid_eff`), and one `suseptibility_<tag>` for each faction of `common/ideologies.txt` - three. 143
  definitions, which is the "143 modifier kinds" read live earlier. `confirmed`.
- **All 143 exist before the first file of modifiers is read**, except that a faction's own kind is made after its own
  block - so a faction's `modifier` cannot name its own kind or a later faction's. `confirmed`.
- **A key outside the list** is logged `unknown modifier '<key>' in file <file>` and dropped wherever CModifier::LoadKey
  reads it; **a building drops it in silence**. `confirmed`.
- **Every modifier file of the base game, Their Finest Hour and BlackICE uses only keys on the list** - static and event
  modifiers, laws, minister types, occupation policies, strategic resources, triggered modifiers, governments, government
  positions, ideologies and faction modifiers, buildings. Measured by a scan; the positive control is that every key the
  files do use is found.
- **An order of battle's `leader = N` with no leader N does nothing at all** - no log, nothing made - and the unit is
  given the best free leader as the game is entered, as any unit without one is. `confirmed`.
- **`extra_amphibious_defence` is stored as text** on a pending list beside the map it is meant to fill; what resolves
  it was not found, and it does not matter for play (FINDINGS-transport.md, B.4: the only reader asks a fleet's summed
  definition, whose map is always empty). `confirmed` for the pending list.

## 1. The definitions, and when each is made

The modifier-definition vector (begin `0x1686194`, end `0x1686198`, capacity `0x168619C`) is appended to by
`ModifierDefinitionDatabase::Add` (`0x5C5D0`), which has exactly three callers among its 110 direct calls:

| caller | what it adds | when (the application's init) |
| --- | --- | --- |
| `InitModifierDefinitions` (`0x56E00`) | 108 definitions, each built with a name, a save token, an id and two flags | `0x636779` |
| `InitMissionEfficiencyModifiers` (`0x183810`) | 32, one per mission index 1..32, token = the order's save token, name = that token's text + `_eff` | `0x636783` |
| `CIdeologyGroup::LoadKey` (`0x126E60`), its `faction` case | one per faction, `suseptibility_` + the faction's tag | through the ideologies loader `0x127470`, called at `0x63682F` |

and the first file of modifiers after them is static and event modifiers (`0x636B34`), then minister types
(`0x636D63`), buildings (`0x637067`), governments (`0x6371EC`), laws (`0x637DC6`), occupation policies (`0x63870A`),
strategic resources (`0x638861`), triggered modifiers (`0x63893E`).

**The key a script writes is the definition's save token.** `CModifier::LoadKey` (`0x59620`) compares the key's token
with each definition's `+0x20`; the tokenizer lower-cases a bare word before looking it up
(FINDINGS-effectgrammar.md, section 1), so a key matches without case, and a quoted key is never a keyword and so
never a kind. The 108 tokens, read off each `push <token>` before `CModifierDefinition_Construct` (`0x56D50`) in
`InitModifierDefinitions`, give the 107 keys in order:

    minimum_revolt_risk local_revolt_risk global_revolt_risk local_manpower global_manpower
    local_manpower_modifier global_manpower_modifier attrition war_exhaustion max_war_exhaustion fort_level
    coastal_fort_level infrastructure local_infrastructure global_infrastructure ic local_ic global_ic
    local_crude_oil global_crude_oil local_energy global_energy local_metal global_metal local_rare_materials
    global_rare_materials local_supplies global_supplies local_fuel global_fuel local_money global_money
    local_leadership global_leadership local_leadership_modifier global_leadership_modifier drift_speed
    suseptibility incorporate_cost territorial_pride war_consumer_goods_demand peace_consumer_goods_demand
    espionage_bonus dissent national_unity naval_capacity air_capacity align_towards radar_level
    supply_consumption peacetime_manpower_rotation unit_recruitment_time unit_start_experience unit_repair
    counter_intelligence counter_espionage threat_impact threat_resistance peace_offmap_intel offmap_land_intel
    offmap_naval_intel offmap_industry_intel offmap_political_intel combat_movement_speed attack_reinforce_chance
    defend_reinforce_chance combat_width org_regain national_unity_effect ruling_party_support land_organisation
    air_organisation naval_organisation research_efficiency industrial_efficiency local_anti_air
    local_partisan_support reserves_penalty_size neutrality_change partisan_efficiency naval_base_efficiency
    supply_throughput officer_recruitment neutrality global_resources local_resources reinforcement_bonus
    air_build_speed land_build_speed rocket_build_speed tank_build_speed naval_build_speed fuel_conversion
    casualty_trickleback hard_attack soft_attack nuke_research amm_movement_speed winter_effects jungle_effects
    leader_defence sw_national_unity_effect land_intel_boost naval_intel_boost local_underground
    strategic_resource_efficiency local_unit_speed

(`naval_intel_boost`, token `0x7F2`, is constructed twice, at `0x4591C4` and `0x45926E`; the first match by position
wins in `CModifier::LoadKey`.) They are the keys `modifierIds.json`'s 107 display names pair with.

The 32 mission keys, `MissionIndexToOrderToken` (`0x184640`) for 1..32: `support_attack strategic_redeployment
move_order rebase reserves patrol intercept sortie convoy_escort convoy_raid air_convoy_raid transport invasion
strategic_bomb logistical_strike runway_cratering installation_strike ground_attack interdiction air_intercept
carrier_protection paradrop_mission port_strike naval_strike rebase_to_carrier nuke_mission transport_supplies_mission
rebase_air air_reserve air_superiority join_fleet join_air`.

**The faction's kind** (`0x526FAF`..`0x52708B`): the `faction` case makes a `CFaction` (`operator new(0xD8)`,
`0x5224B0`), stores it at the group's `+0x54`, and has it load its block (slot 3) - its `modifier` with it. Only then is
`suseptibility_` + the faction's `+0xC` built (`0xA5B150`), turned into a token (`0xA69CA0`), and a definition made
with that token and that string as its name, both flags set (`push 1; push 1`), id = the definition count - also
stored at the faction's `+0xB4` - and appended (`0x527086`). `+0xC` is taken to be the faction's `tag`, `inferred`
from the keys the files write: Their Finest Hour's `minister_types.txt` uses `suseptibility_axis`,
`suseptibility_allies` and `suseptibility_comintern`, the three tags of `ideologies.txt`.

## 2. Which blocks are read through `CModifier::LoadKey`

Seven classes call it from their own `LoadKey` after their own keys (the seven direct callers):
`CTriggeredModifier` (`potential`, `trigger`), `CGovernment` (`duration`, `valid_for_new_country`, `election`, then an
ideology's or a post's name), `CIdeology` (`color`), `CLaw` (`allow`, `cost`), `CMinisterType` (`decay`),
`CGovernmentPosition` (`changeable`), `COccupationPolicy` (`allow`). Six tables have it as slot 4 directly (a scan of
`.rdata` for the pointer): `CModifier`, `CProvinceModifier`, `CStaticModifier` (static and event modifiers),
`CStrategicResource` and `CNullStrategicResource`, and `CFactionModifier` (a faction's `modifier`).
`CModifier::LoadKey`'s own key, `icon`, is therefore taken by every one of them. `CTrait`, though a `CModifier`, is
neither in those tables nor among the seven callers - its keys are trait effects, not kinds; its own `LoadKey` was not
read.

## 3. Buildings

`CBuilding` is not a `CModifier`. `CBuilding::LoadKey` (`0xB6950`), after its sixteen cases, walks the definitions in
order and, at the first whose token matches, sets `effect` (`+0xC`) and `effect_size` (`+0x8`, TokenToFixedPoint) and
returns; a key that matches none is dropped **without a log** - the function's only log lines are the prerequisite
lists' `Unknown building`. A second matching key replaces the first. `icon` is not a building's key and is no kind, so
it is dropped too.

## 4. `extra_amphibious_defence`

`CSubUnitAmphibiousMult::LoadKey` (`0x1A3280`) does not look anything up. For each key of the block it copies the key's
text into a string, reads the value with TokenToFixedPoint (thousandths), and appends the pair to a pending list at its
own `+8` - CSubUnitDefinition `+0x208` - through `AmphibiousMultPending_PushBack` (`0x142FC0`), a
`std::vector<{string, int}>::push_back` with the vector in EDI and the element in ECX. Nothing is logged for any name.
The copy constructor (`0x136570`) copies the pending list (`0x536A57`) before the map at `+0x218`.

What turns the pending names into the map keyed by `type_index` - and what it does with a name that is no unit type -
was not found. It does not reach play: `BM_AMPH_PENALTY` asks the carrying fleet's summed definition's map, which
`CUnit::RebuildDefinition` never fills (FINDINGS-transport.md, B.4), so `s` is always 1000.

## 5. An order of battle's leader that no file declares

`CUnit::LoadKey`'s `leader` case (`0x5B7747`): `FindPersistentByIdPair({0x25, atoi(value)})`, and on 0 `je 0x5B7F4E`,
which is the function's common epilogue (`mov ecx,[esp+0x43c]; pop edi; pop esi; mov fs:[0],ecx; pop ebx; mov esp,ebp;
pop ebp; ret 8`). Nothing is logged and nothing is made; the unit keeps whatever leader it had - none for a new unit,
or what an earlier `leader` line in the same block set. The block form (a save's `{ id type }`) calls
`ParseObjectReference` and `SetLeader` only on a non-null answer (`0x5B77D6`). A unit left without one is given the best
free leader of its country as the game is entered (FINDINGS-leaderassign.md, section 8). This settles that file's
*Not established* item "`0x1B7F4E`, what an order of battle naming an unknown leader does".

Measured: no order of battle of the base game or Their Finest Hour names an undeclared leader (1,291 and 1,413
`leader` lines); BlackICE has 33 such lines, none in a file a country's history names as its start.

## Not established

- What resolves `extra_amphibious_defence`'s pending names into the map, and what it does with an unknown name.
- Whether anything appends to the modifier-definition vector without `ModifierDefinitionDatabase::Add` (an inlined
  push_back or a call through a pointer); writers of the end pointer were not searched for.
- That the faction's `+0xC` is its `tag` rests on the file keys agreeing, not on a reading of `CFaction::LoadKey`.
- What a known kind with a block for its value does (`ParseThousandths` fails, `ReportParseError`, the slot set to 0,
  as `CModifier::LoadKey` reads; what the tokenizer then does with the block's contents was not followed).

## Corrections

- `FINDINGS-leaderassign.md`, *Not established*: the unknown leader is settled (section 5 above).
- `ModifierDefinitionDatabase::Add` was `likely`, named from one caller; it has the three above.
