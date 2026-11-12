# FINDINGS-lendleaseslider.md: the lend-lease share with nobody to give to

*Static reading of `hoi3_tfh.exe`, image base `0x400000`, 2026-11-12. Addresses are `VA / rva`. The game was not running.
Savegame figures are marked **measured**; everything else is read off the bytes. `GetLimit`'s empty-list test and the
screen's clamp loop were checked again off the bytes by the collecting session the same day.*

Asked for by the rewrite: OpenHOI3 let the lend-lease slider take a share when the country gives lend-lease to nobody, and
the maintainer says the original holds it at nought. **The simulation does nothing about it; the production screen does.**

**It corrects the record** in four places: `CDistributeLendLease::GetLimit` was "a marker only: nothing clamps the slider"
- the screen clamps the slider to it; `CCountry::GetMaxLendLeaseFraction` said "the engine never clamps" the share to it,
true of the simulation only; `CProductionView::AddToSlider` was `inferred` and is now read whole; and `CEconomySlider +0x3C`
was "the player moved it", where `SetValue` sets it too. `FINDINGS-countryviews.md` section 2 had the `limit` icon shown
for an answer "nought or more"; the icon's test is above nought (`ja`) - corrected there.

## 1. What "no receiver" is

There is one test, the same in all three places that ask - `CDistributeLendLease::GetLimit` (`0x518BD0 / 0x118BD0`),
`CCountry::GetMaxLendLeaseFraction` (`0x508A90 / 0x108A90`) and `CCountry::HasActiveLendLeaseToAnyone` (`0x5089A0`, the
Lua's test): `(lendlease_distributions_end (+0x6BC) - begin (+0x6B8)) & ~0xF > 0`. The giver's list holds at least one
16-byte entry `{receiver tag, id, weight, effectiveness}`.

- An entry is added by `CCountry::AddLendLease`, which both lend-lease actions call when the offer is accepted, starting
  at weight 500 and effectiveness 0.
- An entry is taken off by `CCountry::RemoveLendLease`, called by both actions and by `CRemoveLendLeaseCommand`; the
  hourly `CCountry::UpdateLendLeaseRoutes` posts that command when no route exists.
- **Nothing else is asked.** A receiver at effectiveness 0 counts, so does one at weight 0, and so does one whose convoy
  has not been made yet.

So "no receiver" means **no lend-lease agreement given and not yet ended**, whatever state the agreement is in.

## 2. The simulation: the share stays, and its IC is lost

`RunCountryDailyPass_DistributeProductionShares` (`0x4DB4F3`) calls each of the six shares in turn with the same
`available = TotalIC << 15`; the `out` it is handed back is never read (decoded `0x4DB4F3..0x4DB54B`: the loop reloads
`[ebx+0x604]` for every share and adds nothing in between). `CDistributeLendLease::Distribute` (`0x518800`, already
recorded) loops over the giver's entries; with none it charges no resources, gives nothing, and writes `*out = 0`. **So a
lend-lease share with no receiver is IC that goes nowhere**; the other five shares get their own percentage of `available`
and no more. A receiver at effectiveness 0 gives the same result.

**Nothing in the model zeroes the share when the last receiver goes.** `CCountry::RemoveLendLease` (`0x508550`, read
whole) calls `RemoveLendLeaseSource` and the vector erase `0x50F9F0`, and nothing else. A census of every instruction in
`.text` whose displacement is `0x5F4` or `0x5F8` (the ProductionDistribution vector) found no hit in `RemoveLendLease`,
`RemoveLendLeaseSource` (`0x5087C0`), `UpdateLendLeaseRoutes` (`0x508C30`), `CRemoveLendLeaseCommand::Execute`
(`0x555D40`) or any lend-lease action's `Apply`. Positive control: the same census finds the daily loop (`0x4DB4F3`),
`CChangeInvestmentCommand::Execute` (`0x556D60`), the daily `BalanceProductionSliders` call (`0x4DC24F`),
`CProductionView::BuildSliders` (`0x7FC4A5`), `CCountry_Reset` (`0x4D4760`) and `CCountry::LoadKey`.
`CChangeInvestmentCommand::Execute` writes the six shares as given, with no clamp (already recorded).

**Measured.** Germany is the player in the maintainer's 1936 game and holds no `lendlease_targets` in any of its saves;
positive control: the key does appear in `Germany1936_03_31_19.hoi3` for another country, and in the 1940/41 Ireland saves.

| save | Germany's lend-lease share (`distribution`, first figure) |
| --- | --- |
| `Germany1936_01_01_00` | 0.15518 |
| `Germany1936_01_08_07` (a week into play) | 0.15518 |
| `Germany1936_03_31_19` | 0.00543 |
| `Germany1936_04_20_03` | 0.00360 |
| `Germany1936_09_02_21` | 0.01453 |

So for a whole week a played country put 15.5% of its IC into lend-lease to nobody. Afterwards the share is small but not
nought - what section 3 predicts: the clamp happens on the screen, and the player's own slider automation hands his share
back to the script each day, which adds 0.00005 each time (`FINDINGS-ministers.md` B.7). The later figures were not
fitted to when the screen was open; they are consistent with this reading and not a check of it.

## 3. The production screen holds the slider at the limit

`CProductionView::Update` (`0x7FD350 / 0x3FD350`, slot 6) runs every frame the production screen is open; its only
recorded caller is `CInGameIdler_UpdateOpenView`, which calls the open country view's slot 6. After the building buttons:

    0x7FE009  if ((float)TotalIC != view->total_ic (+0xC8)) every slider's maximum := TotalIC   (SetMaximum 0x7F0EB0)
    0x7FE06C  CProductionView_Update_ClampSlidersToLimit
    0x7FE114  CProductionView_Update_BalanceSliders
    0x7FE3CD  SendDistribution at most once a wall-clock second, if sliders_changed (+0x324)

No jump from earlier in Update lands past `0x7FE06C`, so the clamp runs every frame (checked by listing every jump in
`0x7FD350..0x7FDFC0`).

### 3.1 The clamp, `0x7FE06C..0x7FE10A`

    for each slider s of the list (+0xB8), list order - upgrade, reinforcement, supply, production, consumer goods, lend-lease:
        lim = s->setting (+0x34) -> slot 11 ()
        if (lim >= 0 && GetValue(s) > lim)
            AddToSlider(s @ESI, (float)(GetValue(s) - lim))

In the bytes: `fldz; fxch; fcompi; jb` skips a limit below nought; `fld value; fcompi lim; jbe` skips a value at or under
the limit; `fsubr qword` makes the amount `value - lim`. Slot 11 answers `-1.0` (`CDistributionSetting::GetNoLimit`, the
float at `0x170AC0C`) for the other five settings, so they are never touched here, and `CDistributeLendLease::GetLimit`
for lend-lease. `GetLimit`, read whole (`0x518BD0..0x518C42`):

    if (country->lendlease_distributions is empty) return 0.0
    return (float)( TotalIC * 1000 * GetMaxLendLeaseFraction(country) / 1000 ) / 1000.0     ; 64-bit, truncated

So **with no receiver, the lend-lease slider is set to 0 every frame the screen is open**; with receivers it is held at
most at the cap, TotalIC × (`LEND_LEASE_MAX_IC_LOW` .. `_HIGH` by effective neutrality over
`LEND_LEASE_NEUTRALITY_LIMIT`), 5% to 90% in Their Finest Hour.

The clamp does not ask `IsHeld`, so it applies while the player is dragging the slider: **the slider cannot be dragged
above its limit.** It does not lock or disable the slider either; the slider stays enabled and draggable, and is simply
put back each frame. Two gaps, both inside `AddToSlider` (3.2): an excess under 0.005 IC rounds to nothing, so the slider
can sit up to that much above the limit; and **a disabled (locked) slider is not clamped**, because `AddToSlider` returns
before setting anything. Whether the lend-lease slider can be locked depends on the right-click lock, whose routine is
still unread; its `ic_need_button` opens the lend-lease window and does not pin it (`CEconomySlider::OnNeedButton`).

### 3.2 `CProductionView::AddToSlider`, `0x7FEBD0 / 0x3FEBD0`, read whole

Arguments: the slider in ESI (both callers load it there, at `0x7FE080` and `0x7FE2E7`), the amount as a float at
`stack:4`, `ret 4`. The result comes back in XMM0; the callers read it with `cvtss2sd xmm0, xmm0`.

    a = (int)(|amount| * 100 + 0.5) / 100, the sign put back       ; 100.0 at 0x160A358, 0.5 at 0x160A308
    if (IsDisabled(slider)) return 0
    if (a < 0)
        if (GetValue + a > 0) { SetValue(GetValue + a); return a }
        r = GetValue - 0.0; SetValue(0.0); return r                  ; 0.0 at 0x160A270
    if (a > 0)
        cap = GetMaximum(slider)                                     ; TotalIC
        lim = setting->slot 11(); if (lim >= 0 && cap > lim) cap = lim
        if (cap - GetValue - a > 0) { SetValue(GetValue + a); return a }
        r = cap - GetValue; SetValue(cap); return r
    return a                                                         ; 0

**The lowering arm's overflow has a sign slip**: it returns the slider's value as a positive number where the change was
negative, so the balancing loop's `left` moves the wrong way for the rest of that round; the next round recounts `left`
from the sliders' values.

### 3.3 Why the clamp reaches the game

`CEconomySlider::SetValue` (`0x7F0CC0`) calls slot 7 of the scrollbar's value object at +0x48 with `(thousandths, 1, 1)`:
`push 1; push 1; push value; call [[esi+0x48]+0x1C]`. The table at +0x48 is `0x15FF858`, written by the scrollbar
constructor at `0xA9DBBD`, and its slot 7 is `0xA9F2B0`, now `CScrollbar_SetValue`, which works out `value - current`
and calls `CScrollbar_MoveBy(scrollbar, delta, markMoved = 1, notify = 1)`. MoveBy writes `+0x252 = 1` when its second
argument is set (`0xAA0127`/`0xAA0150`). In the balancing (3.4), the same frame: `LatchMoved` moves +0x252 into the
slider's `moved` (+0x3C); `IsHeld` answers yes (it opens with `cmp byte [esi+0x3C], 0`); the slider counts as held, so it
is not free, and `sliders_changed` (+0x324) is set; `SendDistribution` posts the six values within a wall-clock second
(`0x7FE3F6..0x7FE426`) as a `CChangeInvestmentCommand`, the lend-lease share 0. Nothing is sent while the player has
delegated production (`automation[1] == 1`, already recorded).

### 3.4 Where the share goes: `CProductionView_Update_BalanceSliders`, `0x7FE114..0x7FE38F`

`FINDINGS-countryviews.md` section 2 has the outline; read again here:

    up to ten rounds:
        left = GetMaximum(first slider)                   ; TotalIC
        free = count (+0xC0)
        for each slider s:  Update(s); LatchMoved(s); left -= GetValue(s)
                            if (IsDisabled(s) || IsHeld(s) || view->+0x320 > 0) free--
                            sliders_changed |= (s->pinned || IsHeld(s)); s->pinned = 0
        step = left / free;  if |left| > 0.005 then |step| at least 0.01f with its sign, else step = 0
        if free > 0: for each slider s: if (left != 0 && !IsHeld(s)) left -= AddToSlider(s, step)
                                        if |left| < 0.005 break;  s->moved = 0
        stop when step == 0

So when the clamp takes the lend-lease slider down, the IC it held is **shared in equal amounts** among the sliders
neither locked nor latched, each kept within 0 .. TotalIC (lend-lease within its limit), in steps cut to the hundredth of
an IC, at least 0.01, stopping within 0.005. The lend-lease slider itself is latched that round, so it takes no share
back; afterwards its limit of 0 caps any step `AddToSlider` gives it at nothing. A slider the screen moves in one round is
latched by its own `SetValue` and counts as held in the next, so the second round usually has few free sliders. Germany's
start (measured shares, 201 IC): 0.15518 × 201 ≈ 31.2 IC freed, about 6.24 IC to each of the five others on the first
frame the screen is open; the command then truncates the shares to 32768ths (`CChangeInvestmentCommand_shares`).

Nothing in the loop tests lend-lease or a receiver; its only special treatment of lend-lease is the slot-11 limit, through
`AddToSlider` and the clamp.

## 4. The AI's countries

The screen clamp is the played country's screen only. For everyone else, `RunCountryDailyPass_BalanceProductionSliders`
(`0x4DBEA8`, recorded) calls the script `BalanceProductionSliders` with level 0 and `vLendLease = 0`. In
`tfh/script/ai_production_minister.lua`:

    if (liOrigPrio == 0) then
        if ministerCountry:HasActiveLendLeaseToAnyone() then  ... preferred = GetMaxLendLeaseFraction() * 0.3 (or 0.1 / 0.3-0.5 for USA at war) ...
        else vLendLease = 0 end
    end

Then `CAI.FastNormalizeByPriority` (`0x8E9250`) gives every share 0.00005 more while room is left, which is why an AI
country with no receiver saves **0.00006**, not 0 (England on 1 January, `FINDINGS-ministers.md`). At levels 1-3, the
player's own slider automation, the script skips that block ("we let player set this slider completely"), so his current
lend-lease share goes back in unchanged, plus the 0.00005. A player who delegates production gets the AI branch, so the
script zeroes his share.

## 5. What the screen shows

- **`limit` icon:** hidden with no receiver. `CEconomySlider::Update` shows it only for a slot-11 answer **above** nought
  (`0x7F08C5..0x7F08D4`: `fcompi; ja`). With receivers it stands at the cap.
- **`value` line:** always white (`GetValueColour`, `§W`). **`need` line:** always the text of `DISTRIBUTE`, with no figure.
- **Tooltip:** empty (slot 5); the lock line `SLIDER_LOCKED_TOOLTIP` / `SLIDER_UNLOCKED_TOOLTIP` comes from the view.
- **The slider is not greyed or disabled.** `BuildSliders` disables only a slider whose `+0x1090` entry is set, and neither
  it nor `PlaceSliders` asks about lend-lease. It moves under the mouse and springs back to its limit each frame.
- **Its button** still opens `CLendLeaseDistribution`, with no rows. **No text key** says why it cannot be moved.

## 6. Hardcoded or mod-able

| rule | where |
| --- | --- |
| "no receiver" = an empty `+0x6B8` list | exe, hardcoded |
| the screen clamps a slider to its slot-11 limit, every frame, while dragged too; locked sliders exempt | exe, hardcoded (`CProductionView::Update`) |
| lend-lease's limit is 0 with no receiver | exe, hardcoded (`GetLimit`) |
| the cap with receivers | mod-able: `common/defines.lua`, `diplomacy` block: `LEND_LEASE_NEUTRALITY_LIMIT` (60), `LEND_LEASE_MAX_IC_LOW` (0.05), `LEND_LEASE_MAX_IC_HIGH` (0.90); the formula is hardcoded |
| freed IC shared in equal steps, hundredth rounding, 0.01 minimum step, 0.005 tolerance, ten rounds | exe, hardcoded (literals `0x160A358`, `0x160AAE8`, `0x160A378`, `0x160A518`) |
| the `limit` icon | the element `limit` (`GFX_production_slider_limiter`) in `domesticpanel_slider`, `interface/country_production.gui`; the clamp does not need it |
| the simulation keeps the share and wastes its IC | exe, hardcoded (daily loop, `CDistributeLendLease::Distribute`) |
| the AI zeroes its share with no receiver | mod-able: `tfh/script/ai_production_minister.lua`, `BalanceProductionSliders`; the +0.00005 is the exe's `FastNormalizeByPriority`, which binds only a script that calls it |

## 7. Not established

- **The right-click lock's routine**, and so whether the lend-lease slider can be locked out of the clamp in practice.
- **Whether `CProductionView::Update` has another caller.** Only `CInGameIdler_UpdateOpenView` is recorded; `findRefs` was
  not run over slot 6.
- **Germany's later figures** (0.0036 .. 0.0145) were not fitted to a model of when the screen was open.
- **`0xA9E810`**, the knob placement `CScrollbar_SetValue` calls, is unread (in `frontier`).
- `CScrollbar_MoveBy`'s parameter is named `byPlayer`, but `SetValue` passes it as 1 too; and
  `CLendLeaseDistribution::AnySliderMoved`'s comment says +0x252 is "set only ... for a player's move" - whether its own
  sliders are ever set with 1 was not checked.

In the record through `fragments/merged/lendlease-slider-2026-11-12.json`.
