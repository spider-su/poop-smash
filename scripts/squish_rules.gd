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
