class_name MusicDirector
extends Node
## Original generative score: minor-key pads, melody, bass and soft percussion.
var world: Node3D
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var cache: Dictionary = {}
var beat := 0
var clock := .5
var combat := false
const MELODY := [62,69,65,72,69,65,64,60,58,65,62,69,65,62,60,57]
const ROOTS := [50,46,53,48]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(10):
		var voice := AudioStreamPlayer.new(); add_child(voice); voices.append(voice)

func note(midi: int,duration: float,kind: String,gain: float) -> void:
	if GameSettings.music_volume<=0 or voices.is_empty(): return
	var key := "%d:%.2f:%s" % [midi,duration,kind]
	if not cache.has(key):
		var count := int(16000*duration); var bytes := PackedByteArray(); bytes.resize(count*2)
		var frequency := 440*pow(2.0,(midi-69)/12.0)
		var rng := RandomNumberGenerator.new(); rng.seed = midi+count
		for i in range(count):
			var t := float(i)/16000
			var envelope := minf(1,t/.025)*pow(1-t/duration,1.5 if kind=="pad" else 3.0)
			var value := sin(TAU*frequency*t)*.65+sin(TAU*frequency*2*t)*.17+sin(TAU*frequency*.5*t)*.12
			if kind=="drum": value = (rng.randf_range(-1,1)*.4+sin(TAU*70*t*(1-t/duration))*.5)*exp(-t*22)
			bytes.encode_s16(i*2,int(clampf(value*envelope,-1,1)*21000))
		var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 16000; stream.data = bytes
		cache[key] = stream
	var voice := voices[next_voice]; next_voice = (next_voice+1)%voices.size()
	voice.stream = cache[key]; voice.set_meta("gain",gain); voice.volume_db = linear_to_db(maxf(.0001,GameSettings.music_volume*gain)); voice.play()

func _process(delta: float) -> void:
	combat = is_instance_valid(world) and world.waves.running
	var quiet: float = .5 if is_instance_valid(world) and world.combat_paused() else 1.0
	for voice in voices: voice.volume_db = linear_to_db(maxf(.0001,GameSettings.music_volume*float(voice.get_meta("gain",.1))*quiet))
	clock -= delta
	if clock>0: return
	clock = .30 if combat else .48
	var root_note: int = ROOTS[(beat/8)%ROOTS.size()]
	if beat%8==0:
		note(root_note+12,1.6,"pad",.3); note(root_note+19,1.6,"pad",.16)
	if beat%4==0: note(root_note,1.0,"bass",.28)
	note(MELODY[beat%MELODY.size()]+(12 if combat and beat%4==3 else 0),.38,"bell",.16 if combat else .12)
	if combat: note(36 if beat%4==0 else 48,.16,"drum",.22 if beat%2==0 else .09)
	beat = (beat+1)%64

func _exit_tree() -> void:
	for voice in voices:
		voice.stop(); voice.stream = null
	cache.clear()
