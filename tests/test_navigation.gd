extends SceneTree

class TestGame:
	extends "res://scripts/main.gd"
	func _preferences_path() -> String:
		return "user://navigation_test_%d.cfg" % OS.get_process_id()

var failures := 0
func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _touch(game, index: int, point: Vector2, pressed: bool = true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	game._input(event)

func _run() -> void:
	var game := TestGame.new()
	root.add_child(game)
	game.set_process(false)
	_check(game.screen == game.Screens.MENU, "Launch did not open menu")
	_touch(game, 0, game.Screens.menu_free_rect(game.content_size).get_center())
	_check(game.screen == game.Screens.PLAY and not game.arcade_mode, "Free-play navigation failed")
	_touch(game, 0, game._center())
	var finger: Vector2 = game.character.finger
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = game._center() + Vector2(180, 0)
	drag.relative = Vector2(180, 0)
	game._input(drag)
	_check(game.character.finger == finger, "Second finger moved character")
	_touch(game, 1, game.Screens.play_menu_rect(game.content_size).get_center())
	_check(game.screen == game.Screens.PLAY, "Second finger activated UI while character held")
	_touch(game, 0, game._center(), false)
	_touch(game, 0, game.Screens.play_sound_rect(game.content_size).get_center())
	_touch(game, 0, game.Screens.play_haptic_rect(game.content_size).get_center())
	_check(not game.sound_enabled and not game.haptics_enabled and not game.character.holding, "Settings touch leaked into character")
	_touch(game, 0, game.Screens.play_menu_rect(game.content_size).get_center())
	_touch(game, 0, game.Screens.menu_arcade_rect(game.content_size).get_center())
	_check(game.arcade_mode and game.remaining_seconds == 60.0, "Challenge navigation failed")
	game._process(0.4)
	game.character.smash()
	var score: int = game.score
	game._process(0.9)
	_check(not game.character.spent and score > 0, "Explosion/respawn/scoring failed")
	game.score = 4321
	game._process(60.0)
	_check(game.screen == game.Screens.RESULTS and game.best_score == 4321, "Results/personal best failed")
	_touch(game, 0, game.Screens.results_retry_rect(game.content_size).get_center())
	_check(game.screen == game.Screens.PLAY and game.score == 0, "Replay failed")
	game._go_menu()
	var path: String = game._preferences_path()
	game.free()
	var restored := TestGame.new()
	root.add_child(restored)
	restored.set_process(false)
	_check(restored.best_score == 4321 and not restored.sound_enabled and not restored.haptics_enabled, "Preferences did not persist across scene restart")
	_check(not restored.character.audio.enabled and not restored.character.haptics_enabled, "Loaded settings did not reach character")
	restored.free()
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("Navigation, single-finger input and persistence: PASS")
	quit(0 if failures == 0 else 1)
