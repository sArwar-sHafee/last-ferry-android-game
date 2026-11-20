# The Last Ferry

A single-player, offline Android puzzle adventure. Three horn blasts reach a flooded harbor. As the ferry keeper, cross the station, restore its machinery, and bring the waiting ship home.

![The keeper crossing the first dock on Android](docs/dock.webp)

## Play version 1.7.0

Install `dist/the-last-ferry.apk` on an OpenGL ES 3-capable device running Android 7.0 or later. The APK includes ARM64, ARMv7, and x86-64 builds. On a connected device you can install it with `adb install -r dist/the-last-ferry.apk`. Open **The Last Ferry** and choose **New game** or **Continue**. The local 1.7.0 APK upgrades earlier local builds. Continue resumes at a matching checkpoint in a retained scene. Saves from retired scenes resume at the next retained scene’s entrance.

| Action | Touch | Keyboard |
| --- | --- | --- |
| Move | Left and right arrows | A / D or arrow keys |
| Jump or catch a ledge | Up arrow while moving toward the lip | Space, W, or Up while moving toward the lip |
| Pull up or drop | Keep holding toward the ledge or tap jump to climb. Move away to let go. | Same with movement and jump keys |
| Climb a ladder | Tap Hand to grab, then hold the Down or Up arrow. Tap Hand again to let go. | E to grab or let go, W / S or Up / Down to climb |
| Operate nearby machinery | Hand | E or Enter |
| Move a crate | Hold the hand while moving | Hold E while moving |
| Work a station | Tap the diagram | Arrows and Space or Enter |
| Undo, reset, hint | Station buttons | Z, R, H |
| Pause or close an instrument | Pause or Android Back | Esc |

The game saves at crossing entrances and checkpoint lamps. **Continue** returns to the latest safe ground. Chapter replay and the **Puzzle workshop** have their own play state. In Settings, you can enter a keeper name, mute the game, and resize the movement, jump, and hand buttons from 75% to 150%. The **Support** button on the title screen opens a page with a link to star the project on GitHub.

## Campaign

The keeper crosses **40 scenes in 13 chapters**. Completing a chapter unlocks the next one. Replay uses its own checkpoints. Each campaign puzzle belongs to a specific station, starting with the pilot’s chart at the landing. Ordinary lamps save progress as you walk past.

The hound and spikes each get their own scene in The Tidal Quays. The Pumpworks teaches the steam vent and tilting bridge separately. Later, jump straight from a tilting bridge onto a moving skiff, cross loose planks with a mosquito swarm behind you, time spikes after a vent, or clear spikes during a hound’s charge.

Wait for the green acid to stop falling before crossing the drain. At a low passage, run through when the roof lifts. The final chapter combines both hazards. In The Night Watch, the keeper has to jump an oncoming hound while a swarm closes in from behind.

In **The Brass Ladder**, climb down to collect the key, then return to the catwalk and use Hand to open the door. In **The Lantern Door**, the monkey throws as soon as you grab the ladder. Time your climb around the stone crossing the middle rungs.

In **The Cable Drum**, a gorilla walks in from the left and beats its chest before giving chase. It swings over the breakable planks and gap on ropes, then pursues the keeper through **The Gull Roost**. In **The Seaward Face**, jump the charging hound, cross five breakable planks, and clear the last gap. A swarm buzzes as it approaches, and a monkey calls when it attacks. Footsteps follow the surface beneath the keeper.

Every crossing in the final storm appears earlier. Practice the acid gate in **The Blind Landing** and the monkey-guarded ladder in **The Gull Roost**. In **The Night Watch**, passing the first monkey starts an ambush from two perches.

In The Freightyard, jump from a sagging cargo net before it drops and take shelter on a bollard as a cable drum rolls underneath. The rock-throwing monkey appears in Mangrove Canopy, and the grazing elephant gives chase in The Limestone Cut. Walk up to the tethered boar at Bracken Gate to start Boar Run. Hold left to slow it or right to speed it up. Release the button to return to cruising speed. The Engine Galleries begin on foot.

See the [chapter contents](docs/chapter-contents.md) for new and former chapter numbers, the [chapter editor](docs/chapter-editor.html) for counts, and the [component image index](docs/component-images/00-component-index.png) for each playable component.

The campaign uses eight types of puzzle. Plot a course through buoys, switch a relay grid, balance the bell, route a mirror beam, push freight, join pressure pipes, clear a skiff channel, and meter sluice water. The workshop opens all eight from the title screen. Use **Next layout** to browse all 66 boards at any time. Set the keeper name to `SHA2027` in Settings to show **Skip puzzle** on campaign and workshop boards.

![Platform materials across the voyage](docs/chapter-materials.webp)

The harbor hound barks before charging and turns at the yard posts. Jump its first pass, then watch behind you for the return sprint. Crates can be pushed or pulled while holding the hand button. The keeper faces the crate in both directions. Overhead hoists run on fixed rails, and vertical lift cages travel between guides with a counterweight.

Two short original music cues accompany the hounds and steam. To replace them in your own build, use non-looping Ogg Vorbis files at `game/audio/pursuit.ogg` and `game/audio/undertow.ogg`, then rebuild.

![The keeper jumping over a charging harbor hound](docs/hound.webp)

The full route and all eight puzzle families passed the Godot pilot. [Playtest and package checks](docs/playtest.md)

## Build on Linux

Use a JDK with `javac` and `keytool` (17 or later), Bash, curl, unzip, and the standard checksum utilities. Run these commands from this directory.

```bash
bash scripts/setup-android.sh
bash scripts/check.sh
bash scripts/build-android.sh
```

Setup reuses Godot 4.7.2 and its matching export templates if available. Missing Linux x86-64 tools come from the official Godot and Android distributions, with pinned archive checksums. Project downloads, caches, editor settings, test saves, and scratch files live under `.work/` on this drive. Imported game resources live in `game/.godot/`. The signed, release-template APK and its SHA-256 checksum go in `dist/`.

For desktop play or editing, use the project environment in the same shell.

```bash
source scripts/env.sh
godot --path game
# Open the editor
godot --editor --path game
```

The default sideload signing key is generated locally in `.work/android-user/`. Keep it to install updates over an existing copy. To use a separate key, set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` before building. All three stay outside source control.

## GitHub Actions

The **Android APK** workflow runs on pushes or from **Actions → Android APK → Run workflow**. It installs the pinned tools, exports and verifies the APK, runs the campaign checks, and uploads **the-last-ferry-android**. Download and extract that artifact to get the APK. Each clean runner generates a fresh sideload signing key, so installing across differently signed builds can require uninstalling the previous copy and losing its local save.

## Source and materials

The editable project is in `game/`. `campaign.gd` defines the chapter and scene order. `passage.gd` defines the crossings and hazards. The puzzle layouts are in `game/art/schematics.json` and `campaign.gd`. The art, sound, icon, and data assets ship with the project and work offline.

`scripts/author_boards.py` reproduces and solves the original five families of station layouts. `scripts/compose.py` synthesizes the ambience and machinery sounds. `scripts/compose_accents.py` synthesizes the encounter music. The audio tools use NumPy, SciPy, and FFmpeg. `scripts/make_icon.py` draws the beacon mark with Pillow. These tools are optional for an ordinary build.

The dog warning uses a trimmed recording by Amada44, distributed under CC BY-SA 3.0. The attribution and license are available in the game. [Original recording](https://commons.wikimedia.org/wiki/File:Barking_of_a_dog.ogg)

Harbor paintings were created for this game with OpenAI ImageGen. Godot, Yrsa, Liberation Mono, and their license notices are credited in **Credits → Licenses**.
