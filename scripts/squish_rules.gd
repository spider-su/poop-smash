class_name SquishRules
extends RefCounted

const MAX_PRESSURE := 1.0
const TAP_GAIN := 0.18
const HOLD_GAIN := 0.42
const DRAG_GAIN := 0.10

static func is_inside(point: Vector2, center: Vector2, radius: float) -> bool:
	return point.distance_to(center) <= radius

static func add_pressure(current: float, amount: float) -> float:
	return clampf(current + amount, 0.0, MAX_PRESSURE)

static func deformation(pressure: float) -> Vector2:
	var amount := clampf(pressure, 0.0, MAX_PRESSURE)
	return Vector2(1.0 + 0.23 * amount, 1.0 - 0.27 * amount)

# Spring integration is frame-rate aware and deterministic for automated tests.
static func spring_step(position: Vector2, velocity: Vector2, target: Vector2, delta: float, stiffness: float = 45.0, damping: float = 12.0) -> Array[Vector2]:
	var acceleration := (target - position) * stiffness - velocity * damping
	var next_velocity := velocity + acceleration * delta
	return [position + next_velocity * delta, next_velocity]

# Imparts a local dent strongest at the finger, falling off smoothly.
static func dent_factor(vertex: Vector2, finger: Vector2, influence_radius: float = 150.0) -> float:
	var normalized := clampf(vertex.distance_to(finger) / influence_radius, 0.0, 1.0)
	return pow(1.0 - normalized, 2.0)
