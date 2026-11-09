# The politics screen's rows for making a puppet and liberating a country

Read 2026-11-09, for OpenHOI3's politics screen. Addresses are **VAs** (rva + 0x400000) unless marked rva. Nothing here is near a `Patch_*` site (trap 19). Release is in `FINDINGS-occupation.md` D.6 and `FINDINGS-effectrun.md`. `CCreateVassalCommand::Execute` and `OnAgree` were read on the decompile and checked on the listing at the branch points named below.

## 1. Are they dead? No

An inventory of OpenHOI3's said "their windows are only ever hidden". That is not true of the original; it describes the rewrite's own state at the time.

- `create_puppet` is hooked to `CPoliticsView`'s glue +0x1EC, whose handler 0x6BC970 is written at 0x6BB041. `liberate_country` to +0x220, handler 0x6BC530, written at 0x6BB09D (the constructor; `BuildWidgets` binds the buttons).
- `OpenPuppetSelection` (0x6BC970) and `OpenLiberateSelection` (0x6BC530) call the window's +0x18 slot 13 (+0x34) on `puppet_select` / `liberate_select`, the same slot the record's `CEU3Dialog::Show` and `CFixedWindow` entries name as Show.
- Positive control, same `findRefs --address` search: the literal `puppet_select` has seven code references, in `Show` (hide), `OpenLiberateSelection` (hide), `OpenPuppetSelection` (hide lookup, then its two later lookups including the Show at 0x6BCC76), `BuildWidgets`, `OpenPolicySelection` (hide). `liberate_select` is likewise seven.
- Rows are reachable through `CPuppetEntry::OnSelect` / `CLiberateEntry::OnSelect` (slot 4), through button glue: 0x67A310 is `mov eax,[ecx]; jmp [eax+0x10]`.

## 2. Which rows, and when

**A row is one candidate from a list; every listed candidate gets a row, none is ever greyed.** Neither the row's constructor nor anything else disables its button (`vassal_selection_button` is referenced only by the constructor; only by slot 53 and the observer hook). The list is built once, when the window is opened; `Update` does not refill it.

`create_puppet` / `liberate_country` (the two openers):

| condition | `create_puppet` | `liberate_country` |
| --- | --- | --- |
| nothing pending | enabled where `GetPossibleVassals` not empty, else disabled | enabled where `GetPossibleLiberations` not empty, else disabled |
| a pending id | disabled; cleared once that country owns a province | pending field `+0x24C` is never written but by the constructor and `Update`, so this branch never holds |

**`GetPossibleVassals(player)`** (rva 0xEE320, also Lua `GetPossiblePuppets`): rebuilt on every call into `CCountry +0x11E0`, walking the player's `OwnedProvinces` in list order, skipping provinces the player does not **control** and the player's capital (`GetCapitalLocation`); for each core on such a province, in core-list order, the country `c` is appended where `c` owns no province, `c` is not the player, `c` is not already listed, and `c`'s capital (`+0xE20`) is one of the player's `OwnedProvinces` (owned, not necessarily controlled). So for a player with annexed land: a country with no provinces of its own, with a core on land the player owns and holds, whose capital the player owns. Merely occupied (controlled, not owned) land gives no row. Order: the order of first discovery by that double walk.

**`GetPossibleLiberations(player)`** (rva 0xEDED0, into the same `+0x11E0`, so asking one throws away the other): for each country in the game state's vector, in order: a government in exile, owning at least one province, whose `GetCapitalLocation` (the **declared** capital, not the acting one) is controlled by the player, not the player, and `IsEnemy(that country, player)` false. Exiles of any faction, or none, can be listed.

Neither list is rechecked at press or by the row; `IsValid` on the command (section 5) and `StaysOpen` on the dialog are the only later checks.

## 3. What each element shows

Windows (`interface/country_politics.gui`, TfH override `tfh/interface/country_politics.gui`):

| element | what | key / source |
| --- | --- | --- |
| `puppet_select` `label_puppet` | `CREATE_PUPPET` "Create Puppet" | .gui |
| `liberate_select` `label_liberate` | `LIBERATE_COUNTRY` "Liberate Country" | .gui |
| `description`, both windows | `DOMESTIC_RELEASE_VASSALL` "Click on a flag to release the country as a puppet." | .gui; the liberate window really does use the same key |
| `back_button` | `CANCEL`; both glue to `OnSelectWindowBack`, the view's Show, which hides both | code (rva 0x2B6FC0) |
| `select_list` | the rows; emptied before fill | code |

Row `puppet_entry` (`CPuppetEntry`, new 0x98, 0x6B76B0):

| element | what |
| --- | --- |
| `create_puppet_entry` | static art `GFX_create_puppet_entry`; the name is absent from the image, so no code touches it |
| `vassal_selection_button` | `GFX_thinshield` (maskedflag) given the country's flag through slot 53 by id; it is the press target |
| `name` | `CountryNameOfCountry(target)` |
| `provinces` | see below |

`provinces` text: the provinces listed are those of the target's `CoreProvinces`, in list order, whose owner and controller are both the player. Where the count is under 4: `VASSALPROV` ("They will receive the following provinces:") rendered, then `" "` before the first name and `", "` before each later name, using the province's own name (`GetName`, its +8 subobject's slot 7 at +0x1C). Where 4 or more: `VASSALPROVNUM` ("They will receive $NUMBER$ provinces.") with `$NUMBER$` the count in decimal. With no provinces the row reads just "They will receive the following provinces:". This count is the row's own and differs from what the command actually does (section 5).

Row `liberate_entry` (`CLiberateEntry`, new 0x98, 0x6B8EB0): `create_puppet_entry` static; `selection_button` the flag; `name` the country name. No `provinces` element; the list at `+0x84` stays empty and the shared destructor (0x6B8040, 0x6B8070) frees it anyway.

**Row tooltips: none.** The buttons' `.gui` tooltip fields are empty and `CPoliticsView::BuildTooltip` (0x6BE790) walks six named lists only (`minister_list1`, `minister_list2`, `laws_listbox`, `policies_listbox`, `law_list`, `policy_list`); the literal `select_list` has exactly two code references, both inside the two `Open*` functions. Positive control: the same search finds the seven `puppet_select` references. The rows therefore say nothing on hover.

**Tooltips on the two opener buttons** (already in `FINDINGS-government.md` D.6, here word for word):

`create_puppet`: `POL_PUPPET_YES` "Create a new puppet state of any of your territory." where `GetPossibleVassals` is non-empty, else `POL_PUPPET_NO` "There are currently no possibilities for any puppets."

`liberate_country`: where `GetPossibleLiberations` is non-empty, `POL_LIB_COUNTRY_YES` "You can liberate any government in exile in your faction, if you control the country's capital. This will return control of their territory to them, and they will function as a proper country again." Otherwise, in order:

1. the player's faction invalid: `POL_LIB_C_NO_FACTION` "You are not a member of a faction."
2. the player in exile: `POL_LIB_C_WE_EXILE` "We are a government in exile, so we can't liberate others."
3. otherwise a line for each exile that owns land, is not the player, and is not the player's enemy, joined by `\n`: `@TAG - CapitalName (@CTRL)`, where `CapitalName` is the exile's declared capital's name and `CTRL` the capital's controller's tag (read off the operator+ chain at 0x6BF3B2-0x6BF454). None such: `POL_LIB_C_NO_EXILES` "There are no governments in exile in our faction." Otherwise `POL_LIB_C_POSSIBLE` "There are a few countries in our faction that are governments in exile, but we do not control their capitals." then `\n` then the lines. The test lists exiles of any faction despite the text's "in our faction"; no faction test is made there.

## 4. Pressing a row

`OnSelect` (slot 4; bare `ret`, nothing tests the target) makes the dialog (new 0x80), `CEU3Idler::AddDialog`, calls the view's slot 2 (`Show`, which hides `puppet_select` / `liberate_select`), and the dialog's slot 9 (BringToFront).

**The dialog** (`DefaultDialog`, `interface/eu3dialog.gui`, buttons `AgreeButton` "OK" and `DeclineButton` "CANCEL", shortcuts ENTER and ESCAPE; the constructors set no button labels):

- `Title` = the target's country name.
- `LeftShield` and `RightShield` both the target's flag.
- `Description`: `VASSALPROVNUM` with `$NUMBER$`:
  - puppet: the target's `CoreProvinces` with owner == player and controller == player;
  - liberate: the target's `OwnedProvinces` whose controller's faction is the player's faction (CCountry `+0xD8` pointer equal).
  - No other text; the description is set through `CEU3Dialog_SetDescription`.
- Placement: the window's own position (slot 26, read from its render node) plus (150, 150), through `CEU3Dialog::SetPosition`, after a call of the window's slot 10 with 0.
- `StaysOpen` (slot 7): puppet, target owns no province (`OwnedProvinces.count < 1`); liberate, target is a government in exile (`+0x95`). Closes itself otherwise.
- Cancel: `CEU3Dialog` slot 6, just closes.

**Agree (slot 5):** `NoteNewPuppet(view, target)` / `NoteLiberation(view, target)` first, then `new 0x4C` command, posted through the idler's slot 18 and its `+0x38` slot 6, then `closed (+0x64) = 1`. No checks of its own.

**The pending slot.** `NoteLiberation` writes the same `+0x218` as `NoteNewPuppet`, not `+0x24C` (as the record says). The consequence is smaller than `FINDINGS-government.md` D.9.1 suggests: after a liberation `create_puppet` goes grey for one `Update` only, because the exile by construction already owns land, so the very next `Update` clears the tag; `liberate_country` is re-decided by its list the next frame.

## 5. The commands

### `CCreateVassalCommand` (token 0x34E, 0x4C bytes): the puppet row

`CCreateVassalCommand(target, player)` (rva 0x14BC50): `+0x3C/+0x40` the vassal, `+0x44/+0x48` the overlord. Saved `from` and `to`. `IsValid` (slot 14, asked before Execute per `FINDINGS-commands.md`): both ids non-zero and the vassal owns no province. Note this is **not** `MakeVassal`, which requires the opposite (the target owns land) and is what `create_vassal` runs.

`Execute` (rva 0x14BD00, to the bare `ret` at 0x54C623), in order:

1. A list: the vassal's `CoreProvinces`, in list order, excluding the overlord's capital (`GetCapitalLocation`), whose owner is the overlord and whose controller is the overlord **or `REB`** (listing 0x54BDF0-0x54BE4F; REB tested by the three letters). So it can differ from the row's count: the row requires controller == player and includes the overlord's capital if it is on the list; the command excludes the capital and includes REB-held provinces. A call to `GetOriginalCapital(vassal)` at 0x54BED6 discards its result.
2. `ReleaseProvinces(list, vassal)` (rva 0xC1430, `FINDINGS-occupation.md` D.6): for each province `ChangeOwner` (the new owner takes control first) with `applyConsequences` 1 and `peaceful` 1, `war_seen_tick` set both ways against the old owner, a core for the vassal added, its capital moved if the history capital is here; afterwards every technology of the vassal raised to the overlord's level where lower (capped at its `max_level`); and for each released province whose values' IC modifier is above 0, a new three-infantry-brigade `CArmy`; the `INDEPENDANCE` message; `FillMinisterPosts(released, 1, 0)`.
3. A new `CVassal` (first the overlord, second the vassal, start today) on `overlord->diplomacy[vassal]->dependency`, `changed` set, appended to the game state's `relations`, activated.
4. The vassal's alignment position copied from the overlord's.
5. Relation +500000 both ways through an inlined `ChangeRelation`, clamped to [-200.000, 200.000].
6. Where the governments differ and the overlord's is `valid_for_new_country`, the vassal takes the overlord's government.
7. `CCountry_FillMinisterPosts(vassal, 1, 0)`.
8. Where the overlord's faction `IsValid`: `CFaction::AddCountry(faction, vassal, 0, 1)`, which joins it and its wars. **With no faction the vassal joins no wars.**
9. Where `overlord->diplomacy[vassal]->alliance` is not null (`cmp [ecx+0x14],0; je 0x54C5AA` at 0x54C378): a further `CAlliance` (first overlord, second vassal, start today) activated and appended. (As read; when this holds is not established.)
10. `RebuildNeighbours` and `CCountry_AfterDiplomacyChange` on the vassal, then the overlord.

No message of its own beyond `ReleaseProvinces`'s `INDEPENDANCE`; no neutrality change.

### `CLiberateCountryCommand` (token 0x59C, 0x4C bytes): the liberate row

`CLiberateCountryCommand(target, player)` (rva 0x14C8E0): `+0x3C/+0x40` the liberated, `+0x44/+0x48` the liberator. `IsValid` (slot 14): both ids non-zero and the liberated is in exile. `Execute` (rva 0x14C980, already recorded, re-read):

1. Every province the exile owns whose **controller's** faction is the liberator's faction (pointer equal; a country in no faction holds the one shared `CNullFaction` object, so two factionless countries compare equal) is given back: `Province_SetController(p, exile, today, applyConsequences 1, rebuildAreas 0, peaceful 1)`. No owner changes; no cores, no brigades, no technology.
2. Area and supply groups rebuilt.
3. **Only if the two are in different factions** (pointer test on `+0xD8`): a `CVassal` (first liberator, second liberated) on `liberator->diplomacy[liberated]->dependency`, appended, activated; alignment position copied; `ChangeRelation(liberator, liberated, +500000)`; government copied if different and `valid_for_new_country`; `FillMinisterPosts(liberated, 1, 0)`; `CFaction::AddCountry(liberator's faction, liberated, 0, 1)` when valid.
4. Message: variables built by `BuildMessageVariables(player's country)` plus `FREE` (liberated's name), `FROM` (liberator's name), `FCAPITAL` (the liberated's capital name, `GetCapitalLocation`). `WE_RETURN_EXILE` where the liberator is the player (header "We have liberated", 1 "$FREE$", 2 "$TITLE$, we can report that our liberation of $FREE$ has been a major success. Today a parade of troops has marched through $FCAPITAL$ in a joyous celebration.", log "We liberated $FREE$, and restored their government to $FCAPITAL$."), otherwise `RETURN_EXILE` (header "$foreign_minister$ reports on", 1 "$FREE$ liberated!", 2 "$TITLE$, we can report that $FREE$ has been liberated by $FROM$. Their government has been restored to $FCAPITAL$ and they are no longer in exile.", log "$FREE$ has been liberated, and their government restored to $FCAPITAL$."). The first CMessage country pair is the liberated country. Goto: none, per `FINDINGS-messagegoto.md`. `RETURN_EXILE_US` is declared and raised by nothing (`FINDINGS-messages.md`).
5. `SetGovernmentInExile(liberated, false)` (rva 0x102BC0).
6. `RebuildNeighbours` and `CCountry_AfterDiplomacyChange` on the liberated, then the liberator.

### Puppet versus liberate

| | Puppet row (`CCreateVassalCommand`) | Liberate row (`CLiberateCountryCommand`) |
| --- | --- | --- |
| target | owns nothing | owns land, in exile |
| land | ownership changes via `ReleaseProvinces` | control of its own land handed back; owner unchanged |
| new units, tech, cores | yes, as `ReleaseProvinces` | none |
| puppet link | always | only across factions |
| relation +500, alignment, government | always | only across factions |
| faction join | where the overlord's faction is valid | across factions, where the liberator's is valid |
| exile status | untouched | ended |
| message | `INDEPENDANCE` | `WE_RETURN_EXILE` / `RETURN_EXILE` |

## 6. Script and AI counterparts (only as far as they bear on the commands)

- AI: `tfh/script/country/ITA.lua:417` posts `CCreateVassalCommand(loPuppetTag, ministerTag)` from `HandlePuppets`; `tfh/script/ai_politics_minister.lua:80` posts `CLiberateCountryCommand(loMember, ministerTag)` after `GetPossibleLiberations` and `IsCapitalSafeToLiberate`. The Lua constructors are `LuaConstruct_CLiberateCountryCommand` (rva 0x589DB0) and the unrecorded `0x589E90` for `CCreateVassalCommand`. Same commands, same `Execute`s, so Lua-posted ones go through the same `IsValid`.
- Script: `create_vassal` runs `MakeVassal` (not this command); `release` runs `ReleaseProvinces` directly. `can_create_vassals` and `is_possible_vassal` read `GetPossibleVassals`.

## Not established

- When `overlord->diplomacy[vassal]->alliance` can be non-null at step 9 of the puppet `Execute`: read as written, its reachability from the row (the vassal owns no land) was not traced.
- The window slot 10 with 0 in both dialog constructors (it writes a ushort at the window's `+0x258`), and how the window's position slot 26 relates to `DefaultDialog`'s `orientation = CENTER` once on screen, so the dialog's on-screen spot is known only as "its own position plus (150, 150)".
- Whether `IsValid` is asked on every route the row's posted command takes before `Execute`; `FINDINGS-commands.md` gives the queue's gates, not re-read here.
- What leaving the politics view with a selection window open does to it: `CPoliticsView::Hide` was not read.
- The name of the shared row destructor (`0x6B8040`, a fold of two): left unnamed. `0x589E90` (`CCreateVassalCommand`'s Lua thunk) is read only as far as its `new 0x4C`, not recorded.
- Scrolling or sorting of `select_list` beyond the insertion order: the rows are appended in list order and no sort call was found in the two `Open*` functions; a sort inside the list box's own slots was not read.
