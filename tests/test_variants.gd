extends SceneTree

const Variants = preload("res://scripts/poop_variants.gd")

func _initialize() -> void:
	if Variants.ALL.size() != 4:
		_fail("Expected four variants")
		return
	if Variants.pressure_multiplier(Variants.FROZEN) >= Variants.pressure_multiplier(Variants.CLASSIC):
		_fail("Frozen must need more pressure")
		return
	if Variants.burst_threshold(Variants.EXPLOSIVE) >= Variants.burst_threshold(Variants.CLASSIC):
		_fail("Volcano must burst earlier")
		return
	if Variants.point_multiplier(Variants.GOLDEN) != 2:
		_fail("Golden must double points")
		return
	for kind in Variants.ALL:
		if Variants.display_name(kind).is_empty() or Variants.description(kind).is_empty():
			_fail("Missing variant label")
			return
		if Variants.palette(kind).size() != 2 or Variants.sound_pitch(kind) <= 0.0:
			_fail("Invalid palette or pitch")
			return
	print("Poop variants: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
