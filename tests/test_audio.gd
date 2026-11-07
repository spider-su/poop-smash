extends SceneTree

const Audio = preload("res://scripts/character/poop_audio.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	var bytes := 0
	for category in Audio.CATEGORIES:
		var previous := PackedByteArray()
		for clip in audio.bank[category]:
			bytes += clip.data.size()
			var peak := 0
			for i in range(0, clip.data.size(), 2):
				peak = maxi(peak, absi(clip.data.decode_s16(i)))
			_check(peak <= int(32767 * 0.161), "Audio exceeds safe overlapping peak")
			_check(clip.data.decode_s16(0) == 0 and absi(clip.data.decode_s16(clip.data.size() - 2)) < 10, "Audio envelope clicks at boundary")
			_check(clip.data != previous, "Sound variations are identical")
			previous = clip.data
	_check(bytes < 500000, "Audio cache exceeds memory budget")
	_check(audio.players.size() == Audio.POOL_SIZE, "Audio pool size incorrect")
	for word in ["ouch", "oh", "nice", "oops"]:
		_check(audio.bank.has(word), "Spoken reaction is missing: " + word)
	audio.play("tap", 0)
	var first = audio.players[0].stream
	audio.play("tap", 0)
	_check(audio.players[1].stream == null, "Rapid tapping bypassed audio cooldown")
	audio.play("burst", 0)
	_check(audio.players[0].stream == first and audio.players[1].stream != null, "New sound interrupted the previous clip")
	# Let the mixer start both playbacks even on a busy headless runner.
	await create_timer(0.10).timeout
	audio.enabled = false
	for player in audio.players:
		_check(not player.playing, "Muted audio is still playing")
	# Let the audio mixer retire stopped playbacks before freeing the pool.
	await create_timer(0.06).timeout
	audio.free()
	await create_timer(0.06).timeout
	if failures == 0:
		print("Audio cache, overlap, cooldown and envelope: PASS")
	quit(0 if failures == 0 else 1)
