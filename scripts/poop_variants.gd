class_name PoopVariants
extends RefCounted

# Four distinctive characters; the same input system drives all of them.
const CLASSIC := 0
const FROZEN := 1
const GOLDEN := 2
const EXPLOSIVE := 3
const ALL := [CLASSIC, FROZEN, GOLDEN, EXPLOSIVE]

static func display_name(kind: int) -> String:
	match kind:
		FROZEN: return "FROZEN"
		GOLDEN: return "GOLDEN"
		EXPLOSIVE: return "VOLCANO"
		_: return "CLASSIC"

static func description(kind: int) -> String:
	match kind:
		FROZEN: return "Tough to squash!"
		GOLDEN: return "Double points!"
		EXPLOSIVE: return "Bursts fast!"
		_: return "Soft and squishy!"

static func pressure_multiplier(kind: int) -> float:
	match kind:
		FROZEN: return 0.48
		EXPLOSIVE: return 1.5
		_: return 1.0

static func burst_threshold(kind: int) -> float:
	return 0.70 if kind == EXPLOSIVE else 1.0

static func point_multiplier(kind: int) -> int:
	return 2 if kind == GOLDEN else 1

static func sound_pitch(kind: int) -> float:
	match kind:
		FROZEN: return 1.6
		GOLDEN: return 1.25
		EXPLOSIVE: return 0.72
		_: return 1.0

static func palette(kind: int) -> Array[Color]:
	match kind:
		FROZEN: return [Color("#3d95c7"), Color("#9de9fc")]
		GOLDEN: return [Color("#c58c16"), Color("#ffe268")]
		EXPLOSIVE: return [Color("#9a3730"), Color("#ff7c41")]
		_: return [Color("#8c3f22"), Color("#d9924b")]
