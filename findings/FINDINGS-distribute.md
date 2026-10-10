# The daily IC split: who is called, with what, and three bodies nobody had read

Static reading of `hoi3_tfh.exe`, image base `0x400000`, on 2026-10-07. Addresses are given
as `VA / rva`. The game was not running. Written because the rewrite's production spec needed
four things `FINDINGS-production.md` and `FINDINGS-ic.md` leave open: how the six IC shares are
driven, what the second term of consumer goods demand is, what the supply share makes, and
where crude oil becomes fuel.

Where a savegame is quoted it is a vanilla Their Finest Hour save from 1 January 1936, hour 0,
and the figure is marked **measured**. Everything else is read off the bytes.

## 1. The economy block of `RunCountryDailyPass`, and the loop over the shares

`RunCountryDailyPass` is `0x4DA530 / 0xDA530`, the country in `ebx`. `FINDINGS-politics.md`
lists `0x4DB418`-`49` as "the economy block". Read through:

    0x4DB418   0x5020E0(country)                              ; unread
    0x4DB41D   if (country->+0xCF8 > 0 || country->+0x95)     ; holds something, or is in exile
    0x4DB434       0x4F1F50(country)                          ; the day's production pools
    0x4DB43A       RunDailyTradeRoutes(country)               ; 0x4FEE70
    0x4DB442       UpdateIC(country, 1)                       ; 0x4F0CC0, with the daily effects
    0x4DB449       ConvertCrudeOilToFuel(country@ESI)         ; 0x4F19F0 - section 4
    0x4DB44E       if (in exile) hand the exile pool's supplies and fuel (+0xA00, +0xA04)
                       to the host: its capital province's pool, and its +0xA64 pool
    0x4DB4C7   if (country->+0xCA8 == 0 || tag == "REB") skip to 0x4DB676
    0x4DB4F3   for (i = 0; i < count(+0x5F4); i++)            ; the six IC shares, in index order
                   shares[i]->vf0(&out, (int64)TotalIC << 15, 0)
    0x4DB5BE   if (gamestate->+0xD0C != 0) ...                ; touches leadership[0], unread
    0x4DB5EC   for (i = 0; i < count(+0x5E4); i++)            ; the four leadership shares
                   leadership[i]->vf0(&out, (int64)(+0xBD8) << 30 / (1000 << 15), 0)
    0x4DB671   influence upkeep (0x503E90)

Four things this settles.

- **`available` is `TotalIC` (`+0x604`), a whole number of IC, shifted into
  `fpml::fixed_point<__int64,48,15>`.** So the cap a shortage puts on `+0x604` and the
  lend-lease added to it are both already in what the shares divide.
- **The six are called in index order**: lend-lease, consumer goods, production, supply,
  reinforcement, upgrade. Each one's resource charge therefore comes off the stockpile before
  the next one's resource check.
- **The `flag` argument is 0 on this path.**
- **The two gates are different.** Production, trade, `UpdateIC` and the fuel conversion run
  only for a country with `+0xCF8 > 0` or in exile. The share loop runs for **every country
  with a tag id that is not `REB`** - including one that holds no province at all.

That last one is visible in a savegame (**measured**). Twenty-three countries that do not
exist on the start date each show `usage` of metal, energy and rare materials, and for each of
them the metal figure is its consumer goods share plus its supply share, times its total IC,
to within the last thousandth or two: East Germany has shares of 0.100 and 0.180 and a total
IC of 2, and the save says `usage = { metal=0.557 ... }`. They also earn money and make
supplies, and all of it lands in the pool of their capital province, whoever holds it - Berlin,
for East Germany. Their `home` pool is not reset (the reset is inside `0x4F1F50`, behind the
first gate), so it holds every day's total since the game began, where `usage` holds one day's.

`+0xBD8` reaches the leadership shares as a thousandths value: the shift by 30 and the divide
by `0x1F40000` are the thousandths-to-fixed-15 conversion.

## 2. `0x4F9F10 / 0xF9F10` - the second term of consumer goods demand

`FINDINGS-production.md` has `CCountry::GetConsumerGoodsNeeded` (`0x4FA020`) as "modifier 40 or
41, plus a term from `0x4F9F10`, clamped". This is that term.

**Extent `0x4F9F10..0x4FA01B`**, ending `ret 4` at `0x4FA019` with four `int3` before
`0x4FA020`. **The country arrives in `edi`** and the out-pointer is the one stack argument, so
no ordinary signature can be written for it. Two callers: `0x4FA083` in
`GetConsumerGoodsNeeded`, and `0x5195A0`, unread - by its neighbourhood the consumer goods
tooltip.

    k = (int)floor(250.5f)                         ; the float at 0x160A688
    *out = 0
    if (country->at_war (+0xACC))  return          ; nothing at war
    if (country->TotalIC (+0x604) == 0) return
    t    = land_brigades_in_service (+0x108C) * 1000 / TotalIC      ; thousandths
    t    = t * k / 1000
    n    = clamp(effective_neutrality (+0xA90) * 1000 / 100000, 0, 1000)
    *out = t * n / 1000

So, **at peace**:

    demand = PEACE_CONSUMER_GOODS_DEMAND
           + 0.25 * (land brigades in service / total IC) * (effective neutrality / 100)

and at war it is `WAR_CONSUMER_GOODS_DEMAND` alone; either way clamped to 0.010 .. 0.990 by
the caller. A neutral country with a large standing army for its industry pays for it in
consumer goods, and the charge disappears the moment it is at war.

The three fields are all already in the record under those names: `+0x108C` counts a land
subunit when the country is mobilised or the subunit is not a reserve, so **mobilising raises
the demand** as well as calling up the reserves; `+0xA90` is neutrality less the threat from
one country, 0 to 100000.

The 250 is a `floor(N.5f)` static, so it is not a define and no file can move it (trap 8,
case 3).

**Not checked against a running game.** A savegame does not carry the demand, and the one
country whose share in the save can be trusted to be untouched - Germany, the human player -
has a consumer goods share of 0.224 that this formula does not reproduce from the laws and
brigades the same save holds (it gives 0.252). So either the share was set earlier, under
other laws, or something else feeds modifier 41. See the last section.

## 3. `CDistributeSupply::Distribute`, `0x51AA80 / 0x11AA80`, read through

Recorded until now as "not read line by line". Slot 0 of `CDistributeSupply` (table
`0x15C2208`, the only table holding it). `this` in `ecx`, `ret 0x10`, extent to `0x51ADCE`.

    alloc    = percentage (+8) x available x factor (+0x10)             ; fixed 15
    made     = MakeSupplies(percentage, available)                      ; 0x51ADD0, below
    country->HomeProduced.supplies (+0x778) += made, in thousandths
    free     = percentage x factor x lend_lease_ic (+0x608)

    left = made
    if (gamestate->+0xC9C <= 0 && country->+0x610 > 0 && the acting capital has an area)
        for each province in that area's list
            if (owner id != country id)            continue
            if (country not in its core list)      continue
            if (province IC <= 0)                  continue
            part = min(1, province IC x (1 + LOCAL_IC) / country->+0x610) x made
            province->pool.supplies (+0x164)             += part
            province->current_producing.supplies (+0x270) = part
            if (province != acting capital) country->to.supplies (+0x9B8) += part
            left -= part
    if (left > 0) GetPool(country).supplies += left

    charge = alloc - (free > 0 ? free : 0)
    if (charge > 0) ConsumeIcResources(country, charge)
    return 0

Three things worth stating.

- **Supplies are made where the factories are.** Each core province of the capital's own area
  gets the share of the day's supplies that its IC is of `+0x610` - the "core home IC" figure
  `FINDINGS-ic.md` could not name a use for. This is one of its two readers; the other,
  `0x4F1C9E`, is the fuel conversion below, which does exactly the same. What does not fit a
  province goes to the stockpile.
- **There is no resource check.** Unlike the production queue, the supply share does not ask
  `GetResourceLimitedIC` first: the supplies are made and the resources charged whatever the
  stockpile holds.
- **`+0x9B8`, the `to` pool, is not "sent to the units"**: it is what was made outside the
  capital province. Germany's save has `home.supplies = 283.840` and `to.supplies = 259.982`
  (**measured**); the difference is Berlin's own share.

### `0x51ADD0 / 0x11ADD0` - how many supplies an allocation makes

`out` in `esi`, `this` (the setting) in `edi`, percentage and available on the stack,
`ret 0x10`. Two callers: `Distribute` at `0x51AB19` and `0x51AF82`, which is the supply
slider's tooltip.

    x = percentage x available                                          ; fixed 15, IC
    x = x * IC_TO_SUPPLIES                         ; `economy +0x10`, thousandths -> fixed 15
    x = x * (1 + technologyStatus[+0x9C] + countryValues[GLOBAL_SUPPLIES])
    x = x * factor (+0x10)
    if (available > 1000 && x < 0) x = 99999                            ; overflow guard

`countryValues +0xD8` is modifier 27. `CTechnologyStatus +0x9C` is new: **the technology
bonus to supply production**, in thousandths - what the `ic_to_supplies` key of a technology
adds up to. The two are **added**, not multiplied, the same way `UpdateIC` adds the
technology IC bonus beside `GLOBAL_IC`.

**Measured:** Germany has a supply share of 0.15518, 201 IC, `IC_TO_SUPPLIES = 7`, four levels
of `supply_production` at 0.05 and a law worth `global_supplies = 0.1`. 0.15518 x 201 x 7 x
1.3 = 283.84, and the save says `283.840`.

## 4. `0x4F19F0 / 0xF19F0` - crude oil into fuel

Unrecorded until now. **The country arrives in `esi`**, no stack arguments, two bare `ret`s
(`0x4F1DD7`, `0x4F1DF6`), `int3` to `0x4F1E00`. One caller, `0x4DB449`. It is the other half of
the pair `CLASSES.md` describes as "the conversion pair": `UpdateIC` turns energy into crude
oil, and this turns crude oil into fuel.

    pool = GetPool(country)
    if (pool.fuel >= 99000.000) return

    income = the crude oil slot of eight of the country's pools:
             home, convoyed_in, traded_for, +0x848, +0x8B4, +0x8FC, back, +0xA64
    days   = (int)floor(365000.5f)                 ; the float at 0x160A9C0 - 365, in thousandths
    if (pool.fuel > income * days / 1000           ; more than a year of the oil coming in
        && pool.fuel / 2 > pool.crude_oil) return  ; and more than twice the oil in stock

    amount = (TotalIC / 2) * 1000                  ; whole IC halved, as thousandths
    if (amount > pool.crude_oil) amount = pool.crude_oil
    pool.crude_oil            -= amount
    country->+0x8D8.crude_oil += amount            ; what the conversion used
    fuel = amount * (1000 + technologyStatus[+0x20]) / 1000
                  * (1000 + countryValues[FUEL_CONVERSION]) / 1000      ; modifier 92
    country->+0x8B4.fuel      += fuel              ; what the conversion made

    then the same spread as section 3: each core province of the capital's own area gets
    its IC's share, into pool.fuel (+0x168) and current_producing.fuel (+0x274), counted
    in `to.fuel` (+0x9BC) outside the capital; the rest goes to the stockpile.

So **a country refines half a unit of crude oil per IC per day**, however much fuel that
makes, and stops only when it is swimming in fuel. `CTechnologyStatus +0x20` is new: the
refining bonus. The two bonuses **multiply** here, where the supply bonuses add.

**Measured, and it fits:** Luxembourg and Honduras have 4 IC, so 2 crude oil a day, and after
the two days the save has behind it each holds 4.000 fuel. Tibet has 2 IC and holds 2.000.

## 5. The fixed-15 arithmetic, as these bodies do it

Three conversions recur in sections 3 and 4, always in the same shape, and a reimplementation
has to round the same way to reproduce a savegame's last digit:

- **thousandths to fixed 15**: `(x << 30) / 0x1F40000` through the signed 64-bit divide
  (`0xB99980`), so `x * 32768 / 1000` truncated toward zero. 0.1 becomes 3276, and the save
  writes that share back as `0.09998`.
- **a product**: the 64-bit multiply (`0xB99AF0`), then `shrd eax, edx, 0xf` with
  `sar edx, 0xf` - an arithmetic shift, so it rounds **down**, not toward zero.
- **fixed 15 to thousandths**: multiply by `0x1F40000` and shift right by 15 twice. Down again.

**Measured, and not read:** the resource charge is not rounded the same way in the two shares
that spend everything. Twenty countries that do not exist fit this and nothing else tried:

    supply:          thousandths( share x TotalIC )            ; multiplied out, then converted
    consumer goods:  thousandths( share ) x TotalIC            ; converted, then multiplied

East Germany, shares 3276 and 5898 out of 32768 and 2 IC: 0.099 x 2 + 0.359 = 0.557, which is
its saved `usage`. The supply half agrees with section 3; the consumer goods half says
`CDistributeConsumerGoods::Distribute` turns its percentage into thousandths before it
multiplies by `available`, which `FINDINGS-production.md` does not go into.

## 6. Energy into crude oil, read through - and a correction to `FINDINGS-ic.md`

The block is `0x4F0FF5`..`0x4F13E2` inside `CCountry::UpdateIC`, the country in `ebx`.
`FINDINGS-ic.md` summarises it as taking "the rate as `1 + 2 * technologyStatus[+0x98]`" and
capping the run at `max(total_ic * 0.05, 1.0)`. **Both halves of that are misread.** The
`1 + 2 x` expression is a divisor in a different term, and the cap is on the crude oil made,
not on the energy used. Read instruction by instruction:

    need   = TotalIC * 2000                         ; what industry wants today, thousandths
    spare  = pool.energy - need                     ; [ebp-0x20]
    most   = max(TotalIC * 1000 * 1000 / 20000, 1000)        ; 0.05 an IC, at least 1.000
    if (!applyDailyEffects || spare <= 0) skip

    energyNet = yesterday's energy income less expense, off fifteen of the country's pools
    crudeNet  = the same for crude oil
    rate   = base + technologyStatus[+0x98]         ; base = 100, see below - so 0.1 + technology
    wanted = (pool.energy + energyNet - 2 * (pool.crude_oil + crudeNet)) * 1000
             / (1000 + rate * 2000 / 1000)
    if (wanted <= 0 || rate <= 0) skip

    per    = max(round(1000000 / rate), 1000)       ; energy per unit of crude oil, at least 1
    energy = min(most * per / 1000, wanted)         ; through floats: (x / 1000 + 0.0005) * 1000
    energy = min(energy, spare)
    crude  = energy * rate / 1000
    if (energy <= 0 || crude <= 0) skip

    pool.crude_oil += crude ;  pool.energy -= energy
    conversion_used.energy (+0x8F4) += energy ;  conversion_made.crude_oil (+0x8C8) += crude

In words:

- **A unit of energy makes `rate` units of crude oil, and `rate` is 0.1 plus the technology
  bonus.** The base is the global at `0x1A87478`, which the image does not hold a value for:
  the static initialiser at `0xCB6650` writes it as `(int)floor(100.5f)`, the float at
  `0x160A684`. So it is 100, a tenth, and no define moves it (trap 8, case 3).
  `CCountry::GetOilConversionRate` (`0x4F17F0`) is that sum; the block calls it three times
  and inlines it once.
- **A country makes at most `max(0.05 x TotalIC, 1)` crude oil a day this way**, and spends
  `1 / rate` energy on each unit - never less than one energy a unit, which only matters
  once `rate` passes 1.
- **It converts only towards a balance.** `wanted` is the amount of energy that, converted,
  leaves the country holding exactly twice as much energy as crude oil, counting yesterday's
  net flow of each: solve `E - x = 2 (C + rate * x)` for `x` and the `1 + 2 * rate` divisor
  falls out. A country with less than twice as much energy as crude oil converts nothing.
- **And never into what industry needs today**: `spare` is the last cap.

The two net flows each sum the same fifteen pools, one slot apart. Income: `home`,
`convoyed_in`, `traded_for`, `+0x848`, `conversion_made`, `+0x8FC`, `back`, `+0xA64`. Expense:
`to`, `usage`, `conversion_used`, `convoyed_out`, `traded_away`, less `+0x824` and `+0x920`,
which are subtracted from the expense - the second is the tribute a subject sends, which
`CLASSES.md` has as held negative.

**Measured, and it fits to the unit.** In a vanilla 1936 savegame two daily passes in, with
the stockpile's starting energy known: Bhutan, 2 IC and no technology, is down 10 energy a
day (1 crude oil at 0.1). The United States, 153 IC and one level of the conversion
technology, 38.25 a day: 7.65 crude oil at 0.2. Germany, 201 IC and two levels, 33.5 a day:
10.05 at 0.3.

The rounding goes through single-precision floats and back - `cvtsi2ss`, a divide by the
double 1000.0, an add of 0.0005, a multiply by 1000.0, then the floor-and-convert pair
`0x401FD0` / `0xC08870`. It is round-to-nearest-thousandth dressed up; a reimplementation in
integers should reproduce it for any value a stockpile can hold, but that was not proved.

## What is not established

- **What sets a country's shares at the start.** In the save, every country that does not
  exist - and Germany, the player - has five shares exactly equal and a consumer goods share
  that is a round number of thousandths. For about half of them that number is
  `0.25 + PEACE_CONSUMER_GOODS_DEMAND` under the laws their history file gives; for the rest
  it is not, and it is not that sum under the laws in the save either. Nothing read here
  writes a share.
- **When the AI changes laws.** The save shows Germany on one industrial policy and its supply
  output only fits the one its history file gives, so the last change of law came after the
  last daily pass and before the save, with the date still at hour 0. Seven countries that do
  not exist show the same. What runs there, and how often, is unread.
- **`0x5020E0`**, the first call of the economy block, and **`0x4F1F50`**, which
  `FINDINGS-politics.md` has as writing `+0x754`..`+0x790`.
- **Why `gamestate +0xD0C` is tested here.** The record has it as `scenario`
  (`FINDINGS-session.md`, section 8). Non-zero, it gates a call on the first leadership share
  here and skips the dissent change in `CDistributeConsumerGoods::Distribute`; what a scenario
  pointer has to do with either was not followed.
- **`0x5195A0`**, the second caller of the demand term.
- ~~**Whether `ConsumeIcResources` can take a stockpile below zero.**~~ It can, for a day:
  supply and consumer goods call it without asking what the stockpile will bear, its own body
  is a plain subtraction, and `RunDailyProvincePass` ends by holding each of a land province's
  seven goods between nothing and 99999. Settled 2026-10-10 against a savegame -
  `FINDINGS-supplyconvoys.md`, section 8.
- **`0x500F3E`**, a third reader of the base conversion rate at `0x1A87478`, in a function
  nothing here has read.
- **Which technology keys fill `CTechnologyStatus +0x20` and `+0x9C`.** Both are named here
  from their one reader. `+0x9C` fits `ic_to_supplies` on a savegame; `+0x20` was not fitted to
  anything, `refinery_efficiency` being the obvious candidate.

## In the record

Entered the same day through `fragments/merged/distribute.json`:
`CCountry::GetStandingArmyConsumerDemand` (`0xF9F10`), `CCountry::ConvertCrudeOilToFuel`
(`0xF19F0`), `CDistributeSupply::GetSuppliesMade` (`0x11ADD0`), the loop as the label
`RunCountryDailyPass_DistributeProductionShares` (`0xDB4F3`), `CDistributeSupply::Distribute`
revised from `inferred` to `confirmed`, and two fields on `CTechnologyStatus`,
`fuel_refining_bonus` (`+0x20`) and `supply_production_bonus` (`+0x9C`). The names are ours.
Section 6 followed through `fragments/merged/oil-conversion.json`: the label
`UpdateIC_EnergyToCrudeOil` (`0xF0FF5`), `InitBaseOilConversionRate` (`0x8B6650`),
`CCountry::GetOilConversionRate` revised from `likely` to `confirmed` with its base rate, and
`CTechnologyStatus +0x98`'s comment corrected.

Applied headless to a copy of the Ghidra project after each: `failed: 0`, and
`struct fields: 0` on the second run.
