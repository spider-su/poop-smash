extends Node

const Variants = preload("res://scripts/poop_variants.gd")
const CATEGORIES := ["tap", "drag", "fart", "worried", "laugh", "idle", "burst", "victory", "ouch", "oh", "nice", "oops"]
const SPEECH := ["ouch", "oh", "nice", "oops"]
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
	var cooldown_key := "speech" if category in SPEECH else category
	if not enabled or not bank.has(category) or float(cooldowns.get(cooldown_key, 0.0)) > 0.0:
		return
	for player in players:
		if player.playing:
			continue
		player.stream = bank[category][rng.randi_range(0, 2)]
		player.pitch_scale = Variants.sound_pitch(variant) * rng.randf_range(0.94, 1.06)
		player.volume_db = linear_to_db(clampf(intensity, 0.2, 1.0))
		player.play()
		cooldowns[cooldown_key] = 0.11 if category == "tap" else (0.22 if category == "drag" else (1.05 if category in SPEECH else 0.7))
		return
	# Dropping a low-priority reaction sounds better than cutting off another clip.

static func _synthesize(category: String, variation: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var duration := 0.19
	if category in ["burst", "victory", "worried", "laugh"]:
		duration = 0.38
	if category in SPEECH:
		duration = 0.30
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
		if category in SPEECH:
			var glide := 0.0
			var first_formant := 430.0
			var second_formant := 950.0
			var third_formant := 2550.0
			var first_weight := 1.0
			var second_weight := 0.8
			var pitch := 225.0 + float(variation) * 32.0
			match category:
				"ouch":
					glide = smoothstep(0.10, 0.70, progress)
					first_formant = 690.0 - 270.0 * glide
					second_formant = 1260.0 - 410.0 * glide
					third_formant = 2820.0
					second_weight = 0.8
				"oh":
					glide = smoothstep(0.12, 0.95, progress)
					first_formant = 500.0 - 105.0 * glide
					second_formant = 900.0 - 190.0 * glide
					third_formant = 2600.0
					second_weight = 0.85
				"nice":
					glide = smoothstep(0.18, 0.73, progress)
					first_formant = 360.0 + 130.0 * glide
					second_formant = 1840.0 + 480.0 * glide
					third_formant = 2950.0
					second_weight = 0.9
				_:
					glide = smoothstep(0.12, 0.48, progress)
					first_formant = 430.0 - 100.0 * glide
					second_formant = 950.0 - 180.0 * glide
					third_formant = 2550.0
					second_weight = 0.78
			phase += TAU * pitch / float(stream.mix_rate)
			var voiced := 0.0
			var weight := 0.0
			for harmonic in range(1, 11):
				var harmonic_frequency := pitch * float(harmonic)
				var distance := (harmonic_frequency - first_formant) / 150.0
				var spectral := exp(-0.5 * distance * distance)
				distance = (harmonic_frequency - second_formant) / 250.0
				spectral += second_weight * exp(-0.5 * distance * distance)
				distance = (harmonic_frequency - third_formant) / 480.0
				spectral += 0.22 * exp(-0.5 * distance * distance)
				spectral /= float(harmonic)
				voiced += sin(phase * float(harmonic)) * spectral
				weight += spectral
			voiced /= maxf(weight, 0.01)
			var hiss := 0.0
			if category == "ouch" and progress > 0.66:
				hiss = clampf((progress - 0.66) * 5.0, 0.0, 1.0)
			elif category == "nice" and progress > 0.78:
				hiss = clampf((progress - 0.78) * 5.0, 0.0, 1.0)
			elif category == "oops" and progress > 0.7:
				hiss = clampf((progress - 0.7) * 4.0, 0.0, 1.0)
			elif category == "oh" and progress < 0.08:
				hiss = clampf(1.0 - progress / 0.08, 0.0, 1.0) * 0.12
			var syllable := 1.0
			if category == "oops" and progress > 0.48 and progress < 0.57:
				syllable = 0.18
			var speech_envelope := minf(t / 0.014, 1.0) * pow(maxf(0.0, 1.0 - progress), 0.72)
			var speech_sample := (voiced * (1.0 - hiss * 0.84) * syllable + noise * hiss * 0.45) * speech_envelope * 0.16
			bytes.encode_s16(i * 2, int(clampf(speech_sample, -0.16, 0.16) * 32767.0))
			continue
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
