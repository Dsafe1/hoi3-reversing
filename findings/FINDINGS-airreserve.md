# An air reserve's day, and the crash it can end in

Read 2026-10-18, from a player's crash dump sent to the maintainer: BlackICE 15.1, the game six
hours and forty minutes in, ended by `abort()`. The dump's `hoi3_tfh.exe` is this build -
timestamp `50E56591`, image size `0x18AE000` - loaded at `0x100000` rather than `0x400000`, so
its addresses less `0x100000` are rvas. It is a small minidump - registers and stacks, no heap -
so what it says about the objects involved stops at their addresses.

## 1. What the dump shows

The exception recorded, `0x40000015`, is `abort()`'s: the C runtime's unhandled-exception filter
was handed a **C++ exception nothing caught** and ended the process. The pointers it was handed
give the original: `std::length_error`, thrown on the main thread in the hourly tick:

    Session::PumpCommands -> CHourlyTickCommand::Execute -> RunHourlyTick -> RunHourlyPass
      -> CAir::UpdateDaily -> CUnit::UpdateDaily -> (an order's RunDaily, see below)
      -> CAirReserveOrder::RunDaily (0x1964B0)
      -> CAirReserveOrder_ReinforceUnit (0x1966B0)
      -> CAirOrder::CopyByUnitType (0x18A7C0) -> std::vector_assign (0x4DD860)
      -> std::vector_Buy (0x142A60): a count of 0xF24E2A94 > 0x3FFFFFFF
      -> std::_Xlength_error (0x794936), 'vector<T> too long'

The frame between `CUnit::UpdateDaily` and `CAirReserveOrder::RunDaily` is a stale return
address, not a call: the dump has no unwind data, `CAir::UpdateDaily` had just given the unit a
`CRebaseAirOrder` whose `RunDaily` is a bare `ret`, and `UpdateDaily` reaches an order's
`RunDaily` through slot 23 (`+0x5C`). Every frame from `CAirReserveOrder::RunDaily` down follows
a `call` that the bytes have at the address before it. So *which* call reached the reserve's day
this hour is not settled by the dump; that one was running, and what it did, is.

## 2. `CAirReserveOrder::RunDaily` (`0x1964B0`, slot 23)

The only table holding it is `CAirReserveOrder`'s; every other air order's slot 23 is the bare
`ret` at `0x6BF890`. `__thiscall`, no arguments, two bare `ret`s.

    if order.unit (+0x8).province (+0x130) != order.province (+0xC):  return
    base = order.unit.home_base_ptr (+0x98)
    for each unit in base's list (+4):
        if unit.order (+0xB0) is null:                skip
        if !unit.order.slot24():                      skip      ; only CNullOrder answers false
        bucket[unit.order.GetPriority()] += unit                ; slot 18
    for priority 3 down:
        for each unit in that bucket, but the reserve's own:
            if unit.order.slot24() and unit.order.GetPriority() == priority:
                CAirReserveOrder_ReinforceUnit(order, unit)

**Slot 18 is `COrder::GetPriority`**, as the record already had it: every air order answers a
constant 0 and the naval orders their `+0x38 priority`. **Slot 24 answers true for every order
class but `CNullOrder`** (`ReturnTrue` at `0x692590`, `ReturnFalse` at `0x192360`; read off all 29
order tables). So the loop **never asks what kind of order a unit holds**.

## 3. `CAirReserveOrder_ReinforceUnit` (`0x1966B0`)

`__stdcall`, the reserve's order and the unit, `ret 8`. Mostly unread (`0x11C0` bytes); the name
is from what it posts. It raises a **`REINFORCE_AIR`** message between the two owners, and then
copies the vector at `+0x34` of **the unit's order** through `CAirOrder::CopyByUnitType`
(`0x18A7C0`, `__thiscall`, the copy's out-vector on the stack, `ret 4`).

`+0x34` is `CAirOrder`'s `by_unit_type`. The copy reads it as a vector - begin `+0x34`, end
`+0x38`, capacity `+0x3C` - which the record held as a bare `int*` (*inferred* from the copy; the
field record is not revised here). **On any order that is not a `CAirOrder` those twelve bytes
are something else**: on a `CNavalOrder`, `return_to_base` (`+0x34`) and `priority` (`+0x38`);
on `CMoveOrder`, `CStrategicRedeploymentOrder` or `CSupportAttackOrder`, whatever those keep
there or what lies past a smaller object. The copy then asks for `(end - begin) / 4` elements,
and a nonsense length is either refused, as here - `std::length_error` - or allocated and copied
from wherever `begin` points.

## 4. What made this game crash - not established

The dump holds the source vector's address, `0xA72D5468` there, so the order was at
`0xA72D5434` - on the heap, which the dump did not keep. So it does not say **which unit at the
reserve's base held which order**. Three readings fit what it does show, and the vtable calls on
that order having worked is evidence against the third:

- **An air unit at the base holding an order that is not a `CAirOrder`** - section 3's case. Which
  of the five non-air classes an air unit can be given was not read.
- **A `CAirOrder` whose vector is corrupt** - by `CAirOrder +0x34` being written as something
  other than a vector somewhere.
- **A unit freed but still in the base's list**, its memory reused.

A save from shortly before the crash would settle the first: the reserve unit and the units
based with it, with their orders, are in it.

## In the record

`fragments/merged/air-reserve-reinforce.json`: five functions new - `CAirReserveOrder::RunDaily`
(and its slot), `CAirReserveOrder_ReinforceUnit` (inferred), `CAirOrder::CopyByUnitType`
(inferred), `std::vector_Buy` and `std::_Xlength_error`.
