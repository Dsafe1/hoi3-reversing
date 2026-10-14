# Spies, intelligence, and what the espionage sliders buy

Read out of `hoi3_tfh.exe` on 2026-09-30 with the game **not running**. Addresses are
virtual, based at `0x400000`, with the rva beside them where a finding names one. Nothing
below was watched happening; every number is the image's.

**In one line.** `CSpyPresence` is a `0xF8`-byte record held one per country in a
`std::vector` at `CCountry +0x1160`, it carries **nine mission allocations and their
normalised shares**, the nine missions are resolved once a game day from
`RunCountryDailyPass` on the tick thread (not on a worker), the roll is the game's MT19937
at rva `0x1310F80`, and **three of the twenty-two espionage defines have no reader at
all** - `SPY_MISSION_CHANGE_DAYS`, `SPY_CONNECTION_DETECTION_CHANCE` and
`SPY_BASE_CONNECTION_DETECTION_CHANCE`. The two intel TBB fan-outs are a **different
subject from spies**: they rebuild every province's per-country fog of war, both from one
function that `RunDailyPass` calls last, and both bodies run on TBB workers.

## `CSpyPresence`, field by field

**The anchor.** The class has no vftable and so no RTTI record, but the name is the game's
own: luabind registers `CSpyPresence` (`.?AVCSpyPresence@@` at `0x1747B64`) with
`GetLevel`, `GetPriority`, `GetLastMissionChangeDate`, `GetMission` and `GetSpyPresence`.
The layout is anchored on

- **`CCountry::GetSpyPresence`, `0x444920 / 0x44920`** - six instructions, `ret 4`, `this`
  in ecx: `return (char*)this->espionage[+0x1160] + tag->id * 0xF8`. That fixes the stride
  at `0xF8` and the indexing at the country id.
- **the constructor, `0x52D380 / 0x12D380`**, `ret 0xC`, which writes every field below and
  whose two `mov dword ptr [reg], 0x15BC568` writes (`0x52D3D6` and `0x52D3F8`) prove the
  two embedded subobjects. The RTTI export names `0x15BC568` **`CStaticModifier`**.
- **`CCountry::SaveContents`**, whose espionage block (`0x4D1D60`-`0x4D1F35`) walks the
  vector and writes six keys, and **`CCountry::LoadKey`** (`0x4CCDA0`), which reads them
  back. `(this->+0x1164 - this->+0x1160) / 0xF8` is the count, at `0x4D1D71` and four more
  places - the `0x84210843` magic with `sar edx, 7` is division by 248.

| offset | name | save key | |
| --- | --- | --- | --- |
| `+0x00` | `level` | `spy_allocation` | spies present, **x1000** - 10 spies is 10000. Clamped to `[0, MAX_SPY_LEVEL]` by the setter |
| `+0x04` | `priority` | `spy_priority` | a plain int, 0..3 |
| `+0x08` .. `+0x28` | `missions[9]` | `spy_mission` | plain ints, one per `SpyMission` - how many spies are put on each |
| `+0x2C` .. `+0x4C` | `mission_share[9]` | - | **derived, x1000**: `missions[k] * 1000 / sum(missions)`. Never saved |
| `+0x50` | `last_mission_change` | `spy_date` | a tick; the constructor sets it to `[0x170C2B8]` (43800000, the epoch) |
| `+0x54` | `lower_unity_modifier` | - | a `CStaticModifier` **held by value**, `0x48` bytes |
| `+0x9C` | `raise_unity_modifier` | - | the second one, same size |
| `+0xE4`, `+0xE8` | `target` | - | a `CCountryTag`: the country the record is *about* |
| `+0xEC`, `+0xF0` | `owner` | - | a `CCountryTag`: the country whose vector this is |
| `+0xF4` | `covert_ops_points` | `covert_ops_points` | x1000, capped at `SPY_COVERT_OPS_MAX` |
| | | | `0xF8` bytes in all |

Which tag is which is read off the construction site, not guessed:
`0x4D5017` calls the constructor with `(out, &otherCountryTag, &ownerTag)` inside a loop
over the country database, so `+0xE4` takes the second argument and `+0xEC` the third.
`CSpyPresence::IsHostileMission` bears it out - it resolves `+0xE4` to a country and asks
*that* country whether it is allied with `+0xEC`.

`+0x54` and `+0x9C` are `0x48` apart and `0x54 + 0x48 = 0x9C`, which is what fixes the
`CStaticModifier`'s size; each has a values array pointer at its own `+0x18` and a
`std::string` at its own `+0x2C` (capacity `0xF`, size 0, first byte 0 - an empty MSVC
short string).

**The two writers are lists of ints and lists of thousandths, and the save says which.**
`spy_priority` and `spy_mission` go through `0x4608D0`, which formats each element with a
plain `%d`; `spy_allocation` and `covert_ops_points` go through `0x4C8050`, which converts
each element with `0xA694C0` - a divide by 1000 and a `%d.%03d`. So the priority and the
mission counts are whole numbers and the level and the covert ops points are thousandths.

### The owner is `CCountry`, and the vector is one record per country

`CCountry +0x1160` / `+0x1164` / `+0x1168` is a `std::vector<CSpyPresence>` - begin, end,
capacity. The constructor (`0x4C8A40`) zeroes all three at `0x4C9ABF`, `0x4C9AC5` and
`0x4C9ACB`, and the country's teardown (`0x4CA740`) destroys the range at `0x4CA982` and
zeroes them again.

**It is sized once, from the country count.** `0x4D4FC9`, inside `0x4D4C50`, calls
`0x50EB70` with `ecx = &country->espionage` and the country count (`countryDB[+0x168]`),
then loops the whole country database building one record per country through the
constructor. So the index into the vector is the country id, which is also the index into
`CCurrentGameState +0xBBC` - both the daily pass and `GetSpyPresence` rely on that.

### How a presence grows and shrinks

Four things move `+0x00`, and no others were found:

| | |
| --- | --- |
| **up** | `CDistributeEspionage::Distribute` (below) hands out whole spies from the country's pool |
| **up/down** | `CSpyPresence::SetLevel` (`0x52D4A0 / 0x12D4A0`), `this` in **EAX**, `ret 4`: store, floor at 0, cap at `[0x170D164]` (= 10000, `MAX_SPY_LEVEL`, ten spies). `modify_spies` uses this - see `FINDINGS-script.md` |
| **down** | a spy caught by counter-espionage costs the perpetrator exactly `1000` - one whole spy - at `0x52E74F`, `add ecx, 0xFFFFFC18`, then floored at 0 and re-capped |
| **reset** | the constructor, at zero |

**`[0x170D164]` (rva `0x130D164`) is `MAX_SPY_LEVEL` and no instruction writes it** - it
holds 10000 in `.data` and is only ever read, by eight sites, all espionage. That agrees
with what `FINDINGS-script.md` already says about `modify_spies`. **`MAX_NUMBER_OF_SPIES`
is a different thing** and does not clamp the level: it is read only by
`CDistributeEspionage::Distribute` (`0x51ED2E`) and by the espionage view (`0x62890A`).

### `mission_share` is recomputed, not stored

**`CSpyPresence::SetMissionAllocation`, `0x52D4D0 / 0x12D4D0`** - `this` in ecx, the
mission index on the stack, the value in **EAX**, `ret 4`:

```
missions[mission] = value
total = missions[0] + ... + missions[8]
if (total == 0) { mission_share[0..8] = 0; return }
for k in 0..8:  mission_share[k] = missions[k] * 1000 / total
```

so `mission_share` is each mission's share of the country's spies in that target, in
thousandths, and every mission effect below is scaled by it. It is not written to the save
and does not need to be: **`CCountry::LoadKey` calls the same setter** (`0x4CE583`) for
every one of the nine values it reads, dividing the flat index by 9 to get the country
(`0x38E38E39`, then `shr ecx, 1`) and taking the remainder as the mission. So a loaded game
has the shares right.

## The nine missions, and which function resolves each

`SpyMission` is a luabind-registered enum (`.?AW4SpyMission@@`) and the nine localisation
keys sit consecutively in `.rdata` from `0x15EC590`, with `SPYMISSION_NONE` and
`SPYMISSION_MAX` beside them at `0x15C2CC0`/`0x15EF4D0`. The order there matches the order
the dispatcher tests the nine dwords in, and each handler reads exactly the define its name
would predict - which is what makes the mapping safe rather than a guess.

| # | offset | `SpyMission` | resolved by | its define | its share |
| --- | --- | --- | --- | --- | --- |
| 0 | `+0x08` | `COUNTER_ESPIONAGE` | `0x52E3A0 / 0x12E3A0` | `SPY_DETECTION_CHANCE` (`country +0x20`) | `+0x2C` |
| 1 | `+0x0C` | `MILITARY` | `0x52FD40 / 0x12FD40` | `SPY_MILITARY_INTEL_TIME_BASE` (`+0x9C`), `MILITARY_ESPIONAGE_DETECTION_CHANCE` (`+0xA0`), `MILITARY_ESPIONAGE_AT_BASE_CHANCE` (`+0xA4`) | `+0x30` |
| 2 | `+0x10` | `TECH` | `0x52EBE0 / 0x12EBE0` | `TECH_ESPIONAGE_BASE_CHANCE` (`+0x94`), `TECH_ESPIONAGE_TECH_PICK_FACTOR` (`+0x98`) | `+0x34` |
| 3 | `+0x14` | `BOOST_RULING_PARTY` | inline, `0x53010C`-`0x53017C` | `SPY_PARTY_ORGANIZATION_BOOST` (`+0x38`) | `+0x38` |
| 4 | `+0x18` | `BOOST_OUR_PARTY` | inline, `0x530182`-`0x5301F7` | `SPY_PARTY_ORGANIZATION_BOOST` | `+0x3C` |
| 5 | `+0x1C` | `LOWER_NATIONAL_UNITY` | `0x530340 / 0x130340`, first half | none - a modifier | `+0x40` |
| 6 | `+0x20` | `INCREASE_THREAT` | inline, `0x5301F7`-`0x530281` | `SPY_THREAT_INCREASE_ACTION` (`+0x54`) | `+0x44` |
| 7 | `+0x24` | `RAISE_NATIONAL_UNITY` | `0x530340`, second half | none - a modifier | `+0x48` |
| 8 | `+0x28` | `COVERT_OPS` | inline, `0x530281`-`0x53032C` | `SPY_COVERT_OPS_GAIN` (`+0x80`), `SPY_COVERT_OPS_MAX` (`+0x84`) | `+0x4C` |

### The two entry points

**`CCountry::DailyEspionagePass`, `0x4FFD10 / 0xFFD10`** - `0x4FFD10` to the `ret 4` at
`0x4FFEBD`, one `CCountry*`. Its **one caller is `0x4DB93E`, inside `RunCountryDailyPass`**
(`0x4DA530`-`0x4DC239`), which `RunDailyPass` calls in its *serial* country loop at
`0x682E1A`. So espionage is resolved **once per country per game day, on the thread that
runs the tick** - not on a TBB worker.

```
for (i = 0; i < gamestate->countryCount; ++i) {
    target = gamestate->countries[+0xBBC][i]
    if (target->ownedProvinces (+0xCF8) <= 0) continue
    presence = me->espionage + i * 0xF8
    if (presence->level <= 0) continue
    RunDailyMissions(presence, me->tag, target->tag)       // 0x5300A0
}
own = me->espionage + me->tagId * 0xF8
if (own->missions[0] != 0) CatchSpies(own, &me->tag, &me->tag)   // 0x52E3A0
```

The second call is the one that matters for detection: a country's **own** record is where
its counter-espionage sits, and the pass runs that arm directly rather than through the
dispatcher.

**`CSpyPresence::RunDailyMissions`, `0x5300A0 / 0x1300A0`** - `0x5300A0` to the `ret 0x10`
at `0x530331`, `this` in **ESI**, and two `CCountryTag`s **by value** on the stack
(`actorTag`, `actorId`, `targetTag`, `targetId` - which is what `ret 0x10` counts). It
tests each of the nine dwords in turn and does nothing for a zero. **Mission 5 and mission
7 are not here**: they are modifiers rather than daily effects, and `0x530340` applies them
from somewhere else entirely (below).

**Mission 1 is throttled to one day in eight.** `0x5300D6`:
`0x44C5C0(&gamestate->tick[+0xBDC]) + targetId`, `and 0x80000007`, with the usual
negative fix-up, and the handler runs only when that is zero. So military intel resolves on
the day where `(day + targetId) mod 8 == 0`, which spreads the eight-day cycle across the
countries.

### The arithmetic, in thousandths

Every mission effect has the same first two terms. Writing `L` for `level` (x1000) and
`S[k]` for `mission_share[k]` (x1000):

    effect = L * DEFINE / 1000 * S[k] / 1000

**Mission 3, boost ruling party** (`0x53010C`): the amount goes to the **target's own**
ruling ideology - `target->ideology (+0x1140)`, index `[ideology + 0x4C]` - added into
`target->+0x10C4[index]` and, unless the total would go negative, also into
`[target->+0x10D4 + index*16] + 0xC`. **Mission 4, boost our party** (`0x530182`) is the
same code with the **actor's** ideology index instead. What `CCountry +0x10C4` and `+0x10D4`
are is **not established** here; the define's name says party organisation and that is as
far as this goes.

**Mission 6, increase threat** (`0x5301F7`): `SPY_THREAT_INCREASE_ACTION`, then
`x * 1000 / 10000` - a divide by ten - then `0x42F100` on the target country and
`0x4F4E80(target@EDI, &amount, &1000)`. Neither of those two was read.

**Mission 8, covert ops** (`0x530281`): `SPY_COVERT_OPS_GAIN`, then a range test
(`-1607028 .. 2147483` in thousandths) picking a 32-bit or 64-bit path, then
`covert_ops_points (+0xF4) += x`, capped at `SPY_COVERT_OPS_MAX` (`0x530326`). The cap is a
hard store, not a refusal.

**Mission 2, tech espionage** (`0x52EBE0`, `ret 0xC`):

    chance = L * TECH_ESPIONAGE_BASE_CHANCE / 1000
    chance = chance * S[2] / 1000
    percent = chance / 1000
    if (MT19937() % 100 > percent) return                     ; 0x52EC4B..0x52EC5A
    ... both countries' CTechnologyStatus (+0xDF8), then 0x540D60 ...

so the chance is read as **whole percent**, and the comparison is `>` - a computed 0%
still succeeds when the draw's remainder is 0, i.e. one day in a hundred. The tech pick
itself uses `TECH_ESPIONAGE_TECH_PICK_FACTOR` at `0x52EEED` and was not read.

**Mission 1, military intel** (`0x52FD40`, `ret 0xC`), as far as its chance:

    timeBase = SPY_MILITARY_INTEL_TIME_BASE / 1000
    chance   = MILITARY_ESPIONAGE_DETECTION_CHANCE * 10000 / 1000     ; ten times the define
    chance   = chance * L / 1000 * S[1] / 1000
    landFactor  = 1000 + actor->modifiers[+0x1D8]                     ; modifier 59, MODIFIER_OFFMAP_LAND_INTEL
    navalFactor = 1000 + actor->modifiers[+0x1E0]                     ; modifier 60, MODIFIER_OFFMAP_NAVAL_INTEL
    atBase   = MILITARY_ESPIONAGE_AT_BASE_CHANCE
    ... then a walk of the target's list at +0xBAC ...

The modifier offsets are `id * 8`, so `+0x1D8` is 59 and `+0x1E0` is 60 - the trap that says
a modifier offset is not `id * 4`. The walk over `+0xBAC` was not read.

### Missions 5 and 7 are modifiers, and they are applied from the modifier rebuild

**`0x530340 / 0x130340`**, `0x530340` to the `ret 0x18` at `0x5305A5`. Six dwords of
arguments: the presence, a modifier accumulator, and the two tags by value. For mission 5
it builds a `CStaticModifier` **in the presence's own `+0x54`** from the template
`[0x1A86208] + 0x98`, then adds its values into the accumulator's `+0x18` array and appends
the object to the accumulator's vector at `+0x8`. For mission 7 it does the same into
`+0x9C` from the template `[0x1A86208] + 0x9C`. The two values it puts in are the
presence's `level` and its `mission_share[5]` (respectively `mission_share[7]`), through
`0x45A080`.

**The templates are named in the image.** `0x45B520`-`0x45B660` registers four modifier
definitions and stores each in the registry at `[0x1A86208]`:

| slot | name | |
| --- | --- | --- |
| `+0x98` | `spy_lower_national_unity` | id `0x3A` at registration |
| `+0x9C` | `spy_raise_national_unity` | `0x3B` |
| `+0xA0` | `spy_lower_neutrality` | `0x3C` |
| `+0xA4` | `spy_support_resistance` | `0x3D` |

So mission 5 is the `spy_lower_national_unity` modifier and mission 7 is
`spy_raise_national_unity`. **`spy_lower_neutrality` and `spy_support_resistance` are
registered and no mission uses them** - nothing in `0x530340` or `0x5300A0` reaches `+0xA0`
or `+0xA4`, and they are not in the nine.

**Its one caller is `0x4DEE93`, inside `0x4DDD80 / 0xDDD80`** - the function
`FINDINGS-production.md` lists as "called with the country after anything in the queue
completes and at the end of the espionage distribute. Not read." Part of it is now read:

```
for (i = 0; i < countryCount; ++i) {
    other = gamestate->countries[i]
    if (other->ownedProvinces (+0xCF8) <= 0) continue
    presence = other->espionage + me->tagId * 0xF8      ; THEIR spies in ME
    if (presence->level <= 0) continue
    0x530340(presence, accumulator, other->tag, me->tag)
}
```

so `0x4DDD80` is the country's static-modifier rebuild, and **the national unity a spy
mission moves is a modifier the rebuild re-derives from every foreign presence, not a
number anybody adds to daily.** That is why `CDistributeEspionage::Distribute` calls
`0x4DDD80` after each spy it places (`0x51F11D`) - a new spy changes the modifier at once.

## Detection, and `spiescaught`

**`0x52E3A0 / 0x12E3A0`**, `0x52E3A0` to the `ret 0xC` at `0x52EBDD`. `(CSpyPresence*,
CCountryTag* actor, CCountryTag* target)`.

**A fresh instance of the abutting-function trap.** `0x52EBE0` - the tech mission - starts
immediately after that `ret` with **no `int3` between them**: a fresh `push ebp; mov ebp,
esp` and its own SEH handler push `0xC8B2B4`. `image.functionStart(0x52EC11)` answers
`0x52EBE0` correctly, but a padding-based scan for the *end* of `0x52E3A0` runs 4.4 KB past
it into `0x52FD32`. That is the seventh pair this folder has found; the known list should
gain `0x52E3A0`/`0x52EBE0`.

The chance, all in thousandths:

```
base = SPY_DETECTION_CHANCE                                  ; country +0x20
if (actor == target) base += actor->modifiers[+0x1B8]         ; modifier 55, MODIFIER_COUNTER_ESPIONAGE
p   = actorCountry->espionage[target->id]                     ; the same record
c   = p->level * base / 1000
c   = c * p->mission_share[0] / 1000
if (actor == target)                                          ; the home-defence arm
    c = c * (1000 - 800 * (1000 - p->mission_share[0]) / 1000) / 1000
```

where **800** is `floorf(800.5f)` off the float at `0x160AADC` - the same
`floorf(N.5f)`-into-a-global shape as `Define10` and `Define50` in `CLASSES.md`, except
that here the float is inline and the value is used once. So a country that puts *all* its
home spies on counter-espionage gets the full chance and one that puts none there keeps a
fifth of it.

Then, per foreign country `other` (skipping the actor itself and anything with no
provinces):

```
q = other->espionage[target->id]                              ; THEIR spies in the target
if (q->level < 1000) continue                                 ; fewer than one whole spy
chance = c
if (actorCountry->0x4EF7C0(other->tag, 1)) {                   ; an ally, by the look of it
    if (target != actor) continue
    if (!IsHostileMission(q)) continue
    chance += 1000000                                          ; certainty
}
chance = chance * (1000 - targetCountry->modifiers[+0x150]) / 1000     ; modifier 42, MODIFIER_ESPIONAGE_BONUS
if (none of q->missions[0..8] is > 0)
    chance = chance * NO_MISSION_SPY_DETECTION_MULTIPLIER / 1000       ; country +0x3C
if ((MT19937() % 1000) >= chance) continue                     ; 0xAA2FD0
if ((MT19937() % 100) >= 10)      continue                     ; 0xAA2F80, a flat 1-in-10
q->level -= 1000 ; floor 0 ; cap MAX_SPY_LEVEL
if (target == actor) actorCountry->spiescaught (+0x11D4)++
if (player == actor) ... raise the message ...
```

**That increment at `0x52E779`/`0x52E780` is the only writer of `+0x11D4` that is not a
reset.** A displacement-exact sweep finds nine sites on a country: the constructor's zero
(`0x4C9B6D`), `CCountry::LoadKey` (`0x4CE5F1`), `CCountry::SaveContents` (`0x4D08A4`),
`0x4D2BA7`, the monthly reset in `CCountry::UpdateMonthly` (`0x4DC8D3`), this
read-increment-write pair, and two reads in the espionage view (`0x6202DF`, `0x62849E`).

**So `spiescaught` has no gameplay consequence at all.** Nothing reads it but the save
writer and the two UI sites, and the UI strings beside them are
`value_spies_caught` / `ESP_SPIES_CAUGHT` and `foreign_spy_actions_indicator` /
`DETECTED_SPY_ACTIONS`. It is a counter for the player's espionage screen, reset every
month, and a mod cannot make anything hang off it without new code.

**Two surprises, both read twice.**

- **`MODIFIER_ESPIONAGE_BONUS` is read off the *target*, and it *lowers* the chance.** In
  the home-defence arm the target is the catcher itself, so a country's own
  `espionage_bonus` makes it worse at catching spies in its own territory. The instruction
  is `mov ecx, [eax + 0x150]` with `eax = [ebp-0x2C]`, and `[ebp-0x2C]` is set at
  `0x52E3D3`-`0x52E3D8` from the third argument. Reported, not explained.
- **`IsHostileMission` gates the ally case the other way round from what the shape
  suggests.** `CSpyPresence::IsHostileMission` (`0x52E340 / 0x12E340`, presence in **EAX**,
  bare `ret`) answers 1 when any of missions 1, 2, 4, 5, 6 or 8 is set - so
  `COUNTER_ESPIONAGE`, `BOOST_RULING_PARTY` and `RAISE_NATIONAL_UNITY` are the three
  benign ones, and for mission 0 it additionally asks whether the record's target is allied
  with its owner. An ally's benign spies are skipped entirely; an ally's hostile spies get
  `+1000000` on the chance, which the `% 1000` roll cannot beat.

### The rolls are the MT19937 at rva `0x1310F80`, and they are not signed

Both helpers end in `0xAA2B90` with `eax = 0x1710F80`, which is rva `0x1310F80` - the
generator state the rest of the folder already names.

| | |
| --- | --- |
| `0xAA2FD0 / 0x6A2FD0` | out pointer in **ESI**, returns it. `*out = ((r % 1000) * 1000) * 1000 / 1000000`, which is `r % 1000` - a random fraction in thousandths |
| `0xAA2F80 / 0x6A2F80` | returns the raw draw in eax |
| `0xAA2B90 / 0x6A2B90` | the tempering: `y ^= y>>11; y ^= (y<<7)&0x9D2C5680; y ^= (y<<15)&0xEFC60000; y ^= y>>18`, state in **EAX**, index at `+0x9C0`, reload through `0xAA2C80` |

**The shifts are `sar`, not `shr`** - an arithmetic right shift where MT19937 specifies a
logical one - so this is not a canonical MT19937. It matters for one reason and only one:
the **last** step is `mov eax, ecx; sar eax, 0x12; xor eax, ecx`, and the top bit of an
arithmetic shift of `ecx` equals the top bit of `ecx`, so the xor clears it. **Every draw
is therefore in `[0, 2^31)` and non-negative**, which is why the `cdq; idiv 100` in the
second gate and in the tech mission is safe. A first reading here had it the other way
round and would have reported a 55% catch rate; the sign is worth checking before anyone
writes a formula from an `idiv` in this image.

## The espionage leadership slider

**`CDistributeEspionage::Distribute`, `0x51ED00 / 0x11ED00`**, slot 0, the shape
`FINDINGS-production.md` fixes for all ten siblings. Three phases.

**1. The pool.** In fixed 15 (32768 is 1), with `available` the slider's allocation:

    x = basePercentage(+0x8) * factor(+0x10) * available * 1000
    country->spy_pool (+0x1170) += (x >> 15) * LEADERSHIP_TO_SPIES / 1000

`LEADERSHIP_TO_SPIES` is `economy +0x24`, read at `0x51ED9C`; `MAX_NUMBER_OF_SPIES` is
`country +0x1C`, read at `0x51ED2E` and divided by 1000 straight away, so it is a **count of
spies**, not thousandths. `+0x1170` is the field the save writes as `spies`.

**2. Count the priority bands.** For every country whose presence is not already at
`maxSpies`:

    band = presence->priority
    if (presence->level >= (int)(maxSpies * 0.7 + 0.01) * 1000) band--
    clamp band to [0, 3]
    buckets[band]++

The 0.7 and the 0.01 are the doubles at `0x160A600` and `0x160A5F8`. So **a presence that
has already reached 70% of `MAX_NUMBER_OF_SPIES` drops a priority band**, which is how the
game stops one target soaking up everything.

**3. Spend, highest band first.**

```
for (band = 3; band > 0; --band) {
    if (spy_pool / 1000 < 1) break
    if (buckets[band] == 0) continue
    perTarget = max(1, (spy_pool / 1000) / buckets[band])
    for (i = *cursor; i < countryCount; ++i) {
        ... recompute band for presence i, skip unless it equals this band ...
        if (presence->level >= maxSpies * 1000) continue
        if (spy_pool / 1000 < 1) break
        give = min(maxSpies - presence->level / 1000, perTarget)
        if (give <= 0) continue
        *cursor = i + 1
        presence->level += give * 1000    (floor 0, cap MAX_SPY_LEVEL)
        spy_pool -= give * 1000
        0x4DDD80(country)                 // rebuild the static modifiers
    }
    if (nothing was placed or *cursor >= countryCount) *cursor = 1
}
out = 0
```

Two things this settles.

- **Priority band 0 never receives a spy.** The loop is `while (band > 0)`
  (`test esi, esi; jg` at `0x51F15E`), so 0 means "none here" and the usable bands are 1, 2
  and 3.
- **The class carries a round-robin cursor per band.** `edi` starts at `this + 0x34` and
  drops by 4 each band, so `+0x34`, `+0x30` and `+0x2C` are the three cursors and `+0x28`
  is untouched by this body. `CDistributeEspionage` is therefore at least `0x38` bytes,
  against `CDistributeProduction`'s `0x30`. The cursor is why the slider does not always
  favour the first country in the list.

`Distribute` returns zero, like production's.

## The two intel fan-outs: province fog of war, not spies

`ClearIntelFunctor` and `UpdateIntelFunctor` have nothing to do with `CSpyPresence`.
Both are launched from **one** function.

**`0x688D40 / 0x288D40`** takes a `CCurrentGameState*`. `FINDINGS-aisched.md` has its
callers right - six, of which `0x683056` is the **last call in `RunDailyPass`** - and got
one thing wrong that is worth correcting: it reports `0x689278`, the `UpdateIntel`
launcher's call site, without saying where it is, and `image.functionStart(0x689278)`
answers `0x689201`, which is not a function at all (`add dword ptr [ebp - 0x18], 0xC`).
**Both launchers are called from inside `0x688D40`**, `0x688DD8` and `0x689278`, with a
serial country loop between them.

    esi   = (state->+0xB90 - state->+0xB8C) / 4          ; the PROVINCE count
    _alloca(esi * 12)                                    ; 0x688D7D, a 12-byte-per-province scratch
    grain = max(1, esi / ([0x170ABB0] == 1 ? 1 : 32))
    range = { end = esi, begin = 0, grain }              ; ECX
    0x68E510(range, 0x6880B0())                          ; ClearIntel
    ... a serial loop over the countries, gated on [c+0x44] and [c+0xD60] ...
    grain = max(1, provinceCount / ([0x170ABB0] == 1 ? 1 : 32))
    0x68E5E0(range, 0x6882D0(&state->countries, &state->provinces))   ; UpdateIntel

So **both iterate provinces, not countries**, and both take the same grain: a
**thirty-second** of the province count, where the AI fan-out takes a sixteenth. Both save
`[0x1A857BF]`, set it to 1 and restore it, the same as the other fan-outs.

**What `ClearIntel` does per element** - `0x68F170`'s serial body is `0x688170 / 0x288170`,
range in **EAX**, functor at `[ebp+8]`:

```
for (i = begin; i != end; ++i) {
    prov = functor->provinces[i]
    memset(prov->+0x370, [0x170AD30] ? 0 : 9, prov->+0x374)
    h = prov->+0xD4
    h->+0x278 = 0
    h->+0x13C = 1
    scratch[i].byte8 = (h->+0x13D && h->+0x22) ? 1 : 0
    if (that byte) ... prov->+0x334 (the owner tag) and the country database ...
}
```

`+0x370` / `+0x374` is the per-country intel array and its length, which
`FINDINGS-mapmode.md` already names, and 9 is the level that file records for a country's
own provinces. So **`ClearIntel` wipes the whole fog-of-war table to "everybody sees
everything" when `[0x170AD30]` (rva `0x130AD30`) is zero and to "nobody sees anything" when
it is set** - that global is the fog-of-war switch, and `0x689280` tests it again right
after the second fan-out. What `prov + 0xD4` is was not established.

**`UpdateIntel`'s per-element body** is `0x6883B0 / 0x2883B0`, range in **ECX**, functor at
`[ebp+8]`. It also indexes `functor->provinces[i]`, gates on `prov->+0xD4->+0x13D`, reads
the province's owner (`+0x334`) and controller (`+0x338`), compares the controller against
`functor->+0x10`, and resolves tags to countries through `0x402610`. It is 2.4 KB long and
was **not read past `0x688480`**; what it writes back into `+0x370` is not established here.

**The thread, exactly.** `RunDailyPass` runs on the tick thread; `0x688D40` runs there;
the `start_for::execute` bodies - and therefore `0x688170` and `0x6883B0` - run wherever
TBB schedules them. `parallel_for` is `spawn_root_and_wait`, so the calling thread
participates too: **some elements run on the tick thread and the rest on workers, and which
is which is not decidable statically.** For a BiceLib hook that means the same constraint
`FINDINGS-aisched.md` states for `ProcessAI`: no main Lua state, no message, no ImGui
frame - and here also no assumption that the hook is *off* the tick thread either.

`[0x170ABB0]` (rva `0x130ABB0`) making the grain the whole range when it is 1 is the same
unresolved global `FINDINGS-aisched.md` flags; if it is 1 in a normal game these fan-outs
are a single chunk and effectively serial.

## Which defines feed espionage, and the three that feed nothing

Twenty-two entries of the `country` block (`CDefines + 0xCC`) are espionage or intel. The
readers below come from a displacement-exact sweep: find every `mov reg, [reg2 + 0xCC]` in
`.text` by locating the four-byte displacement and decoding backwards, then follow that
register - and any register it is copied into - forward 160 instructions, recording every
memory read through it. That finds inlined `GetDefines` as well as the call, which is
trap 8's blind spot; every reader listed was then checked in the disassembly, and the
false positives from unrelated `+0xCC` fields (`0x793A95`, `0x608A90`, `0x693E02`,
`0x7AA2CD`, `0x6C25BD`, `0x593DC7` among them) were dropped.

| offset | define | readers |
| --- | --- | --- |
| `+0x1C` | `MAX_NUMBER_OF_SPIES` | `0x51ED2E` slider, `0x62890A` espionage view |
| `+0x20` | `SPY_DETECTION_CHANCE` | `0x52E473` |
| **`+0x24`** | **`SPY_MISSION_CHANGE_DAYS`** | **none** |
| **`+0x28`** | **`SPY_CONNECTION_DETECTION_CHANCE`** | **none** |
| **`+0x2C`** | **`SPY_BASE_CONNECTION_DETECTION_CHANCE`** | **none** |
| `+0x30` | `SPY_UNIT_DETECTION_CHANCE` | `0x89F55A` |
| `+0x34` | `SPY_INTEL_MISSION_BONUS` | `0x624C55` espionage view, `0x89F503` |
| `+0x38` | `SPY_PARTY_ORGANIZATION_BOOST` | `0x530117`, `0x53018D` |
| `+0x3C` | `NO_MISSION_SPY_DETECTION_MULTIPLIER` | `0x52E700` |
| `+0x54` | `SPY_THREAT_INCREASE_ACTION` | `0x53020C` |
| `+0x74` | `COUP_CHANCE_PER_POSITION` | `0x4F7AE9`, `0x66A0C7`, `0x7D156B`, `0x80AC16` |
| `+0x7C` | `SPY_BASE_PRODUCTION_DETECTION_CHANCE` | `0x62BDD8`, `0x69EDB4`, `0x69EFAB`, `0x69F190` |
| `+0x80` | `SPY_COVERT_OPS_GAIN` | `0x530296` |
| `+0x84` | `SPY_COVERT_OPS_MAX` | `0x530318`, `0x4A35CE`, `0x80B2A1`, `0x80BCC8` |
| `+0x88` | `COUP_COVERT_OPS_COST` | `0x4F7D42`, `0x4F7F53`, `0x61F6E5` |
| `+0x94` | `TECH_ESPIONAGE_BASE_CHANCE` | `0x52EC11` |
| `+0x98` | `TECH_ESPIONAGE_TECH_PICK_FACTOR` | `0x52EEED` |
| `+0x9C` | `SPY_MILITARY_INTEL_TIME_BASE` | `0x52FD68` |
| `+0xA0` | `MILITARY_ESPIONAGE_DETECTION_CHANCE` | `0x52FD8D` |
| `+0xA4` | `MILITARY_ESPIONAGE_AT_BASE_CHANCE` | `0x52FE0C` |
| `+0xA8` | `SPY_MILITARY_INTEL_LOCAL_TIME_BASE` | `0x9BE41E` |

Plus `LEADERSHIP_TO_SPIES` (`economy +0x24`), whose two readers `FINDINGS-production.md`
already has.

**The three dead ones are worth the mod's attention.** `SPY_MISSION_CHANGE_DAYS` is
particularly striking: `CSpyPresence +0x50` records the tick the mission last changed, the
save carries it as `spy_date` and Lua exposes it as `GetLastMissionChangeDate`, but the
define that would make it mean anything is read by nothing, so **there is no cooldown on
changing a spy mission**. The two connection-detection defines are read by nothing either;
`SPY_BASE_PRODUCTION_DETECTION_CHANCE`, which sits beside them in `defines.lua` and looks
like a sibling, *is* read, four times.

The blind spot in the method: a reader that stashes the block pointer in a stack slot and
reloads it more than 160 instructions later, or that indexes the block through a computed
offset, would be missed. Neither shape appears in any of the readers that were found.

## Corrections to the existing record

- **`FINDINGS-aisched.md` leaves `0x689278`'s container unattributed** and
  `image.functionStart` answers `0x689201`, which is not a function. Both intel launchers
  are called from inside `0x688D40`.
- **`FINDINGS-aisched.md` says the intel fan-outs' period and iteration are unknown.** They
  iterate the **province** vector, the grain is a thirty-second of it, and the daily call is
  `RunDailyPass`'s last (which that file does say for `ClearIntel`).
- **`FINDINGS-production.md` lists `0x4DDD80` as "not read".** Its espionage arm is now
  read: it walks every foreign country's presence in this one and applies the two national
  unity modifiers through `0x530340`. The rest of it is still unread.
- **`CLASSES.md` describes `CCountry +0x1160` as "`0xF8` an entry, one per country: `+4` is
  the priority the `spy_priority` key sets, `+0xF4` the covert ops points".** That is
  right as far as it goes; it is now a full layout. **`+0x1164` is the vector's `end`, and
  `+0x1168` its capacity** - the entry calls `+0x1164` `_end`, which is correct.
- **Add `0x52E3A0`/`0x52EBE0` to the abutting-function list** in `image.py`'s docstring and
  in `CLASSES.md`.

## What is not established

- **Everything live.** The game was not running. No presence was read out of memory, no
  save was fitted against these offsets, and no spy was watched being caught.
- **`CSpyPresence +0x54` and `+0x9C` are `CStaticModifier` by value, and that is all.** The
  class's own 14 slots were not read and neither was `0x4593F0`, its constructor, beyond
  the vftable write and the empty string it leaves.
- **`CCountry +0x10C4` and `+0x10D4`**, which the two party-boost missions write. The
  define is `SPY_PARTY_ORGANIZATION_BOOST` and the index is an ideology's `+0x4C`, so
  "party organisation per ideology" is the obvious reading and is recorded here as a
  reading, not a finding. `+0x10D4`'s stride-16 indirection is not explained at all.
- **`0x4EF7C0`**, the two-argument predicate on a country that decides the ally case, and
  `0x42F100`, `0x4F4E80` (the threat pair), `0x540D60` (the tech steal) and `0x44C5C0` (the
  tick-to-days helper). All named as callees only.
- **The bodies of `0x52EBE0` past `0x52EC60` and `0x52FD40` past `0x52FE28`** - what tech
  is actually stolen, and what the military-intel walk over the target's `+0xBAC` does.
  Only their chances were read.
- **`UpdateIntelFunctor`'s per-element body past `0x688480`.** What it writes into a
  province's intel array is not read, so "UpdateIntel recomputes what ClearIntel wiped" is
  inference from the pairing and the names.
- **`prov + 0xD4`**, which `ClearIntel` and `UpdateIntel` both dereference, and the
  12-byte-per-province scratch array `0x688D40` allocates for them.
- **`[0x170AD30]` being the fog-of-war switch** is inference from what `ClearIntel` fills
  with (9 when clear, 0 when set) and from `0x689280` testing it again after
  `UpdateIntel`. Nothing names it.
- **The two messages `CDistributeEspionage::Distribute` raises.** The brief says two; the
  arithmetic above is what was read, and the message text was not chased.
- **`CDistributeEspionage +0x28`.** Three of the four dwords at `+0x28`..`+0x34` are the
  band cursors; `+0x28` would be band 0's and the loop never reaches it, so whether it is
  that or something else is open.
- **Which of the five non-tick callers of `0x688D40`** matter, so "intel is rebuilt daily"
  remains a floor, exactly as `FINDINGS-aisched.md` says.
- **`spy_lower_neutrality` and `spy_support_resistance`**, the two registered modifier
  definitions no spy mission uses. Something else may build them; nothing in the espionage
  path does.

---

# The espionage wave, 2026-10-14

Sections A to E were read in one wave for OpenHOI3 (`WAVE.md`, "the espionage wave"), on the ground the
reading above laid. Each says where it corrects that reading.

## A. Placing spies

*Read 2026-10-14 off the listing, with the game not running. Addresses are virtual, with the rva beside named
ones. The saves are the maintainer's in `Documents\Paradox Interactive\Hearts of Iron III\save games`.*

**In one line.** A country's free spies (`spies` in a save) are bought every day by the espionage share of
leadership. The same daily call then hands them out, a whole spy at a time, to its presences in priority bands 3,
2 and 1. A presence never loses spies except to a catch, a coup or an annexation. A command only ever changes a
priority.

**Corrected here:** `CDistributeEspionage::Distribute` raises **no message** - the "two messages" were the two
lazy constructions of `g_CCurrentGameState`; `0x4DDD80` runs on the **target**, once per spy placed, not once at
the end; the band cursor does not wrap within a day (below); and `CSpyPresence.missions[]` are **priorities**
(weights, 0..3), not numbers of spies.

### A.1 The two commands

Both are `CCommand`s with the actor's tag at `+0x3C/+0x40` and the target's at `+0x44/+0x48`. The target is the
actor itself for the home presence. Neither has validation of its own: slot 14 is the folded
`CountryPairCommand_IsValid` (both ids non-zero), and both `Execute`s run on every peer.

**`CChangeSpyPriority`** (0x50 bytes; vftable 0x15C4174; type id 0x6E1, the save token `spy_priority`). Keys:
`actor`, `target`, `priority` (`+0x4C`).

- `Execute` (`0x5589A0 / 0x1589A0`) is one store: `actor->espionage[targetId].priority = cmd->priority`. There is
  no range check.
- Its posters: the espionage view's six priority buttons - `own_priority` up and down, `target_priority` up and
  down, and the country list's `priority` up and down - each cycling its button frame so the posted priority goes
  round 0, 1, 2, 3, 0; and Lua's `CChangeSpyPriority(actor, target, priority)`, which passes the integer through
  untouched. The AI posts at most `CSpyPresence.MAX_SPY_PRIORITY`, which is 3.
- A change counts from the actor's next daily distribution.

**`CChangeSpyMission`** (0x54 bytes; vftable 0x15C41B4; type id 0x6E3, `spy_mission`). Keys: `actor`, `target`,
`id` (the mission, `+0x4C`), `priority` (`+0x50`).

```
Execute (0x558EB0 / 0x158EB0):
    presence = actor->espionage[targetId]
    if (mission < 9) presence.SetMissionAllocation(mission, priority)   ; signed test
    presence.last_mission_change = gamestate->tick (+0xBDC)
```

The value is **the mission's priority**, a weight: the screen's mission rows cycle it 0..3, and the AI gives 1, 2
or 3. The tick is written every time, even when the mission is out of range or the priority is unchanged. The
test is signed (`jge`), so a negative mission would write before the array (-1 into `priority`, -2 into `level`);
nothing posts one.

**There is no rule on which mission may go where.** `CSpyPresence::MissionAllowed` (`0x5305B0 / 0x1305B0`) is a
Lua-only function: counter-espionage (0) and boost ruling party (3) are allowed anywhere; raise national unity (7)
only at home; military, tech, boost our party, lower national unity, increase threat and covert ops (1, 2, 4, 5, 6,
8) only abroad. Nothing in the C++ calls it, and neither Their Finest Hour's AI script nor the base game's does. A
mission posted against that table is stored and runs.

**Mission shares.** `mission_share[k] = missions[k] * 1000 / sum`, truncated, all zero when the sum is zero,
recomputed by `SetMissionAllocation` (`0x52D4D0`) whenever any priority changes and on load - as the first reading
said, now confirmed on the listing. Priorities 1, 1, 1 give 333 each, summing to 999.

**The primary mission** (`CSpyPresence::GetPrimaryMission`, `0x52D6D0`, Lua only) is the mission with the highest
priority, the lowest index winning a tie, or 9 (`SPYMISSION_MAX`, none) when every priority is 0.

### A.2 The daily distribution: `CDistributeEspionage::Distribute`, `0x51ED00 / 0x11ED00`

It runs once a game day for each country with a tag but REB, from `RunCountryDailyPass`'s leadership loop - before
the same country's `DailyEspionagePass`. Countries run in database order.

```
maxSpies = MAX_NUMBER_OF_SPIES / 1000                    ; TFH 10 (a count)
L        = thousandths(((base_percentage * available) >> 15 * factor) >> 15)
spy_pool += L * LEADERSHIP_TO_SPIES / 1000               ; TFH 0.15 (base 0.05); no ceiling

; count the bands - every country i >= 1, no province test
for i in 1 .. countryCount-1:
    p = espionage[countries[i].id]
    if p.level >= maxSpies*1000: continue
    band = p.priority - (p.level >= (int)(maxSpies*0.7 + 0.01)*1000 ? 1 : 0)   ; 7000 in TFH
    buckets[clamp(band, 0, 3)]++

for band in 3, 2, 1:                                     ; band 0 never receives
    if spy_pool/1000 < 1 or buckets[band] == 0: continue
    perTarget = max(1, (spy_pool/1000) / buckets[band])
    placed = false
    for i in cursor[band] .. countryCount-1:             ; empty if cursor >= count
        if countries[i] owns no province: continue
        p = espionage[countries[i].id]
        if band(p) != band or p.level >= maxSpies*1000: continue
        if spy_pool/1000 < 1: break
        give = min(maxSpies - p.level/1000, perTarget)
        if give <= 0: continue
        cursor[band] = i + 1;  placed = true
        p.level = clamp(p.level + give*1000, 0, 10000)
        spy_pool -= give*1000
        RebuildStaticModifiers(countries[i])             ; the TARGET's modifier
    if not placed or cursor[band] >= countryCount: cursor[band] = 1
```

The 0.7 and the 0.01 are doubles compiled into the image, not defines. `MAX_SPY_LEVEL` is not a define either: it
is `g_MaxSpyLevel`, 10000, which nothing writes. The three cursors live at `+0x2C`, `+0x30` and `+0x34` (bands 1,
2, 3); `+0x28` is a fourth, set to 1 like the others by `CCountry::CCountry` (`0x4C9F93`) and never used. None of
them is saved. `CDistributeEspionage` is 0x38 bytes (`push 0x38; call new` at 0x4C9F5E).

What this means in play: a priority-1 presence stops at 7 spies, because at 7 it drops to band 0, while priorities 2
and 3 go on to 10; a presence at priority 0 never gains a spy from the slider; and a country's only eligible
presence gets a spy every second day at most, because the day after a placement the scan starts past it.

### A.3 What else writes a presence's level, and what does not

A sweep of every `[reg+0x1160]` in `.text` found 87 sites, each followed for stores. Every writer of `level`: the
constructor and `CSpyPresence::Reset` (`0x52D750`; 0); `SetUpCountryForNewGame`'s first allocation; the loader,
through `SetLevel` (the loader's alone); `Distribute`; a catch (-1000, `CatchSpies`); a coup attempt (0,
`PerformCoup`, for the instigator's presence); an annexation (0, for every presence in the annexed country); and
`modify_spies` (inline add, clamped). **Nothing decays a presence.** `spy_pool` is written only by the
constructor, the loader, `CCountry_Reset` and `Distribute`.

### A.4 What a new game's presences hold

- **No history file sets a spy key.** A grep of `history/countries`, `tfh/history`, `common/countries` and
  `tfh/common` for "spy" found only a minister surname, "Spychalski" - the positive control.
- **Every country's own presence starts at priority 1 with counter-espionage priority 1**
  (`InitCountryPerCountryArrays`, `CCountry_Reset`). The start save has priority 1 at the own index, and nowhere
  else, for all 101 countries.
- **Levels come from `SetUpCountryForNewGame`'s score** (already recorded), and then two days of distribution. The
  start save's home levels: 2 for 70 countries (4 halved, not major); 0 for the 23 that hold no land, REB among
  them; 5 for the seven majors and 3 for China. Those eight are exactly the countries whose daily gain reaches half
  a spy: 4 + 1 and 2 + 1, the extra spy the second day's distribution's. Every country at 2 has a pool under 1
  (the largest is 0.700). This closes the open question `SetUpCountryForNewGame`'s record left - "the self entries
  are 1 higher for the seven majors".
- **Germany, Britain and the United States** keep 1.226, 1.208 and 1.578 free spies with one spy placed. Their
  gains (1.113, 1.104, 1.289 a day) would have placed a second spy on day two had the band-1 cursor not been past
  them: the cursor rule, seen in a save.

### A.5 Against the saves

| prediction | save | result |
| --- | --- | --- |
| Pool grows by share x leadership x 0.15 a day, less whole spies placed | GER, 1 Jan -> 4 Jan 12h | 1.226 + 3 x 1.113 - 2 = **2.565**; home 5 -> 7 (perTarget 2 on 2 Jan) |
| A priority-1 home at 7 gets nothing more | GER, 4 Jan -> 7 Jan 14h -> 8 Jan 7h | +3.339, +1.113, no placement |
| The pool has no ceiling | GER, 1 Apr -> 20 Apr at a 0.03 share | 11.196 + 19 x 0.133 = **13.723** |
| Priority 0 never grows; priority 1 never above 7 | all saves | no priority-0 rise within one game; maxima: priority 1 at 7, priority 2 at 7, priority 3 at 10 |
| Mission priorities are 0..3 | all saves | values 0..3 only |
| `spy_date` = the tick of the last mission command | April saves | each AI country's stamps fall at one fixed hour (France 9, Sweden 18, Hungary 5, the USSR 6) |

Not every country is checkable: most AI countries set their espionage share to 0 within days
(0.60999/0/0/0.39001), so their pools are flat until the AI moves the slider back - the AI's slider is section E's.

### A.6 What looks wrong but is what the bytes do

- **The cursor does not wrap.** A band can sit out a whole day with spies in the pool.
- **The band count has no province test.** A presence with a priority in a country that does not exist dilutes
  everyone's `perTarget`.
- **The pool is charged the full `give` even when the 10-spy cap cut it.** Unreachable with
  `MAX_NUMBER_OF_SPIES = 10`; a mod that raises the define above 10 would lose spies every day into presences stuck
  at 10. BlackICE keeps 10.
- **Priority 1 caps at 7 spies**: the 70% rule makes it band 0.
- **Neither command checks anything.** `MissionAllowed` exists and nobody calls it.
- **`CChangeSpyMission` stamps `spy_date` even when nothing changed**, and its mission test is signed.
- **`SPY_MISSION_CHANGE_DAYS` (7) is still read by nothing.** The base game's own AI script used `spy_date` for a
  60-day hold; Their Finest Hour's script replaced that file and does not.

### A.7 What was not settled

- The 9 October game's saves (4-8 January) differ from the 7 October start save in **27 presences at priority 0,
  each one higher**. No writer can raise a priority-0 presence after the new game is set up, so these are two
  different new games whose setups differ; why the deterministic score (Lua `AI_GenerateNonHistoricalRelation`
  plus the recorded terms) came out differently was not found. The growth comparisons above were run within one
  game, or on the home presence and the pool, which this does not affect.
- The rest of `InitCountryPerCountryArrays` and `CCountry_Reset` (both stay `inferred`).

**Frontier (rvas):** `0xE21E0` - the stretch at 0x4E3208 that builds `CCountry +0x102C` from presences with a
level above 0, very likely the list behind Lua's `GetSpyingOnUs`, not certainly inside `RebuildNeighbours`; the
covert-ops spenders of `+0xF4` - `0x44C60` (beside `CCovertOpsMission::LoadKey`), `0x1594D0` (beside
`CSendCovertOpsMission`), `0x2E2230` and `0x2E638A` (the province view); `0xC8400`, `GetMissionPriority`, a
one-line Lua getter not recorded.

## B. What a mission does

*Read 2026-10-14 on the listing, the game not running. Addresses are virtual, with rvas beside named functions. L is
a presence's `level` (spies x 1000) and S[k] its `mission_share[k]` (thousandths). Unless a line says otherwise,
every product is a 64-bit multiply and every "/1000" truncates toward nought. Their Finest Hour's values of the
defines are in brackets.*

**Corrected here:** military intel runs on days **of the month**, not a rolling count of days (`0x44C5C0` is
`Date_DayOfMonth`); the covert-ops gain is **divided by thirty** (the define is monthly), which the first reading
missed; `0x540D60` is the technology database's constructor, not the steal; `modify_spies` does not call
`SetLevel`; six define readers in the table above are false positives (B.11); and the party boosts write nothing at
all when the result would go negative. Added beyond the wave's plan: `common/covert_ops.txt`'s province operations
(`CSendCovertOpsMission`), which also spend covert-ops points.

### B.1 The dispatcher, corrected

`CSpyPresence::RunDailyMissions` (`0x5300A0`, rva `0x1300A0`), read again whole:

- **Military intel's throttle is on the day of the month.** `0x44C5C0` is `Date_DayOfMonth`: tick minus the epoch,
  over 24, then minus the month lengths in the table at `0x1713294` (31, 28, 31 ...), 0-based. So mission 1 runs on
  the days d of the month where `(d + targetId) mod 8 = 0` - three or four times a month, the pattern restarting each
  month; not an even one day in eight.
- **The covert-ops gain is divided by thirty.** After `x = L x SPY_COVERT_OPS_GAIN / 1000 x S[8] / 1000` the code
  takes `x x 1000 / 30000` - 32-bit when -1607028 < x < 2147483 (magic `0x45E7B273`, `sar 0xd`), 64-bit otherwise,
  the same result - and only then adds to `covert_ops_points` (`+0xF4`). The define's own comment, "monthly gain per
  spy", agrees. Above `SPY_COVERT_OPS_MAX` the field is stored down to it.
- **A country's own record runs every mission too.** `CCountry::DailyEspionagePass`'s loop (`0x4FFE30`..`0x4FFE82`)
  tests only the target's provinces and the presence's level, never "is this me". The saves show home records with
  spies: on 20 April Germany's record about Germany holds 7 spies with counter-espionage, Britain's runs
  counter-espionage and boost ruling party, the Soviet Union's counter-espionage and raise national unity. So spies
  at home run all their missions on the country itself, and **counter-espionage at home rolls twice a day** - once
  through the dispatcher, once from the pass's own direct call at `0x4FFEA8`.

None of the nine arms tests an alliance.

### B.2 Tech espionage (mission 2)

`CSpyPresence::RunTechEspionage`, `0x52EBE0` (rva `0x12EBE0`) to `0x52FD32`.

1. **First roll**: `percent = L x TECH_ESPIONAGE_BASE_CHANCE (2) / 1000 x S[2] / 1000 / 1000`; fail when
   `Random() % 100 > percent`, so the chance is (percent + 1) in 100. One spy entirely on tech gives 3 in 100; ten
   spies 21.
2. **Weights.** For every technology in `g_CTechnologyDataBase`'s vector (n of them, the null one included) the
   weight is 0 unless all three hold: its slot 9 is true (a real technology; `CNullTechnology` answers false); it is
   `stealable` (`+0x2BC`; every technology is unless its file says `stealable = no`, and no Their Finest Hour file
   does); and the target's level in it is above the actor's. Then `w = trunc(trunc(10000 / gap) / max(difficulty,
   1))`, gap in whole levels: small gaps and easy technologies weigh most.
3. **Second roll**: `D = floor(((float)n + 0.0005) x 1000) x 10000 / 1000` (n x 10000), `v = sum(w) x 1000 / D` (-1
   when D is 0) - the mean weight over **all** n technologies, as a fraction of 10000. Then `chance = v x
   TECH_ESPIONAGE_TECH_PICK_FACTOR (0.3) / 1000 x S[2] / 1000`, succeeding when `RandomThousandths() < chance`.
   Illustrative only: with about 287 technology blocks, a target one level ahead in 40 technologies of difficulty 4
   gives v about 34 and a chance about 10 in 1000 with all spies on tech - with ten spies about 0.2% a day.
4. **Pick**: `PickWeightedIndex(w, n, Random())` (`0xAB4790`): the first index whose running total of positive
   weights exceeds `draw % total`. Nothing happens when it answers 0 or less.
5. **The theft.** The actor's research progress in that technology is set to 0; the actor's level becomes **the
   target's level, however many levels that is**, and `CTechnologyStatus::ApplyTechnologyEffects(tech, actor, gap x
   1000)` applies the levels gained; the technology is unlinked from the actor's current research (`+0x638`).
   Nothing tests `max_level`, `allow` or prerequisites.
6. **Messages.** The actor's branch is tested first; the target's only when the actor is not the player.
   - **The actor is the player**: `WE_STEAL_TECH_ONCE` when the technology's `additional_offset` is 0, else
     `WE_STEAL_TECH_REPEAT`, tags (actor, target). Variables after the country's standard set: `LEVEL` the new level,
     `TYPE` the technology's name, `TARGET_ADJ` the target's adjective, `EFFECT` `CTechStatistics::BuildEffectsText`
     at the new level with its first `§W` turned to `§b`, or the localised `none` ("none") when empty.
     `WE_STEAL_TECH_ONCE`: header `$TYPE$`; title "$TARGET_ADJ$ Blueprints Stolen!"; body "$TITLE$, our spies have
     stolen plans for $TYPE$ which will give us the following benefits." then `$EFFECT$`; log "$TYPE$ aquired by
     spies." `WE_STEAL_TECH_REPEAT`: body "...stolen plans that let us improve our abilities in $TYPE$ to level
     $LEVEL$, giving the following benefit."; log "$TYPE$ increased to $LEVEL$ by stealing enemy plans".
   - **The target is the player**: the victim hears only when its **own** record's `level x S[0] / 1000` is above
     2000 - more than two spies on counter-espionage at home. Then `LEVEL` and `TYPE` are set and, above 5000,
     `TECH_STOLEN` with `RESPONSIBLE` the actor's name - "Our Blueprints Stolen!" / "$TITLE$, spies from
     $RESPONSIBLE$ have managed to escape with our technology", tags (target, actor); otherwise
     `TECH_STOLEN_BY_UNKNOWN` - "...unknown spies have managed to escape with our technology", tags (target,
     target). Both log "$TYPE$ aquired by enemy spies."
   - All four message types are `log=yes popup=yes` in Their Finest Hour.

### B.3 Military intel (mission 1)

`CSpyPresence::RunMilitaryEspionage`, `0x52FD40` (rva `0x12FD40`). `T = SPY_MILITARY_INTEL_TIME_BASE / 1000` (32);
`base = MILITARY_ESPIONAGE_DETECTION_CHANCE (0.6) x 10000 / 1000 x L / 1000 x S[1] / 1000`. The walk over the
target's `Units` list (`+0xBAC`) by kind:

- **land**: `c = (1000 + actor's OFFMAP_LAND_INTEL) x base / 1000`;
- **air**: `c = MILITARY_ESPIONAGE_AT_BASE_CHANCE (2) x base / 1000` when at its own base (`CUnit_IsAtOwnBase`,
  inlined), else `base` - **air never uses an offmap modifier**;
- **naval**: `c = (1000 + OFFMAP_NAVAL_INTEL) x base / 1000`, times the at-base factor again when at its own base;
- anything else: `base`.

Then `p = (int)((float)c / 1000.0)` through `fistp`, which **rounds**, and the unit is caught when an inlined
MT19937 draw `% 1000 < p` (the same generator and arithmetic-shift tempering as `0xAA2F80`). With all spies on
military, one spy gives a land unit 6 in 1000 a run, ten spies 60.

On success: `v = min(RandomThousandths() x (2000 x S[1] / 1000) / 1000, 1000)` - the 2000 is `floor(2000.5f)` from
`0x160A5F4` - and `level = v x 7 / 1000 + 2`, 2..9 (with every spy on military, half the successes give 9); then
`CUnit_GrantIntel(actor, 32, level, unit)`. `CUnit::UpdateDaily` takes one off the entry each call and drops it at
0; that this runs daily is the record's inference. **A later success overwrites the entry**, so a level 2 can
replace a level 9. No message, no detection.

### B.4 The two party boosts (missions 3 and 4)

`+0x10C4` is the values array of the organisation `CIdeologyData` at `CCountry +0x10BC`, and `+0x10D4` is its
tallies vector: each entry 16 bytes, its first dword pointing at the five tally slots, so `[[+0x10D4] + i x 16] +
0xC` is **tally slot 3**, the spies' slot of `FINDINGS-government.md` B.1.

- **Boost ruling party**: `x = L x SPY_PARTY_ORGANIZATION_BOOST (0.01) / 1000 x S[3] / 1000`, i the **target's**
  ruling party.
- **Boost our party**: the same with S[4], i the **actor's** ruling party. Both write into the **target's** figures.

`v = organisation[i] + x`. When v < 0 **nothing is written, to either** (the account above said only the tally was
spared). Otherwise `tally[i][3] += v` (the new figure, not the change) and `organisation[i] = v`. No cap at 100 (the
month's `NormaliseToHundred` restores the total) and no null test on either ruling party. One spy entirely on it adds
0.010 organisation a day; ten spies 0.100.

### B.5 Increase threat (mission 6)

`amount = L x SPY_THREAT_INCREASE_ACTION (0.07) / 1000 x S[6] / 1000 / 10`, `scale = 1000`. The code calls
`CCountry::GetActingCapitalLocation(target)` (`0x42F100`, a pure getter) and **throws the result away**, then
`SpreadThreatToAll(&amount, &scale, feared = target)` (`0x4F4E80`, rva `0xF4E80`, read in `FINDINGS-diplostate.md`).
So it is the threat **spread to everyone**, not over the map, and it is threat **from the target**: every other
country's threat toward the spied-on country rises - the base scaled by the target's `THREAT_IMPACT` and halved when
it is not in a faction, each share by reach and ideology and the receiver's `THREAT_RESISTANCE`, floored at a
twentieth of the base. One spy entirely on it gives a base of 0.007 a day, and truncation leaves most countries 0 to
0.003.

### B.6 Lower and raise national unity (missions 5 and 7)

`CSpyPresence::ApplyUnityModifiers` (`0x530340`) refills the presence's own embedded modifier from the
`spy_lower_national_unity` template (`national_unity = -0.1`) or the `spy_raise_national_unity` template (`+0.15`)
with `CModifier_CopyValues` (`0x45A020`), then scales every value with `CModifier_ScaleValues` (`0x45A080`), first by L
and then by S[5] or S[7]. So the modifier is `-0.1 x spies x share` or `+0.15 x spies x share`. It lasts as long as
the presence has spies and the mission is set: `CCountry::RebuildStaticModifiers` re-derives it from every country's
record about the rebuilt country, its own included, from countries that own provinces only - in
`RunCountryDailyPass` and after each spy the slider places. `modify_spies` triggers no rebuild. A `national_unity`
figure is **per month** (`FINDINGS-government.md` section C), and the month's `national_unity` modifiers together are
floored at -1.0: ten spies entirely on lowering reach that floor alone.

### B.7 Covert ops (mission 8), what spends the points, and the coup

**Gain**: B.1, `L x 0.5 / 1000 x S[8] / 1000 / 30` a day - one spy entirely on it 0.016 a day, ten 0.166, about 5 a
month - capped at 50. The points belong to one target: `CSpyPresence +0xF4`.

**Spender 1, the coup** (`FINDINGS-government.md` B.6, cited). The espionage view's update (`0x61F490`) enables
`attempt_coup_button` through the element's slot 46 and disables it through slot 47 - never hiding it (section D) - only
when all three hold: the player's record about the viewed country holds `level / 1000 > 0`, a whole spy - **this
settles `FINDINGS-government.md` B.8's open `[esp+0x58]`**, set at `0x61F531` from `[record] / 1000`;
`covert_ops_points >= COUP_COVERT_OPS_COST` (20), compared raw, so 20.000; and `CanAttemptCoup`. The chance is
`CoupChance`; the cost, in `PerformCoup`: the instigator's spies there go to 0 and the points lose 20, floored at 0.
The button posts `CPerformCoupCommand` through the callback `0x629A30`.

**Spender 2, covert operations in a province.** The executable loads `common/covert_ops.txt`: Their Finest Hour has
`sabotage_strategic_resource` (cost 10), `steal_battle_plans` (cost 10, `local_intel_boost = 60`), `scout_area` (15),
`sabotage_area` (15) and more. A `CCovertOpsMission` holds its key at `+0x8`, the `effect` block (a `CEffect` by
value) at `+0x28`, `is_valid` at `+0x48` and `is_selectable` at `+0x88` (both `CAndTrigger`s by value), and `cost`
at `+0xC8`, a whole number. The province view's `cov_ops_mission_entry` gates its `selectbutton` on
`CCovertOpsMission_CanSelect` (`0x444C60`): false when the province id is 0, false when the actor's points **about
the province's controller**, in whole points, are below the cost, else true when `is_selectable` is empty, else its
answer. Pressing it posts `CSendCovertOpsMission(player, province, mission)`; its `Execute` (`0x5594D0`) takes `cost
x 1000` off those points **with no floor and no re-check**, then runs the effect with FROM = the player and the
province as scope. No message. `IsValid` (`0x559990`) checks only that the three ids are non-zero; the type id is
`0x7F6`, `send_covert_ops_mission`.

### B.8 The ally test

`0x4EF7C0` is `CCountry::IsFriend` (the Lua name; the record had `IsFriendly`). `this->IsFriend(tag,
includeMilitaryAccess)` is true when, in order: the tag is this country; either is the other's overlord, or both share
one; they share a real faction; **the other country's** diplomacy status toward this one has an alliance (`+0x14`);
that status is co-belligerent (`+0x58`) and this country is not its enemy; or, only with the flag, **this country's**
status toward the other has military access (`+0x4C`). Of its 75 callers espionage calls it twice: **`CatchSpies`**,
with `true` - a friend's spies are never caught in a foreign target, and at home they are skipped unless
`IsHostileMission`, in which case `+1000000` makes the first roll certain and only the 1-in-10 gate stays - and
**`IsHostileMission`**, with `false`: counter-espionage inside a friend is benign. No mission's effect differs for an
ally.

### B.9 Every message

| type | raised when | told | variables | TFH flags |
| --- | --- | --- | --- | --- |
| `WE_STEAL_TECH_ONCE` / `_REPEAT` | tech steal, the actor is the player | actor | `LEVEL`, `TYPE`, `TARGET_ADJ`, `EFFECT` | log, popup |
| `TECH_STOLEN` | tech steal, the target is the player, its counter-espionage spies > 5 | target | `LEVEL`, `TYPE`, `RESPONSIBLE` | log, popup |
| `TECH_STOLEN_BY_UNKNOWN` | the same, counter-espionage spies > 2 and <= 5 | target | `LEVEL`, `TYPE` | log, popup |
| `SPIESFOUNDUS` | a catch, the catcher is the player | catcher | `WHERE` = the caught spies' owner | log=no, popup=no |
| `SPIESFOUNDTHEM` | a catch, the caught owner is the player | owner | `WHERE` = the target | log=no, popup=no |

`SPIESFOUNDUS`: header "$minister_of_security$ reports."; body "Hostile Spy Detected / A spy from $WHERE$ was
detected and neutralized in $COUNTRY$"; log "We detected a spy from $WHERE$ in $COUNTRY$." `SPIESFOUNDTHEM`: header
"$minister_of_intelligence$ reports."; body "Our Spy Detected / One of our spies in $WHERE$ was detected and
neutralised."; log "One of our spies in $WHERE$ was detected." Missions 1 and 3-8 and covert operations raise
nothing; the coup fires `on_coup_success` or `on_coup_fail` (`FINDINGS-onactions.md`).

### B.10 The script keywords

- **`spies = N`** (condition, `CSpyCountTrigger::Evaluate`, `FINDINGS-triggerleaves.md`): the scope country's level
  in THIS's country, or its own record, >= N, in thousandths.
- **`spy_mission_count = { type value }`** (condition, `CSpyMissionCountTrigger::Evaluate`): `level x share[type] /
  1000 >= value`; an unknown type is counter-espionage.
- **`has_hostile_spy_mission`** (condition, `0x6060C0`): `IsHostileMission` of the scope country's record about
  THIS, compared with the trigger's `+0x40` - which the constructor never sets, the keyword built on the block tail,
  so it compares against whatever the heap held. Unused.
- **`modify_spies`** (effect, `0x5BE130`, now confirmed): `level += count x 1000` on the scope country's record about
  the target, clamped 0..10000 inline. The count is never loaded, so the effect cannot be configured
  (`FINDINGS-script.md`).
- **`local_intel_boost = N`** is an **effect**, not a modifier (`CLocalIntelBoost::Execute`,
  `FINDINGS-effectrun.md`): level 8 for 15 on every unit within N of the province. `steal_battle_plans` in
  `covert_ops.txt` is its only Their Finest Hour user.
- **`spy_lower_neutrality`** (`neutrality_change = -0.003`) and **`spy_support_resistance`** (`partisan_efficiency =
  5`) are registered at the registry's `+0xA0`/`+0xA4`, and no reader was found - all 60 direct loads of
  `[0x1A86208]` and all 18 calls of `GetModifierDataBase` followed for 14 and 12 instructions; the same search finds
  `+0x98`/`+0x9C` in `0x530340` (the positive control).

### B.11 Corrections to the record and the sections above

- Mission 1's throttle: day of the month, not days. Mission 8: a thirtieth of the formula a day. Missions 3 and 4: a
  negative result writes neither the array nor the tally.
- `0x540D60` is `CTechnologyDataBase::CTechnologyDataBase`; the steal is `RunTechEspionage`'s own body.
- `SetLevel`'s only caller is `CCountry::LoadKey`; `modify_spies`, `CatchSpies` and the slider inline the clamp.
  `CUnit_GrantIntel` has two callers.
- **The define table's readers.** `0x4A35CE` (`or [eax+0x84],0x100`), `0x80B2A1` and `0x80BCC8` (`[esp+0xcc]`) are
  not `SPY_COVERT_OPS_MAX`; `0x66A0C7`, `0x7D156B` and `0x80AC16` (`movq xmm0,[eax+0x74]` after `0x45FF30`) are not
  `COUP_CHANCE_PER_POSITION`. Each was read in place. Of the listed readers only `0x530318` and `0x4F7AE9` are real;
  no new sweep was run for others.

### B.12 What the saves predict

No country in the 1 January or 20 April saves has a covert-ops mission set, and `covert_ops_points` is 0 for all 101
countries in both. Home records hold spies, matching B.1. Nothing else a mission does is kept in a save: the tallies,
the unit intel and the modifiers are not saved.

### B.13 What looks wrong but is what the bytes do

- A country's own record runs every mission, so counter-espionage at home rolls twice a day, and home spies on
  increase threat raise everyone's threat from the country itself.
- A tech steal takes the target's full level in one go and resets the actor's progress in that technology.
- The second tech roll averages over every technology in the database, so a large tree makes steals rarer.
- Military intel's result is rounded, not truncated; air units ignore the offmap modifiers; a later low roll
  overwrites a higher intel level.
- `GetActingCapitalLocation`'s result is thrown away in mission 6.
- `SPIESFOUNDUS` says the spy was caught "in $COUNTRY$" (the player's own country) even when caught abroad; both
  spies-found types are hidden by default in Their Finest Hour.
- `CSendCovertOpsMission::Execute` can push the points below nought; the coup floors them, covert operations do not.
- `has_hostile_spy_mission` compares against an uninitialised byte.
- `spy_lower_neutrality` and `spy_support_resistance` are defined and registered, and no reader was found.

### B.14 What was not settled

- Whether `CUnit::UpdateDaily` really runs daily (the record's inference); the 32 is counted in its calls.
- That `+0xB8`/`+0xBC` on the coup button are show and hide (section D).
- Who evaluates `CCovertOpsMission`'s `is_valid` (`+0x48`): not found.
- What the province view's covert-operations window shows, and the order of its entries.
- The `disrupt_production` and `disrupt_research` static modifiers registered beside the spy ones.
- No party boost was checked against a save: the monthly drift swamps it.

**Frontier (rvas):** `0x2E1DB0` (the province view's covert-ops entry builder), `0x2E2C10` (its select callback),
`0x2E1FF0` (the `CanSelect` caller), `0x44B40` (`CCovertOpsMission` text, probably its name and description),
`0x21F490` (the espionage view's update with the coup gate, D), `0xF7EE0` (the coup button's tooltip, D), `0x159900`
(`CSendCovertOpsMission` Clone), `0x159380` (another table-writing site of that class), `0x140B50` (the technology
database's destructor).

## C. What a country knows

*Read 2026-10-14 on the listing (VAs, rvas beside named functions) and checked against the decompilation of a copy
with the record applied. Defines are Their Finest Hour's.*

**In one line.** What one country knows of another is **one figure, the spies**: `spies x 1000 / MAX_SPY_LEVEL`
less the target's `COUNTER_INTELLIGENCE`, with no other term. What a country knows of a province is a byte per
country, rebuilt daily and raised hourly, from control, friends, neighbours, units, undergrounds and radar.

**Corrected here:** `RunIntelRefreshIfRequested` is 0x7B8 bytes - a full per-province hourly raise - not "ten
instructions", and its request list is emptied every hour; `FINDINGS-airbattle.md` section 7 had the land and naval
intel-boost modifiers swapped (land reads modifier 103, `+0x338`, behind `CProvinceTemplate +0x22` `is_land`; sea
104, `+0x340`) and the radar rings the wrong way round - the far ring is never reached - and its "not a
neighbour's" is wrong; `g_FogOfWarEnabled` is the `fow` console command, raised to confirmed. And
`FINDINGS-espionage.md`'s define table above: `0x69EDB4`, `0x69EFAB` and `0x69F190` are not readers of
`SPY_BASE_PRODUCTION_DETECTION_CHANCE` - they are `[ebx+0x7C]` with ebx = `[obj+0x5F8]+0xCC` in map-nudge code
(strings 'naval_base', 'nudge_warning'); its one reader is 0x62BDD8.

### C.1 The figure for another country

It is not stored anywhere. It is computed on demand by `CSpyPresence_GetIntelFactor` (`0x52D630`, rva `0x12D630`)
from the looking country's presence in the target:

    F = level x 1000 / MAX_SPY_LEVEL (g_MaxSpyLevel, 10000)  -  target's COUNTER_INTELLIGENCE (modifier 54, +0x1B0)

- Everything is in thousandths; the division truncates, with a 64-bit path for large levels (if `MAX_SPY_LEVEL`
  were 0 the first term would be -1). One spy is 0.1, ten spies 1.0.
- **There is no clamp**: counter-intelligence above the spies' share makes F negative.
- **No other term exists.** Neighbours, an alliance, a faction, puppet and master, and war are not consulted. The
  function is twelve instructions, read whole; its only modifier read is `+0x1B0`, and `fieldchain.py --holder
  0xDA8 --field 0x1B0` finds no other reader of `COUNTER_INTELLIGENCE` anywhere.
- Where `COUNTER_INTELLIGENCE` comes from in Their Finest Hour: the civil laws - `open_society` -0.25,
  `limited_restrictions` -0.10, `repression` +0.1, `totalitarian_system` +0.25 - and the minister type
  `efficient_sociopath` +0.1.
- **What the save predicts:** F is the save's `spy_allocation` towards the target divided by 10, less the target's
  counter-intelligence; the save keeps no figure of its own. Germany's presences in the saves are whole spies (76
  targets of at least 1.000 on 1 January, 56 on 20 April), so the one-spy gate below never falls on a fraction
  there.

**Its readers, and the thresholds each uses:**

1. **The AI, `CAIIntel(us, them)`** (`0x89F240`; already confirmed, checked again at `0x89F308`-`0x89F37F`):
   `GetFactor` = F / 1000 as a float; `UncertaintyFactor` = clamp(1.0 - F + **0.2**, 0.2, 1.0) - the double at
   0x160A260 is the floor test and the float 0.2 at 0x171618C what is stored; `HasNoIntel` is `level < 1000`, fewer
   than one spy. `CalculateTheirPercievedMilitaryStrengh` also counts a unit as seen where `us`'s province byte is
   2 or more.
2. **The espionage screen.** `CEspionageView::GetIntelFactor` (`0x62A9E0`, rva `0x22A9E0`) answers 0 when no
   country is chosen (view `+0x1F8`), else F for **the player's** presence (`CCurrentGameState +0xC34`) in the
   chosen country. The `country_info` refresh `0x624970` turns that into:
   - **no intelligence** where the player's level is under 1000 (`setl` at 0x624BDA): the figures then show
     **"?"**, the literal at 0x15B4EB8 (0x624D4D);
   - **uncertainty** U = clamp(1.0 - F + **0.1**, **0.1**, 1.0) - the doubles 1.0 at 0x160A248 and 0.1 at
     0x160A3C0, the floor float 0.1 at 0x15C05F8. **The screen's floor is lower than the AI's 0.2.**
   - **The `spy` console cheat** (`g_SpyCheat`, 0x1A855F4) clears the no-intelligence flag and sets U to 0, so the
     screen shows true figures. Nothing in the simulation reads that byte.
   - **`OFFMAP_INDUSTRY_INTEL`** (modifier 61, `offmap_industry_intel`; the `industrial_specialist` minister +0.2)
     of the player is added to F and taken off U, each held to [0, 1], in two places - 0x6250DE in `country_info`
     and 0x62689A in the research section `0x626790` - its only readers (`fieldchain.py --holder 0xDA8 --field
     0x1E8`).
   - The estimates' random generator is seeded at 0x624B0A..0x624B7B (`0xAA2BF0`) with *the month of the year
     (0-11) + the player's country id*. **Inferred:** an estimate changes month by month and repeats each year in the
     same month.
   - The production list (`0x62BB20`): chance % = trunc(trunc(floorf(100000.5) x
     `SPY_BASE_PRODUCTION_DETECTION_CHANCE` (0.5) / 1000) x F / 1000) / 1000 - **50% at F = 1** - and each queue
     item is then rolled with an MSVC `rand` LCG (0x343FD/0x269EC3, two steps) seeded from the item and `0x61E350`'s
     date figure.
   - What each element shows is section D's; these are the gates it cites.
3. **The diplomacy screen hides nothing behind it.** A displacement-exact scan for `+0x1160` (the presence vector)
   finds 87 sites, none in the diplomacy view's code; the same scan finds the espionage view's 20 (the positive
   control). `0x62A9E0`'s three callers are all in the espionage view, and `FINDINGS-diplomacyview.md` has threat and
   goods shown plainly.
4. **The other "intel" modifiers are not part of the figure.** `OFFMAP_LAND_INTEL` (59) and `OFFMAP_NAVAL_INTEL`
   (60) are read only by `RunMilitaryEspionage` and `CAIIntel`'s strength estimate. **`PEACE_OFFMAP_INTEL` (58) and
   `OFFMAP_POLITICAL_INTEL` (62) have no reader** through a country's modifier values (`fieldchain --holder 0xDA8`,
   fields 0x1D0 and 0x1F0: none; positive controls 0x1B0 and 0x1D8 return their known readers) - so the ministers
   `general_staffer` (peace_offmap_intel 0.1), `barking_buffoon` (0.05) and `political_specialist`
   (offmap_political_intel 0.2) do nothing. Blind spot: a reader through another holder or a computed offset would be
   missed.

### C.2 What a country knows of a province

**Where it lives.** `CMapProvince +0x370` is one byte per country id (0-9), bounded by `+0x374`. **The savegame
keeps none of it** (its only `intel` key is `minister_of_intelligence`); it is rebuilt as a game is entered
(`RunIntelRefresh` from `CInGameIdler::Enter`, 0x66042A). Beside it, `CProvinceTemplate +0x278` (`stack_intel`,
`+0x13C` marking it stale) holds the figure for the country at the screen and its friends - what the map draws
stacks by. **"Friend" for the screen** is `Intel_IsFriendOfViewer` (`0x688050`), inlined everywhere: the same
country, the same real faction (faction slot 7 true and the same object), or an alliance in that country's
diplomacy status towards the viewer - not a puppet, a co-belligerent or military access.

**Who shares a country's 9s:** every country on its `allied_or_faction_countries` (`CCountry +0xFA8`), which
`RebuildNeighbours` fills with the countries the pair holds an alliance with, a dependency (puppet or master), or the
same real faction.

**The daily rebuild, `RunIntelRefresh`** (`0x688D40`, rva `0x288D40`, to `ret 4` at 0x689303):

1. **Clear** (`ClearIntelFunctor_SerialBody`, TBB, grain = provinces / 32): every byte to 0, or to **9 where
   `g_FogOfWarEnabled` is clear** (0x170AD30; starts at 1; the `fow` console command flips it and prints "Fog of war
   turned OFF/ON"); `stack_intel` to 0; and the 12-byte scratch entry per province filled - `+0` the controller's
   `encryption` (`CTechnologyStatus +0x3C`), `+4` the controller's `+0xFA8` list, `+8` the province is land and
   simulated, `+9` the controller is the screen's friend.
2. **Undergrounds** (serial): for every existing country, each province on its `underground_provinces` (`+0xD60`)
   gets 9 for that country and every country on its list.
3. **Neighbours** (serial). For every land, simulated province P, over its edges, each **land, simulated** neighbour
   N gets **at least 3** for P's controller and every country on the controller's list; and for each unit in P whose
   owner is **not P's controller**, and not the owner of the unit before it in the list, at least 2 + s for that
   owner - s is 0 where the owner's `decryption` (`+0x40`) is below N's controller's `encryption`, 1 where equal, 2
   where above, but where (d x 10000 / 1000) exceeds 1000 (d the difference in thousandths) s is that quotient / 1000
   + 1; capped at 9. So a gap of 0.1 or less gives 4, and each further 0.1 adds one. Their Finest Hour:
   `decryption_machine` +0.1 a level (up to 12), `encryption_machine` +0.1, `radio` -0.2 encryption.
4. **UpdateIntel** (`UpdateIntelFunctor_SerialBody`, TBB). For each simulated province P:
   - **9** for the controller and its list; **9** for the underground's owner (where `+0x390` is not 0) and its list;
   - each unit's **intel grants** (`CUnit +0x2A8`, `{country, duration, level}`) with a duration above 0 give at
     least min(level, 9). Writers: `CUnit_GrantIntel`, from `local_intel_boost` (level 8, 15 days) and from
     `RunMilitaryEspionage` at 0x530076 (section B). Durations count down by one per call of `CUnit` slot 32
     (`CUnit::UpdateDaily`, 0x5BAF70, which drops spent entries);
   - where a unit's owner is not P's controller: **9 on land**; at sea, 9 where a combat of kind 1 is in P or the
     unit is a patrol (0x42E) with a target, **else at least 2**;
   - **radar**, for each existing country with `listening_station` (`CTechnologyStatus +0xDC`): s = -1 where its
     decryption is below P's controller's encryption, 0 where equal, else max(1, d x 10 / 1000); m = trunc(
     **`LAND_INTEL_BOOST`** (103) / 1000) over land, **`NAVAL_INTEL_BOOST`** (104) over sea - these two modifiers have
     no other reader; near = s + 2 + m, held to 0..8; a country already at near or above is skipped. For each of its
     radar provinces (`CCountry +0x1148`) with `RADAR_LEVEL` above 0: reach = level x (`RADAR_RANGE` (0.18) x
     `Province_RadarVisibility(P)` / 1000) / 1000, and P is seen where 16(dx^2 + dy^2) < R^2, with R =
     trunc(trunc(250000 x reach / 1000) / 1000) and dx the short way round the map. The second test, against 350000,
     always passes, so **only near is ever written; the far level (s + 1 + m) is dead**. It is written for the
     radar's country and its list.
   - `Province_RadarVisibility(P)` (`0x4A76A0`) is 1000 with no units or no controller; otherwise 1000 + r x
     max(100, the controller's radio_strength tech x 1000 / 100000) / 1000 x `BASE_RADIO_STRENGTH` (10) / 1000, with
     r the largest radio_strength of each unit's **first** brigade, never below 1000. Their Finest Hour's brigades
     have radio_strength 1, which gives **2000: ground with troops on it is seen from twice as far.** With troops
     present, radar level 1 sees **90 km**, level 10 ten times that; with none, 45 km.
5. **No fog** (`g_FogOfWarEnabled` clear): the screen's country gets 9 on every simulated province.

**The hourly raise, `RunIntelRefreshIfRequested`** (`0x689310`, to `ret 4` at 0x689AC5), at the end of every hour:
if the request list's head is -1 it runs the whole rebuild; otherwise, for each requested simulated province, it
**raises** bytes and clears nothing - controller and its list 9; land, simulated neighbours, controller and list at
least 3; units: grants, and 9 / 9 / 2 for a foreign owner as in the daily pass; then **every land neighbour,
simulated or not**, at least 2, 3 or 4 by decryption against encryption, **unscaled**; and the underground's owner
and its list 9 where P's underground building's `level_max` is above 0. No radar. Who files requests: positive ids -
`CUnit::EnterProvince` (the province left and the one entered) and `CLocalIntelBoost::Execute`; -1, pushed to the
front - changes of owner and controller (`CMapProvince::SetOwner`, `Province_SetController`),
`RebuildProvinceModifierValues`, `CCountry::AddRadarProvince`, alliances (`CAlliance::Activate`/`Deactivate`,
`CAllianceAction::Apply`), the military-access actions, `CNapAction::Apply`, `CSendExpeditionaryForceAction::Apply`,
`CFactionAction::Apply` and `CSetCountryControllerCommand`. `RunHourlyTick` then sets every unit's `intel_level`
(`CUnit +0x1F8`) for the screen's country - 9 for its own and its friends' units, else the byte of the unit's
province - and **frees the whole list** (0x6823DD..0x682407).

**How often it runs:** once a game day (the second-to-last call in `RunDailyPass`), plus at the end of any hour with
a -1 request; also as a game is entered, in custom-game setup, in scenario setup (`RefreshAllCountries`) and in the
map editor (`CNudgeIdler` slot 3. It starts on the tick thread; the element bodies run on TBB workers and the tick
thread.

**Thresholds its readers use** (cited, not re-read):

| level | used by |
| --- | --- |
| >= 2 | seen: air missions, the AI's choice of target, pathing cost, victory-point map brightness, `CAIIntel` |
| < 2 / < 3 / < 5 / < 7 | a unit's stack is hidden / gets the unknown picture / its name is `???` / its figures are `?` (`FINDINGS-counters.md`) |
| >= 6 | the province window's buildings, the intel map mode |
| >= 6, 7, 8 each double naval spotting; 9 short-circuits it | `FINDINGS-navaldetection.md` |
| > 8 | the province tooltip's supply lines |

### C.3 What looks wrong but is what the bytes do

- The far radar ring is never written: 350000 > 250000, so every province in reach gets the near level.
- A country's own units in its own provinces give it nothing on adjacent land beyond the controller's 3: the
  foreign-unit rule skips the controller's units.
- The hourly raise gives a fleet in a sea zone 2-4 on adjacent coast; the daily rebuild never does (it requires P to
  be land), so the coast is lost again at the day's turn.
- The hourly decryption step is unscaled (at most 4); the daily one scales up to 9.
- The AI's uncertainty floor is 0.2 and the screen's 0.1.
- F has no floor: counter-intelligence above the spies' share makes it negative.
- Ministers with `peace_offmap_intel` or `offmap_political_intel` do nothing (no reader found).
- The daily underground arm's `stack_intel` test re-tests the **controller**, not the underground's owner; the
  hourly arm tests the owner.
- A unit grant's level raises `stack_intel` unclamped (above 9 if the level is), while the byte is held to 9.
- `CSetCountryControllerCommand`'s -1 and every alliance change force a whole rebuild in that hour.

### C.4 What was not settled

- Which sections of `country_info` each U or F feeds, and what "?" replaces element by element - section D's; the
  gates are above.
- The estimate generator's seeding function `0xAA2BF0` and `0x61E350` were not read past the date arithmetic;
  "estimates hold for a calendar month" is inference.
- Where `CUnit` slot 32 is called from, so whether grants count down daily (the record already marks that inferred).
- Combat kind 1 at sea is taken from the existing record, not re-read.
- `RunMilitaryEspionage`'s grant level and duration (0x530076) are section B's. The record's `CUnit +0x2A8` comment
  and `CUnit_GrantIntel` still say "its one caller is local_intel_boost"; there are two.
- `0x4EF7C0` (`CCountry::IsFriend`) is recorded and confirmed, cited and not read: the intel passes do not use it.

**Frontier (rvas):** `0x224970` (the `country_info` refresh, D), `0x226790` (research section, D), `0x22BB20`
(production list, D), `0x22D9F0` (the screen's estimate helper), `0x21E350` (the date seed), `0x6A2BF0` (generator
seeding), `0x1BAF70` (`CUnit::UpdateDaily`'s caller and period), `0x130076` (the military grant, B).

## D. The screen

*Read 2026-10-14 on the listing. The file is `tfh/interface/country_espionage.gui`; the class `CEspionageView`, view
index 4. Sections A-C settle what the figures are; this is what the screen shows of them and what it posts.*

Conventions, those of `FINDINGS-government.md` D and `FINDINGS-diplomacyview.md`: **P** is the played country (idler
slot 23, game state `+0xC30/+0xC34`); **chosen** is the view's selected country (`+0x1F4/+0x1F8`); **pres(c)** is
`P.espionage[c]` (`CSpyPresence`). A window finds an element by its slot - 13 a button, 14 a text box, 15 an instant
text box, 17 an icon, 18 a checkbox, 27 a child window, 31 a list. On buttons and icons slot 18 sets the frame and 19
reads it; on a button 46 (`+0xB8`) enables and 47 (`+0xBC`) disables; lists use 20 show, 21 hide, 23 empty, 4 add;
slot 38 greys a window. FFP is `FormatFixedPoint`, which truncates. Texts are Their Finest Hour's English.

**In one line.** Below one whole spy every figure of the chosen country shows "?"; otherwise each estimate is
perturbed at random by an uncertainty u = clamp(1.1 - F, 0.1, 1.0), F being section C's figure, on a private
generator seeded with the month of the year plus the played country's id, so a month's figures hold still.

**Corrected here:** `attempt_coup_button` is **never hidden** - `Update` enables or disables it - which corrects
`FINDINGS-government.md` B.6 and B.8, section B.7 above and the `CanAttemptCoup` record comment; the view's spy gate
is whole spies, level / 1000 truncated, above 0. `CEspionageView::BuildTooltip` is raised to confirmed with a
corrected signature. `RandomPerturbAtLeast`'s six "not read" callers are `FormatEstimatedStock`, diplomacy, manpower,
leadership, the spy pool and weak tech.

### D.1 The view, and when things happen

**Construction.** `CEspionageView::CEspionageView` (`0x61EAE0`, rva `0x21EAE0`) is called once, at 0x659C7A, after
`new 0x37C` - the fifth view, view index 4; the base makes `country_espionage` and `topcolor_espionage`. It sets the
sort handler to Name, the list handler to All, the direction byte `+0x1F0` to 1, and `+0x374` and `+0x378` to -1.
**It picks the first chosen country**: of every country (database order) that owns a province and is not P, the one P
feels the most threat from (`Diplomacy[c]->threat`), ties to the first in database order, and with no threat anywhere
the first such country. Then `BuildWidgets`, and both windows are hidden.

**`BuildWidgets`** (`0x6226A0`, rva `0x2226A0`; from the constructor and Rebuild) binds the five sort buttons, the
tabs `majors_button`, `neighbours_button`, `unaligned_button` and `all_button`, `button_viewproduction` and
`button_viewministers` (both set to frame 1), `attempt_coup_button` and `target_priority`. **`self_button` is bound to
nothing**: the only reference to its name in the image is diplomacy's (0x782657; the positive control
`majors_button` is referenced here), so "Selected" does nothing. It makes the faction boxes and the continent buttons
as diplomacy D.2/F.2 does, with this file's position types: `espionage_faction_start` (56,349), step
`espionage_faction_offset` (101,0), each `faction_symbol_button` (or `faction_symbol_big_button`) given sprite
`GFX_sort_<faction key>` and the faction's slot 6 text; continents from `espionage_continent_offset` (57,406), step
`espionage_continent_start` (100,0), wrapping at `espionage_continent_end`.x (300) with y + 20 - three a row, Europe,
Asia, Africa then the Americas and Oceania - named `cont_button_<n>`. A faction click lists the faction's members; a
continent click every country whose **capital** is on it. Then `FillSpyMissions`, `FillOwnSpyMissions` and
`BindOwnCountryInfo`.

**Show** (slot 2, `0x61FAF0`), every opening: shows both windows; `UpdateAutomationLine`; P's flag and name in
`own_country_info` (`country_flag`, `label_nation`), then `RefreshOwnCountryInfo`; **makes the country list again from
scratch** by re-running the current tab, faction or continent (diplomacy only refills an empty list); hides
`country_info` when nothing is chosen, else `RefreshCountryInfo`; and tags the main window `espionage_view`.

**Update** (slot 6, `0x61F490`), every frame while open:

1. `UpdateFactionBoxes` (an empty loop that moves nothing) and `RefreshOwnCountryInfo` (all of `own_country_info`,
   D.3). Nothing below runs without a chosen country.
2. spies = pres(chosen).level / 1000, truncated. **`country_info` is made again only when spies differs from
   `+0x374`, or `EspionageView_MonthRefreshKey` (the month of the year 0..11 + P's id) differs from `+0x378`**: that
   runs `RefreshSpyCount` and `FillProductionSection`. Otherwise only the production rows refresh.
3. The mission rows refresh.
4. **Every country row refreshes**: `spy_level`, `covert` and `threat` are live (D.2).
5. **`attempt_coup_button` is enabled when** spies > 0, **and** pres(chosen).covert_ops_points >=
   `COUP_COVERT_OPS_COST` (20), **and** `CanAttemptCoup` (B) holds; otherwise disabled. **Never hidden.**
6. `covert_ops_value` = itoa(covert_ops_points / 1000).

**Rebuild** (slot 0, `0x61FCA0`): Hide, the base remakes the windows, then `BuildWidgets`.

**Ai Control** (slot 14, `0x62CF40`, in place of the base's whole-window greying): greys `own_priority`,
`country_info`, `own_country_info` and every row's `priority`, leaving `unit_queue` and `country_info_sections`
usable. The mode arrows and `automation_setting` are the base's (diplomacy D.7).

**What opens the screen:** `topbarbutton_intelligence`, through `CTopBar::OnIntelligenceButton` ->
`OpenCountryView(4)` - a toggle, as politics D.7; **F5** is the file's `shortcut`. An alert named `intel` also opens
it (`OnAlertClicked`, 0x64B5A8), only when it is not already open; what raises such an alert was not found (`intel` is
also referenced twice in tutorial code, 0x8E5F82 and 0x8E5FB7).

**Elements no code looks up** keep the file's text: `headline_espionage` "INTELLIGENCE", `label_internal` "Internal",
`label_external` "External", `label_free_spies` "Free Spies", `label_active_spies` "Active Domestic Spies" / "Active
Spies", `label_active_foreign_spies` "Active Spies Abroad", `label_partisan_efficiency`, `label_spies_caught`,
`label_our_neutrality`, `target_priority_label` "Send Spy Priority", `covert_ops_label` "Covert Ops Points:",
`top_tech_label` "Strong Tech", `weak_tech_label` "Weak Tech", `current_research_label` "Current Research",
`popularity_label` "Popularity", `view_production_label` "Production", `view_minister_label` "Ministers", the icons and
`covert_ops_icon`. **`spy_unitbrowse_entry`, `spy_basebrowse_entry` and `spy_browser_offset` are unused**: their names
are not in the image.

### D.2 The country list

**Tabs** (each empties the stored list `+0x1FC`, refills it, flips `+0x1F0`, and re-runs the current sort):

| button | who | stored order |
| --- | --- | --- |
| `all_button` (default) | every country of the database owning a province, not P | **by name A to Z**, ties in database order |
| `majors_button` | the vector's countries owning a province, not P, `major` or max IC over 100 | vector |
| `neighbours_button` | P's neighbour list, owning a province | that list's |
| `unaligned_button` | the vector's countries owning a province in the null faction, **neither P nor the chosen one** | vector |
| faction box | the faction's members (`+0x28`) owning a province, not P | by name |
| continent button | countries whose capital (`GetCapitalLocation`) is on it, owning a province, not P | by name |

**Only All** also chooses the owner of a single selected map province (when it is not P).

**Sorts.** One direction byte `+0x1F0` (1 at construction) serves all five. A sort button passes its current value
(non-zero: descending, largest or Z first), and the sort then flips it; a tab flips it first, so re-running the last
sort keeps its direction. The first opening shows All, A to Z. Each insert walks back from the tail and inserts after
the first node that does not belong behind the new one, so **ties keep the stored order**.

| button | key (all P's) |
| --- | --- |
| `sortby_name_button` "Name" | `CountryNameOfCountry`, unsigned bytes, case and all |
| `sortby_threat_button` "Threat" | `P.Diplomacy[c]->threat` (`CompareThreatToCountry`) |
| `sortby_covert_button` "Covert" | pres(c).covert_ops_points |
| `sortby_spy_level_button` "Spies" | pres(c).level |
| `sortby_spy_priority_button` "Priority" | pres(c).priority; **always highest first**, though the byte still flips |

Rows are added in order; where the view is open the list box is then shown and **tagged `diplomacy_view`**.

**A row** (`espionage_country_entry`, `CEspionageView::CCountrylistItem`, 0x110 bytes): `country_button` (a checkbox)
and `country_icon` (the flag) both select - the checkbox is ticked and `SelectCountry` runs; `name` the country's
name, set once; `threat` = FFP(P.Diplomacy[c]->threat, 1); `covert` = itoa(pres(c).covert_ops_points / 1000);
`spy_level` = itoa(level / 1000) when made, and each frame thereafter `FormatFixedPointTrimmed(level)`, with `covert`
and `threat`; `priority` frame = pres(c).priority + 1 (frames 1-4) - a click +1 with 4 wrapping to 1, a right click
(glue `+0x24`) -1 with 1 wrapping to 4, set at once and posting **`CChangeSpyPriority(P, c, frame - 1)`** (constructor
0x5588F0, through idler slot 18 -> `+0x38` -> slot 6); where c is the chosen country `target_priority` follows. **Rows
have no tooltip** (inferred: neither this view's nor diplomacy's `BuildTooltip` answers them).

### D.3 `own_country_info` (P; every frame)

| element | text |
| --- | --- |
| `country_flag`, `label_nation` | P's flag and name (Show and `BuildWidgets`) |
| `value_free_spies` | itoa(spy_pool `+0x1170` / 1000) - the 20 April save's 13.723 shows "13" |
| `value_active_spies` | itoa(pres(P).level / 1000), the domestic spies |
| `value_active_foreign_spies` | the sum over countries owning a province, not P, of pres(c).level / 1000, each truncated |
| `value_partisan_efficiency` | `§R` above 50.000, `§Y` above 0, nothing at or below 0, + FFPTrimmed(`MODIFIER_PARTISAN_EFFICENCY`, id 79); no `§W` |
| `value_spies_caught` | itoa(spiescaught `+0x11D4`) |
| `foreign_spy_actions_indicator` ("§R!") | shown when pres(P).level x 1000 / (`MAX_NUMBER_OF_SPIES` 10 x 1000) > 300 (floorf(300.5f)) - more than 3 domestic spies - **and** any country owning a province has a level above 0 in P; hidden otherwise |
| `value_our_neutrality` | FormatFloat(effective neutrality / 1000, 0), rounded |
| `own_priority` | frame = pres(P).priority + 1; click and right click +-1, posting **`CChangeSpyPriority(P, P, p)`** |
| `our_spy_missions` | `CSpyMissionEntry` rows for missions 0, 3 and 7 (Counterespionage, Support Ruling Party, Raise National Unity) about P |

### D.4 `country_info` for the chosen country

**Header** (`RefreshCountryInfo`): `country_flag`, `label_nation`, `faction_symbol_icon` (frame `CFaction +0x3C`,
hidden for the null faction). Choosing a country **always switches to the Production section**.

**Spies.** `value_active_spies` = colour + itoa(level / 1000) + `§W`, with F = the intel factor / 1000: **F > 0.6
`§G`, F > 0.3 `§Y`, else `§R`**. `spy_bar` frame = spies + 1 (11 frames). `target_priority` frame = priority + 1, its
click and right click posting **`CChangeSpyPriority(P, chosen, p)`**. `covert_ops_value`: D.1.

**Missions** (`spy_missions`, `CSpyMissionEntry`): missions 0-8 but 7, eight rows (7 only when the chosen country is
P, which never happens); `title` = `SpyMissionTitle(k)`; `priority` frame = pres(chosen).missions[k] + 1 (the weight
0..3); click and right click +-1 post **`CChangeSpyMission(P, target, k, w)`** (constructor 0x558E00).

**The estimates** (`FillEstimates`, `0x624970`). The private generator is seeded with month + P's id, so a month's
figures are fixed.

- **noIntel** = pres(chosen).level < 1000, fewer than one whole spy; the `spy` cheat clears it.
- **u** = clamp((1 - F) + 0.1, 0.1, 1.0); 0 under the cheat.
- **b** = `SPY_INTEL_MISSION_BONUS` (0.5), applied **flat, whatever missions are set** (a copy of the presence is made
  and never read).
- **ind** = P's `MODIFIER_OFFMAP_INDUSTRY_INTEL` / 1000.
- Each estimate is base + trunc(k x scale / 1000), with k = floor(((r - 0.5) x spread + 0.0005) x 1000) - so +-
  spread/2 of the scale - floored, and capped where stated (`RandomPerturbClamped`, `0x62D9F0`).

| element | under noIntel | otherwise |
| --- | --- | --- |
| `counter_intel` | "Counterespionage: ?" | "Counterespionage: " + FFP(clamped(chosen's own level x mission_share[0] / 1000, 0..10 spies, scale 10, u), 0) |
| `energy/metal/raremat/oil/fuel/supplies/money_number` | "?" | `FormatEstimatedStock` (`0x61D410`): the stock (the exile pool, or the acting capital's pool) +- spread/2 of itself, spread = clamp(u - ind, 0, 1) x (1 - b); FFP 0 decimals, or FFP(v / 1000) + "K" above 99999 |
| `ic_number` | "?/?/?" | **exact**: (avail > 0 `§R` else `§G`) + GetAvailableIC + "/" + (max IC > TotalIC `§R` else `§G`) + max IC + "/" + TotalIC |
| `dissent_number` | "?" | FFP(clamped 0..100, scale 100, spread u x (1 - b), 2 decimals) |
| `national_unity_number` | "?" | FFP(clamped 0..100, scale 100, u, 1) |
| `diplomacy_number` | "?" | FFP(diplomatic influence, or 100.000 under `[0x1BEA410]`, floor 0, scale 100, u, 0) |
| `manpower_number` | "?" | FFP(manpower, floor 0, scale 100, u, 0) |
| `leadership_number` | "?" | FFPTrimmed(TotalLeadership, floor 0, scale 100, u) |
| `espionage_number` | "?" | itoa((spy_pool +- scale 10, u) / 1000) |

Draw order: counter-intelligence, then the seven goods (only when not noIntel), then dissent, unity, diplomacy,
manpower, leadership, espionage, then research.

**Research** (`FillResearchLists`, `0x626790`). With k = clamp(F + ind, 0, 1) and u' = clamp(u - ind, 0, 1), rows
`espionage_research_entry`:

- `current_research`: the first trunc(GetAllowedResearchSlots x k + 0.5) entries of the chosen country's
  CurrentResearch list, as name + " (" + p + "%)", p = this level's progress in whole percent + trunc((r - 0.5) x u' x
  99), held to 0..99.
- `top_tech` / `weak_tech`: **theories and practicals (the technology categories)**, ranked by the chosen country's
  ability (the higher of its own and its shared-from country's); n = min(trunc(5k), all); top highest first, weak
  lowest first; name + " (" + FFPTrimmed(shown) + ")", the value perturbed +- u' x 2.5 levels and floored at 0.
  **Top shows min(previous raw value, this one), weak max(previous, this one).**
- With F <= 0 and no industry intelligence the lists are empty. They are not "?"-gated.

**Coup.** `attempt_coup_button`'s enabling is D.1; a click posts **`CPerformCoupCommand(from = chosen, to = P)`**
(`OnAttemptCoup`, `0x629A30`) with no further test.

**Pie** (`political_popularity_chart`): the chosen country's popularity, exactly as politics D.2 (whole percents,
half to even). **Not gated.**

### D.5 `country_info_sections`

**Production** (`button_viewproduction`, frame 2 when pressed; also on every country change). `units_label` =
`SPY_PRODUCTION_LABEL` "Producing" (the file's "Known Count: $COUNT$" is never shown). `unit_queue` lists each of the
chosen country's constructions, in list order, for which r < chance: chance = 100000 x
`SPY_BASE_PRODUCTION_DETECTION_CHANCE` (0.5) / 1000 x F / 1000 / 1000 - **50 x F whole percent** - and r an MSVC-rand
product: s1 = (construction id + month key) x 0x343FD + 0x269EC3, s2 = s1 x 0x343FD + 0x269EC3, r = ((s2 >> 16) &
0x7FFF) x ((s1 >> 16) & 0x7FFF) % 100, fixed per item per month. Rows (`spy_production_queue_entry`) copy the
production screen's: counter icon, `unit_name`, a progress bar, "+N" for a series; `unit_target` "=> name" is parked
at x 99300.

**Ministers** (`button_viewministers`): `units_label` the government's name; `minister_list1/2` the chosen country's
posts as politics D.3, as `CForeignMinisterItem` rows - `title` the post, `name`, `personality`, `legend_color`,
`photo`, "???" without a valid minister. **No knowledge test.**

### D.6 Tooltips (`CEspionageView::BuildTooltip`, slot 10, `0x61FCD0`)

By element name, in this order:

| element | text | delayed |
| --- | --- | --- |
| `political_popularity_chart` | the slice's ideology (slot 14 for chosen) + " - §Y" + n + "%§W" | `QUALIFIES_FOR_CABINET` "Qualifies §Y$COUNT$§W for cabinet positions", COUNT = chosen's cabinet[ideology] |
| `value_spies_caught` | `ESP_SPIES_CAUGHT` "We have caught §Y$NUM$§W foreign spies in the last month.", NUM = spiescaught | the contributors to P's `MODIFIER_COUNTER_ESPIONAGE` (`CModifier` slot 9, scale 1000) |
| `foreign_spy_actions_indicator` | `DETECTED_SPY_ACTIONS` "We have detected foreign spy activity in our country." | - (an empty country loop follows) |
| `value_our_neutrality` | `ESP_NEUTRALITY` "Our neutrality is currently §Y$NUM$§W.", NUM = FormatFloat(effective neutrality, 0) | - |
| `value_active_spies` (**both windows**) | `ESP_NUM_SPIES` "We currently have §Y$NUM$§W spies in §Y$NATION$§W.", of the chosen country | `ESP_NUM_SPIES_DELAYED` "New spies will be sent here with a priority of §Y$PRIO$§W as they become available. You can have a maximum of §Y10§W active spies in a nation.", PRIO 0..3 |
| the seven goods, `ic_number`, `diplomacy/espionage/manpower/dissent/national_unity/leadership_number` | `ESP_ESTIMATE_RES` "Our spies estimate a total of §Y$NUM$§W $ITEM$", NUM **the box's current text** ("?" or "§R1/..." included), ITEM Energy / Metal / Rare Materials / Crude Oil / Fuel / Money / Supplies (`GoodName` through `GoodIndexByShortName`), IC, Diplomacy, Espionage, Manpower, Dissent, National Unity, Leadership | `ESP_ESTIMATE_RES_DELAY` "This value is an estimate. You can increase the accuracy by sending more spies or appointing minister with this speciality." |
| `attempt_coup_button` | 0x4F7EE0(chosen, out, &P) (section B's) | - |
| rows of `spy_missions` / `our_spy_missions` (any element) | `SpyMissionDescription`: `SPYMISSION_*_DESC` | - |
| rows of `minister_list1/2` | `legend_color`: the minister's ideology name; others: the personality's modifier values | - |

**No tooltip** on country rows, research rows, production rows, `target_priority`, `own_priority`, `counter_intel`,
`covert_ops_value`, `spy_bar` or the icons. `ESP_ESTIMATE_RES_DELAY_SPEC`, `SPY_PRIORITY_0..3` and
`CHANGESPYMISSIONDESC` are not in the image.

### D.7 What looks wrong and is what the bytes do

1. `self_button` does nothing.
2. The Priority sort never reverses, yet still flips the shared direction byte.
3. Show re-lists every time; only All picks up a selected province's owner.
4. Unaligned leaves out the chosen country.
5. `SPY_INTEL_MISSION_BONUS` halves the spread of the goods and of dissent only, whatever missions are set; not unity,
   diplomacy, manpower, leadership, spies or counter-intelligence. A presence copy is made and unused.
6. IC is exact though its tooltip calls it an estimate; the pie and the ministers show everything at any knowledge.
7. The estimates' generator is seeded by month of the year + player id: the same month next year, and every target,
   share the draw sequence.
8. Strong and weak tech values are smoothed by min/max against the previous row's raw value.
9. A month change or a change of spy count while Ministers is open refills `unit_queue` and empties the minister
   lists, the Ministers tab staying pressed (`+0x370` is never read).
10. `value_active_spies`' tooltip in `own_country_info` speaks of the chosen country.
11. The tooltip hard-codes "10" spies.
12. The partisan colour is red only above 50.000 (unreachable) and has no `§W`.
13. The country list box is tagged `diplomacy_view`.
14. A row's `spy_level` is an integer when made and trimmed decimals after one frame.
15. `ESP_ESTIMATE_RES`'s NUM embeds colour codes and "?".

### D.8 What was not settled

- Who raises an alert named `intel`.
- What `CStandardlistboxItem +0x24` (the row refresh gate) means; taken to be "on screen".
- The coup tooltip 0x4F7EE0 (B's); the pie hit test 0xAA3270.
- The row checkbox's `+0x60`/`+0x100` writes.
- Whether the main window's `espionage_view` tag overrides the list's `diplomacy_view`; rows get no tooltip either
  way, inferred.
- The `CBuildQueueEntry` production row was read from the decompilation only.

**Frontier (rvas):** `0xF7EE0` (the coup tooltip), `0xF7940` (the popularity copy), `0x6A3270` and `0x6A37D0` (the
pie's hit test and setter), `0x113980` (the `CSpyPresence` copy constructor), `0x3C9530`, `0x10D210` (the persistent
id's resolve), `0x21C840`, `0x22D640`, `0x22D6C0` and `0x22D740` (glue constructors), `0x22B240` (the row
destructor's body).

### D.9 The coup's tooltip (`CoupTooltip`, `0x4F7EE0`, rva `0xF7EE0`)

*Read 2026-10-14 on the listing, for OpenHOI3's screen, after the maintainer's screenshot of the original showed the
tooltip. Section D.6 and `FINDINGS-government.md` B.6 had it read for its keys only.*

Two lines. **The first**: where the instigator's and the target's ruling ideologies are of one group, or the target's
government is not fractured (`CCountry_HasFracturedGovernment`), `COUP_DESC_DISABLED` - "Their party position is too
strong" - alone; otherwise `COUP_DESC` where the instigator's group holds a seat in the target's cabinet
(`CoupCabinetSeats` above 0) and `COUP_NOT_ENOUGH_SUPPORT` where it holds none, each with `TARGET` the target's name.
**Then a line break** (the one-character string at 0x15B57D0, `\n`) **and the cost**: `COV_OPS_COST` and the cost with
no decimals where the instigator's covert-ops points about the target are at least `COUP_COVERT_OPS_COST`, else
`COV_OPS_COST_LACKING` with `COST` the cost and `CURRENT` the points, both with no decimals. The reasons are
`CanAttemptCoup`'s three tests; the spies are not asked. The maintainer's screenshot: "Their party position is too
strong" / "Costs 20 covert ops points. We only have 0".

## E. The AI's spying

*Read 2026-10-14. Addresses are VAs with the rva beside named functions.*

**In one line.** The AI's spying is one program, the install's Lua `IntelligenceMinister_Tick` - Their Finest
Hour's `tfh/script/ai_intelligence_minister.lua` shadows the base game's - which sets each country's priority toward
every other country and a priority for each of the nine missions there, by posting `CChangeSpyPriority` and
`CChangeSpyMission`. The minister runs no C++ espionage logic at all. Checked against the saves: the script's priority
and mission rules give 5,802 of 5,929 AI pairs on 20 April exactly, the other 127 one higher (the neighbour term the
model leaves out), none otherwise off.

**Corrected here:** the minister's countdown draw is `% 10 + 1`, not the politics minister's `% 3 + 1`; a command it
posts executes an hour later (its `spy_date` carries the minister's hour plus one); `CCountry::CalculateIsAllied`
counts faction members that have no bilateral alliance, which answers `FINDINGS-scopetriggers.md`'s open question;
and `CSpyPresence` has no `GetMission` in Their Finest Hour's registration - the struct comment and the opening of
this file are wrong - so the base game's script cannot run in this executable.

### E.1 Who has an intelligence minister, and when it acts

**Creation** is the politics minister's rule (`FINDINGS-government.md` E.1): `CEU3AI::CreateMinisters` (rva
`0x4888C0`) makes it, at `CEU3AI +0x68`, for every country the local player does not play, and for the player's own
only when `GetLocalPlayer()[+0x38][4] == 1` - espionage delegated. A scenario makes none. The saves bear this out:
Germany, the maintainer's country, keeps the start's own presence (priority 1, counter-espionage 1) and nothing abroad
in all five saves.

**Enabling.** `CAIEspionageMinister::Enable` (slot 52, `0x89CB30`, rva `0x49CB30`) sets `+0x3C enabled = 1`,
appends the minister to seven observer channels of the table at `0x1B14DC0` (0x14, 0x15, 0x19, 0x1A, 0x1B, 0x1C and
0x17), and sets **`+0x30 countdown = MT19937Next(gamestate +0x124) % 10 + 1`** - one draw on the AI's generator, so
the first `DoWork` comes 1 to 10 AI passes later. The subscriptions do nothing: every slot a channel can call on this
class (11 to 47) is an empty shared stub - `0x60CD50` (`ret 4`), `0xA806D0` (`ret 8`) or `0x84A610` (`ret 0x10`);
channel 0x15, a war joined, calls slot 41, and 0x14, a war left, slot 40. Slot 49 (`0x89CDD0`, rva `0x49CDD0`) is one
body shared with the foreign and production ministers: it clears the minister's node on the seven channels and
tail-jumps to `CAIAgent::DisableAndDisband`.

**The schedule.** `ProcessAI` passes its gates and calls slot 9 (`CAIAgent::Update`), which counts the countdown down
and calls slot 10 at 0; that pass runs hourly on TBB workers. `CAIEspionageMinister::DoWork` (`0x89CEC0`, rva
`0x49CEC0`) sets the countdown back to 1 and acts only when `(country_id + 1) % 24 == (tick - 0x29C55C0) % 24` -
**once a game day, in the hour (id + 1) mod 24**. It then fetches the global `IntelligenceMinister_Tick` (`0x89D0D0`)
and calls it through `LuaCallProxy_IntelligenceMinister_CallVoid` (`0x89D050`), the one argument the minister pushed
as a `CAIEspionageMinister` (`0x89D110`), no result. A Lua error or a missing function is caught (`luabind::error`)
and logged as `LUA Error: <message>` by `ReportLuaError`. Nothing else runs: no weekly sub-task, and no test of who
plays the country. Ids follow `common/countries.txt` after `---` (0): REB 1, GER 2, ENG 3; **Germany's hour is
03:00**.

**What the saves show of it.** The maintainer's saves are not one continuous game: Paraguay's home record is stamped
1936.1.1.3 in the save of 20 April (file dated 8 October) and 1936.1.2.4 in those of 4 and 8 January (dated 9
October), so they are at least two sessions from the one start. In `Germany1936_01_01_00.hoi3` no minister has acted:
every country's own presence is priority 1 with counter-espionage 1, every other priority is 0, and every `spy_date`
1.1.1.0. By 4 January 12:00, 30 of the 77 existing AI countries have acted; by 8 January 07:00, 51; by 20 April all
77 - the countries still at the start's values are exactly REB, GER and the 22 that own no province. **The stamps
carry the hour after the minister's**: for 76 of the 77, every non-epoch `spy_date` is at `(id + 2) mod 24`, so a
command the AI posts in its hour executes, and stamps the tick, at the next hour (inferred from the saves; the command
drain was not read). Paraguay is the one exception: its home record is stamped 1936.1.1.3, its own hour.

### E.2 `IntelligenceMinister_Tick` (Their Finest Hour)

    if math.mod(GetAIRand(), 9) == 0   -> everything below          1 day in 9
    else                               -> nothing

One draw on the game state's generator, so an AI country reconsiders its spies every nine days on average. On a hit it
builds `IntelligenceData` - a file-local table, one per thread's Lua state, rebuilt each tick: the minister, its AI
and tag, the country; `GetFaction()`; the **declared** capital (`GetCapitalLocation`), its controller and continent;
`IsAtWar`, `IsMajor`, `IsGovernmentInExile`; its own presence `GetSpyPresence(own tag)` with its priority and primary
mission; `GetNationalUnity():Get()`, the ruling party and its group, and that party's popularity
`AccessIdeologyPopularity():GetValue(party):Get()`. `humanTag`, `TotalDaysFromStart` and `BufferUsedForMissions = 60`
are filled and never used; `Year` and `IsAtWar` are used only by Germany's override.

**Bad spies:** for each country in `GetSpyingOnUs()` (E.4), if its presence in us has `GetPrimaryMission() ==
SPYMISSION_LOWER_NATIONAL_UNITY` (5), `DomesticBadSpies = true`. No other hostile mission counts. Then
`ManageSpiesAtHome()`, then `ManageSpiesAbroad()`.

**`ManageSpiesAtHome`.** All nine missions start at 0. A country's `Intel_Home(IntelligenceData)` override replaces
the rule - the chosen mission gets 3 and nothing else, not even counter-espionage; Their Finest Hour has none.
Otherwise, NU being national unity in percent and P the ruling party's popularity in percent:

| first that holds | missions |
| --- | --- |
| always | counter-espionage 3, plus: |
| NU < 70 | raise national unity 2 |
| bad spies | nothing more |
| P < 35 | boost ruling party 1 |
| NU < 80 | raise national unity 1 |
| P < 65 | boost ruling party 1 |
| NU < 95 | raise national unity 1 |

Then `UpdateMissions(us, us)` and, if the home priority is below `CSpyPresence.MAX_SPY_PRIORITY` (3),
`CChangeSpyPriority(us, us, 3)`.

**`UpdateMissions(actor, target, missions)`**: for each of the nine missions in the order `pairs` gives, if
`presence:GetMissionPriority(m) ~= value` it does `ai:Post(CChangeSpyMission(actor, target, m, value))` - only
differences, one command a mission.

**`ManageSpiesAbroad`**: for every country of `CCurrentGameState.GetCountries()` (id order) that `Exists()` (owns a
province) and is not us: missions all 0; `IsAlly = CalculateIsAllied(tag)`; allies to `ManageSpiesAbroadAllies`,
everyone else to `ManageSpiesAbroadNonAllies`; the priority capped at 3 and posted as `CChangeSpyPriority(us, them,
p)` where it differs; then `UpdateMissions(us, them, missions)`.

**Allies:** priority 1, or 0 for a government in exile (its missions then all 0). Missions: counter-espionage 2, plus
boost ruling party 1 where the ally's ruling party is in our ideology group (`CIdeologyGroup ==` compares the index)
and its popularity is under 65, or, where the groups differ and we are a major, boost our party 1.

**Non-allies:**

1. p = the country's `Intel_Priority(IntelligenceData, them)` override, else 0.
2. Unless they are in exile: +1 if a non-exile neighbour (`IsNonExileNeighbour`) and not a friend; +1 if both are
   majors and they are not a friend; and where their declared capital is on our continent, +1 if not a friend and +1
   if at war with them.
3. A country's `Intel_Mission` override sets its mission to 3.
4. **If p > 0**, `PickBestMissions`.
5. Priority 0 leaves every mission 0, so missions there are withdrawn; the spies are not recalled.

"Friend" is `Support.IsFriend(ai, our faction, them)` (Their Finest Hour's `ai_support_functions.lua`): if they are in
a faction, a friend iff it is ours; if in none, **not** a friend if for any faction but ours
`floor(GetCountryAlignmentDistance(them, that faction's leader):Get()) < 100`, otherwise a friend. So an unaligned
country far from every other faction's leader is a friend.

**`PickBestMissions`:** if we are a government in exile and the country controls our declared capital, military 3.
Else, not at war with them: two draws from {military, boost our party, tech}, `math.random(3)` each, the first set to
2, the second to 1 (the same mission twice ends at 1). At war: where they are a non-friend neighbour and
`GetSurrenderLevel():Get() > 0.6` (surrender progress above 600 of 1000), lower national unity 3; else two draws from
{military, tech, lower national unity}, 2 then 1. The draws may overwrite an override's 3. `math.random` is the C
runtime's per-thread `rand`, never seeded (`FINDINGS-luahost.md`), so which picks a country gets depends on which TBB
worker ran it - not reproducible (inferred).

**Overrides.** Their Finest Hour's only intelligence overrides are Germany's (`tfh/script/country/GER.lua`):
`Intel_Priority` is 3 for AUS while Germany is at peace and the year is at most 1938, and `Intel_Mission` boost our
party for AUS on the same terms. `Intel_Priority_Ally` and `Intel_Mission_Ally` are documented in `DEFAULT_LAND.lua`
and `DEFAULT_MIXED.lua` and never called.

**The base game's script is a different, older design and cannot run in this executable.** It sets one mission per
presence and holds a peace-time mission 60 days from `GetLastMissionChangeDate`; it uses the acting capital,
`IsNeighbour`, `IsInfluencing` and missions Their Finest Hour does not have (`SPYMISSION_POLITICAL`,
`_DISRUPT_RESEARCH`, `_DISRUPT_PRODUCTION`, `_SUPPORT_RESISTANCE`, `_NONE`). It fails at its first engine call -
`domesticSpyPresence:GetMission()`: no `GetMission` string is in the image (positive control: `GetPrimaryMission` at
`0x15EF538`) - and its three-argument `CChangeSpyMission` matches no overload (E.5). Their Finest Hour's file shadows
it, so this matters only to a mod that falls back to it. BlackICE ships its own `script/ai_intelligence_minister.lua`,
which was not read.

### E.3 Checked against the saves

The rules of E.2 were applied to every AI country's records with each save's own alignment positions, factions,
alliances and capitals (`map/continent.txt`) and the seven `major = yes` countries of `common/countries`; neighbours
were not modelled.

- **20 April:** of 5,929 (actor, existing target) pairs, 5,802 have exactly the predicted priority; the other 127 are
  one higher - the neighbour term - and none is off otherwise. Every mission set fits its branch.
- **8 January:** 3,845 exact, 82 one higher, none off. The one mission set outside the peace list is ETH on ITA,
  `military 1, lower national unity 2`: the at-war list, in a war.
- **The allies rule needed faction members** without a bilateral alliance block: France's minister treats IRQ, OMN,
  YEM, BHU and NEP as allies (`CE2, BOP1`), and MON and TAN treat each other so. This is what
  `CCountry::RebuildNeighbours` pass 2b does: Allies (`+0xF88`) is the bilateral alliances plus every member of our
  faction. **It settles the question `FINDINGS-scopetriggers.md` left open: faction membership does widen `ally`**
  (inferred only in that the save's alliance blocks are taken as complete).
- **Home rule:** 76 of 77 match the save's current unity and popularity; Estonia is at 69.990, drifted under 70 since
  its last change. On 8 January 50 of 51, Japan at 70.003.

### E.4 What each method answers

| method | answers |
| --- | --- |
| `CCurrentGameState.GetAIRand()` (rva `0x4E9950`) | recorded (`FINDINGS-government.md` E.4): one draw on the state's generator `+0x124`, unlocked |
| `CCurrentGameState.GetPlayer()` (rva `0x4E9620`) | `&state+0xC30`, the local player's tag; creates the state if there is none |
| `CCurrentGameState.GetCurrentDate()` (rva `0x4E96E0`) | `&state+0xBDC`, the tick (also registered as `CAI:GetCurrentDate`) |
| `CEU3Date:GetYear()` (rva `0x2EF40`), `GetTotalDays()` (rva `0x2EF70`, recorded as `CDate::GetDays`) | the year; `(tick - 43800000) / 24` |
| `CCurrentGameState.GetCountries()` (rva `0x4E9560`) | `&state+0xBBC`, every country by id, `---` first |
| `CCountry:Exists()` | owns a province (`FINDINGS-luaapi.md`) |
| `minister:GetOwnerAI()` (rva `0x4E90A0`) | `+0x54`; a folded getter (five ministers and `CBuilding::GetIndex`), so not recorded |
| `minister:GetCountryTag()` (rva `0x487FA0`) | `+0x34/+0x38`, by value |
| `CCountry:GetFaction()`, `HasFaction()`; `CFaction ==`; `GetFactionLeader()` | `FINDINGS-luaapi.md` section 5; the leader is the first member |
| `CCountry:GetCapitalLocation()` (rva `0x17AF0`) | the **declared** capital `+0xE20`, not the acting one |
| `CProvince:GetController()`, `GetContinent()`; `CContinent ==` | `+0x334`, `+0x368`; continents compare by name |
| `CCountry:IsAtWar()`, `IsMajor()`, `IsGovernmentInExile()`, `IsNonExileNeighbour(t)`, `GetRelation(t)`, `CDiplomacyStatus:HasWar()` | `FINDINGS-luaapi.md` section 6; a major is `major = yes` (the seven) or provincial IC `+0x60C` over 100 |
| `CCountry:GetSpyPresence(t)` (rva `0x44920`) | `espionage[t->id]`, a reference into the vector |
| `CSpyPresence:GetPriority()` (rva `0x7BBDD0`) | `+0x4`; a folded `mov eax,[ecx+4]; ret` (also `CCountryTag::GetIndex` and a `CList` `GetTailData`), so not recorded |
| `CSpyPresence:GetPrimaryMission()` (rva `0x12D6D0`) | the first mission with the highest priority (ties to the lower index); **9 when none is above 0** |
| `CSpyPresence:GetMissionPriority(m)` (rva `0xC8400`) | `missions[m]`, unchecked |
| `CSpyPresence:GetLevel()` (rva `0xC83F0`), `GetLastMissionChangeDate()` (rva `0xC8410`) | `+0x0` as a CFixedPoint (Get() 0 to 10); `+0x50` as a date |
| `CSpyPresence.MissionAllowed(m, a, b)` (rva `0x1305B0`) | at home only: raise national unity; abroad only: military, tech, boost our party, lower national unity, increase threat, covert ops; anywhere: counter-espionage, boost ruling party. Lua-only, and **no script and no C++ asks it** |
| `CSpyPresence.MAX_SPY_PRIORITY`, `MAX_SPY_LEVEL` | **3** and **10**, registered at `0x8EBDA8` and `0x8EBD9A` |
| `CCountry:GetSpyingOnUs()` (rva `0xE6A60`) | `+0x1028`, rebuilt daily by `RebuildNeighbours`: every other country (not `---`, not REB, owning a province), in id order, whose presence in us has **level > 0**; a fraction of a spy counts |
| `CCountry:GetNationalUnity()` (rva `0xF8B20`) | `+0x10B8`, thousandths of a percentage point; Get() is 1.0 to 100.0 |
| `CCountry:GetRulingIdeology()` (rva `0xE0580`) | `+0x1140`, the ruling party (recorded); it can be null, and the script's `:GetGroup()` would then raise a Lua error and the day's work would end |
| `CIdeology:GetGroup()` (rva `0xC89A0`) | `+0x50`, folded, so not recorded |
| `CCountry:AccessIdeologyPopularity()` (rva `0xC8830`), `CIdeologyData:GetValue(i)` (rva `0x128480`) | `&+0x10F4`; `values[i->+0x4C]` in thousandths of a percentage point, unchecked |
| `CCountry:CalculateIsAllied(t)` (rva `0xE6A30`) | `t` is in Allies `+0xF88`: a bilateral alliance **or a member of our faction** (E.3) |
| `CCountry:GetSurrenderLevel()` (rva `0xFCB80`) | `GetSurrenderProgress`, 0 to 1000; Get() 0 to 1 |
| `CEU3AI:GetCountryAlignmentDistance(a, b)` (rva `0x49A480`) | `FINDINGS-luaapi.md` section 7: the triangle distance in its own units, whose box is -200 to 200 |
| `ai:Post(cmd)` (rva `0x49A790`) | recorded: posts the slot-13 copy through the AI country's interface host |

### E.5 The two constructors from Lua

**`CChangeSpyPriority(actor, target, priority)`.** `LuabindInvoke_CChangeSpyPriority_Init` (`0x97FE40`, rva
`0x57FE40`) requires exactly 3 arguments, converts argument 1 to the actor tag and 2 to the target tag, and argument
3 must be a number, read with `lua_tointeger` (to the nearest). `LuaConstruct_CChangeSpyPriority` (`0x989940`, rva
`0x589940`) takes `(priority, actor, target)` in luabind's layout and calls the C++ constructor `0x5588F0`: actor to
`+0x3C/+0x40`, target to `+0x44/+0x48`, priority to `+0x4C`.

**`CChangeSpyMission(actor, target, mission, priority)`.** `LuabindInvoke_CChangeSpyMission_Init` (`0x980080`, rva
`0x580080`) requires exactly 4 arguments; arguments 1 and 2 are the tags, argument 3 the mission by `(int)lua_tonumber`
(truncated), argument 4 the priority by `lua_tointeger`. `LuaConstruct_CChangeSpyMission` (`0x989A20`, rva
`0x589A20`) calls the constructor `0x558E00`: actor to `+0x3C/+0x40`, target to `+0x44/+0x48`, mission to `+0x4C`,
priority to `+0x50`. The base game's three-argument call fails the argument count. The commands themselves are
section A's.

### E.6 What the AI sets, in effect

Its own country: priority 3, counter-espionage 3, plus one booster. Allies: priority 1, counter-espionage 2, plus one
booster. Others: 0 to 3 by neighbourhood, majority, continent and war, with two random picks among military, tech and
boost our party at peace, or military, tech and lower national unity at war - lower national unity at 3 against a
neighbouring enemy close to surrender. **The AI never chooses increase threat, covert ops or a coup**, and nothing in
its script reads a define.

### E.7 Germany on 1 January 1936 (inference from the files, with the start save)

Germany is the player and, not delegated, has no minister; the saves show none acting through 20 April. Were it an AI
country, at 03:00 on its first day of a 1-in-9 hit, with the start save's figures (unity 89.998, national socialist
popularity 62.5, the Axis alone, capital in Europe, no alliance):

- **Home:** counter-espionage 3 and boost ruling party 1 (unity at least 80, popularity under 65); priority 3. No
  country spying on Germany has lower national unity as its primary mission: every presence's missions are 0, so the
  primary is 9.
- **Abroad**, by the save's positions (the neighbours FRA, BEL, LUX, HOL, DEN, POL, CZE, AUS, SCH and LIT given by
  hand, inferred):

  | priority | countries | why |
  | --- | --- | --- |
  | 3 | **AUS** | Germany's own `Intel_Priority` gives 3; AUS is a friend (26 from Germany, 374 from ENG, 380 from SOV) |
  | 3 | **FRA** | neighbour, major, Europe |
  | 2 | ENG, SOV | major, Europe |
  | 2 | BEL, HOL, LUX, CZE | neighbour, and Europe within 100 of ENG |
  | 1 | USA | major; 19 from ENG, so not a friend |
  | 1 | FIN, NOR, IRE, GRE | Europe, within 100 of ENG |
  | 0 | every other existing country | |

  The 0s include ITA, JAP, POL, DEN, LIT and SCH: unaligned and at least 100 from both ENG and SOV, so "friends", and
  a friend's neighbour term counts nothing.
- **Missions:** each country above 0 gets two picks from military, boost our party and tech (2 then 1); AUS also gets
  boost our party 3 from `Intel_Mission`, which a pick of the same mission lowers to 2 or 1.

### E.8 What looks wrong and is what the bytes and scripts do

- The minister listens on seven channels and every handler it has there is empty.
- Its countdown draw is `% 10 + 1` where the politics minister's is `% 3 + 1`.
- A posted command executes, and stamps `spy_date`, the hour after the minister's.
- Allies include every faction member, bilateral alliance or not.
- "Friend" for an unaligned country means far from every other faction's leader, so the USA is not Britain's target
  and Italy and Japan are not Germany's.
- Bad spies are only a primary lower-national-unity mission, and finding them only drops the home boosters;
  counter-espionage is 3 regardless.
- A non-ally at priority 0 has its missions zeroed and its spies left in place.
- `PickBestMissions` sizes the peace list by the war list's length (both 3); `loNewMission` is a global never set, so
  its test always passes; two equal picks leave one mission at 1, and a pick can lower an override's 3.
- An `Intel_Home` override's mission replaces counter-espionage rather than adding to it.
- `humanTag`, `TotalDaysFromStart` and `BufferUsedForMissions` are unused; `Intel_Priority_Ally` and
  `Intel_Mission_Ally` are documented and never called.
- `MissionAllowed` exists and nothing asks it. The base game's script cannot run in this executable.
- `math.random` is per-thread and unseeded; `GetAIRand` is shared and unlocked.

### E.9 What was not settled

- **Why Paraguay's home record on 20 April is stamped in its own hour**, against the hour after for every other stamp.
- What drains a posted command an hour later: the +1 is read off the saves, not the bytes.
- Which slot channels 0x17 and 0x19 to 0x1C dispatch to (the minister's slots there are all empty stubs, so it
  cannot matter here).
- Germany's neighbours were given by hand; whether any country besides the seven has provincial IC over 100 in 1936
  (which would make it a major) was not checked.
- The order `pairs` visits the nine missions in (the array part, then key 0) - it changes only the order of commands.
- BlackICE's `script/ai_intelligence_minister.lua` was not read.

**Corrections made by this section:** this file's opening says luabind registers `CSpyPresence` "with GetLevel,
GetPriority, GetLastMissionChangeDate, GetMission and GetSpyPresence", and `project.json`'s `CSpyPresence` struct
comment says the same. Their Finest Hour registers `GetLevel`, `GetPriority`, `GetMissionPriority`,
`GetLastMissionChangeDate`, `GetPrimaryMission`, the static `MissionAllowed`, and the constants `MAX_SPY_PRIORITY` 3
and `MAX_SPY_LEVEL` 10; there is no `GetMission`, and `GetSpyPresence` is `CCountry`'s. `FINDINGS-ai.md` describes the
five ministers' slot 10 as alike apart from K; the intelligence minister's `Enable` draws `% 10 + 1` and subscribes to
seven channels, which the politics minister's does not. `FINDINGS-scopetriggers.md`'s open question (can a faction
member lack a bilateral alliance and still be an `ally`?) is answered yes by the saves.

**Frontier (rvas):** `0x49D160` (the minister's instance push), `0x49C960` (`CAIAgent` slots 67/68), `0x49C700`
(`CAIAgent::GetCountry`, base script only), and the three folded getters `0x4E90A0`, `0x7BBDD0` and `0xC89A0`, left
unrecorded on purpose.
