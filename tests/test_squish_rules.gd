extends SceneTree

const Rules = preload("res://scripts/squish_rules.gd")

func _initialize() -> void:
	if not Rules.is_inside(Vector2(10, 10), Vector2.ZERO, 20.0):
		_fail("Inside touch rejected")
		return
	if Rules.is_inside(Vector2(40, 0), Vector2.ZERO, 20.0):
		_fail("Outside touch accepted")
		return
	if not is_equal_approx(Rules.add_pressure(0.9, 0.3), 1.0):
		_fail("Pressure should clamp")
		return
	if Rules.deformation(1.0).x <= 1.0 or Rules.deformation(1.0).y >= 1.0:
		_fail("Character should compress vertically and expand horizontally")
		return
	var result := Rules.spring_step(Vector2.ZERO, Vector2.ZERO, Vector2(100, 0), 0.016)
	if result[0].x <= 0.0 or result[1].x <= 0.0:
		_fail("Spring must move toward touch target")
		return
	if Rules.dent_factor(Vector2.ZERO, Vector2.ZERO) < 0.99:
		_fail("Touch dent must peak under finger")
		return
	if Rules.dent_factor(Vector2(200, 0), Vector2.ZERO) > 0.01:
		_fail("Touch dent must fade away from finger")
		return
	print("Squish rules: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
