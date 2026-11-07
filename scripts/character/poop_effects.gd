extends RefCounted

const Variants = preload("res://scripts/poop_variants.gd")
const FACE_FONT = preload("res://assets/fonts/Fredoka-Bold.ttf")
const ANTICIPATION := 0.085
const DURATION := 0.82
var age := DURATION
var variant := 0
var reduced := false
var word := "SPLAT!"
var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var sizes := PackedFloat32Array()
var landed := PackedByteArray()
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func start(kind: int) -> void:
	variant = kind
	age = 0.0
	word = ["SPLAT!", "PLOP!", "POOF!", "PFFFFT!"][rng.randi_range(0, 3)]
	positions.clear()
	velocities.clear()
	sizes.clear()
	landed.clear()

func active() -> bool:
	return age < DURATION

func anticipating() -> bool:
	return age < ANTICIPATION

func _emit() -> void:
	var count := 44 if variant == Variants.EXPLOSIVE else 30
	if reduced:
		count = 16
	for i in count:
		var direction := Vector2.from_angle(TAU * float(i) / count + rng.randf_range(-0.12, 0.12))
		positions.append(direction * 25.0)
		velocities.append(direction * rng.randf_range(260, 780 if variant == Variants.EXPLOSIVE else 630) + Vector2(0, -100))
		sizes.append(rng.randf_range(6.0, 24.0))
		landed.append(0)

func step(dt: float) -> bool:
	if not active():
		return false
	var previous := age
	age = minf(DURATION, age + dt)
	var just_exploded := previous < ANTICIPATION and age >= ANTICIPATION
	if just_exploded:
		_emit()
	for i in positions.size():
		velocities[i].y += 1050.0 * dt
		positions[i] += velocities[i] * dt
		if positions[i].y > 255.0 - sizes[i] and velocities[i].y > 0.0:
			positions[i].y = 255.0 - sizes[i]
			velocities[i] = Vector2(velocities[i].x * 0.66, -velocities[i].y * 0.30)
			landed[i] = 1
	return just_exploded

func shake() -> Vector2:
	if reduced or age < ANTICIPATION or age > 0.25:
		return Vector2.ZERO
	return Vector2(sin(age * 155.0), cos(age * 137.0)) * (0.25 - age) * 20.0

func draw_on(canvas: CanvasItem) -> void:
	if not active() or anticipating():
		return
	var phase := clampf((age - ANTICIPATION) / (DURATION - ANTICIPATION), 0.0, 1.0)
	var palette := Variants.palette(variant)
	if not reduced and phase < 0.4:
		canvas.draw_arc(Vector2.ZERO, 45.0 + phase * 350.0, 0, TAU, 48, Color(1, 0.96, 0.8, (1.0 - phase / 0.4) * 0.5), 9.0, true)
	for i in positions.size():
		var color: Color = palette[i % 2]
		var radius := sizes[i] * (1.0 - phase * 0.5)
		var speed := velocities[i].length()
		var stretch := 1.0 + minf(speed / 850.0, 0.55)
		if landed[i] == 1:
			stretch = 0.65
		var direction := velocities[i].normalized()
		var across := direction.orthogonal()
		var poly := PackedVector2Array()
		var steps := 4 if variant == Variants.FROZEN else 12
		for j in steps:
			var a := TAU * float(j) / steps
			poly.append(positions[i] + (direction * cos(a) * stretch + across * sin(a) / stretch) * radius)
		canvas.draw_colored_polygon(poly, color)
		if i % 3 == 0:
			canvas.draw_circle(positions[i] + Vector2(-radius * 0.2, -radius * 0.3), radius * 0.22, Color(1, 1, 1, 0.5))
		if variant == Variants.GOLDEN and i % 3 == 0:
			canvas.draw_line(positions[i] - Vector2(radius, 0), positions[i] + Vector2(radius, 0), Color("#fff7b4"), 2.0, true)
		if variant == Variants.EXPLOSIVE and i % 4 == 0:
			canvas.draw_circle(positions[i] - velocities[i] * 0.016, radius * 0.6, Color(1, 0.7, 0.1, 0.5))
	var bounce := 1.0 + 0.16 * sin(minf(phase * 4.0, 1.0) * PI)
	var font := FACE_FONT
	canvas.draw_string_outline(font, Vector2(-180, 16), word, HORIZONTAL_ALIGNMENT_CENTER, 360, int(54 * bounce), 9, Color("#69372e"))
	canvas.draw_string(font, Vector2(-180, 16), word, HORIZONTAL_ALIGNMENT_CENTER, 360, int(54 * bounce), Color("#fff4d6"))
