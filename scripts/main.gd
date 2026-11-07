extends Node2D

const Rules = preload("res://scripts/squish_rules.gd")
const ScoreRules = preload("res://scripts/score_rules.gd")
const Variants = preload("res://scripts/poop_variants.gd")
const Screens = preload("res://scripts/screen_flow.gd")
const APP_ICON = preload("res://assets/branding/app-icon.png")
const SAVE_PATH := "user://poop_smash.cfg"
const ROUND_SECONDS := 60.0
const BASE_RADIUS := 176.0
const BROWN := Color("#865029")
const LIGHT_BROWN := Color("#b6773c")
const PINK := Color("#fa96a3")
const INK := Color("#423025")
const CREAM := Color("#fff0d6")
const BURST_LENGTH := 0.82

var pressure := 0.0
var holding := false
var active_touch := -1
var finger := Vector2.ZERO
var finger_start := Vector2.ZERO
var squish_offset := Vector2.ZERO
var squish_velocity := Vector2.ZERO
var squash := 0.0
var squash_velocity := 0.0
var drag_stretch := Vector2.ZERO
var hold_seconds := 0.0
var total_smashes := 0
var current_variant := Variants.CLASSIC
var variant_sequence := 0
var last_reward := 0
var reward_timer := 0.0
var screen := Screens.MENU
var arcade_mode := false
var round_smashes := 0
var max_combo := 0
var latest_record := false
var voice_player: AudioStreamPlayer
var voice_cooldown := 0.0
var round_finished := false
var remaining_seconds := ROUND_SECONDS
var score := 0
var best_score := 0
var combo_count := 0
var combo_window := 0.0
var wobble := 0.0
var burst_timer := 0.0
var blink_timer := 1.7
var blink_remaining := 0.0
var expression_timer := 0.0
var expression := "happy"
var sound_enabled := true
var haptics_enabled := true
var particles: Array[Vector2] = []
var particle_velocity: Array[Vector2] = []
var particle_size: Array[float] = []
var rng := RandomNumberGenerator.new()
var sound_player: AudioStreamPlayer
var sound_cooldown := 0.0
var touch_flash := 0.0
var touch_position := Vector2.ZERO
var celebration_time := 0.0

func _ready() -> void:
	rng.randomize()
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)
	finger = _center()
	_load_preferences()
	_next_variant()
	queue_redraw()

func _process(delta: float) -> void:
	# Consume all elapsed time in small steps so springs stay stable on slow phones.
	var elapsed := delta
	while elapsed > 0.0:
		var step := minf(elapsed, 1.0 / 120.0)
		_advance(step)
		elapsed -= step
	queue_redraw()

func _advance(delta: float) -> void:
	var dt := delta
	if screen == Screens.PLAY and arcade_mode and not round_finished:
		remaining_seconds = maxf(0.0, remaining_seconds - delta)
		if remaining_seconds <= 0.0:
			_finish_round()
	reward_timer = maxf(0.0, reward_timer - delta)
	touch_flash = maxf(0.0, touch_flash - dt * 3.0)
	if screen == Screens.RESULTS:
		celebration_time += dt
	# The player cannot interact during splatter; start the combo deadline on respawn.
	if screen == Screens.PLAY and burst_timer <= 0.0:
		combo_window = maxf(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo_count = 0
	wobble += dt * 3.0
	sound_cooldown = maxf(0.0, sound_cooldown - dt)
	voice_cooldown = maxf(0.0, voice_cooldown - dt)
	blink_timer -= dt
	if blink_timer <= 0.0:
		blink_remaining = 0.12
		blink_timer = rng.randf_range(1.4, 3.5)
	blink_remaining = maxf(0.0, blink_remaining - dt)
	expression_timer = maxf(0.0, expression_timer - dt)
	if expression_timer <= 0.0:
		expression = "happy"

	if burst_timer > 0.0 and screen == Screens.PLAY:
		burst_timer -= dt
		for i in particles.size():
			particle_velocity[i].y += 620.0 * dt
			particles[i] += particle_velocity[i] * dt
		if burst_timer <= 0.0:
			pressure = 0.0
			particles.clear()
			particle_velocity.clear()
			particle_size.clear()
			expression = "happy"
			_next_variant()
	elif screen == Screens.PLAY:
		if holding:
			hold_seconds += dt
			pressure = Rules.add_pressure(pressure, Rules.HOLD_GAIN * dt * Variants.pressure_multiplier(current_variant))
			if pressure > 0.72:
				expression = "worried"
				expression_timer = 0.15
			if pressure >= Variants.burst_threshold(current_variant):
				_burst()
		else:
			pressure = maxf(0.0, pressure - dt * 0.18)
			drag_stretch = drag_stretch.lerp(Vector2.ZERO, minf(1.0, dt * 5.0))

		var target_offset := Vector2.ZERO
		if holding:
			target_offset = (finger - _center()).limit_length(110.0) * 0.20
		var spring := Rules.spring_step(squish_offset, squish_velocity, target_offset, dt)
		squish_offset = spring[0]
		squish_velocity = spring[1]
		var target_squash := pressure if holding else 0.0
		var acceleration := (target_squash - squash) * 64.0 - squash_velocity * 13.0
		squash_velocity += acceleration * dt
		squash += squash_velocity * dt

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			if _press_ui(event.position):
				return
			if _press(event.position) and holding:
				active_touch = event.index
		elif not event.pressed and active_touch == event.index:
			_release()
	elif event is InputEventScreenDrag:
		if holding and event.index == active_touch:
			_drag(event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and active_touch == -1:
			if _press_ui(event.position):
				return
			if _press(event.position) and holding:
				active_touch = -2
		elif not event.pressed and active_touch == -2:
			_release()
	elif event is InputEventMouseMotion and active_touch == -2:
		_drag(event.position, event.relative)

func _press_ui(position: Vector2) -> bool:
	var size := get_viewport_rect().size
	var action := Screens.hit_action(screen, position, size)
	match action:
		"arcade":
			_start_round()
			return true
		"free":
			_start_free_play()
			return true
		"retry":
			_start_round()
			return true
		"menu":
			_go_menu()
			return true
		"sound":
			sound_enabled = not sound_enabled
			if not sound_enabled:
				sound_player.stop()
				voice_player.stop()
			_save_preferences()
			return true
		"haptics":
			haptics_enabled = not haptics_enabled
			_save_preferences()
			return true
	return screen != Screens.PLAY

func _start_free_play() -> void:
	screen = Screens.PLAY
	arcade_mode = false
	_reset_play()

func _go_menu() -> void:
	screen = Screens.MENU
	arcade_mode = false
	holding = false
	active_touch = -1
	burst_timer = 0.0
	pressure = 0.0
	sound_player.stop()
	voice_player.stop()

func _reset_play() -> void:
	round_finished = false
	remaining_seconds = ROUND_SECONDS
	score = 0
	round_smashes = 0
	max_combo = 0
	latest_record = false
	combo_count = 0
	combo_window = 0.0
	reward_timer = 0.0
	pressure = 0.0
	burst_timer = 0.0
	holding = false
	active_touch = -1
	particles.clear()
	particle_velocity.clear()
	particle_size.clear()
	_next_variant()

func _start_round() -> void:
	screen = Screens.PLAY
	arcade_mode = true
	_reset_play()

func _finish_round() -> void:
	if screen != Screens.PLAY:
		return
	round_finished = true
	holding = false
	active_touch = -1
	screen = Screens.RESULTS
	celebration_time = 0.0
	latest_record = score > best_score
	if latest_record:
		best_score = score
		_save_preferences()
	_play_sound("victory")
	_rumble(35)

func _load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_score = maxi(0, int(cfg.get_value("arcade", "best_score", 0)))
	sound_enabled = bool(cfg.get_value("settings", "sound", true))
	haptics_enabled = bool(cfg.get_value("settings", "haptics", true))

func _save_preferences() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("arcade", "best_score", best_score)
	cfg.set_value("settings", "sound", sound_enabled)
	cfg.set_value("settings", "haptics", haptics_enabled)
	var result := cfg.save(SAVE_PATH)
	if result != OK:
		push_warning("Could not save Poop Smash preferences: %s" % error_string(result))

func _next_variant() -> void:
	# Cycle predictably in free play; randomized selection keeps arcade rounds fresh.
	if arcade_mode:
		current_variant = Variants.ALL[rng.randi_range(0, Variants.ALL.size() - 1)]
	else:
		current_variant = Variants.ALL[variant_sequence % Variants.ALL.size()]
		variant_sequence += 1
	pressure = 0.0
	squash = 0.0
	squash_velocity = 0.0
	drag_stretch = Vector2.ZERO
	squish_offset = Vector2.ZERO
	squish_velocity = Vector2.ZERO

func _center() -> Vector2:
	return get_viewport_rect().size * Vector2(0.5, 0.53)

func _press(position: Vector2) -> bool:
	if screen != Screens.PLAY or burst_timer > 0.0 or not _character_contains(position):
		return false
	holding = true
	finger = position
	finger_start = position
	hold_seconds = 0.0
	pressure = Rules.add_pressure(pressure, Rules.TAP_GAIN * Variants.pressure_multiplier(current_variant))
	touch_position = position
	touch_flash = 1.0
	squash_velocity += 3.8
	expression = ["surprised", "worried", "laugh"][rng.randi_range(0, 2)]
	expression_timer = 0.45
	_play_sound("tap")
	if voice_cooldown <= 0.0 and rng.randf() < 0.26:
		_play_voice()
		voice_cooldown = 0.85
	_rumble(18)
	if pressure >= Variants.burst_threshold(current_variant):
		_burst()
	return true

func _drag(position: Vector2, relative: Vector2) -> void:
	if not holding or burst_timer > 0.0:
		return
	finger = position
	touch_position = position
	touch_flash = 0.6
	drag_stretch = (position - finger_start).limit_length(220.0) * 0.28
	# Use distance rather than a per-event cap: touch sampling rates vary by device.
	pressure = Rules.add_pressure(pressure, relative.length() * Rules.DRAG_GAIN_PER_PIXEL * Variants.pressure_multiplier(current_variant))
	if relative.length() >= 18.0:
		expression = "worried"
		expression_timer = 0.30
		if sound_cooldown <= 0.0:
			_play_sound("drag")
			sound_cooldown = 0.13
	if pressure >= Variants.burst_threshold(current_variant):
		_burst()

func _release() -> void:
	holding = false
	active_touch = -1
	hold_seconds = 0.0
	squash_velocity -= 1.2
	if burst_timer <= 0.0:
		expression = "laugh"
		expression_timer = 0.45

func _burst() -> void:
	if burst_timer > 0.0:
		return
	burst_timer = BURST_LENGTH
	holding = false
	active_touch = -1
	total_smashes += 1
	round_smashes += 1
	if arcade_mode and not round_finished:
		combo_count = ScoreRules.next_combo(combo_count, combo_window)
		combo_window = ScoreRules.COMBO_WINDOW_SECONDS
		max_combo = maxi(max_combo, combo_count)
		last_reward = ScoreRules.points_for_smash(combo_count) * Variants.point_multiplier(current_variant)
		score += last_reward
		reward_timer = 1.3
		expression = "surprised"
	particles.clear()
	particle_velocity.clear()
	particle_size.clear()
	var particle_count := 44 if current_variant == Variants.EXPLOSIVE else 30
	for i in particle_count:
		var angle := TAU * float(i) / float(particle_count) + rng.randf_range(-0.22, 0.22)
		var direction := Vector2.from_angle(angle)
		particles.append(_center() + direction * rng.randf_range(8.0, 35.0))
		particle_velocity.append(direction * rng.randf_range(170.0, 760.0 if current_variant == Variants.EXPLOSIVE else 520.0) + Vector2(0, -110))
		particle_size.append(rng.randf_range(8.0, 26.0))
	_play_sound("burst")
	if voice_cooldown <= 0.0 and rng.randf() < 0.45:
		_play_voice()
		voice_cooldown = 1.0
	_rumble(55)

func _rumble(milliseconds: int) -> void:
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)

func _ellipse(center: Vector2, radii: Vector2, color: Color, distort: bool = false) -> void:
	draw_colored_polygon(_ellipse_polygon(center, radii, distort), color)

func _ellipse_polygon(center: Vector2, radii: Vector2, distort: bool = false) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var local_finger := finger - center
	for i in 48:
		var a := TAU * float(i) / 48.0
		var vertex := Vector2(cos(a) * radii.x, sin(a) * radii.y)
		if distort:
			vertex += drag_stretch * (0.25 + 0.5 * maxf(0.0, -sin(a)))
			if holding:
				var local_delta := local_finger - vertex
				vertex += local_delta.normalized() * 45.0 * squash * Rules.dent_factor(vertex, local_finger, 170.0)
		poly.append(center + vertex)
	return poly

func _body_rects() -> Array[Rect2]:
	var c := _center() + squish_offset
	var dims := Rules.deformation(clampf(squash, 0.0, 1.0)) * BASE_RADIUS
	var bounce := sin(wobble * 2.0) * 4.0 * (1.0 - pressure)
	var shapes: Array[Rect2] = []
	for shape in [Vector3(121, 1.18, 0.83), Vector3(110, 1.15, 0.79), Vector3(42, 0.89, 0.81), Vector3(-55, 0.67, 0.72), Vector3(-122, 0.37, 0.49)]:
		var radii := dims * Vector2(shape.y, shape.z)
		shapes.append(Rect2(c + Vector2(0, shape.x + bounce) - radii, radii * 2.0))
	return shapes

func _character_contains(position: Vector2) -> bool:
	# Share the drawn contours, including rebound and stretch, with touch detection.
	for rect in _body_rects():
		if Geometry2D.is_point_in_polygon(position, _ellipse_polygon(rect.get_center(), rect.size * 0.5, true)):
			return true
	return false

func _draw() -> void:
	var size := get_viewport_rect().size
	_draw_background(size)
	_ellipse(Vector2(size.x * 0.5, size.y * 0.87), Vector2(260, 42), Color("#f2d4b0"))
	var font := ThemeDB.fallback_font
	var palette := Variants.palette(current_variant)
	var body_dark: Color = palette[0]
	var body_light: Color = palette[1]
	var c := _center() + squish_offset
	if burst_timer > 0.0:
		var fade := clampf(burst_timer / BURST_LENGTH, 0.0, 1.0)
		for i in particles.size():
			var tint: Color = body_dark if i % 3 != 0 else body_light
			_ellipse(particles[i], Vector2.ONE * particle_size[i] * (0.3 + 0.7 * fade), tint)
		draw_string(font, c + Vector2(-115, 25), "SPLAT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 62, PINK)
	else:
		var bounce := sin(wobble * 2.0) * 4.0 * (1.0 - pressure)
		var body := _body_rects()
		var body_colors := [body_dark.darkened(0.27), body_dark, body_light, body_dark, body_light]
		for i in body.size():
			_ellipse(body[i].get_center(), body[i].size * 0.5, body_colors[i], true)
		_ellipse(c + Vector2(-38, -113 + bounce), Vector2(17, 31), Color(1, 1, 1, 0.25), true)
		_ellipse(c + Vector2(-113, 56 + bounce), Vector2(19, 35), Color(1, 1, 1, 0.17), true)
		if current_variant == Variants.FROZEN:
			# Distinct icy shine and jagged frost across the crown.
			draw_line(c + Vector2(-82, -110), c + Vector2(-42, -154), Color.WHITE, 7.0)
			draw_line(c + Vector2(-42, -154), c + Vector2(0, -125), Color.WHITE, 7.0)
		elif current_variant == Variants.GOLDEN:
			# Small crown keeps the rare target recognizable without new art assets.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-56, -178), c + Vector2(-34, -218), c + Vector2(-10, -190), c + Vector2(22, -223), c + Vector2(54, -173)]), Color("#ffed80"))
		elif current_variant == Variants.EXPLOSIVE:
			_ellipse(c + Vector2(0, -176), Vector2(13, 24), Color("#ff643b"))
		var face := c + drag_stretch * 0.20 + Vector2(0, bounce)
		var eyes_closed := blink_remaining > 0.0
		if eyes_closed:
			_ellipse(face + Vector2(-62, -23), Vector2(37, 7), INK)
			_ellipse(face + Vector2(62, -23), Vector2(37, 7), INK)
		else:
			_ellipse(face + Vector2(-62, -23), Vector2(38, 48), Color.WHITE)
			_ellipse(face + Vector2(62, -23), Vector2(38, 48), Color.WHITE)
			var look := (finger - face).limit_length(180.0) / 14.0 if holding else Vector2.ZERO
			_ellipse(face + Vector2(-62, -23) + look, Vector2(17, 23), INK)
			_ellipse(face + Vector2(62, -23) + look, Vector2(17, 23), INK)
		_ellipse(face + Vector2(-110, 54), Vector2(26, 15), PINK)
		_ellipse(face + Vector2(110, 54), Vector2(26, 15), PINK)
		if expression == "worried" or expression == "surprised":
			_ellipse(face + Vector2(0, 81), Vector2(27, 39), INK)
		elif expression == "laugh":
			_ellipse(face + Vector2(0, 81), Vector2(52, 28), INK)
			_ellipse(face + Vector2(0, 94), Vector2(29, 9), PINK)
		else:
			draw_arc(face + Vector2(0, 62), 42, 0.16, PI - 0.16, 24, INK, 9.0, true)
		draw_string(font, Vector2(size.x * 0.5 - 135, size.y * 0.78), "TAP  •  HOLD  •  DRAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BROWN)
	if touch_flash > 0.0 and screen == Screens.PLAY:
		draw_arc(touch_position, 28.0 + (1.0 - touch_flash) * 46.0, 0.0, TAU, 32, Color(1, 1, 1, touch_flash * 0.7), 5.0)
	if screen == Screens.MENU:
		_draw_menu(font, size)
	elif screen == Screens.RESULTS:
		_draw_results(font, size)
	else:
		_draw_hud(font, size)
		_draw_footer(font, size)

func _draw_background(size: Vector2) -> void:
	var top := Color("#89dafa") if screen == Screens.MENU else Color("#fff3d3")
	var bottom := Color("#f6a9cf") if screen == Screens.MENU else Color("#f9d5ad")
	for i in 32:
		var t := float(i) / 31.0
		draw_rect(Rect2(0, size.y * t, size.x, size.y / 31.0 + 2.0), top.lerp(bottom, t))
	for i in 13:
		var x := size.x * (0.1 + float((i * 47) % 81) / 100.0)
		var y := size.y * (0.10 + float((i * 29) % 72) / 100.0)
		var r := float(5 + (i * 11) % 22)
		draw_circle(Vector2(x, y + sin(wobble + float(i)) * 8.0), r, Color(1, 1, 1, 0.13))

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
	# Menu logo uses the same original illustration as the launcher icon.
	draw_string(font, Vector2(30, 118), "POOP SMASH!", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 60), 64, Color("#75351d"))
	draw_string(font, Vector2(40, 173), "SQUISH • SPLAT • LAUGH!", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 80), 25, Color("#8c5630"))
	var pulse := 1.0 + 0.022 * sin(wobble * 2.0)
	var icon_size := minf(size.x * 0.53, size.y * 0.33) * pulse
	var icon_rect := Rect2(Vector2((size.x - icon_size) * 0.5, size.y * 0.305 - icon_size * 0.5), Vector2.ONE * icon_size)
	draw_texture_rect(APP_ICON, icon_rect, false)
	draw_string(font, Vector2(40, size.y * 0.60), "Your finger is the weapon!", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 80), 27, INK)
	_button(font, Screens.menu_arcade_rect(size), "60-SECOND CHALLENGE", Color("#f6ac1f"), Color("#62361d"), 31)
	_button(font, Screens.menu_free_rect(size), "FREE PLAY", Color("#4bd73e"), Color("#24431b"), 32)
	draw_string(font, Vector2(32, size.y - 43), "OFFLINE • NO ADS • BEST %d" % best_score, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 64), 23, Color("#673c37"))

func _draw_hud(font: Font, size: Vector2) -> void:
	_round_rect(Rect2(18, 22, size.x - 36, 288), Color("#fff5df"), 28.0)
	draw_string(font, Vector2(42, 83), "POOP SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 47, INK)
	draw_string(font, Vector2(42, 130), "%s • %s" % [Variants.display_name(current_variant), Variants.description(current_variant)], HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 84), 24, BROWN)
	if arcade_mode:
		draw_string(font, Vector2(42, 203), "TIME %02d" % ceili(remaining_seconds), HORIZONTAL_ALIGNMENT_LEFT, -1, 37, INK)
		draw_string(font, Vector2(312, 203), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 344), 32, INK)
		_round_rect(Rect2(42, 223, size.x - 84, 18), Color("#e7d0a8"), 9.0)
		if remaining_seconds > 0.0:
			_round_rect(Rect2(42, 223, (size.x - 84) * remaining_seconds / ROUND_SECONDS, 18), Color("#f5a129"), 9.0)
		if combo_count > 1 and combo_window > 0.0:
			draw_string(font, Vector2(42, 284), "COMBO x%d" % mini(combo_count, ScoreRules.MAX_MULTIPLIER), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#bb3c6a"))
	else:
		draw_string(font, Vector2(42, 208), "FREE PLAY • %d SMASHES" % round_smashes, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 84), 30, INK)
	if reward_timer > 0.0 and arcade_mode:
		draw_string(font, Vector2(42, 355 - 12.0 * (1.0 - reward_timer / 1.3)), "+%d" % last_reward, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#bd396a"))

func _draw_footer(font: Font, size: Vector2) -> void:
	_round_rect(Rect2(9, size.y - 165, size.x - 18, 150), Color("#ffedce"), 25.0)
	_button(font, Screens.play_menu_rect(size), "MENU", Color("#9656cb"), Color.WHITE, 25)
	_button(font, Screens.play_sound_rect(size), "SOUND %s" % ("ON" if sound_enabled else "OFF"), Color("#e29a40"), Color.WHITE, 22)
	_button(font, Screens.play_haptic_rect(size), "VIBE %s" % ("ON" if haptics_enabled else "OFF"), Color("#e29a40"), Color.WHITE, 22)
	draw_string(font, Vector2(35, size.y - 23), "TAP · HOLD · DRAG", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 70), 22, BROWN)

func _draw_results(font: Font, size: Vector2) -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.20, 0.09, 0.32, 0.91))
	for i in 32:
		var x := size.x * float((i * 37 + 17) % 101) / 101.0
		var y := fposmod(float((i * 71) % 100) / 100.0 * size.y + celebration_time * (35.0 + float(i % 5) * 15.0), size.y)
		_ellipse(Vector2(x, y), Vector2(6, 12), Color("#ffc24c") if i % 2 == 0 else Color("#ed82bc"))
	var panel := Rect2(30, size.y * 0.26, size.x - 60, size.y * 0.56)
	_round_rect(panel, Color("#f8e6ff"), 34.0)
	draw_string(font, Vector2(58, panel.position.y + 71), "CHALLENGE COMPLETE!", HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 116), 36, Color("#6a2c9b"))
	var subtitle := "NEW PERSONAL BEST!" if latest_record else "NICE SMASHING!"
	draw_string(font, Vector2(58, panel.position.y + 125), subtitle, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 116), 28, Color("#b7426a"))
	draw_string(font, Vector2(55, panel.position.y + 220), "%d POINTS" % score, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 110), 48, Color("#7432ab"))
	draw_string(font, Vector2(56, panel.position.y + 271), "%d SMASHES • MAX COMBO x%d" % [round_smashes, mini(max_combo, ScoreRules.MAX_MULTIPLIER)], HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 112), 24, BROWN)
	draw_string(font, Vector2(56, panel.position.y + 319), "PERSONAL BEST: %d" % best_score, HORIZONTAL_ALIGNMENT_CENTER, int(size.x - 112), 27, INK)
	_button(font, Screens.results_retry_rect(size), "PLAY AGAIN", Color("#57d538"), Color("#294d21"), 32)
	_button(font, Screens.results_menu_rect(size), "MAIN MENU", Color("#9451d7"), Color.WHITE, 27)

func _play_voice() -> void:
	if not sound_enabled:
		return
	# Deliberately synthetic, randomized cartoon vowel chirps, not real speech.
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	var length := 6000
	var pcm := PackedByteArray()
	pcm.resize(length * 2)
	var base_pitch := rng.randf_range(140.0, 260.0) * Variants.sound_pitch(current_variant)
	var syllables := rng.randi_range(2, 4)
	for i in length:
		var t := float(i) / 22050.0
		var pos := float(i) / float(length)
		var syllable := sin(TAU * float(syllables) * pos)
		var envelope := pow(maxf(0.0, syllable), 1.5) * (1.0 - pos)
		var frequency := base_pitch * (1.0 + 0.35 * sin(TAU * 9.0 * t))
		var tone := sin(TAU * frequency * t + 2.5 * sin(TAU * 35.0 * t))
		pcm.encode_s16(i * 2, int(clampf(tone * envelope * 0.33, -1.0, 1.0) * 32767.0))
	stream.data = pcm
	voice_player.stop()
	voice_player.stream = stream
	voice_player.play()

func _play_sound(kind: String) -> void:
	if not sound_enabled:
		return
	var audio := AudioStreamWAV.new()
	audio.mix_rate = 22050
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.stereo = false
	var duration := 0.14
	if kind == "burst" or kind == "victory":
		duration = 0.40
	elif kind == "drag":
		duration = 0.20
	var samples := int(duration * float(audio.mix_rate))
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	var pitch := rng.randf_range(0.72, 1.36) * Variants.sound_pitch(current_variant)
	var voice := rng.randi_range(0, 3)
	for i in samples:
		var t := float(i) / float(audio.mix_rate)
		var progress := float(i) / float(samples)
		var envelope := pow(1.0 - progress, 1.7)
		var hz := (95.0 + 140.0 * (1.0 - progress)) * pitch
		if kind == "burst":
			hz = (180.0 - 130.0 * progress) * pitch
		elif kind == "victory":
			hz = (280.0 + 460.0 * progress) * pitch
		elif kind == "drag":
			hz = (60.0 + 70.0 * sin(progress * PI)) * pitch
		var phase := TAU * hz * t
		var wave := sin(phase + 4.0 * sin(TAU * 18.0 * t))
		if voice == 1:
			wave += 0.38 * sin(2.0 * phase)
		elif voice == 2:
			wave = sin(phase + 13.0 * sin(TAU * 11.0 * t))
		elif voice == 3:
			wave += 0.5 * sin(phase * 0.5)
		var noise := rng.randf_range(-0.30, 0.30)
		var value := clampf((wave * 0.68 + noise) * envelope * 0.37, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(value * 32767.0))
	audio.data = pcm
	sound_player.stop()
	sound_player.stream = audio
	sound_player.play()
