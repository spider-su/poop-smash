extends RefCounted

enum State { IDLE, HAPPY, CURIOUS, SURPRISED, SQUISHED, WORRIED, ANGRY, DIZZY, LAUGHING, PANICKING, BURSTING, RECOVERING }
var state := State.IDLE
var remaining := 0.0
var blink := 0.0
var blink_clock := 2.0
var tap_window := 0.0
var taps := 0
var mouth := 0.25
var brow := 0.0
var look := Vector2.ZERO
var bubble := ""
var bubble_time := 0.0
var bubble_cooldown := 0.0
var age := 0.0
var idle_clock := 4.0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func enter(next: State, duration: float = 0.6) -> void:
	state = next
	remaining = duration

func say(words: Array[String]) -> void:
	if bubble_cooldown > 0.0:
		return
	bubble = words[rng.randi_range(0, words.size() - 1)]
	bubble_time = 1.15
	bubble_cooldown = 2.8

func tap() -> void:
	taps = taps + 1 if tap_window > 0.0 else 1
	tap_window = 0.8
	enter(State.DIZZY if taps >= 4 else State.SURPRISED, 0.65)
	blink_clock = minf(blink_clock, 0.08)
	say(["Hey!", "Oops!", "Again?!"])

func drag(stretch: float) -> void:
	enter(State.SURPRISED if stretch > 130.0 else State.SQUISHED, 0.25)
	if stretch > 130.0:
		say(["Nooo!", "Oh no!"])

func release() -> void:
	enter(State.LAUGHING, 0.75)
	say(["Hehe!", "Pfffft!"])

func respawn() -> void:
	bubble_time = 0.0
	taps = 0
	tap_window = 0.0
	enter(State.RECOVERING, 0.35)

func step(dt: float, holding: bool, pressure: float, finger: Vector2, variant: int) -> void:
	age += dt
	tap_window = maxf(0.0, tap_window - dt)
	bubble_time = maxf(0.0, bubble_time - dt)
	bubble_cooldown = maxf(0.0, bubble_cooldown - dt)
	remaining = maxf(0.0, remaining - dt)
	blink_clock -= dt
	if blink_clock <= 0.0:
		blink_clock = rng.randf_range(1.8, 4.0)
	blink = sin(clampf((0.14 - blink_clock) / 0.14, 0.0, 1.0) * PI)
	if state != State.BURSTING:
		if holding and pressure > 0.88:
			enter(State.PANICKING, 0.2)
			say(["Oh no!", "Nooo!"])
		elif holding and pressure > 0.55:
			enter(State.ANGRY if variant == 3 else State.WORRIED, 0.2)
		elif remaining <= 0.0:
			enter(State.SQUISHED if holding else State.IDLE, 0.2)
	if not holding and state == State.IDLE:
		idle_clock -= dt
		if idle_clock <= 0.0:
			enter(State.CURIOUS if rng.randf() < 0.5 else State.HAPPY, 1.2)
			idle_clock = rng.randf_range(3.0, 6.0)
	var alarm := state in [State.SURPRISED, State.PANICKING, State.BURSTING]
	var target_mouth := 0.95 if alarm else (0.65 if state in [State.LAUGHING, State.DIZZY] else 0.23)
	mouth = lerpf(mouth, target_mouth, 1.0 - exp(-14.0 * dt))
	brow = lerpf(brow, 1.0 if state in [State.WORRIED, State.PANICKING, State.ANGRY] else 0.0, 1.0 - exp(-12.0 * dt))
	var target_look := finger.limit_length(180.0) / 14.0 if holding else Vector2(sin(age * 0.8) * 7.0, sin(age * 0.4) * 3.0)
	look = look.lerp(target_look, 1.0 - exp(-16.0 * dt))
