# Which defines.lua entries the executable reads, and where

Read out of the executable on 2026-11-18, for a survey of which `common/defines.lua` entries OpenHOI3 asks for against
those the original reads. Addresses are **rvas** against an image base of `0x400000` (trap 1) unless a virtual address
is said. Everything here was read instruction by instruction except where it says otherwise.

## 1. The only way in is the struct

`scripts/definesMap.py` lists what `CDefines::Load` (`0x46210`) stores: 395 names in the eight blocks, and the top
level's `start_date`, `end_date`, `land_combat`, `naval_combat`, `air_combat`, `bombing` and `base_militia`.

**Nothing reads a define by name anywhere else.** The two getters `Load` calls, `0x45F40` (thousandths) and `0x460D0`
(a whole number), have 386 and 10 call sites and every one is inside `Load`. No define's name string is referenced from
code outside `Load`, with one exception: `land_combat`'s string is referenced twice, once by the helper below and once
at VA `0xCFCB4A`, the save loader's battle key of the same spelling. So a define is reached only through the
`CDefines` struct, and a reader is a read of a field.

## 2. The top level's five strings

Each is a 0x1C-byte string inside `CDefines`, taken out of the Lua state the file ran in. The stores are
`lea ecx, [ebx + N]` in `Load`:

| field | key | store | Their Finest Hour |
| --- | --- | --- | --- |
| `+0x10` | `land_combat` | VA `0x44647A` | `land_doctrine_practical` |
| `+0x2C` | `naval_combat` | VA `0x446592` | `naval_doctrine_practical` |
| `+0x48` | `air_combat` | VA `0x4466A6` | `air_doctrine_practical` |
| `+0x64` | `bombing` | VA `0x4467BA` | `air_doctrine_practical` |
| `+0x80` | `base_militia` | VA `0x4468D2` | `militia_brigade` (`FINDINGS-surrender.md`, C.2) |

`land_combat`'s key alone is pushed through a helper, **`0x4B650`**, called at VA `0x446408`: with the Lua state's
holder in `EDI` and a three-word record in `ESI`, it stores the state at `[esi]`, `lua_gettop + 1` at `[esi+4]` and
`EDI` at `[esi+8]`, then `lua_pushstring(state, "land_combat")`, and returns `ESI`. The other four keys are pushed
inline (`push 0x15B8BE0` is `naval_combat` at VA `0x44650C`).

## 3. Battles teach practicals: `CCombatant::GainPractical` (`0x165430`)

Called at the head of each kind of battle's slot 15 (`Attack`) with the side, the address of one of the strings above,
and a `military` define:

| caller | define | string |
| --- | --- | --- |
| `CLandCombatant::Attack`, VA `0x56B375`-`0x56B395` | `LAND_DOCTRINE_INCREASE`, `+0x100` | `+0x10` |
| `CNavalCombatant::Attack`, VA `0x567968`-`0x567987` | `NAVAL_DOCTRINE_INCREASE`, `+0x104` | `+0x2C` |
| `CAirCombatant::Attack`, VA `0x56D787`-`0x56D79C` | `AIR_DOCTRINE_INCREASE`, `+0x108` | `+0x48` |
| `CBomberCombatant::Attack`, VA `0x5615E0`-`0x5615F5` | `BOMBING_DOCTRINE_INCREASE`, `+0x10C` | `+0x64` |

On land it comes after `AccumulateLeaderCombatHours` and `UpdateFrontLine` and before the side's generator draw; at
sea and in the air after the leaders' hours.

    GainPractical(side, name, amount):
        make the technology category database if it is missing   ; global VA 0x1A87B78, 0x58 bytes, 0x540D60 / 0x542630
        category = look name up in it by its hash (+0x2C, 0x9C7D60)
        if none: return                                          ; VA 0x5654A0
        for each node of side +0x54 (the tag at +0, the id at +4, the next at +0xC):
            CCountry::GainTechAbility(countries[id], category, amount)   ; VA 0x5654D7

The list at `+0x54` is the one a beaten side empties (`FINDINGS-combat.md`, the combatant's two lists), so the gain
goes to the countries still fighting. `GainTechAbility` (`0xE02F0`) is the diminishing gain a finished level uses.

*Measured* through OpenHOI3, which builds this: `Ireland1940_05_23_15.hoi3` played one hour, the land practical moves
for the same two countries as in `_16`, France by 0.003 there and 0.002 in the rebuild - a whole number of hours'
gain either way.

## 4. A brigade on a strategic redeployment: `CRegiment::SupplyConsumption` (`0x1AD0F0`)

The unit routine's multiply is in `FINDINGS-unitdaily.md`. The brigade routine has its own, as its last step
(VA `0x5AD2A1`-`0x5AD2EB`):

    if regiment->slot 9 (+0x24)()                                 ; a land regiment
       and regiment->unit (+0xB0)->order (+0xB0)->slot 16 (+0x40)() == 0x5A4    ; a strategic redeployment
        *out = *out * STRAT_REDEP_SUPPLY_MOD (military +0x1E8) / 1000, 64-bit

after the strength term. So what a brigade's card shows doubles in Their Finest Hour as its unit's charge does.
`CRegiment::FuelConsumption` (`0x1AD300`) answers nothing for the same brigade, as its record already says.

## 5. Shore bombardment's side sum, in `CLandCombatant::ApplyCombatModifiers` (`0x169B50`)

`FINDINGS-combatmods.md` section 5 gives the shape; the test of who bombards is read here (VA `0x569D37`-`0x56A002`):

    if side->units.count (+0x48) <= 0: no bombardment                       ; VA 0x569D6C
    prov = combat (+0x3C)->province (+0x18)
    for each edge of prov->template (+0xD4), 0x14 bytes each from +0x90 to +0x94:
        n = provinces[edge +4]
        if n->template->is_land (+0x22): next                                ; VA 0x569DCB
        for each unit u of n->units (+0x2B8):
            if u->movement_order_remaining_provinces_count (+0x140) > 0: next    ; VA 0x569DE5
            first = the side's first unit (side +0x40, its first node)
            if u's owner id (+0x128) == first's owner id (+0x128): next           ; VA 0x569E23
            if the pair's status (owner country +0xE28[first's id]) has a war (+0x20),
               or first's owner tag is REB, or u's owner's tag (CCountry +0xCA4) is REB:
                shore += u->definition (+0xC8)->shore_bombardment (+0x170) * SHORE_BOMBARDMENT_MOD / 1000
                                                                                  ; __alldiv, toward nought
    if shore < SHORE_BOMBARDMENT_CAP (military +0x1CC): shore = the cap          ; VA 0x569FE5
    then, per unit of the side, BM_SHORE_BOMBARD (0x0F) on attack and defence where shore != 0

**The owner asked about is the side's first unit's**, so a side of several countries is bombarded by the first's
enemies alone; the floor is taken as it stands, so a cap above nothing would be given to every land battle.

## 6. The exile's partisans: the test is on the brigade's own figures

`SetGovernmentInExile`'s return arm (`FINDINGS-surrender.md`, C.2) tests `regiment +0x58` - the regiment's own
definition, which `CSubUnit::ApplyTechnologies` rebuilds with its technologies - not the type's template:
`mov eax, [eax+0x58]; cmp [eax+0x110], ebx; jg skip` at VA `0x5031C9`-`0x5031D6`. The name is looked up in
`g_CSubUnitDataBase` (VA `0x1A886F0`) by its hash at `+0x10` (`0x9C7D60`, VA `0x503319`); no type of the name, no
conversion.

## 7. Demobilising returns manpower

**`CToggleMobilizationCommand::Execute` (`0x151490`) does more than its record said**, and only on standing down:
`cmp byte [ecx+0x44], bl; je 0x551C9A` at VA `0x5518DF` sends a mobilise order to its message and out at VA `0x5521FE`,
and an order to stand down - whether or not the country was mobilised - through its message and into this loop
(VA `0x552083`-`0x5521F8`). `CCountry_SetMobilised` (`0x107A20`) has already cleared the flag at its head.

    factor = DEMOBILIZATION_FACTOR (country block +0x64)                            ; VA 0x5520AC
    for each unit of the country's Units (+0xBAC), every level, list order:
        for each sub unit of unit +0x38:
            excess = strength (+0x5C) - GetMaxStrength(out, 0, 0)               ; slot 12, VA 0x552104
            if excess <= 0: next                                                 ; VA 0x55210C
            def = the sub unit's own definition (+0x58)
            men = excess * 1000 / def->max_strength (+0xEC)                     ; __allmul, __alldiv
            men = men * def->build_cost_manpower (+0xFC) / 1000
            men = men * factor / 1000                                            ; to VA 0x552174
            strength_ceiling (+0x30) = 0                                         ; VA 0x55217E
            m = min(GetMaxStrength(out, 0, 0), GetMaxStrength(out, 0, 0)), not below nought
            strength = m;  strength_ceiling raised to m                         ; VA 0x5521AF-0x5521B7
            the country's manpower (+0xBCC) += men, not below nought             ; VA 0x5521D6

`GetMaxStrength` (`0x1AB680`) reads nothing the zeroing touches, so the three answers are one: the definition's
`max_strength`, cut by `RESERVES_PENALTY_SIZE` for a reserve whose owner - `CSubUnit::GetOwner`, the lender for a lent
unit - is neither mobilised (`+0x94`) nor at war (`+0xACC`). So a reserve filled up while mobilised is cut back to its
peacetime share, its ceiling lowered with it, and `DEMOBILIZATION_FACTOR` of the men of the cut, priced at
`build_cost_manpower` a full brigade, come home. The file's own comment on the define says as much: "The amount of
manpower you get back from units when demobilizing".

## 8. What a static reader scan can and cannot say

To find which defines have no reader, three scans were run on 2026-11-18: from every `call GetDefines` and every load
of `g_CDefines` (VA `0x1A86040`), the pointer followed to a block load and a field read; the same, through stack slots,
indexed reads, field pointers and calls three deep; and `scripts/fieldchain.py --holder <block> --field <offset>` for
each name in question. **A zero from any of them means little**:

- 91 of the 110 names the first scan found no reader for are read - OpenHOI3 reads them off this fact base's findings.
- **The weather block is copied into globals at set-up** (`FINDINGS-weather.md`, section 5), and those reads are of the
  globals.
- **`GetDefines` is inlined as a test of the global and a branch**, so the pointer reaches the code after it only along
  the taken edge; a walk that follows the fall-through loses it at the `operator new` there.
- `fieldchain.py` found no reader of `STRAT_ALLIES_HELP`, whose read at VA `0x56B771` the first scan found.
- **A scan must not count `lea reg, [reg]`**: the first one counted MSVC's alignment filler `lea ecx, [ecx]` at
  VA `0x5520BD` as a read of `country +0x0`, `CORE_LOSE`.

Every candidate the scans and the chain gave for the twenty names below was read by hand and is something else - a
list node in the land modifier code (VA `0x56A042`), a diplomacy status entry (VA `0xA1DBD9`), a GUI argument
(VA `0x6F29C3`), and the C runtime's locale copy at VA `0xBAA3F0`, whose `+0xBC` is the thread locale's `lconv`.

So these stay as they were - eleven the record calls readerless and nine nobody had looked for - and **the running
game is to settle them**: `probes/hoidefwatch.lua`, queued in `CANDIDATES.md`, *Live probes queued*.

| readerless by earlier findings | not looked for before |
| --- | --- |
| `SURPRISE_BONUS`, `UNDERGROUND_PARTISAN_STRENGTH`, `MILACC_CANCEL_RELATION_CHANGE`, `NAP_INFLUENCE_COST`, `RELATION_INFLUENCE_COST`, `WAR_THREAT`, `SPY_MISSION_CHANGE_DAYS`, `SPY_CONNECTION_DETECTION_CHANCE`, `SPY_BASE_CONNECTION_DETECTION_CHANCE`, `REBEL_ACCEPTANCE_MONTHS`, `ROUGH_COUNTRY_RUIN_EST_MODIFIER` | `CORE_GAIN`, `CORE_LOSE`, `IC_TO_CONSUMER_GOODS`, `MAX_PROVINCE_SELL_PRICE`, `COMBAT_EVENT_DURATION`, `MINIMUM_STRENGTH`, `NAVAL_STACKING_PENALTY`, `JOINBLOCK_INFLUENCE_COST`, `PURCHASE_INFLUENCE_COST` |

`PRIDE_SUNK_DISSENT_IMPACT` and `GFX_RAINIMPACT_LIMIT` are in Their Finest Hour's file and not pushed by `Load` at all,
so nothing can read them.

## 9. Strategic warfare's allies term, in `CLandCombatant::Attack` (`0x16B340`)

`FINDINGS-government.md` C.5 gives its shape and leaves "strong allies at war" unsaid. It is a field, not a call. After
the side's units have fired (VA `0x56B3C5`), once a day:

    if (tick (game state +0xBDC) - 43800000) % 24 != 0: done                    ; VA 0x56B444-0x56B459
    p = combat (+0x3C)->province (+0x18);  C = p's controller (+0x334 / +0x338)
    if the side has units (+0x40) and is the attacker (+0x38):
        first = the side's first unit
        if IsFriend(countries[p's owner id (+0x330)], first's owner (+0x124), 1):  ; VA 0x56B4BC
            p = first's current province (+0x130);  C = p's controller          ; VA 0x56B4C9
    if p's area (+0x2B4) != the area of GetActingCapitalLocation(C): done         ; VA 0x56B4F6-0x56B507
    if !IsFriend(countries[p's owner id], C, 1): done                            ; VA 0x56B532
    if C's strong_allies_at_war count (+0xFC0) <= 0, or the side has no units: done   ; VA 0x56B551-0x56B560
    for each unit of the side, in order:
        n = (int)floorf((float)((float)regiments_count (+0x40) + 0.0005) * 1000)  ; 0x160A460, 0x160A300
        if the unit's owner id (+0x128) is C's:  v = n * STRAT_NO_ALLIES_HELP_PENALTY (+0x140) / 1000
        else if its owner id is on C's strong_allies_at_war (+0xFB8; id at +4, next at +0xC):
                                                 v = n * STRAT_ALLIES_HELP (+0x144) / 1000
        else: next
        CStrategicWarfare::AddAlliesImpact(C's StrategicWarfare (+0x1184), &v)  ; VA 0x56B7A6

`(tick - 43800000) % 24` is the hour of the day: 43,800,000 is a whole number of days. **The province the area and the
friend tests ask of is the one C was taken from**, which for a friendly attacker is where its first unit stands. A
unit's owner here is its plain owner (`+0x124`/`+0x128`), not its lender. `strong_allies_at_war` (`CCountry +0xFB8`,
its count at `+0xFC0`) is the list `CCountry::RebuildNeighbours` makes from `Allies (+0xF88)` (VA
`0x4E3616`-`0x4E370D`, `FINDINGS-factbase.md`): each ally whose `+0x95` (in exile) is clear, whose acting capital's
`CProvince +0x368` (continent) is ours, whose `max_ic (+0x60C)` is at least ours halved toward nought
(`cdq; sub eax, edx; sar eax, 1`, then `jl` skips), and whose `at_war (+0xACC)` is set - in the allies' order.

*Measured* through OpenHOI3, a look: `Ireland1939_09_01_00.hoi3` played to `_09_06_18` gives Poland, and only Poland,
entries in both, small charges at midnight - 23 summing to -0.020 in the save, 32 to -0.016 in the rebuild, whose
battles are its own AI's.

## 10. A lend-lease convoy's efficiency is not saved

`CConvoy +0xAC`, `lend_lease_efficiency`, is what `LL_CONVOY_EFF_IMPACT` and `LL_CONVOY_EFF_REGAIN` move
(`FINDINGS-convoys.md`; the field's record). **Neither the convoy's writer nor its reader touches it**: no
instruction of `CConvoy::SaveContents` (`0xC5600`) or `CConvoy::LoadKey` (`0xC5320`) addresses `+0xAC`, and
LoadKey's thirteen keys are `convoys`, `daily`, `end`, `escorts`, `id`, `last_attack`, `lend_lease`,
`lendlease_targets`, `path`, `ship`, `start`, `start_date`, `trade`. A convoy read from a save is made by
`CConvoy::CConvoy` (from `CCountry::LoadKey`, VA `0x4CDB29`), which sets the field to 1000 (VA `0x4C518D`), so **a load
gives every lend-lease convoy its whole efficiency back**.

The save does hold a key of a like name, `lendlease_effectiveness` (string VA `0x15E4258`), made into the key object at
VA `0x1B11540` with id `0x83C` by a static initialiser not recorded (VA `0xD0B943`-`0xD0B95A`), one of a run that
makes the save's key objects one after another, each `mov edx, <string>; ...; mov ecx, <id>; mov esi, <global>`. It is not the convoy's: the id
is used in `CCountry::SaveContents` (VA `0x4D2254`), so it is a country's figure; which one was not read. Beside it,
`lendlease_targets` is id `0x806` (VA `0x1B0DE68`), which both of the convoy's routines use (VA `0x4C544F`,
`0x4C58FC`).

## 11. The twenty, watched in the running game (2026-11-20)

`probes/hoidefwatch.lua` run on the base game: an access breakpoint on each field's address, at most four at a time, each
stretch of play beside a **positive control** - a define the same play is known to read - so that a zero says something.
The game was loaded at `Ireland1941_07_16_07.hoi3` with the first three fields armed from the main menu, so its load and
entering were watched too, and played at speed 4 in stretches of about 220 hours, the fields swapped between stretches;
then a new game of 1 January 1936 was started with `CORE_LOSE`, `CORE_GAIN` and `REBEL_ACCEPTANCE_MONTHS` armed from the
main menu, its set-up, its two days and 232 hours more watched. **None of the twenty was read.**

| stretch | watched (none read) | the control and where it was read |
| --- | --- | --- |
| load, entering, 24 h of July 1941 | `SURPRISE_BONUS`, `MINIMUM_STRENGTH` | `BASE_NIGHT_PENALTY` 474 times: `BombCombatWeatherModifier`, `CTargetCombatant::ApplyCombatModifiers`, `LandCombatWeatherModifier` |
| 320 h | `COMBAT_EVENT_DURATION`, `NAVAL_STACKING_PENALTY`, `UNDERGROUND_PARTISAN_STRENGTH`, `IC_TO_CONSUMER_GOODS` | none - repeated below with one, but for the partisans |
| 199 h, across 1 August | `CORE_LOSE`, `CORE_GAIN`, `REBEL_ACCEPTANCE_MONTHS` | `BASE_NIGHT_PENALTY` 6,359 times at five sites, `NavalCombatWeatherModifier` and `AirCombatWeatherModifier` among them |
| 221 h | `ROUGH_COUNTRY_RUIN_EST_MODIFIER`, `MAX_PROVINCE_SELL_PRICE`, `WAR_THREAT`, `MINIMUM_STRENGTH` | none in the stretch; the war's battles ran on |
| 220 h | `SPY_MISSION_CHANGE_DAYS`, `SPY_CONNECTION_DETECTION_CHANCE`, `SPY_BASE_CONNECTION_DETECTION_CHANCE` | `SPY_DETECTION_CHANCE` 2,709 times, all in `CSpyPresence::CatchSpies` (VA `0x52E473`) |
| 219 h, across 1 September | `NAP_INFLUENCE_COST`, `PURCHASE_INFLUENCE_COST`, `RELATION_INFLUENCE_COST` | `INFLUENCE_INFLUENCE_COST` twice: `CInfluenceNation::Apply` and `::IsSelectable` |
| 220 h | `JOINBLOCK_INFLUENCE_COST`, `MILACC_CANCEL_RELATION_CHANGE` | `GUARANTEE_INFLUENCE_COST` 5,203 times in `CGuaranteeAction::IsSelectable` (VA `0xA1DB81`); `NAP_JOIN_INFLUENCE_COST` 1,916 times in `CNapAction::IsSelectable` (VA `0xA2D831`); `MILACCESS_INFLUENCE_COST` 122 times in `CMilitaryAccessAction::IsSelectable` and `COfferMilitaryAccessAction::IsSelectable`; `JOIN_FACTION_INFLUENCE_COST` not at all |
| 219 h | `COMBAT_EVENT_DURATION`, `NAVAL_STACKING_PENALTY`, `IC_TO_CONSUMER_GOODS` again | `BASE_NIGHT_PENALTY` 5,434 times at five sites, the naval one 144 |
| a new game: set-up, two days, 232 h | `CORE_LOSE`, `CORE_GAIN`, `REBEL_ACCEPTANCE_MONTHS` | - |

What each zero is worth:

- **Settled, the play that would read them having run**: `SURPRISE_BONUS`, `MINIMUM_STRENGTH` and `COMBAT_EVENT_DURATION`
  (land battles every hour); `NAVAL_STACKING_PENALTY` (sea battles fought); `IC_TO_CONSUMER_GOODS` (every country's shares
  of IC run daily); the three spy defines (spies caught thousands of times); `NAP_INFLUENCE_COST` - **the AI asked whether
  each pact could be offered 1,916 times in one stretch, and that test reads `NAP_JOIN_INFLUENCE_COST`**, as does the
  pact's charge (`CNapAction::Apply`, already recorded). `MILACC_CANCEL_RELATION_CHANGE` is settled by the listing rather
  than by play: the cancel arm of `CMilitaryAccessAction::Apply` takes `MILACC_DECLINE_RELATION_CHANGE`.
- **Watched where their play did not happen, so still open**: `CORE_LOSE` and `CORE_GAIN` (no change of owner in either
  stretch), `REBEL_ACCEPTANCE_MONTHS` (no rising holding land seen), `WAR_THREAT` (no declaration), `JOINBLOCK_INFLUENCE_COST`
  (no faction join weighed - its sibling `JOIN_FACTION_INFLUENCE_COST` was not read either), `PURCHASE_INFLUENCE_COST` and
  `RELATION_INFLUENCE_COST` (a licence is charged `LICENCE_INFLUENCE_COST`; what "purchase" and "relation" would be asked by
  was not found), `MAX_PROVINCE_SELL_PRICE`, `ROUGH_COUNTRY_RUIN_EST_MODIFIER`, and `UNDERGROUND_PARTISAN_STRENGTH` (no
  control of its own, and partisans not seen rising). A scripted play - a capitulation, a declaration, a rising - would settle
  them; the bridge's allowed writes (pause, speed, save, the menus) cannot make one.
- **`PURCHASE_INFLUENCE_COST`, `RELATION_INFLUENCE_COST` and `MAX_PROVINCE_SELL_PRICE` are likely leftovers of the
  engine's Europa Universalis III parts** - the maintainer's account, 2026-11-20 - and so read by nothing: buying, improving
  relations with influence and selling a province are EU3's diplomacy, Hearts of Iron 3 has no action for any of them (its
  licence is charged `LICENCE_INFLUENCE_COST`), and the AI's own class is still `CEU3AI`. *Inferred*: the watch saw no
  read, and no action that could read them is known; that the defines came over from EU3 with `CDefines::Load` is the
  account, not a reading.
- The diplomacy and alignment blocks have no struct in the record, so `NAP_INFLUENCE_COST`, `PURCHASE_INFLUENCE_COST`,
  `RELATION_INFLUENCE_COST`, `JOINBLOCK_INFLUENCE_COST`, `MILACC_CANCEL_RELATION_CHANGE` and `WAR_THREAT` are written here
  alone; the other fourteen's field comments carry the result.

## Corrections to the record

- `CToggleMobilizationCommand::Execute`: "The rest is a COUNTRY message for the player" was wrong - section 7.
- `CCombatant::GainPractical`: `inferred` to `confirmed`, with the lookup by name, the list it walks and all four
  callers.
- `CRegiment::SupplyConsumption`: the strategic redeployment's multiply added.
