# A fleet's base check in the hour, the removal of a fleet with no base, and two technology effects

Read on 2026-11-20 for OpenHOI3's loose ends "a fleet's base check in its hour" and "read and not built:
`escort_efficiency`, `radar_efficiency`". Static, on the listing; nothing here was watched in the running game.

## 1. Where a unit's hour checks its base (confirmed)

`CNavy::CheckBase` (rva `0x1D01B0`) is CNavy's slot 18, and `CAir::CheckBase` (`0x1D0E20`) CAir's. `slotcalls.py 18`
finds the call that runs them every hour: the **last step of `CUnit::CheckOrderAndCombat`** (`0x5BA2F0`, CUnit slot 31,
which CNavy's override tail-jumps into):

    0x5BAC15  lea ecx, [state + 0xB5C]; call 0x430960        ; the step before
    0x5BAC20  mov edx, [esi]
    0x5BAC22  mov eax, [edx + 0x48]                          ; slot 18
    0x5BAC25  mov ecx, esi
    0x5BAC27  call eax
    0x5BAC30  add [esi + 0x9C], -1                            ; the two countdowns, after it
    0x5BAC36  add [esi + 0xA0], -1

`RunCountryHourlyPass` calls slot 31 for every unit of every country in turn on the tick thread, so **every fleet's base is
checked at the end of its hour, idle or not**, in its country's order of units. The same function also runs as a unit
block closes (`CUnit::AfterLoad`, already recorded).

## 2. The removal of a fleet with no base (confirmed)

After the country's and the faction's walks (already recorded), at `0x5D0386`:

    if fleet->base (+0x98) != 0: done
    country = countries[fleet->owner id (+0x128)]
    if country->total_num_of_ports (+0x1060) != 0: done
    state = g_CCurrentGameState, made (0xDA8 bytes, its constructor) where it is null
    CGameState::QueueUnitRemoval(fleet in EAX, state)            ; 0x5D0443

`QueueUnitRemoval` (`0x284C80`, already recorded) pushes the unit's id pair on the end-of-hour queue, whose drain removes
each live unit with `CGameState::RemoveUnit(state, unit, 0, 1)` - its officers lost, its passengers with it, what it
commanded left at the top of the order of battle (`FINDINGS-effectrun.md`, section 3.11). So the fleet is gone at the
end of the hour in which the check found nothing, and a fleet queued twice is removed once.

`total_num_of_ports` is every province the country owns with a port and a naval base built, whoever controls it and
however damaged (`FINDINGS-scriptgaps.md`): a fleet whose country still owns a port an enemy holds is left with no base
and kept.

## 3. `escort_efficiency` (confirmed)

`CConvoy::GetDefence` (`0xC7C10`), read whole on the bytes:

    defence = escorts (+0x9C) x 5000
    if the way has provinces (+0xB8):   defence = defence x 1000 / (count x 1000)     ; _allmul, _alldiv: cut towards nought
    defence = defence x (1000 + countries[convoy +0x34] -> +0xDF8 -> +0x78) / 1000      ; imul, _alldiv, 64 bits

The country is the convoy's own. `+0xDF8 +0x78` is `escort_efficiency` by `CTechStatistics`' loader
(`FINDINGS-uinumbers2.md`), which settles the name `FINDINGS-convoys.md` had by elimination. `fieldchain.py --holder
0xDF8 --index 30 --stride 4` finds this function as **the one reader** of the field.

## 4. `radar_efficiency` (likely: no reader)

`fieldchain.py --holder 0xDF8 --index 13 --stride 4` - the same search, on `+0x34` - finds **no reader**. The positive
control is section 3: the same search on the neighbouring field of the same block finds its one reader. And the radar,
read whole for OpenHOI3's intelligence (its `docs/mechanics/intelligence.md`, section 4), takes the controller's
`radio_strength` (`+0x38`) and the radar station's level, and nothing at `+0x34`. What reads the field is the technology
tooltip, which shows it as `RADAR_EFFICIENCY_TECH` (`FINDINGS-techtext.md`). So a technology's `radar_efficiency` is
loaded and shown and, as far as a static search can say, does nothing. *Not excluded*: a read through a pointer copied
off `+0xDF8` across a call, which the chain search does not follow; a data breakpoint on a country's `+0xDF8 -> +0x34`
in the running game would settle it.
