extends Node2D

const Rules = preload("res://scripts/squish_rules.gd")
const ScoreRules = preload("res://scripts/score_rules.gd")
const Variants = preload("res://scripts/poop_variants.gd")
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
var arcade_mode := false
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

func _ready() -> void:
	rng.randomize()
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	finger = _center()
	_load_preferences()
	_next_variant()
	queue_redraw()

func _process(delta: float) -> void:
	var dt := minf(delta, 0.033)
	if arcade_mode and not round_finished:
		remaining_seconds = maxf(0.0, remaining_seconds - delta)
		if remaining_seconds <= 0.0:
			_finish_round()
	reward_timer = maxf(0.0, reward_timer - delta)
	combo_window = maxf(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo_count = 0
	wobble += dt * 3.0
	sound_cooldown = maxf(0.0, sound_cooldown - dt)
	blink_timer -= dt
	if blink_timer <= 0.0:
		blink_remaining = 0.12
		blink_timer = rng.randf_range(1.4, 3.5)
	blink_remaining = maxf(0.0, blink_remaining - dt)
	expression_timer = maxf(0.0, expression_timer - dt)
	if expression_timer <= 0.0:
		expression = "happy"

	if burst_timer > 0.0:
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
	else:
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
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			if _press_ui(event.position):
				return
			if _press(event.position):
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
			if _press(event.position):
				active_touch = -2
		elif not event.pressed and active_touch == -2:
			_release()
	elif event is InputEventMouseMotion and active_touch == -2:
		_drag(event.position, event.relative)

func _press_ui(position: Vector2) -> bool:
	var size := get_viewport_rect().size
	if arcade_mode and round_finished and position.y >= size.y * 0.40 and position.y <= size.y * 0.61:
		_start_round()
		return true
	if position.y >= size.y - 160.0:
		if position.x < size.x * 0.5:
			sound_enabled = not sound_enabled
			if not sound_enabled:
				sound_player.stop()
		else:
			haptics_enabled = not haptics_enabled
		_save_preferences()
		return true
	if position.y >= 245.0 and position.y <= 325.0:
		if arcade_mode:
			arcade_mode = false
			round_finished = false
			remaining_seconds = ROUND_SECONDS
			combo_count = 0
			combo_window = 0.0
		else:
			_start_round()
		return true
	return false

func _start_round() -> void:
	arcade_mode = true
	round_finished = false
	remaining_seconds = ROUND_SECONDS
	score = 0
	combo_count = 0
	combo_window = 0.0
	pressure = 0.0
	burst_timer = 0.0
	holding = false
	active_touch = -1
	particles.clear()
	particle_velocity.clear()
	particle_size.clear()
	_next_variant()

func _finish_round() -> void:
	round_finished = true
	holding = false
	active_touch = -1
	if score > best_score:
		best_score = score
		_save_preferences()

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
	if burst_timer > 0.0 or (arcade_mode and round_finished) or not Rules.is_inside(position, _center(), BASE_RADIUS * 1.3):
		return false
	holding = true
	finger = position
	finger_start = position
	hold_seconds = 0.0
	pressure = Rules.add_pressure(pressure, Rules.TAP_GAIN * Variants.pressure_multiplier(current_variant))
	squash_velocity += 3.8
	expression = ["surprised", "worried", "laugh"][rng.randi_range(0, 2)]
	expression_timer = 0.45
	_play_sound("tap")
	_rumble(18)
	if pressure >= Variants.burst_threshold(current_variant):
		_burst()
	return true

func _drag(position: Vector2, relative: Vector2) -> void:
	if not holding or burst_timer > 0.0:
		return
	finger = position
	drag_stretch = (position - finger_start).limit_length(220.0) * 0.28
	pressure = Rules.add_pressure(pressure, minf(relative.length() / 550.0, Rules.DRAG_GAIN) * Variants.pressure_multiplier(current_variant))
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
	if arcade_mode and not round_finished:
		combo_count = ScoreRules.next_combo(combo_count, combo_window)
		combo_window = ScoreRules.COMBO_WINDOW_SECONDS
		last_reward = ScoreRules.points_for_smash(combo_count) * Variants.point_multiplier(current_variant)
		score += last_reward
		reward_timer = 1.3
		if score > best_score:
			best_score = score
			_save_preferences()
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
	_rumble(55)

func _rumble(milliseconds: int) -> void:
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)

func _ellipse(center: Vector2, radii: Vector2, color: Color, distort: bool = false) -> void:
	var poly := PackedVector2Array()
	var local_finger := finger - (_center() + squish_offset)
	for i in 48:
		var a := TAU * float(i) / 48.0
		var vertex := Vector2(cos(a) * radii.x, sin(a) * radii.y)
		if distort:
			vertex += drag_stretch * (0.25 + 0.5 * maxf(0.0, -sin(a)))
			if holding:
				var local_delta := local_finger - vertex
				vertex += local_delta.normalized() * 45.0 * squash * Rules.dent_factor(vertex, local_finger, 170.0)
		poly.append(center + vertex)
	draw_colored_polygon(poly, color)

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), CREAM)
	_ellipse(Vector2(size.x * 0.5, size.y * 0.87), Vector2(260, 42), Color("#f2d4b0"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(58, 115), "POOP SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 58, INK)
	draw_string(font, Vector2(58, 175), "Squish it. Smash it. Again!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, BROWN)
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
		var dims := Rules.deformation(clampf(squash, 0.0, 1.0))
		var bounce := sin(wobble * 2.0) * 4.0 * (1.0 - pressure)
		var rx := BASE_RADIUS * dims.x
		var ry := BASE_RADIUS * dims.y
		_ellipse(c + Vector2(0, 110 + bounce), Vector2(rx * 1.15, ry * 0.79), body_dark, true)
		_ellipse(c + Vector2(0, 42 + bounce), Vector2(rx * 0.89, ry * 0.81), body_light, true)
		_ellipse(c + Vector2(0, -55 + bounce), Vector2(rx * 0.67, ry * 0.72), body_dark, true)
		_ellipse(c + Vector2(0, -122 + bounce), Vector2(rx * 0.37, ry * 0.49), body_light, true)
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
	_draw_hud(font, size)
	_draw_footer(font, size)

func _draw_hud(font: Font, size: Vector2) -> void:
	var label_text := "%s — %s" % [Variants.display_name(current_variant), Variants.description(current_variant)]
	draw_string(font, Vector2(58, 350), label_text, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 100.0), 22, INK)
	if reward_timer > 0.0 and arcade_mode:
		draw_string(font, Vector2(58, 455), "+%d!" % last_reward, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#cf672c"))
	if arcade_mode:
		draw_string(font, Vector2(58, 228), "TIME: %02d   SCORE: %d" % [ceili(remaining_seconds), score], HORIZONTAL_ALIGNMENT_LEFT, -1, 31, INK)
		if combo_count > 1 and combo_window > 0.0 and not round_finished:
			draw_string(font, Vector2(58, 390), "COMBO x%d!" % mini(combo_count, ScoreRules.MAX_MULTIPLIER), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, PINK)
		draw_string(font, Vector2(58, 430), "BEST: %d" % best_score, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, BROWN)
	else:
		draw_string(font, Vector2(58, 230), "SMASHES: %d    BEST: %d" % [total_smashes, best_score], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	var control := Rect2(Vector2(48, 249), Vector2(size.x - 96, 76))
	draw_rect(control, BROWN, true)
	var text_value := "FREE PLAY" if arcade_mode else "START 60s CHALLENGE"
	draw_string(font, Vector2(73, 302), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color.WHITE)
	if round_finished:
		draw_rect(Rect2(Vector2(35, size.y * 0.42), Vector2(size.x - 70, 180)), Color("#fff6e8"), true)
		draw_string(font, Vector2(76, size.y * 0.48), "TIME'S UP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, INK)
		draw_string(font, Vector2(76, size.y * 0.53), "SCORE %d   BEST %d" % [score, best_score], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, BROWN)
		draw_string(font, Vector2(76, size.y * 0.56), "Tap here to play again", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, INK)

func _draw_footer(font: Font, size: Vector2) -> void:
	var top := size.y - 156.0
	draw_rect(Rect2(0, top, size.x, 156), Color("#f6dfbe"))
	draw_string(font, Vector2(37, top + 60), "SOUND: %s" % ("ON" if sound_enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	draw_string(font, Vector2(size.x * 0.5 + 16, top + 60), "VIBRATE: %s" % ("ON" if haptics_enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	draw_string(font, Vector2(35, top + 114), "Tap / hold / drag the monster!", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, BROWN)

func _play_sound(kind: String) -> void:
	if not sound_enabled:
		return
	var audio := AudioStreamWAV.new()
	audio.mix_rate = 22050
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.stereo = false
	var duration := 0.14
	if kind == "burst":
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
