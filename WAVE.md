# The next wave

**This file holds one thing: the wave that is planned but has not run.** It exists because the plan
used to live in `CANDIDATES.md`, which is five hundred lines of queue and archive, and finding the
plan in it was a search rather than a glance.

The contract, so the two files do not drift:

| | |
| --- | --- |
| **`WAVE.md`** (this file) | the plan for the wave that has **not launched**. Overwritten by the next plan |
| `CANDIDATES.md` | the standing queue and the archive. **A wave's result goes there**, not here, along with the area-level backlog a plan is chosen from |

So: plan here -> launch -> write the result into `CANDIDATES.md` -> replace this file with the next
plan. If this file describes a wave that has already landed, it is stale and `CANDIDATES.md` is the
truth.

---

## The weather wave - the simulation of it, from a new game to the map

> **LANDED 2026-10-15.** Three briefs, merged (55 address entries landed and 23 revised; 1 struct declared, 35 fields;
> apply `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-weathersim.md` sections A, B and C, indexed
> in `CANDIDATES.md`, where six things it left are queued.

Planned 2026-10-15, for OpenHOI3, on the maintainer's word that day ("Commit and continue"): weather is the third of
six pieces in his order ("3 - 2 - 1 - 5 - 4 - 6": the province view, convoys in the build queue, weather, transport
and invasion, the headless run, the AI). OpenHOI3 has every **consumer** of weather built - movement, land, naval, air
and bombing combat, supply loss, naval spotting and break-off, firing range, the air gate, the province view's strip -
and every province's `CWeather` stays at nought, because the **simulation** of it is not built. Three briefs; the
write-up is **a new `findings/FINDINGS-weathersim.md`**, sections A, B and C.

**What is known and is not to be redone** - a great deal; cite it, re-read on the listing only to settle what follows,
to raise an `inferred` record or to correct one:

- `FINDINGS-weather.md`: the fields and their save keys, `CWeatherManager` embedded in `CGameState +0xAEC`, the two
  hourly calls out of `RunHourlyPass` (`0x282630`), `UpdateProvinceWeatherRange` (`0x27B1C0`), every consumer, the 56
  defines and `InitialiseWeatherState` (`0xB54F0`) caching 49 of them.
- `FINDINGS-weatherfront.md`: `CWeatherFront::Tick` (`0xB4620`), `SpreadWeather` (`0xB42B0`), the front's layout,
  constructor and save keys, `CWeather::Update` (`0xB2590`) branch by branch, `Clamp` (`0xB2210`), `CreateFront`
  (`0xB5D80`), `PropagateHighPressure` (`0xB6050`), `IsAngleWithinArc` (`0xB4490`), `GraphicName` (`0xB4400`), the
  compiled-in numbers, and the savegame checks.
- `FINDINGS-temperature.md`: `BaseTemperature` (`0xB22E0`) in full, `climate.bmp` and `LoadProvinceClimate`
  (`0x8BE00`), `ComputeProvinceClimate` (`0xA81A0`), `ComputeProvinceLatitude` (`0x963F0`) and its southern bug, the
  daily recompute in `RunDailyProvincePass` (`0x9EAB0`), and its corrections to the two above.
- `FINDINGS-mapbuild.md` sections 6 and 7 and `FINDINGS-movement.md` section 6: an edge's bearing (filled by
  `CProvinceTemplate::MeasureEdges`, `0x4A9E70`; the formula fitted, the call at VA `0xC0BDBA` not read), which pixel
  a province samples.
- `FINDINGS-mapmode.md`: mode 11 is the weather map mode on `mapmode_3`, coloured by the generic path, style 0xB..0xF;
  `ProvinceTooltip_Mode11` (rva `0x9B2B1`) is its tooltip part, not read.
- `FINDINGS-provinceview.md`: the view's weather strip.

**What OpenHOI3 needs that is not settled**, by brief:

| brief | what it settles | starting points |
| --- | --- | --- |
| **A. The hour and the new game** | **The order of everything weather does**, so a reimplementation runs it in the original's place: `RunHourlyPass` (`0x282630`) whole as far as where `CWeatherManager::Tick` (`0x2826F3`) and the province pass (`0x282A3B`) fall among its other steps (movement, combat, supply - name them, do not read them); the order `CWeatherManager::Tick` (`0xB5A20`) ticks its fronts in and where a new front goes on its list; whether `PropagateHighPressure` runs before or after the fronts and in `CMap +0x21C8`'s file order; `UpdateProvinceWeatherRange`'s per-province order (night, update, picture) and whether anything in the province pass reads a neighbour (so whether the parallel split could change a result). **The new game**: the loop at rva `0x25C820` that runs `INITIAL_SIMULATION_HOURS_AHEAD` (96 in Their Finest Hour) hours of weather before the start - exactly what each of its hours runs, with what clock (does the date move? which hour and month does `IsNight` see?), and where it falls against `CInGameIdler::Enter`'s latitude and climate loop (`0x25AFAD`), `ResetZoneState` (`0xB59C0`), the two days a new game runs first (`FINDINGS-buildqueue.md`'s and the tick's), and `InitialiseWeatherState`. **The draws**: every random number weather takes (`CreateFront`'s heading and cooldown, the new low's depth) - which generator (`RandomThousandths` `0x6A2FD0`: the game's shared MT19937, or a generator of its own?), and in what order within an hour. **Save and load**: what of the weather a savegame keeps and a load restores - `CWeatherManager`'s own keys (the fronts; the per-zone cooldown and heading vectors? `ResetZoneState` on load?), `CWeather`'s keys (written only where not nought?), and what a load leaves to be made again (night, climate, latitude) | rva `0x282630`, `0xB5A20`, `0x25C820`, `0x25A2B0`, `0xB59C0`, `0xB54F0`, `0x6A2FD0`, `0x27B1C0`; `CWeatherManager`'s and `CWeatherFront`'s save slots |
| **B. The arithmetic, whole and in order** | **One implementable account of every formula**, re-read on the listing in instruction order with every multiplication and division in its place, every comparison's strictness and every clamp: `CWeather::Update` (`0xB2590`) from top to bottom in one listing - the three earlier files read it in pieces and corrected one another twice; the muddyness branch exactly ("while precipitation > 0.500 or frozen ground above -5 C", "above 15 C a further 5" - which fields, which order, what `infra` is); the temperature step's direction choice and its multipliers; the pressure step. `CWeather::BaseTemperature` (`0xB22E0`) confirmed in order. `CWeatherFront::Tick` and `SpreadWeather` confirmed, with `IsAngleWithinArc`'s `%` on a negative centre exactly. `CreateFront` and the front's constructor - the draws in order. `PropagateHighPressure`'s queue (FIFO? does a province enter it twice?). `ComputeProvinceClimate`'s band boundaries to the day (`<=` or `<`), `L` and `X`'s rounding. **And the bearing**: the call at VA `0xC0BDBA` in `MeasureEdges` - which function (`atan2`?), its two arguments exactly, and the rounding after, for land-to-land and for an edge between land and sea (the naval base's position at which end?) | rva `0xB2590`, `0xB22E0`, `0xB4620`, `0xB42B0`, `0xB4490`, `0xB5D80`, `0xB44E0`, `0xB6050`, `0xB2210`, `0xA81A0`, `0x963F0`, `0xA9E70`, VA `0xC0BDBA` |
| **C. Weather on screen** | **The weather map mode** (mode 11, `mapmode_3`, `FINDINGS-mapmode.md`): what colours each province, land and sea - by which field, with which colours or gradient, what the generic path does for it (its style number), and whether it also shows the billboards; **its tooltip part** `ProvinceTooltip_Mode11` (rva `0x9B2B1`): every line, key and variable, format and colour. **The weather billboards on the map**: `CWeatherBillboardType` (`mapitems.gfx`'s `weatherBillboardType` entries: `rain_test`, `rain_test_simple`, `weather_snow`, ...), **`GraphicName`'s seven strings** (their initialiser - the names it answers), how a province's picture name (`CProvince +0x98`) and its redraw flag (`+0x9C`) become a billboard: in which map modes, at what zoom, where in the province, how many, at what size and how animated (`effect`, `scale`), and whether a "simple" type is chosen by a setting. **The movement tooltip**: whether `0x33D460`'s inlined copy of `CWeather::MovementEffect` is a tooltip, and if so which element's and what it says. Anything else on screen that reads weather (the province view's strip is read) | rva `0x9B2B1`, `0xB4400`, `0x33D460`, the `CWeatherBillboardType` RTTI, `tfh/interface/mapitems.gfx`, `FINDINGS-mapmode.md`, `FINDINGS-gui.md`'s billboard rows |

**Measurable afterwards, by OpenHOI3**: the maintainer's saves `Germany1936_01_08_02`, `_03`, `_06` and `_07` lie an
hour or a few apart with no midnight between the first two; each holds every province's weather and every front, so
an hour of weather run from one save's state and set beside the next is a check of brief B province by province -
everything but the draws of a new front. `tfh/map/cache/adjacencies.bin` holds every edge's bearing.
