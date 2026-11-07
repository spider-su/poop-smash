extends Node

const Variants = preload("res://scripts/poop_variants.gd")
const CATEGORIES := ["tap", "drag", "fart", "worried", "laugh", "idle", "burst", "victory"]
const POOL_SIZE := 4
var enabled := true:
	set(value):
		enabled = value
		if not value:
			stop()
var bank: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var cooldowns: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for category in CATEGORIES:
		var clips: Array[AudioStreamWAV] = []
		for variation in 3:
			clips.append(_synthesize(category, variation))
		bank[category] = clips
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)

func step(dt: float) -> void:
	for key in cooldowns:
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - dt)

func stop() -> void:
	for player in players:
		player.stop()

func play(category: String, variant: int, intensity: float = 1.0) -> void:
	if not enabled or not bank.has(category) or float(cooldowns.get(category, 0.0)) > 0.0:
		return
	for player in players:
		if player.playing:
			continue
		player.stream = bank[category][rng.randi_range(0, 2)]
		player.pitch_scale = Variants.sound_pitch(variant) * rng.randf_range(0.94, 1.06)
		player.volume_db = linear_to_db(clampf(intensity, 0.2, 1.0))
		player.play()
		cooldowns[category] = 0.11 if category == "tap" else (0.22 if category == "drag" else 0.7)
		return
	# Dropping a low-priority reaction sounds better than cutting off another clip.

static func _synthesize(category: String, variation: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var duration := 0.19
	if category in ["burst", "victory", "worried", "laugh"]:
		duration = 0.38
	var count := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 731 + variation * 97 + category.hash()
	var phase := 0.0
	for i in count:
		var t := float(i) / float(stream.mix_rate)
		var progress := t / duration
		var frequency := 145.0 + variation * 28.0
		var noise := random.randf_range(-1.0, 1.0)
		var voice := category in ["worried", "laugh", "idle"]
		if category in ["burst", "fart"]:
			frequency = 62.0 + 115.0 * pow(1.0 - progress, 2.0)
		elif category == "drag":
			frequency = 100.0 + 65.0 * sin(progress * PI)
		elif category == "victory":
			frequency = 230.0 + floorf(progress * 4.0) * 68.0
		elif voice:
			frequency = 235.0 + 80.0 * sin(progress * TAU * (3.0 if category == "laugh" else 1.0))
		frequency *= 0.94 + float(variation) * 0.065
		phase += TAU * frequency / float(stream.mix_rate)
		var wave := sin(phase + 1.4 * sin(phase * 0.47))
		if category in ["tap", "drag", "burst"]:
			wave = wave * 0.65 + noise * (0.35 if category == "burst" else 0.16)
		if voice:
			wave *= 0.35 + 0.65 * pow(sin(progress * PI * 3.0), 2.0)
		var envelope := minf(t / 0.012, 1.0) * pow(1.0 - progress, 1.6)
		# Peak <= 0.16 per clip; four overlapping voices remain below full scale.
		var sample := clampf(wave, -1.0, 1.0) * envelope * 0.16
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = bytes
	return stream
