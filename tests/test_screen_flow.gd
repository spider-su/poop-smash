extends SceneTree

const Flow = preload("res://scripts/screen_flow.gd")

func _initialize() -> void:
	var size := Vector2(720, 1280)
	if Flow.hit_action(Flow.MENU, Flow.menu_arcade_rect(size).get_center(), size) != "arcade":
		_fail("Arcade start not tappable")
		return
	if Flow.hit_action(Flow.MENU, Flow.menu_free_rect(size).get_center(), size) != "free":
		_fail("Free-play start not tappable")
		return
	if Flow.hit_action(Flow.RESULTS, Flow.results_retry_rect(size).get_center(), size) != "retry":
		_fail("Replay not tappable")
		return
	if Flow.hit_action(Flow.RESULTS, Flow.results_menu_rect(size).get_center(), size) != "menu":
		_fail("Return to menu not tappable")
		return
	if Flow.hit_action(Flow.PLAY, Flow.play_sound_rect(size).get_center(), size) != "sound":
		_fail("Sound toggle not tappable")
		return
	if Flow.hit_action(Flow.PLAY, Flow.play_haptic_rect(size).get_center(), size) != "haptics":
		_fail("Vibration toggle not tappable")
		return
	if Flow.hit_action(Flow.MENU, Vector2(350, 620), size) != "":
		_fail("Non-buttons should not fire actions")
		return
	print("UI screen flow: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
