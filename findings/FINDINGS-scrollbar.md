# A scrollbar's end buttons: the step, Ctrl, and holding

*Read 2026-10-12 for OpenHOI3's sliders, after the maintainer's account of the running game: "You
can hold the mouse button for them to continue changing the value. Holding CTRL speed that up
considerably." The mechanics spec is `OpenHOI3/docs/mechanics/interface.md`, section 2. Addresses
are VA / rva. Everything here is one build of `hoi3_tfh.exe`.*

What a press of a `scrollbarType`'s end button moves it by, what Ctrl and a second key make of that,
and how holding the button repeats it. The production and technology screens' sliders are
scrollbars (`FINDINGS-countryviews.md`, section 2), and so are the list boxes' bars.

**How it was read.** The constructor and the six handlers were decompiled headless out of a copy of
the Ghidra project with the record applied (`ghidra/DecompileAt.java`), and the one instruction the
repeat hangs on was read in the listing (section 3). Nothing was watched running; the maintainer's
account is what it was read against.

## 1. The handlers

The scrollbar (vftable `0x15FF7A0`, the record's `GuiObject_scrollbarType`; `CScrollbar` on the
observer convention, `FINDINGS-guilive.md`) is built at `0xA9DB30`. It gives each of its end buttons
a `CButtonObserver` (`0xA9A740`: the observer in EAX, the owner in ECX, nine handlers each with an
adjustment on the stack, `ret 0x48`) with three of them:

| | `leftbutton` | `rightbutton` |
| --- | --- | --- |
| pressed | `0xA9F3F0` | `0xA9F680` |
| held, each frame | `0xA9F980` | `0xA9FAD0` |
| let go | `0xAA01E0` | `0xAA0210` |

`confirmed` for the addresses (`0xA9DC4A`..`0xA9DCA0`); which of the observer's events is which is
`inferred` from what each does.

## 2. A press

`0xA9F3F0`, ECX the scrollbar, `confirmed` off the decompilation and the listing:

    if the bar is switched off (its +0xA0's slot 44 answers 3):  nothing
    step = the declared step, in thousandths                      ; +0x48's slot 6, its +8
    if step == floor(1.5) = 1:   step = step * 10000 / 1000        ; a thousandth counts as ten
    if the input object's slot 10 is down:  step = step * floor((+0x204 * 10  + 0.0005) * 1000) / 1000
    if the input object's slot 12 is down:  step = step * floor((+0x208 * 100 + 0.0005) * 1000) / 1000
    if the state (+0x64) is 4 or 10:
        move the value by -step (by +step where +0x23C is set), noting the player moved it
        and telling its observers                                   ; 0xAA0060
        state = 10
    if the state is 2:  state = 10

The input object is the gui's (`+0x28`, then `+0xA4`). `+0x204` and `+0x208` are 1 from the
constructor (`0xA9DF2E`, `0xA9DF34`), so **one key multiplies the step by ten and the other by a
hundred**, and both by a thousand. `0xA9F680` is the same for `rightbutton`, with the signs the other
way and the step passed through `floor((step / 1000 + 0.0005) * 1000)`, which leaves a whole number
of thousandths as it is; its states are 5 and 10, and 3.

**Which keys.** The builder windows' step buttons ask the game screen's input object at slot 12, and
their own tooltip says "Ctrl + LMB to add or remove 10" (`FINDINGS-buildertooltips.md`, section 2).
So slot 12 is Ctrl **if the gui's input object is of the same class** as the game screen's, which was
not traced: `likely`. The maintainer's word that Ctrl speeds the sliders up "considerably" fits a
hundred. **Slot 10 is Shift by the maintainer's word**, asked on 2026-10-12 which other key speeds
a slider up: "Its shift." That is the running game's answer and not the bytes': the key code behind
slot 10 was not traced either.

**The production and technology sliders declare `stepSize = 0.001`**: one thousandth, so a press is
0.01, Shift makes it 0.10, Ctrl 1.00 and both 10.00. The lend-lease slider's `0.01` is a press of 0.01
too, and is not multiplied.

**Moving the value** (`0xAA0060`, the scrollbar in EAX, three stack arguments, `ret 0xC`): the value
(`+0x220`, a float) as thousandths, `floor((value + 0.0005) * 1000)`, plus the step, kept between
`+0x38C` and `+0x390` where `+0x394` is set, stored back over 1000; the second argument sets
`+0x252`, and the third tells each observer in the list at `+0x4C` (their slots 2 and 1).

## 3. Holding

`0xA9F980`, every frame the button is down, `confirmed`:

    if the bar is switched off:  nothing
    clock = +0x200                                  ; made from g_random_object's slot 1
    if clock.GetSeconds() == 0:  clock.Start()
    else:                        held (+0x228) = clock.GetSeconds()
    every = 0.5 (+0x224, a float) * 0.30000001192092896    ; 0.15 s
    if held <= every:
        if clock.GetSeconds() > 0.5:  press; state = 2       ; never reached: held is the time itself
    else:
        do  held = held - every;  press  while every < held

Let go (`0xAA01E0`): state = 10, `clock.Reset()`, held = 0.

**The line the repeat hangs on** is `0xA9F9EE`..`0xA9F9F8`:

    d9 44 24 04   fld   [esp+4]          ; held, as it was
    d9 c0         fld   st(0)
    de ea         fsubp st(2)            ; DE E8+i: st(i) = st(i) - st(0)
    de c1         faddp st(1)
    d9 9e 28 02   fstp  [esi+0x228]

which is `held + (seconds - held)`: **each frame `held` is set to the whole time the button has been
down**, and the subtractions of the frame before are lost. The decompiler reads it the same way.

The clock is the platform's (`g_random_object`, `FINDINGS-tooltips.md`): a `CHighPerfWinClock`, whose
slot 1 (`0xB4FBE0`, **Start**) takes the performance counter and sets it running, slot 2
(`0xB4FE40`, **Reset**) zeroes its base and stops it, and slot 5 (`0xB4FE80`, GetSeconds) answers 0
while stopped. So the first frame of a hold starts it, and from the next:

    presses this frame = how many times 0.15 goes into the time held, less one at an exact multiple

**So holding presses nothing for 0.15 s, then once a frame, then twice, and so on: the longer it is
held, the more presses each frame makes, and the faster the game draws, the faster it goes.** A
second's holding at 60 frames a second makes 177 presses after the one the press made. `confirmed` for
the arithmetic; the frame count is the running game's.

## Kept as read, though they look odd

1. **A repeat that grows without end** - each frame counts the whole time held - and a branch for a
   first repeat at half a second that the arithmetic never reaches.
2. **The speed depends on the frame rate.**
3. **A declared step of exactly a thousandth is taken as a hundredth**, and no other step is
   multiplied.

## Not established

- **The key codes behind the input object's slots 10 and 12**: Shift by the maintainer's word, and
  Ctrl by the builders' tooltip if the gui's input object is the game screen's class.
- **What `+0x23C` is.** The constructor copies it from an argument (`0xA9DDA3`); the production
  sliders, which declare `horizontal = 1`, take away on their `leftbutton`, so it is not simply that
  key. With it set, `leftbutton` adds.
- **What sets `+0x204` and `+0x208`** other than the constructor; nothing in the scrollbar's own code
  does.
- **Which of the observer's nine events** are press, hold and let go, beyond what the handlers do.

## In the record

Entered in `ghidra/project.json` by `fragments/merged/scrollbar.json`: the six handlers, the move
(`CScrollbar_MoveBy`), the constructor, `CButtonObserver_Init`, and the clock's `Start` and `Reset`,
all new; with a `CScrollbar` struct of eleven fields. Then by `fragments/merged/scrollbar-shift.json`,
the same day, for the maintainer's word on slot 10: the two press handlers and `+0x204` revised.
