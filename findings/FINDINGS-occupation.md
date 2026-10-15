# Occupation, revolt risk, partisans and rebels

Read out of `hoi3_tfh.exe` on 2026-09-30, statically. Addresses are **virtual** (base
`0x400000`) with the rva beside them, because `project.json` wants rvas and the
disassembler prints virtual addresses. Nothing here was measured in a running game.

**In one line.** Occupation is not a special case in the engine: a `COccupationPolicy`
*is* a `CModifier`, and the whole of it is added into the occupied province's modifier
values by the province modifier rebuild. Revolt risk is one accumulator per province
(`CProvince +0x328`) that the daily pass moves by a **hardcoded plus or minus 0.1 a day**
while the controller is at war with the owner, and what the game reads is that accumulator
plus `LOCAL_REVOLT_RISK` plus the controller's `GLOBAL_REVOLT_RISK` minus the province's
garrison suppression, floored at `MINIMUM_REVOLT_RISK`. Partisans and rebels are brigades
created for a `CRebelFaction`; the two creation paths read here are the government-in-exile
underground mobilisation and the province revolt.

---

## 1. Revolt risk

### 1.1 The accumulator and what changes it

`CProvince +0x328` (`revolt_risk`, thousandths, already in the record) is moved in exactly
one place: **the daily province pass at `0x49EAB0` (rva `0x9EAB0`)**.

That function is `f(CMapProvince*)`, `ret 4`, and it is called once per province from a
plain serial loop at `0x682E4B`:

    0x00682E41  mov ecx, [ebx + 0xb8c]        ; the province vector
    0x00682E47  mov edx, [ecx + esi*4]
    0x00682E4A  push edx
    0x00682E4B  call 0x49eab0

`0x682E4B` lies inside **`RunDailyPass`** (`0x682C20`..`0x683077`), not `RunHourlyPass` -
the two abut, which is the trap `FINDINGS-tick.md` already names, and `image.functionStart`
answers `RunHourlyPass` for this address. `FINDINGS-tick.md` already lists `0x49EAB0` in
`RunDailyPass`'s callee list without saying what it is. **The loop is serial on the calling
thread; no TBB task is involved**, so this is hookable from BiceLib on the game thread.

The revolt-risk block runs at `0x49EE0F`..`0x49EED6`:

    controller = CountryOf(province->controller_tag)            ; +0x334, via 0x402610
    if (province->owner_id == controller->id)  goto floorAtZero ; +0x330 vs +0xCA8
    ; --- inlined CCountry::IsEnemy, byte for byte the same as 0x42F1B0 ---
    status = controller->statuses[province->owner_id]           ; +0xE28
    if (status->+0x20 == 0
        && province->owner_tag != 'REB'                        ; +0x32C
        && controller->tag     != 'REB')      goto floorAtZero  ; +0xCA4
    ; --------------------------------------------------------------------
    ceiling = provinceValues[MODIFIER_LOCAL_PARTISAN_SUPPORT]   ; [[p+0x114]+0x260]
    step    = 0.100                                            ; g at 0x1A86CF4
    if (province->revolt_risk > ceiling) step = -0.100
    suppress = min( province->suppression * 0.100, 0.200 )      ; +0x28, g at 0x1A86CD0
    province->revolt_risk += step - suppress
    if (province->revolt_risk > ceiling) province->revolt_risk = ceiling
  floorAtZero:
    if (province->revolt_risk < 0) province->revolt_risk = 0

Written the way a modder thinks, with `local_partisan_support` and revolt risk both in
percentage points (that is the unit `common/occupation_policies.txt` uses - 9, 16, 25):

| condition | change per day |
| --- | --- |
| owner controls the province, or controller is not at war with owner | **none** |
| garrison suppression 0 | **+0.1** |
| garrison suppression 1.0 | **0.0** |
| garrison suppression 2.0 or more | **-0.1** |
| already above `local_partisan_support` | `-0.1 - min(suppression*0.1, 0.2)`, then clamped down to `local_partisan_support` |

and it is clamped to `[0, local_partisan_support]` afterwards - the floor at 0 runs on every
province every day, the ceiling only on the branch that changed it.

**Three things a modder will want from that.**

- `local_partisan_support` is the **cap on a province's accumulated revolt risk**, not a
  separate partisan statistic. `MODIFIER_LOCAL_PARTISAN_SUPPORT` is modifier id `0x4C`
  (76), so `+0x260` in the values array, and `0x49EE77` is the read.
- **The step and the suppression cap are compiled into the exe.** They are the two
  fixed-point globals `0x1A86CF4` and `0x1A86CD0`, built at startup by the initialisers at
  `0xCB0FA0` and `0xCB1030` from the floats 100.5 and 200.5 at `0x160A684` and
  `0x160A64C` (`0x401FD0` is `floor`, `0xC08870` the float-to-int, so they land as 100 and
  200 thousandths). **No `defines.lua` entry touches them.** Both globals are also read by
  unrelated code (`0x4A3B12`, `0x4A3B1A` in the building-level change at `0x4A39B0`), so
  they are generic 0.1 and 0.2 constants and must not be named after revolt.
- The gate is **`controller->IsEnemy(owner)`**, inlined. Identical code is
  `CCountry::IsEnemy` at `0x42F1B0` (rva `0x2F1B0`), already in the record. So revolt risk
  does **not** accumulate in a province you occupy from somebody you have peace with - and
  it *does* accumulate whenever either side is `REB`, because `IsEnemy` answers true for
  `REB` unconditionally.

`CDiplomacyStatus +0x20` is the war between the pair - non-null means at war. That is read
off `IsEnemy`'s shape rather than from the writer, so it is **inferred**; the record has no
name at that offset.

### 1.2 What the game actually reads: the effective revolt risk

`0x4A4050` (rva `0xA4050`) is the getter. It has a **register convention** - its address is
taken nowhere - province in `edi`, the out `int*` in `esi`, one dword pushed and left for the
caller, plain `ret`:

    *out = 0
    if (CountryOf(province->controller_tag)->IsEnemy(&province->owner_tag))
        *out = province->revolt_risk                            ; +0x328
    if (province->controller_id != 0) {
        c = CountryOf( controller_tag == 'REB' ? province->owner_tag
                                               : province->controller_tag )
        *out += c->countryValues[MODIFIER_GLOBAL_REVOLT_RISK]    ; [[c+0xDA8]+0x10]
    }
    *out += provinceValues[MODIFIER_LOCAL_REVOLT_RISK]           ; [[p+0x114]+0x8]
    *out -= province->suppression                                ; +0x28
    return out

So all three of the first three modifiers are accounted for:

    revolt_risk_shown =
        max( MINIMUM_REVOLT_RISK(province),
               (controller at war with owner ? province.revolt_risk : 0)
             + GLOBAL_REVOLT_RISK(the country whose revolt this is)
             + LOCAL_REVOLT_RISK(province)
             - suppression(province) )

The `max` with `MINIMUM_REVOLT_RISK` is **not** inside `0x4A4050`. It is applied by the
caller, and that is exactly what separates the two script triggers:

| trigger | vftable | slot 6 | what it compares |
| --- | --- | --- | --- |
| `CRevoltRiskTrigger` | `0x15F87E0` | `0x9E7590` (rva `0x5E7590`) | `max(provinceValues[MINIMUM_REVOLT_RISK] clamped at >= 0, 0x4A4050)` > `value * 1000` |
| `CPureRevoltRiskTrigger` | `0x15F8814` | `0x9E6940` (rva `0x5E6940`) | `0x4A4050` > `value * 1000`, no floor |

`0x9E7649`..`0x9E7660` is the floor:

    0x009E7644  call  0x4a4050
    0x009E7649  mov   ecx, [edi + 0x114]       ; the province's values
    0x009E764F  mov   eax, [ecx]               ; values[MINIMUM_REVOLT_RISK]
    0x009E7652  test  eax, eax
    0x009E7654  jns   0x9e7658
    0x009E7656  xor   eax, eax                 ; a negative minimum counts as 0
    0x009E765B  cmp   ecx, eax
    0x009E765D  cmovl ecx, eax                 ; max(revoltRisk, minimum)

**So `revolt_risk` in a trigger is the effective figure and `pure_revolt_risk` the same
figure without the minimum floor.** The two differ only when `minimum_revolt_risk` exceeds
everything else, and `pure_` is the one that can read the negative values a big garrison
produces.

`0x4A40E0` (rva `0xA40E0`) is a three-instruction accessor that writes the raw `+0x328`
into an out pointer; it has one call site (`0x5FE390`) and is in no vftable.

### 1.3 Suppression: `CProvince +0x28`

`+0x28` is recomputed once a day, in the same pass, immediately before the revolt-risk
block:

    0x0049EDF7  mov  edi, ebx                  ; the province
    0x0049EDF9  call 0x49f360
    0x0049EE02  mov  eax, [eax]
    0x0049EE04  mov  [ebx + 0x28], eax

`0x49F360` (rva `0x9F360`), province in `edi`, out `int*` on the stack, `ret 4`:

    *out = SuppressionIn(province)                              ; 0x49F250
    for each p in province->+0x14C .. +0x150                    ; the adjacency vector
        if (p->path_node->is_land                               ; [p+0xD4]+0x22
            && p->controller_id == province->controller_id)      ; +0x338
            *out += SuppressionIn(p)

`0x49F250` (rva `0x9F250`), province in `eax`, out `int*` on the stack, `ret 4`:

    *out = 0
    for each unit in province->units                            ; +0x2B8
        if (!CountryOf(unit->owner_tag)->SameSide(&province->controller_tag, true))
            continue                                            ; 0x4EF7C0
        strength = sum over unit->regiments of regiment->+0x5C   ; +0x38, CRegiment +0x5C
        ratio    = strength * 1000 / unit->GetMaxStrength()      ; vtable slot 23
        *out    += ratio * unit->definition->suppression / 1000  ; [unit+0xC8]+0x130
    *out = *out / 10                                            ; x1000 then /10000

`CSubUnitDefinition +0x130` is `suppression`, already in the record, and that is what pins
this function. Two things worth a modder's attention:

- **suppression is taken once from `CUnit +0xC8`** - but that is **not** the same as "not
  summed over its brigades", which is what this said until 2026-10-01 and which was wrong.
  `+0xC8` is a `CSubUnitDefinition` the division **owns**, rebuilt by
  `CUnit::RebuildDefinition` (rva `0x1B5ED0`) by summing each brigade's own definition
  (`CSubUnit +0x58`) into it across 60 fields through `0x1A7FC0`, and `suppression` (`+0x130`)
  is one of the plain sums. So a division's suppression **is** the total of its brigades',
  scaled by how intact the division is. One read of an aggregate is not evidence of no
  aggregation. See `FINDINGS-unitdef.md`.
- **a unit suppresses its own province and every adjacent land province under the same
  controller**, so one garrison covers a cluster; and the `/10` at the end means the number
  that lands in `+0x28` is suppression times 100 in thousandths, so a brigade with
  `suppression = 2.0` at full strength contributes 0.2 to the figure that both the daily
  step and the effective revolt risk use.
- **So the real figures are per *division*, not per brigade.** With brigade suppression summing
  into the division's definition, a full-strength division contributes
  `(sum of its brigades' suppression) / 10`. At BlackICE's values that is 1.8 for three
  `garrison_brigade` (6 each), 2.55 for three militia (8.5), 0.3 for three infantry (1). The
  daily step freezes at a province total of 1.0 and saturates at 2.0, so **one properly built
  garrison or militia division saturates its province and every same-controller land
  neighbour** - which is a different conclusion from the per-brigade reading this file
  originally carried.

The friendly test at `0x4EF7C0` returns true at once when the tags match and otherwise goes
to the faction/alliance database, so an allied garrison counts. It is not named here - it is
a general diplomacy helper, not a revolt one.

### 1.4 Where the occupation policy enters the province's modifier values

`0x49F3E0` (rva `0x9F3E0`, `ret 4`, ends `0x4A0673`) is the **province modifier rebuild** -
it writes `CProvince +0xFC`'s values array, which is what `+0x114` points into. The daily
pass calls it at `0x49EE0A` behind a local flag, and the full-revolt path calls it at
`0x65BF7A` just before spawning.

Inside it, at `0x49FBE2`:

    if (province->owner_id == province->controller_id) skip
    if (province->controller_tag == 'REB')             skip
    controller = countryDb->byId[province->controller_id]    ; [0x1A855A4]+0x16C
    policy     = controller->statuses[province->owner_id]->+0x10
    if (!policy) skip
    for id in 0 .. modifierDefinitionCount                  ; ([0x1A86198]-[0x1A86194])/4
        provinceValues[id] += policy->values[id]            ; policy is a CModifier, +0x18

`CDiplomacyStatus +0x10` is `occupation_policy` - that is read off the loader
(`CDiplomacyStatus::LoadKey`, `0xA48190`, key `occupation_policy`, token `0x57C`), not
guessed. And RTTI says **`COccupationPolicy : CModifier`**.

**That is the whole occupation penalty.** There is no separate hardcoded reduction to IC,
resources, manpower or leadership for an occupied province: `local_ic`, `local_resources`,
`local_manpower_modifier`, `local_leadership_modifier`, `local_partisan_support` and
`local_revolt_risk` out of `common/occupation_policies.txt` are added into the province's
modifier values here and then consumed by the ordinary IC, resource, manpower and revolt
paths. Which is also why `local_partisan_support` and `local_revolt_risk` in that file
reach revolt risk by two different routes - one as the cap on the accumulator, one as a
flat addend on the effective figure.

Note the `REB` exclusion: **a province that `REB` controls gets no occupation policy
modifier at all**, whatever policy the pair has.

---

## 2. Partisans from an underground

`0x50B630` (rva `0x10B630`), `ret 8`, taking `(CCountry* exile, CMapProvince* source)` on
the stack. It is the only function in the image that logs
`"Failed to spawn partisant from underground at location "` (`country.cpp`, at `0x50BA2B`).

    ; pick where the partisans appear
    edges  = source->path_node->+0x90 .. +0x94        ; stride 0x14, ProvinceEdge
    target = source                                   ; the default
    pick a random edge (0xAA2F80 % edgeCount)
    if (that neighbour is in a real area && neighbour->owner_id == source->owner_id)
        target = that neighbour
    else
        walk the edges in order and take the first that passes the same two tests
    if (target is in no real area) -> log the failure and return

    ; create them
    faction = 0x4C0430( the global at 0x1A871D8, target, 1, &exile->tag )
    0x4C1160( this = target, faction,
              UNDERGROUND_SPAWN_STRENGTH / 1000, true, &exile->tag )

    ; pay for them
    u = source->underground_building                   ; +0x30C
    u->level_current -= SPAWN_PARTISAN_LIMIT           ; +0x24, floored at 0
    u->+0x28 = (level changed)                         ; the dirty byte

So, in modder terms:

- **the partisans do not appear in the province with the underground**; they appear in a
  neighbour that the same country *owns*, picked at random among the qualifying neighbours,
  and only fall back to the underground's own province when no neighbour qualifies;
- **the brigade count is `UNDERGROUND_SPAWN_STRENGTH`** (military block, `CDefines+0xAC`
  `+0x264`), truncated to a whole number, and `0x4C1160` clamps it to at least 1;
- **the cost is `SPAWN_PARTISAN_LIMIT` levels off the source province's `underground`
  building**, floored at 0. The same define is the *threshold* elsewhere (below), so it is
  doing double duty as "the level one mobilisation needs" and "the level one mobilisation
  burns".

`SPAWN_PARTISAN_LIMIT` is at `CDefines+0xAC` `+0x248` and the image reads it in five places,
four of them in this cluster (`0x50B0BD`, `0x50B20F`, `0x50B485`, `0x50B4D3`) plus
`0x88A4F1`; `definesMap.py` run backwards is how they were found.

### The availability checks around it

`0x50AFD0` (rva `0x10AFD0`), thiscall on a `CCountry`, `ret 4`, builds the
tooltip/availability text for mobilising undergrounds:

    if (!this->+0x95) -> 'WE_NOT_GOVERNMENT_IN_EXILE'
    total = 0 ; ready = 0
    for each province the country OWNS (province->owner_id == this->id, over +0xD60)
        total++
        if (province->underground_building->level_current > SPAWN_PARTISAN_LIMIT) ready++
    if (ready == 0) -> 'UNDERGROUNDS_NOT_PREPARED' with TOTAL = total
    else            -> the ready/total text

**`CCountry +0x95` is the government-in-exile flag.** The record currently names it
`use_own_pool` with the comment "when set, GetPool answers the country's pool at `+0x9F8`
instead of the capital's". Both readings can be true of the same byte - an exile has no
capital to draw a pool from - but the name is describing a consequence rather than the
field. This finding does not redefine it; see *Contradictions*.

Two sibling functions do the same job for the two player-facing actions, with the same shape
and the same `LIMIT` / `CURRENT` / `UNDERGROUND_NOT_STRONG_ENOUGH` keys: `0x50B4A0`
(`MOBILIZE_PARTISANS`, reads `SPAWN_PARTISAN_LIMIT` at `0x50B485` and `0x50B4D3`) and
`0x50BB60` (`MOBILIZE_UNDERGROUND`, reads `SPAWN_UNDERGROUND_LIMIT` at `0x50BB49` and
`0x50BB93`). `0x50B1E0` is a second, whole-country variant of `0x50AFD0`.

### The rest of the underground cluster

`definesMap.py` backwards puts the whole underground model in one block of the image, and
none of it was named before:

| define | `CDefines+0xAC` | read at | in |
| --- | --- | --- | --- |
| `MAX_UNDERGROUND_DISTANCE` | `+0x250` | `0x509067`, `0x5092A6` | `0x509050`, `0x509230` |
| `UNDERGOUND_INITIAL_STRENGTH` (sic) | `+0x254` | `0x50925A`, `0x5092B7` | the same two |
| `UNDERGROUND_STRENGTH_GAIN` | `+0x258` | `0x50A1B7` | `0x50A110` |
| `UNDERGROUND_DETECT_CHANCE` | `+0x25C` | `0x50A1CB` | `0x50A110` |
| `SPAWN_PARTISAN_LIMIT` | `+0x248` | `0x50B0BD`, `0x50B20F`, `0x50B485`, `0x50B4D3` | the tooltips |
| `UNDERGROUND_SPAWN_STRENGTH` | `+0x264` | `0x50B69C` | `0x50B630`, the spawn |
| `SPAWN_UNDERGROUND_LIMIT` | `+0x24C` | `0x50BB49`, `0x50BB93` | `0x50BB60` |
| `UNDERGROUND_PARTISAN_STRENGTH` | `+0x260` | - | **no reader found** |

`0x50A110` (rva `0x10A110`, 0xD30 bytes) is the underground's own periodic work - it reads
both `UNDERGROUND_STRENGTH_GAIN` and `UNDERGROUND_DETECT_CHANCE`, reads
`provinceValues[MODIFIER_LOCAL_PARTISAN_SUPPORT]` at `0x50A278`, and builds the
`OURUNDERGROUNDREMOVED` and `UNDERGROUNDREMOVED` messages with `COUNTRY` and `PROV`
parameters. It is **not read here**; it is the largest single lead left in this domain.

`UNDERGROUND_PARTISAN_STRENGTH` is pushed by `CDefines::Load`, so it is stored, but the
backwards scan finds nothing reading `CDefines+0xAC` `+0x260` anywhere in the image. That is
the `WHITESEA` case in `definesMap.py`'s docstring one step further on: the engine reads the
key and then never uses it. Treat it as **likely dead**, with the caveat that the scan only
follows a block pointer taken from `GetDefines`'s return within one function.

---

## 3. `CRebelFaction` and `CRebelType`

### 3.1 Layout, from the loaders

`fieldmap.py` reads both loaders cleanly, and the runtime code agrees with every offset it
gives. **`CRebelType`** (`common/rebel_types.txt`, `CRebelType::LoadKey`):

| key | offset | note |
| --- | --- | --- |
| `spawn_chance` | `+0x28` | a factor/modifier block, read into |
| `movement_evaluation` | `+0x44` | the same shape |
| `siege_won_trigger` | `+0x60` | |
| `can_enforce_trigger` | `+0xE0` | |
| `siege_won_effect` | `+0x120` | |
| `demands_enforced_effect` | `+0x160` | |
| `area` | `+0x180` dword | |
| `ideology` | `+0x184` dword | |
| `unit` | `+0x188` dword | the `CSubUnitDefinition*` the brigades are built from |
| `defection` | `+0x18C` dword | |
| `independence` | `+0x190` dword | |
| `defect_delay` | `+0x194` dword | |
| `resilient` | `+0x198` byte | |
| `reinforcing` | `+0x199` byte | |
| `smart` | `+0x19A` byte | |
| `auto_convert` | `+0x19B` byte | |

`is_triggered_only` is in the switch but lands nowhere the walker can see.

Two independent runtime confirmations: `0x686D1D` tests `type->+0x190` (`independence`)
before it will match a faction to a province, and the record's own note on
`CUnit::RetreatFromCombat` says the `REB` path needs "a flag at `+0x30`'s `+0x198`" -
`+0x30` is the faction's type and `+0x198` is `resilient`.

**`CRebelFaction`** (`CReferenceObject` base, vftable `0x15C0B6C`, 8 slots):

| key | offset | note |
| --- | --- | --- |
| `id` | `+0x8` | from the shared one-key `id` base; `+0x8` type, `+0xC` value |
| `type` | `+0x30` | the `CRebelType*` |
| `province` | `+0x34` | |
| `country` | `+0x38` | whose rebels these are; `CCountryTag` is 8 bytes, so the tag is at `+0x38` and its id at `+0x3C` |
| `government` | `+0x40` | |
| `independence` | `+0x44` | the country it wants released, its id at `+0x48`; **the daily faction pass deletes the faction the moment that country exists** |
| `target` | `+0x74`, `+0x78` | **the record already has `+0x70`/`+0x74`/`+0x78` as the targets list**, first/last/count; what `fieldmap.py` sees as two dwords is the push_back updating the tail and the count, not an id pair |
| `army` | `+0x84`, `+0x88` | the same shape: the record has `+0x80`/`+0x84`/`+0x88` as the armies list, and `fieldmap.py` is seeing the tail and count |
| `provinces` | `+0x94` | the record calls this a **vector** of ids ending at `+0x98`; the daily pass walks it as a **linked list**, payload at `+0x0` and next at `+0x8` - see *Contradictions* |
| - | `+0x90` | the **"delete me" byte**, set by the daily pass |

### 3.2 The daily pass

`RunDailyPass` walks the rebel factions itself, right after the province loop:

    0x00682E64  mov edi, [ebx + 0xc7c]        ; rebel_factions, already in the record
    0x00682E72  mov esi, [edi]
    0x00682E78  call 0x4b9d60                 ; the faction's daily work
    0x00682E7D  cmp byte [esi + 0x90], 0      ; did it ask to die?
    ...         unlink from +0xC7C/+0xC80, free it, dec +0xC84

so **a rebel faction is updated once a day and can remove itself the same day**, unless
`CCurrentGameState +0xC88` is set, in which case it is only marked (`+0xC` on the node) and
left in the list - that looks like an iteration guard.

`0x4B9D60` (rva `0xB9D60`, `f(CRebelFaction*)`, `ret 4`) opens with the two death tests:

    0x4BD4E0(faction)                                        ; not read here
    if (CountryOf(faction->country_tag)->+0xCF8 <= 0
        && faction->type->area == 0)        -> faction->+0x90 = 1 ; return
    if (faction->independence.id != 0            ; +0x48
        && CountryOf(faction->independence_tag)->+0xCF8 > 0)
                                           -> faction->+0x90 = 1 ; return

then walks `faction->provinces` (`+0x94`), and for each province id whose province is
**controlled by `REB` and has a non-null owner** calls `0x4B98D0(faction, ownerTag,
ownerId)` and, on true, appends a 0x10-byte node to a list it builds on the stack. That list
is the faction's business with each owner it is in revolt against; what `0x4B98D0` decides
and what the list is then used for are **not established**.

`CCountry +0xCF8` is not in the record. It sits just before `+0xD00`, the province-id list
head, and every one of its readers tests it against 0 as a liveness check (`0x4DAF22`,
`0x4DB41D`, `0x4DB7C9`, `0x4DB92B`, `0x4DBEC7`, all inside the daily politics region).
**Most likely the country's province count** - inference, not established, and deliberately
not recorded as a field here. Read with that reading, the two tests say: a faction dies when
the country it fights for holds nothing and its type is not area-bound, and **an
independence faction dies the moment the country it wanted to release exists** - its goal is
met.

### 3.3 Finding the faction for a province, and creating the brigades

`0x686CF0` (rva `0x286CF0`, game state in `eax`, `ret 8`): walk `+0xC7C`, keep the faction
whose `+0x30` is the wanted `CRebelType*`; when that type's `independence` (`+0x190`) is
non-zero, also require the area computed from the faction's `+0x44`/`+0x48` by `0x4BF6F0` to
match the province. So **one faction per (rebel type, area)**, and a nation-wide type shares
one faction.

`0x686C10` (rva `0x286C10`, game state in `eax`, `ret 4`) is the other lookup: it walks
`+0xC7C` and, inside each faction, the **armies** list at `+0x80` (nodes of 20 bytes, next
at `+0xC`), matching the node's object id at `+0x0`/`+0x4` against the argument's `+0x10`
and `+0x14`. This is the function the record
already mentions in `CUnit::RetreatFromCombat`'s comment as `0x286C10`.

`0x4C1160` (rva `0xC1160`, thiscall on the province, `ret 0x10`) is **the shared "put rebel
brigades in this province" call** - five call sites, including the underground spawn and the
province revolt. Its arguments are `(faction, count, bool, CCountryTag*)`:

    if (!province->area->slot0())          return    ; +0x2B4, not a real area
    if (!province->path_node->+0x13D)      return    ; a CProvinceTemplate flag
    if (count < 1) count = 1
    faction = 0x686CF0(province, arg1)               ; the faction for this province
    0x4A40F0(...)                                    ; not read here
    if (faction == 0) -> 0x686D80(...) with the string at 0x15B4945 and return
    if (province->controller_tag != 'REB')
        0x4B9150(province->controller_tag, province->controller_id)
    0x4BAA20(faction, &tmp, province, count, bool, tag)

`0x4BAA20` (rva `0xBAA20`, `ret 0x14`) is the creation proper. It is the only function that
reads `MODIFIER_PARTISAN_EFFICENCY` off a country's values (`[[c+0xDA8]+0x278]` at
`0x4BAD3F`; the other reader is `0x628060`, UI). It raises the player-facing message from
`REBELS` / `REBELDESC` / `PROV` / `REVOLT` with `MESSAGE_HEAD_MARS`, **clamps its count
argument to 1..4** (`0x4BAACD`..`0x4BAADD`), and records the pre-revolt owner and controller
pair when the province is occupied and the actor is not an exile. Its body past that point is
**not read here**; it is 0xDE0 bytes and the largest remaining lead after `0x50A110`.

`0x4A6C30` (rva `0xA6C30`), thiscall on a province, is the **full province revolt**, called
only from `0x65BF81` (the in-game screen path, so a command or a console action; the caller
also calls the modifier rebuild `0x49F3E0` immediately before, and checks the province's
controller for `REB` immediately after):

    if (province->revolt_risk == 0)
        province->revolt_risk = provinceValues[MODIFIER_LOCAL_PARTISAN_SUPPORT]
    if (province->+0x60 == 0) return                  ; no rebel type chosen
    brigades = province->+0x64 * max(1, province->manpower / 1000)   ; +0x320
    faction  = 0x686CF0(province, province->+0x60)
    if (faction) 0x4BAA20(faction, ..., province, brigades, 0, "---")
    else         0x686D80(...)                        ; make the faction first

**`CProvince +0x60` is a `CRebelType*` and `+0x64` the brigades-per-manpower-point
multiplier** - that is `likely`, from this one reader plus the argument `0x686CF0` expects;
neither is written by the save writer, and the only writers found (`0x496AB1`, `0x40DE92`)
zero them, so whatever chooses a province's rebel type at runtime is **not
established**.

---

## 4. What else is special-cased for `REB`

`FINDINGS-politics.md` records the daily politics pass forcing dissent to 0 for `REB`.
Every other `REB` special case found in this domain, each a literal R/E/B byte comparison:

| where | on | effect |
| --- | --- | --- |
| `0x42F1BF` `CCountry::IsEnemy` | either tag | **everybody is at war with `REB` and `REB` with everybody**, with no `CDiplomacyStatus` entry |
| `0x49EE3B` daily province pass | province owner, else controller | revolt risk accumulates even without a war entry |
| `0x49FBF7` modifier rebuild | province controller | **a `REB`-held province gets no occupation policy modifier** |
| `0x4A4089` effective revolt risk | province controller | `GLOBAL_REVOLT_RISK` is taken from the province's **owner** instead of its controller |
| `0x4B9E92` daily rebel faction pass | province controller | only `REB`-controlled provinces count as the faction's |
| `0x4C045D` inside `0x4C0430` | province controller | a distinct path when the province is already `REB`-held |
| `0x4C130A` inside `0x4C1160` | province controller | `0x4B9150(controller)` runs **only** when the controller is not `REB` |
| `0x4B8F40` | - | the only other function in the rebel block that holds the literal `REB`; almost certainly the `REB` country lookup, **not read here** |

**Does the mod's `REB` match what the engine expects?** The engine needs `REB` to be a real,
loadable country: it constructs a `CCountry` for it, indexes `+0xE28` with it, gives it a tag
at `+0xCA4`, walks its provinces, and forces its dissent to zero every day. The mod's own
setup was not audited as part of this work - that is left as a check, and the cheapest form
of it is that a missing `REB` flag `.tga` kills startup outright, so a `REB` that loads at
all has at least a tag and a flag.

---

## What is not established

- **What turns revolt risk into an actual revolt.** The accumulator, the effective figure,
  the two triggers and both creation paths are read. The **daily roll** that consumes the
  effective revolt risk and calls into `0x4BAA20` was not found. `0x4A4050`'s callers are the
  two triggers plus six sites in the `0x60xxxx`, `0x6Exxxx`, `0x86xxxx`, `0x8Bxxxx` and
  `0x8Exxxx` ranges that look like UI, and none of them is in the daily pass. It may be in
  `0x50A110`, in `0x4BAA20`'s unread body, in the event machinery (`rebel_types.txt`'s
  `spawn_chance` is a factor block, which is the `CMeanTimeToHappen` shape), or a `REB` AI
  behaviour. **`spawn_chance` being evaluated by the engine at all was not confirmed.**
- **How often the underground grows and is detected** - `0x50A110` is unread, so
  `UNDERGROUND_STRENGTH_GAIN` and `UNDERGROUND_DETECT_CHANCE` have a reader but no rate.
- **`0x4BAA20`'s body** past its argument clamping: the unit creation, where
  `MODIFIER_PARTISAN_EFFICENCY` is applied, and what the 1..4 clamp is clamping.
- **What `0x4B98D0` decides** in the daily faction pass, and what the 0x10-byte node list it
  feeds is for.
- **`CCountry +0xCF8`.** Read as a liveness test in many places; "province count" is
  inference and it is deliberately not recorded as a field.
- **`CProvince +0x60` and `+0x64`.** Recorded as `likely`; nothing found that sets them to a
  real value.
- **`CProvinceTemplate +0x13D`**, which gates rebel creation in `0x4C1160`, is still the
  unknown flag the record already says it is.
- **The units of `CProvince +0x28`.** The arithmetic is exact (suppression x 1000 / 10 per
  unit at full strength) but nothing here was measured in a running game, so the claim that a
  `suppression = 2.0` brigade lands as 200 rests on reading `CSubUnitDefinition +0x130` as
  thousandths like every other loader field.
- **`CDiplomacyStatus +0x20`** is inferred to be the war from `IsEnemy`'s shape; its writer
  was not found.
- **The occupation policy's `allow` block** - `COccupationPolicy::LoadKey` (`0x52CEE0`) keeps
  it off the object where `fieldmap.py` can see it, and nothing here reads who evaluates it.
- **`CExecuteRebelAcceptanceCommand` and `REBEL_ACCEPTANCE_MONTHS`.** The command's loader
  takes one key (`scope`), `CCountry` has `last_rebel_acceptance` and the define is at
  `CDefines+0xCC` `+0x10`, but the backwards scan finds **no reader of that define**, and the
  acceptance runtime was not reached. "Acceptance" is still unexplained.
- **`CSpawnPartisanCommand` and `CSpawnFullRevoltCommand` `Execute`.** Only their loaders are
  read. `0x4A6C30` is reached from the screen, which is consistent with
  `CSpawnFullRevoltCommand`, but the vftable slot was not checked.

## Contradictions with the existing record

- **`CCountry +0x95`** is recorded as `use_own_pool`. `0x50AFF5` tests it and produces
  `WE_NOT_GOVERNMENT_IN_EXILE` when it is clear, so the field is the government-in-exile flag
  and `use_own_pool` names a consequence. Nothing is redefined here.
- **`CRebelFaction +0x94`.** The record calls it "a vector, ending at `+0x98`". The daily
  faction pass at `0x4B9DE7`..`0x4B9E0F` walks it as a **linked list** - `edi = [node]` is
  the province id and `[node + 8]` is the next node, with the walk ending on null rather
  than on `+0x98`. One of the two readings is wrong and this work does not settle which;
  nothing is redefined here.
- **`0x49EAB0` is in `RunDailyPass`, not `RunHourlyPass`.** `FINDINGS-tick.md` has it right
  in the callee list; `image.functionStart(0x682E4B)` answers `RunHourlyPass` because the two
  functions abut. Anything built on that helper's answer in this range is wrong by one
  function.

## How this was found

`definesMap.py` run backwards, as the brief suggested, is what opened the domain: a scan for
`call 0x445D90` sites followed by `mov reg, [eax + <block>]` and then any `[reg + <field>]`
read turns each define name straight into an address, and the partisan and underground
defines all landed in one 0x3000-byte block of the image that had no names in it at all.

Two scanning traps cost time and are worth recording:

- **Linear-decoding the whole `.text`** from its first byte desyncs on the first jump table
  and then reports confident nonsense: a scan for `[reg + 0x328]` that way found **one** site
  in the image, when there are 54, and the province save writer alone has two. Decoding each
  function from its own entry - found from the `int3` padding between them, 25679 of them -
  fixes it.
- **The scratchpad is shared with other agents.** A scratch `dispscan.py` was overwritten
  mid-session by another agent's file of the same name. Scratch scripts in this folder need a
  per-task prefix.

---

# The occupation and revolt wave, 2026-10-14

Six readers, read for OpenHOI3 on 2026-10-14 (`WAVE.md`, "the occupation and revolt wave"), on the
listing throughout unless an item is marked inferred. Addresses are virtual, with rvas beside named
functions. Defines and texts are Their Finest Hour's. The fragments are `fragments/merged/`
`occupation-policy.json`, `revolt-risk.json`, `rebels-made.json`, `rebel-faction-day.json`,
`undergrounds.json` and `counter-espionage-sign.json`; apply 199, `failed: 0`.

**What these sections correct in the ones above and in `FINDINGS-revolt.md`**, so a reader of the
older text knows which sentences to discount:

- Suppression (section 1.3) is summed over **every province within two edges, the province's own
  units counted twice** - not over the adjacent ones - and the `/10` is per province (B.2).
- `GetProvinceEffectiveRevoltRisk` takes **nothing on the stack** (B.1).
- `SetProvinceRevoltRisk`'s flag files a history entry; it announces nothing (B.3).
- `SpawnFullRevoltInProvince` is the province history's `revolt = { }` carried out as a new game is
  entered; `CSpawnFullRevoltCommand` never reaches it - it is the exile's Organized Revolt (B.4, E.8).
- Section 3.3: `0x4C1160` has a by-actor lookup and zeroes revolt risk before testing the faction;
  `FindRebelFactionForProvince` is not "one faction per (rebel type, area)"; `0x4BF6F0` answers the
  country to be freed, not an area; `0x4BAA20` records no pre-revolt owner and controller pair and is
  0x1063 bytes, not 0xDE0; a null rebel type does not log (C.1-C.5, C.9).
- Section 4: `0x4B8F40` is `CRebelFaction::CRebelFaction`, not the `REB` country lookup (C.4).
- `FINDINGS-revolt.md` section 3: the "eight timed and conditional province modifiers" are inlined
  `vector::push_back` growth paths; the `+0x13C` walk is the province's dated `add_province_modifier`
  list, and `nationalism` is static `+0x44` times province `+0x24` (A.7).
- `FINDINGS-revolt.md` section 1.3: the draw at `0x4BA9D4` is not in the daily faction pass but in the
  monthly one, which abuts it (D.6); `0x50B1E0` is the mobilisation itself, not a tooltip (E.8);
  `CanMobilizePartisans` and `CanSpawnUnderground` have six callers each (E.4).
- `SpawnPartisansFromUnderground`'s first argument is the underground's owner, not necessarily an
  exile (E.5).

---

## A. Occupation policies and the rest of a province's modifier

### A.1 What a policy is, and the null one

`common/occupation_policies.txt` is loaded by `LoadOccupationPolicies` (`0x52D0A0`, rva `0x12D0A0`)
into `g_occupation_policies` (`0x1A87A0C`, rva `0x1687A0C`), a name database whose vector at `+0xC`
holds entry 0, **`no_occupation`** - the shared `CNullOccupationPolicy` (`g_null_occupation_policy`,
`0x1A855CC`) - and then one `COccupationPolicy` (0x90 bytes) per block in file order. Their Finest
Hour's are `collaboration_government`, `military_government`, `full_occupation`,
`total_exploitation` and `civil_war`.

A policy is a `CModifier`, its values the block's `local_*` figures, and holds besides `+0x2C` the
name's token, `+0x30` the key, `+0x4C` its index and `+0x50` its `allow` block as an embedded
`CAndTrigger`. Slot 14 answers true for a real policy and false for `no_occupation`. The null
policy's block is empty; its texts are `no_occupation` "No Occupation" and `no_occupation_desc` "This
is never displayed.". Their Finest Hour's file has **no `local_revolt_risk`** in any policy, and
`civil_war` has an `allow` block and no figures.

**A pair's policy is never null.** `CDiplomacyStatus::Reset` stores `no_occupation` - when a country
is made, on a session reset, and in `AnnexCountry` for every country's status toward the annexed.

### A.2 Where `CDiplomacyStatus +0x10` is written

An image-wide scan for `[R+0x10]` stores where R came from a `[X+0xE28]` array within ten
instructions finds three inline stores (`0x4A2F5B`, `0x4A2FBD`, `0x550EDA`), every known reader being
found by the same scan. With the writers that take the status in a register, the complete list:

1. **A capture** (`Province_SetController`, at `0x4A2E62`). Where the new controller differs from the
   old, s = `countries[new]->diplomacy[old controller]` (checked: `edi` is the new controller,
   `[esp+0x28]` the province's controller read at `0x4A2CF8` before it changes). While s holds
   `no_occupation`, `civil_war` is looked up by name and stored if its `allow` holds with country =
   new and FROM = old; if s still holds `no_occupation`, entry 1 of the database is stored - the
   file's first policy, `collaboration_government`. So it is set once, on the first capture, and
   keyed by the **old controller**, not the owner (A.4).
2. **The player's command**, `CChangeOccupationPolicyCommand` (A.3).
3. **History.** A country history line `<policy> = <TAG>` (`0x5EE6C3`) makes a `COccupationChange`,
   whose Apply sets `country->diplomacy[TAG]` with no `allow` test and no rebuild, keeping the old
   policy for going backwards. Their Finest Hour's (GER `total_exploitation = POL`, BUL
   `full_occupation = GRE`, JAP `total_exploitation = CHI`) are all dated 1939 or later.
4. **The save** (`CDiplomacyStatus::LoadKey`, key `occupation_policy`, by name). The writer saves it
   only where slot 14 holds, so a pair at `no_occupation` writes nothing.
5. **Reset**, back to `no_occupation`.

**Nothing resets the policy at peace, on a change of owner, or when the war ends.** No AI or Lua
chooses one: the command's one constructor call is the policy window's (`0x6BAD5A`), luabind registers
nothing about occupation (it names `CChangeLawCommand` 13 times, the control), Their Finest Hour's Lua
never mentions it, and no trigger or effect key exists. So **an AI keeps whatever its captures set**.

### A.3 The command

`CChangeOccupationPolicyCommand` (0x50 bytes, type `0x57B` `change_occupation_policy`): `which`
(`+0x3C`, the country setting it), `target` (`+0x44`), `occupation_policy` (`+0x4C`, by name; an
unknown name keeps the prototype's `no_occupation`). **IsValid is the shared `ReturnTrue`.** Execute
(`0x550E90`, rva `0x150E90`):

    countries[which]->diplomacy[target]->occupation_policy = policy
    for each province in which's controlled provinces (+0xD00):
        if province.owner == target: RebuildProvinceModifierValues(province)
    CCountry::RebuildStaticModifiers(which)

No message is raised.

### A.4 What a province gets, and from whom

The rebuild (A.7, step 7) adds `countries[controller]->diplomacy[owner]->occupation_policy` whole,
except in a province its owner controls and one `REB` controls. **There is no war test**: an ally, or
a country at peace, that controls someone's province applies its own policy toward the owner. Because
a capture keys by the old controller, the two disagree when a province is taken from a third country:
POL land held by GER and retaken by FRA sets FRA->GER, while the rebuild reads FRA->POL - which may
still be `no_occupation`, so the province gets nothing and `no_occupation` is among its contributors.

### A.5 The screen

The politics screen (`CPoliticsView`, `country_politics.gui`). `policies_label`
("OCCUPIED_COUNTRIES", "Occupied Countries") sits over `policies_listbox`, filled once when the screen
is shown (`FillOccupationList`, `0x6BDD10`) with **one row per country** that, in the game state's
country order, owns a province, is not the player, is at war with the player (`+0x20` only) or either
is `REB`, and has an owned province the player controls. A country at peace whose land the player
holds gets no row, though its policy still applies.

A row (`current_policy_entry`, `CPolicyEntry`): `country_icon` the flag, `country` the name, `which`
the display name of the player's current policy toward it (rewritten by the row's slot 9,
`0x6BA490`; every frame, inferred), `select_button` (`GFX_policy_button`) opens the window. Tooltip,
on `which` and `select_button` only: the policy's values, a line each (`DescribeAllValues`), the
delayed half `<key>_desc`.

The window (`policy_selection_window`, `OpenPolicySelection`, `0x6C10F0`) hides `liberate_select` and
`puppet_select`, sets `category` to the occupied country's name, and gives `policy_list` one row
(`possible_policy_entry`, asked for as `possible_Policy_entry`) for **every policy of the file** in
order, `no_occupation` left out and none filtered. A row: `name`, `effect` the values; the current
policy hides `possible_indicator` (its row wears `GFX_bg_selected_policy`), every other row hides
`current_indicator`; `select_button` is **disabled where `allow` is false**, with country = the player
and FROM = the occupied country, and is **not** disabled for the current policy. Its tooltip, on
`select_button` only, is the `allow` block's account of itself (`GetBlockText`, red-when false,
depth 0). Pressing it posts `CChangeOccupationPolicyCommand(player, occupied, policy)` and hides the
window; no dialog, no cost. `cancel` hides it.

| key | English |
| --- | --- |
| `collaboration_government` | Collaboration Government |
| `military_government` | Military Government |
| `full_occupation` | Full occupation |
| `total_exploitation` | Total Exploitation |
| `civil_war` | Civil War |
| `civil_war_desc` | This is a Civil War - no repressive occupation policy is necessary. |

### A.6 Messages

**None**, on a capture, the command or history; neither `messagetypes.txt` nor the executable's
strings has one.

### A.7 A province's modifier, step by step

`RebuildProvinceModifierValues` (`0x49F3E0`-`0x4A068B`, rva `0x9F3E0`; the record's end was wrong).
Every static is added whole and pushed on the contributor list the tooltip reads, unless said.

1. **Clear** the values and contributor list; free the scaled copies (`+0x12C`).
2. **Buildings**, in vector order where `level_max > 0`: `values[kind] += definition.effect_size *
   level_current / 1000`, truncated - the current level, fractions included. **Not listed as
   contributors.**
3. **`overseas`**, and **`blockaded`** inside it (`FINDINGS-leadership.md` section 8).
4. **`non_core`** (the same).
5. **One of three by the template**: `coastal` (land with a sea neighbour, `+0xA0`), else
   `non_coastal` (other land), else `coastal_sea` (sea with a land neighbour, `+0xA1`), else nothing.
6. **`no_adjacent_controlled`**: the province has an owner and no simulated neighbour (template
   `+0x13D`) has its controller - a province with no controller included.
7. **The occupation policy** (A.4).
8. **`blockaded` again** where the province's own port is blockaded (`+0x36C`), independently of 3.
9. **`land_province`** for land (Their Finest Hour's: `attrition = 1`), else **`sea_zone`**.
10. **`manpower` times the province's manpower**, only above 0: `value * manpower / 1000`, 64-bit,
    truncated. Empty in Their Finest Hour.
11. **`nationalism` times the province's `nationalism` (`+0x24`)**, where nationalism is not 0, the
    controller has no core on it and the owner is the controller: `value * nationalism / 1000`. Their
    Finest Hour's block is `local_revolt_risk = 0.3`, so 0.3 points per year left.
12. **The dated modifiers** (`+0x13C`, from `add_province_modifier`), in list order: one whose date has
    passed and whose year is above 1 is unlinked and deleted, else added -
    `year(d) = (d - 43,800,000) / 24 / 365.0`, truncated. The country's active-modifier rule.
13. **Radar.** For an owned province whose `radar_level` differs from the last applied (`+0x378`):
    old < 1000 and new > 0, `AddRadarProvince(controller)`; else old > 0 and new < 1000,
    `RemoveRadarProvince`; store it and queue the hourly intelligence refresh.
14. **`revolt_risk` times the effective revolt risk** (`FINDINGS-revolt.md` section 3, B).

The scaled copies (10, 11, 14) are fresh `CStaticModifier`s with source tag `+0x40 = 0xF`, kept on
`+0x12C` until the next rebuild frees them.

**Nationalism.** `CMapProvince::ChangeOwner` sets `+0x24 = YEARS_OF_NATIONALISM` (20, so 20000)
whenever the old owner is a real country (`FINDINGS-surrender.md`). `RunMonthlyPass` rebuilds every
province from index 1 and then takes 83 off it, floored at 0 (`0x683B9A`, `0x683BA5`).

**When the rebuild runs**, from its 15 callers (`findRefs.py --callers 0x49F3E0`, 2026-10-14; this
paragraph said "and the screen" until then, and no caller is a screen):

- `RunMonthlyPass` (`0x683B9A`): every province from index 1, before the month's nationalism decay;
- `RunHourlyProvincePass` (`0x49EA97`): **every hour, where any of the province's buildings has its
  `changed` byte (`+0x28`) set** - which a bombing, a fallen-back defender's damage and the day's
  repair set. Its tail, read on the listing: the first building with the byte calls the rebuild
  once, which clears them all;
- `RunDailyProvincePass` (`0x49EE0A`): where the day's repair carried a building across a whole
  level (B.1, step 2) - so in practice at once, rather than within the hour;
- `CMapProvince::TakeControl` (`0x4A215B`), a battle's capture; `CMapProvince::ChangeOwner`
  (`0x4A38E2`); `SetProvinceBuildingLevel` (`0x4A3B41`); `CProvince_AddTimedModifier`
  (`0x4A08F3`), `add_province_modifier`; `CChangeOccupationPolicyCommand::Execute` (`0x550FA7`);
  `CExecuteDecisionCommand::Execute` (`0xA09754`); `CCgmSetBuildingLevelCommand::Execute`
  (`0x42CC3F`, the console's command, slot 6 at `0x42CB70`); `ApplyCustomGameSettings`
  (`0x41E050`); and `CInGameIdler::Enter` four times (`0x65AFA8`, `0x65BF7A` before the new
  game's revolt pass, `0x65BFF1`, `0x65C00F`).

**Entering a game makes every province again at least twice** (read on the listing 2026-10-15,
from the function's start so the instructions are aligned; the decompiler times out on it). Two
loops run over every province from index 0: the first (`0x65AE30`) on every entry, nothing
before it able to skip it - the rebuild, then `0x4963F0` and the climate, and the province's
`+0xC` byte cleared; the second (`0x65BD12`) rebuilds each province at the end of its turn, and
in a new game - the state's `+0xD9C` byte clear - once before as well, ahead of
`SpawnFullRevoltInProvince`. **`TakeControl` rebuilds only where the controller changed**: after
`Province_SetController` it compares the province's controller with the one before and jumps past
the rebuild when they agree (`0x4A20F8`-`0x4A20FE`).

**`Province_SetController` is not among them.** A plain change of controller - the day's return
of occupied land (B.1, step 9), an effect - leaves the province's modifier as it was until one of
the above, so the occupation policy reaches a province taken in battle at once and one handed
back within the hour at best and the month at worst.

**Nationalism from the history.** Their Finest Hour has five provinces with two history files
that each set an owner - two files of one name in two of `tfh/history/provinces`' folders (3948,
3949, 4592, 4647), or a base and a `tfh` file of two names (4905) - and those five, and no other
province, hold nationalism 19.917 in the start save (A.8): twenty years less the month a new game
runs. No province history sets an owner in a dated entry on or before 1 January 1936, so nothing
else could have. So an `owner` line where the province already has an owner counts as a change of
owner (*inferred* from the save; how the history applies an `owner` line was not read).

### A.8 Against the saves

Five provinces (3948, 3949, 4592, 4647, 4905) hold nationalism 19.917 on 1 January, 19.834 on 1
February, 19.751 on 1 March, 19.668 on 1 April and 20 April: 83 a month exactly, a month's pass
already run as the game was made. Fifty-two Chinese provinces appear at 19.917 on 1 April. All hold
their owner's core, so the static adds nothing in any of them. The 1 January save has no policy, as
predicted; from 1 February ITA->ETH and ETH->ITA hold `collaboration_government` (ETH->ITA fits the
old-controller key), and from 1 April CHI->CGX `civil_war`, both named in its `allow`.
`collaboration_government`'s `local_partisan_support = 1.5` caps revolt risk at 1.5, which three of
the six Ethiopian provinces of 20 April hold.

**Looks wrong, is the bytes:** a capture keys by the old controller while the rebuild reads
controller->owner; the command checks nothing and `allow` only greys the button, the current policy's
included; the policy applies with no war test while the screen lists only countries at war; a policy
survives peace; `no_occupation` is added as a contributor wherever none was set; `blockaded` can be
added twice; radar adds on any rise from below 1 and removes on any fall below 1; buildings are not
listed as contributors; `civil_war` is looked up with no null test (inferred: a mod without it would
fault on the first capture).

**Not settled:** that the list box reaches `CPolicyEntry`'s slot 9 every frame; the global
`0x1A870F4`; what `GetBlockText` prints for a policy with no `allow`; whether a capture ever hands an
owner's province to a third party in play.

---

## B. Revolt risk and what it does

### B.1 The daily province pass, and the step

`RunDailyProvincePass` (`0x49EAB0`, rva `0x9EAB0`), read to its `ret 4` at `0x49F240`, runs once a
province from `RunDailyPass` at hour 0. **Nothing at all is done to a province whose template is not
`simulated` (`+0x13D`)**. In order:

1. `ComputeProvinceClimate` (`0x4A81A0`).
2. Production climbs and buildings are repaired: roads = infrastructure * (1000 + local + global) /
   1000, held to 10..1000; rate = (100 + roads) * (1000 + `repair_rate`) / 1000; each good of
   `current_producing` rises by the rate toward `max_producing`; each building whose definition says
   `repair` rises by BUILDING_REPAIR_SPEED * rate. **The rebuild flag is set when a repair carries a
   building across a whole level.**
3. `capital` (`+0x2B0`) is set where the controller's acting capital is this province or a neighbour.
4. Suppression (`+0x28`) = `SuppressionNearProvince` (B.2).
5. `RebuildProvinceModifierValues`, **only if the flag is set**.
6. **Revolt risk** (`0x49EE0F`-`0x49EED6`):

        c = CountryOf(controller)
        if (owner_id != c.id && (c.statuses[owner_id].war != 0 || owner == REB || c == REB)) {
            cap  = values[LOCAL_PARTISAN_SUPPORT]
            step = (revolt_risk > cap) ? -100 : +100
            cut  = min(suppression * 100 / 1000, 200)            ; 64-bit, truncated
            revolt_risk += step - cut
            if (revolt_risk > cap) revolt_risk = cap
        }
        if (revolt_risk < 0) revolt_risk = 0

7. `CProvince::UpdateSupplyDepot`.
8. **The `on_encirclement` on_action**, where `out_of_supply_days` (`+0x20`) is exactly 1, the area's
   slot 0 holds and area `+0x68` is set; one draw seeds the scope.
9. **The day's return of occupied land**: owner and controller differ, the owner is not at war with
   the controller, neither is `REB`, and the owner is not in exile -
   `Province_SetController(province, owner, now, true, true, false)`.
10. A province with no owner but a controller gets `Province_SetController(province, ---, now,
    false, false, false)`.
11. On land, the pool's seven goods are held between 0 and 99999.000.

`GetProvinceEffectiveRevoltRisk` (`0x4A4050`, rva `0xA4050`) is as section 1.2 has it - province in
EDI, out in ESI, **nothing on the stack** (bare `ret`). Every reader but `pure_revolt_risk` floors it
at max(values[MINIMUM_REVOLT_RISK], 0).

### B.2 The units, against the saves

`SuppressionInProvince` (`0x49F250`) and `SuppressionNearProvince` (`0x49F360`), re-read:

- **Per province**, P = (sum over friendly units of (sum of regiment strength * 1000 / max strength)
  * the division's suppression / 1000) / 10, each division truncated; the division's suppression is
  its brigades' sum (`CUnit::RebuildDefinition`). The /10 is per province.
- **The province's figure**, S = P(self) + sum of P(q) over `near_provinces` (`+0x14C`) that are land
  under the same controller. That list is **every province within two edges, and the province
  itself**, so its own units count twice.
- So a full-strength brigade with `suppression = 1.00` is 0.100 of S; S = 1.000 stops the climb, S =
  2.000 reverses it at 0.1 a day, and in the effective figure every 1.000 of S is a point off.

**The check.** Italy takes 9987 at 7 January 1936 19:00; `Germany1936_01_07_22.hoi3` has no
`revolt_risk`, `_01_08_02` has `revolt_risk=0.031`. Under Italian control at 22:00, with
`max_strength = 30` and suppression militia 0.33, infantry 1.00, `hq_brigade` 0.67:

| province | units | P |
| --- | --- | --- |
| 9987 itself | 6a Divisione CCNN Tevere, 3 militia at 29.974 | 989 -> 98, counted twice: 196 |
| 9995 (one edge) | 29a 'Piemonte' (2 infantry) and 7a CCNN Cirene (4 militia) | 1998 + 1318 -> 331 |
| 10003 (one edge) | Divisione Libia (3 militia) | 98 |
| 10022 (two edges) | Corpo d'Armata Libico HQ | 670 -> 67 |

S = 692, cut = 69, step = 100 - 69 = **31, the save's 0.031.** Neighbours only predicts 0.048; two
edges counting the province once, 0.041; one brigade's suppression for the division's sum, 0.071.

**`+0x328` and the save's `revolt_risk=`** are the accumulator in thousandths, written only when
positive: `1.500` is 1.5 points, `collaboration_government`'s cap. The six provinces of 20 April were
taken by Italy between 7 January and 12 February and **all went back to Ethiopia at 1936.3.5.0** (step
9, the war over); each is identical on 1 April and 20 April, because an owner-controlled province is
only floored. **Revolt risk freezes once the war between controller and owner stops**, and never
decays. The two at the cap had 15 or more ungarrisoned days; the other four (1.375, 0.974, 0.147,
0.081) cannot be reproduced without saves between 1 January and 1 April. In the maintainer's other
game (as Italy), 9980 holds 0.734 on 1 February and 1 March - held by Ethiopia 8-25 January, then
frozen - and 9960 rises from 0.704 to 1.500, Ethiopia's cap.

### B.3 Who sets revolt risk

`SetProvinceRevoltRisk` (`0x4A40F0`, rva `0xA40F0`), `(province, value, logHistory)`, `ret 0xC`,
**sets** `+0x328 = max(value, 0)`; the flag files a `CRevoltRiskChange` in the province's history,
dated now, saved as a dated `revolt_risk = N` in its `history` block. Nothing is announced. Callers:

- **`CRevoltRiskEffect::Execute` (`0x9A55E3`)**, the effect `revolt_risk = N`, a `CValueEffect`: it
  **adds** N (thousandths) to the accumulator with the flag set, and tests no province (a country
  scope reaches province 0). Its text `REVOLTRISK_EFFECT` "$DIRECTION$ $VALUE$ revoltrisk in
  $WHERE$.\n".
- **`CRevoltRiskChange::Apply` (`0x5FE370`)**, forward and backward: a province history's dated
  `revolt_risk = N`, which **sets** the figure when history is replayed; forward keeps the old figure
  truncated to whole points.
- **`CreateRebelBrigadesInProvince` (`0x4C1301`)**, which sets 0 (C.1).

No province history of Their Finest Hour or BlackICE uses either key.

### B.4 `+0x60`/`+0x64` and the new-game revolt

`+0x60`/`+0x64` are a province history's `revolt = { type size name leader }`: `CRevoltChange::Apply`
(`0x5FFD20`) calls `SetProvinceRevolt` (`0x4A6E40`), which stores the type and the size and **frees
the name and the leader unused**.

`SpawnFullRevoltInProvince` (`0x4A6C30`) has one caller, `0x65BF81`, in `CInGameIdler::Enter`'s
per-province pass, which runs only when the session was not loaded from a save, the modifier rebuild
just before it:

1. if revolt risk is 0, it becomes `local_partisan_support` - for every province of a new game;
2. return if `+0x60` is null;
3. brigades = size * max(1, manpower / 1000);
4. `CreateRebelsForFaction` on the faction `FindRebelFactionForProvince` finds, or `CreateRebelFaction`
   makes one;
5. with a faction and `REB` the controller, `RebelFaction_TakeProvince`.

`CSpawnFullRevoltCommand` (vftable `0x15C4404`, type `0x789` `spawn_full_revolt`; Execute slot 6
`0x55C6A0`, IsValid slot 14 `0x55C800` - the country is in exile, nothing else) runs
`CCountry_MobilizeAllUndergrounds` (E.8). It is posted only by `CPoliticsView::OnRevolt`.

### B.5 The conditions (slot 6; recorded and confirmed, operators re-read)

| keyword | reads | operator | operand | scope |
| --- | --- | --- | --- | --- |
| `revolt_risk` | max(effective, max(MINIMUM_REVOLT_RISK, 0)) | `>` | integer * 1000, decimals cut | province; false on a country |
| `pure_revolt_risk` | effective (can be negative) | `>` | integer * 1000 | province; false on a country |
| `num_of_revolts` | country `+0xF50` | `>=` | raw count | country |
| `revolt_percentage` | `+0xF50` * 1000 / owned provinces (`+0xCF8`) | `>=` | thousandths: 0.3 is 30% | country; false with none owned |
| `nationalism` | province `+0x24` | `>` | integer * 1000 | province |

**What `num_of_revolts` counts**: `CCountry::RebuildNeighbours` zeroes `+0xF50` and adds one for each
owned province whose **controller is `REB`** (`0x4E2A05`), recounted daily and at every change of
hands. `+0xF54` is counted alike and read by nothing.

### B.6 What the player is shown

**The province view** (refresh at `0x6DE5F0`): `text_partisans` shows r = max(effective, max(minimum,
0)) as "§Y" (only when r > 0) + r to one place, truncated, + "%" - `§Y1.5%` - **only at intelligence
9**; below it, `text_partisans`, `text_manpower` and `text_leadership` read "?". `partisans_icon` says
`PV_RR` "Revolt Risk". The figure's tooltip, `BuildProvinceRevoltRiskTooltip` (`0x4A4250`, rva
`0xA4250`): with fog of war on and intelligence below 2, `CANT_SEE_UNDER_FOW` "This is not possible to
determine without further access to the area."; otherwise, in order:

1. `LIKELY_REBELS` "Likely Rebels" + ": §Y" + the `<type>_title` of the type the province would choose
   + "§W", where one is chosen;
2. `PARTISAN_SUPPORT` "Partisan Support" + ": §R+" + **the accumulator** to two places + "§W", when
   above 0 and the controller is at war with the owner;
3. the contributors to `GLOBAL_REVOLT_RISK` "National Revolt Risk" in the controller's modifier (the
   owner's where `REB` holds the province);
4. the contributors to `LOCAL_REVOLT_RISK` "Local Revolt Risk" in the province's;
5. `SUPPRESSION` "Suppression" + ": §G-" + suppression to two places + "§W", when not 0;
6. always, "Minimum Revolt Risk" + ": §Y" + its value to two places + "%§W".

Lines end in "\n" and the whole is trimmed.

**The map mode**, 12 (`MapMode_Revolt_Set`, `0x666430`; button `mapmode_5`, sprite
`GFX_mapmode_revolt`, tooltip `MAPMODE_5` "Revoltrisk Mapmode"), coloured by `0x865C40`: brightness b
= 1.0 where the player knows the province at 2 or more, 0.5 below, 0 for one not simulated; grey
(0.9b, 0.9b, 0.9b) unless the player controls it or knows it at 3 or more; otherwise by r - above 4
points red (f*b, 0.3b, 0.3b) with f = min(1, 0.7 + 0.02 * points), from 2 orange (0.9b, 0.6b, 0.3b),
above 0 yellow (0.9b, 0.9b, 0.3b), at 0 green (0.3, 0.9, 0.3) unscaled; **an underground anywhere in
those provinces paints it red** (b, 0.3b, 0.3b). The map tooltip adds nothing for mode 12.

**The alert** `alert_revoltrisk_in_provinces` (alert 3; `_instant` "§YPossible Partisans§W",
`_delayed` "The following provinces run a risk of having a partisan uprising.\n$LIST$") is built and
sorted every pass (`CompareProvincesByRevoltRisk`) and **never shown**: none of the fifteen calls to
`CAlertManager_Show` passes 3.

**Looks wrong, is the bytes:** revolt risk freezes, never decays, once the war ends; suppression
counts a province's own units twice and reaches two edges; the `revolt_risk` effect adds where a
history `revolt_risk` sets; every new-game province at 0 is first given its partisan support (inert in
Their Finest Hour); the alert is dead; the tooltip's "Partisan Support" is the raw accumulator; the
readout has one decimal and the tooltip two; the readout needs intelligence 9 and the tooltip 2; zero
risk is bright green on the map whatever the intelligence; `revolt_risk` and `pure_revolt_risk` are
strict `>`.

**Not settled:** the four lower Ethiopian figures; the game's own edge list (`provinces.bmp`
adjacency was used, straits unmodelled); the AI readers `0x8B9D46` and `0x8E1AA6`; the view's refresh
whole; which tooltip slot the conditions' keys sit in (`REVOLT_RISK_HIGHER_THAN` "Revolt risk at least
", `PURE_REVOLT_RISK_HIGHER_THAN` "Base revolt risk at least ", `THEN_NUMBER_OF_REVOLTS_ARE_MORE_THAN`
"Number of rebel provinces at least ", `THE_NUMBER_OF_REVOLT_FRACTION_IS_MORE_THAN` "Number of
provinces in revolt at least ").

---

## C. How rebel brigades are made

### C.1 The way in: `CreateRebelBrigadesInProvince` (`0x4C1160`, rva `0xC1160`)

Five callers: the console handler `0x43DF5A`, the roll's spawn `0x4C1110` (count 3), the underground
spawn `0x50B92B` - **the only one passing `forActor` true**, with the underground owner's tag -
`CCreateRebelsEffect` and `CCreateRevoltEffect`. `__fastcall(province@ECX, CRebelType*, count, bool
forActor, CCountryTag* actor)`, `ret 0x10`:

    if (!province.area.slot0() || !province.template.simulated) return      ; +0x2B4, +0xD4 -> +0x13D
    if (count < 1) count = 1
    if (forActor) faction = first faction with type == rebelType && country.id == actor.id
    else          faction = FindRebelFactionForProvince(province, rebelType)
    SetProvinceRevoltRisk(province, 0, false)          ; 0x4C1301, before the null test
    if (faction) {
        if (province.controller != REB) RebelFaction_AddTarget(faction, controller)   ; 0x4B9150
        CreateRebelsForFaction(actor, faction, &id, province, count, forActor)
    } else
        CreateRebelFaction(rebelType, province, state, count, "", forActor, actor)   ; 0x686D80

- `CProvinceTemplate +0x13D` is the recorded `simulated` (`FINDINGS-supplynetwork.md`).
- **Revolt risk drops to nought whenever the two gates pass, even when nothing is made**: a null type
  makes `CreateRebelFaction` return null after the risk is already zeroed. There is no log on that
  path (the string at `0x4C137F` is the empty name).
- `RebelFaction_AddTarget` (`0x4B9150`, rva `0xB9150`, faction in ESI, `ret 8`) appends `{tag, id}` to
  the targets (`+0x70`) unless that id is there: every province a faction rises in adds its controller
  to those it fights.

### C.2 Which faction a rising joins: `FindRebelFactionForProvince` (`0x686CF0`, rva `0x286CF0`)

Over the factions whose type is the wanted one:

    if (type.independence)                                     ; +0x190, 0 or 1
        if (faction.independence.id == ChooseRebelIndependenceTag(type, province).id)
            return faction                                     ; the first match
    elif (type.area == 0 && faction.country.id == province.owner_id)
        found = faction                                        ; the walk goes on
    return found                                               ; the last match, or null

`CRebelType::LoadKey` gives the enumerated keys two values each: `area` = (value != `nation`),
`defection` = (value != `none`), `independence` = (value != `none`), `auto_convert` = (value ==
`yes`). Every shipped type is `area = nation`; `nationalist_rebels` and `patriot_rebels` have
`independence = any`, `patriot_rebels` `defection = any`. So an independence type keeps one faction
per country it would free; a nation-wide type one per country it rises in, the later in the list
winning; a type with any other `area` never matches, so every rising of it makes a new faction.

### C.3 The country to be freed: `ChooseRebelIndependenceTag` (`0x4BF6F0`, rva `0xBF6F0`)

`__stdcall(CRebelType*, CCountryTag* out, CMapProvince*)`, `ret 0xC`; `---` when the province is null,
in no real area, or the type's independence is 0. The candidates, in order: each core of the province
(`+0x344`) that is not `REB`, owns no province (`+0xCF8 <= 0`) and is not listed; then each country of
the database, in order, with the same tests, whose original capital (`CCountry::GetOriginalCapital`:
the history's `capital`, else `+0xE20`) is this province or a neighbour (`HasEdgeTo`). Each scores 1000,
**+200000 for a core of the province**, **+300000 when its original capital is this province**; the
first strictly highest wins.

### C.4 A new faction: `CreateRebelFaction` (`0x686D80`, rva `0x286D80`) and `CRebelFaction::CRebelFaction` (`0x4B8F40`, rva `0xB8F40`)

`CreateRebelFaction` (type in ECX, province in EDI; the game state, count, a by-value name, forActor
and actor on the stack; `ret 0x2C`; callers `0x4C1416` and `SpawnFullRevoltInProvince`):

    if (type && type.independence && !forActor && ChooseRebelIndependenceTag(type, province).id == 0)
        type = ChooseRebelTypeForProvince(db, province, false, ---)       ; not tested again
    if (!province || !type) return null
    f = new CRebelFaction (0xA4)
    f.id = {0x27, g_rebel_id++}
    append f to CCurrentGameState +0xC7C
    CreateRebelsForFaction(actor, f, &id, province, count, forActor)

`0x4B8F40` writes the vftable `0x15C0B6C` (at `0x4B8FA0`): it is the constructor, and its literal
`REB` is stored into **`+0x4C`, `units_owner`**, which the loader's constructor (`0x4B8DE0`) also
writes and which is not saved. A new faction holds: `type` (+0x30) the possibly re-chosen type;
`province` (+0x34) where it rose; `country` (+0x38) `*actor` when forActor, else **the province's
owner**; `government` (+0x40) from `RebelFaction_ChooseGovernment` (`0x4BC900`: among governments
that are real and `valid_for_new_country`, 31000 for one whose ideologies hold the type's `ideology`,
else 1000, +50000 for the faction country's present government, the first highest; where none, the
country's own, the independence country's or the owner's, else the log "Rebel Faction type '...' in
<country> could not find a valid Government type."); `independence` (+0x44)
`ChooseRebelIndependenceTag`; `units_owner` (+0x4C) `REB`; `name` (+0x54) `<type>_name` rendered with
COUNTRY the country's adjective, INDEP the independence country's, EVIL the first target's; targets
(+0x70) one, **the province's controller at creation**; armies (+0x80) and provinces (+0x94) empty.
The name argument is never read.

### C.5 The army: `CreateRebelsForFaction` (`0x4BAA20`, rva `0xBAA20`)

Extent `0x4BAA20`-`0x4BBA82`, two `ret 0x14` (`0x4BAA63`, `0x4BBA80`).
`__fastcall(actor@ECX, faction, int* outArmyId, province, count, bool forActor)`:

    if (count == 0) { *out = {0,0}; return }            ; before the clamp
    owner = faction.units_owner                         ; REB
    if (forActor) owner = *actor                        ; the underground's owner
    elif (faction.type.auto_convert && CountryOf(province.owner).government_in_exile    ; +0x95
          && province.owner_id != province.controller_id)
        owner = province.owner                          ; straight to the exile
    count = clamp(count, 1, 4)

**The clamp is the number of brigades in the one army a call makes.** The roll passes 3; the
underground `UNDERGROUND_SPAWN_STRENGTH / 1000` (0.2, so 0, lifted to 1 by `0x4C1160`): one brigade;
`create_rebels` and `create_revolt` manpower * N (C.7). Then:

1. **One army**, `new CArmy` (0x308, ctor `0x4828C0`), id `{0x27, g_rebel_id++}`, named by
   `RebelFaction_MakeArmyName`: for n = 1, 2, ... `itoa(n)` + the localised ordinal (`ST` "st" for 1,
   `ND` "nd" for 2, `RD` "rd" for 3, `TH` "th" otherwise and for 11-13) + " " + `<type>_army` rendered
   as above, the first no army of the faction has - "1st Ethiopian Partisans" (`partisans_army`
   "$COUNTRY$ Partisans").
2. `CCountry::AddUnit(owner, army)`, `CUnit_SetOwner`; its id pair onto `faction.armies`.
3. **Each brigade**: `new CSubUnit` (0xD8) as a `CRegiment`, an id from the same counter, named by
   `CCountry::MakeSubUnitName` of **the faction's country**; `SetType` with the type's `unit`
   (+0x188), `home` = the province. **Experience** starts at the constructor's -1000 and gets += the
   **faction's first target's** `partisan_efficiency` (`[[c+0xDA8]+0x278]`), capped at 100000 - so -1.0
   plus the occupier's efficiency (in Their Finest Hour from `civil_law`, 1 to 4, the trait
   `prince_of_terror`, 10, and the static `spy_support_resistance`, 5). **Technology**: for each
   technology of the definition, level = `Random() % L`, L the first target's level, 0 where L is 0 -
   the inlined draw at `0x4BADED`, one per technology above 0, so always strictly below the occupier.
   `ApplyTechnologies(b, false)` clamps strength and organisation to the new maxima: **full strength
   and full organisation**. `AddRegimentToUnit`.
4. `CUnit::EnterProvince` twice around `RebuildAvatar`; the army's intel for the player 9 for his own,
   his faction's or an ally's, else the province's.
5. **`CCombatManager::CheckForCombat(army, province)`**: a rising where non-rebel troops stand starts
   in combat at once.
6. **No leader** is given. The provinces list (+0x94) is filled when rebels take a province (D.4).

### C.6 What the player is told

The province's controller is taken after placement and before the battle check.

- **The controller is the player**: `REVOLT`, with the province, the controller's message variables
  and `MESSENGER` (`MESSAGE_HEAD_MARS` "The General Staff reports"), `REBELS` the faction's name,
  `REBELDESC` `<type>_desc` (`partisans_desc` "Partisans fight against enemy occupiers, and they dream
  of expelling their enemy from the country."), `PROV`. Texts: `REVOLT_LOG` "$REBELS$ are revolting in
  $PROV$!", `REVOLT_HEADER` "$minister_of_security$ reports", `REVOLT_MAP` "Revolt!";
  `messagetypes.txt`: log, on map, popup, no pause, `cat_province`. Then the sound `army_selected`
  plays unless playing (inferred).
- **Otherwise, the army's owner is the player** (an exile's or an underground's partisans):
  `PARTISANS`, with the owner's variables, `MESSENGER`, `PROV`, and `EVIL` the controller's name;
  `PARTISANS_LOG` "Partisans rising up for us in $PROV$.", `PARTISANS_HEADER` "$minister_of_intelligence$
  reports", `PARTISANS_MAP` "Partisans!". No sound.
- Nobody else. The controller is tested first.

### C.7 The two script effects (`FINDINGS-effectrun.md`)

`<rebel type> = N` is `CCreateRebelsEffect`; `create_revolt = N` is `CCreateRevoltEffect`. N is
thousandths; the count is trunc(province manpower * N); the scope is a province. `create_rebels`
names its type and so bypasses `spawn_chance`; `create_revolt` checks the area and `simulated` and
takes `ChooseRebelTypeForProvince(..., false, ---)`. Both call `CreateRebelBrigadesInProvince(...,
false, ---)`: 1 to 4 brigades a use, owned by `REB` unless `auto_convert` gives them to an exile, the
province's revolt risk set to 0. `CREATE_REBELS` "§R$SIZE$§Y $TYPE$§W regiment(s) rise up in revolt in
§Y$WHERE$§W." shows the count before the clamp.

### C.8 In a save

Factions, armies and brigades take their ids from one counter, `g_rebel_id` (`0x170AF7C`), saved in the
header as `rebel=`, type 39 (0x27) where ordinary units are 41. All twelve of the maintainer's saves
have `rebel=1` and no `rebel_faction` block: nothing has risen in that game by 20 April 1936.

**Looks wrong, is the bytes:** the brigades take experience and technology from the faction's first
target, the occupier; experience starts at -1.0; technology is `Random() % L`, so 0 at L = 1; revolt
risk is zeroed when nothing is made; a nation-wide type joins the last matching faction and an
independence type the first; the re-chosen type is not tested again; `EnterProvince` runs twice; a
count of 0 returns before the clamp; the `CREATE_REBELS` text shows the count before the clamp; an
occupier who is the player is told `REVOLT` even of an exile's partisans.

**Not settled:** what `0x4BBA90` collects for the name test (inferred: the faction's armies, which D
confirms as `RebelFaction_CollectUnits`); whether `ideology = any` leaves `+0x184` null; the sound
slots; how the unit writer emits a rebel army.

---

## D. The rebel faction's day

A faction lives on two clocks: **every day** (`RunDailyRebelFactionPass`, `0x4B9D60`, rva `0xB9D60`,
ending `ret 4` at `0x4BA4CD`) and **every month** (`RunMonthlyRebelFactionPass`, `0x4BA4D0`, rva
`0xBA4D0`, which abuts it with no padding and is called once, from `RunMonthlyPass` at `0x683CF6`).
Nothing reads `can_enforce_trigger` or `demands_enforced_effect` and nothing posts the rebel
acceptance command, so **rebels make no demands in this build**, and defection never fires.

### D.1 "Friendly" and "hostile"

`RebelFaction_IsFriendlyCountry` (`0x4B98D0`, rva `0xB98D0`; faction in EAX, a `CCountryTag` by value,
`ret 8`) works over the faction's targets (+0x70): with none, everybody is friendly; otherwise the
country is friendly only if, for every target T, T is not the country and the country is at war with T
(`CDiplomacyStatus +0x20`) or either is `REB`. Partisans in occupied Poland (target GER) find Poland,
at war with Germany, friendly; nationalists rising in a country that holds its own land have it as
target, so nothing it holds is friendly.

`RebelFaction_IsHostileProvince` (`0x4B9970`, rva `0xB9970`; faction in EDI, province in ESI): **in
reach** - the type's `area` is not 0, or the province is owned by the faction's country - and its owner
or its controller is not friendly.

### D.2 The day, in order

1. **`RebelFaction_ResilientRetreat`** (`0x4BD4E0`, rva `0xBD4E0`), nothing unless the type is
   `resilient` - no type in Their Finest Hour or BlackICE is. For each unit in a battle, battle by
   battle until one retreats: fighting a friend, it retreats; otherwise, only if `smart`, it weighs the
   odds - units marching into the battle province join their sides; ratio = their brigades / ours (land
   units, ours at least 1), nothing below 0.75; power is the sum of `CUnit::GetPower` (ours 10 where 0);
   d = their dice - ours scales theirs by 1 + d/18 (d > 0) or ours by 1 + |d|/4.5 (d < 0); above 5.0
   for (their/our power) * ratio it retreats. It retreats to the hostile land neighbour (edge kind not
   3) scoring highest above -1000: +1000 per regiment of a `REB` unit there, -1000 per other regiment,
   +4000 when `REB` controls it, -10000 when its controller is friendly, the first of equals.
2. **Death test 1**: the faction's country owns no province **and** the type's `area` is `nation`:
   `wants_removal` (+0x90) set, return.
3. **Death test 2**: an independence country (+0x48) that already owns a province: the same.
4. **Provinces.** For each id on +0x94: controlled by `REB`, owned, the owner friendly - listed; not
   controlled by `REB` or unowned - dropped (marked only while +0xA0 is set; +0x9C down). **Each listed
   province is handed back to its owner**, `Province_SetController(province, owner, now, 1, 0, 0)`,
   with every capture consequence (`FINDINGS-surrender.md` D.2), the building damage included.
5. **Every faction rebuilds the area and supply groups every day**, unconditionally.
6. **Armies cleanup**: each entry on +0x80 whose unit no longer exists or whose owner is not `REB` is
   dropped (marked only while +0x8C is set; +0x88 down).
7. **Death test 3**: no armies (+0x88) and no provinces (+0x9C).
8. **Movement**, for each idle unit - not moving (+0x140 <= 0), not retreating (+0x158), not fighting
   (+0x11C <= 0). `target = RebelFaction_ChooseMoveTarget` (D.3). With no target on non-hostile ground:
   to the faction's home province (+0x34) if it is hostile; else, if the home's controller is friendly,
   **the unit is disbanded** (`RebelFaction_RemoveArmy`, `CGameState::RemoveUnit(state, unit, 0, 1)`).
   With a target: `CPathFind::Find`, the path **cut** after the first province on it in reach whose
   owner or controller is not friendly (after its first province where none is), `SetUnitPath(unit,
   path, 1)`.

### D.3 Where rebels go: `RebelFaction_ChooseMoveTarget` (`0x4B99D0`, rva `0xB99D0`, `ret 8`)

1. A type both `reinforcing` and `smart` stays put while strength per brigade is below 0.66 (a full
   Their Finest Hour brigade is 30) - the only reader of `reinforcing`.
2. **One `Random()`** (`0x4B9A8F`) seeds a scope with **no country**, the candidate as its province.
3. Only where the unit's province is in a real area: every province of its `COwnerArea` (+0x24), then
   those of each touching area (+0x34 links, in order), each having to be hostile.
4. score = `CMeanTimeToHappen::GetDays(&type.movement_evaluation, scope)`, **halved** where the
   candidate is not an edge neighbour.
5. The highest above 0 wins, the first of equals.

Their Finest Hour's `movement_evaluation`: `units_in_province = 1` x0.1, `controlled_by = REB` x0.001,
`revolt_risk` x1.5 three times, `is_core = REB` x5.

### D.4 When rebels take a province

**`REB` becomes the controller, never the owner** (`CMapProvince::SetOwner` refuses it). At a capture
in `CCombatManager::CheckForCombat` (`0x430B5E`-`0x430CF5`, read on the listing 2026-10-15): a `REB` unit
with a faction makes the new controller `REB`; then the faction's independence
country when the type's `independence` is **0** and that country owns land (the test reads inverted);
then the current controller where it is friendly; then the **owner** where it is friendly, last and so
winning - partisans that win in their owner's occupied land hand it straight back. That country is
what `CMapProvince::TakeControl` is then called with (`0x430CF5`), once no other land unit stands there
that is not retreating, has neither order field (`+0x300`, `+0x304`) set and is an enemy of it - its
owner `REB`, the taker `REB`, or the taker at war with it or in an undeclared war covering the province.
The same test, with the unit's owner as the taker, is every country's capture. Where the controller
changed and the old one was the player, `PROVINCELOST` goes to him: PROV the province, COUNTRY the new
controller's name, or the name of the rebel faction holding it where `REB` does.

When `REB` does become controller of an owned province with units, `Province_SetController` makes the
first `REB` unit's faction take it, `RebelFaction_TakeProvince` (`0x4BCBB0`, rva `0xBCBB0`) - **the
siege won**: one `Random()` seeds a scope with no country, the province, and the faction as
`rebel_faction`; `siege_won_trigger` is asked; if it holds, the province's owner is the player and
`siege_won_effect`'s text is longer than one character, **`REVOLTSIEGE`** is raised (`MESSENGER`
`MESSAGE_HEAD_MARS`, `REBELS`, `EFFECT`, `PROV`) - with no message type or text in either install, so
as the null type - and `siege_won_effect` runs for any owner. Whether or not it held, the province id is
appended to +0x94. Every type of both installs leaves both blocks empty. Because the scope carries the
faction, `release_vassal = REB` in a siege effect frees the faction's independence country (D.6).

### D.5 Defection: wired, never fires

For factions with no independence country, the monthly pass takes each province on +0x94 that `REB`
controls, with no land battle, not its owner's capital: date = `ProvinceHistory_LatestControllerDate(
history, REB)` + `defect_delay` months; **the first province whose date is still ahead ends the whole
pass**; otherwise `RebelFaction_GetDefectionTarget` (`0x4BC800`, rva `0xBC800`) is asked. With
`defection = none` it answers `---`; with anything else it walks every country comparing the tag's
first two letters with `R` and `E`, **stores nothing**, and answers `---` too (checked on the listing,
`0x4BC8B0`-`0x4BC8D7`). So `Province_Defect` (`0x4C0B50`, inferred; `WEDEFECT` "The province of $PROV$
has defected to $COUNTRY$", `THEYDEFECT`, `OTHERDEFECT`) is unreachable, and the defection arms of
`add_core`, `remove_core`, `secede_province` and `is_core` get `---` too.

`defect_delay` is whole months; `CRebelType`'s constructor defaults it to `YEARS_UNTIL_BROKEN` * 12 =
24. Their Finest Hour: `partisans`, `organized_partisans`, `disgruntled_rabble` 24; `nationalist_rebels`
12; `patriot_rebels` 6.

### D.6 Independence

For factions with an independence country, monthly: the candidates are the faction's provinces that
are not their owner's capital, hostile, and a core of the independence country or `defection` 1; with
none, nothing. date = the earliest `REB` control date among them + `defect_delay` months; if still
ahead, nothing. chance = ratio * 100 * 0.15, ratio being the candidates over the same set counted again
- always 1 - so **15% a month**, `Random() % 100` (`0x4BA9D4`). On success
`RebelFaction_GrantIndependence(faction, ---)` (`0x4BE590`, rva `0xBE590`): `ReleaseProvinces`
(owner changes, cores, technology, three-brigade armies, the `INDEPENDANCE` message - D.9 - "$foreign_minister$
reports that $ACTOR$ Has Declared Independence from their former masters of $OPRESSOR$ and are now
enjoying freedom to oppress each other.", log "$ACTOR$ declared independence from $OPRESSOR$."); every
unit of the faction transferred to the new country, leaders with them; the faction's government written
into the new country's +0xDFC; called with `---`, **one war per distinct former owner**, the new
country attacking, `revolutionary_war` set, named "$ORDER$$FIRST$-$SECOND$ War"; `wants_removal` set.

### D.7 Rebel acceptance

`CExecuteRebelAcceptanceCommand` (0x84, a `CCommand` plus a `CEventScope` at +0x3C, type `0x647`):
IsValid, the scope's `rebel_faction` resolves and it has a country; Execute (`0x55B6E0`) raises
`REBELACCEPTANCEUS` or `REBELACCEPTANCEOTHER` (no type, no text), resets the scope's random state and
stamps `last_rebel_acceptance` (`0x4EFED0`) - nothing else. **Nothing posts it**: its vftable is written
only by the prototype `RegisterCommandTypes` makes and by Clone. `REBEL_ACCEPTANCE_MONTHS` (60) has
**no reader** (every load of the defines' country block scanned for `+0x10`; the same scan finds
`YEARS_UNTIL_BROKEN` five times and `ELECTION_RANDOMNESS` at the elections). EU3 heritage, unfinished.

### D.8 Every rebel-type key

| key | what it does |
| --- | --- |
| `area` | `nation` = 0, else 1; with 0 death test 1 applies and the reach is the country's own provinces |
| `defection` | never makes a province defect; `any` counts every hostile province toward independence |
| `defect_delay` | months (D.5, D.6) |
| `independence` | C.3 chooses the country; D.6 frees it |
| `auto_convert` | read only by `CreateRebelsForFaction` (C.5) |
| `resilient` | D.2 step 1; also `CUnit::RetreatFromCombat` |
| `reinforcing` | only with `smart` (D.3) |
| `smart` | D.2 step 1 and D.3 |
| `siege_won_trigger`, `siege_won_effect` | D.4 |
| `can_enforce_trigger`, `demands_enforced_effect` | never evaluated |
| `unit_transfer` | **not a key**: the loader has no case, so it is dropped |

**Looks wrong, is the bytes:** defection's chooser keeps nothing; the monthly defection branch ends the
whole pass at the first province not yet due; the independence chance is a ratio of one set counted
twice; every faction rebuilds the area and supply groups daily; a province handed back takes capture
damage; the inverted-looking independence branch at capture; movement and the siege are asked in a scope
with no country; `unit_transfer` is no key; a unit with nothing left to fight beside a friendly home is
deleted.

### D.9 Releasing a country: `ReleaseProvinces` (`0x4C1430`, rva `0xC1430`)

Read on the listing on 2026-10-15, where `FINDINGS-effectrun.md` 2.9 had the decompiler only; the record
is raised to confirmed. `(CList of CMapProvince*, tag, id)`, `ret 0xC`; an empty list does nothing. The
**oppressor** is the first province's owner, taken before anything moves.

1. **Each province, in list order:**
   - once for each distinct owner, `war_seen_tick` both ways between the released country and that owner
     set to an hour count 24 behind now;
   - `CMapProvince::ChangeOwner(province, released, now, applyConsequences 1, rebuildAreas 0, peaceful 1)`;
   - a core of the released country added where it has none;
   - where the province is the released country's history capital (its history's capital entry, else its
     capital) and its capital is not its original capital, the capital moves here.
2. The area and supply groups, made again.
3. **Technology**: for every technology in the database's order, where the released country's level is
   below the oppressor's, it becomes the oppressor's, at most the technology's `max_level`.
4. **Armies**, where the infantry brigade answers that it may be built: **each released province whose
   IC modifier is above 0 gets an army of three infantry brigades** of the released country - ids, names
   and registration as any unit's, the brigades' home the province, entered into it, the player's
   intelligence of it set as for rebels (C.5), and a battle checked for.
5. **`INDEPENDANCE`**: MESSENGER from `MESSAGE_HEAD_CHAN`, ACTOR the released country's name, OPRESSOR the
   oppressor's, placed at the released country's capital, both of its country pairs the released.
6. `CCountry_FillMinisterPosts(released, 1, 0)`.

No vassal relation is made and nothing is declared: the wars of D.6 are `RebelFaction_GrantIndependence`'s.

### D.10 `CCountry +0x44`, and the rebels' officers

`+0x44` is a byte the hourly officer recount, the daily country pass and three other country loops skip a
country on. A scan of every byte store to `[reg+0x44]` in `.text` (54, each stretch decoded from its own
start) finds it set to 1 by `CCountry::CCountry` and `CCountry_Reset`, and cleared only by
`CInGameIdler::Enter` (`0x65B1B9`), for a country whose id is not on the scenario's list (`+0x88`) when a
scenario is set. It is recorded as `in_scenario`. **In a campaign every country holds it, `REB` among
them** - which closes `FINDINGS-aisched.md`'s open item.

So the rebels' officer ratio is recounted every hour like anyone's, and with no officers - their
history file is empty, and nothing gives `REB` leadership - it is nought. A brigade's organisation
ceiling is its figure times the ratio (`FINDINGS-organisation.md`, section 2), and the hourly regain holds
it there: **a rebel brigade made at full organisation is at nought after its first hour**. That follows
from the rules as read, and the maintainer confirms it of the running game (2026-10-15): rebels have no
organisation.

**Not settled:** the order of the history list `ProvinceHistory_LatestControllerDate` walks;
`Province_Defect` read off the decompiler only; the `REB` test in `CUnit::UpdateHourly` (`0x5B9F1D`,
`FINDINGS-organisation.md`), which hands a rebel unit of under 0.1 strength in all to `0x684C80`.

---

## E. Undergrounds and partisans

### E.1 In one line

An underground is a **province building** - whichever building carries `local_underground`, put in the
building database's `+0x28` slot by its modifier id `0x66`. A country at war builds one through
production in a province held by its enemy; it starts at a strength falling with distance from the
nearest friendly air base, or at full `UNDERGOUND_INITIAL_STRENGTH` in an exile's own land; it grows by
`UNDERGROUND_STRENGTH_GAIN` a day and may be found by the garrison's suppression; on action 0 it rises as
partisans every day it is at `SPAWN_PARTISAN_LIMIT`, on 1 it plants a new underground in a neighbour
every day it is full. An exile has Organized Revolt, which raises every ready underground in its own
land at once.

### E.2 The building and its levels

`common/buildings.txt` (both installs): `underground = { onmap = yes capital = yes local_underground =
1 visibility = yes cost = 4 time = 180 on_completion = militia_theory completion_size = 0.1 max_level =
1 show_for_province = no repair = no }`. The province holds it at `+0x30C`: `level_max` (+0x20),
`level_current` (+0x24, **the underground's strength**), a dirty byte (+0x28). The owner is
`underground_owner` (`CProvince +0x38C` tag, `+0x390` id), the action `underground_action` (`+0x394`).

`level_max` is raised 1000 (capped at `max_level`, so 1.0) by `CBuildingConstruction::Deliver`
(`0x485BD0`, a finished line with a target province), `CBuildingDeployment::DeployAt` (`0x57E640`, a
line placed later on the map) and `SpawnUndergroundFromProvince`; a custom game's
`CCgmSetUndergroundCommand` sets both levels to 1000. Both go to 0 on the pass's removal (E.4),
`Province_SetController`'s dissolution (`FINDINGS-surrender.md` D.4 step 6), and the custom game's
destroy.

A new underground by `Deliver` or `DeployAt` (the latter only where the level was below 1 and is now
above 0): `level_current += Underground_GetInitialStrength(province, builder)`, capped; the builder
becomes `underground_owner`; the province goes on the builder's list (`CCountry_AddUnderground`,
`0x50A030`); the template byte `+0x20` set to 1.

**Initial strength** (`0x509230`, rva `0x109230`): an exile building in a province it owns gets
`UNDERGOUND_INITIAL_STRENGTH` (0.4) flat. Otherwise `Underground_FindNearestAirBase` (`0x509050`,
rva `0x109050`) takes the builder's `AirBases` (+0xD70), then each ally's (+0xF88), own first, the base
**strictly below** `MAX_UNDERGROUND_DISTANCE` (1000) by `CMap::DistanceBetweenProvinces` (kilometres,
x wrapping), the first of equals; none in range gives 0; otherwise r = d * 1000 * 1000 / 1000 and
strength = (1000 - r) * 0.4 / 1000, 64-bit, truncated - 0.4 at the base, nothing at 1000.

**Where it may be built** - the production screen's button is `CCountry_CanTrainUnderground` (at war,
not in exile; `FINDINGS-productiontooltip.md` section 6); per province `Underground_CanPlaceIn`
(`0x508230`, rva `0x108230`): with `requireEmpty` no underground there; its **controller at war with
the builder**; the builder a **friend of its owner** (military access counted); and unless the builder
is a major (+0x15C) or has `MaxIC` (+0x60C) above 100, the owner **is the builder** - a minor builds
only in its own occupied land.

**The modifier**: `local_underground = 1` puts `level_current` into value 102 (+0x330); a whole-image
scan finds **no reader** of it (positive control: `+0x260` gives four, the three known among them).

**The list** `CCountry +0xD60` (`underground_provinces`): appended by `CCountry_AddUnderground` and the
spread, and rebuilt **whole** by `CCountry::RebuildNeighbours` (`0x4E3086`) from every province, in id
order, with `level_max > 0` and the country as `underground_owner` - which is how a load restores it.

**Finished**, `Deliver` and `DeployAt` raise `BUILDING_DONE` ("$NAME$ has been built in $PROV$.") to the
player only where he **controls** the province: for an underground, the occupier; the builder hears
nothing. No save of the maintainer's holds an underground.

### E.3 Placing one on the map

While a deployment is placed, `0x867A00` colours the map (inferred): a province where an underground
can go green `0.6 + 0.3 * initial / UNDERGOUND_INITIAL_STRENGTH`, red and blue 0.5; other valid
provinces green 0.9; everything else grey 0.5.

### E.4 The daily pass, `RunDailyUndergroundPass` (`0x50A110`, rva `0x10A110`)

From `RunCountryDailyPass` at `0x4DBB64`, after `0x507630` and before the revolt roll. For each
province on `underground_provinces`, in list order:

1. **Growth**, first, every day:

        factor = values[LOCAL_PARTISAN_SUPPORT] * 10 / 1000 + 1000
        gain   = factor * UNDERGROUND_STRENGTH_GAIN / 1000             ; 64-bit, truncated
        level_current = min(level_current + gain, level_max)

   0.01 a day in Their Finest Hour with no support.
2. **Detection**: threshold = `fistp((float)(suppression * UNDERGROUND_DETECT_CHANCE / 1000) /
   1000.0)` (round half to even), detected = draw % 1000 < threshold. With
   `UNDERGROUND_DETECT_CHANCE = 2`, round(suppression * 2 / 1000) in a thousand a day, suppression in
   thousandths (B.2): S below 250 never finds one; three full `garrison_brigade` (2.00 each) at S = 600
   give 1 in 1000. A detected underground goes on the removal list and **the local player only** is
   told: `OURUNDERGROUNDREMOVED` where he owns the underground (header "$minister_of_intelligence$
   reports", log "Our underground base in $PROV$ was destroyed", map "Underground destroyed!"), else
   `UNDERGROUNDREMOVED` where he controls the province ("We destroyed an underground base in $PROV$");
   both `log=no onmap=yes popup=yes`, `cat_units`. A detected one does nothing else that day.
3. **Liberation**: otherwise, where the province's controller is its **owner**, onto the removal list
   with **no message**.
4. **Otherwise, the action**: 0, where `CanMobilizePartisans`, the province is collected; 1, where
   `CanSpawnUnderground`, `SpawnUndergroundFromProvince` runs **at once**; 2 or anything else, nothing.

After the walk: `SpawnPartisansFromUnderground(country, province)` for each collected (`0x50AD08`);
then each removed one - `SetProvinceBuildingLevel(province, underground, 0, false)` (which rebuilds the
province's modifier), off the list, `underground_owner = ---`, both levels 0, template `+0x20` = 1.

`CanMobilizePartisans` (`0x50B450`; country in EAX, province in ESI): on the list, and the bypass byte
or `level_current >= SPAWN_PARTISAN_LIMIT` (0.5). `CanSpawnUnderground` (`0x50BB20`): the same with
`SPAWN_UNDERGROUND_LIMIT` (1.0) and no bypass. **Neither asks for an exile.** So an underground built
at a base starts at 0.4, rises first on day 10 paying 0.5 to nought, then every 50 days; on action 1 it
needs to be full (60 days from 0.4) and pays all of it.

### E.5 Partisans, `SpawnPartisansFromUnderground` (`0x50B630`, rva `0x10B630`)

As section 2 has it, with two corrections: its first argument is the underground's **owner**, not
necessarily an exile; and `0x4C0430` is `ChooseRebelTypeForProvince(db, target, allowTriggeredOnly 1,
&owner.tag)`, which is why the triggered-only `organized_partisans` can be drawn. Then
`CreateRebelBrigadesInProvince(target, type, UNDERGROUND_SPAWN_STRENGTH / 1000, 1, &owner.tag)`: one
brigade (C).

### E.6 A new underground, `SpawnUndergroundFromProvince` (`0x50BD00`, rva `0x10BD00`)

One `Random()` (`0x50BD8D`) modulo the source's edges picks a neighbour, taken only when it has no
underground and the same owner id as the source. **If it fails nothing happens and nothing is paid**:
the fallback walk (`0x50BE70`) re-tests the random neighbour every pass and never succeeds; the next day
draws again. On success: the target's `level_max += 1000` (capped), `level_current +=
UNDERGROUND_SPAWN_STRENGTH` (0.2), `underground_owner` = the source's, onto the list; **then** the source
pays `SPAWN_UNDERGROUND_LIMIT` (1.0), floored at 0. No test of the target's controller, area or
`simulated`, and no template byte: a spread into land its owner controls is removed by the next day's
liberation, silently.

### E.7 What sets `underground_action`

Written only by `CChangeUndergroundMission::Execute` (`0x55C970`) and the loader; 2 is the default and
is not saved; **nothing resets it**, so a new underground inherits the province's last action.

| class | type | fields | IsValid | Execute | posted by |
| --- | --- | --- | --- | --- | --- |
| `CChangeUndergroundMission` | `0x79E` | +0x3C target, +0x40 type (default 2) | target != 0 | `underground_action = type`, the map icon refreshed | the province view's `underground_mission`; the AI; a Lua constructor no script calls |
| `CSpawnPartisanCommand` | `0x786` | +0x3C province | id, owner id, `CanMobilizePartisans(owner, province)` | `SpawnPartisansFromUnderground(owner, province)` | `spawn_partisan`; run in place by Organized Revolt |
| `CSpawnUndergroundCommand` | `0x787` | +0x3C province | id, owner id, `CanSpawnUnderground` | `SpawnUndergroundFromProvince` | `spawn_underground` |
| `CSpawnFullRevoltCommand` | `0x789` | +0x3C country | in exile | `CCountry_MobilizeAllUndergrounds` | the politics screen's `revolt` |

**The province view's `underground` window** (`province_interface.gui`: `underground_status`,
`spawn_partisan`, `spawn_underground`, `supression_icon`, `text_supression`, `underground_mission`)
shows (`0x6EA920`, not read to its end) in a custom game's setup where the player could build;
otherwise for an underground the player owns, or someone else's where the player could place one.
`underground_status` is a bar at `level_current * 100 / 1000`. `spawn_partisan` and `spawn_underground`
are enabled where the predicate holds for the player and post the command for the province - or, with
several selected, for each with the player's underground passing it - **at once, not waiting for the
day**. `underground_mission` shows frame action + 1 (3 with no underground), is enabled only for the
player's own, steps forward (1, 2, 3, 1; `0x6EA380`) and back (`0x6EA490`) and posts
`CChangeUndergroundMission(province, frame - 1)`; which mouse button is which was not read.

**Tooltips** (`BuildProvinceViewTooltip`, `0x6E4250`; main line and delayed half told apart by layout,
inferred): `underground_status` `UNDERGROUND_STATUS` "Underground strength: §Y$CURRENT$§W/§Y$MAX$§W" to
one place, truncated; `spawn_partisan` for another's underground `UNDERGROUND_OWNER_DESC` "Underground
owned by §Y$COUNTRY$§!", for the player's `SPAWN_PARTISAN` "Spawn partisan unit" then
`MOBILIZE_PARTISANS` "Mobilize nearby partisans" at the limit or `UNDERGROUND_NOT_STRONG_ENOUGH` "Not
strong enough. §Y$LIMIT$§W is needed and is currently at §Y$CURRENT$§W"; `spawn_underground` the same
with `SPREAD_UNDERGROUND` "Expand underground resistance network" and `MOBILIZE_UNDERGROUND` "Organize a
nearby underground base" against `SPAWN_UNDERGROUND_LIMIT`; `underground_mission` for another's
`UNDERGROUND_OWNER_DESC`, for the player's by action 0 `UNDERGROUND_ACTION_PARTISAN` "Spawn partisan unit
as soon as we can", 1 `UNDERGROUND_ACTION_SPREAD` "Spread underground network as soon as we can", 2
`UNDERGROUND_ACTION_NONE` "Do nothing and build up strength"; `supression_*` `SUPRESSION` "Suppression".

**The map icon** (`0x640450`, inferred): frame action + 1 for the player's own, action + 4 for anyone
else's; under fog of war a foreign underground shows only where the player could place one.

### E.8 Organized Revolt

The politics screen's `revolt` ("Organized Revolt!", `FULL_RISING`), shown only for an exile, is enabled
by `CCountry_CanMobilizeUndergrounds` (`0x50AE40`): in exile, and an underground on its list in a
province it **owns** strictly above `SPAWN_PARTISAN_LIMIT`. Its tooltip (`0x50AFD0`): not in exile,
`WE_NOT_GOVERNMENT_IN_EXILE` "We are not a government in exile"; else over the undergrounds in owned
provinces (TOTAL) and those strictly above the limit (VAL), VAL = 0 `UNDERGROUNDS_NOT_PREPARED` "None of
our $TOTAL$ underground resistance cells are prepared yet", else `UNDERGROUNDS_READY_TO_RISE` "$VAL$ of
our $TOTAL$ underground resistance cells are prepared to rise up". Pressed, it posts
`CSpawnFullRevoltCommand`, whose Execute runs `CCountry_MobilizeAllUndergrounds` (`0x50B1E0`): every
owned province on the list strictly above the limit, in list order, gets a `CSpawnPartisanCommand` built
on the stack, its IsValid asked (at or above the limit) and its Execute run. Undergrounds in an ally's
land are not counted. The exile's other rules are `FINDINGS-surrender.md` C.7.

### E.9 The AI

**C++**: `AI_ManageUndergrounds` (`0x889E10`, rva `0x489E10`, inferred), every hour from `ProcessAI`
for each AI country with undergrounds (not `REB`, not the player), groups them by their province's
`COwnerArea`. For each area: a score from 0 - only where `0x47FD90(area)` holds (unread) - over the
area's fronts (C the controller of the front's first province not held by its owner, L the owner of the
first neighbour its owner controls and at war with C, the walk ending where there is none; a front
whose L is at war with the AI skipped; unit strengths (slot 27, unread) summed for friends of C and of
L, skipped where L's is above 0 and C's below 1.1 times it; else score += (C - L) * 0.1, times 1.5
where the area's controller is the AI), capped at 1000, t = 1000 - score. **Spread** where n /
min(area provinces, 200) < (20 + 20 * t / 1000) / 1000 - every underground there not on 1 set to 1;
**otherwise** with `ready` the count at or above the limit, every one not on 2 set to 2 where `ready <
n * t / 1000`, else every one set to 0. With no fronts it waits until **all** of an area's undergrounds
are ready, then mobilises them together; it posts only where the action changes.

**Lua**: `ai_production_minister.lua` (Their Finest Hour 1357-1373) builds them with
`CConstructBuildingCommand(tag, underground, GetRandomUnderGroundTarget(), 1)` where IC > 0.1; a
country file may override `Build_Underground` (France helps build them, Germany never). No script posts
a mission or spawn command. `CCountry::GetRandomUnderGroundTarget` (`0x509920`) was not read.

### E.10 The bypass byte

`[0x1A85599]` (`g_ignore_partisan_spawn_limit`) is written only by the console command
**`alwayspartisants`** (`ap`; "Toggles ability to always spawn partisants from undergrounds."), handler
`0x43A980`, and read by `CanMobilizePartisans` and the AI.

### E.11 Defines (Their Finest Hour)

| define | value | where read |
| --- | --- | --- |
| `SPAWN_PARTISAN_LIMIT` | 0.5 | mobilisation: `>=` in the pass and the province buttons, `>` on Organized Revolt; and its cost |
| `SPAWN_UNDERGROUND_LIMIT` | 1 | the spread's threshold and cost |
| `MAX_UNDERGROUND_DISTANCE` | 1000 | air-base reach and the initial fall-off |
| `UNDERGOUND_INITIAL_STRENGTH` | 0.4 | initial strength; the placing map's scale |
| `UNDERGROUND_STRENGTH_GAIN` | 0.01 | daily growth |
| `UNDERGROUND_DETECT_CHANCE` | 2 | detection |
| `UNDERGROUND_SPAWN_STRENGTH` | 0.2 | the partisan brigade count (truncated, then at least 1) **and** a spread's starting strength |
| `UNDERGROUND_PARTISAN_STRENGTH` | 1 | no reader |

**Looks wrong, is the bytes:** a failed spread does nothing and the fallback never succeeds; a spread
can land where its owner controls and be removed the next day, the 1.0 lost; Organized Revolt counts
ready only above 0.5 while the pass and the buttons mobilise at it; only Organized Revolt needs an
exile; it raises only undergrounds in the exile's own land; `UNDERGROUND_SPAWN_STRENGTH` is a count and
a strength; `BUILDING_DONE` goes to the occupier; `underground_action` is never reset; liberation is
silent and tests the province's owner; growth runs before detection and liberation; detection rounds
half to even; the status bar is percent of 1.0; the removal messages carry two COUNTRY variables and
use only PROV.

**Not settled:** `0x47FD90` and unit slot 27 (the AI's score is read by its shape); the mission button's
mouse buttons; the view tooltip's main and delayed halves; the underground's save pair;
`GetRandomUnderGroundTarget`; whether the list is in province order when the pass runs.

---

## F. What `counter_espionage` really does

Settles `CANDIDATES.md` item 7. `counter_espionage` (modifier 55) is read **once** in the image: it is
added to `SPY_DETECTION_CHANCE` when a country catches spies in its own territory, so it helps at home
and does nothing anywhere else. `espionage_bonus` (42) is also read once, in the same function, off the
country the spies are standing in: it multiplies every catch there by (1000 - value) / 1000, so it
protects foreign spies inside the holder's country and does nothing for the holder's own spies abroad.
**BlackICE renames 42 "Domestic Counterespionage Difficulty"** (`MODIFIER_ESPIONAGE_BONUS` in its
`localisation/interface.csv`), and that name fits what the bytes do; the original calls it "Espionage
bonus" and writes a positive value green.

### F.1 The keys and the definitions

`InitModifierDefinitions` (`0x456E00`, rva `0x56E00`) builds the definitions in vector order:

| construction | id | name | token | flags (more-is-better, percent) |
| --- | --- | --- | --- | --- |
| 43rd, call `0x457D64` | 42 | `MODIFIER_ESPIONAGE_BONUS` | `0x4C4` `espionage_bonus` | 1, 1 |
| 55th, call `0x458162` | 54 | `MODIFIER_COUNTER_INTELLIGENCE` | `0x4EA` `counter_intelligence` | 1, 1 |
| 56th, call `0x4581B8` | 55 | `MODIFIER_COUNTER_ESPIONAGE` | `0x4EB` `counter_espionage` | 1, 1 |

The flag order's positive control is `MODIFIER_DISSENT` (43): percent, more is worse, as recorded.
**`CModifier::LoadKey`** (`0x459620`, rva `0x59620`): `icon` (token `0xB2`) to +0x28; **every other key
is matched against each definition's token at +0x20**, the first match winning, its value read as
thousandths into `values[position * 8]`; a miss logs `unknown modifier '<key>' in file <file>` and drops
the key (the record had said such keys were dropped in silence). Nothing swaps 42 and 55. English:
`MODIFIER_COUNTER_ESPIONAGE` "Counterespionage", `MODIFIER_ESPIONAGE_BONUS` "Espionage bonus",
`MODIFIER_COUNTER_INTELLIGENCE` "Counterintelligence".

### F.2 The catch, re-read

`CSpyPresence::CatchSpies` (`0x52E3A0`, rva `0x12E3A0`), `(presence, actor, target)`: the base is
`SPY_DETECTION_CHANCE`, and `add edx, [[actor+0xDA8]+0x1B8]` at `0x52E484` runs only when actor and
target are the same country - **`counter_espionage` is the catching country's own, added, only at
home**. At `0x52E6BD`-`0x52E6D0`, `mov ecx, [[target+0xDA8]+0x150]; mov eax, 1000; sub eax, ecx; imul` -
**`espionage_bonus` is the target's** (the country the spies are in), never the spies' owner's, lowering
the chance in both arms. Callers: `DailyEspionagePass` (`0x4FFEA8`, its own record and tag twice) and
`RunDailyMissions` (`0x5300B7`, any presence with a counter-espionage weight). A total of +0.1 doubles
the home chance; -0.1 (`free_press` alone) leaves a base of nought, and no catch at home can pass except
a friend's hostile spies with their +1000000.

### F.3 Every reader, by every form

Over a resumed sweep of `.text`: a forward trace of every values pointer (a country's `[x+0xDA8]`, a
province's `[x+0x114]`, any `CModifier`'s `[x+0x18]`) finds `+0x1B8` only at `0x52E484` and `+0x150`
only at `0x52E6C3` (controls: `RunMilitaryEspionage`'s `+0x1D8`/`+0x1E0`, `CSpyPresence_GetIntelFactor`'s
`+0x1B0`); every `[values + reg*8]` was followed to its index and none can reach 42 or 55 (`GetValue`,
`0x4179E0`, is Lua's, and Their Finest Hour calls it once, for `_MODIFIER_GLOBAL_IC_`); of every push or
mov of `0x37` and `0x2A`, only `0x620498` reaches a modifier - the contributor list of 55 for the
intelligence screen's `value_spies_caught` tooltip (D.6 of `FINDINGS-espionage.md`). Nothing else reaches
either: not military intelligence, the steal, the boosts, threat, covert operations, the coup, the AI.

### F.4 The tooltip

`CModifier::DescribeOwnValue` colours by +0x29; both are set, so positive is green. "Counterespionage:
+10.0%" in green is right - it helps catching. "Espionage bonus: +10.0%" in green is **the inverted
tooltip**: its one effect is to make spies in the holder's own country harder to catch. Their Finest Hour
hands it out as though it helped the holder: the `comintern` faction modifier (0.1), the minister types
`technical_specialist` and `power_hungry_demagogue` (0.05), the triggered modifier `neutrality` (0.1)
for every country outside a faction, and four event modifiers.

### F.5 Against the start save

The save has 33 spies fewer abroad than OpenHOI3's set-up (1816 to 1783). Every presence abroad holds
all weights at 0, so no foreign catcher runs and every caught spy falls under the no-mission x0.1.
Modelled from the save's levels and weights, friends by faction, alliance and vassal, and
`counter_espionage` and `espionage_bonus` totalled from the press law, `neutrality`, the Comintern and
the posted ministers' types, over two days with two home rolls a day (1482 presences, 1768 spies):

| reading | expected catches (sd) |
| --- | --- |
| neither modifier | 13.9 (3.7) |
| **as read** | **24.9 (5.0)** |
| 55 subtracted (the "difficulty" sense) | 5.4 (2.3) |
| 42 raising instead | 30.4 (5.5) |
| 55 only | 27.7 (5.2) |
| 42 only | 12.7 (3.6) |

The save's 33 is +1.6 sd from the reading; OpenHOI3's 22 (with triggered modifiers) and 18 (without)
are single draws about 24.9 and 13.9; "counter-espionage makes catching harder" predicts 5.4, which the
save rules out. **The 22-to-33 gap is not evidence of a misreading.**

**What the maintainer's observation comes to.** He was describing `espionage_bonus`, which BlackICE
labels "Domestic Counterespionage Difficulty", and the bytes bear him out exactly: it is read only off
the country the spies are in, lowers every catch there, and does nothing for his spies abroad. The
original's "Espionage bonus", green when positive, is the inverted tooltip. `counter_espionage` does
what the reading said.

**Not settled:** no save pair with a counter-espionage law changed; the model ignores co-belligerence and
military access as friendship and uses the save's levels; a values pointer handed to another function is
beyond the trace (no indexed or immediate site suggests one).
