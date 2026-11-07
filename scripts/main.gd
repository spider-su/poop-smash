extends Node2D

const Rules = preload("res://scripts/squish_rules.gd")
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
	queue_redraw()

func _process(delta: float) -> void:
	var dt := minf(delta, 0.033)
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
	else:
		if holding:
			hold_seconds += dt
			pressure = Rules.add_pressure(pressure, Rules.HOLD_GAIN * dt)
			if pressure > 0.72:
				expression = "worried"
				expression_timer = 0.15
			if pressure >= 1.0:
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
			if _press(event.position):
				active_touch = event.index
		elif not event.pressed and active_touch == event.index:
			_release()
	elif event is InputEventScreenDrag:
		if holding and event.index == active_touch:
			_drag(event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and active_touch == -1:
			if _press(event.position):
				active_touch = -2
		elif not event.pressed and active_touch == -2:
			_release()
	elif event is InputEventMouseMotion and active_touch == -2:
		_drag(event.position, event.relative)

func _center() -> Vector2:
	return get_viewport_rect().size * Vector2(0.5, 0.53)

func _press(position: Vector2) -> bool:
	if burst_timer > 0.0 or not Rules.is_inside(position, _center(), BASE_RADIUS * 1.3):
		return false
	holding = true
	finger = position
	finger_start = position
	hold_seconds = 0.0
	pressure = Rules.add_pressure(pressure, Rules.TAP_GAIN)
	squash_velocity += 3.8
	expression = ["surprised", "worried", "laugh"][rng.randi_range(0, 2)]
	expression_timer = 0.45
	_play_sound("tap")
	_rumble(18)
	if pressure >= 1.0:
		_burst()
	return true

func _drag(position: Vector2, relative: Vector2) -> void:
	if not holding or burst_timer > 0.0:
		return
	finger = position
	drag_stretch = (position - finger_start).limit_length(220.0) * 0.28
	pressure = Rules.add_pressure(pressure, minf(relative.length() / 550.0, Rules.DRAG_GAIN))
	if relative.length() >= 18.0:
		expression = "worried"
		expression_timer = 0.30
		if sound_cooldown <= 0.0:
			_play_sound("drag")
			sound_cooldown = 0.13
	if pressure >= 1.0:
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
	expression = "surprised"
	particles.clear()
	particle_velocity.clear()
	particle_size.clear()
	for i in 30:
		var angle := TAU * float(i) / 30.0 + rng.randf_range(-0.22, 0.22)
		var direction := Vector2.from_angle(angle)
		particles.append(_center() + direction * rng.randf_range(8.0, 35.0))
		particle_velocity.append(direction * rng.randf_range(170.0, 520.0) + Vector2(0, -110))
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
	draw_string(font, Vector2(58, 239), "SMASHES: %d" % total_smashes, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, INK)
	var c := _center() + squish_offset
	if burst_timer > 0.0:
		var fade := clampf(burst_timer / BURST_LENGTH, 0.0, 1.0)
		for i in particles.size():
			var tint := BROWN if i % 3 != 0 else LIGHT_BROWN
			_ellipse(particles[i], Vector2.ONE * particle_size[i] * (0.3 + 0.7 * fade), tint)
		draw_string(font, c + Vector2(-115, 25), "SPLAT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 62, PINK)
	else:
		var dims := Rules.deformation(clampf(squash, 0.0, 1.0))
		var bounce := sin(wobble * 2.0) * 4.0 * (1.0 - pressure)
		var rx := BASE_RADIUS * dims.x
		var ry := BASE_RADIUS * dims.y
		_ellipse(c + Vector2(0, 110 + bounce), Vector2(rx * 1.15, ry * 0.79), BROWN, true)
		_ellipse(c + Vector2(0, 42 + bounce), Vector2(rx * 0.89, ry * 0.81), LIGHT_BROWN, true)
		_ellipse(c + Vector2(0, -55 + bounce), Vector2(rx * 0.67, ry * 0.72), BROWN, true)
		_ellipse(c + Vector2(0, -122 + bounce), Vector2(rx * 0.37, ry * 0.49), LIGHT_BROWN, true)
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
	draw_string(font, Vector2(58, size.y - 84), "Every burst brings a fresh little monster!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)

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
	var pitch := rng.randf_range(0.72, 1.36)
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
