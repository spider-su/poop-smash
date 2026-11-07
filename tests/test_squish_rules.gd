extends SceneTree

const Rules = preload("res://scripts/squish_rules.gd")

func _initialize() -> void:
	if not Rules.is_inside(Vector2(10, 10), Vector2.ZERO, 20.0):
		push_error("Inside touch rejected")
		quit(1)
		return
	if Rules.is_inside(Vector2(40, 0), Vector2.ZERO, 20.0):
		push_error("Outside touch accepted")
		quit(1)
		return
	if not is_equal_approx(Rules.add_pressure(0.9, 0.3), 1.0):
		push_error("Pressure should clamp")
		quit(1)
		return
	if Rules.deformation(1.0).x <= 1.0 or Rules.deformation(1.0).y >= 1.0:
		push_error("Character should compress vertically and expand horizontally")
		quit(1)
		return
	print("Squish rules: PASS")
	quit(0)
