# Weather simulated: the hour, the arithmetic, and the screen

Read statically on 2026-10-15 for OpenHOI3, as the weather wave (`WAVE.md`, landed in `CANDIDATES.md`). It
consolidates and corrects `FINDINGS-weather.md`, `FINDINGS-weatherfront.md` and `FINDINGS-temperature.md`, which read
the subsystem in pieces: section A is when weather runs - in the hour and in a new game - its draws and its save;
section B every formula in instruction order; section C what the player is shown. Addresses are `VA / rva`.

## A. The hour, the new game, the draws and the save

The order of everything weather does - in an hour, in a new game before its first hour, in its random draws, across a
save and a load; the formulas are section B's. Three statements of the earlier files are corrected: the record's
"new-game setup loop at `0x3DC89`" is the `weather` console command, and the pre-roll's call is at `0x65C86A`; "two
fronts compete for a province and the first wins" is not quite what happens (A.2); `ResetZoneState` plays no part in a
new game or a load (A.4).

### A.1 Where weather falls in the hour

`RunHourlyTick` (rva `0x2813F0`): advances the date (`inc [state+0xBDC]`, `0x68155F`); reseeds the game's shared
generator from the hour's tick command (`0x681C79`); snapshots the generator; runs `RunHourlyPass` (`0x682080`); on a
change of day only, runs `RunDailyPass` (`0x68213A`). So **a game's first played hour is 01:00** - the clock moves
before the hour is simulated - and **the season lags its day by an hour**: `RunDailyProvincePass` recomputes every
climate inside the daily pass, after the midnight hour, so the 00:00 hour still uses the day before's band.

`RunHourlyPass` (rva `0x282630`), on the straight-line path `0x682630`-`0x682C1D`:

1. `0x44DE20` on `state+8` (not read).
2. **The hour and the month**: `g_CurrentHourOfDay` (`0x1A85594`) = `(tick - 43800000) % 24`; `g_CurrentMonth`
   (`0x1A85590`, 0 = January) from the day of the year walked down `MonthLengthTable` {31,28,...}.
3. `CSupply::RebuildSupplyNetwork`, only where `supply_network_dirty (+0x50)` is set.
4. **`CWeatherManager::Tick`** (rva `0xB5A20`, `0x6826F3`): fronts, high pressure, new lows (A.2).
5. Every ideology group's faction (or the null faction) has `+0xAC` reset to 0.
6. `0x68A0A0(state)`, a per-province pass (not read).
7. `RunCountryHourlyPass` for each country, serially - every unit's orders, **movement** and battle checks.
8. The unit fan-out (`CUnit::UpdateHourly`, on workers).
9. The country fan-out.
10. The AI-trade fan-out, skipped where a scenario is set; then `ai_pass_done`.
11. **The province weather fan-out** (`0x682A3B`): `UpdateProvinceWeatherRange` (rva `0x27B1C0`) on workers (A.3).
12. `RunHourlyProvincePass` for each simulated province.
13. **`CCombatManager::Tick`**.
14. `0x68A0A0(state)` again.
15. The tutorial gate.

So **movement, the unit hour and the country hour run between the two weather halves**: they see this hour's manager
tick applied - humidity, pressure, windspeed and temperature spread by the fronts and the high-pressure walk and lowered
by a new low, unclamped - and precipitation, cloud, muddyness and frozen as **last hour's** `CWeather::Update` left them.
**Only combat, last in the hour, sees the hour whole.**

### A.2 `CWeatherManager::Tick`, in order

The manager in EDI; read whole, `0x4B5A20`-`0x4B5D7C`:

```
if (cooldowns (+0x18) is empty) InitialiseWeatherState(this)      ; 0x4B5A4E
for (i over cooldowns) --cooldown[i]                              ; no floor - it goes negative
for (id in map->high_pressure_zones (+0x21C8))                    ; a list, appended in file order
    PropagateHighPressure(map->provinces[id])                     ; ECX = the province
cap = zoneCount (map +0x21D8, 8-byte records) * trunc(MAXFROMEACHPRESSURE / 1000)
while (fronts.count (+0x10) < cap) {
    f = CreateFront(this); if (!f) break
    append f at the TAIL of the list
}
for (p in state->provinces) p->weather_front (+0x14) = 0
for (node in list, from the head; next saved before the call) {
    if (!CWeatherFront::Tick(front)) {
        unlink the first node holding it (searched from the head)
        for (j, zone in map->low_pressure_zones)                   ; j = place in the WHOLE list
            if (zone.id == front->home->id) cooldown[j] = 0
        front->slot0(1)                                            ; destructor: +0x14 = 0 on every
    }                                                              ; province still on its list
}
```

- **High pressure comes before any front**, once per entry of `high_pressure_zones` in `default.map` file order: 8 in
  Their Finest Hour, starting `10737` (Azores).
- **The cap is 18 x 8 = 144 fronts**: 18 `low_pressure_zones` times `MAXFROMEACHPRESSURE` 8.
- **New fronts**: `CreateFront` is called until the cap or until it answers null, not once an hour. It starts at the
  first zone each call and returns the first that qualifies, setting its cooldown to 24..71 hours so the next call passes
  it by: **in one hour every qualifying zone gets one front, in zone file order**, up to the cap.
- **A new front goes at the tail**: it ticks last, in its first hour, and its countdown of 0 moves it at once.
- **The zone test reads a stale marker**: `CreateFront` checks "a front over the home province" (`+0x14`), which still
  holds last hour's markers - the clear comes after the creation.
- **Fronts tick in list order**: the oldest surviving first, this hour's new ones last.
- **Two index spaces**: `CreateFront`'s slot index counts only the zones whose climate mask lets them through and is not
  advanced on a mask failure; the dying-front reset indexes by the zone's place in the whole list. In Their Finest Hour
  the masks are 31 on 15 zones, 16 on `11395` and `920`, and 6 on `10597`; whenever a zone ahead in the list is masked
  out, the reset clears **another zone's** slot.

**"Two fronts compete and the first wins" is not quite what happens.** Every marker is cleared before any front ticks,
and a front writes its marker back only when it ticks, so a front earlier in the list sees a later front's provinces as
free (condition (b) of `FINDINGS-weatherfront.md` section 1) and may recruit them. When the later front then ticks: **on
a quiet hour** it re-stamps its whole list, so the province's marker ends as the later front's though both fronts hold
it; **on a move hour** it stamps, then at the end clears every province it left - the province is then on the earlier
front's list with marker 0 for the rest of the hour, a front after both may recruit it again, and `CWeather::Update`
treats it as having no front. A front that dies through the "small and far from home" exit deletes itself with its list
intact, and its destructor zeroes the marker on every province of that list, whoever recruited them this hour. All this
is the clear at `0x4B5C7C`, the early exits of `CWeatherFront::Tick` before its re-stamp (`0x4B472A`, `0x4B4763`) and
the unconditional destructor (`0x4B45E5`).

### A.3 The province pass

`UpdateProvinceWeatherRange` (rva `0x27B1C0`), a TBB range `{end, begin, grain}` in EAX; for each index from `begin` up
to `end`, for each province whose template `+0x13D` (simulated) is set:

```
province->is_night (+0x2C) = IsNight(province, g_CurrentHourOfDay, g_CurrentMonth)
CWeather::Update(&province->weather)
name = CWeather::GraphicName(&province->weather)          ; a pointer to one of seven strings
if (name != province->+0x98) { province->+0x9C = 1; province->+0x98 = name }
```

**Nothing in the pass reads another province**: `IsNight` reads the province's template and the map width;
`CWeather::Update` (read whole in its decompilation) reads its own `CWeather`, its province's template, terrain and
modifier array, its `+0x14` and `+0x30`, and the global date inside `ComputeProvinceClimate` - **it never dereferences
the front**, only tests `+0x14` against 0; `GraphicName` reads the defines. So the split over workers cannot change a
result, and a serial loop in any order gives the same answer.

**`IsNight` (rva `0xA7390`)**, read whole; province in EDI, hour and month on the stack, `ret 8`:

```
local = (template->position_x (+0x64) * 24 / map->width (+0x2A74) + hour + 12) % 24
m     = template->+0xA2 ? month : (month + 6) % 12          ; +0xA2 set = northern half
q     = trunc(trunc(latitude_north (+0x388) * DayLength[m] / 1000) * 1000 / 2000) / 1000
night = (local < 6 - q) || (local > 18 + q)
DayLength = {-6000, -3000, 0, 3000, 6000, 12000, 6000, 3000, 0, -3000, -6000, -12000}
```

All divisions truncate toward zero. The middle column of the map keeps the game's hour; wherever `latitude_north` is 0 -
the whole southern hemisphere - day is 06 to 18 inclusive; at latitude 950 June gives q = 5, night only at local hour 0,
and December q = -5, day only from 11 to 13.

### A.4 The new game

Before `CInGameIdler::Enter` (rva `0x25A2B0`) runs, `CGameState::ResetSession` has called **`CProvince_ResetState`**
(rva `0x96480`) on every province - climate `+0x30` 0, front marker `+0x14` 0, humidity, windspeed, temperature,
precipitation, muddyness, frozen and cloud 0, **pressure `g_PRESSUREDEFAULT`**, the front cache 0 - and deleted every
live front. **It does not touch the zone cooldowns and headings.** Then, in `Enter`'s own order:

1. **Every province, new game and loaded alike** (`0x65AE30`-`0x65AFBD`, after `ADAPTING_HISTORY`):
   `RebuildProvinceModifierValues`, `ComputeProvinceLatitude`, `ComputeProvinceClimate` for the start date.
2. **Every province again, both kinds of session** (`0x65BD12`-`0x65C01C`, ending "provinces initialised<"):
   `UpdateProvinceNightFlag` (rva `0xA7210`) sets the two globals from the start date and writes `is_night` for hour 0;
   **for a new game only, `temperature = CWeather::BaseTemperature(&weather)`** (`0x65BF63`) - the province's target with
   this night flag and this climate, cloud, rain, frozen and wind still nought, so the cloud, cold-rain and wind-chill
   terms add nothing; then the modifier rebuild.
3. The supply network (`0x65C611`), "supply logic defined<".
4. **The weather pre-roll**, skipped for a loaded session (`loaded_from_save +0xD9C`, `0x65C7FA`) and in a tutorial
   (`+0xD9D`), after `RebuildStrategicResourceProvinces`:

   ```
   hours = trunc(INITIAL_SIMULATION_HOURS_AHEAD / 1000)      ; read off the defines, 96 in TFH
   n = number of provinces                                    ; taken once
   repeat hours times:
       CWeatherManager::Tick(&state->weather)                 ; 0x65C86A
       for (i = 0; i < n; ++i) CWeather::Update(&provinces[i]->weather)
   ```

   **No simulated-flag test, no `IsNight`, no `GraphicName`, and the date never moves**: all 96 hours run with the night
   flag and climate of 00:00 on the start date. The province loop is serial in index order, which by A.3 does not
   matter.
5. `0x688000`, then **the first day's `RunDailyPass`** ("processed intel setup <").
6. `RunSupplyAndConvoyIterations`: **the second day's `RunDailyPass`, `RunMonthlyPass`, and one `RunHourlyPass`**
   (`FINDINGS-supplypass.md` section 7). The two daily passes recompute every climate for the same date, so the bands
   do not change; the hourly pass is a full weather hour (A.1-A.3) at hour 0 and month 0, with night and pictures.
7. `in_game` = 1 (`0x65D126`).

**So a new game has run 97 weather hours before its first tick, and the start save is written after them** - 96 of
tick and update with the clock stopped, one whole. `Germany1936_01_01_00.hoi3` holds 21 fronts and every province's
weather as those hours left it. **A loaded game runs steps 1 and 2 without the temperature seed, and none of the rest.**

**When the defines take effect**: `CWeatherManager::Tick` calls `InitialiseWeatherState` only while the cooldown vector
is empty, and only the manager's destructor (rva `0x27D980`) empties it, which no session reset or load reaches. So in an
ordinary process it runs once, in **the first hour of the first game the process simulates**, and that is when the
weather defines are first copied into their globals; before that the built-in values stand - `g_PRESSUREDEFAULT`
1013.000, Their Finest Hour's define, so step 0's reset agrees with it. A mod that changes `PRESSUREDEFAULT` gets 1013.000
in the first game of a process and its own value after.

**`ResetZoneState` (rva `0xB59C0`) plays no part in a new game or a load.** Its only caller,
`RebuildEventCandidatesAndDailyCaches` (rva `0x282510`), is reached from `CReopenLobby::Execute` (once a session, while
`Session +0x236` is 0, after which it sets the byte) and from `CInGameIdler::StartGame` (the in-game screen's slot 67,
called only by `CStartGame::Execute`, which the in-game lobby's start button posts), only where `Session +0x236` is set;
that byte (`lobby_reopened`) is set only by `CReopenLobby::Execute` and the hot-join handler. **So in an ordinary game
the cooldowns and headings are never reset**: in a fresh process they start at 0, and a second game started or loaded in
the same process inherits the first game's.

### A.5 The draws

Weather takes exactly three draws, all on **the game's shared MT19937** (`g_random_seed` at `0x1710F80`, through
`Random`, rva `0x6A2F80`, and `RandomThousandths`, rva `0x6A2FD0`): **the heading**, `RandomThousandths()` = `draw %
1000`, drawn only where the zone's cached heading is 0 (otherwise it is advanced by `1000000 / MAXFROMEACHPRESSURE` =
125, no draw); **the zone cooldown**, `24 + Random() % 48`; **the new low's depth**, `Random() % trunc(LOWPRESSUREOFFSET
/ 1000)`, 0..99, the drop `LOWPRESSUREBASE + 1000 x` it. Nothing else in weather draws - not the front tick, the spread,
the high-pressure walk, the update, the base temperature, the clamp or the picture; none touches the generator's state
or index (`0x1711940`), where the same search finds five touches in `RunDailyProvincePass` as a positive control. The
draw is never negative (`MT19937Next` clears bit 31).

**Order**: all three happen in step 3 of `CWeatherManager::Tick` - per front created, heading (where drawn), cooldown,
depth, fronts in zone file order. In the hourly path nothing between the reseed (`0x681C79`) and the manager tick
draws, as far as the calls there were followed, so **weather's draws are the first of each hour** (*inferred*: those
calls were scanned for draws, not read through). **The pre-roll has no reseed**: its 96 hours draw one stream from
wherever the front end left the generator, and the first days continue it.

### A.6 Save and load

**A save keeps**:

- **a province's weather**: `CWeather::SaveContents` (rva `0xB1FF0`) writes each of `humidity`, `pressure`,
  `windspeed`, `temperature`, `precipitation`, `muddyness`, `frozen` and `cloud_coverage` **only where it is not
  nought**, and **`pressure` only where it is not `PRESSUREDEFAULT`**; the front cache and the back pointer are not
  saved. *Measured*: over the 14,168 province weather blocks of `Germany1936_01_01_00.hoi3` and of `_01_08_02`, no key
  reads 0.000 and no `pressure` 1013.000 (7,519 and 9,646 pressure keys).
- **the fronts, and only the fronts**: `CWeatherManager::SaveContents` (rva `0xB5F60`) writes under the game's `weather`
  key one `front={ direction rotation speed home provinces }` a front, **in list order**. *Measured*: the start save's
  block has 21 fronts and no other key, `_01_08_02`'s 29.
- **not**: the per-zone cooldowns (`+0x18`) and headings (`+0x28`); `is_night`, climate and `latitude_north`; the front
  marker and the pressure-walk scratch; the picture (`+0x98`/`+0x9C`).

**A load**: `ResetSession` deletes the live fronts and resets every province with `CProvince_ResetState`, so an absent
key reads back as 0, or `PRESSUREDEFAULT` for pressure, and the round trip is exact; the parse fills the weather keys and
appends each `front` at the tail in file order, keeping its `speed` countdown, `direction`, `rotation`, `home` and
provinces, without stamping `+0x14` (the manager's AfterLoad is the empty stub); `Enter`'s loaded path recomputes
latitude, climate and the night flag for the saved hour and runs no temperature seed, pre-roll or first days.

**The first hour after a load** has every front marker at 0 when `CreateFront` runs, so a front over its home stops no
zone; and **in a fresh process every cooldown and heading is 0**, so every qualifying zone may spawn that hour with a
freshly drawn heading, up to its 8 and the global 144 - a burst of new fronts the saved game would not have had. In a
process that has run a game, the cooldowns and headings are that game's.

### A.7 What looks wrong but is what the bytes do

- A new game's 96 pre-roll hours never move the clock and never update the night flag or the picture: night and season
  are frozen at 00:00 on the start date, and the provinces outside a scenario are updated too.
- The zone cooldowns decrement without a floor.
- A dying front resets the cooldown of its zone's place in the whole list, while `CreateFront` reads and writes by the
  zone's place among those its mask lets through; with a masked zone ahead the reset clears another zone's cooldown.
- Markers are cleared before any front ticks, so an earlier front can recruit a later front's provinces, and a province
  can sit on two fronts' lists, or on one with marker 0.
- A dying front's destructor clears the marker on every province of its list, unconditionally.
- The cooldowns and headings are never saved and survive a session reset.
- The weather defines take effect only at the first weather tick a process runs.
- The midnight hour uses the day before's climate band.
- `ConsoleCmd_Weather` (rva `0x3DA80`, the `weather <num>` console command) calls `InitialiseWeatherState`
  unconditionally, appending a second set of zeros to the heading vector; only the first set is ever indexed.

### A.8 Not settled

- **Whether nothing between the hourly reseed and the manager tick draws**: the calls there (`0x6D7F10`, `0x644670`,
  the dialog code, `0x44DE20`) were scanned, not read through.
- **The seed the generator holds during a new game's pre-roll**: the front end appears to hand one round in a command
  (`0x6F45FC`, from `0x174DA94` and the draw count), and `0x311EA0` takes it from a timer; neither read through.
- **Whether the in-game lobby, and so `CStartGame`, appears in a single-player game.** It matters only where `Session
  +0x236` is set, which no single-player path found sets. *A screenshot would settle it*: after a single-player load
  completes, is there a lobby window with a start button over the map, or is the map live at once?
- **`CProvince_ResetState`'s remainder**: that it leaves `+0x2C`, `+0x98`/`+0x9C`, `+0x388` and `+0x10` alone rests on
  a linear decode of a 650-instruction body (trap 9).

**Frontier** (rvas): `0x4DE20` (the first call in `RunHourlyPass`), `0x28A0A0` (the per-province pass run twice an
hour), `0x2470D0` (the hot-join handler), `0x288000` (`Enter`, after the pre-roll), `0xA6C30` (`Enter`'s per-province
call after the temperature seed), `0x311EA0` and `0x2D7AD0` (the seed's origin), `0x2913F0` (`CIngameLobby`'s
constructor and its `+0x236` reads).

---

## B. The arithmetic, whole and in order

Read from the listing, instruction by instruction. Checked against the maintainer's saves `Germany1936_01_08_02.hoi3`
and `_03`, one hour apart, and against Their Finest Hour's `tfh/map/cache/adjacencies.bin` with `provinces.bmp`,
`definition.csv`, `default.map` and `positions.txt`. No interface text or localisation key is involved.

### B.0 Conventions

- **Every quantity is an integer in thousandths.** A product `a x k / 1000` is a 64-bit product (`__allmul`) followed
  by `__alldiv`, which **truncates toward zero**. Every `/` below is C division.
- **A constant written `floor(N.5f)` is compiled in** - a static set by its own CRT initialiser, or an inline `floorf`
  and `_ftol2_sse`. No `defines.lua` entry moves it.
- **Define values are Their Finest Hour's** (`tfh/common/defines.lua`, `weather`):

| define | value |
| --- | --- |
| `PRESSUREMIN` | 870 |
| `PRESSUREMAX` | 1090 |
| `PRESSUREDEFAULT` | 1013 |
| `PRESSURESTEP` | 5 |
| `PRESSUREREDUCTION` | 2 |
| `PRESSUREPROPAGATION` | 10 |
| `PRESSURETHRESHOLD` | 300 |
| `MAXHUMIDITY` / `MINHUMIDITY` | 100 / 0 |
| `MAXFROMEACHPRESSURE` | 8 |
| `CLOUDCOVERAGETEMPERATUREDROP` | 8 |
| `HOURLYFROZENINCREASE` (HFI) | 0.01 |
| `HOURLYTHAW` | 0.01 |
| `TEMPERATURECHANGESPEED` (TCS) | 0.1 |
| `WEATHERMOVEMENTDELAY` | 2 |
| `LOWPRESSUREBASE` / `LOWPRESSUREOFFSET` | 100 / 100 |

- **Which cached global holds which define** is taken from `InitialiseWeatherState`'s copier, not from the file's
  initial values: the file has 870 at `0x170CA94` and 1090 at `0x170CA98`, and the copier writes `PRESSUREMIN` into
  `0x170CA98` and `PRESSUREMAX` into `0x170CA94`.

### B.1 `CWeather::Update` (`0x4B2590 / 0xB2590`)

`this` (the `CWeather`) in EDI, no stack arguments, a bare `ret` at `0x4B2AD3`; once an hour for every simulated
province.

```
province = this->province                         ; CWeather +0x2C
land     = province->template->is_land            ; +0xD4 -> +0x22
; 0. the front and the wind
if (province->weather_front == 0) {               ; CProvince +0x14, read live
    windspeed = windspeed * 750 / 1000            ; floor(750.5)
    this->front = 0                               ; CWeather +0x28
} else this->front = province->weather_front

; 1. humidity
t = max(temperature, 0)
if (land) cap = terrain.humidity * 5000 / 1000    ; CTerrain +0x60, i.e. x5
else    { cap = 5000; t += 10000 }
if (humidity >= 1000) t = t * 1000 / humidity     ; last hour's humidity
pNorm = (pressure - PRESSUREMIN) * 1000 / (PRESSUREMAX - PRESSUREMIN)
humidity += ((1000 - pNorm) * t / 1000) * cap / 1000   ; the 1000 is [0x170CAEC], file-set

; 2. cloud - this hour's humidity, last hour's temperature
ratio = temperature > 0 ? (humidity * 1000 / temperature) * 10 : humidity
thr   = 50000 - terrain.precipitation - (land ? 30000 : 0)    ; CTerrain +0x64
if (ratio >= thr && humidity > 0) cloud += front ? 100 : 200
else                              cloud -= 50

; 3. precipitation
precipitation = 0
thr = land ? (front ? 500*1000/2000 = 250 : 0) : 500
if (cloud > thr) precipitation = 2000 * (cloud - thr) / 1000
if (!front) { cloud    -= precipitation * 200 / 1000
              humidity -= 10000 * precipitation / 1000 }

; 4. land only (0x4B280B jumps over it at sea)
infra = mods[12] * (1000 + mods[13] + mods[14]) / 1000   ; CProvince +0x114, +0x60/+0x68/+0x70
infra = min(max(infra, 10), 1000)                         ; 10 = floor(10.5), the shared static
if (precipitation > 500 || (frozen > 0 && temperature >= -5000))
     muddyness += (1000 - infra) * 50 / 1000
else muddyness -= max(infra * 5 / 1000, 2)
if (temperature > 15000)      muddyness -= 5
else if (temperature < -5000) muddyness = 0
if (temperature < 0 && precipitation > 250) {
     if (temperature < -5000) frozen += HFI                ; else: NOTHING
} else if (temperature < -10000 && frozen < 500) frozen += 200 * HFI / 1000
  else if (temperature < -2000  && frozen < 250) frozen += 100 * HFI / 1000
  else if (temperature > 0)                      frozen -= HOURLYTHAW

; 5. temperature
step   = land ? 2 : 1
target = BaseTemperature(this)                   ; B.2: reads the values above, unclamped
if (target > temperature + 10000) step *= 10
if (target < temperature - 10000) step *= 10
else if (target < temperature - 5000) step *= 5  ; cooling only - no x5 for warming
if (TCS > 0 && climate == 3) step *= 10          ; climate computed first if 0
if (TCS < 0 && climate == 5) step *= 2           ; dead while TCS > 0
delta = step * 1000 * TCS / 1000
if (temperature > target) temperature -= delta
else                      temperature += delta   ; equal moves UP; no stop at the target

; 6. pressure
if (pressure < PRESSUREDEFAULT && (land || province->weather_front == 0))   ; +0x14 live, not +0x28
    pressure += PRESSURESTEP                     ; may pass PRESSUREDEFAULT
; 7.
CWeather::Clamp(this)
```

**Clamping happens once, at the end.** From step 2 on cloud can be -0.050 or up to 1.200, precipitation up to 2.400 -
so the no-front humidity drain can reach 24.000 in an hour - and frozen can pass 1.000. The muddyness and frozen tests
and `BaseTemperature` all see these unclamped figures. Step 4's tests read last hour's temperature, this hour's
precipitation and last hour's frozen; muddyness is stepped before frozen.

**Step sizes with TCS = 0.1**: land 0.2, 1.0 (x5), 2.0 (x10) or 20.0 (x10 x10) an hour; sea 0.1, 0.5, 1.0, 5.0 or
10.0. In the `01_08_02` -> `_03` saves the front-free steps are exactly these: land 0.2 x7215, 2.0 x2961, 1.0 x62; sea
1.0 x2245, 0.1 x755, 0.5 x73, 5.0 x2.

**Muddyness** rises at most 0.0495 an hour (at infra 10) and **not at all at infra 1.000**; it falls at least 0.002; above
15 C a further 0.005 comes off after either branch.

### B.2 `CWeather::BaseTemperature` (`0x4B22E0 / 0xB22E0`)

`out` in ESI, the `CWeather` on the stack, `ret 4`, answers `out`. It confirms `FINDINGS-temperature.md` section 1 in
order. The switch tests climates 3, 4, 1, 2, 5; any other value adds nothing.

| climate | season term | latitude (`+0x388`) | extra | night (`CProvince +0x2C`) |
| --- | --- | --- | --- | --- |
| 3 | +5.000 | - | - | -2.000 |
| 4, 2 | +1.000 | - | - | -2.000 |
| 1 | -1.000 | > 950: -1.000; > 650: -1.000 | - | -2.000 |
| 5 | -4.000 | > 950: -2.000; > 650: -4.000 | wind chill | -5.000 |

- **The wind chill (climate 5)**: if `out < -3.000` and `frozen >= 1.000`, `out -= 125 x windspeed / 1000 + 5.000`; the
  125 is `floor(125.49999f)`.
- **The start value** is `template +0x8`: `climate.bmp` and the terrain's temperature.
- **For every climate, afterwards**: if `out > 10.000` or the province is sea, `out -= cloud x
  CLOUDCOVERAGETEMPERATUREDROP / 1000`; then, if `out < 3.000` and `precipitation > 0`, `out -= 4.000`.
- Every comparison is strict but `frozen >= 1000`.

**The unclamped inputs matter**: for a clear sky that lost cloud this hour the cloud read here is -0.050, and the cloud
term then *warms* the target by 0.400 - always at sea, on land only where the target is above 10 C.

### B.3 `CWeather::Clamp` (`0x4B2210 / 0xB2210`)

`this` in EAX, bare `ret`, in this order: windspeed [0, 200.000]; temperature [-50.000, 50.000]; humidity
[`MINHUMIDITY`, `MAXHUMIDITY`]; muddyness, frozen and precipitation [0, 1.000]; pressure [`PRESSUREMIN`,
`PRESSUREMAX`]; cloud [0, 1.000]. Only `Update` and the front's constructor call it.

### B.4 `CWeatherFront::Tick` (`0x4B4620 / 0xB4620`)

The front on the stack, `ret 4`, answers a bool.

```
if (--f.move_countdown > 0) { for p in f.provinces: p.weather_front = f; return true }
n = f.count                                        ; before anything changes
f.move_countdown = WEATHERMOVEMENTDELAY / 1000
arc = 200;  if (n < 3) arc += 150
if (n > 30)  arc = arc * 1000 / 2000
if (n > 100) arc = arc * 1000 / 2000
f.direction += f.rotation
f.rotation   = f.rotation * 800 / 1000             ; toward zero: 10,8,6,4,3,2,1,0 -> 34 in all
if (n < 1) return false
if (n < 4 && DistanceBetweenProvinces(f.provinces.first, f.home) > 4000) return false
local = copy of f.provinces in order (each stamped weather_front = f); clear f.provinces
for p in local (list order):
    if (p.pressure >= PRESSUREDEFAULT) continue          ; no SpreadWeather either
    recruited = []; spread = false
    for edge in p.template.edges (vector order, CProvinceTemplate +0x90):
        q = province[edge.to]
        if (q.weather_front != 0) continue               ; this front or any other
        if (q.pressure - PRESSURETHRESHOLD > p.pressure) continue
        if (local.count > 100 && spread) continue        ; local.count, NOT f.count
        if (!IsAngleWithinArc(f.direction, edge.bearing, arc)) continue
        spread = true
        recruited.append(&q.weather); q.weather_front = f; f.provinces.append(q)
    SpreadWeather(&p.weather, recruited)                 ; even when recruited is empty
for p in local: p.weather_front = 0
return f.count > 0
```

- **`DistanceBetweenProvinces`** is `isqrt(16 x (dx^2 + dy^2))` over the bounding-box centres (`+0x2C`/`+0x30`), dx
  folded to the short way round where `|dx|` exceeds half the width; Newton's method from s/2, answering floor(sqrt s),
  four times the pixel distance.
- **The new list order** is the leaving provinces in their own order and within each the recruits in edge order, which
  fixes both the next move's walk and the order `SpreadWeather` writes in.

### B.5 `SpreadWeather` (`0x4B42B0 / 0xB42B0`)

`from` and `to` on the stack, `ret 8`.

```
rain = from.humidity * 980 / 1000
from.humidity -= rain / 5                 ; computed as rain*1000/5000, truncated; once
for t in to (list order):
    t.humidity += rain
    wd = (from.windspeed - t.windspeed) * 970 / 1000       ; may be negative
    dp = t.pressure - from.pressure
    if (dp > 0) { t.pressure -= dp * 980 / 1000            ; computed as + (-dp)*980/1000
                  wd = max(dp * 250 / 1000, wd) }
    t.windspeed += wd
    t.temperature += clamp((from.temperature - t.temperature) * 950 / 1000, -10000, 10000)
```

The four constants are statics: 980, 970, 250 and 950. Nothing is clamped here.

### B.6 `IsAngleWithinArc` (`0x4B4490 / 0xB4490`)

Three `int`s on the stack - `value`, `centre`, `half` - cdecl, bare `ret`.

```
hi = (centre + half) % 1000;  lo = (centre - half) % 1000     ; C %, sign of the dividend
return lo < hi ? (lo <= value && value <= hi) : (value >= lo || value <= hi)
```

`Tick` calls it as **(value = the front's direction, centre = the edge's bearing, half = arc)** - the pushes and the
decompiler agree. So the centre is a bearing in 0..1000 and is never negative; a bearing below `half` gives a negative
`lo` and no wrap, and a direction near 1000 is then refused though within the arc; **a bearing of 1000 wraps** (`lo =
1000 - half`, `hi = half`) and a bearing of 0 does not, so the 776 due-west edges stored as 1000 behave differently from
the 15 stored as 0; **the direction is compared raw** - it drifts up to 34 past its birth value, to 1034 or -34; above
1000 it passes only windows that wrap, and every one of them; below 0 it passes a non-wrapping window only from bearing
0 to about `half`, and every wrapping one. `lo == hi` would accept everything but needs `half` = 0 (mod 500), which never
happens.

### B.7 `CreateFront` (`0x4B5D80 / 0xB5D80`) and the front's constructor (`0x4B44E0 / 0xB44E0`)

`CreateFront` takes the manager on the stack, `ret 4`.

```
i = 0
for zone {id, mask} in CMap +0x21D8, in file order:
    p = province[id]; if (p.climate == 0) ComputeProvinceClimate(p)
    if (!(mask & (1 << p.climate))) continue          ; i NOT advanced
    if (p.weather_front)       { ++i; continue }
    if (cooldown[i] > 0)       { ++i; continue }      ; manager +0x18
    cooldown[i] = 0
    if (#live fronts with home.id == id >= MAXFROMEACHPRESSURE/1000) { ++i; continue }
    d = heading[i]                                    ; manager +0x28
    if (d == 0) d = RandomThousandths()               ; r % 1000, 0..999   [draw 1, only here]
    else { d += 1000000 / MAXFROMEACHPRESSURE         ; 125 at 8 (raw 8000); -1 if 0
           if (d > 1000) d -= 1000 }                  ; 1000 itself is kept
    heading[i] = d
    cooldown[i] = 24 + Random() % 48                  ; 24..71 hours   [draw 2]
    rot = 10; if (p.template.northern_hemisphere) rot = -10
    return new CWeatherFront(p, d, rot)
return null
```

**The constructor**, everything on the stack, `ret 0x10`: `home` becomes the front's only province; `rotation` = rot,
`move_countdown` = 0 (so the first `Tick` moves it), `direction` = d, `home` = p; **[draw 3]** `home.pressure -=
LOWPRESSUREBASE + 1000 x (Random() % (LOWPRESSUREOFFSET/1000))` - 100.000 to 199.000 with Their Finest Hour's values;
`Clamp(&home.weather)`.

**Both generators are the game's shared MT19937**: `Random` (`0x6A2F80`) and `RandomThousandths` (`0x6A2FD0`), neither
answering a negative number. Within one front's birth the draws are `RandomThousandths` (only where the cached heading
is 0), then `Random` for the cooldown, then `Random` for the depth. The first eligible zone in file order wins; neither
per-zone vector is bounds-checked against `i`; a heading drawn as 0 is cached as 0 and so drawn again next time.

### B.8 `PropagateHighPressure` (`0x4B6050 / 0xB6050`)

The **seed province** in ECX (not the manager - the record's `CWeatherManager::` prefix is misleading), bare `ret`.

```
for every province: dist = 99999                          ; CProvince +0x10
seed.pressure = PRESSUREMAX; seed.dist = 0
queue = [seed]                                            ; FIFO: pop head, push tail
while queue: c = pop
    for edge in c.template.edges (vector order):
        n = province[edge.to]
        d = n.template.size_class + c.dist                ; +0x24, 1..4
        if (n.dist <= d) continue                         ; relax only on strictly cheaper
        target = PRESSUREMAX - (d*1000) * PRESSUREREDUCTION / 1000     ; = 1090000 - 2000*d
        if (target <= n.pressure) continue                ; dist NOT updated, walk stops here
        n.pressure += PRESSUREPROPAGATION                 ; one step; may pass the target
        n.dist = d
        if (target > 0) push n
```

A province can be raised and queued more than once in one propagation, when a cheaper way to it turns up while it is
still below that way's target; the walk does not pass through a province already at or above its target; each high
runs separately, so a province reached by two highs is raised twice in the hour; nothing here clamps. In the saves, 55
front-free provinces below 1013 rose by 15.000 (a propagation step and the hourly step), one by 10.000, 1,327 by 5.000.

### B.9 `ComputeProvinceClimate` (`0x4A81A0 / 0xA81A0`) and `ComputeProvinceLatitude` (`0x4963F0 / 0x963F0`)

**Latitude**:

```
half = height / 2                                     ; CMap +0x2A78
dy   = max(template.label_y - half, 0)                ; +0x60, the bbox centre y
latitude = dy * 1000 / half                           ; -1 if half == 0
```

`label_y` is `min + (max - min + 1)/2`, copied from `+0x30` in `ComputeProvinceGeometry` at `0x491827`; nothing later
changes it.

**Climate** writes 3 first, then picks a band. Where `template +0xA2` (the **northern** hemisphere) is set: A=1, B=2,
C=3, D=4, E=4, F=5; where clear: A=4, B=4, C=5, D=1, E=2, F=3.

```
if (latitude <= 250) return                                    ; floor(250.5)
a = (latitude - 250) * 1000 / 750                              ; floor(750.5)
L = (a * 183000 / 1000) / 1000                                 ; = floor(a*183/1000)
W = 91;  X = 183 - L
days = (clock(CCurrentGameState +0xBDC) - 43800000) / 24
doy  = days - (int)(float)((int)(days / 365.0) * 365.0)
d    = doy - L/2
F: d <= 0     A: 1..45     B: 46..91     C: 92..91+X
D: 92+X..136+X     E: 137+X..182+X     F: d > 182+X
```

Band widths F = L days, A 45, B 46, C 183 - L, D 45, E 46; F is centred on 1 January. The whole southern hemisphere
has latitude 0 and so is always 3.

### B.10 The edge bearing (`CProvinceTemplate::MeasureEdges`, `0x4A9E70 / 0xA9E70`; the call at `0xC0BDBA`)

**The two points**: `s` this province's unit point and `t` the neighbour's (`+0x64`/`+0x68`); **land to sea**, `s` is
this province's naval base position; **sea to land**, `t` is the neighbour's naval base position - `building_positions
[naval_base]` at `+0x258`, floats at `+8`/`+0xC`, truncated; **where `positions.txt` gives no `naval_base`, it is the
bounding-box centre** (`min + (max - min + 1)/2`), not the unit point.

```
if (sx - tx > width) tx += width; else if (sx - tx < -width) tx -= width   ; full width: never fires
y = (float)(sy - ty);  x = (float)(tx - sx)
a = (float) atan2(y, x)                      ; _CIatan2: x87 fpatan at 64-bit precision
b = (float)(a / 6.2831854820251465)          ; 2pi as a float, widened
c = (float)(b + 0.5)
e = (float)((float)(c + 0.0005000000237487257) * 1000.0)
bearing = (int)floorf(e)
```

East 500, north 250, south 750, exactly west 1000 (atan2 of +0 and a negative x is +pi); 0 only slightly north of
west. **It reproduces all 83,596 edges of `tfh/map/cache/adjacencies.bin`** - 56,858 land-land, 19,116 sea-sea, 7,622
land-sea - and two positive controls fail as they should: wrapping x the short way breaks 174 sea-sea edges across the
seam, and taking the unit point as the default naval base breaks 118 land-sea edges of the 50 coastal provinces with no
`naval_base` entry. A plain double version also reproduces every edge, so on this map the float steps never decide a
bearing; they are still what the code does.

### B.11 What the saves confirm (`01_08_02` -> `01_08_03`)

| check | result |
| --- | --- |
| windspeed decay, front-free | 13,313 of 13,313 |
| frozen as read, front-free land | 10,238 of 10,238 (the old table: 10,208) |
| humidity, cloud and precipitation together, front-free sea with an unambiguous pressure | 2,950 of 2,950 |
| temperature step sizes | all in the allowed set |
| pressure changes | consistent with B.1 step 6 and B.8 |

**A save writes no `pressure` key where it is 1013.000**: none of 14,168 province blocks has `pressure=1013.000`, and
4,521 have no key; so a missing pressure means `PRESSUREDEFAULT`, not nought (*inferred*; section A).

### B.12 Corrections to the earlier files

- **`FINDINGS-weatherfront.md` section 4**: the frozen table's first case is `temperature < 0 && precipitation >
  0.250`, inside which only below -5 C does anything happen; the muddyness gate is `frozen > 0 && temperature >=
  -5.000`, so at exactly -5.000 the ground gets muddier.
- **`FINDINGS-weatherfront.md` section 1 (d)**: the over-100 test counts the front before the move.
- **`FINDINGS-temperature.md` section 11**: "`IsAngleWithinArc`'s `%` on a negative centre" is wrong - the centre is
  the bearing; the direction is what drifts, and it is compared raw.
- **`FINDINGS-temperature.md` section 3**: the pseudo-code's bound for D is a day too long; the bytes end D at `136 +
  X`, which its own table (D 45 days, E 46) already says.
- **`FINDINGS-mapbuild.md` section 6**: its formula wraps x by the map width and the code does not; "land-sea edges are
  computed some other way" is the naval base, with the bounding-box default.
- **`FINDINGS-movement.md` section 6**: "the base game gives every land province that touches the sea a `naval_base`
  position" is false - 50 do not, and their default is the bounding-box centre.
- **`project.json`**: `CWeather::Update`'s comment still said 0.980, and `+0xA2` was still `southern_hemisphere`; both
  are fixed.

### B.13 What looks wrong but is what the bytes do

- Frozen ground between -5 and 0 C under rain above 0.250 neither freezes nor thaws.
- `BaseTemperature` reads unclamped figures: a cloud of -0.050 warms the target by 0.4 C, and frozen can be above 1.000
  for the wind chill.
- The temperature step overshoots the target, moves up when equal to it, gives the x5 to cooling only; the climate-5 x2
  is dead while TCS is positive.
- The pressure step can pass `PRESSUREDEFAULT`; a high's step can pass its target, and a province can be raised twice in
  one propagation.
- A front province below `PRESSUREDEFAULT` loses a fifth of its rain-humidity every move, even when it recruits nothing.
- The arc test is asymmetric for bearings below `half`; bearing 0 is not bearing 1000; the direction is never reduced
  mod 1000.
- The bearing ignores the map seam: an edge across the date line points the long way round.
- Muddyness never rises at infra 1.000.
- `CreateFront`: a zone failing its mask does not advance the per-zone index; a cached heading of 1000 is kept; a
  heading of 0 means "draw a new one".
- `default.map`'s own comment on `low_pressure_zones` reads "2 = spring, 4 = summer, 8 = autumn, 16 = winter", a band
  off the code's `1 << climate`: `16` is climate 4, northern autumn, and `31` misses climate 5, northern winter - so the
  White Sea and Siberia zones (`= 16`) spawn in autumn, not winter.

### B.14 Not settled

- The x87 precision of the bearing's later steps: Direct3D 9 may have set 24-bit precision, and `_CIatan2` forces
  0x133F; it makes no difference on Their Finest Hour's map, where the double formula gives 83,596 of 83,596, but a
  mod's map could in principle hit a boundary.
- Where the bounding-box default for a missing `naval_base` is written: established from the cache, not read - very
  likely the `building_positions` resize in `ComputeProvinceGeometry` just after the centre is set (`0x4919DF`..).
- Land humidity and cloud and the temperature target were not set against the saves: that needs each province's
  terrain, `climate.bmp` and `IsNight`. The land precipitation thresholds were checked by `FINDINGS-weatherfront.md`
  section 8.
- That `CCurrentGameState +0xBDC` is the clock in hours is taken from `FINDINGS-temperature.md`.

**Frontier** (rvas): `0x80A740` (the CRT's `_trandisp2`), `0x80CCDC` (its atan2 handler), `0x919DF`.. (the
`building_positions` fill in `ComputeProvinceGeometry`), `0x8FBB0` (the `positions.txt` loader's `building_position`
key).

---

## C. Weather on screen

Figures are tagged **[exe]** where compiled into `hoi3_tfh.exe` and **[mod]** where a file sets them. Four corrections:
**the weather mode writes map style 0** (the terrain style), not 0xB as `FINDINGS-mapmode.md`'s style table has it;
**`0x33D460` is not a tooltip** but the land orders window's *Synchronise Arrival* estimate (the movement tooltip
proper is `BuildSpeedModifierTooltip`, in `FINDINGS-unitpaneltooltips.md`); **the weather tooltip part replaces the
province's name and owner** rather than adding to them; and **`HideProvinceObjects98`'s picture is the supply depot**,
which answers the open question in `FINDINGS-airmap.md`.

### C.1 The weather map mode

**The button** is `mapmode_3` in `tfh/interface/menubar.gui`, sprite `GFX_mapmode_weather`; the in-game screen gives
it by name (`0x6C82C2`) the tooltip `MAPMODE_3` "Weather Mapmode".

**The setter**, `MapMode_Weather_Set` (`0x667300 / 0x267300`, the idler in ECX, bare `ret`), in order:

1. unless the mode is already 11, plays the `click` sound;
2. leaving mode 18 it takes the air icons and circles down, leaving 19 the naval icons;
3. sets the idler's `+0xD34` and `CMap +0x2A90` to 11;
4. `MapMode_ShowButton(3)`;
5. on the settings object: `+0xE7` = 0, the layer mask `+0xF0` = **0xFFBB**, the map style `+0xF4` = **0**;
6. the graphics owner's word `+0x60F8` = 0x100: as bytes, `+0x60F8` = 0 turns the supply depot pictures off and
   **`+0x60F9` = 1 turns the weather pictures on** - the only write of a 1 to `+0x60F9` in the image, every other mode
   writing 0;
7. `HideProvinceObjects98` (the supply depots), `MapMode_Weather_Colour`, `Map_RefreshColourTextures(0)`, `+0x60DC` = 1.

**When the colours are made**: by the setter, and again only by the in-game screen's map refresh (`0x6516A0`, from
`CInGameIdler::Update`), which re-runs the setter while the mode is 11 and `in-game screen +0x84 & 0xF` is set -
`Province_SetController` sets bit 1, `ApplyCustomGameSettings` 0xF, a few unidentified writers others; no hourly or
daily writer was found (a byte scan for `or [reg+0x84], imm`, positive control `Province_SetController`'s write). **So
the map's frozen colouring can lag the weather by days, while the pictures (C.3) follow it every hour.**

**The colour**, `MapMode_Weather_Colour` (`0x8678A0 / 0x4678A0`), for every province from index 1: **brightness** 1.0
where the player's intelligence is 2 or more, 0.5 otherwise, 0 where the template's `simulated` (`+0x13D`) is clear
**[exe]**; **owner id 0** - both colours 0x99999999; **otherwise** r = g = brightness, b = frozen / 1000 where above 0,
a = 1, packed truncating x255 into the ground and stripe colours. It is the terrain mode's loop (`MapMode_Terrain_Colour`,
`0x863F00`) with blue added.

**What the shader is given**: style 0 makes `Map_UpdateProvinceColourTexture` (`0x880DE0 / 0x480DE0`) keep R and B and
replace G with 0.1, or 0 where `CMapProvince`'s byte `+0xC` is clear (not read); A = 1; the texel is written B, G, R, A,
256 to a row. The sea is not recoloured - only styles 16, 18 and 19 recolour water - so the weather mode's sea is the
terrain mode's. *Inferred*: style 0 draws the land with `terrain_2_0.fx`'s `PixelShader_Map2_0`, whose per-province
`GeneralTexture` is this texture:

    grey = dot(rgb, (0.212671, 0.715160, 0.072169))
    rgb  = lerp(rgb, grey, B)     // "Winter"
    rgb += 0.3 * B
    rgb *= R                      // fog of war
    rgb += G

**So the weather mode is the terrain mode with frozen ground greyed and lightened by `frozen`** **[mod: the .fx]**.

### C.2 The tooltip part, `ProvinceTooltip_Mode11` (`0x49B2B1`)

**1. The province text is replaced**: `assignString` on the tooltip text, so the frame's name and owner are dropped, by
`Weather_DescribeLines` (`0x4B2AE0 / 0xB2AE0`). Each line is a localised key in the settings' text colours, `": "`, the
figure through `FormatFixedPoint` (truncating), and the unit:

| line | key | text | figure | places | ends with |
| --- | --- | --- | --- | --- | --- |
| 1 | `TEMPERATURE` | "Temperature" | temperature | 1 | `"C\n"` |
| 2 | `PRESSURE` | "Pressure" | pressure | 1 | `"mb\n"` |
| 3 | `WINDSPEED` | "Wind speed" | windspeed | 1 | the text of `KPH` ("KPH"), then `"\n"` |
| 4 | `HUMIDITY` | "Humidity" | humidity | 2 | `"%\n"` |
| 5 | `OVERCAST` | "Overcast" | cloud x 100 | 2 | `"%\n"` |
| 6 | `PRECIPITATION` | "Precipitation" | precipitation x 100 | 2 | `"%\n"` |
| 7 | `MUDDY` | "Mud" | muddyness x 100 | 2 | `"%\n"` |
| 8 | `FROZEN` | "Frozen" | frozen x 100 | 2 | `"%\n"` |

The x100 is `x * floor(100000.5) / 1000` **[exe]**.

**2. The front line**, where a front is over the province (`CProvince +0x14`): `WeatherFront_DescribeMovement`
(`0xB5340`), `WEATHER_FRONT` "This low pressure zone is moving §Y$DIR$§W.", `DIR` from `DirectionText(front +0x08)`
(`0xB4DD0`), each bound inclusive **[exe]**:

| heading (thousandths of a turn) | DIR |
| --- | --- |
| <= 63 | West |
| <= 188 | Northwest |
| <= 313 | North |
| <= 438 | Northeast |
| <= 563 | East |
| <= 688 | Southeast |
| <= 813 | South |
| <= 938 | Southwest |
| above 938 | West |

**3. The weather word**: `GraphicName` compared as a string, and the word appended **with no line break**:

| picture name | key | text |
| --- | --- | --- |
| `weather_snow_storm` | `WEATHER_SNOW_STORM` | "Blizzard" |
| `weather_snow` | `WEATHER_SNOW` | "Snow" |
| `weather_thunderstorm` | `WEATHER_STORM` | "Storm" |
| `weather_rain` | `WEATHER_RAIN` | "Rain" |
| `weather_cloud` | `WEATHER_CLOUD` | "Cloudy" |
| `weather_partialcloud` | `WEATHER_PARTIAL_CLOUD` | "Partial Clouds" |
| anything else (an empty name) | `WEATHER_CLEAR_SKY` | "Clear Sky" |

**4.** The shared tail (`FINDINGS-provincetooltip.md` section 7) follows. There is no intelligence gate.

### C.3 The weather drawn on the map

**The picture's name**, `CWeather::GraphicName` (`0x4B4400`), every comparison strict; the limits **[mod:
`defines.lua`]**, -5.000 **[exe]**:

| condition | then |
| --- | --- |
| precipitation > `GFX_SNOW_LIMIT` (0.1) and temperature < -5.000 | `weather_snow_storm` where wind > `GFX_SNOW_STORM_LIMIT` (15), else `weather_snow` |
| otherwise precipitation > `GFX_RAIN_LIMIT` (0.1) | `weather_thunderstorm` where wind > `GFX_STORM_LIMIT` (15), else `weather_rain` |
| otherwise cloud > `GFX_CLOUD_LIMIT` (0.8) | `weather_cloud` |
| otherwise cloud > `GFX_PARTIAL_CLOUD_LIMIT` (0.3) | `weather_partialcloud` |
| otherwise | `""` (clear sky) |

The seven strings are built by CRT initialisers at `0xCB39F0`-`0xCB3AB0`, in the table's order.

**When a picture is made.** Once an hour `UpdateProvinceWeatherRange` stores the name at `+0x98` and sets `+0x9C`
where it changed. Every frame `ProvinceGraphics_Update` (`0x63EF30`) adds, for each province entry with a picture,
`fmod(clock.slot5(), 1000)` to the picture's time (`CBillboardObject +0x14C`); and on 14 frames in 15, where the template
is simulated and the weather mode is on (`+0x60F9`), calls `ProvinceGraphics_UpdateWeatherPicture` (`0x63FE90`), else
destroys any picture. **So weather pictures exist only in the weather mode.** `ProvinceGraphics_UpdateWeatherPicture`
reads and clears `+0x9C`; where it was clear and a picture exists, keeps it while the name is not empty and destroys it
otherwise; else it takes the name afresh from `GraphicName`, appends `_simple` where the entry's cached byte `+0x8C` is
set, destroys an existing picture whose type differs or whose cached setting differs from **`alwaysCounters`**
(settings `+0xF9`), caches that setting in `+0x8C`, makes the billboard by name from `mapitems.gfx`, hangs it on the
province's anchor node (graphics `+0x10`) 1.0 higher **[exe]**, and shows it - so **the simple art follows
`alwaysCounters` one rebuild late**.

**The types** (`CWeatherBillboardType`, `tfh/interface/mapitems.gfx`, the keys **[mod]**): `CWeatherBillboardType::LoadKey`
keeps `textureFile` in a list of its own, in order, any number; `animation` and `simple` are stored and read by nothing
found; `effectFile`, `effect`, `scale` and `noOfFrames` come from the billboard type. The entries are `rain_test`,
`rain_test_simple` and `weather_{snow, snow_storm, rain, thunderstorm, partialcloud, cloud}`, each with a `_simple`
twin, all of scale 2.5 and `gfx/fx/weather_billboard.fx`, technique RainTech or SnowTech; texture 0 is the cloud and
texture 1 the rain or snow, and the thunderstorm adds `lightning01`-`03`. `LoadResources` (slot 6) builds two quads
facing the camera, z = 0: the **upper**, for texture 0, half-height = scale and half-width = scale x the texture's
aspect, y from 3 - s to 3 + s; the **lower**, for texture 1 and the lightning, lifted by 2s - 0.3, y from 3.3 - 3s to
3.3 - s, hanging under the cloud and overlapping it by 0.3. u is scaled by width / (width rounded up to a power of two) /
frames, v likewise. The 3.0, 2.0 and 0.3 are **[exe]**.

**How it is drawn.** Each frame `QueueForDraw` (slot 37) puts the picture on `g_WeatherBillboardDrawList`, which
`BillboardList_DrawBatch` draws after the counters. `CBillboardObject::Draw` first cycles the lightning where there are
more than two textures (only the thunderstorm): with none showing and time - last change > 15000 it shows frame
`((int)time % 3) + 1`; after 1000 it shows none again and waits a further `r x 10000`, `r` from **the picture's own
MT19937 seeded with its address** - not the game's generator, not reproducible **[exe]**. `CWeatherBillboardType::DrawQuad`
(slot 31) then draws, with two textures, `tex0` = texture 1 at `vTime` = time on the lower quad; with a lightning frame
showing, `tex0` = that texture at `vTime` = 0 on the lower quad; and always, last, `tex0` = texture 0 at `vTime` = 0 on the
upper quad. `vXOffset` = 0, `vFlip` = 1; `tex1` is never set, as the shader never samples its BottomTexture. **From the
shader**: rain samples its colour at uv + (0.000025t, -0.00005t) and its alpha at uv; snow at uv + (sin(-0.00001t x 3 x
3.14) / 100, -0.00001t). The clouds are still.

### C.4 The "movement tooltip" at `0x73D460`

`LandOrdersView_EstimateArrival` (`0x73D460 / 0x33D460`) serves the land orders window's `sync_checkbox`
(`ORDER_SYNC_ARRIVAL` "Synchronise Arrival"): for a `move_order`, `CLandOrdersView` slot 2 (`0x73CF80`) raises the date
widget to the estimate and the accept handler (`0x73D760`) uses it as the order's arrival. For each unit:

    speed   = def +0x108 * (1000 + destination terrain's movement adjuster) / 1000
                         * (1000 + w) / 1000
                         * LAND_SPEED_MODIFIER / 1000
    hours   = ceil(path length * 1000 / speed / 1000.0)
    arrival = now + hours + unit +0xD4 / 1000

the latest over all units, where `w` is `MovementEffect` inlined on the **destination's** weather, without
`LOCAL_UNIT_SPEED` - the real march uses the province the unit is in. The unit panel's speed tooltip's weather line is
`SPEED_MODIFIER_WEATHER` in `BuildSpeedModifierTooltip`, already read.

### C.5 Other readers on screen

Already read: the province view's strip (`FINDINGS-provinceview.md`), `ATTR_WEATHER` and `SPEED_MODIFIER_WEATHER`
(`FINDINGS-unitpaneltooltips.md`), `BM_WEATHER` in the battle window. **New, weather mode only**:
`MapObjects_RebuildTileStrips` (`0x862260`) gives the strips through provinces with **temperature < -5.000** u + 0.5,
the right half of their atlas - temperature, not `frozen`; the layout fits `map/terrain/borders.tga`, 2048 x 256, two
halves, four rows (*inferred*). `MapObjects_UpdateLayerVisibility` (`0x85BBB0`): the object group at `+0x64` is visible
only with mask bit 0x20 and mode 11; what it holds was not read. The other callers of `GraphicName` and of the combat and
attrition effects are accounted for, none in interface code.

### C.6 What looks wrong but is what the bytes do

- The weather mode's tooltip drops the province's name and owner.
- No line break separates "...moving §YWest§W." from "Rain".
- The map's frozen colouring is redone only on choosing the mode or a map refresh (a change of controller, say), not
  each hour; the pictures are live.
- Land with owner id 0 is drawn 0x99999999 in both the terrain and weather modes: 0.6 fog and 60% "winter" greying
  whatever the weather (*inferred*, through the shader).
- `alwaysCounters` picks the simple weather art, switching only at the second rebuild after the setting changes; the
  `simple` and `animation` keys do nothing.
- The cloud layer never animates; `tex1` is never bound, and the second `textureFile` reaches the screen only as `tex0`
  on the lower quad.
- The lightning's timing uses a generator seeded with a heap address.
- The snow picture needs a temperature strictly below -5.000, as do the strips, while the map's blue uses `frozen`: two
  tests of winter on one screen.
- The sync estimate uses the destination's weather and terrain and leaves out `LOCAL_UNIT_SPEED`.
- `Graphics_CreateObjectByName` has no null test, so a missing `weather_*` entry would crash.
- No intelligence or zoom gate in the update path, and sea provinces get pictures too.

### C.7 Not settled

**Three of the items below were settled on 2026-10-15 by the maintainer's screenshots** of the original's weather
mode (his game runs with `alwaysCounters=yes` in `settings.txt` and `debug fow`): the pictures **draw at every zoom**,
as dots from far off; with `alwaysCounters` on they are **the `_simple` icons**, `simple_partcloud` over the Breton
Coast and `simple_raincloud` over Brest, as C.3 reads; at about 33 screen pixels to a map pixel (Quimper, 11 map
pixels wide, and Morlaix, 17, measured off `provinces.bmp`) the square cloud is 162 pixels wide - **5 map units at a
map unit to a map pixel** - and its middle 133 pixels, 4.0 map pixels, north of the sea zone's text position, which is
the 1.0 raise and the 3.0 middle of C.3 with up off the map seen as north; and **the tooltip has no province name**,
only the eight lines and the word, the word on a line of its own after `Frozen`. The half brightness of C.1 was not
seen: `debug fow` gives every province 9.

- **The units of the clock's slot 5** (`[0x1A857E4]`), and with them the speed of the rain, the snow and the lightning:
  milliseconds is inferred from the 15000/1000/10000 constants.
- **Which texture the style-0 terrain shader samples as `GeneralTexture`** (inferred Texture1), and **what `CMapProvince
  +0xC` is** (it decides G = 0.1 or 0).
- **Whether the scene culls the pictures by zoom or layer**: no test in the update path, and group `+0x64` is
  unidentified. *A screenshot of the weather mode zoomed fully out would show whether clouds draw.*
- **The strip mesh's identity.** *A screenshot of the weather mode on a province colder than -5 C beside a warmer one, at
  border zoom.*
- **The tooltip without the province's name.** *A screenshot of any province's tooltip in the weather mode.*
- `unit +0xD4` in the estimate.
- **Other rows of `FINDINGS-mapmode.md`'s style table look wrong too**: in a decode of the setter range, `0x667920`
  writes 0xE, `0x667B50` 0xF, and a write at `0x6678A4` 0xD; not re-read.

**Frontier** (rvas): `0x2516A0` (the map refresh), `0x241D00`, `0x45C6F0`, `0x33CF80`, `0x33D760`, `0x6B6BE0`,
`0x661DD0`, `0x660F30`, `0x6D4C30`, `0x44E450`, `0x46AA70`.
