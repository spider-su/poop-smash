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
	for viewport in [Vector2(720, 960), Vector2(720, 1280), Vector2(720, 1600), Vector2(960, 1280)]:
		var bounds := Rect2(Vector2.ZERO, viewport)
		var controls := [Flow.play_menu_rect(viewport), Flow.play_sound_rect(viewport), Flow.play_haptic_rect(viewport)]
		for rect in controls:
			if not bounds.encloses(rect):
				_fail("Footer control outside viewport")
				return
		if controls[0].intersects(controls[1]) or controls[1].intersects(controls[2]):
			_fail("Footer controls overlap")
			return
		if Flow.menu_arcade_rect(viewport).intersects(Flow.menu_free_rect(viewport)):
			_fail("Menu actions overlap")
			return
		if not Flow.results_panel_rect(viewport).encloses(Flow.results_retry_rect(viewport)) or not Flow.results_panel_rect(viewport).encloses(Flow.results_menu_rect(viewport)):
			_fail("Results actions outside panel")
			return
	print("UI screen flow and aspect ratios: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
