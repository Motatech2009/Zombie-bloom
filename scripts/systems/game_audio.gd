class_name GameAudio
extends Node
## Short synthesized gameplay cues with a shared, bounded voice pool.

enum Cue { HOWL, ROLL, RELOAD, PICKUP, CORE_UPGRADE, WIND }

const SAMPLE_RATE := 22050
const LENGTHS := [1.38, .32, .29, .19, .64, 2.4]
const LEVELS := [.17, .09, .08, .065, .095, .038]
var cache: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var listener: Node3D
var wind_left := 4.5
var pickup_left := 0.0
var bag_units := 0
var rolling := false
var reloading := false

func _ready() -> void:
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func audible() -> bool:
	return DisplayServer.get_name() != "headless" and not voices.is_empty() and GameSettings.volume > 0

func play_stream(stream: AudioStreamWAV, gain: float) -> void:
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = stream
	voice.volume_db = linear_to_db(gain)
	voice.play()

func play_tone(frequency: int, duration: float, gain: float) -> void:
	if not audible():
		return
	var key := str(frequency) + ":" + str(duration)
	if not cache.has(key):
		var samples := int(SAMPLE_RATE * duration)
		var bytes := PackedByteArray()
		bytes.resize(samples * 2)
		for i in range(samples):
			var time := float(i) / float(SAMPLE_RATE)
			var envelope := pow(1.0 - float(i) / samples, 2)
			var value := sin(TAU * frequency * time * (1.0 - time * 2))
			bytes.encode_s16(i * 2, int(value * envelope * 20000))
		cache[key] = make_stream(bytes)
	play_stream(cache[key], gain)

func play_cue(cue: Cue, variant: int = 0) -> void:
	if not audible():
		return
	var key := "cue_%d_%d" % [cue, variant]
	if not cache.has(key):
		cache[key] = synthesize(cue, variant)
	play_stream(cache[key], LEVELS[cue])

static func synthesize(cue: Cue, variant: int = 0) -> AudioStreamWAV:
	var duration: float = LENGTHS[cue]
	var samples := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + int(cue) * 53 + variant * 211
	var filtered := 0.0
	var breeze := 0.0
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / (samples - 1)
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, .12)
		breeze = lerpf(breeze, filtered, .025)
		var value := 0.0
		match cue:
			Cue.HOWL:
				var pitch := TAU * (168.0*t + 52.0*t*t - 42.0*t*t*t + .75*sin(TAU*4.0*t))
				value = (sin(pitch)*.48 + sin(pitch*2.0)*.19 + filtered*.22) * pow(sin(PI*progress),1.45)
			Cue.ROLL:
				value = (filtered * .66 + breeze * 1.9) * sin(PI * progress)
			Cue.RELOAD:
				var click := exp(-t * 95.0)
				var latch := exp(-(t - .17) * 70.0) if t >= .17 else 0.0
				value = (filtered + sin(TAU * 460.0 * t) * .22) * (click * .64 + latch * .83)
			Cue.PICKUP:
				value = (noise * .28 + filtered * .72) * exp(-t * 24.0)
			Cue.CORE_UPGRADE:
				var latch := exp(-absf(t - .08) * 45.0)
				var motor := sin(TAU * (102.0 * t + 18.0 * t * t)) * .45 + sin(TAU * 206.0 * t) * .13
				value = motor * sin(PI * progress) + filtered * latch * .65
			Cue.WIND:
				value = (breeze * 4.1 + filtered * .36) * pow(sin(PI * progress), 1.3)
		var edge := minf(1.0, minf(t / .006, (1.0 - progress) * 24.0))
		bytes.encode_s16(i * 2, roundi(clampf(value * edge, -1.0, 1.0) * 23000))
	return make_stream(bytes)

static func make_stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	return stream

func update_field(actor: Node3D, delta: float, calm: bool) -> void:
	if actor == null or actor.health.dead or not audible():
		listener = null
		return
	if actor != listener:
		listener = actor
		pickup_left = 0.0
		bag_units = inventory_units(actor.bag)
		rolling = actor.roll_left > 0
		reloading = actor.weapons.reload_left > 0
		return

	var now_rolling: bool = actor.roll_left > 0
	if now_rolling and not rolling:
		play_cue(Cue.ROLL)
	rolling = now_rolling

	var now_reloading: bool = actor.weapons.reload_left > 0
	if now_reloading and not reloading:
		play_cue(Cue.RELOAD)
	reloading = now_reloading

	pickup_left -= delta
	if pickup_left <= 0.0:
		var units := inventory_units(actor.bag)
		if units > bag_units:
			play_cue(Cue.PICKUP)
		bag_units = units
		pickup_left = .12

	if calm:
		wind_left -= delta
		if wind_left <= 0.0:
			play_cue(Cue.WIND)
			wind_left = 16.0

func inventory_units(bag: ItemBag) -> int:
	var units := 0
	for item in bag.slots:
		units += int(item.qty)
	return units

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	cache.clear()
