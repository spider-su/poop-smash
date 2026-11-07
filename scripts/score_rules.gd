class_name ScoreRules
extends RefCounted

const COMBO_WINDOW_SECONDS := 5.0
const BASE_POINTS := 100
const MAX_MULTIPLIER := 5

static func next_combo(previous: int, time_remaining: float) -> int:
	return previous + 1 if previous > 0 and time_remaining > 0.0 else 1

static func points_for_smash(combo: int) -> int:
	return BASE_POINTS * mini(maxi(combo, 1), MAX_MULTIPLIER)
