class_name ScreenFlow
extends RefCounted

const MENU := 0
const PLAY := 1
const RESULTS := 2

static func menu_arcade_rect(size: Vector2) -> Rect2:
	return Rect2(52, size.y - 230, size.x - 104, 108)

static func menu_free_rect(size: Vector2) -> Rect2:
	return Rect2(52, size.y - 352, size.x - 104, 100)

static func play_menu_rect(size: Vector2) -> Rect2:
	return Rect2(22, 24, 90, 90)

static func play_sound_rect(size: Vector2) -> Rect2:
	return Rect2(24, size.y - 108, 144, 88)

static func play_haptic_rect(size: Vector2) -> Rect2:
	return Rect2(size.x - 168, size.y - 108, 144, 88)

static func variant_dock_rect(size: Vector2) -> Rect2:
	return Rect2(24, size.y - 252, size.x - 48, 132)

static func results_panel_rect(size: Vector2) -> Rect2:
	return Rect2(30, size.y * 0.41, size.x - 60, size.y * 0.58)

static func results_retry_rect(size: Vector2) -> Rect2:
	return Rect2(48, size.y * 0.805, size.x - 96, size.y * 0.085)

static func results_menu_rect(size: Vector2) -> Rect2:
	return Rect2(size.x * 0.20, size.y * 0.91, size.x * 0.60, size.y * 0.070)

static func hit_action(screen: int, position: Vector2, size: Vector2) -> String:
	if screen == MENU:
		if play_sound_rect(size).has_point(position):
			return "sound"
		if play_haptic_rect(size).has_point(position):
			return "haptics"
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
