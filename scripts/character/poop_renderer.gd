extends RefCounted

const Variants = preload("res://scripts/poop_variants.gd")
const Expressions = preload("res://scripts/character/poop_expressions.gd")
const BODY_TEXTURE = preload("res://assets/character/gloss-material.png")
const UVProfile = preload("res://scripts/character/body_uv_profile.gd")
const FACE_FONT = preload("res://assets/fonts/Fredoka-Bold.ttf")
const INK := Color("#39160f")
const CONTROL := [
	Vector2(-155, 236), Vector2(-208, 209), Vector2(-225, 167),
	Vector2(-213, 119), Vector2(-169, 94), Vector2(-181, 51),
	Vector2(-157, 5), Vector2(-113, -14), Vector2(-124, -63),
	Vector2(-97, -110), Vector2(-56, -131), Vector2(-65, -163),
	Vector2(-38, -191), Vector2(-11, -197), Vector2(22, -233),
	Vector2(44, -188), Vector2(72, -170), Vector2(90, -142),
	Vector2(88, -109), Vector2(128, -94), Vector2(149, -58),
	Vector2(146, -12), Vector2(182, 12), Vector2(199, 51),
	Vector2(187, 91), Vector2(222, 122), Vector2(236, 168),
	Vector2(218, 210), Vector2(170, 235), Vector2(90, 249),
	Vector2(0, 255)
]
var face_indices := PackedInt32Array()
var rest := PackedVector2Array()
var mesh := ArrayMesh.new()
var mesh_points := PackedVector2Array()
var mesh_colors := PackedColorArray()
var mesh_indices := PackedInt32Array()
var mesh_variant := -1
var mesh_uv := PackedVector2Array()
var mesh_sources: Array[PackedInt32Array] = []

func _init() -> void:
	for i in 32:
		var next := (i + 1) % 32
		face_indices.append_array(PackedInt32Array([0, 1 + i, 1 + next, 1 + i, 33 + i, 33 + next, 1 + i, 33 + next, 1 + next]))
	# One closed, continuous silhouette. Interior swirl lines never split the body.
	for i in CONTROL.size():
		for j in 4:
			rest.append(_catmull(CONTROL[posmod(i - 1, CONTROL.size())], CONTROL[i], CONTROL[(i + 1) % CONTROL.size()], CONTROL[(i + 2) % CONTROL.size()], float(j) / 4.0))
	# Refine long triangle edges so material UVs bend smoothly across the swirl.
	mesh_points = rest.duplicate()
	var triangles := Geometry2D.triangulate_polygon(rest)
	var midpoints := {}
	for i in range(0, triangles.size(), 3):
		_refine_triangle(triangles[i], triangles[i + 1], triangles[i + 2], midpoints)
	for point in mesh_points:
		mesh_uv.append(_material_uv(point))

func _refine_triangle(a: int, b: int, c: int, midpoints: Dictionary) -> void:
	var corners := [a, b, c]
	var longest := 0
	var distance := 0.0
	for edge in 3:
		var length_squared := mesh_points[corners[edge]].distance_squared_to(mesh_points[corners[(edge + 1) % 3]])
		if length_squared > distance:
			distance = length_squared
			longest = edge
	if distance <= 40.0 * 40.0:
		mesh_indices.append_array(PackedInt32Array([a, b, c]))
		return
	var first: int = corners[longest]
	var second: int = corners[(longest + 1) % 3]
	var opposite: int = corners[(longest + 2) % 3]
	var key := Vector2i(mini(first, second), maxi(first, second))
	if not midpoints.has(key):
		midpoints[key] = mesh_points.size()
		mesh_points.append((mesh_points[first] + mesh_points[second]) * 0.5)
		mesh_sources.append(PackedInt32Array([first, second]))
	var middle: int = midpoints[key]
	_refine_triangle(first, middle, opposite, midpoints)
	_refine_triangle(middle, second, opposite, midpoints)

func _material_uv(point: Vector2) -> Vector2:
	var top := rest[0].y
	var bottom := top
	for p in rest:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	var ratio := clampf((point.y - top) / (bottom - top), 0.0, 1.0)
	var y := clampf(point.y, top + 0.01, bottom - 0.01)
	var left := INF
	var right := -INF
	for i in rest.size():
		var a := rest[i]
		var b := rest[(i + 1) % rest.size()]
		if y >= minf(a.y, b.y) and y <= maxf(a.y, b.y) and absf(a.y - b.y) > 0.0001:
			var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
			left = minf(left, x)
			right = maxf(right, x)
	var across := clampf((point.x - left) / maxf(right - left, 0.01), 0.0, 1.0)
	var row := ratio * (UVProfile.ROWS.size() - 1)
	var low := mini(int(row), UVProfile.ROWS.size() - 2)
	var span: Vector2 = UVProfile.ROWS[low].lerp(UVProfile.ROWS[low + 1], row - low)
	return Vector2(lerpf(span.x, span.y, across), lerpf(UVProfile.TOP, UVProfile.BOTTOM, ratio))

static func _catmull(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)

func contour(deformation) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in rest.size():
		result.append(deformation.warp(rest[i]))
	return result

func deformed_vertices(d) -> PackedVector2Array:
	var vertices := contour(d)
	for sources in mesh_sources:
		var point := Vector2.ZERO
		for source in sources:
			point += vertices[source] / float(sources.size())
		vertices.append(point)
	return vertices

func _body_mesh(canvas: CanvasItem, d, kind: int, dark: Color, light: Color) -> void:
	if mesh_variant != kind:
		mesh_variant = kind
		# Neutral baked illumination supplies smooth depth without a shader.
		mesh_colors.resize(mesh_points.size())
		mesh_colors.fill(dark.lerp(light, 0.94).lightened(0.12))
	var warped := deformed_vertices(d)
	var vertices := PackedVector3Array()
	vertices.resize(mesh_points.size())
	for i in mesh_points.size():
		var p: Vector2 = warped[i]
		vertices[i] = Vector3(p.x, p.y, 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = mesh_colors
	arrays[Mesh.ARRAY_INDEX] = mesh_indices
	arrays[Mesh.ARRAY_TEX_UV] = mesh_uv
	# Topology, UVs and tint are cached; only positions move during play.
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	canvas.draw_mesh(mesh, BODY_TEXTURE, Transform2D.IDENTITY, Color(1.25, 1.25, 1.25, 1.0))

func _ellipse(canvas: CanvasItem, deformation, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(deformation.warp(center + Vector2(cos(angle), sin(angle)) * radii))
	canvas.draw_colored_polygon(points, color)

# A small triangle fan keeps the lighting continuous as each feature deforms.
func _shaded_ellipse(canvas: CanvasItem, d, center: Vector2, radii: Vector2, lit: Color, rim: Color) -> void:
	var points := PackedVector2Array([d.warp(center + radii * Vector2(-0.22, -0.28))])
	var colors := PackedColorArray([lit])
	for ring in 2:
		var radius := 0.58 if ring == 0 else 1.0
		var offset := radii * Vector2(-0.22, -0.28) * (1.0 - radius)
		for i in 32:
			var angle := TAU * float(i) / 32.0
			points.append(d.warp(center + offset + Vector2(cos(angle), sin(angle)) * radii * radius))
			var shade := 0.18 if ring == 0 else 0.72 + 0.28 * (sin(angle) + 1.0) * 0.5
			colors.append(lit.lerp(rim, shade))
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), face_indices, points, colors)

func _path(canvas: CanvasItem, deformation, controls: Array[Vector2], color: Color, width: float) -> void:
	var line := PackedVector2Array()
	for i in controls.size() - 1:
		for j in 8:
			line.append(deformation.warp(_catmull(controls[maxi(i - 1, 0)], controls[i], controls[i + 1], controls[mini(i + 2, controls.size() - 1)], float(j) / 8.0)))
	line.append(deformation.warp(controls[-1]))
	canvas.draw_polyline(line, color, width, true)

func draw_on(canvas: CanvasItem, deformation, expressions, kind: int, ratio: float, reduced: bool, celebrating: bool = false) -> void:
	var palette := Variants.palette(kind)
	var dark: Color = palette[0]
	var light: Color = palette[1]
	var outline := contour(deformation)
	canvas.draw_colored_polygon(outline, dark.lerp(light, 0.65))
	_body_mesh(canvas, deformation, kind, dark, light)
	var closed := outline.duplicate()
	closed.append(outline[0])
	canvas.draw_polyline(closed, dark.darkened(0.32), 4.0, true)
	for glint in [Vector2(-31, -153), Vector2(-91, -52)]:
		for ring in range(5, 0, -1):
			_ellipse(canvas, deformation, glint, Vector2(13, 25) * (0.6 + float(ring) * 0.15), Color(1, 1, 0.95, 0.055))
		_ellipse(canvas, deformation, glint + Vector2(-2, -5), Vector2(6, 13), Color(1, 1, 0.97, 0.42))
	_path(canvas, deformation, [Vector2(-185, 162), Vector2(-169, 140), Vector2(-141, 134)], Color(1, 1, 1, 0.36), 9.0)
	_ellipse(canvas, deformation, Vector2(140, 193), Vector2(43, 9), Color(1, 1, 1, 0.12))
	_variant(canvas, deformation, expressions.age, kind, ratio, reduced)
	_face(canvas, deformation, expressions, kind)
	if celebrating:
		_crown(canvas, deformation)
		for side in [-1, 1]:
			var eye := Vector2(side * 65, -16)
			_ellipse(canvas, deformation, eye, Vector2(58, 41), Color("#28152e"))
			_ellipse(canvas, deformation, eye + Vector2(0, -3), Vector2(50, 32), Color("#4b325b"))
			_path(canvas, deformation, [eye + Vector2(-25, -17), eye + Vector2(1, -25), eye + Vector2(26, -19)], Color("#c1a6d2"), 7)
		_path(canvas, deformation, [Vector2(-15, -22), Vector2(0, -27), Vector2(15, -22)], Color("#29152b"), 9)
	_bubble(canvas, expressions)

func _face(canvas: CanvasItem, d, e, kind: int) -> void:
	var alarm: bool = e.state in [Expressions.State.PANICKING, Expressions.State.BURSTING, Expressions.State.SURPRISED]
	for side in [-1, 1]:
		var eye := Vector2(side * 65, -16)
		var asymmetric := 1.0 + float(side) * sin(e.age * 3.0) * (0.06 if e.state == Expressions.State.CURIOUS else 0.02)
		var lid: float = maxf(0.09, 1.0 - e.blink * 0.96)
		if kind == Variants.FROZEN:
			lid *= 0.88
		elif kind == Variants.GOLDEN and not alarm:
			lid *= 0.82
		var radii := Vector2(52, (63 if alarm else 58) * lid * asymmetric)
		_ellipse(canvas, d, eye + Vector2(0, 3), radii + Vector2(4, 4), INK)
		_shaded_ellipse(canvas, d, eye, radii, Color("#ffffff"), Color("#cbbac9"))
		if lid > 0.3:
			var look: Vector2 = e.look * Vector2(1.0, lid)
			_shaded_ellipse(canvas, d, eye + look + Vector2(3, 4), Vector2(25, 31 * lid), Color("#17101c"), Color("#693b30"))
			_ellipse(canvas, d, eye + look + Vector2(-3, -6), Vector2(9, 11 * lid), Color.WHITE)
			_ellipse(canvas, d, eye + look + Vector2(10, 10), Vector2(3, 4 * lid), Color("#e3ccea"))
			if e.state == Expressions.State.DIZZY:
				_path(canvas, d, [eye + Vector2(-15, 0), eye + Vector2(0, -14), eye + Vector2(13, 0), eye + Vector2(0, 13), eye + Vector2(-5, 1)], Color("#c6a4de"), 3.0)
		var eyebrow_y: float = -83.0 - e.brow * 8.0
		var slant: float = e.brow * float(side) * (13.0 if e.state == Expressions.State.ANGRY else -12.0)
		_path(canvas, d, [Vector2(eye.x - 24, eyebrow_y + slant), Vector2(eye.x, eyebrow_y - 7), Vector2(eye.x + 24, eyebrow_y - slant)], INK, 6.0)
		var cheek := Vector2(side * 119, 55)
		_ellipse(canvas, d, cheek, Vector2(24, 11), Color(0.96, 0.48, 0.30, 0.45))
		_ellipse(canvas, d, cheek + Vector2(-5, -4), Vector2(8, 3), Color(1.0, 0.88, 0.72, 0.65))
	if alarm:
		var opening: float = 16.0 + e.mouth * 34.0
		_shaded_ellipse(canvas, d, Vector2(0, 86), Vector2(28, opening), Color("#120b15"), Color("#713027"))
		_shaded_ellipse(canvas, d, Vector2(0, 86 + opening * 0.59), Vector2(17, opening * 0.28), Color("#ffb1a3"), Color("#e54961"))
	else:
		var mouth := PackedVector2Array()
		var mouth_colors := PackedColorArray()
		var amount: float = 0.65 + e.mouth * 0.6
		for i in 33:
			var angle := TAU * float(i) / 32.0
			var p := Vector2(cos(angle) * 72.0, 83.0 + sin(angle) * 40.0 * amount)
			if sin(angle) < 0.0:
				p.y = 65.0 + sin(angle) * 5.0
			mouth.append(d.warp(p))
			mouth_colors.append(Color("#251016").lerp(Color("#863527"), maxf(0.0, sin(angle))))
		canvas.draw_polygon(mouth, mouth_colors)
		canvas.draw_polyline(mouth, INK, 3.0, true)
		var tongue := Vector2(sin(e.age * 6.0) * (6.0 if e.state == Expressions.State.LAUGHING else 1.5), 83 + 25 * amount)
		_shaded_ellipse(canvas, d, tongue, Vector2(37, 13 * amount), Color("#ffb5a7"), Color("#eb455a"))
		_path(canvas, d, [tongue + Vector2(-3, -8 * amount), tongue + Vector2(0, -3 * amount), tongue + Vector2(0, 1)], Color(0.72, 0.15, 0.25, 0.55), 2.0)
		_ellipse(canvas, d, Vector2(0, 68), Vector2(33, 5), Color("#fff9e9"))

func _variant(canvas: CanvasItem, d, time: float, kind: int, ratio: float, reduced: bool) -> void:
	if kind == Variants.FROZEN:
		_path(canvas, d, [Vector2(-88, -111), Vector2(-58, -151), Vector2(-23, -121)], Color("#edffff"), 5.0)
		if ratio > 0.25:
			var crack := Color(0.14, 0.38, 0.64, clampf((ratio - 0.25) * 1.8, 0.0, 1.0))
			_path(canvas, d, [Vector2(126, 10), Vector2(102, 35), Vector2(117, 52), Vector2(91, 78)], crack, 4.0)
			if ratio > 0.6:
				_path(canvas, d, [Vector2(103, 35), Vector2(75, 26), Vector2(65, 43)], crack, 3.0)
	elif kind == Variants.GOLDEN:
		_crown(canvas, d)
		for i in (2 if reduced else 5):
			var point: Vector2 = d.warp(Vector2(sin(time * 1.7 + i * 2.1) * 202, cos(time * 1.3 + i * 1.8) * 170))
			var radius := 3.0 + 4.0 * maxf(0.0, sin(time * 4.0 + i))
			canvas.draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), Color("#fffacc"), 2.5, true)
			canvas.draw_line(point - Vector2(0, radius), point + Vector2(0, radius), Color("#fffacc"), 2.5, true)
	elif kind == Variants.EXPLOSIVE:
		_ellipse(canvas, d, Vector2(22, -206), Vector2(12, 25), Color("#ffb348"))
		_ellipse(canvas, d, Vector2(22, -209), Vector2(6, 15), Color("#fff3a0"))
		for i in (1 if reduced else 3):
			var life := fposmod(time * 0.7 + float(i) / 3.0, 1.0)
			var point: Vector2 = d.warp(Vector2(22, -228)) + Vector2(sin(time + i) * 16, -life * 58)
			canvas.draw_circle(point, 5.0 + life * 8.0, Color(0.65, 0.51, 0.58, (1.0 - life) * 0.25))

func _crown(canvas: CanvasItem, d) -> void:
	var crown := PackedVector2Array()
	for point in [Vector2(-54, -181), Vector2(-65, -233), Vector2(-27, -210), Vector2(0, -253), Vector2(27, -210), Vector2(61, -233), Vector2(53, -181)]:
		crown.append(d.warp(point))
	canvas.draw_colored_polygon(crown, Color("#ffd335"))
	for x in [-31, 0, 31]:
		_ellipse(canvas, d, Vector2(x, -192), Vector2(6, 7), Color("#f46b26"))
	_path(canvas, d, [Vector2(-50, -186), Vector2(0, -183), Vector2(50, -186)], Color("#fff291"), 5)

func _bubble(canvas: CanvasItem, e) -> void:
	if e.bubble_time <= 0.0:
		return
	var fade: float = minf(e.bubble_time / 0.15, (1.15 - e.bubble_time) / 0.1)
	var center := Vector2(110, -274 - sin(clampf(fade, 0.0, 1.0) * PI) * 3.0)
	var color := Color(1, 0.99, 0.93, clampf(fade, 0.0, 1.0))
	canvas.draw_style_box(_bubble_style(color), Rect2(center - Vector2(73, 26), Vector2(146, 52)))
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-38, 22), center + Vector2(-48, 42), center + Vector2(-18, 22)]), color)
	canvas.draw_string(FACE_FONT, center + Vector2(-68, 8), e.bubble, HORIZONTAL_ALIGNMENT_CENTER, 136, 25, Color(0.27, 0.15, 0.22, color.a))

var bubble_style := StyleBoxFlat.new()
func _bubble_style(color: Color) -> StyleBoxFlat:
	bubble_style.bg_color = color
	bubble_style.set_corner_radius_all(24)
	return bubble_style
