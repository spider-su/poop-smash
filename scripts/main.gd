extends Node2D

const Rules = preload("res://scripts/squish_rules.gd")
const BASE_RADIUS := 176.0
const BROWN := Color("#865029")
const LIGHT_BROWN := Color("#b6773c")
const PINK := Color("#fa96a3")
const INK := Color("#423025")

var pressure := 0.0
var dragging := false
var holding := false
var hold_seconds := 0.0
var combo := 0
var total_smashes := 0
var wobble := 0.0
var burst_timer := 0.0
var sparkle: Array[Vector2] = []
var rng := RandomNumberGenerator.new()
var sound_player: AudioStreamPlayer

func _ready() -> void:
	rng.randomize()
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	queue_redraw()

func _process(delta: float) -> void:
	wobble += delta * 4.0
	if holding and burst_timer <= 0.0:
		hold_seconds += delta
		pressure = Rules.add_pressure(pressure, Rules.HOLD_GAIN * delta)
		if pressure >= 1.0:
			_burst()
	elif burst_timer <= 0.0:
		pressure = maxf(0.0, pressure - delta * 0.10)
	if burst_timer > 0.0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			pressure = 0.0
			sparkle.clear()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif event is InputEventScreenDrag:
		_drag(event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif event is InputEventMouseMotion and holding:
		_drag(event.position, event.relative)

func _center() -> Vector2:
	return get_viewport_rect().size * Vector2(0.5, 0.53)

func _press(position: Vector2) -> void:
	if burst_timer > 0.0 or not Rules.is_inside(position, _center(), BASE_RADIUS * 1.25):
		return
	holding = true
	dragging = false
	hold_seconds = 0.0
	pressure = Rules.add_pressure(pressure, Rules.TAP_GAIN)
	combo += 1
	_play_squish()
	if pressure >= 1.0:
		_burst()

func _drag(position: Vector2, relative: Vector2) -> void:
	if not holding or burst_timer > 0.0:
		return
	dragging = true
	pressure = Rules.add_pressure(pressure, minf(relative.length() / 550.0, Rules.DRAG_GAIN))
	if pressure >= 1.0:
		_burst()

func _release() -> void:
	holding = false
	dragging = false
	hold_seconds = 0.0

func _burst() -> void:
	if burst_timer > 0.0:
		return
	burst_timer = 0.75
	holding = false
	total_smashes += 1
	combo = 0
	sparkle.clear()
	for i in 24:
		sparkle.append(Vector2.from_angle(TAU * float(i) / 24.0 + rng.randf_range(-0.15, 0.15)) * rng.randf_range(60.0, 250.0))
	_play_squish(true)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var polygon := PackedVector2Array()
	for i in 48:
		var a := TAU * float(i) / 48.0
		polygon.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(polygon, color)

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#fff0d6"))
	_ellipse(Vector2(size.x * 0.5, size.y * 0.87), Vector2(265, 48), Color("#f2d4b0"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(58, 115), "POOP SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 58, INK)
	draw_string(font, Vector2(58, 175), "Squish it. Smash it. Again!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, BROWN)
	draw_string(font, Vector2(58, 237), "SMASHES: %d" % total_smashes, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, INK)
	var center := _center()
	if burst_timer > 0.0:
		var phase := 1.0 - burst_timer / 0.75
		for offset in sparkle:
			_ellipse(center + offset * (0.3 + phase * 1.6), Vector2(20, 15) * (1.0 - phase * 0.7), BROWN)
		draw_string(font, center + Vector2(-120, 25), "SPLAT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 62, PINK)
	else:
		var scale_factor := Rules.deformation(pressure)
		var bounce := sin(wobble * 2.0) * 5.0 * (1.0 - pressure)
		var rx := BASE_RADIUS * scale_factor.x
		var ry := BASE_RADIUS * scale_factor.y
		_ellipse(center + Vector2(0, 110 + bounce), Vector2(rx * 1.15, ry * 0.79), BROWN)
		_ellipse(center + Vector2(0, 42 + bounce), Vector2(rx * 0.89, ry * 0.81), LIGHT_BROWN)
		_ellipse(center + Vector2(0, -55 + bounce), Vector2(rx * 0.67, ry * 0.72), BROWN)
		_ellipse(center + Vector2(0, -122 + bounce), Vector2(rx * 0.37, ry * 0.49), LIGHT_BROWN)
		_ellipse(center + Vector2(-62, -23 + bounce), Vector2(38, 48), Color.WHITE)
		_ellipse(center + Vector2(62, -23 + bounce), Vector2(38, 48), Color.WHITE)
		_ellipse(center + Vector2(-51, -15 + bounce), Vector2(17, 23), INK)
		_ellipse(center + Vector2(73, -15 + bounce), Vector2(17, 23), INK)
		_ellipse(center + Vector2(-110, 54 + bounce), Vector2(26, 15), PINK)
		_ellipse(center + Vector2(110, 54 + bounce), Vector2(26, 15), PINK)
		if pressure > 0.66:
			_ellipse(center + Vector2(0, 81 + bounce), Vector2(30, 42), INK)
		else:
			draw_arc(center + Vector2(0, 62 + bounce), 42, 0.16, PI - 0.16, 24, INK, 9.0, true)
		draw_string(font, Vector2(size.x * 0.5 - 125, size.y * 0.78), "TAP  •  HOLD  •  DRAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BROWN)
	draw_string(font, Vector2(58, size.y - 84), "Every burst brings a fresh little monster!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)

func _play_squish(big: bool = false) -> void:
	var audio := AudioStreamWAV.new()
	audio.mix_rate = 22050
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.stereo = false
	var samples := 6500 if big else 3100
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	var seed_pitch := rng.randf_range(0.8, 1.3)
	for i in samples:
		var t := float(i) / 22050.0
		var env := pow(1.0 - float(i) / float(samples), 2.0)
		var frequency := (75.0 + (1.0 - t) * (115.0 if big else 65.0)) * seed_pitch
		var wave := sin(TAU * frequency * t + 7.0 * sin(TAU * 14.0 * t))
		var noise := rng.randf_range(-0.35, 0.35)
		var value := clampf((wave * 0.75 + noise) * env * 0.40, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(value * 32767.0))
	audio.data = pcm
	sound_player.stop()
	sound_player.stream = audio
	sound_player.play()
