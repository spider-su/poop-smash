# Poop Smash roadmap

## M0 — playable draft (complete)
- [x] Original procedural cartoon character
- [x] Tap, press-and-hold, drag to squish
- [x] Pressure, splat burst, automatic respawn
- [x] Synthesized randomized squish sounds
- [x] Smash counter
- [x] Godot headless test + Android APK workflow

## M1 — character feel
- [x] Finger-position deformation and drag stretch
- [x] Spring-driven wobble and shape recovery
- [x] Animated face: eye tracking, blinking and reactions
- [x] Particle movement, gravity and shrinking during splat
- [x] Varied generated squish, drag and burst sounds
- [x] Toggle sound and haptics, persist choices locally
- [ ] Physical Android device playtest and tuning
- [ ] Richer deformation and voiced character quips

## M2 — short game loop
- [x] Optional 60-second arcade challenge with timer and game-over state
- [x] Points and combo multipliers, capped at x5
- [x] Local personal best score and preferences
- [ ] Different poop types and special reactions
- [ ] Better game-over and retry UI
- [ ] Artwork, icon and Play Store assets

## M3 — release
- [ ] Accessibility, Android performance and device acceptance
- [ ] Release signing and AAB
- [ ] Closed testing and player feedback

## Testing
Use Godot headless import, squish tests, scoring tests, and scene boot. Check a real
Android device for interactions, sound toggle, vibration toggle, exact 60-second
round ending, score persistence after app relaunch, and returning to free play.
