# The Last Ferry playtests

## Version 1.7.0

The Godot pilot completed all 39 scenes and eight scheduled puzzles, then opened the credits. It logged 460.2 seconds of uninterrupted traversal and zero recoveries. The suite also checked chapter unlocks, the last boar-to-foot transition, and Continue from both a retained checkpoint and a retired scene.

A separate fixed-step rehearsal used the public touch controls and pointer input. It reached the credits after 476.5 seconds of active game time and 67 station pointer presses. Human play times include reading, deciding how to cross, and solving the panels.

The chapter editor opened all 13 chapters and saved and exported a change to a combined encounter count. The Android 1.7.0 package passed v2 and v3 signature verification, 16 KB alignment, and the SHA-256 check. The export omits the retired chapter backdrops and their unused ambience.

[Chapter landscapes](chapter-materials.webp) · [Component index](component-images/00-component-index.png)

## Earlier 1.5 playtest

The Godot pilot reached the credits through all 94 locations and nine scheduled puzzles in 3,698.5 seconds of simulated traversal (61 minutes 39 seconds rounded), with zero failures. The test opened and finished each of the eight chapter replays. Separate ride checks covered both the trolley and the boar waiting at the boarding point, moving with the keeper, holding position during pause, and staying parked after dismount.

Godot rendered each chapter’s ordinary ground for visual inspection.

An Android emulator upgraded the existing installation to version 1.5.0 (build 6), opened the eight-chapter picker, entered Boar Run, and paused at Bracken Gate. The boar was visible on the clay platform before boarding. [Android screenshots](android15.webp)

## Earlier 1.4 playtest

The Godot campaign pilot completed all 150 locations, solved nine scheduled panels, and reached the credits with zero failures. Simulated traversal took 5,043.9 seconds (84 minutes 4 seconds). Chapter selection tests checked all 15 entrances and exits and verified that replay preserved the story checkpoint. A dedicated touch test tapped the hand once from the far side of the first pontoon, supplied zero horizontal input, and checked that the keeper arrived safely on the second float.

Godot rendered the mounted boar, mangrove spider, cave lighting, and both phases of the storm. APK verification passed Android signature schemes v2 and v3 and the 16 KB alignment check. The Android emulator installed version 1.4.0 over the existing game, launched it from the launcher, and opened chapter VIII from the chapter picker. [Android screenshot of Bracken Gate](boar-run.webp)

## Earlier 1.3 playtest

The campaign physics check completed all 150 locations, ten scheduled puzzles, and the ending in 5,835.8 simulated traversal seconds (97 minutes 16 seconds), with zero failures. A separate automated touch-control playthrough started a new game and reached the credits in 96 minutes 22 seconds of active game time.

The chapter selection check opened every chapter from a fresh logbook, verified each ten-location boundary, and checked that replay preserved earned progress and the story checkpoint. The Android 15 emulator installed the signed upgrade over 1.2. On the emulator, chapters VIII and XV opened from the chapter picker, then Continue restored the original landing checkpoint. [Android chapter picker](chapters.webp)

Movement checks cover a successful jump over the first charge, a catch from behind after the dog turns, pushing a crate, backing away while pulling it, and releasing the grip. Two renders from a fixed camera verify the traveling hoist at opposite ends of its rail. The guide posts and overhead beam keep their screen positions as the trolley moves.

## Earlier 1.2 playtest

The campaign simulation reached the ferry and credits through all 150 locations. It recorded **5,778.6 seconds of traversal (96 minutes 19 seconds)** with the known-solution pilot and encountered ten scheduled panels. A separate touch-control rehearsal resumed from a saved checkpoint in the Sluice House and reached the credits after 5,755.4 active game seconds (95 minutes 55 seconds). Individual play times will vary.

| Crossing check | Result |
| --- | --- |
| Manual paired locks | Two across the campaign, down from 49 in version 1.1 |
| Consecutive breakaway planks | 3, 4, 5, 6, 7, 8, or 10 |
| Consecutive moving pontoons or suspended decks | 1, 2, 3, 4, or 5 |
| Elevation | Every exit meets the next entrance at the same world height. The first landing stands 73 world pixels above the waterline and the final gallery stands 835 above it. |
| Hound | The dog warned from ahead, caught a stationary keeper, and reset on respawn. The running-jump test cleared the dog and landed safely. |

The signed APK installed over version 1.1 on a private Android 15 x86-64 emulator. Continue restored the existing checkpoint, Android Back opened pause, and the installed file’s SHA-256 matched the APK in `dist/`. The package passed v2 and v3 signature checks and 16 KB alignment. Physical ARM-device testing remains outstanding.

[Low-water passage](low-water.webp) · [Upper tower](upper-tower.webp) · [Running jump](hound.webp)

## Reproduce the checks

- `bash scripts/check.sh` exercises campaign physics, puzzle solving and pacing, room transitions, terrain variety, death and recovery, settings, replay, save migration, and the ending.
- `bash scripts/rehearse.sh --fixed-fps 60` plays through the chapter transitions, touch controls, instrument interfaces and beacon at an accelerated frame rate. Omit the fixed frame rate to run in real time.
- `bash scripts/preview.sh` captures the game viewport using a graphical Linux session. Test saves and captures stay under `.work/`.

## Earlier Android 1.1 checks

The locally signed 1.1.0 APK (version code 2) installed over the local 1.0.0 build on a private Android 15 x86-64 emulator. It retained the previous installation date and resumed the old save at the restored landing checkpoint. The test used a 1280 × 720 landscape viewport and host-backed Intel UHD 620 graphics.

The Android run increased touch buttons to 150%, checked their gameplay layout, restored the default size, switched between both bell-counterpoise layouts, and solved the second layout using touch. A chapter replay tested a two-finger running jump and pull-up onto the high quay while preserving the campaign save. [Android screenshot](dock.webp)

The APK passed v2 and v3 signature verification and 16 KB zip alignment. Its manifest declares Android 7.0 as the minimum, ARM64, ARMv7, and x86-64 architectures, and zero requested permissions. The installed APK’s SHA-256 matched the file in `dist/`. Device coverage is limited to the x86-64 emulator. The included GitHub Actions workflow was checked through its local build and test commands.
