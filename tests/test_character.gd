extends SceneTree

const Character = preload("res://scripts/character/poop_character.gd")
const Deformation = preload("res://scripts/character/poop_deformation.gd")
const Expressions = preload("res://scripts/character/poop_expressions.gd")
const Effects = preload("res://scripts/character/poop_effects.gd")
const Renderer = preload("res://scripts/character/poop_renderer.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var renderer := Renderer.new()
	print("Character mesh vertices: ", renderer.mesh_points.size())
	_check(renderer.mesh_points.size() < 750, "Character mesh exceeds vertex budget")
	_check(renderer.mesh_uv.size() == renderer.mesh_points.size(), "Material UVs missing")
	for uv in renderer.mesh_uv:
		_check(uv.is_finite() and uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1, "Material UV outside texture")
	for angle in 8:
		var extreme := Deformation.new()
		extreme.reset()
		extreme.tap(Vector2.from_angle(TAU * angle / 8.0) * 170.0)
		extreme.drag(Vector2.from_angle(TAU * angle / 8.0) * 155.0)
		extreme.step(0.5, 0.9)
		var contour := renderer.contour(extreme)
		var vertices := renderer.deformed_vertices(extreme)
		for triangle in range(0, renderer.mesh_indices.size(), 3):
			var center := Vector2.ZERO
			for j in 3:
				center += vertices[renderer.mesh_indices[triangle + j]] / 3.0
			_check(Geometry2D.is_point_in_polygon(center, contour), "Mesh triangle escaped visible contour at maximum stretch: angle %d, triangle %d, center %s" % [angle, triangle, center])
	for fps in [20, 30, 60, 120]:
		var d := Deformation.new()
		d.reset()
		d.tap(Vector2(175, 65))
		d.drag(Vector2(10000, -1000))
		_check(d.pull_target.length() <= Deformation.MAX_STRETCH + 0.01, "Stretch limit exceeded")
		for i in fps * 2:
			d.step(1.0 / fps, 0.6)
		_check(d.pull.is_finite() and absf(d.dent) < 80.0, "Spring became unstable")
		_check(Geometry2D.triangulate_polygon(renderer.contour(d)).size() > 0, "Stretched contour cannot be triangulated")
		var near := d.warp(Vector2(170, 65)) - Vector2(170, 65)
		var far := d.warp(Vector2(-190, -120)) - Vector2(-190, -120)
		_check(near.length() > far.length() * 2.0, "Deformation is not localized")
		d.release()
		for i in fps * 6:
			d.step(1.0 / fps, 0.0)
		_check(d.pull.length() < 0.02 and absf(d.dent) < 0.02 and d.squeeze < 0.001, "Body failed to recover at %d FPS" % fps)
		_check(Geometry2D.triangulate_polygon(renderer.contour(d)).size() > 0, "Recovered silhouette has gaps")

	var e := Expressions.new()
	for i in 4:
		e.tap()
	_check(e.state == Expressions.State.DIZZY, "Repeated taps should cause dizziness")
	e.release()
	_check(e.state == Expressions.State.DIZZY, "Finger release hid repeated-tap dizziness")
	e.step(0.1, true, 0.95, Vector2(100, 0), 0)
	_check(e.state == Expressions.State.PANICKING, "High pressure should cause panic")
	var bubble := e.bubble
	e.say(["replacement"])
	_check(e.bubble == bubble, "Bubble cooldown was ignored")
	e.release()
	_check(e.state == Expressions.State.LAUGHING, "Release should cause relieved laughter")
	e.respawn()
	_check(e.state == Expressions.State.RECOVERING, "Respawn should recover")
	e.step(1.0, false, 0.0, Vector2.ZERO, 0)
	_check(e.state == Expressions.State.IDLE, "Recovery did not return to idle")

	for kind in [0, 1, 2, 3]:
		var c := Character.new()
		root.add_child(c)
		c.audio.enabled = false
		c.haptics_enabled = false
		c.reset(kind)
		c.deformation.entrance = 1.0
		c.pressure = c.Variants.burst_threshold(kind) - 0.01
		var smashes := [0]
		c.smashed.connect(func(_kind): smashes[0] += 1)
		c.tap(Vector2.ZERO)
		_check(c.spent and smashes[0] == 1 and c.effects.anticipating(), "Variant threshold/anticipation failed")
		c.smash()
		_check(smashes[0] == 1, "Burst scored twice")
		for i in 20:
			c.step(1.0 / 120.0, false, false)
		_check(c.effects.positions.size() == (44 if kind == 3 else 30), "Variant particles missing")
		for i in 120:
			c.step(1.0 / 120.0, false, false)
		_check(not c.effects.active(), "Explosion did not finish")
		c.reset(kind)
		_check(not c.spent and c.pressure == 0.0 and not c.holding, "Respawn did not reset character")
		c.free()
	var reduced := Effects.new()
	reduced.reduced = true
	reduced.start(3)
	reduced.step(0.1)
	_check(reduced.positions.size() == 16 and reduced.shake() == Vector2.ZERO, "Reduced effects ignored")
	if failures == 0:
		print("Character deformation, expressions and effects: PASS")
	quit(0 if failures == 0 else 1)
