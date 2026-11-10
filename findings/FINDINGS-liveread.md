# Short reads of the running game, 2026-11-10

Read through the Cheat Engine bridge, the method of `FINDINGS-balancing.md`. A new 1936 game was run for 36 hours, then
`Ireland1941_07_16_07.hoi3` was loaded and run for 3. Addresses are rvas unless marked VA. *Confirmed* here means seen in
the running game.

## 1. The generator is not re-seeded in play (confirmed)

The record and `FINDINGS-landbattle.md` section 3 said every hour starts a fresh stream. It does not, in single player:

- `ReseedGlobalRandom` (`0x6A2ED0`) was hit **no times** in 36 hours of a new game, with a breakpoint on its entry.
- `g_random_draws` (`0x134DA8C`) ran on from 7,771 to 25,530 over those hours, and the saves' `count` runs on as well
  (132,951 to 133,091 over one hour of January 1936; 20,622,004 to 20,623,449 over five of 1940).
- The dword at `0x134DA94` held 86 throughout: the figure `ReseedGlobalRandom` passes to the initialiser (`mov eax,[0x174DA94]`
  VA, then `0xAA2BF0` with the state array in ecx). This is the generator's real seed. The state array at `0x1310F80` is
  not a seed, whatever its record name says.

`RunHourlyTick`'s store of the seed and zeroing of the draws (VA `0x681C3E`-`0x681C79`) is a path single-player does not
reach. `SnapshotRandomState` pushes the draws and that seed into the hour's tick payload each hour, and this path takes them
back. That it is the multiplayer resynchronisation (a reader placed it under "Games out of sync") was **not checked**.

**How many draws.** An ordinary hour made 57 to 175 in the first days. The midnight of 2 January made 14,241, all between the
start of `RunHourlyPass` and the first `ProcessAI` of that hour.

**Replaying an hour** therefore needs the state array and its index (`0x1310F80`, `0x1311940`), dumped live at the start of
the hour. A save cannot supply them.

## 2. The order of the hour (confirmed)

Logged for 36 hours at `RunHourlyPass`, `ProcessAI` and the one execute site of the command queue (`0x689940`):

    CHourlyTickCommand runs -> RunHourlyPass -> the daily pass, on a new day -> ProcessAI x102 -> the commands posted, then the next tick

- **The AI runs after every pass of the hour**, the daily pass included: its 102 entries always came after the hour's draws
  were made. That agrees with the static reading, `CGameState::RunAIPass` being called from `CInGameIdler::Update`, a frame
  after the tick.
- **All 102 countries run in a different order each hour** (36 different orders in 36 hours), the TBB workers of
  `ProcessAIFunctor`. The first few to enter vary, for example `---`, `YEM`, `REB`.
- **The commands they post run after all 102 passes**, before the next tick: 4,264 executed, the last of each hour a
  `CHourlyTickCommand`. Their serials are nearly in order but not quite (34 of 37 hours have a swap, 1275 before 1274), the
  mark of posting from several threads.
- **Neither the AI passes nor the commands drew on the game's generator.** Every one of the 17,759 draws in the log came
  between `RunHourlyPass` and the first `ProcessAI`. A sample of 36 early hours of 1936; the claim is about those.

A loaded game's generator is left alone: at the moment `Ireland1938_08_03_14.hoi3` stands loaded and paused, `g_random_draws` is 2 and
`0x134DA94` is 0, whatever the save's `seed` and `count` say.

## 3. A unit's figures (confirmed)

`CUnit +0xC8` set beside the unit's brigades' `CSubUnit +0x58` definitions, 80 units of 2 or more brigades: **soft, hard, air
attack, defensiveness, air defence, width, strength, supply, fuel and officers are the sum; toughness is twice the sum; piercing
is the best brigade's; softness is the mean, truncated.** 80 of 80 on each.

## 4. List orders only memory holds (confirmed for a new game)

Paused on 2 January 1936 at 12:00, with nothing changed hands yet:

- `CCountry +0xCF0` (owned), `+0xD00` (controlled), `+0xD10` (cores) and `+0xD80` (naval bases) are **in province-number order**
  for every country of 2 or more: 76, 76, 90 and 40 of them.
- `CMapProvince +0x2B8` (the units in a province) is **in order of arrival**, at the end as a unit comes. A headquarters
  the AI makes in the first hours stands after the divisions already there, so the list is neither by id nor by order of battle:
  province 1964 holds its theatre, Eastern Command, Home Counties Area, 12th Division, London District, 1st London Division and
  then the new 2nd Army Group.

The factions held one member each on that date, so that list was not tested.

## 5. Italy's organisation in 1941 (confirmed)

`CCountry +0xD90`'s entry 70 (`LAND_ORGANISATION`) for Italy is 50. It comes from one of its two `CTriggeredModifier`s at
`+0x658`; the file's only land-organisation entry that fits a country in that state is `veteran_army` (`land_battles_fought =
250`, `land_organisation = 0.05`), and the save gives Italy 251. Entries 71 and 72 (air and naval organisation) are 0, so the
5% is not on every kind of brigade, as was thought. The ratio is 1400, at its cap. The save check's 44.100 against 42.000 is
this modifier.

## 6. The AI's attack odds (confirmed)

`CAIUnit::EstimateAttackOdds` read at both of its value exits (`0x4D9E02`, `0x4D9E1E`) with its arguments, 232 calls, 16 July
1941 08:00 to 10:00, Germany and the Soviet Union. Each side's `D` is `toughness (theirs: defensiveness) x +0xF0 x +0xF8`, which
is `combat_defend_product` and `landing_defend_scale`, read at VA `0x7E9C34` in the live base.

Set beside OpenHOI3 from the same save, unit list for unit list: 81 estimates compare, and every one lies within 11%, half of them
within 4%. Germany's single-unit estimates are within 0.5% with one exception of 1.7%. The Soviet Union's stand about 4% high, by
a term not found. Of the other 151 calls, 18 repeat one already compared and 133 have a list of units OpenHOI3 did not try, its candidates coming in another order or its picks differing (the cause was not traced).

## 7. A land battle's hour, against OpenHOI3 (confirmed)

The first hour of `Ireland1938_08_03_14.hoi3`, loaded and run in both. The generator's whole state (the 624 words at `0x1310F80`, the index at
`0x1311940`, the draws) dumped at the entry of `CCombat::Tick` (`0x16EBE0`) for every battle, and put into OpenHOI3 at the same point; each battle's
fronts and reserves, then `CLandCombatant::FireUnit` (`0x16ADC0`) with its unit, the side's stream `*random`, the draws and the unit's four products, then
each brigade after the hour.

- Battle at 5597 and at 7510: **every figure the same** - the fronts and reserves, the streams `x`, the draws at every shot, and all brigades' strength and
  organisation to the thousandth.
- Battle at 5638: the same, but for one brigade of unit 4658, 26.789/22.065 against 26.804/22.154. The unit's product was the same, but the enemy's
  (850/1700 against 848/1698) was not: **experience, which is rolled in the unit's hour before the battles**, on draws not restored here.
- The modifiers on every unit, read off `CUnit +0xDC`: 6 experience, 8 territorial pride, 10 dug in, 1 leader, 5 stacking, 14 river, 18 combined arms,
  25 terrain, 26 weather, 27 night, 17 several battles. China's 8, +200, is the triggered modifier `desperate_defence` (`lost_national = 0.3`), which a load
  had been testing before the count that answers it; the rest are as OpenHOI3 makes them.
- A bombing is not yet the original's: from one generator, OpenHOI3 draws 33 and 75 where the original drew 32 and 86 (a third, 73, agrees).
- **Not shown**: the first front of a new battle, a reserve coming up, tactics chosen. No battle both games had going needed them: the two new ones (7511, 5596)
  came of a move only the original's AI made.

## 8. Controlling the running game from outside (confirmed)

Two bytes of `CInGameIdler`, written from Cheat Engine with the game in single player. **Pause**: `+0x12D8` = 1. **Unpause**: `+0x12D9` = 1 and `+0x12D8` = 0, what
`CInGameIdler::Unpause` stores. To stop on an exact hour, a breakpoint on `RunHourlyPass` (`0x282630`) sets the pause when the tick reaches the target; that hour
then finishes and no other starts. **Save**: `+0xAB0` = 1, the autosave request, which is honoured while paused: `autosave.hoi3` was written within ten seconds,
dated 1938.8.3.16 and complete.

That save's `seed` is -1514471307 and its `count` 885. `seed` in a save is **the first word of the generator's state array** (`0x1310F80`), which the paused game
held at the same value with its draws at 885, and not the figure the generator was made from (`0x134DA94`).
