# The in-game menu: the menu, its save dialog and its message settings

*The in-game menu wave, 2026-11-04: three readers, read statically out of `hoi3_tfh.exe` with `scripts/disasm.py`,
`scripts/findRefs.py`, `scripts/vtable.py` and a Ghidra copy. Only valid for this build. Set against the maintainer's
screenshot of the original's menu, which the reading agrees with. For OpenHOI3, which has no saving, loading or main
menu yet.*

**The wave in one paragraph.** **The menu** (`menubar.gui`'s `menu`, section A) opens by Escape with nothing selected,
by the top bar's `topbar_menubutton` or by the custom-game bar's `menupause`, always on its six buttons; it pauses a
single-player game and never a multiplayer one, shuts the side menus, lets the selection go and shuts a country view.
Only Save Game is ever greyed, and only in a custom game. Resign and Quit open one dialog, `CQuitDialog`, keyed "RESIGN"
or "QUIT": Quit goes to the desktop, Resign ends the game into the back-end screen; neither saves. Close, and Close from
any of its windows, go back to the six buttons, and having opened one of them leaves the game paused when the menu shuts
(read, and confirmed by the maintainer in the original). **The message settings window** (section B) lists every message type with four boxes - ticked means off -
each click changing the type at once and only the window's Close writing `messagetypes_custom.txt`; the tabs are radio
buttons none of which is ticked at first; **a click on a type's name does nothing**, its handler attached to no element.
**The save dialog** (section C) lists the `save games` folder's `.hoi3` files newest first, offers the country's name and
the date (`Germany1936_01_01_00`), adds `.hoi3`, asks before overwriting, and goes back to the menu.

**Corrected in the record**: `CInGameIdler::OnMessageSettingsRowClick` is unreachable and the panel never opens
`CMessageSettingWindow`; `CloseMessageSettings` is the save routine, not the close button; `CSavegameItem` is the front
end's load list's row; `ListFilesWithExtension`'s first parameter is a `const char*`; `SaveGameFromDialog` takes
`(idler, path)` - `FINDINGS-autosave.md` said it takes the dialog; and Resign opens `CQuitDialog`, not
`CConfirmVictoryConditionResign`.

| section | reader | fragment |
| --- | --- | --- |
| A, the menu | A | `fragments/merged/ingame-menu.json` |
| B, the message settings window | B | `fragments/merged/message-settings.json` |
| C, the save dialog | C | `fragments/merged/save-dialog.json` |

## A. The menu

*Reader A. Addresses are VAs unless marked rva.*

**Synopsis.** The aim was what makes and opens the in-game menu, whether it pauses the game, what each of its six
buttons does and when one is greyed, and what lies behind Resign, Quit and Close. All of it is settled off the bytes.
**Three things open the menu**: Escape over the map with nothing selected, the top bar's `topbar_menubutton`, and the
custom-game bar's `menupause`. **It pauses a single-player game, never a multiplayer one**, and always opens on its six
buttons. **The one button ever greyed is Save Game, and only in custom game mode.** **Corrected in the brief**: Resign
does not open `CConfirmVictoryConditionResign` - Resign and Quit both open a `CQuitDialog`, keyed "RESIGN" or "QUIT";
`CConfirmVictoryConditionResign` is the victory dialog's Resign - and Resign does not go "to the main menu" as its text
says: it ends the game into the back-end screen (`CBackEndIdler`).

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x26BD10` | `CInGameIdler::ToggleMenu` | new | confirmed | opens the menu (pausing it in single player, panel shown, side menus, selection and a country view shut) or closes it when it is up |
| `0x26BE80` | `CInGameIdler::CloseMenu` | new | confirmed | from a subwindow back to the panel; otherwise unpauses if the menu paused the game, and hides it |
| `0x26BCF0` | `CInGameIdler::OnMenuCloseButton` | new | confirmed | `menu_close_button` (ESCAPE): CloseMenu(0) |
| `0x26CCA0` | `CInGameIdler::OnMenuOptionsButton` | new | confirmed | shows the CIngameSettingsScreen (+0x1D2C) and hides the menu's subwindows |
| `0x26F6E0` | `CInGameIdler::OnMenuMessageSettingsButton` | new | confirmed | hides the subwindows, then CInGameIdler_FillMessageSettings |
| `0x272A10` | `CInGameIdler::OnMenuResignButton` | new | confirmed | CQuitDialog "RESIGN", the player on both shields, AddDialog |
| `0x272840` | `CInGameIdler::OnMenuQuitButton` | new | confirmed | CQuitDialog "QUIT", the same shape |
| `0x2724D0` | `CQuitDialog::CQuitDialog` | new | confirmed | DefaultDialog; title and description key+"_TITLE" and key+"_DESC"; `ret 0xC` |
| `0x272790` | `CQuitDialog::OnAgree` | new | confirmed | slot 5: "RESIGN" gives RequestGameOver (slot 74), anything else RequestQuit (slot 73) |
| `0x2727F0` | `CQuitDialog::ScalarDeletingDestructor` | new | confirmed | slot 0 |
| `0x271320` | `CConfirmVictoryConditionResign::OnAgree` | new | confirmed | slot 5: VC_RESIGN gives RequestGameOver |
| `0x262FD0` | `CInGameIdler::TogglePause` | new | confirmed | slot 27: posts CPauseGame in multiplayer; otherwise toggles +0x12D8 (a tutorial gate in front) |
| `0x24C480` | `CInGameIdler::Unpause` | new | confirmed | slot 71: clears +0x12D8 outside a custom game, nothing in one |
| `0x2439C0` | `CInGameIdler::IsPaused` | new | confirmed | slot 95: `mov al,[ecx+0x12D8]` |
| `0x2CBBB0` | `CTopBar::OnMenuButton` | new | confirmed | `topbar_menubutton`: ToggleMenu(0) |
| `0x24C70` | `CCgmBar::OnMenuPause` | new | confirmed | the custom-game bar's `menupause` ("Menu"): ToggleMenu(1) |
| `0x2559D0` | `CInGameIdler::Update` | revised | confirmed | a sentence added: Save greyed in a custom game; the builder window's unpause through +0x1D3E |
| `0x25A2B0` | `CInGameIdler::Enter` | revised | inferred | a sentence added: where the menu window is made and its six glues attached |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CInGameIdler | `0x1E8` | `menu_close_observer` | `void*` | new |
| CInGameIdler | `0x288` | `menu_save_observer` | `void*` | new |
| CInGameIdler | `0x2D8` | `menu_message_observer` | `void*` | new |
| CInGameIdler | `0x378` | `menu_options_observer` | `void*` | new |
| CInGameIdler | `0x450` | `menu_resign_observer` | `void*` | new |
| CInGameIdler | `0x4A0` | `menu_quit_observer` | `void*` | new |
| CInGameIdler | `0x1CDC` | `menu_window` | `void*` | new |
| CInGameIdler | `0x1D2C` | `settings_screen` | `void*` | new |
| CInGameIdler | `0x1D3E` | `paused_before_window` | `bool` | new |
| CInGameIdler | `0x12D8` | `paused` | `bool` | new |
| CEU3Dialog | `0x8` | `idler` | `void*` | new |
| CQuitDialog | `0x68` | `key` | `Hoi3CString` | new (struct declared: 0x84, inherits CEU3Dialog, vftable 0x11CF114) |
| CConfirmVictoryConditionResign | `0x68` | `idler` | `CInGameIdler*` | new (struct declared: 0x6C, inherits CEU3Dialog, vftable 0x11CF0CC) |

Slots recorded: CInGameIdler 27, 71, 95; CQuitDialog 0 and 5; CConfirmVictoryConditionResign 5. *Also read in passing*:
`CEU3Dialog::Close`'s "slot 5 is inferred the agreeing answer" can be raised to confirmed - the base constructor
attaches glue `+0xC` (`0x6FB9A0` = `jmp [[ecx]+0x14]`, slot 5) to `AgreeButton` at `0x63D61E`, and glue `+0x38`
(`0x998430` -> slot 6) to `DeclineButton` at `0x63D68E`; not revised here, being outside the brief.

### A.1 What makes it and what opens it

**Made** by `CInGameIdler::Enter` at VA `0x65E676`-`0x65EC2C`: the window `menu` (`interface/menubar.gui`) through the
gui's slot 11, with idler `+0x1794` as its parent (not identified), kept at `+0x1CDC` (its only writer, `0x65E6C1`) and
hidden at once; the icon `menu` (`GFX_menu`) found and given its slot 33 with 1 (the setter of byte `+0x44`, the likely
focus byte; what it does for an icon is not established); each of the six buttons found on `menu_panel` and given an
observer glue (`CButtonObserverGlue<CInGameIdler>`, 0x50 bytes), the constructor building each through `0x679650`,
which stores the click handler at glue `+8`:

| button | text | glue | handler |
| --- | --- | --- | --- |
| `menu_save_button` | "Save Game" | `+0x288` | `0x66C090` (section C) |
| `menu_options_button` | "Game Options" | `+0x378` | `0x66CCA0` |
| `menu_resign_button` | "Resign" | `+0x450` | `0x672A10` |
| `menu_message_button` | "Message Settings" | `+0x2D8` | `0x66F6E0` |
| `menu_quit_button` | "Quit" | `+0x4A0` | `0x672840` |
| `menu_close_button` | "Close" (shortcut ESCAPE) | `+0x1E8` | `0x66BCF0` |

**Opened** always through `CInGameIdler::ToggleMenu` (VA `0x66BD10`), nine direct callers:
- **Escape** - key down, not taken by the interface (the event's handled byte `+0x18`, tested at `0x653851`) - in
  `CInGameIdler_HandleInput`: with anything selected the first Escape only lets the selection go; with nothing selected,
  ToggleMenu(0) (`0x653899`). **So with units selected Escape takes two presses.**
- **The top bar's `topbar_menubutton`** (`GFX_menubutton`): `CTopBar::OnMenuButton`, the observer `+0x13C`'s handler,
  ToggleMenu(0) on the top bar's idler (`+0x24`); a second press closes the menu.
- **The custom-game bar's `menupause`** (`tfh/interface/cgm.gui`, "Menu"): `CCgmBar::OnMenuPause`, ToggleMenu(**1**);
  its glue at CCgmBar `+0x4C`, attached at `0x424226`.
- The rest: CloseMenu's reopen and the thunks of `menu_save` and `menu_message_settings` (`0x66BD00`, `0x66C070`,
  `0x670240`). No F10, nothing else: findRefs over `0x66BD10` gives those nine.

### A.2 ToggleMenu, and the pause

With the menu window up (`+0x5B`), ToggleMenu only calls `CloseMenu(arg)`. Otherwise, in order:
1. `+0x1D3E = IsPaused()` (slot 95, `+0x12D8`);
2. **only where the game was not paused and is not multiplayer (`+0x68`): TogglePause** (slot 27) - so the menu pauses
   a single-player game and never a multiplayer one;
3. the window shown (its slot 13);
4. the window's slot 28 (`0xAC2DE0`, a walk of the subwindow map at `+0x414` hiding each), which takes down
   `menu_panel`, `menu_save` and `menu_message_settings`;
5. **`menu_panel` shown** - the menu always opens on its six buttons; that is the reference at `0x66BD91`;
6. with arg 1 (custom game), the window's slot 11 (`0xAC11D0`, not read);
7. always `CInGameIdler_CloseSideMenus`, then ClearSelection (slot 46) - the unit panels go with the selection;
8. with arg 0 only: an open country view toggled shut (AnyCountryViewOpen, then OpenCountryView(`+0xCFC`)),
   `+0x1D3D = 1` (not identified), and `bg_main_menus` (`+0x1914`) hidden.

**The pause**: TogglePause (slot 27, VA `0x662FD0`) in multiplayer posts a `CPauseGame` (0x5C bytes, constructor
`0x6D7F10`); otherwise, unless a tutorial blocks it, Unpause (slot 71) when paused, or `+0x12D8 = 1` when not. Unpause
(`0x64C480`) clears `+0x12D8` (and sets `+0x12D9`) **outside a custom game only**. `+0x12D8` reads as "paused" (likely);
Enter sets it twice, so a game comes up paused. `+0x1D3E` is shared with the builder windows (`0x673470` opens one;
Update's `0x656791` closes it), which pause and unpause the same way.

### A.3 CloseMenu, Close and Escape

`CInGameIdler::CloseMenu` (VA `0x66BE80`) asks first whether any of these is shown: `menu_save`,
`menu_message_settings`, a message-type window the panel opened (`+0x5F0`), the in-game settings screen (`+0x1D2C`, its
slot 3 = its `+4`). **If so**, it hides the menu window, calls the settings screen's slot 2 (hide) and **ToggleMenu
again, which opens the menu on its panel** - Close from a subwindow goes back to the six buttons. **If not**, it unpauses
(slot 27) only where the game is paused, is not multiplayer and `+0x1D3E` is clear (the menu did the pausing), sets
`+0x1D3E`, and hides the menu window and the settings screen.

**A quirk of the bytes**, **confirmed by the maintainer in the original, 2026-11-04**: the reopen in the subwindow arm
reads `+0x1D3E` again while the menu's own pause holds, so it becomes 1 - **once Save Game, Game Options or Message
Settings has been opened, closing the menu leaves the game paused**.

`menu_close_button` is CloseMenu(0). Escape with the menu up fires Close by the button's ESCAPE shortcut; that the
interface marks the key handled, so HandleInput's own Escape branch does not open the menu again, is inferred. Other
callers of CloseMenu: in-game screen slot 93 (after a country view is shut), `0x663340` (a path letting the selection
go), **`CInGameIdler::ShowCombatView` (`0x66513A`) - opening a battle's window closes the menu** - and the in-game
settings screen's slot 5.

### A.4 Save Game, Game Options, Message Settings, and greying

- **Save Game** (`0x66C090`, section C): shows the window, hides its subwindows, fills `games`, shows `menu_save`.
- **Game Options** (`0x66CCA0`): the `CIngameSettingsScreen` at `+0x1D2C` (0x3E0 bytes, constructor `0x6FB710`, window
  `menu_settings_ingame`, made by Enter at `0x66061D`) gets its slot 1 (show), then the menu's slot 28 hides
  `menu_panel` by a tail jump; the menu window with its picture stays up. The settings screen's own close (slot 5,
  `0x6FB8D0`) comes back through CloseMenu.
- **Message Settings** (`0x66F6E0`): shows the window, hides its subwindows, then `CInGameIdler_FillMessageSettings`
  (section B).
- **Greying**: `CInGameIdler::Update` (VA `0x655D1C`-`0x655E19`), every frame the menu is up, disables
  `menu_save_button` (slot 47) where the custom-game settings' first byte is set and enables it (slot 46) otherwise -
  the only greying of any menu button; each of the other five names is referenced once in the image, in Enter. Nothing
  tests multiplayer or a client there. There is no ironman: findBytes finds no "ironman" in any case, the positive
  control the same search finding `menu_panel` at its 8 known references.
- **The oracle**: the reading agrees with the maintainer's screenshot outside a custom game - the picture, five
  `GFX_frontend_button3` buttons at y 220-380 in the file's order, the narrower `GFX_frontend_button4` Close apart at y
  430, none greyed.

### A.5 Resign and Quit

**What opens**: both make a `CQuitDialog` (operator new(0x84); constructor `0x6724D0`), built on the `DefaultDialog`
window of `eu3dialog.gui` through the CEU3Dialog base, the key at `+0x68`, the title key+`_TITLE` and the description
key+`_DESC`. The handler puts the player's country (game state `+0xC30`) on both shields and calls
`CEU3Idler::AddDialog`; the menu stays up behind it, and the game paused.

**The text** (`localisation/frontend.csv`): Quit - `QUIT_TITLE` "Quit Game", `QUIT_DESC` "Are you sure you want to quit
and return to desktop?"; Resign - `RESIGN_TITLE` "Resign Game", `RESIGN_DESC` "Are you sure you want to resign and return
to the main menu?"

**The answers**: Ok (`AgreeButton`, ENTER) is slot 5, `CQuitDialog::OnAgree` - key "RESIGN" calls
`CInGameIdler::RequestGameOver` (slot 74, `+0x1CD9`), after which `ProcessSessionEndRequests` builds a `CBackEndIdler`
as the next screen without resetting the game state (what that screen shows was not read; the text's "main menu" is
reached only through it); anything else calls `CInGameIdler::RequestQuit` (slot 73, `+0x1CD8`), ending in
PostQuitMessage(0) - to the desktop. **Neither saves first**: nothing on either path calls a writer (RequestQuit's
helper `0x677130` not read). Cancel (`DeclineButton`, ESCAPE) is the base's slot 6, `CEU3Dialog::Close`, which only
closes.

**`CConfirmVictoryConditionResign`** is the `VCConfirm` dialog of the campaign's end (constructor `0x670C20`, idler at
`+0x68`): its Resign (VC_RESIGN, slot 5) is the same RequestGameOver; its Continue only closes.

### A.6 Tooltips

**None of the six buttons has one, nor `topbar_menubutton`**: their .gui entries are empty, and each name is referenced
only where it is wired (once in Enter for the menu's, once in CTopBar::Build for the top bar's).
`CInGameIdler::GetElementTooltip` has a literal `menu_button` that would give M_MENU_BUTTON "Menu" (VA `0x6C9191`), but no
element of that name exists in Their Finest Hour's or BlackICE's .gui files (grep), so it never answers.

### A.7 Not established

- What the window's slot 11 (taken in a custom game) and the icon's slot 33 do.
- `+0x1D3D` and `+0x12D9`.
- TogglePause's tutorial test `0x8E7A60` and its multiplayer guard `+0x1CD0`/`+0xF5`.
- The idler `+0x1794` (the menu's parent).
- What `CBackEndIdler` shows.
- Whether the interface marks a shortcut key handled (inferred from HandleInput's test).
- *An inference in section B's area*: `menu_message_settings`'s `close` has no ESCAPE shortcut, so Escape there runs
  ToggleMenu, then CloseMenu, back to the panel **without** CloseMessageSettings - and `messagetypes_custom.txt` would
  not be written.

## B. The message settings window (`menu_message_settings`)

*Reader B. Read 2026-11-04, statically, from a copy of the Ghidra project with the record applied. Addresses are VAs
unless marked rva. This extends `FINDINGS-messageshow.md` section 8; what that settles is not repeated.*

**Synopsis.** The aim was the message settings window whole: how it opens and closes, the seven tabs, the `settings`
rows and their four checkboxes, the `message` button, `reset`, the tooltips, pausing, and where the choices are kept. All
of it is settled. **Corrected rather than added**: **`CInGameIdler::OnMessageSettingsRowClick` (`0x26FE50`) is never
reached** - its only route is a button glue the constructor makes at idler `+0x4F0`, which nothing attaches to any
element - so clicking a type's name in the panel does nothing and the panel never opens `CMessageSettingWindow`, where
the record said it did (two entries, and `FINDINGS-messageshow.md` section 8); **`CloseMessageSettings` (`0x2701B0`) is
not the panel's `close` but the save routine** - the close handler is a new function, `0x270240`, which calls it and
goes back to the menu's six buttons; **the pause icon's tooltip reads the type's `log` flag**, not `pausepopup`; and
**the `messagecat_all` tab has no tooltip** - the code meant for it tests `messagecat_others` a second time.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x26CCC0 | CMessageSettingsItem::CMessageSettingsItem | new | confirmed | builds one row: its window, its type, the checkbox glue on the four icons, ticked where off, tagged `message_setting_item`; attaches nothing to `message` |
| 0x26D160 | CMessageSettingsItem_HasIcon | new | confirmed | whether an element is one of a row's four icon checkboxes (for the tooltip) |
| 0x26D340 | CMessageSettingsItem_IconTooltip | new | confirmed | MESSAGE_IS_LOG / _POPUP / _ONMAP / _PAUSE with $TRUTH$; the pause one reads `log` (+0xD) |
| 0x26DFC0 | MessageSettings_ListCategory | new | confirmed | refills the list with the types of one category (6 = all) |
| 0x26E4D0 | CInGameIdler::OnMessageCategoryTicked | new | confirmed | a tab ticked: the other six unticked (radio buttons), the list refilled for its category |
| 0x26F3F0 | CInGameIdler::OnMessageCategoryUnticked | new | confirmed | a tab unticked: where none is ticked, every type listed (and `all` "unchecked", a no-op) |
| 0x270240 | CInGameIdler::OnMessageSettingsClose | new | confirmed | the panel's `close`: saves the file, then ToggleMenu -> CloseMenu -> the menu reopened on its six buttons |
| 0x2701B0 | CInGameIdler::CloseMessageSettings | revised | confirmed (was inferred) | the save routine, not the close button; its +0x5F0 arm dead |
| 0x26FE50 | CInGameIdler::OnMessageSettingsRowClick | revised | confirmed | body as before; now says it is unreachable (its glue +0x4F0 attached to nothing) |
| 0x26F710 | CInGameIdler_FillMessageSettings | revised | confirmed | adds: runs only while `menu` is open, ignores the tabs, shows the window; callers named |
| 0x26FC70 | ResetMessageTypes | revised | confirmed | adds: the list is not refilled, and the panel's Close then writes the file again with the defaults |
| 0x299CD0 | CMessageSettingWindow::CMessageSettingWindow | revised | confirmed | last sentence only: the panel does not open it |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CMessageSettingsItem (declared: 0x68, vftable 0x11CEDD8) | 0x20 | window | void* | new |
| CMessageSettingsItem | 0x28 | type | CMessageType* | new |
| CMessageSettingsItem | 0x30 | checkbox_observer | void* | new |
| CInGameIdler | 0x4F0 | message_row_click_observer | void* | new |
| CInGameIdler | 0x540 | message_settings_close_observer | void* | new |
| CInGameIdler | 0x590 | message_settings_reset_observer | void* | new |
| CInGameIdler | 0x5F0 | message_setting_window | CMessageSettingWindow* | new |
| CInGameIdler | 0x5F8 | message_setting_window_observer | void* | new |
| CInGameIdler | 0x648 | message_category_ticked_observer | void* | new |
| CInGameIdler | 0x680 | message_category_unticked_observer | void* | new |

### B.1 Opening and closing

**Opening**: `menu_message_button`'s handler is A's `OnMenuMessageSettingsButton` (glue `+0x2D8`): it shows `menu`
(`+0x1CDC`), hides all the menu's child windows (window slot 28) and calls `CInGameIdler_FillMessageSettings`. Fill works
only while `menu` is on screen (`cmp [menu+0x5B], 0` at `0x66F835`): it empties `settings`, adds a row for **every**
registered type in registry order, and shows `menu_message_settings` (`0x66FC19`). The panel is a child of `menu` with
no pause of its own; the menu has paused a single-player game already (section A).

**Closing**: Enter attaches the glue at `+0x540` to the panel's `close` (`0x65EEA8`). Its handler,
`OnMessageSettingsClose` (`0x670240`): `CloseMessageSettings` - which hands any panel-opened type window (`+0x5F0`) to
the dialog list, clears `+0x5F0` and **writes `messagetypes_custom.txt`** (`SaveCustomTypes`, `0x6701B0`-`0x67023A`) -
then `ToggleMenu`, which with the menu up goes to `CloseMenu`; with `menu_message_settings` shown, CloseMenu hides `menu`
and opens it again on `menu_panel`. **So Close leads back to the six buttons, and the game stays paused** (section A).
`CloseMessageSettings` has one other way in, the glue at `+0x5F8` on a type window's `ok_button` and `cancel_button`,
which only the row click attaches - dead (B.4).

### B.2 The seven tabs

Each tab is a checkbox carrying two glues, both attached by Enter (`0x66070C`-`0x660A0D`, `0x660A8C`-`0x660DEC`). A click
that **ticks** a tab calls `OnMessageCategoryTicked` with it (glue `+0x648`, its `+0x20` arm), which unticks the other
six with `CCheckBox_Uncheck` - **radio buttons** - and refills the list through `MessageSettings_ListCategory`, keeping
the types whose `categories` index matches: combat 0, diplomacy 1, units 2, provinces 3, events 4, others 5, all 6
(everything). A click that **unticks** one - on the ticked tab - calls `OnMessageCategoryUnticked` (glue `+0x680`, its
`+0x18` arm): where no tab is ticked any more, every type is listed; it also passes `messagecat_all` to Uncheck, which
does nothing to an unticked box, so "all" is not ticked.

**How a click chooses its arm**: the checkbox's click (`0xA81D10`) ticks a box in state 0 or 2 and notifies observer
slots 4, 2 and 6 (`0xA80F60`, `0xA80F20`, `0xA80F80`), playing the `+0x140` sound; it unticks one in state 1 only while
`+0xD8` is clear, notifying slots 3 and 6 and playing `+0x13C`. The glue's slots 1-6 call its member pointers at `+8`,
`+0x10`, `+0x18` (no argument) and `+0x20`, `+0x28`, `+0x30` (with the box).

**Ticked at first: none.** The only code that changes a tab is the two handlers above, which only untick (every
reference to the seven names); nothing in Enter, the menu's button or Fill ticks one. So the panel first opens with no
tab ticked and every type listed. **Fill ignores the tabs**: after a tab is chosen, closing and opening the panel again
(or OK in a type window while the menu is up) lists every type with the old tab still ticked - list and tab disagree
until a tab is clicked. **The seven `messagecat_text_*`** are never named in the executable and show their file text
(`MESSAGESETTINGS_ALL` "All" ... `MESSAGESETTINGS_OTHER` "Other"); the file names the last `messagecat_text_other`, not
`_others`.

### B.3 The rows

**Which**: every registered type, in the order first registered - `interface/messagetypes.txt`'s, then any type only in
the player's file; `option` and `idle` play no part. Their Finest Hour has 184 types, and the maintainer's
`messagetypes_custom.txt` holds all 184. **`text`** is `<TYPE>_SETUP` rendered - ATTACKUS_SETUP "When one of our land
units is attacked by the enemy". **`message`** carries `*`, which renders empty: only the row's background sprite.

| icon | type field | what it does in play |
| --- | --- | --- |
| `messageicon_pause` | `pausepopup` (+0x10) | a popup, and a pause in single player |
| `messageicon_log` | `log` (+0xD) | a log line |
| `messageicon_dialog` | `popup` (+0xE) | a popup |
| `messageicon_map` | `onmap` (+0xC) | the map text |

**Ticked means off**: a box is ticked where its setting is off, its sprite's second frame (red) showing, the first
(green) where it is on; the .dds files have two frames, green then red. **A click**, tick or untick, runs
`CMessageSettingsItem::OnCheckbox`, which writes all four boxes back into the shared `CMessageType` - at once, for every
later message of that type, on this machine only; no command is posted. **It reaches the disk only when the panel's Close
is pressed.** A pause box on with the dialog box off still pops up, `pausepopup` implying a popup (messageshow, section
1).

### B.4 A type's own window from the panel: dead

`OnMessageSettingsRowClick` would open a `CMessageSettingWindow` for the row's type, keep it at `+0x5F0`, attach the
`+0x5F8` glue to its OK and Cancel, and place it at the row. Its only reference is the constructor's
`CButtonObserverGlue<CInGameIdler>` at `+0x4F0` (slot 1). **Nothing attaches it**: a sweep of all of `.text` (3,084,578
instructions) for any operand holding 0x4F0 finds only the constructor (`0x6477DF`), the destructor (`0x649C78`), two
exception-unwind stubs (`0xC5745A`, `0xC90B3A`) and unrelated displacements on other objects - **positive control**: the
same sweep finds the `+0x540` attach (`0x65EEA8`); the row constructor attaches nothing to `message`; the string
`message` is looked up only by the row click itself and at four unrelated sites. So **clicking a type's name does
nothing**; a type's window opens only from a right click on its popup or its log row, `+0x5F0` is always null, and
CloseMenu's test of it is dead too. **A ten-second click in the original confirms or refutes it.**

### B.5 Reset

`reset` (glue `+0x590`, attached by Enter) runs `ResetMessageTypes`: the player's file deleted, then
`interface/messagetypes.txt` read again over the registry, and nothing else. Three consequences, all the bytes': **the
list is not refilled**, so the rows show the old settings until a tab is clicked or the panel opened again; **a click on
any box of a stale row writes all four of its stale values back** into its type; and **the panel's Close writes
`messagetypes_custom.txt` again**, whole, with the defaults - so the file is back at once, and a mod's later changes to
existing types are hidden again (the oddity in messageshow, section 8). *Inferred*: the reload overwrites types in place,
so the rows' pointers stay valid (messageshow, section 1).

### B.6 Tooltips

**The tabs** are answered by name in `CInGameIdler_NamedElementTooltip`: MESSAGECAT_COMBAT "Combat Messages",
_DIPLOMACY "Diplomatic Messages", _UNITS "Unit Messages", _PROVS "Province Messages", _EVENTS "Event Messages", _OTHERS
"Other Messages". **`messagecat_all` gets nothing**: the code meant for it compares `messagecat_others` again (VA
`0x6C49F7`, string `0x15CDECC`), so "All Messages" never shows. The message log's six category boxes have the same names
and so the same tooltips. **The row icons** are answered in `CInGameIdler::GetElementTooltip`: it looks for elements
tagged `message_setting_item` (`0x6C5A3E`), walks the rows with `CMessageSettingsItem_HasIcon` and builds the text with
`CMessageSettingsItem_IconTooltip` - MESSAGE_IS_LOG / _POPUP / _ONMAP / _PAUSE, "This message type $TRUTH$ currently
displayed ...", $TRUTH$ "is" or "is not". **The pause tooltip tests `log`** (`cmp byte ptr [edx+0xd]` at `0x66D749`), so
it says what the log icon says. *Inferred*: that the window's slot 30 tag reaches the icons. `message`, `text`, `reset`
and `close` have none: the file gives none, and no tooltip code names them (GetElementTooltip has an arm for
`closebutton`, not `close`).

### B.7 Where the choices are kept

**In memory**: the shared `CMessageType` flags, changed at once. **On disk**: `messagetypes_custom.txt` in the PhysFS
write folder - the played mod's user folder, `Documents\Paradox Interactive\Hearts of Iron III\` for the base game, or
`<mod>\` - one block per type, `NAME=` then `{ log= onmap= popup= idle= option= pausepopup= categories="cat_..." }`.
**Written** by the panel's Close, by OK in a type window, and (the dead route) by the panel window's OK or Cancel; **not**
by a checkbox click or by Reset. **Read** at every start, over `messagetypes.txt` (`FINDINGS-startup.md`). Left any other
way than its Close, the changes live in memory until something else writes the file; no other way out was found -
whether Escape is one is section A's.

### B.8 Not established

- What a checkbox's `+0xD8` means, and so whether clicking the ticked tab can untick it at all.
- What window slots 28 and 30 do exactly (inferred: hide children; tag elements).
- The element at idler `+0x1794` (the rows' parent).
- `0x699590` (the copy of the type list both fillers walk) and `0x6999E0`.

## C. The save dialog (`menu_save`)

*Reader C. Addresses are rvas unless marked VA. **[exe]** is hardcoded in `hoi3_tfh.exe`, **[mod: ...]** a file may
change it.*

**Synopsis.** The aim was the in-game save dialog from the press of `menu_save_button` to the call into the save writer:
how it opens and closes, what `games` holds and in what order, what a row shows and what a click on it does, how the
offered name is built, and what `save`, `cancel` and the overwrite question do. All of it is settled. **Corrected rather
than added**: **`CSavegameItem` is not this dialog's row** but the front end's load list's (`savegameentry` in the
lobby's `save_games_list`) - the in-game rows are plain `CStandardlistboxItem`s; **`ListFilesWithExtension`'s first
parameter is a `const char*`**, not a `Hoi3CString*`, and its argument order is read off the body, no longer inferred;
and **`FINDINGS-autosave.md` was wrong about `SaveGameFromDialog`** - it "takes the save dialog rather than a name, so it
is not a usable 'save as this name' entry point", where it takes `(idler, path)` and a caller can name the file. The
catch, for BiceLib: on the way out it always calls `ToggleMenu`, so called with the menu shut it opens the menu (and
pauses a single-player game).

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x271370 | SaveGameFromDialog | revised | confirmed | signature added (`__stdcall (idler, path)`, `ret 8`) and the whole body read, to the writer call, the catch funclet and the return to the menu panel |
| 0x26C090 | CInGameIdler::OpenSaveDialog | new | confirmed | `menu_save_button`'s handler (glue +0x288): shows `menu`, hides its sub-windows, fills `games` newest first, offers country + date, shows `menu_save` |
| 0x2715E0 | CInGameIdler::OnSaveDialogSave | new | confirmed | `save`: an empty name does nothing; `.hoi3` added unless there; the path; an existing file -> `CConfirmSave`, else `SaveGameFromDialog` |
| 0x270260 | CInGameIdler::OnSaveDialogRowClick | new | confirmed | a row's `game` checkbox puts its name (without `.hoi3`) into `game_name` and clears the other rows |
| 0x26BD00 | CInGameIdler::OnSaveDialogCancel | new | confirmed | `cancel` = `ToggleMenu(0)`, which brings back the six-button panel |
| 0x2705B0 | CConfirmSave::CConfirmSave | new | confirmed | `DefaultConfirm` window with CONFIRMSAVETITLE / CONFIRMSAVETEXT (NAME), centred |
| 0x270A00 | CConfirmSave::OnConfirm | new | confirmed | slot 5: the folder built again and the file saved over |
| 0x270BD0 | CConfirmSave::ScalarDeletingDestructor | new | confirmed | slot 0 |
| 0x23AA10 | ListFilesWithExtensionSorted | new | confirmed | wraps `ListFilesWithExtension`, may sort newest first; 4 callers |
| 0x23A840 | SaveFileIsNewer | new | confirmed | the sort's predicate: `PHYSFS_getLastModTime` of `dir/a` against `dir/b` |
| 0x23B0D0 | SortFilesNewestFirst | new | inferred | a `std::sort` instantiation by shape; its loop at 0x23B160 not read |
| 0x4C830 | FormatDateFileStamp | new | confirmed | `%d_%02d_%02d_%02d` (year, month, day, hour) from the tick; the autosave writer's too |
| 0x6C2DE0 | CFixedWindow::HideSubWindows | new | confirmed | primary slot 28: hides every sub-window of a window |
| 0x66BCB0 | ListFilesWithExtension | revised | confirmed (was likely) | the directory a `const char*`; body read: the extension's tail matched case and all, **names with any byte >= 0x80 left out** (and logged), directories left out |
| 0x784A40 | PHYSFS_getLastModTime | new | confirmed | named by the exe's export table |
| 0x66B200 | GetDocumentsGameFolder | new | confirmed | `My Documents\Paradox Interactive\<game>`, made if missing |
| 0x66B2B0 | GetDefaultUserDir | new | confirmed | the above with "Hearts of Iron III"; the startup makes it PhysFS's write directory |
| 0x66C1B0 | VirtualFile_Open | new | inferred | the game's PhysFS file: `+0x13 = (text == 0)`, CSaveWriter's binary byte; openWrite or openAppend; throws on failure; the read branch not read |
| 0x66D3E0 | VirtualFile_SetWriteBuffer | new | confirmed | `PHYSFS_setBuffer` of 1 MiB |

Slots: `CConfirmSave` 0 and 5; `CEU3DialogGui` 28 = `CFixedWindow::HideSubWindows`. Struct declared: `CConfirmSave`
(0x88, inherits CEU3Dialog, vftable_rva 0x11CF084).

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CConfirmSave | 0x68 | file_name | Hoi3CString | new |
| CConfirmSave | 0x84 | host | CInGameIdler* | new |
| CInGameIdler | 0x198 | save_cancel_observer | void* | new |
| CInGameIdler | 0x328 | save_button_observer | void* | new |
| CInGameIdler | 0x418 | save_row_observer | void* | new |

### C.1 Opening, closing, and the pause

**Opening**: `menu_save_button`'s glue at `CInGameIdler +0x288` calls `CInGameIdler::OpenSaveDialog` (`0x26C090`) at
every press: it shows `menu`, hides every sub-window of it (`CFixedWindow::HideSubWindows`, slot 28) - so the six-button
panel goes and only `menu_save` is left - makes the list and the offered name again from nothing, and shows `menu_save`.
**The dialog pauses nothing of its own**: the pause is the menu's (section A). **Closing**: `cancel` and a finished save
both go back to the six-button panel, neither shutting the menu - `cancel` runs `ToggleMenu(0)` (C.7), and every save ends
in `ToggleMenu(idler, 0)`, which with `menu_save` up goes through `CloseMenu` and opens the menu on `menu_panel` again
(section A's note on `+0x1D3E` applies).

### C.2 What `games` lists

**The folder [exe]**: `save games/`, relative to PhysFS's write directory. At startup `GetDefaultUserDir` /
`GetDocumentsGameFolder` build `My Documents\Paradox Interactive\Hearts of Iron III` (`SHGetFolderPathW(CSIDL_PERSONAL)`,
the folder made if missing; `userdir=` on the command line or `userdir.txt` may override it - `0x66ADB0`, which reads
`userdir.txt`, not read), mounted at the front of the search path (VA `0xA56EDA`) and made the write directory
(`PHYSFS_setWriteDir`, VA `0xA56EE0`). So the folder is `Documents\Paradox Interactive\Hearts of Iron III\save games`,
where the maintainer's saves are. With a mod a second directory is mounted and made the write directory (VA
`0xA572FD`/`0xA57303`); BlackICE's saves are under `...\Hearts of Iron III\BlackICE GitHub\save games`, so that is
*inferred* to be the mod's own user folder.

**The `mod/<X>/save games/` branch**: where the string the settings object holds at `+0xA4` is not empty (copied by
`0xC600`; called the mod name elsewhere in the record), the folder is `mod/<X>/save games/`. Nothing that writes `+0xA4`
was found - the next 14 instructions after all 3,129 `GetGameSettings` calls and all 359 direct references to the
singleton were searched, the same scan finding the `0x40C600` readers - and neither user folder has a `mod` subfolder, so
on this machine the branch has not been taken. *Inferred*: were it taken, writing would fail, PhysFS's openWrite making
no folders.

**Which files**: `ListFilesWithExtensionSorted("save games/", "hoi3", newestFirst=true)`, through
`PHYSFS_enumerateFiles` over the whole search path - the user folder and, by PhysFS's semantics (*inferred*), the
install's base and `tfh` folders too. Kept: names ending in `hoi3`, byte for byte, case and all, no dot needed [exe].
Left out: directories, and **any name with a byte >= 0x80**, logged as `Invalid filename found:` (a `js` on each byte at
VA `0xA6BEA9`). The three rotating autosaves (`autosave.hoi3`, `oldautosave.hoi3`, `olderautosave.hoi3`) are ordinary
`.hoi3` files there, so they are listed. **Order**: newest first by `PHYSFS_getLastModTime`, whole seconds [exe];
`std::sort` is not stable, so equal times - or two files that cannot be dated, at -1 - come out in no fixed order.

**A row**: a bare 0x28-byte `CStandardlistboxItem`, its window `save_game_entry` [mod: menubar.gui] at `+0x20`, its
checkbox `game` (`GFX_save_list_button`) carrying **the file name cut at its first `.hoi3`** - `autosave.hoi3` shows
`autosave`, `a.hoi3.hoi3` shows `a`. **`CSavegameItem` (RTTI) is not used here**: its only constructor, VA `0x703BF0`,
builds the front end's `savegameentry` rows in the lobby's `save_games_list` (VA `0x715100`); the only other user of the
`save_game_entry` window is `CGotoProvinceItem` (VA `0x68FA30`), a goto-province list.

### C.3 The name `game_name` offers

**The country's name and a date stamp**, `Germany1936_01_01_00`:
- **the country**: `CountryNameOfTag(GetPlayer())`, the player's country's localised name [mod: localisation], **only its
  first space** made `_` - "United Kingdom" gives `United_Kingdom`, a name of two spaces keeps the second;
- **the date [exe]**: `FormatDateFileStamp(game state +0xBDC)`, `%d_%02d_%02d_%02d` - year, month, day, hour: days =
  (tick - 43800000) / 24, the hour the remainder; year = (int)(days / 365.0); the day of the year days less
  (int)(float)(year x 365); month and day by walking the month lengths, both from 1. The autosave writer's
  `debug_saves` branch uses the same function;
- **multiplayer [exe]**: where `CInGameIdler +0x68` is set, `mp_` in front.

After writing it the box is given ~~an unread edit-box routine (`0x690140`) and its word `+0x40` set to 1 (*inferred*: the
caret and the keyboard's focus)~~ **corrected 2026-11-05 by `FINDINGS-editbox.md`**: `0x690140` is
`EditBox_RefreshText`, which hands the box's display the line the caret is on, and the word `+0x40` = 1 is `clicked`,
the request for the keyboard the gui's input pass grants at the end of the frame - the store is how the dialog gives
`game_name` the focus. **`filename_label`** shows its file text MENU_BAR_SAVE_GAME_FILENAME ("Saved game
filename:") [mod: menubar.gui, localisation]; the exe holds neither the element's name nor the key, so no code touches
it.

### C.4 A click on a row

`OnSaveDialogRowClick` (`0x270260`), the `CCheckBoxObserverGlue<CInGameIdler>` at `+0x418`'s handler, given the clicked
checkbox: it walks the rows; the clicked row's text becomes `game_name`'s; every other row's checkbox has `+0x60` and
`+0x100` cleared where its byte `+0xD8` is 0 or its byte `+0x136` not (*inferred*: unticked, so one row at a time shows
chosen; the two bytes not read). Nothing is saved or loaded by the click; `save` then adds `.hoi3` back, finds the file
and asks the overwrite question.

### C.5 `save` (MENU_BAR_SAVE "Save")

`OnSaveDialogSave` (`0x2715E0`), the glue at `+0x328`'s handler:
1. **the name** is `game_name`'s text; `TrimWhitespace` is run on it **and its answer thrown away** - the length tested
   is the untrimmed one's - so only an **empty** box does nothing, and a name of blanks is saved as such;
2. **the extension [exe]**: where the last `.` stands after the first character and all from it is exactly `.hoi3`, the
   name is kept; otherwise `.hoi3` is added - `my.save` gives `my.save.hoi3`, `x.HOI3` gives `x.HOI3.hoi3`, `.hoi3` gives
   `.hoi3.hoi3`. **No character is refused or replaced** (*inferred*: `:` or `\` would have PhysFS refuse the path, the
   failure of C.6);
3. **the path**: `save games/` + name, or `mod/<X>/save games/` + name (C.2);
4. **an existing file** - `FileExists` (`PHYSFS_exists`) over the whole search path, not the write directory alone: a
   `CConfirmSave` (0x88 bytes) made and handed to the idler's dialog list, the window `DefaultConfirm`
   [mod: eu3dialog.gui] centred, the title CONFIRMSAVETITLE "Save Game", the text CONFIRMSAVETEXT "Are you sure you wish
   to overwrite the file $NAME$?", NAME with its `.hoi3` [mod: misc.csv]. OK (ENTER) is `CConfirmSave::OnConfirm`: the
   folder built again and `SaveGameFromDialog`, with no second test. CANCEL (ESCAPE) is `CEU3Dialog::Close`, shutting
   only the question; the dialog stays up behind it throughout. *Inferred*: a same-named file in the install's own
   `save games` folder would raise the question too, though the write goes to the user folder;
5. otherwise `SaveGameFromDialog(idler, path)` at once.

Nothing tests multiplayer, and nothing ever greys `save`: the image holds two references to the string `save`, Enter's
binding and a console function.

### C.6 Writing the file, up to the writer (`SaveGameFromDialog`, `0x271370`)

1. the inert suspend bracket: slot 4 of `[[idler+0x1790]+0xE4]`, the shared `ret 4`;
2. `VirtualFile_Open(path, write)` with ECX = 1 - `PHYSFS_openWrite` under the write directory: **an existing file is
   truncated, and the save is text** (file `+0x13` = 0);
3. a 1 MiB PhysFS buffer, then a `CSaveWriter` on the stack (depth -1);
4. **the game state's slot 1, `CPersistent::Save(writer)` - the save writer.** The reading stops here;
5. the file deleted through its slot 0, which closes it;
6. **on failure**: `VirtualFile_Open` throws "Could not open file: ..., error: <PhysFS>"; the catch logs `Failed to write
   save file File exception: <what>` (eu3idler.cpp line 9261, channel 0x10004) and hides `menu`;
7. in every case it ends with `ToggleMenu(0)`, the menu panel shown again.

**No message is shown and success is not told.** *Inferred*: a write failing part-way, after an overwrite was agreed,
has already truncated the old save.

### C.7 `cancel` (MENU_BAR_CLOSE "Close", shortcut ESCAPE) and Escape

`OnSaveDialogCancel` (`0x26BD00`) is `ToggleMenu(0)`: with the dialog up it goes through `CloseMenu` and back to the menu
panel - **Close returns to the menu, not to the map**. The selection key handler's own Escape also calls
`ToggleMenu(0)` with nothing selected; whether both fire, or which takes the key, is **not established** - both firing
would shut the menu outright.

### C.8 Tooltips, greying, multiplayer

**No tooltips**: every tooltip field of the `.gui` is empty, and `menu_save`, `games`, `game_name`, `save_game_entry` and
`game` are referenced only by the functions above, `CloseMenu` and `Enter` (the same search finding Enter's bindings, the
positive control). **Nothing greys `save` or `cancel`.** **Multiplayer**: only the `mp_` prefix (*inferred*: a client
saves locally).

### C.9 What looks wrong and is the original's - do not tidy

1. The trim is worked out and thrown away, so a name of blanks saves.
2. Only the first space of the country's name becomes `_`.
3. A row cuts the name at its *first* `.hoi3`; `save` tests the *last* dot.
4. The extension test minds case: `.HOI3` gets `.hoi3` added.
5. Files with names of bytes above 127 are never listed - and a non-English country name can make just such a default
   name (*inferred*; how PhysFS writes Windows-1252 bytes was not read).
6. Existence is asked over the whole search path; the write goes to the write directory alone.
7. Close and Save both go back to the panel, not to the map.

### C.10 Not established

- What writes settings `+0xA4`; ~~`0x690140` and the edit box's `+0x40`~~ (read, `FINDINGS-editbox.md`); the row
  checkbox's bytes `+0xD8` and `+0x136`.
- Which of `cancel` and the key handler takes Escape.
- `userdir.txt`'s reader (`0x66ADB0`); how a name of high bytes or of illegal characters fares in `PHYSFS_openWrite`;
  `VirtualFile_Open`'s read branch; the sort loop at `0x23B160`.
