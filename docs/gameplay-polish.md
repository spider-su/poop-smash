# Gameplay polish

## Component boundaries

- `main.gd`: single-finger ownership, screen navigation, one gameplay clock, scoring, combos, settings and safe-area layout.
- `character/poop_character.gd`: pressure and variant state; tap/drag/release/smash; coordinates the components and emits one scored smash and one respawn request.
- `character/poop_deformation.gd`: bounded attachment spring, slower neighboring displacement, localized compression, damped recoil, idle breathing and entrance bounce. All elapsed time is integrated in steps no larger than 1/120 second.
- `character/poop_renderer.gd`: one closed Catmull–Rom silhouette and a 491-vertex shaded mesh, attached swirl seams, soft highlights, face and variant marks. Topology/lighting are cached; the same deformed contour is used for hit detection. No external art or heavy shader dependencies.
- `character/poop_expressions.gd`: explicit expression states, blinking, independent brows, pupil tracking, mouth transitions and infrequent text bubbles.
- `character/poop_effects.gd`: 85 ms anticipation followed by a bounded 0.82-second burst/respawn sequence, directional droplets, landing squashes, variant signatures and comic captions.
- `character/poop_audio.gd`: 24 original cached synthesized clips, four non-interrupting players, category cooldowns, smooth envelopes and bounded overlapping volume.
- `ui/game_ui.gd`: existing bright UI, animated results counting, score feedback and shared layout hitboxes from `screen_flow.gd`.

Scoring and variant rule paths remain unchanged. Combos count playable time, excluding burst animation. The four pressure thresholds, reward multipliers, free-play rotation and random challenge selection remain intact. Existing `user://poop_smash.cfg` saves remain compatible.

Set the main node's exported `reduced_effects` parameter to remove shake/impact rings/trembling and reduce particle/confetti counts. Text feedback remains readable with sound off.

## Validation

Use Godot **4.7.2 stable**:

```sh
bash scripts/check_godot.sh godot --headless --path . --editor --import --quit
for test in tests/test_*.gd; do
  bash scripts/check_godot.sh godot --headless --path . --script "res://$test"
done
bash scripts/check_godot.sh godot --headless --path . --quit-after 120
```

The wrapper fails on engine/script errors even when Godot returns status zero.

Tests cover scoring, variant thresholds, 20/30/60/120 FPS timing, spring stability and recovery, localized deformation, single-finger ownership, collision contours, expression transitions, bubble cooldowns, burst lifecycle, sound cache/levels/overlap, scene navigation, replay and actual file-based settings persistence using isolated test saves.

Capture **actual rendered game frames** in a graphical session:

```sh
godot --path . --resolution 540x960 --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/capture_visuals.gd -- --output=/tmp/poop-smash-visuals
```

The capture script saves menu, idle Classic, squish, stretch, Frozen, Golden, Volcano, explosion and results, plus an engine/viewport manifest. It refuses to produce screenshots with the headless display driver. CI uses Mesa/Xvfb at 540×960, 540×720 and 540×1200. Captures isolate saves and mute audio.

GitHub Actions builds a debug APK for `com.spidersu.poopsmash` after import, all tests, scene boot and captures. It checks the actual APK for the required vibration permission and absence of Internet permission. Open the successful run, then download **poop-smash-debug-apk** from Artifacts and extract `poop-smash-debug.apk`. **poop-smash-visuals** contains the screenshots.

## Acceptance limits

Headless tests prove rules and lifecycle, not subjective tactile quality. Software-rendered screenshots establish layout and rendering evidence, not physical Android performance, safe-area correctness, haptic reliability or speaker quality. Physical-device acceptance remains required on a budget phone and a tall phone. The illustrated 128×128 launcher icon remains the art reference; the live character uses a continuous deformable vector rather than a static bitmap.

Next milestone: physical-device playtesting, 30–60-second free-play feedback, tuning voice mix and touch resistance, launcher/adaptive-icon checks, and measured CPU/frame timing before release signing or store work.
