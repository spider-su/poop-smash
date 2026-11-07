class_name ScreenFlow
extends RefCounted

const MENU := 0
const PLAY := 1
const RESULTS := 2

static func menu_arcade_rect(size: Vector2) -> Rect2:
	return Rect2(52, size.y * 0.66, size.x - 104, 86)

static func menu_free_rect(size: Vector2) -> Rect2:
	return Rect2(52, size.y * 0.66 + 108, size.x - 104, 80)

static func play_menu_rect(size: Vector2) -> Rect2:
	return Rect2(16, size.y - 137, 166, 75)

static func play_sound_rect(size: Vector2) -> Rect2:
	return Rect2(192, size.y - 137, 242, 75)

static func play_haptic_rect(size: Vector2) -> Rect2:
	return Rect2(444, size.y - 137, size.x - 460, 75)

static func results_retry_rect(size: Vector2) -> Rect2:
	return Rect2(60, size.y * 0.26 + size.y * 0.56 - 160, size.x - 120, 75)

static func results_menu_rect(size: Vector2) -> Rect2:
	return Rect2(60, size.y * 0.26 + size.y * 0.56 - 76, size.x - 120, 60)

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
