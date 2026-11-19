# Readings for BlackICE's saves: the fired events' order, and a figure past three decimals

*2026-11-19. Asked for by OpenHOI3's second stage of the BlackICE layer, which sets a BlackICE new game beside a BlackICE
start save made by the original with BiceLib loaded and only its infrastructure fix on, and nine later saves of the same
game (`Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\save games\Ireland1936_*`, made that day). Each
question below is one those saves raised and Their Finest Hour's could not.*

All addresses are VAs unless marked rva.

## 1. The order of `fired_events`: 511 buckets

The record had the mechanism and not the size. `FireEvent` (rva `0x5C0C80`) inserts a fire-once event into the registry
at `CCurrentGameState +0xC38` - bucket `((id_type << 16) + id) % bucket_count`, a node pushed at the bucket's head - and
`CGameState::SaveContents` (rva `0x27E6F0`) writes `fired_events` by walking the buckets in turn and each chain from its
head. What `bucket_count` (`+0xC3C`) is was not written down.

**It is 511, set by the base constructor.** `CGameState::CGameState` (rva `0x27D070`), read in place:

    0x67D417  mov  eax, 0x1ff
    0x67D41C  mov  [ebx+0xc3c], eax          ; bucket count 511
    0x67D422  mov  edx, 4 ; mul edx           ; 511 * 4 bytes, with the overflow flag folded in (seto/neg/or)
    0x67D42C  mov  [ebx+0xc38], esi          ; count 0
    0x67D437  call 0xb94bec                   ; operator new
    0x67D43C  mov  ecx, [ebx+0xc3c] ; add ecx,ecx ; add ecx,ecx
    0x67D44E  mov  [ebx+0xc40], eax          ; the bucket heads
    0x67D454  call 0xb99220                   ; memset(heads, 0, 511 * 4)
    0x67D45C  mov  [ebx+0xc44], edi ...       ; fired_events_loaded begin, end, capacity zeroed

Nothing else in the constructor writes `+0xC3C`, and the registry is never grown. `0x1FF` is the bucket count of the
other hash maps this engine builds (the technology database's three).

**Measured, and the measurement is what found it**: the order of `fired_events` in three BlackICE saves of one game -
10 events on 16 January, 12 on 2 February, 22 on 16 March, every one of type 40 - is ascending in
`((40 << 16) + id) % N` for **N = 511 and for no other N from 2 to 4999**. Their Finest Hour's saves hold two at most, too
few to tell.

So a save lists its fired events: bucket 0 to 510; within a bucket, the latest fired first. After a load
`ResolveSavedFiredEvents` (rva `0x280FE0`) inserts the save's events in the save's order, each at its bucket's head, so a
save written straight after a load turns round any two events that share a bucket.

## 2. `TokenToFixedPoint` keeps every digit after the point

`TokenToFixedPoint` (rva `0x669550`) was recorded as reading the fraction "padded with zeros to exactly three places". It
pads, and it does not cut. Read whole, `0xA69550` to the `ret 8` at `0xA6962D`:

    0xA69563..0xA69582   find the '.', counting characters
    0xA69591..0xA695A1   eax = eax * 10 + (c - '0') for EVERY character after the '.', edi counting them
    0xA695A3  cmp edi, 3 ; jge 0xa695b8       ; three or more digits: no padding
    0xA695A8..0xA695B6   eax *= 10 for each digit short of three
    0xA695B8..0xA695CB   negate the fraction when text[0] is '-' (whatever atoi returned)
    0xA695CD..0xA69619   fraction * 1000, then * 1000 / 1000000 - an overflow guard, the identity
    0xA69619  out = atoi(text) * 1000 + fraction

So `0.5` is 500 and `1.25` 1250 as recorded, but **`0.3375` is 3375 - 3.375 - and `0.0025` is 25, `1.0001` is 1001**: a
fraction of more than three digits is read ten or more times too large. The sign is right for every case - `-1.5` is
-1500 - since the fraction is negated whenever the text begins with `-`, not only when `atoi` answered 0.

`ParseThousandths` (rva `0x6696A0`), the checked reader `ParseFixedPoint` and `CModifier::LoadKey` use, copies at most
three digits into a `"000"` template and so cuts as one would expect: `0.0025` is 2 there. The record's
`CModifier::LoadKey` entry named that call `TokenToFixedPoint`; it is `ParseThousandths`, so modifiers - laws, event and
static modifiers, a technology's country effects, traits - are cut to three places.

**Who reads with `TokenToFixedPoint`**: 188 call sites. `CSubUnitDefinition::LoadKey` (rva `0x1A3C80`) is the one that
matters here: every one of its 44 numeric stores, `+0xE4` to `+0x1BC` - `build_cost_manpower` (`+0xFC`) and
`repair_cost_multiplier` (`+0x104`) among them - takes its value from a `call 0xa69550` straight before it (a decode of the
function from its entry, each call paired with the store after it). `CBuilding::LoadKey`'s `effect_size` and
`CSubUnitAmphibiousMult::LoadKey` were already recorded as reading with it. A technology's block for a unit type is read
through the unit files' own lookup (`CTechnology::LoadKey`), and **observed so in the running game** (2026-11-19, the
maintainer): BlackICE's division-size technology with `build_cost_ic = 0.3375` in a unit block shows **3.37** in its
tooltip - the 3.375 this reading gives, written to two places - where a cut to three digits would show 0.34.

**What it touches**: Their Finest Hour writes no figure of more than three decimals in `common`, `technologies` or
`units`. BlackICE writes three in a unit block - `build_cost_ic = 0.3375` and `-0.3375` in its division-size technologies -
and two in an event modifier (`Conscripting_Unmarried_Men_CMF`: `national_unity` and `land_organisation` at -0.0025, which
the modifier loader cuts). Its twenty `factor = 0.000000001` in events are mean-time-to-happen factors, read by
`CMTTHModifier::LoadKey` through `ParseFixedPoint`, so nought.

## 3. Not settled

- **Ethiopia's starting manpower** in the BlackICE start save is what about six points of revolt risk in its provinces
  would give, where the rule that fits every other country - the provinces made as the entry first made them, with no
  country's `global_revolt_risk` in them (OpenHOI3's `docs/mechanics/manpower.md`, section 4, measured on 77 of 79) -
  gives none. Its sources then are `initial_mobilization` (+2), `emergency_conscription` (+5) and `state_press` (-1.5); no
  combination of them and of its history's `free_press` (+4) gives six without contradicting Czechoslovakia, whose
  `free_press` counts for nothing. Not read: what the entry's first province pass sees of a country's modifier.
- **A thousandth of organisation** on 432 brigades of the start save, each country one way - Britain's above, the United
  States' below. A rounding a positive figure alone goes through cannot give both; nothing found reads differently. Not
  read further.

## 4. Measured on the same saves, with nothing read

Recorded so that a later reading can be set beside them; OpenHOI3's specs cite each.

- A new game's Lua `Laws()` runs before the country's manpower is started at its most (the record's
  `SetUpCountryForNewGame_CallLaws`): BlackICE's `conscription_law_two` script, a ratio of manpower to divisions, moves no
  law in the start save, where with the pool counted it would move 17.
- A technology declared twice (BlackICE's `cag_design_hidden`, since removed from the mod) is two technologies under one
  name: the save lists both entries, the first at 0 and the second at its level, and a look by name finds the later.
- A province's `history` holds the changes made in play - `controller`, `owner`, `add_core` and `remove_core` where the
  list changed, `manpower` and `leadership` as an effect left them - a dated block each; none in a start save.
- A brigade's `home` is the province it was made in, on a headquarters' brigade made in play and on a rebel brigade, and
  on nothing an order of battle made; a faction, its army and each brigade take the next numbers of the rebels' counter, in
  that order (type 39).
- `prov_vp` is the victory points of the provinces the country controls, 107 of 107 in two saves; `offmap_vp` is nought
  and `last_mission_cancel` the null date in every save.
- `nocategory`, the null category's ability, is taught by a technology with no `on_completion` and decays monthly:
  BlackICE's OMG, 0 to 5.000 to 4.900 to 4.802.
- A history's post takes the minister id as written, even another country's: Reichskommissariat Ural holds Ukraine's
  900004 to 900006.
- A save writes a country's variables in the order of their names, the case folded down, and none at nought - as
  `FINDINGS-negatives.md`, section 7, read.
