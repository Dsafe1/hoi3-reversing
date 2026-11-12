# Music

*Read statically on 2026-11-11, for OpenHOI3's question of how the original plays its soundtrack. Fragment
`music-player.json`. Addresses are VAs unless a line says rva. Positive control for the call-site census: the method finds
every site already recorded - the title theme in `CFrontEnd::Update`, the end-of-game tracks in `CBackEndIdler::Enter`, the
volume in `CEU3Application::Run` - so its silence about pause, events or war means something.*

**The census.** The music object `g_Music` (VA 0x1B16808) is reached through `GetMusic` (0xAB8CD0, 28 direct calls) or
that getter's body inlined in `CEU3Application`'s constructor, `LoadEverything`, the tail of `CFrontEnd::Update` and
`CEU3Application::Run`. Every music call site is in one of: startup, the front end's frame and render, the in-game frame
(`CInGameIdler_UpdateMusic`), the in-game render, `CInGameIdler::OnResetDevice`, `nextsong`, `ProcessSessionEndRequests`,
the end-of-game screen, the front end's exit button and `Run`. **Nothing else starts, stops or changes music** - not
pausing, not war or peace, not an event, not a message type. No script keyword names a song beyond `music/*.txt`. The only
music file names in the executable are three hardcoded tracks (*confirmed*, string census of `.rdata` and `.data`).

## 1. In game: when a song changes

`CInGameIdler_UpdateMusic` (rva `0x254000`, idler in EDI) runs once a frame; its only caller is `CInGameIdler::Update`
(rva `0x256764`), after `CInGameIdler_Render`. *Confirmed*, read whole:

1. **Entering a game stops what plays.** `CInGameIdler::Enter` sets `g_LastSongIndex` to -1 (rva `0x25A2F7`) on every
   entry, new games and loads alike. The first frame that sees -1 calls Stop (slot 4) and sets the index to -2. That is
   where the title theme ends.
2. It returns unless the **master** volume (settings `+0x80`) is above 0.0 and the Direct3D device is usable
   (`CGraphics +0x6BCA0`).
3. It returns while the music object is playing (slot 14) **and** slot 11 reports no end: **a new song is chosen only
   when nothing is playing or the current track has just finished.**
4. It picks a song (section 2) and, where the path is longer than 2 characters, plays it (slot 2) and starts it (slot 3,
   again only with the device usable), logs `new song <path>` (`eu3idler.cpp`) and sets the index to 0. If no song
   qualifies nothing plays, and the test repeats next frame.

So **no timer, no event trigger, no deliberate silence between songs, no fade and no crossfade.** Music keeps playing
while the game is paused. With the master volume at 0 no new song is chosen; with it above 0 and the music volume at 0,
songs keep being chosen and played inaudibly.

## 2. How a song is chosen

### 2.1 The files

`LoadSongs` (rva `0x5CB60`) runs once per `music/*.txt`. *Confirmed*: each top-level `song` builds a 0x40-byte `CSong`
appended in file order; any other top-level key is skipped silently. `CSong::LoadKey` knows `name` (`+8`) and `chance`.
**`chance` is a CMeanTimeToHappen built in place at `+0x24` with its days at 1** - the grammar `days`/`months`/`years`/a
top-level `factor` (any of which sets the base by atoi) and `modifier = { factor = F <conditions> }`. Each file ends by
logging `Loaded N songs.`, N cumulative. The install has `songs.txt` (43), `sovietsuite.txt` (4) and
`the_allies_of_the_west.txt` (4); that the files load in alphabetical order is *inferred* (ListFilesWithExtension over
the virtual file system).

### 2.2 The pick: `SongDataBase_PickSong` (rva `0x5CE90`)

*Confirmed*, read whole. The scope is a fresh `CEventScope` whose country is **the played country**; the seed is 0. For
each song in database order:

1. **skipped if it is on the recent list**;
2. `roll = draw % 5 + 5` - 5 to 9 (the draw is never negative);
3. `chance = CMeanTimeToHappen::GetDays(song.chance, scope)`: `days * 1000`, then `* factor / 1000` for each modifier
   whose conditions hold, in file order - with no keys 1000;
4. `weight = roll * 1000 * chance / 1000`, a 64-bit product, integer division;
5. **kept if its weight is strictly greater than the best so far**, the best starting at 0.

So a weight of 0 never wins (`factor = 0` is "never"); equal weights go to the **earlier-loaded** song, and with every
factor at 1 the weights take only five values, so ties are frequent; **a factor of 2 or more beats every factor-1 song
whatever the rolls** (10 at least against 9 at most) - factors are tiers more than odds. A Soviet player's
`sovietsuite_part1..4`, factor 3 for `SOV` (15 to 27), are chosen before any factor-1 or factor-2 song, in an order the
rolls decide.

**The roll's generator** is an MT19937 (the engine's own twist and tempering, `MT19937Twist`, the `MT19937Next` masks)
whose 624-word state is **a local on this function's stack that nothing initialises**: the index is 0 on entry, so the
first draw twists whatever was on the stack. *Confirmed* that no write precedes the twist; *inferred* that the rolls vary
unpredictably. It is not the game's synced generator and it is not seeded.

### 2.3 The recent list

After the loop, **whether or not a song was found**: where the list holds more than 5 entries the oldest is removed; then
the chosen song is appended. **The six songs chosen last can never be chosen next.** A pass that finds nothing frees a
place only when the list holds six, so **if five or fewer songs can win, the music stops for good** once each has played,
until another becomes possible. The list belongs to the database, not the game, so **it carries over from one game to
the next** in a session. *Confirmed.*

### 2.4 The path

`music/` + `name` (`CSong_GetPath`, rva `0x5CA30`), opened through the virtual file system, so a mod's `music/` overrides
the install's (*inferred*: through `VirtualFile_Open`, not read in detail).

### 2.5 The fallback with no song defined

`CInGameIdler::CInGameIdler` lists `music/*.mp3` into `+0x5E0`, leaving out `music/diesiraeintro.mp3`,
`music/titletheme_heartsofiron.mp3` and `music/victorymarchverdi.mp3` (exact comparison). **Used only when the song
database is empty.** Its index is `(int)(seconds on the idler's clock since Enter) % count`, redrawn while it equals the
last - a busy wait until the second turns over, and **a hang if the list holds exactly one file** that has played. Each
song from it is also started with slot 3. *Confirmed.*

## 3. `nextsong`

`CInGameIdler::NextSong` (slot 33, rva `0x278730`) builds the same scope, makes the database if needed, runs
`SongDataBase_PickSong`, and where a path came back plays and starts it at once, cutting off the current track; the
index to 0. It asks **neither the master volume nor whether anything plays**; the song goes on the recent list like any
other. With nothing qualifying it answers an empty string - "Now playing " and nothing - and the track plays on.
*Confirmed.*

## 4. Main menu, lobby and loading: the title theme

- **At startup** `CEU3Application::LoadEverything` installs the DirectShow music object - or a CNullMusic with "Sound
  disabled (mastervolume is set to a negative value in settings.txt)" - sends the volume once and, with the master volume
  above 0, plays and starts `music/titletheme_heartsofiron.mp3`. This is before graphics, the GUI and the databases, so
  **the title theme plays through the startup load.** *Confirmed.*
- **`CFrontEnd::Update`, at each frame's start**: with the device usable, the master volume above 0 and slot 11 saying the
  track has just ended, it plays and starts the title theme again ("start song", "end song play"). *Confirmed.*
- **After `CFrontEnd_Render`, a second check**: where slot 14 says nothing plays, or slot 11 reports an end, with the
  device usable, it calls Start (slot 3) - which does nothing to an ended track, `PollEnded` leaving the state at playing.
  **Slot 11 consumes the end event, so whichever check sees it first decides whether the theme comes round again**; the
  end arrives on DirectShow's own thread, and the frame's drawing sits between the tail check and the next frame's early
  one. *Inferred, untested*: the tail usually sees it, and the theme plays once and the menu falls silent. **Worth checking
  by ear.**
- **The lobby** is a view of the same `CFrontEnd`; the theme carries on into it. *Confirmed by structure.*
- **Loading a game**: `CFrontEnd::LaunchGame` runs inside the front end's frame and DirectShow plays on its own threads,
  so the theme carries on through loading (*inferred*) until the first in-game frame stops it (section 1, *confirmed*).

## 5. Leaving a game

`ProcessSessionEndRequests` calls Stop (slot 4) on all three exits - game over and resign, exit to menu (the tutorial
ending), quit; this confirms the "a stop, *inferred*" of `FINDINGS-endgame.md`. The front end's exit button stops it too;
Stop seeks back to 0.

- **The end-of-game screen** plays `music/victorymarchverdi.mp3` where the winner is the player's faction, else
  `music/diesiraeintro.mp3`, with the master volume (+0x80) above 0 - slot 2 alone, so the track is heard while the state
  says stopped, and plays once.
- **Exit from it to the main menu**: the front end's tail check sees "not playing" and calls Start; the end-game track
  carries on, and when it ends the race of section 4 decides. *Inferred chain, each link read.*
- **Exit to menu after the tutorial**: the stopped graph is at position 0, so the front end's Start **replays the last
  in-game song from its start** at the main menu. *Inferred chain, each link read.*

## 6. Losing the Direct3D device

`CGraphics +0x6BCA0` (`device_ready`) is cleared when `Present` answers D3DERR_DEVICELOST and set when
`TestCooperativeLevel` succeeds - in practice a fullscreen game minimised or alt-tabbed (*inferred*; a window merely behind
others reads 1 live). On the frame it is found lost, `CFrontEnd_Render` and `CInGameIdler_Render` pause the music (slot 5)
and mute the sound (the in-game one sets two more idler bytes, not read); when it comes back the front end calls Start,
and in game `CInGameIdler::OnResetDevice` (CLostDeviceInterface slot 1) does the same with the sound. While it is lost no
song is chosen. *Confirmed.*

## 7. The music object

`DXMusic_Construct` creates CLSID_FilterGraph and queries IGraphBuilder, IMediaControl, IMediaSeeking, IMediaEventEx and
IBasicAudio (*confirmed* by decoding the GUIDs). All state is in globals; the table at VA 0x1601A28 has no RTTI and 15
slots:

| slot | what it does |
| --- | --- |
| 2 Play | AddSourceFilter, FindPin `Output`, Stop, the graph rebuilt without the old source, Render, seek to 0, Run; the state is not changed. A file that fails early is skipped and the current track plays on (*inferred*) |
| 3 Start | only from stopped (0) or paused (2): Run, the saved volume put back, state 1 |
| 4 Stop | from 1 or 2: Stop, seek to 0, state 0 |
| 5 TogglePause | 1 → Pause, state 2; 0 or 2 → Run, state 1 |
| 7 SetVolume(v) | put_Volume((int)(sqrt(sqrt(v)) * 10000 - 10000)), hundredths of a decibel |
| 11 PollEnded | drains events; on EC_COMPLETE Stop and answers 1, leaving the state at 1 |
| 14 IsPlaying | state == 1 |
| 12, 13 | a playlist; no caller found, *inferred* dead |

**No track loops on its own**: EC_COMPLETE stops the graph, and looping exists only in the front end's replay of the title
theme. **Volume**: `CEU3Application::Run` sends `v = master/100 * music/100` each frame it changes; the curve gives 1.0 = 0
dB, 0.5 ≈ −15.9 dB, 0.25 ≈ −29.3 dB, 0.1 ≈ −43.8 dB, 0 = −100 dB.

## 8. What looks wrong and is what the bytes do

- The pick is argmax(chance × 5..9), not a weighted draw; ties go to load order, and a factor of 2 beats every factor-1 song.
- The roll comes from an uninitialised stack generator.
- Five or fewer possible songs means silence once each has played; the recent list outlives a game.
- The fallback list can hang the game with one file.
- In-game gating and the end-of-game screen ask the master volume, not `music_volume`.
- `nextsong` ignores the volume and cuts the current track.
- Whether the title theme loops at all is a race between two checks in one frame.

## 9. Not established

- Whether the title theme loops at the main menu (section 4) - by ear, or a live breakpoint on `DXMusic_PollEnded`.
- Whether the stale-stack rolls vary much in practice.
- `VirtualFile`'s handling in Play, the early exit with it.
- The two other bytes the in-game render sets on a device loss; `CMusic` slot 1 (VA 0xAB8D60, shared with CNullMusic); the
  song database's +0x1C byte.

## Corrections

- `LoadSongs`: the CMeanTimeToHappen is the song's `chance`, not a false friend.
- `CFrontEnd::Update`: the title theme replays when the track has ended, not when "nothing plays".
- `CBackEndIdler::Enter` and `FINDINGS-endgame.md` A.3: settings `+0x80` is the master volume, not music (`+0x88`).
- `CFrontEnd_Render`: pause and resume follow device loss, not window focus.
- `FINDINGS-endgame.md` A.3: the session end's "slot 4 (a stop, *inferred*)" is confirmed.

## Mechanics, without addresses

Each marked hardcoded in the executable or mod-able, and by which file.

- A song changes only when the current track ends or nothing plays: no timer, trigger, fade, crossfade or gap. Hardcoded.
- Entering any game, new or loaded, stops the current track and a song is picked at once. Hardcoded.
- Songs are picked only while the master volume is above 0; the music volume does not gate picking. Hardcoded (the
  volumes are `settings.txt`'s `master_volume` and `music_volume`).
- Music plays on while the game is paused; a lost display device pauses it and no song is picked until it is back. Hardcoded.
- `nextsong` uses the same pick, plays at once cutting the track, and ignores the volume. Hardcoded.
- Songs are every `song = { name = ... chance = { ... } }` of any `music/*.txt`; other top-level keys are ignored.
  Mod-able (`music/*.txt`).
- The path is `music/` + `name`, through the layering. Rule hardcoded, files mod-able.
- `chance` is mean-time-to-happen grammar: base 1 unless `days`/`months`/`years`/a top-level `factor` sets it, each
  `modifier` whose conditions hold multiplying by its `factor` (thousandths); the played country is the scope. Grammar and
  scope hardcoded, values mod-able (`music/*.txt`).
- Weight = chance × an integer roll 5 to 9, a roll per eligible song per pick, from a local unsynced source. Hardcoded.
- The highest weight wins, strictly; the first loaded wins ties; 0 never wins. Load order is file order, files in
  (inferred) alphabetical order. Rule hardcoded, order mod-able.
- The six most recently chosen songs are excluded; after each pick, with six held, the oldest leaves, then the new one
  joins; with nothing able to win and fewer than six held, nothing plays until conditions change; the list survives
  between games of a session. Hardcoded.
- With no `music/*.txt` song at all: every `music/*.mp3` but the three special tracks, by whole seconds since entering
  mod the count, never the same twice running. Hardcoded.
- The title theme `music/titletheme_heartsofiron.mp3` starts during the startup load (master volume above 0), plays
  through the main menu, lobby and the game's loading, and stops on the first in-game frame. Name hardcoded, file mod-able.
- At the main menu the title theme is played again when it ends - but that replay usually loses a race in the original,
  so it likely plays once (*inferred*). Hardcoded.
- The end-of-game screen plays `music/victorymarchverdi.mp3` where the winner is the player's faction, else
  `music/diesiraeintro.mp3`, master volume above 0, once, carrying on into the main menu. Names hardcoded, files mod-able.
- Leaving a game by any route stops the music; after the tutorial the last song replays from its start at the main
  menu. Hardcoded.
- Tracks do not loop. Volume = master/100 × music/100, as (fourth root of v) × 10000 − 10000 hundredths of a dB. Hardcoded.
