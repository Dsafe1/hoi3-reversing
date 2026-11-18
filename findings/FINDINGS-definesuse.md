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

## 7. Demobilising returns manpower - the part not read

**`CToggleMobilizationCommand::Execute` (`0x151490`) does more than its record said.** After the threat it reads
`DEMOBILIZATION_FACTOR` (country `+0x64`, VA `0x5520AC`) and walks the country's units (`+0xBAC`) and each unit's
regiments. For each regiment it takes its `+0x5C` less what its vftable slot 12 (`+0x30`) answers; where that is
above nought, scales it by the define and by two more thousandths factors (VA `0x552131`-`0x552169`), sets the
regiment's field `+0x30` to nought, asks slot 12 again, holds that answer between nought and the first, stores it at
`+0x5C` and raises `+0x30` to it (VA `0x55217E`-`0x5521B7`); and adds the scaled figure to the country's manpower
(`+0xBCC`, VA `0x5521D6`), floored at nought. *Inferred* from the loop's shape alone: which figures, which cap and whether it runs only on demobilising
are not read. The file's own comment on the define says "The amount of manpower you get back from units when
demobilizing".

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

## Corrections to the record

- `CToggleMobilizationCommand::Execute`: "The rest is a COUNTRY message for the player" was wrong - section 7.
- `CCombatant::GainPractical`: `inferred` to `confirmed`, with the lookup by name, the list it walks and all four
  callers.
- `CRegiment::SupplyConsumption`: the strategic redeployment's multiply added.
