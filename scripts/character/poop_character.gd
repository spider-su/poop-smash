extends Node2D

signal smashed(kind: int)
signal respawn_requested

const Rules = preload("res://scripts/squish_rules.gd")
const Variants = preload("res://scripts/poop_variants.gd")
const Deformation = preload("res://scripts/character/poop_deformation.gd")
const Expressions = preload("res://scripts/character/poop_expressions.gd")
const Renderer = preload("res://scripts/character/poop_renderer.gd")
const Effects = preload("res://scripts/character/poop_effects.gd")
const Audio = preload("res://scripts/character/poop_audio.gd")

var deformation := Deformation.new()
var expressions := Expressions.new()
var renderer := Renderer.new()
var effects := Effects.new()
var audio := Audio.new()
var variant := Variants.CLASSIC
var pressure := 0.0
var holding := false
var finger := Vector2.ZERO
var finger_start := Vector2.ZERO
var hold_seconds := 0.0
var spent := false
var respawn_sent := false
var haptics_enabled := true
var reduced_effects := false
var idle_voice_clock := 9.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	add_child(audio)
	reset(variant)

func reset(kind: int) -> void:
	variant = kind
	pressure = 0.0
	holding = false
	hold_seconds = 0.0
	finger = Vector2.ZERO
	finger_start = Vector2.ZERO
	spent = false
	respawn_sent = false
	effects.age = Effects.DURATION
	deformation.reset()
	expressions.respawn()
	queue_redraw()

func contains(point: Vector2) -> bool:
	return not spent and Geometry2D.is_point_in_polygon(point, renderer.contour(deformation))

func tap(point: Vector2) -> bool:
	if effects.active() or not contains(point):
		return false
	holding = true
	finger = point
	finger_start = point
	hold_seconds = 0.0
	deformation.tap(point)
	pressure = Rules.add_pressure(pressure, Rules.TAP_GAIN * Variants.pressure_multiplier(variant))
	audio.play("tap", variant)
	if rng.randf() < 0.18:
		audio.play("fart", variant, 0.5)
	var voice: String = ["oh", "ouch", "oops"][rng.randi_range(0, 2)]
	audio.play(voice, variant, 0.68)
	expressions.tap(voice.capitalize() + "!")
	_rumble(15)
	_check_threshold()
	return true

func drag(point: Vector2, relative: Vector2) -> void:
	if not holding or spent:
		return
	finger = point
	deformation.drag(point - finger_start)
	expressions.drag(deformation.pull_target.length())
	pressure = Rules.add_pressure(pressure, relative.length() * Rules.DRAG_GAIN_PER_PIXEL * Variants.pressure_multiplier(variant))
	audio.play("drag", variant, 0.65)
	if deformation.pull_target.length() > 70.0:
		audio.play("ouch", variant, 0.82)
	_check_threshold()

func release() -> void:
	if not holding:
		return
	holding = false
	var stretched := deformation.pull_target.length() > 70.0
	deformation.release()
	expressions.release()
	audio.play("laugh", variant, 0.65)
	if stretched:
		audio.play("ouch", variant, 0.82)
	elif hold_seconds > 0.45:
		audio.play("oh", variant, 0.7)
	hold_seconds = 0.0

func _check_threshold() -> void:
	if pressure >= Variants.burst_threshold(variant):
		smash()

func smash() -> void:
	if spent:
		return
	spent = true
	holding = false
	deformation.release()
	expressions.enter(Expressions.State.BURSTING, Effects.DURATION)
	expressions.say(["Oh no!", "Oops!"])
	effects.reduced = reduced_effects
	effects.start(variant)
	smashed.emit(variant)

func step(dt: float, allow_respawn: bool = true, idle_audio: bool = true) -> void:
	audio.step(dt)
	var ratio := pressure / Variants.burst_threshold(variant)
	expressions.step(dt, holding, ratio, finger, variant)
	if spent:
		if effects.step(dt):
			audio.play("burst", variant)
			_rumble(50)
		if not effects.active() and not respawn_sent and allow_respawn:
			respawn_sent = true
			respawn_requested.emit()
	else:
		if holding:
			hold_seconds += dt
			if ratio > 0.7:
				audio.play("worried", variant, 0.5)
			_check_threshold()
		else:
			pressure = maxf(0.0, pressure - dt * 0.18)
			idle_voice_clock -= dt
			if idle_audio and idle_voice_clock <= 0.0:
				audio.play("idle", variant, 0.3)
				audio.play(["oh", "nice", "oops"][rng.randi_range(0, 2)], variant, 0.62)
				idle_voice_clock = rng.randf_range(8.0, 15.0)
	deformation.step(dt, ratio, 1.35 if variant == Variants.FROZEN else 1.0)
	deformation.tremble = 0.0 if reduced_effects or not holding else maxf(0.0, ratio - 0.86) * 16.0
	deformation.inflation = 1.0 + effects.age * 0.7 if effects.anticipating() else 1.0
	queue_redraw()

func _rumble(milliseconds: int) -> void:
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)

func _draw() -> void:
	if not spent or effects.anticipating():
		renderer.draw_on(self, deformation, expressions, variant, pressure / Variants.burst_threshold(variant), reduced_effects)
	else:
		draw_set_transform(effects.shake())
		effects.draw_on(self)
		draw_set_transform(Vector2.ZERO)
