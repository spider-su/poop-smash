extends SceneTree

class CaptureGame:
	extends "res://scripts/main.gd"
	func _load_preferences() -> void:
		pass
	func _save_preferences() -> void:
		pass

var output := "res://build/visuals"
var game: CaptureGame

func _initialize() -> void:
	call_deferred("_capture")

func _shot(label: String) -> void:
	game.queue_redraw()
	game.character.queue_redraw()
	game.ui.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if result != OK:
		push_error("Screenshot failed: " + label)
		quit(1)

func _kind(kind: int) -> void:
	game._start_free_play()
	game.current_variant = kind
	game.character.reset(kind)
	game._process(0.4)

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual capture requires an actual graphical renderer.")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	game = CaptureGame.new()
	root.add_child(game)
	game.set_process(false)
	game.sound_enabled = false
	game.haptics_enabled = false
	game._sync_settings()
	game._process(0.5)
	await _shot("01-menu")
	_kind(0)
	await _shot("02-classic")
	game._press(game.character.to_global(Vector2(140, 60)))
	game._process(0.7)
	await _shot("03-squish")
	_kind(0)
	game._press(game.character.to_global(Vector2(160, 60)))
	game._drag(game.character.to_global(Vector2(310, 15)), Vector2(150, -45) * game.character.scale)
	game._process(0.22)
	await _shot("04-stretch")
	_kind(1)
	game.character.pressure = 0.72
	game._press(game._center())
	game._process(0.1)
	await _shot("05-frozen")
	_kind(2)
	await _shot("06-golden")
	_kind(3)
	game._press(game._center())
	game._process(0.45)
	await _shot("07-volcano")
	game.character.smash()
	game._process(0.26)
	await _shot("08-explosion")
	game._start_round()
	game.score = 12750
	game.round_smashes = 29
	game.max_combo = 5
	game._finish_round()
	game._process(1.1)
	await _shot("09-results")
	var manifest := {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "window": str(root.size), "viewport": str(root.get_visible_rect().size), "screens": 9}
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("Visual captures: PASS ", output)
	quit()
