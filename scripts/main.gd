extends Node2D

const Rules = preload("res://scripts/squish_rules.gd")
const ScoreRules = preload("res://scripts/score_rules.gd")
const Variants = preload("res://scripts/poop_variants.gd")
const Screens = preload("res://scripts/screen_flow.gd")
const Character = preload("res://scripts/character/poop_character.gd")
const GameUI = preload("res://scripts/ui/game_ui.gd")
const PARK = preload("res://assets/backgrounds/park.png")
const SAVE_PATH := "user://poop_smash.cfg"
const ROUND_SECONDS := 60.0
const BURST_LENGTH := 0.82

# Available to device accessibility presets without introducing another menu.
@export var reduced_effects := false
var character := Character.new()
var ui := GameUI.new()
var active_touch := -1
var current_variant := Variants.CLASSIC
var variant_sequence := 0
var screen := Screens.MENU
var arcade_mode := false
var round_finished := false
var remaining_seconds := ROUND_SECONDS
var score := 0
var best_score := 0
var round_smashes := 0
var total_smashes := 0
var max_combo := 0
var combo_count := 0
var combo_window := 0.0
var latest_record := false
var last_reward := 0
var reward_timer := 0.0
var sound_enabled := true
var haptics_enabled := true
var wobble := 0.0
var celebration_time := 0.0
var content_origin := Vector2.ZERO
var content_size := Vector2(720, 1280)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	add_child(character)
	character.z_index = 1
	character.smashed.connect(_on_smash)
	character.respawn_requested.connect(_next_variant)
	ui.game = self
	ui.z_index = 2
	add_child(ui)
	_load_preferences()
	_sync_settings()
	_next_variant()
	_layout()
	get_viewport().size_changed.connect(_layout)

func _layout() -> void:
	content_origin = Vector2.ZERO
	content_size = get_viewport_rect().size
	# Android safe-area coordinates are physical screen pixels, not canvas units.
	if OS.has_feature("mobile"):
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var physical := Vector2(DisplayServer.screen_get_size())
		if safe.size.x > 0.0 and safe.size.y > 0.0 and physical.x > 0.0 and physical.y > 0.0:
			var factor := content_size / physical
			content_origin = safe.position * factor
			content_size = safe.size * factor
	var top := 270.0
	var bottom := content_size.y - 230.0
	if screen == Screens.MENU:
		top = 320.0
		bottom = Screens.menu_free_rect(content_size).position.y - 80.0
	var available := maxf(200.0, bottom - top)
	var character_scale := minf(1.32, minf((content_size.x - 80.0) / 480.0, available / 540.0))
	character.position = content_origin + Vector2(content_size.x * 0.5, (top + bottom) * 0.5 - 8.0)
	character.scale = Vector2.ONE * character_scale
	queue_redraw()
	ui.queue_redraw()

func _process(delta: float) -> void:
	# One clock drives gameplay and visuals; small steps keep springs stable.
	var elapsed := delta
	while elapsed > 0.0:
		var step := minf(elapsed, 1.0 / 120.0)
		_advance(step)
		elapsed -= step
	queue_redraw()
	ui.queue_redraw()

func _advance(dt: float) -> void:
	if screen == Screens.PLAY and arcade_mode and not round_finished:
		remaining_seconds = maxf(0.0, remaining_seconds - dt)
		if remaining_seconds <= 0.0:
			_finish_round()
	reward_timer = maxf(0.0, reward_timer - dt)
	if screen == Screens.RESULTS:
		celebration_time += dt
	if screen == Screens.PLAY and not character.spent:
		combo_window = maxf(0.0, combo_window - dt)
	if combo_window <= 0.0:
		combo_count = 0
	wobble += dt * 3.0
	character.step(dt, screen == Screens.PLAY, screen == Screens.PLAY)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			if _press_ui(event.position):
				return
			if _press(event.position) and character.holding:
				active_touch = event.index
		elif not event.pressed and active_touch == event.index:
			_release()
	elif event is InputEventScreenDrag:
		if event.index == active_touch:
			_drag(event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and active_touch == -1:
			if _press_ui(event.position):
				return
			if _press(event.position) and character.holding:
				active_touch = -2
		elif not event.pressed and active_touch == -2:
			_release()
	elif event is InputEventMouseMotion and active_touch == -2:
		_drag(event.position, event.relative)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(character):
		_release()

func _press_ui(position: Vector2) -> bool:
	var action := Screens.hit_action(screen, position - content_origin, content_size)
	match action:
		"arcade", "retry":
			_start_round()
			return true
		"free":
			_start_free_play()
			return true
		"menu":
			_go_menu()
			return true
		"sound":
			sound_enabled = not sound_enabled
			_sync_settings()
			_save_preferences()
			return true
		"haptics":
			haptics_enabled = not haptics_enabled
			_sync_settings()
			_save_preferences()
			return true
	return screen != Screens.PLAY

func _sync_settings() -> void:
	character.audio.enabled = sound_enabled
	character.haptics_enabled = haptics_enabled
	character.reduced_effects = reduced_effects

func _start_free_play() -> void:
	screen = Screens.PLAY
	arcade_mode = false
	_reset_play()

func _start_round() -> void:
	screen = Screens.PLAY
	arcade_mode = true
	_reset_play()

func _reset_play() -> void:
	round_finished = false
	remaining_seconds = ROUND_SECONDS
	score = 0
	round_smashes = 0
	max_combo = 0
	latest_record = false
	combo_count = 0
	combo_window = 0.0
	reward_timer = 0.0
	active_touch = -1
	_sync_settings()
	_next_variant()
	_layout()

func _go_menu() -> void:
	screen = Screens.MENU
	arcade_mode = false
	active_touch = -1
	character.audio.stop()
	current_variant = Variants.CLASSIC
	character.reset(current_variant)
	_layout()

func _finish_round() -> void:
	if screen != Screens.PLAY:
		return
	round_finished = true
	_release()
	screen = Screens.RESULTS
	celebration_time = 0.0
	latest_record = score > best_score
	if latest_record:
		best_score = score
		_save_preferences()
	character.audio.play("victory", current_variant)

func _next_variant() -> void:
	if arcade_mode:
		current_variant = Variants.ALL[rng.randi_range(0, Variants.ALL.size() - 1)]
	else:
		current_variant = Variants.ALL[variant_sequence % Variants.ALL.size()]
		variant_sequence += 1
	character.reset(current_variant)

func _center() -> Vector2:
	return character.position

func _press(position: Vector2) -> bool:
	return screen == Screens.PLAY and character.tap(character.to_local(position))

func _drag(position: Vector2, relative: Vector2) -> void:
	if screen == Screens.PLAY:
		# Convert both position and travel into the same local space as the mesh.
		character.drag(character.to_local(position), relative / character.scale)

func _release() -> void:
	character.release()
	active_touch = -1

func _on_smash(kind: int) -> void:
	active_touch = -1
	total_smashes += 1
	round_smashes += 1
	if arcade_mode and screen == Screens.PLAY and not round_finished:
		combo_count = ScoreRules.next_combo(combo_count, combo_window)
		combo_window = ScoreRules.COMBO_WINDOW_SECONDS
		max_combo = maxi(max_combo, combo_count)
		last_reward = ScoreRules.points_for_smash(combo_count) * Variants.point_multiplier(kind)
		score += last_reward
		reward_timer = 1.3

func _preferences_path() -> String:
	return SAVE_PATH

func _load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_preferences_path()) != OK:
		return
	best_score = maxi(0, int(cfg.get_value("arcade", "best_score", 0)))
	sound_enabled = bool(cfg.get_value("settings", "sound", true))
	haptics_enabled = bool(cfg.get_value("settings", "haptics", true))

func _save_preferences() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("arcade", "best_score", best_score)
	cfg.set_value("settings", "sound", sound_enabled)
	cfg.set_value("settings", "haptics", haptics_enabled)
	var result := cfg.save(_preferences_path())
	if result != OK:
		push_warning("Could not save Poop Smash preferences: %s" % error_string(result))

func _draw() -> void:
	_draw_background(get_viewport_rect().size)
	var shadow := character.position + Vector2(0, 260.0 * character.scale.y)
	var points := PackedVector2Array()
	for i in 48:
		var a := TAU * float(i) / 48.0
		points.append(shadow + Vector2(cos(a) * 210, sin(a) * 24) * character.scale)
	draw_colored_polygon(points, Color(0.42, 0.23, 0.22, 0.13))
func _draw_background(size: Vector2) -> void:
	var texture_size := Vector2(PARK.get_size())
	var cover := maxf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn := texture_size * cover
	draw_texture_rect(PARK, Rect2((size - drawn) * 0.5, drawn), false)
	for i in 9:
		var x := size.x * (0.08 + float((i * 47) % 84) / 100.0)
		var y := size.y * (0.12 + float((i * 29) % 70) / 100.0)
		draw_circle(Vector2(x, y + sin(wobble * 0.5 + i) * 7.0), float(3 + i % 4 * 2), Color(1, 1, 0.9, 0.20))
