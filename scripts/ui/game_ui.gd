extends Node2D

const Screens = preload("res://scripts/screen_flow.gd")
const Variants = preload("res://scripts/poop_variants.gd")
const ScoreRules = preload("res://scripts/score_rules.gd")
const INK := Color("#442738")
const BROWN := Color("#865029")
const ROUND_SECONDS := 60.0
var game

func _draw() -> void:
	if game == null:
		return
	draw_set_transform(game.content_origin)
	var size: Vector2 = game.content_size
	var font := ThemeDB.fallback_font
	if game.screen == Screens.MENU:
		_draw_menu(font, size)
	elif game.screen == Screens.RESULTS:
		_draw_results(font, size)
	else:
		_draw_hud(font, size)
		_draw_footer(font, size)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	draw_colored_polygon(points, color)

func _round_rect(rect: Rect2, color: Color, radius: float = 20.0) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.45)
	var vertices := PackedVector2Array()
	for corner in 4:
		var origin := Vector2(rect.end.x - r, rect.position.y + r)
		if corner == 1:
			origin = rect.end - Vector2.ONE * r
		elif corner == 2:
			origin = Vector2(rect.position.x + r, rect.end.y - r)
		elif corner == 3:
			origin = rect.position + Vector2.ONE * r
		for j in 9:
			var a := (float(corner) - 1.0) * PI / 2.0 + float(j) * PI / 16.0
			vertices.append(origin + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(vertices, color)

func _button(font: Font, rect: Rect2, label: String, background: Color, foreground: Color = Color.WHITE, font_size: int = 30) -> void:
	var shadow := Rect2(rect.position + Vector2(0, 7), rect.size)
	_round_rect(shadow, background.darkened(0.48), 28.0)
	_round_rect(rect, background, 28.0)
	draw_line(rect.position + Vector2(32, 9), Vector2(rect.end.x - 32, rect.position.y + 9), background.lightened(0.27), 4.0, true)
	var baseline := rect.position.y + (rect.size.y + float(font_size)) * 0.5 - 7.0
	draw_string(font, Vector2(rect.position.x + 18.0, baseline), label, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x - 36.0), font_size, foreground)

func _draw_menu(font: Font, size: Vector2) -> void:
	# The animated in-game mascot is shared by menu and gameplay.
	draw_string(font, Vector2(30, 118), "POOP SMASH!", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 60), 64, Color("#75351d"))
	draw_string(font, Vector2(40, 173), "SQUISH • SPLAT • LAUGH!", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 80), 25, Color("#8c5630"))
	draw_string(font, Vector2(40, Screens.menu_arcade_rect(size).position.y - 38), "A little squish. A lot of personality.", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 80), 27, INK)
	_button(font, Screens.menu_arcade_rect(size), "60-SECOND CHALLENGE", Color("#f6ac1f"), Color("#62361d"), 31)
	_button(font, Screens.menu_free_rect(size), "FREE PLAY", Color("#4bd73e"), Color("#24431b"), 32)
	draw_string(font, Vector2(32, size.y - 43), "OFFLINE • NO ADS • BEST %d" % game.best_score, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 64), 23, Color("#673c37"))

func _draw_hud(font: Font, size: Vector2) -> void:
	_round_rect(Rect2(18, 22, size.x - 36, 288), Color("#fff5df"), 28.0)
	draw_string(font, Vector2(42, 83), "POOP SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 47, INK)
	draw_string(font, Vector2(42, 130), "%s • %s" % [Variants.display_name(game.current_variant), Variants.description(game.current_variant)], HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 84), 24, BROWN)
	if game.arcade_mode:
		draw_string(font, Vector2(42, 203), "TIME %02d" % ceili(game.remaining_seconds), HORIZONTAL_ALIGNMENT_LEFT, -1, 37, INK)
		draw_string(font, Vector2(312, 203), "SCORE %d" % game.score, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 344), 32, INK)
		_round_rect(Rect2(42, 223, size.x - 84, 18), Color("#e7d0a8"), 9.0)
		if game.remaining_seconds > 0.0:
			_round_rect(Rect2(42, 223, (size.x - 84) * game.remaining_seconds / ROUND_SECONDS, 18), Color("#f5a129"), 9.0)
		if game.combo_count > 1 and game.combo_window > 0.0:
			draw_string(font, Vector2(42, 284), "COMBO x%d" % mini(game.combo_count, ScoreRules.MAX_MULTIPLIER), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#bb3c6a"))
	else:
		draw_string(font, Vector2(42, 208), "FREE PLAY • %d SMASHES" % game.round_smashes, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 84), 30, INK)
	if game.reward_timer > 0.0 and game.arcade_mode:
		draw_string(font, Vector2(42, 355 - 12.0 * (1.0 - game.reward_timer / 1.3)), "+%d" % game.last_reward, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#bd396a"))

func _draw_footer(font: Font, size: Vector2) -> void:
	_round_rect(Rect2(9, size.y - 165, size.x - 18, 150), Color("#ffedce"), 25.0)
	_button(font, Screens.play_menu_rect(size), "MENU", Color("#9656cb"), Color.WHITE, 25)
	_button(font, Screens.play_sound_rect(size), "SOUND %s" % ("ON" if game.sound_enabled else "OFF"), Color("#e29a40"), Color.WHITE, 22)
	_button(font, Screens.play_haptic_rect(size), "VIBE %s" % ("ON" if game.haptics_enabled else "OFF"), Color("#e29a40"), Color.WHITE, 22)
	draw_string(font, Vector2(35, size.y - 23), "TAP · HOLD · DRAG", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 70), 22, BROWN)

func _draw_results(font: Font, size: Vector2) -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.20, 0.09, 0.32, 0.91))
	for i in (8 if game.reduced_effects else 32):
		var x := size.x * float((i * 37 + 17) % 101) / 101.0
		var y := fposmod(float((i * 71) % 100) / 100.0 * size.y + game.celebration_time * (35.0 + float(i % 5) * 15.0), size.y)
		_ellipse(Vector2(x, y), Vector2(6, 12), Color("#ffc24c") if i % 2 == 0 else Color("#ed82bc"))
	var panel := Screens.results_panel_rect(size)
	_round_rect(panel, Color("#f8e6ff"), 34.0)
	draw_string(font, Vector2(58, panel.position.y + panel.size.y * 0.10), "CHALLENGE COMPLETE!", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 116), 36, Color("#6a2c9b"))
	var subtitle := "NEW PERSONAL BEST!" if game.latest_record else "NICE SMASHING!"
	draw_string(font, Vector2(58, panel.position.y + panel.size.y * 0.18), subtitle, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 116), 28, Color("#b7426a"))
	draw_string(font, Vector2(55, panel.position.y + panel.size.y * 0.34), "%d POINTS" % int(game.score * (1.0 - pow(1.0 - clampf(game.celebration_time / 0.9, 0.0, 1.0), 3.0))), HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 110), 48, Color("#7432ab"))
	draw_string(font, Vector2(56, panel.position.y + panel.size.y * 0.44), "%d SMASHES • MAX COMBO x%d" % [game.round_smashes, mini(game.max_combo, ScoreRules.MAX_MULTIPLIER)], HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 112), 24, BROWN)
	draw_string(font, Vector2(56, panel.position.y + panel.size.y * 0.53), "PERSONAL BEST: %d" % game.best_score, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 112), 27, INK)
	_button(font, Screens.results_retry_rect(size), "PLAY AGAIN", Color("#57d538"), Color("#294d21"), 32)
	_button(font, Screens.results_menu_rect(size), "MAIN MENU", Color("#9451d7"), Color.WHITE, 27)

