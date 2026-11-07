class_name ScreenFlow
extends RefCounted

const MENU := 0
const PLAY := 1
const RESULTS := 2

static func menu_arcade_rect(size: Vector2) -> Rect2:
	return Rect2(52, size.y - 330, size.x - 104, 86)

static func menu_free_rect(size: Vector2) -> Rect2:
	return Rect2(52, size.y - 220, size.x - 104, 80)

static func play_menu_rect(size: Vector2) -> Rect2:
	return Rect2(16, size.y - 137, (size.x - 52) * 0.25, 75)

static func play_sound_rect(size: Vector2) -> Rect2:
	var width := size.x - 52
	return Rect2(26 + width * 0.25, size.y - 137, width * 0.36, 75)

static func play_haptic_rect(size: Vector2) -> Rect2:
	var width := size.x - 52
	return Rect2(36 + width * 0.61, size.y - 137, width * 0.39, 75)

static func results_panel_rect(size: Vector2) -> Rect2:
	var height := minf(size.y * 0.76, 760.0)
	return Rect2(30, (size.y - height) * 0.5, size.x - 60, height)

static func results_retry_rect(size: Vector2) -> Rect2:
	var panel := results_panel_rect(size)
	return Rect2(60, panel.end.y - 166, size.x - 120, 75)

static func results_menu_rect(size: Vector2) -> Rect2:
	var panel := results_panel_rect(size)
	return Rect2(60, panel.end.y - 80, size.x - 120, 60)

static func hit_action(screen: int, position: Vector2, size: Vector2) -> String:
	if screen == MENU:
		if menu_arcade_rect(size).has_point(position):
			return "arcade"
		if menu_free_rect(size).has_point(position):
			return "free"
	elif screen == RESULTS:
		if results_retry_rect(size).has_point(position):
			return "retry"
		if results_menu_rect(size).has_point(position):
			return "menu"
	elif screen == PLAY:
		if play_menu_rect(size).has_point(position):
			return "menu"
		if play_sound_rect(size).has_point(position):
			return "sound"
		if play_haptic_rect(size).has_point(position):
			return "haptics"
	return ""
