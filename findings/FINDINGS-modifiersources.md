# What OpenHOI3's modifier rebuilds lacked, read: the subject's step, the laws' order, the blockade and the radar list

Read 2026-11-14 by the `modsources` agent (the radar list's removal - two callers of `CCountry_RemoveRadarProvince`, `0x4A047A` and
`0x4A270E`, and its unlink of `+0x1148` - checked off the listing by the collecting session) for OpenHOI3's `docs/mechanics/modifiers.md`, setting its country and province rebuilds beside
`CCountry::RebuildStaticModifiers` (22 steps, `FINDINGS-countrymodifier.md`) and `RebuildProvinceModifierValues`
(14 steps, `FINDINGS-occupation.md`, section A). Addresses in the tables are rvas; the listings are virtual addresses
(rva + 0x400000, trap 1). Values are thousandths.

## Synopsis

The country rebuild's step 19 - a puppet's master's faction's `align_towards_*` - was read to the byte: it is the
static the master's faction names as its `influence`, skipped where the puppet's own active_modifiers hold that very
pointer, and a missing static is not guarded. The laws are walked in law-group order (the `laws` vector is indexed by
group), which OpenHOI3 had not followed. The at-war blockade test in step 10's province loop is dead. The blockaded
byte (`CMapProvince +0x36C`) is worked out only by the controller setter, and `UpdateBlockadeLevel` is now
`confirmed` with its formula. **Corrected**: OpenHOI3's intelligence spec held that a country's radar list is never
taken from; `CCountry_RemoveRadarProvince` is reached from two places and removes, and the province rebuild's radar
step is "old < 1000 and new > 0 adds, else old > 0 and new < 1000 removes", not a crossing of 1000.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0xDF479` | `RebuildStaticModifiers_SubjectInfluence` | new | confirmed | step 19 to the byte: the faction's `influence` static, skipped by pointer in active_modifiers; null not guarded |
| `0xDEA50` | `RebuildStaticModifiers_AddControlledProvinceModifiers` | revised | confirmed | the at-war blockade test at its tail does nothing |
| `0xE1FC0` | `UpdateBlockadeLevel` | revised | confirmed | was inferred; the flag's writer read, the formula and the three callers written out |
| `0xDD250` | `CCountry::AddRadarProvince` | revised | confirmed | not "crosses 1000"; -1 pushed even when already listed |
| `0xDD370` | `CCountry_RemoveRadarProvince` | revised | confirmed | the search, the two callers; it removes |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| `CCountry` | `+0xBD4` | `blockade` | `int` | revised - comment: its one writer read |
| `CCountry` | `+0x1148` | `radar_provinces` | `CList<int>` | revised - comment: every toucher, its one reader, not saved |
| `CProvince` | `+0x378` | `radar_level_applied` | `int` | revised - comment: the real rule, and the setter's write |

## 1. The country rebuild

### The laws, by group

`CCountry +0x628` is one `CLaw*` per law group, indexed by the group's own index (the record's field, three readings).
Step 7 walks it from index 0, adding each law whose slot 16 answers true. **So a country's laws come among the
modifier's contributors in `laws.txt`'s order of groups**, whatever order a history file or a save named them in.
Nothing new was read for this; it is what the record already says, written down because OpenHOI3 walked them in the
order given and its top bar's tooltips listed them otherwise (Germany's history names education before economy).

### Step 10's tail is dead

The province loop (`0x4DEA50`..`0x4DEB98`) ends each turn with:

    0x4DEB53  cmp byte [edi+0xacc], 0          ; at_war
    0x4DEB60  cmp byte [eax+0x36c], 0          ; the province's blockaded byte
    0x4DEB6F  cmp [eax+0x330], ecx             ; owned by this country (+0xCA8)
    0x4DEB7F  call 0x42F100                    ; GetActingCapitalLocation
    0x4DEB84  cmp esi, [eax+0x2b4]             ; same area as the capital?
    0x4DEB8E  call 0x42F100                    ; again - and the result is not used
    0x4DEB93  next province

`0x42F100` is `CCountry::GetActingCapitalLocation`, a getter. Nothing follows from the test: a remnant of something
removed. No effect on any figure.

### Step 16, the modifier at `+0x700`

`FINDINGS-countrymodifier.md` found nothing that fills it by a scan for `+0x700`. A scan for its values pointer's
displacement, `+0x718`, finds no `CCountry` function either (its hits are stack slots, `CInGameIdler` and the lobby).
Still `likely` always empty; not watched live.

### Step 19, a puppet's master's faction

`0x4DF479`..`0x4DF57A`:

    if (!country->isSubject (+0xF34)) skip
    if (country->faction (+0xD8) && faction->slot7()) skip          ; in a real faction itself
    overlord = countries[country->Overlord.id (+0xF3C)]
    if (!overlord->faction || !overlord->faction->slot7()) skip
    m = FindStaticModifierByName(overlord->faction)                 ; reads faction +0xBC, the `influence` string
    if (m) for each entry of country->active_modifiers (+0x648): if entry->modifier (+8) == m, skip
    add m's values; push m onto the contributors

The pointer compare is how an influence or an alignment, which put the same static on the country's active_modifiers,
keeps it from counting twice. **The null case is not guarded**: `test ebx,ebx; je 0x4DF533` at `0x4DF517` jumps over
the list walk straight into the add loop at `0x4DF533`/`0x4DF550`, which reads `[ebx+0x18]` - so a
`static_modifiers.txt` without the faction's influence name faults here. Their Finest Hour's three are
`align_towards = 20`, BlackICE's 15.

## 2. The blockaded port

**`UpdateProvinceBlockaded` (`0xA65E0`)**, read whole (the record's account, checked):

    if province has an owner (+0x330), a port (+0x354), a naval base (+0x300) built above 0 (+0x20),
       and its template is simulated (+0x13D):
        n = sum of regiments_count (+0x40) over the units of the port's sea province (port +0x18 -> +0x2B8)
            that UnitBlockadesProvince accepts
        blockaded (+0x36C) = n >= 1
        UpdateBlockadeLevel(owner)
    else blockaded = 0, return

**`UnitBlockadesProvince` (`0x1C8110`)**: not fighting (`combats_count +0x11C <= 0`), not retreating (`+0x158`),
`CCountry::IsEnemy(owner, &province->controller, province)` (an undeclared war over the province counts), and
`regiments_count >= 1`.

**Its one caller is `Province_SetController` (step 8, every change, with or without consequences)**, after the new
controller is written. So a port is blockaded or not as of the last change of its controller: a fleet arriving or
leaving tells it nothing, a port that never changes hands is never blockaded, and one taken with enemy ships off it
stays blockaded until it changes hands again. Not saved (no key in any save of the maintainer's).

**`UpdateBlockadeLevel` (`0xE1FC0`)**, now `confirmed`:

    ports = cut = 0
    for each province the country owns (+0xCF0):
        if (area +0x2B4 == acting capital's area || continent +0x368 == acting capital's continent)
           && owner && port && naval base built > 0:
            ports++
            if (blockaded || owner != controller) cut++
    blockade (+0xBD4) = ports ? cut x 1000 / ports (truncated; a fixed-point divide of cut x 1000 by ports x 1000) : 0

Callers: `CCountry::UpdateMonthly` (after `UpdateMaxManpower`), `CInGameIdler::Enter` (after `UpdateIC`), and
`UpdateProvinceBlockaded` for the port's owner. Readers of the byte: `is_blockaded`, `UpdateBlockadeLevel`, the
province rebuild's overseas step (via `COwnerArea::FindOpenPort`, whose only caller it is) and its second
`blockaded` step, and the dead test of
section 1.

## 3. The radar list

**`CCountry::AddRadarProvince` (`0xDD250`)**: appends the id unless present, then pushes -1 onto
`CCurrentGameState +0xCF8` - on both paths (a match jumps from `0x4DD285` to `0x4DD2D8`, which is the push).

**`CCountry_RemoveRadarProvince` (`0xDD370`, ECX the country, EDX the id, bare `ret`)**: finds the first node with
that id (`cmp [eax],edx` at `0x4DD3A0`), hands it to `CList_RemoveNode` (`0x5D49D0`) - a null node where absent -
and pushes -1 either way. **It removes.** Its two callers:

- `RebuildProvinceModifierValues_Radar` (`0x4A047A`): for an owned province whose `MODIFIER_RADAR_LEVEL` differs from
  `radar_level_applied (+0x378)`:

      if (applied < 1000 && level > 0)       AddRadarProvince(controller, id)
      else if (applied > 0 && level < 1000)  RemoveRadarProvince(controller, id)
      applied = level; push -1

  so 0.5 -> 0.7 adds again (a no-op, but a refresh), 1.5 -> 0.5 removes, and 0.5 reached from 0 is listed. The -1
  is pushed only on this changed branch.
- `Province_SetController` (`0x4A270E`), step 2b, with `applyConsequences` (peaceful or not): `v != 0` adds to the
  new controller, the old one is always removed, `applied = v`. A change without consequences moves nothing, so the
  old holder's list keeps the province.

**Who touches `+0x1148`** (a scan of the displacements `0x1148`/`0x114C`/`0x1150`): the constructor, the function at
`0x4CA740` (likely the destructor), `CCountry_Reset`, Add, Remove, and **one reader, `UpdateIntelFunctor_SerialBody`
(`0x688AB0`)**, which takes each listed province's current level. Not saved: a load starts every list empty and
`radar_level_applied` at 0, and `CInGameIdler::Enter`'s province rebuilds list every owned province with radar under
its controller of the moment.

**Corrected**: OpenHOI3's `docs/mechanics/intelligence.md`, section 4, said a country's radar provinces are a list it
"adds to and never takes from". The record already had `CCountry_RemoveRadarProvince` with its setter caller
(`FINDINGS-surrender.md` D.2); the spec had not followed it.

## Not established

- Whether the province's unit list (`+0x2B8`) of a sea province holds passengers aboard a fleet and aircraft passing
  over; a blockade counts whatever it holds.
- Whether `combats_count (+0x11C)` counts a bombing.
- The `+0x700` modifier in a running game.
