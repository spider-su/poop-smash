extends SceneTree

# Exercise the real scene logic without reading or changing player preferences.
class TestGame:
	extends "res://scripts/main.gd"

	func _load_preferences() -> void:
		pass

	func _save_preferences() -> void:
		pass

	func _sync_settings() -> void:
		super()
		character.audio.enabled = false

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _hold_without_motion(game: TestGame, fps: int, seconds: float) -> void:
	for _frame in int(fps * seconds):
		game._process(1.0 / float(fps))

func _drag_to_burst(game: TestGame) -> void:
	game._drag(game.character.to_global(Vector2(150, 0)), Vector2(1100, 0) * game.character.scale)

func _run() -> void:
	var game := TestGame.new()
	root.add_child(game)
	game.set_process(false)
	for fps in [20, 30, 60, 120]:
		game._start_round()
		game.current_variant = game.Variants.FROZEN
		game.character.variant = game.current_variant
		game._press(game._center())
		var tap_pressure: float = game.character.pressure
		_hold_without_motion(game, fps, 6.0)
		_check(not game.character.spent, "A stationary hold destroyed the character at %d FPS" % fps)
		_check(is_equal_approx(game.character.pressure, tap_pressure), "Stationary hold added smash pressure at %d FPS" % fps)
		_check(absf(game.remaining_seconds - 54.0) < 0.01, "Challenge clock stopped during a stationary hold")
		_drag_to_burst(game)
		_check(game.character.spent and game.combo_count == 1, "Dragging no longer earns a smash at %d FPS" % fps)

		game._start_round()
		game.character.smash()
		game._process(game.BURST_LENGTH + 0.1)
		game.current_variant = game.Variants.FROZEN
		game.character.variant = game.current_variant
		game._press(game._center())
		_drag_to_burst(game)
		_check(game.combo_count == 2, "Hold-to-drag Frozen smash broke combo at %d FPS" % fps)

	game._start_free_play()
	game.current_variant = game.Variants.CLASSIC
	game.character.variant = game.current_variant
	var center := game._center()
	_check(game._press(game.character.to_global(game.character.deformation.warp(Vector2(0, 245)))), "Visible bottom of character rejected touch")
	game._release()
	_check(not game._press(game.character.to_global(Vector2(210, -180))), "Empty corner accepted touch")
	game.character.deformation.pull = Vector2(100, 0)
	game.character.deformation.anchor = Vector2(210, 110)
	_check(game.character.contains(game.character.deformation.warp(Vector2(206, 110))), "Stretched body rejected touch")
	game._start_free_play()
	game.current_variant = game.Variants.CLASSIC
	game.character.variant = game.current_variant
	game._press(center)
	game._drag(game.character.to_global(Vector2(220, 0)), Vector2(220, 0) * game.character.scale)
	var single_event_pressure := game.character.pressure
	game._start_free_play()
	game.current_variant = game.Variants.CLASSIC
	game.character.variant = game.current_variant
	game._press(center)
	for i in 4:
		game._drag(game.character.to_global(Vector2((i + 1) * 55, 0)), Vector2(55, 0) * game.character.scale)
	_check(is_equal_approx(game.character.pressure, single_event_pressure), "Swipe pressure depends on event count")

	game._start_free_play()
	game.character.pressure = 0.95
	game.current_variant = game.Variants.CLASSIC
	game.character.variant = game.current_variant
	var touch := InputEventScreenTouch.new()
	touch.position = center
	touch.pressed = true
	touch.index = 0
	game._input(touch)
	_check(game.character.spent and game.active_touch == -1, "Burst retained a stale touch owner")

	game._start_round()
	game.character.smash()
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
