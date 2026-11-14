class_name GameAudio
extends Node
## Tiny synthesized cues. No downloads, recordings or licensed audio.
var cache: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0

func _ready() -> void:
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func play_tone(frequency: int, duration: float, gain: float) -> void:
	if voices.is_empty() or GameSettings.volume == 0:
		return
	var key := str(frequency) + ":" + str(duration)
	if not cache.has(key):
		var samples := int(22050 * duration)
		var bytes := PackedByteArray()
		bytes.resize(samples * 2)
		for i in range(samples):
			var time := float(i) / 22050.0
			var envelope := pow(1.0 - float(i) / samples, 2)
			var value := sin(TAU * frequency * time * (1.0 - time * 2))
			bytes.encode_s16(i * 2, int(value * envelope * 20000))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = bytes
		cache[key] = stream
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = cache[key]
	voice.volume_db = linear_to_db(gain)
	voice.play()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	cache.clear()
