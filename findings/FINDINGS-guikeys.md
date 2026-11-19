# Seven `.gui` keys OpenHOI3 passed over

*Read 2026-11-19, statically, from the install's `hoi3_tfh.exe` (a subagent's reading; the collecting session checked
the three revisions off the listing - the scrollbar reader's 22 cases, `buttonMesh` sharing `spriteType`'s case, and
both `priority` cases going through ParseFloat - before merging). Addresses are VAs (rva + 0x400000) unless marked
rva. Fragment: `gui-unused-keys.json`.*

## The readers

The value readers each key below goes through, all already recorded: ParseString VA 0xA7AFB0, ParseIntPairXY
0xA7B670, **ParseFloat 0xA7B640** (sscanf `%f`, format at 0x15FD134), ParseInt 0xA7B470 (`%i`, 0x15FD14C), ParseBool
0xA7B410.

So **every `priority`, `scale` and `rotation` in these grammars is a float**. That includes CWindowType's `priority` at
+0x124, which the record had typed `int` (corrected). Confirmed.

## 1. guiButtonType / checkboxType `parent`: template inheritance

**Where it is stored.** `GuiType_guiButtonType::LoadKey` (0xB2CE40) handles token 0x84 at 0xB2CFCC with ParseString
into **declaration +0x13C**. One type class serves both keywords. Confirmed.

**Who reads it.** Slot 7 of the type table 0x1606AD0, **`ResolveParent` (0xB2C6E0)**, runs once after loading:
- `CGui::ResolveTypeParents` (0xA7D740) walks the CGui's type tree (+0x34) and calls each top-level type's slot 7 with
  that tree, through `TernarySearchTree_ForEach` (0xA7E170) and the thunk 0xA7E200.
- A windowType's slot 7 (0xAC5350) does the same over its own child tree (+0x150) first, and so does a scrollbarType's
  (0xB287E0) over +0x160.
- **So a `parent` is looked up in the tree of the element's immediate container**: the window, or the scrollbar. The
  lookup is GuiTypeTree_FindByString, which is **case-insensitive**.
- Siblings are resolved in alphabetical order (the tree's in-order walk). Confirmed.

**What ResolveParent does.** The declaration carries a list of inheritable keys (+0x68). Its constructor (0xB2DA90)
fills it with exactly **quadTextureSprite/spriteType (+0x104), parent, tooltipText (+0x21C), position,
delayedTooltipText (+0x238)** - sprite, tooltipText and delayedTooltipText, not every button key. The steps:
1. If every listed key is "set", or `parent` is empty, nothing happens.
   - A string key counts as set when it is non-empty (IsKeySet 0xB2D4D0).
   - **`position` always answers set**, so although it has a copy case, **position is never inherited**.
2. Otherwise P = Find(parent), and every unset listed key is copied from P (SetKey 0xB2D8E0).
   - **There is no null test.** A parent the container does not hold reads through a null pointer, which is a
     load-time crash. Inferred from the bytes; not provoked.
3. If keys are still unset and P's own `parent` is non-empty and differs from this declaration's name,
   P = Find(P.parent) and step 2 repeats.
   - Only a direct loop back to self is caught. A longer cycle would loop forever (inferred).
4. When the chain ends with keys still unset:
   - **tooltipText = `Please add Text`**
   - **delayedTooltipText = `Please add Text To the delayTooltip`**
   - A `tooltip = NOTOOLTIP` branch exists but is dead, because `tooltip` (token 0x8F) is not on the list.
5. In every case, +0x278 = ParseGuiOrientation(+0x25C).

Steps 1-5 are confirmed off the bytes, VA 0xB2C6E0-0xB2CD9C.

**Negative, with its search and control.** No widget uses the `parent` string. Every construction path copies it by
value into the constructor and the constructor only frees it:
- GuiButton_Construct 0xB3FA50: arg at [ebp+0x20], touched only by the free at 0xB40603-0xB4061F.
- CheckBox_Construct 0xA80FA0, from the checkboxType create (slot 12, 0xB2BEE0): freed at 0xA817E0.
- 0xB41570 (from 0xB2C4C0) and 0xB5AA00 (from 0xB2C5E0): freed only.
- 0xB5B310 (from 0xB2C2A0) forwards it to GuiButton_Construct.

Positive control: in the same constructors, the tooltip argument beside it ([ebp+0x3C]) is copied into the widget. The
search was every `[reg+0x13C]` in .text by byte search with decode verification; in the gui types' code the only hits
are ResolveParent, IsKeySet, SetKey, GetParentName, the constructor, the destructor and the by-value copies in the five
creates.

**The uses.** All 22 base-game uses (20 in BlackICE) are a scrollbar's up/down button naming that scrollbar's slider
(`listboxSliderButton`, `ds_SliderButton`, `aggro_SliderButton`). Each sets its own sprite, and the slider's
tooltipText/delayedTooltipText are `""`. **So the only effect is that the end buttons' tooltipText and
delayedTooltipText become the two placeholder strings.** Confirmed for the declaration.
- *Not settled:* whether a tooltip ever shows them. The end buttons are built through 0xB2C4C0, which passes the
  localised tooltipText/delayedTooltipText (0xB2E0D0/0xB2E1E0) to the button; whether the in-game tooltip code shows
  them was not read.
- **For a reimplementation:** the rule is field-wise. An empty sprite, tooltipText or delayedTooltipText is taken from
  the named sibling in the same container, then from that one's parent, and so on. Position and every other key are
  never inherited. A chain ending with a tooltip text still empty fills in the placeholder.
- scrollbarType and listboxType have the same mechanism for their own `parent` (+0x110 and +0x84). The scrollbar's list
  includes priority; the listbox's list is size, position, background, step, borderSize, orientation. iconType has no
  `parent`: its slot 7 is the folded `ret 4`, and the token falls to CGuiType::LoadKey.

## 2. guiButtonType `scale`

**Where it is stored.** Declaration +0x290, a float through ParseFloat, default 1.0 (the constructor, from 0x171DBAC).
The guiButtonType create (slot 11, 0xB2C070) passes it, with `rotation` +0x28C, to GuiButton_Construct, which stores
them at **widget +0x150** and +0x14C. Confirmed.

**Who reads it.**
- Rotation goes straight to the drawn object's slot 34 (SetRotation) at construction (0xB40014).
- **Scale does not.** The button's slot 64 (`ReturnFloatAt150`, 0xB56050; the base table's slot 64 is `fld1`) is called
  from exactly one place: **`GuiButton_SetDisplayObject`, slot 56 (0xB40980)**, which swaps in a new drawn object and
  calls its slot 39, `C2dObject::SetScale`, with the scale.
- Search: every vftable dispatch through +0x100 whose result is consumed as an x87 float - one site (0xB40A84).
  Positive control: the scan finds this known site. GuiButton_Construct touches +0x150 only with its store.
- **So the picture made at construction, and any sprite set by GuiButton_SetSpriteType, is drawn at scale 1.0.** Only a
  drawn object handed in through slot 56 is scaled. The 32 dispatch sites through +0xE0 that call slot 56 include the
  portrait handouts after each PictureSprite_Construct.
- When applied, the sprite quad is (W/frames − L)·s by (H − B)·s (FINDINGS-buttonstatefx.md section 4), so s
  multiplies the drawn size.
- **The checkboxType create (0xB2BEE0) never reads +0x290**, so a checkboxType's scale does nothing.

**The one use.** `scale = 0.5` on `country_icon` (`current_policy_entry`, country_politics.gui) in both the base game
and BlackICE: a `GFX_minishield_small` masked shield. The code that fills it (VA 0x785440) sets the country through
slot 53 and makes no slot-56 call, and no +0xE0 site lies in the functions naming `country_icon` (0x785440, 0x6BA170,
0x655449's).
- **So it is drawn at full size.** Inferred, because the 32 +0xE0 sites were not each tied to an element.
- For a reimplementation: store it, draw the button's own sprite at 1.0, and apply s only to a picture code swaps in.

## 3. scrollbarType `priority`

**Where it is stored.** The record said `GuiType_scrollbarType_LoadKey` (0xB28C30) reads only lockable and drag. **It
handles 22 keys**: slider +0x68, track +0x84, rightButton +0xA0, leftButton +0xBC, rangeLimitMinIcon +0xD8,
rangeLimitMaxIcon +0xF4, parent +0x110, position +0x12C, size +0x134, borderSize +0x13C, maxValue +0x144, minValue
+0x148, stepSize +0x14C, startValue +0x150, **priority +0x154 (float)**, horizontal +0x184 (int), lockable +0x198,
drag +0x199, rangeLimitMin +0x19C, rangeLimitMax +0x1A0, useRangeLimit +0x1A4, and the child declarations. **It
forwards the rest to CGuiType::LoadKey, not CWindowType::LoadKey.** priority defaults to 0.0 (0xB28286).

**Who reads it.** Only the scrollbar's own inheritance: ResolveParent 0xB28957, IsKeySet 0xB297B1, SetKey 0xB299C4. The
only path to CScrollbar_Construct is the create 0xB284C0 (three callers), and it reads every other numeric field but
not +0x154.
- Search: every `[reg+0x154]` in .text. Positive control: the same scan finds the create's startValue read at 0xB2855C.
- **Clean negative: stored, inheritable, and read by nothing.** Confirmed.

## 4. iconType `buttonMesh`

`GuiType_iconType_LoadKey` (rva 0x6C8320, slot 4 of 0x12021B0; not recorded before) sends **tokens 0x35 `spriteType`
and 0xA9 `buttonMesh` to one case body**: ParseString into +0x6C (byte table 0xAC84E0). So `buttonMesh` *is*
`spriteType`, and whichever comes later in the block wins. Confirmed.

The other icon keys: position +0x94 (sets byte +0x9C = 1), 3dposition +0x88 (ParseVector3, +0x9C = 0), scale +0xA0
(float), orientation +0xA4, frame +0xA8 (`%i`), rotation +0xAC (`%f`).

All six uses (credits.gui, metaserver.gui ×4, settings.gui) name ordinary sprites (corneredTileSpriteType etc.). Treat
it exactly as `spriteType`.

## 5. listboxType `step`/`spacing`, `priority`, `allwaystransparent`

**`step`/`spacing` (+0x158, int, default 1 from 0xB2B165).** Read by nothing.
- The create (0xB2BDC0) reads only +0x68, +0xF4..+0x110, +0x160, +0x84 (`parent`, which the record had called the
  background) and +0xA0 (the background).
- No read goes through the widget's declaration pointer +0x140.
- step is on the inheritable list, but IsKeySet and SetKey have no case for it.
- The widget's own byte +0x158 is a different field (set to 1 at 0xB2BE9D).

**`priority` (+0x114, float).** Read only by IsKeySet and SetKey (0xB2B9DD, 0xB2BC69). It is not on the inheritable
list, so it is not even inherited. **It does nothing.**

Search for both: every `[reg+D]` in the type's code (VA 0xB2A000-0xB2C000) and the widget's (0xA8B000-0xA8F800), plus
every `mov r,[x+0x140]` in .text followed by a read through r. Positive control: that scan finds the known `offset`
reads (+0xFC/+0x100 at 0xA8C29E/0xA8C2A4) and +0x198. Confirmed.

**`allwaystransparent` (+0x198, bool, default no).** Read once, by GuiListBoxBase_Construct at 0xA8C43E through the
widget's +0x140.
- **When no:** the box's drawn object (+0xB4) is pushed, paired with the box, onto the graphics' (+0xD8) vector of
  {element, drawn object} entries (0xA78360). Every button (GuiButton_Construct), icon (CIcon ctor) and window
  background (CFixedWindow ctor) is registered the same way.
- **When yes:** it is not registered.
- Confirmed for the gate. What the list is for (the pictures the mouse is resolved against, so "yes" lets clicks and
  hover pass through the box's background) is **inferred**: the list's reader was not found.
- For a reimplementation: `allwaystransparent = yes` means the list box's background does not take the mouse. Its rows
  and scrollbar are separate elements and are unaffected.

## Not settled

- The reader of the graphics' +0xD8 pick list (which would turn §5's meaning into confirmed).
- Whether the placeholder tooltip texts of §1 are ever displayed.
- Whether any slot-56 caller targets a guiButtonType (§2).
- What CScrollbar_Construct and GuiListBoxBase_Construct do with the `parent` string addresses their creates pass
  (0xB2851E, 0xB2BE69).
- Which keyword's widget 0xB2C2A0/0xB5B310 build (table 0x1609280, from CWindowType slot 8's path).
- C2dObject::SetScale's record comment says "the icon and the button pass their own scale (+0xB8, slot 64)". In fact
  the icon reads +0xB8 directly in its own slot 56 (0xAA296A), and slot 64 is the button's getter. Left unrevised.

## In the record

Entered in `ghidra/project.json` by `fragments/merged/gui-unused-keys.json`: 22 functions - 17 new, five revised
(`GuiType_guiButtonType::LoadKey` with its offsets and what `parent` and `scale` do; `GuiType_scrollbarType_LoadKey`,
which reads 22 keys and not two; `GuiListBoxBase_Construct`, the `allwaystransparent` gate; `GuiType_listboxType_Create`,
whose +0x84 is `parent` and not the background) - four structs declared and twenty fields, one revised:
`CWindowType +0x124 priority` from int to float.

**A stale entry found on the way, not removed.** `InitialiseGui`, rva `0x27D740` (FINDINGS-startup.md), is this
`CGui::ResolveTypeParents`: its comment names the call at VA 0x632264, which is `call 0xA7D740`, rva `0x67D740` - its
VA was written as its rva (trap 1), which is why `buildFindings.py` has always left it out as "not a function start".
The merge has no way to retire an entry, and only it writes `project.json`, so it stays until one is added.
