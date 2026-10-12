# The leader window's tooltips

Read on 2026-10-12 for OpenHOI3's tooltips, after `FINDINGS-unitpaneltooltips.md`. Static reading
of `hoi3_tfh.exe`; **every address is a VA** (image base `0x400000`) unless it says rva.
`FINDINGS-leaderwindow.md` is the window itself; its *Not established* left this part out.

**Synopsis.** The window's tooltips are one routine, **`CLeaderAssignmentPanel::ElementTooltip`
(`0x7681C0`)**, which only the unit panel's header asks (`CUnitView::BuildTooltip`, first thing,
while the window is shown). It asks the trait filter first and that answer is final; then the row
that holds the element, whose answer stands if it says anything; then by name: `gaintrait_info`
the traits the window's leader is on his way to, `selected_photo` his own tooltip, `trait_icon`
the trait's name and what it does, `filter_traits` `TRAIT_FILTER_DESC`. **Anything left falls back
to the header's own names**, so a row's `leader_button` says what the header's leader button
says. A trait's two texts are its slot 6 - the name, rendered when the trait is made - and slot 7,
a line per effect; a filter row's checkbox says the effects and `TRAIT_FILTER_ENTRY_DESC`.
**Corrected on the way**: the leader's own tooltip says how many he may command only where he
**commands** a unit and it is a fleet or an air unit, and picks ships or planes by that unit -
`FINDINGS-unitpaneltooltips.md` section 13 had it by his kind. That the original shows the
window's tooltips at all the bytes read do not settle; the maintainer's screenshot does.

## 1. How it is reached

`0x7681C0` has one caller, `0x76A2B4` in `CUnitView::BuildTooltip` (`0x76A210`), which asks it
while the panel at `+0x34` is shown and keeps its answer where it gives a `text` or a `delayed`
(`FINDINGS-unitpaneltooltips.md` section 3). Push order at the call: the element, the out, the
panel - so `(panel, out, element)`, `ret 0xC`. `confirmed`

**The window's elements do reach it - seen, not read.** The in-game screen asks the unit panel
only for an element the panel's window holds (its `+0x18`'s slot 37, the recursive descendant
test, `FINDINGS-guicontainers.md`), and the leader window is made by the factory of the in-game
screen (`[CCurrentGameState +0xBE8]`, its slot 14 the gui at `+0x60`) with the screen's slot 16 -
`lea eax, [ecx+0x1794]` - as the second argument, which was not followed; so the bytes read do not
show how the window comes to be held by the panel's. **The maintainer's screenshot of the running
game, 2026-10-12, shows it is**: an Italian corps' leader window with `Engineer`, a trait's name,
in the tooltip box over a row's trait icon - section 5's `text`, the delayed half not yet shown.

## 2. The panel's routine (`0x7681C0`)

`(panel, out, element)`. In order:

1. **The trait filter**, where its window (`[+0x1E8]+4`) is shown (`+0x5B`) and holds the element
   (slot 37 of its `+0x18`): `0x767110` - the filter's list (`+8`), the first row whose window
   holds the element (its `+0x1C`'s slot 22), and that row's tooltip (`0x766D40`, section 5); with
   none, an empty tooltip. **The answer is final**, empty or not.
2. **The rows**: the window `leaderlist`, the first row whose window holds the element; its
   tooltip (`CLeaderAssignmentEntry::ElementTooltip`, section 3). Where it has a `text` or a
   `delayed` that is the answer; otherwise the search stops and goes on by name.
3. **By the element's name** (slot 17), first that matches:

| element | what it says |
| --- | --- |
| `gaintrait_info` | the traits to gain (`0x765D40`, section 4) of the window's leader, `+0x1E0` |
| `selected_photo` | that leader's own tooltip (his slot 9, `CLeader::BuildTooltip`) |
| `trait_icon` | the trait named by the element's `+8` (section 5): its slot 6 into `text`, its slot 7 into `delayed` |
| `filter_traits` | `TRAIT_FILTER_DESC`, in `text` |

Anything else: an empty tooltip, so `CUnitView::BuildTooltip` goes on with its own names (section
6). `confirmed`

`+0x1E0` is the unit's leader as the window opened (`FINDINGS-leaderwindow.md` section 2), the
null leader where it had none.

## 3. A row (`CLeaderAssignmentEntry::ElementTooltip`, `0x766060`)

`(entry, out, element)`, `ret 0xC`. Empty unless the row's leader (`+0x28`, an id pair) resolves;
then by name: `gaintrait_info` his traits to gain (section 4); `trait_icon` the trait's slot 6 and
slot 7 as above; `photo` his own tooltip (slot 9). Anything else empty. `confirmed`

## 4. The traits to gain (`0x765D40`)

The leader in `EDX`, the out pushed, a bare `ret` (`0x7683D1`..`0x7683E3`: `mov edx,[edi+0x1E0]`,
`push`, `call`, `add esp,4`).

    progress = CTraitGainTracker::BuildProgressTooltip of his +0xC4
    progress empty:   NO_TRAIT_TO_GAIN_DESC
    otherwise:        TO_GAIN_TRAITS_DESC + "\n" + progress

all in `text`. `confirmed`. The progress lines are `FINDINGS-unitpaneltooltips.md` section 13's:
a trait's line only while it is above nothing and short of the whole. The null leader is made
with a tracker of its own (`CNullLeader::CNullLeader`) and so says `NO_TRAIT_TO_GAIN_DESC`.

## 5. A trait's texts

**Which trait.** `CTraitEntry::CTraitEntry` gives its window the trait's key through slot 30 of
the window's `+0x18`, and the element's `+8` carries it - as the battle window's modifier icons
carry their id (`FINDINGS-battletooltips.md` section 1). The key is looked up by
`CTraitDataBase_Find` (`0x5B4E00`: the database in `EAX`, the name pushed, `ret 4`; a hash
table, `h = (h + c) * 61` over the name's bytes as signed chars, `h` modulo `+4` into the buckets
at `+8`, a bucket a chain of `(trait, next)`; the name compared length and bytes). Where it is not
there, `CNullTrait_Instance` (`0x5B4440`), a null trait of its own made on first use and kept at
`0x1A855E8` - not the one at index 0 of the database. `confirmed`

**Its name** is slot 6 (`0x5B29D0`): the string at `+0x48`, which the constructor
(`CTrait::CTrait`, `0x5B26F0`, `(storage, key, index)`, `ret 0xC`) fills with the key's text,
rendered once as the trait is made. `confirmed`

**What it does** is slot 7 (`0x5B4350`): for each of its effects, in its file's order, a line
(`TraitEffectLine`, `0x5B30B0`: the kind in `ECX`, then the out, the value and the terrain pushed,
`ret 0xC`), with `\n` between lines and none after the last:

    the label, by the kind:
         0 TRAIT_XP_GAIN               11 TRAIT_SUBMARINE_ATTACK      22 TRAIT_ENVELOPMENT_BONUS *
         1 TRAIT_SURPRISE_CHANCE       12 TRAIT_DISENGAGE_TIMER  #    23 TRAIT_EXPERIENCE_BONUS
         2 TRAIT_SUPPLY_CONSUMPTION *  13 TRAIT_SPREAD_OUT            24 TRAIT_FORT_DEFENCE
         3 TRAIT_DEFENCE_MODIFIER      14 TRAIT_SPOTTING_CHANCE       25 TRAIT_AMPH_ATTACK
         4 TRAIT_OFFENCE_MODIFIER      15 TRAIT_DEFENDER_SOFTNESS     26 TRAIT_DIGIN_BONUS
         5 TRAIT_COMBAT_MOVE_SPEED     16 TRAIT_STRATEGIC_ATTACK      27 nothing
         6 TRAIT_WINTER_ATTRITION *    17 TRAIT_NAVAL_ATTACK          28 TRAIT_TERRAIN_SPEED, TYPE = the terrain's text
         7 TRAIT_RIVER_ATTACK          18 TRAIT_NIGHT_ATTACK          29 TRAIT_TERRAIN_ATTACK, TYPE = the terrain's text
         8 TRAIT_FORT_ATTACK           19 TRAIT_TACTICAL_ATTACK       30 nothing
         9 TRAIT_COMBINED_ARMS_BONUS   20 TRAIT_DISSENT_IMPACT
        10 TRAIT_OUT_OF_SUPPLY_MODIFIER 21 TRAIT_ENCIRCLEMENT_BONUS *
    then " §G" where the value - negated for the four marked * - is above 0, else " §R"
         (0x5B4173..0x5B4195: `cmp esi, ebx; jle` to 0x15C341C)
    then "+" where the value itself is above 0
    then for 12, marked #: FormatFixedPoint(value, 0 places)
         for the rest:     FormatFixedPoint(value * 100000 / 1000, 0 places) + "%§W"
                           (0x5B41B6..0x5B4225, 64-bit multiply and divide)

The kinds are `CTrait::LoadKey`'s numbering (the order of the comment heading
`common/traits.txt`): 27 is `paradrop_mission` and 30 `terrain_defence`. `confirmed`

**A filter row** (`CTraitFilterEntry::ElementTooltip`, `0x766D40`, `(entry, out, element)`,
`ret 0xC`): only where the element is the row's checkbox `background` (`+0x34`, found by name in
the constructor at `0x766C42`..`0x766C77`): its trait's (`+0x2C`) slot 7 in `text` and
`TRAIT_FILTER_ENTRY_DESC` in `delayed`. The null trait's row says no effects and only the second.
Its `trait_name` is `allwaystransparent` in the file, so the checkbox under it is what the mouse
finds. `confirmed`

## 6. What falls to the header

`CUnitView::BuildTooltip` goes on, by name, where the window's routine gave neither text nor
delayed (`FINDINGS-unitpaneltooltips.md` section 3). Of its names a row of the window has one,
`leader_button`, so **a row's button says `UW_LEADER_BUTTON_IRO`, delayed `UW_LEADER_BUTTON_DRO`**
- "Assign new leader." - where the mouse is on the button and not on a text box over it.
`confirmed` for the arithmetic of the dispatch; not itself seen in the running game.

## 7. The leader's own tooltip, corrected

`CLeader::BuildTooltip` (`0x580220`): the command-size line is written where his unit (`+0x40`)
is set (`0x5803F3`..`0x5803F9`, to `0x58085D` with none) **and** that unit is a fleet (its slot
16) or an air unit (slot 17) (`0x580401`..`0x58041B`); the size and the rank test are of that unit
(`0x5800A0` and `0x5CD960` with `[leader+0x40]`), and `SHIPS_LABEL` or `PLANES_LABEL` is by its
slot 16 (`0x580673`..`0x58068B`). The positioning line is by his own kind (`+0x68 == 1`,
`0x58085D`). So a leader commanding nothing - most of the window's rows - has no command line.
`confirmed`

**The null leader** is `CLeader::CLeader` (`0x57F580`, `(storage)`, `ret 4`), which zeroes his
kind, rank, skill, most skill and experience (`+0x68`..`+0x80`), with the name `NO_LEADER`'s text:
his tooltip is `INACTIVE`, the name, skill 0 with `LEADER_SKILL_AT_MAX`, and an experience of
nothing.

## Kept as read, though they look odd

1. Paradrop mission and terrain defence have no label: their lines are the colour and the
   figure alone.
2. An effect of nothing is red.
3. More encirclement and envelopment bonus is written red, as more supply consumption and winter
   attrition are.
4. A row's button says "Assign new leader." - the header's - having nothing of its own.
5. The row of no trait in the filter says nothing but the second half.

## Not established

- What the in-game screen's `+0x1794` is, and so how the leader window comes to be held by the
  unit panel's - that it is, the maintainer's screenshot shows (section 1).
- The null trait at `0x1A855E8`: what its constructor names it, which a key missing from the
  database would show.
