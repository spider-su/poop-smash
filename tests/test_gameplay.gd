extends SceneTree

# Exercise the real scene logic without reading or changing player preferences.
class TestGame:
	extends "res://scripts/main.gd"

	func _load_preferences() -> void:
		pass

	func _save_preferences() -> void:
		pass

	func _play_sound(_kind: String) -> void:
		pass

	func _play_voice() -> void:
		pass

	func _rumble(_milliseconds: int) -> void:
		pass

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _hold_until_burst(game: TestGame, fps: int) -> float:
	var elapsed := 0.0
	while game.burst_timer <= 0.0 and elapsed < 10.0:
		game._process(1.0 / float(fps))
		elapsed += 1.0 / float(fps)
	return elapsed

func _run() -> void:
	var game := TestGame.new()
	root.add_child(game)
	game.set_process(false)
	for fps in [20, 30, 60, 120]:
		game._start_round()
		game.current_variant = game.Variants.FROZEN
		game._press(game._center())
		var elapsed := _hold_until_burst(game, fps)
		_check(absf(elapsed - 4.532) < 0.06, "Frozen hold timing differs at %d FPS: %f" % [fps, elapsed])
		_check(absf(game.remaining_seconds - (60.0 - elapsed)) < 0.001, "Round clock differs from gameplay time")

		game._start_round()
		game._burst()
		game._process(game.BURST_LENGTH + 0.1)
		game.current_variant = game.Variants.FROZEN
		game._press(game._center())
		_hold_until_burst(game, fps)
		_check(game.combo_count == 2, "Hold-only Frozen smash broke combo at %d FPS" % fps)

	game._start_free_play()
	game.current_variant = game.Variants.CLASSIC
	var center := game._center()
	_check(game._press(center + Vector2(0, 245)), "Visible bottom of character rejected touch")
	game._release()
	_check(not game._press(center + Vector2(210, -180)), "Empty corner accepted touch")
	game.squish_offset = Vector2(20, 10)
	game.squash = 1.0
	game.drag_stretch = Vector2(60, 0)
	_check(game._character_contains(center + Vector2(245, 110)), "Stretched body rejected touch")
	game._start_free_play()
	game.current_variant = game.Variants.CLASSIC
	game._press(center)
	game._drag(center + Vector2(220, 0), Vector2(220, 0))
	var single_event_pressure := game.pressure
	game._start_free_play()
	game.current_variant = game.Variants.CLASSIC
	game._press(center)
	for i in 4:
		game._drag(center + Vector2((i + 1) * 55, 0), Vector2(55, 0))
	_check(is_equal_approx(game.pressure, single_event_pressure), "Swipe pressure depends on event count")

	game._start_free_play()
	game.pressure = 0.95
	game.current_variant = game.Variants.CLASSIC
	var touch := InputEventScreenTouch.new()
	touch.position = center
	touch.pressed = true
	touch.index = 0
	game._input(touch)
	_check(game.burst_timer > 0.0 and game.active_touch == -1, "Burst retained a stale touch owner")

	game._start_round()
	game._burst()
	game._process(game.BURST_LENGTH + game.ScoreRules.COMBO_WINDOW_SECONDS + 0.1)
	_check(game.combo_count == 0, "Combo did not expire after respawn")
	game._start_round()
	game._process(60.0)
	_check(game.screen == game.Screens.RESULTS, "Long frame did not end round")
	_check(not game._press(center), "Results screen accepted gameplay touch")
	game._start_round()
	_check(game.score == 0 and game.remaining_seconds == 60.0 and game.combo_count == 0, "Replay did not reset round")
	game.free()
	if failures == 0:
		print("Gameplay timing and touch: PASS")
	quit(0 if failures == 0 else 1)
