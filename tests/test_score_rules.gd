extends SceneTree

const ScoreRules = preload("res://scripts/score_rules.gd")

func _initialize() -> void:
	if ScoreRules.next_combo(0, 0.0) != 1:
		_fail("First smash must start at combo 1")
		return
	if ScoreRules.next_combo(2, 3.0) != 3:
		_fail("Combo must continue inside window")
		return
	if ScoreRules.next_combo(2, 0.0) != 1:
		_fail("Expired combo must reset")
		return
	if ScoreRules.points_for_smash(1) != 100 or ScoreRules.points_for_smash(3) != 300:
		_fail("Incorrect progressive scores")
		return
	if ScoreRules.points_for_smash(12) != 500:
		_fail("Combo multiplier must be capped")
		return
	print("Arcade scoring: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
