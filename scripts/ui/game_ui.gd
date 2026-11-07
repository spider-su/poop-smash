extends Node2D

const Screens = preload("res://scripts/screen_flow.gd")
const Variants = preload("res://scripts/poop_variants.gd")
const ScoreRules = preload("res://scripts/score_rules.gd")
const Renderer = preload("res://scripts/character/poop_renderer.gd")
const Deformation = preload("res://scripts/character/poop_deformation.gd")
const Expressions = preload("res://scripts/character/poop_expressions.gd")
const INK := Color("#59210f")
const PURPLE := Color("#6125a9")
var game
var font := preload("res://assets/fonts/Fredoka-Bold.ttf")
var hero := Renderer.new()
var hero_deformation := Deformation.new()
var hero_expression := Expressions.new()

func _init() -> void:
	hero_deformation.entrance = 1.0
	hero_expression.state = Expressions.State.LAUGHING
	hero_expression.mouth = 0.85
	hero_expression.blink = 1.0 # Glasses cover closed eyes; no white edges protrude.

func _draw() -> void:
	if game == null:
		return
	draw_set_transform(game.content_origin)
	var size: Vector2 = game.content_size
	if game.screen == Screens.MENU:
		_draw_menu(size)
	elif game.screen == Screens.RESULTS:
		_draw_results(size)
	else:
		_draw_hud(size)
		_draw_footer(size)

func _number(value: int) -> String:
	var digits := str(value)
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result

func _rounded_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.49)
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
			var angle := (float(corner) - 1.0) * PI / 2.0 + float(j) * PI / 16.0
			vertices.append(origin + Vector2(cos(angle), sin(angle)) * r)
	return vertices

func _panel(rect: Rect2, top: Color, bottom: Color, radius: float = 28.0, rim: Color = Color("#d293ff")) -> void:
	draw_colored_polygon(_rounded_points(Rect2(rect.position + Vector2(0, 7), rect.size), radius), bottom.darkened(0.48))
	draw_colored_polygon(_rounded_points(rect, radius), rim)
	var inner := rect.grow(-4)
	var points := _rounded_points(inner, radius - 4)
	var colors := PackedColorArray()
	for point in points:
		colors.append(top.lerp(bottom, clampf((point.y - inner.position.y) / inner.size.y, 0, 1)))
	draw_polygon(points, colors)
	draw_line(rect.position + Vector2(radius, 8), Vector2(rect.end.x - radius, rect.position.y + 8), Color(1, 1, 1, 0.65), 3.0, true)

func _text(rect: Rect2, words: String, size: int, fill: Color = Color.WHITE, outline: Color = INK, weight: int = 6) -> void:
	var baseline := rect.position + Vector2(0, (rect.size.y + size) * 0.5 - 7)
	draw_string_outline(font, baseline + Vector2(0, 3), words, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), size, weight + 2, outline.darkened(0.25))
	draw_string_outline(font, baseline, words, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), size, weight, outline)
	draw_string(font, baseline, words, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), size, fill)

func _play_icon(center: Vector2, radius: float = 22.0) -> void:
	var points := PackedVector2Array([center + Vector2(-radius * 0.6, -radius), center + Vector2(radius, 0), center + Vector2(-radius * 0.6, radius)])
	draw_colored_polygon(points, Color("#f8fff0"))
	points.append(points[0])
	draw_polyline(points, Color("#287000"), 4.0, true)

func _clock(center: Vector2, radius: float = 24.0) -> void:
	draw_circle(center, radius + 5, INK)
	draw_circle(center, radius + 1, Color.WHITE)
	draw_circle(center, radius - 5, Color("#b2551e"))
	draw_line(center, center + Vector2(0, -radius * 0.56), Color.WHITE, 4.0, true)
	draw_line(center, center + Vector2(radius * 0.35, radius * 0.24), Color.WHITE, 4.0, true)
	draw_line(center + Vector2(-5, -radius - 8), center + Vector2(5, -radius - 8), Color.WHITE, 6.0, true)

func _button(rect: Rect2, label: String, green: bool, icon: String = "", text_size: int = 42) -> void:
	var light := Color("#aaff0b") if green else Color("#fff94d")
	var dark := Color("#22b600") if green else Color("#ff9708")
	var edge := Color("#e7ffb6") if green else Color("#fff6bc")
	_panel(rect, light, dark, 48.0, edge)
	var text_rect := rect.grow(-15)
	if icon != "":
		var center := rect.position + Vector2(65, rect.size.y * 0.5)
		if icon == "play":
			_play_icon(center)
		else:
			_clock(center, 23)
		text_rect.position.x += 80
		text_rect.size.x -= 90
	if icon == "clock":
		_text(Rect2(text_rect.position, Vector2(text_rect.size.x, text_rect.size.y * 0.5)), "60-Second", 37, Color.WHITE, Color("#8e330a"), 6)
		_text(Rect2(text_rect.position + Vector2(0, text_rect.size.y * 0.5), Vector2(text_rect.size.x, text_rect.size.y * 0.5)), "Challenge", 38, Color.WHITE, Color("#8e330a"), 6)
	else:
		_text(text_rect, label, text_size, Color.WHITE, Color("#28540c") if green else Color("#8e330a"), 7)

func _draw_menu(size: Vector2) -> void:
	# Native type remains sharp at every phone aspect ratio.
	for i in 11:
		var angle := TAU * i / 11.0
		var p := Vector2(size.x * 0.5, 180) + Vector2(cos(angle) * size.x * 0.37, sin(angle) * 114)
		draw_circle(p, 6 + i % 4 * 2, Color("#bf4b0b"))
	_text(Rect2(36, 37, size.x - 72, 128), "Poop", 114, Color("#fffaf1"), INK, 18)
	_text(Rect2(18, 140, size.x - 36, 148), "Smash", 138, Color("#ffe539"), INK, 20)
	_button(Screens.menu_free_rect(size), "Free Play", true, "play", 47)
	_button(Screens.menu_arcade_rect(size), "60-Second Challenge", false, "clock", 35)
	_settings(size)
	_text(Rect2(180, size.y - 108, size.x - 360, 88), "Best: " + _number(game.best_score), 23, Color("#fff5bc"), PURPLE, 4)

func _settings(size: Vector2) -> void:
	for action in ["sound", "vibe"]:
		var rect := Screens.play_sound_rect(size) if action == "sound" else Screens.play_haptic_rect(size)
		var enabled: bool = game.sound_enabled if action == "sound" else game.haptics_enabled
		_panel(rect, Color("#c85bff"), Color("#7428d3"), 25, Color("#f3c4ff"))
		_text(rect.grow(-5), ("Sound " if action == "sound" else "Vibe ") + ("On" if enabled else "Off"), 23, Color.WHITE, Color("#491477"), 4)

func _draw_hud(size: Vector2) -> void:
	var menu := Screens.play_menu_rect(size)
	_panel(menu, Color("#cf64ff"), Color("#6e22c7"), 44, Color("#f1c6ff"))
	# House symbol keeps the existing return-to-menu action explicit.
	var c := menu.get_center()
	draw_colored_polygon(PackedVector2Array([c + Vector2(-25, -2), c + Vector2(0, -25), c + Vector2(25, -2), c + Vector2(17, -2), c + Vector2(17, 23), c + Vector2(-17, 23), c + Vector2(-17, -2)]), Color.WHITE)
	draw_rect(Rect2(c + Vector2(-6, 6), Vector2(12, 18)), PURPLE)
	_panel(Rect2(135, 29, 233, 78), Color("#347c62"), Color("#15554c"), 37, Color("#8edbbd"))
	_clock(Vector2(177, 69), 23)
	var time_text := "0:%02d" % ceili(game.remaining_seconds) if game.arcade_mode and game.remaining_seconds < 60 else ("1:00" if game.arcade_mode else "Free Play")
	_text(Rect2(211, 34, 146, 69), time_text, 38 if game.arcade_mode else 26, Color.WHITE, Color("#17443a"), 5)
	_panel(Rect2(size.x - 267, 29, 245, 78), Color("#347c62"), Color("#15554c"), 37, Color("#8edbbd"))
	_text(Rect2(size.x - 260, 34, 231, 69), _number(game.score if game.arcade_mode else game.round_smashes), 43, Color("#ffe64b"), INK, 6)
	var combo := mini(game.combo_count, ScoreRules.MAX_MULTIPLIER)
	var caption := "Combo x%d!" % combo if combo > 1 else ("Squish & smash!" if game.arcade_mode else Variants.display_name(game.current_variant).capitalize())
	_text(Rect2(100, 144, size.x - 200, 66), caption, 44, Color("#fff9d2"), Color("#81350e"), 8)
	var track := Rect2(size.x * 0.28, 218, size.x * 0.44, 30)
	_panel(track, Color("#451285"), Color("#321164"), 15, Color("#f1cfff"))
	var ratio: float = game.combo_window / ScoreRules.COMBO_WINDOW_SECONDS if combo > 1 else game.character.pressure / Variants.burst_threshold(game.current_variant)
	if ratio > 0.01:
		_panel(Rect2(track.position + Vector2(4, 4), Vector2(maxf(12.0, (track.size.x - 8) * ratio), 22)), Color("#f18aff"), Color("#a72bff"), 11, Color("#fbc8ff"))
	if game.reward_timer > 0.0 and game.arcade_mode:
		_text(Rect2(120, 270 - (1.3 - game.reward_timer) * 30, size.x - 240, 58), "+" + _number(game.last_reward), 45, Color("#ffeb45"), INK, 7)

func _thumbnail(center: Vector2, kind: int, scale_factor: float = 0.18) -> void:
	var palette := Variants.palette(kind)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for p in hero.rest:
		points.append(center + p * scale_factor)
		colors.append(palette[0].lerp(palette[1], clampf(0.6 - p.x / 600.0 - p.y / 850.0, 0.0, 1.0)))
	draw_polygon(points, colors)
	for side in [-1, 1]:
		var eye := center + Vector2(side * 62, -16) * scale_factor
		draw_circle(eye, scale_factor * 41, Color.WHITE)
		draw_circle(eye + Vector2(2, 2), scale_factor * 22, INK)
	draw_arc(center + Vector2(0, 56) * scale_factor, scale_factor * 37, 0.1, PI - 0.1, 16, INK, 3.0, true)
	if kind == Variants.GOLDEN:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-10, -31), center + Vector2(-12, -44), center + Vector2(0, -39), center + Vector2(9, -46), center + Vector2(13, -31)]), Color("#fff16c"))

func _draw_footer(size: Vector2) -> void:
	var dock := Screens.variant_dock_rect(size)
	_panel(dock, Color(0.58, 0.29, 0.66, 0.85), Color(0.38, 0.13, 0.5, 0.88), 30, Color("#ffcff5"))
	var width := (dock.size.x - 16) / 4.0
	for kind in Variants.ALL:
		var cell := Rect2(dock.position + Vector2(8 + kind * width, 7), Vector2(width - 5, 115))
		if kind == game.current_variant:
			_panel(cell, Color("#ffe957"), Color("#ffad38"), 23, Color("#fff9c2"))
		_thumbnail(cell.get_center() + Vector2(0, -20), kind)
		_text(Rect2(cell.position.x, cell.end.y - 29, cell.size.x, 24), Variants.display_name(kind).capitalize(), 17, Color.WHITE, PURPLE, 3)
	_settings(size)
	_text(Rect2(185, size.y - 108, size.x - 370, 88), "Tap • Hold • Drag", 21, Color.WHITE, PURPLE, 3)

func _draw_results(size: Vector2) -> void:
	for i in 32:
		var t := float(i) / 31.0
		draw_rect(Rect2(0, size.y * t, size.x, size.y / 31.0 + 2), Color("#6424b7").lerp(Color("#391477"), t))
	var glow := Vector2(size.x * 0.5, size.y * 0.29)
	for i in 16:
		var angle: float = TAU * i / 16.0 + game.celebration_time * 0.035
		draw_colored_polygon(PackedVector2Array([glow, glow + Vector2.from_angle(angle) * size.y, glow + Vector2.from_angle(angle + 0.10) * size.y]), Color(1, 0.74, 0.8, 0.07))
	for i in (8 if game.reduced_effects else 28):
		var p := Vector2(size.x * float((i * 37 + 17) % 101) / 101.0, fposmod(float(i * 83) + game.celebration_time * (35 + i % 5 * 15), size.y))
		draw_set_transform(game.content_origin + p, float(i), Vector2.ONE)
		draw_rect(Rect2(-5, -9, 10, 18), [Color("#ffe646"), Color("#ff6aaa"), Color("#65e6ff")][i % 3])
	draw_set_transform(game.content_origin)
	_text(Rect2(20, 20, size.x - 40, 75), "Challenge", 62, Color("#fff6ff"), Color("#3d0c73"), 13)
	_text(Rect2(20, 90, size.x - 40, 74), "Complete!", 66, Color("#fff6ff"), Color("#3d0c73"), 13)
	var panel := Screens.results_panel_rect(size)
	var hero_position := Vector2(size.x * 0.5, panel.position.y - 125)
	var hero_scale := minf(0.94, size.y / 1420.0)
	hero_deformation.time = game.celebration_time
	hero_expression.age = game.celebration_time
	draw_set_transform(game.content_origin + hero_position, 0, Vector2.ONE * hero_scale)
	hero.draw_on(self, hero_deformation, hero_expression, 0, 0.0, game.reduced_effects, true)
	draw_set_transform(game.content_origin)
	var card := Rect2(42, panel.position.y, size.x - 84, size.y * 0.15)
	_panel(card, Color("#9b32ed"), Color("#3b127b"), 34, Color("#efb6ff"))
	_text(Rect2(card.position.x + 12, card.position.y + 10, card.size.x - 24, card.size.y * 0.30), "Your Score", 32, Color.WHITE, Color("#310e68"), 5)
	var count := int(game.score * (1.0 - pow(1.0 - clampf(game.celebration_time / 0.9, 0, 1), 3.0)))
	_text(Rect2(card.position.x + 20, card.position.y + card.size.y * 0.34, card.size.x - 40, card.size.y * 0.58), _number(count), 83, Color("#ffe536"), Color("#a3440d"), 8)
	if game.latest_record:
		var badge := Rect2(size.x - 150, card.position.y - 29, 122, 62)
		_panel(badge, Color("#ff9e32"), Color("#e95016"), 20, Color("#fffbd1"))
		_text(badge.grow(-4), "New Best!", 23, Color.WHITE, Color("#983005"), 3)
	var stats := [["Smashes", str(game.round_smashes)], ["Max Combo", "x%d" % mini(game.max_combo, ScoreRules.MAX_MULTIPLIER)], ["Time", "60s"]]
	for i in 3:
		var row := Rect2(57, card.end.y + 12 + i * size.y * 0.061, size.x - 114, size.y * 0.053)
		_panel(row, Color("#7334be"), Color("#4e218d"), 23, Color("#9564cf"))
		if i == 0:
			_thumbnail(row.position + Vector2(39, row.size.y * 0.5 - 4), 0, 0.095)
		elif i == 1:
			_text(Rect2(row.position.x + 10, row.position.y, 60, row.size.y), "x", 40, Color("#ffdf32"), INK, 4)
		else:
			_clock(row.position + Vector2(39, row.size.y * 0.5), 15)
		_text(Rect2(row.position.x + 81, row.position.y, row.size.x * 0.48, row.size.y), stats[i][0], 28, Color.WHITE, Color("#381065"), 4)
		_text(Rect2(row.end.x - 130, row.position.y, 115, row.size.y), stats[i][1], 35, Color("#ffe745"), Color("#381065"), 4)
	_button(Screens.results_retry_rect(size), "Play Again", true, "play", 46)
	var menu := Screens.results_menu_rect(size)
	_panel(menu, Color("#c457f5"), Color("#7225c7"), 42, Color("#efbeff"))
	_text(menu.grow(-5), "Main Menu", 36, Color.WHITE, Color("#3d126c"), 6)
