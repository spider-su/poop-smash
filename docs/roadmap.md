# Poop Smash roadmap

## M0 — playable draft (complete)
- [x] Original procedural cartoon character
- [x] Tap, press-and-hold, drag to squish
- [x] Pressure, splat burst, automatic respawn
- [x] Synthesized randomized squish sounds
- [x] Smash counter
- [x] Godot headless test + Android APK workflow

## M1 — character feel (iteration 1)
- [x] Finger-position deformation and drag stretch
- [x] Spring-driven wobble and shape recovery
- [x] Animated face: eye tracking, blinking and reactions
- [x] Particle movement, gravity and shrinking during splat
- [x] Varied generated squish, drag and burst sounds
- [x] Optional haptic hook on mobile (enabled, settings UI pending)
- [ ] Real device acceptance and tuning
- [ ] Audio/haptics settings controls and persistent preferences
- [ ] Richer localized squash mesh, voiced character quips, richer particles

## M2 — short game loop
- [ ] 60-second arcade challenge, combos and best score
- [ ] Different poop types and special reactions
- [ ] Local progress and settings
- [ ] Illustration, icon and Play Store assets

## M3 — release
- [ ] Mobile accessibility and performance pass
- [ ] Release signing, AAB and store compliance
- [ ] Closed test and player feedback

## Testing
Run headless import, test_squish_rules, and scene boot through CI. On device, check:
tap→expression/sound; hold→pressure/burst; drag→stretch/eye tracking;
release→elastic return; splat→droplets→respawn; 30+ repeated bursts;
different finger IDs; silent or haptic-disabled device behaviour.
