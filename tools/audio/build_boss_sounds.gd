extends SceneTree
## Bake short mono PCM sounds at authoring time. Run with Godot from the project root.

const Bank := preload("res://scripts/combat18/boss_sound_bank.gd")
const RATE := 22050

# Each layer holds a material or vocal texture, start, duration, gain, pitch, and pitch sweep.
const LAYERS := [
	[["air",0,.48,.60,140,-90],["growl",.02,.33,.47,82,-30],["dirt",.085,.35,.29,31,0]], # Charge
	[["thud",0,.30,.78,90,-42],["crack",.005,.17,.44,270,-90]], # Charge impact
	[["thud",0,.58,.93,73,-41],["crack",.012,.23,.58,210,-95],["dirt",.055,.49,.39,42,-19]], # Quake
	[["bubble",0,.25,.80,135,110],["air",.08,.25,.25,350,-110]], # Acid launch
	[["bubble",0,.29,.66,92,160],["bubble",.075,.26,.57,164,158],["bubble",.14,.33,.60,220,-90],["dirt",.14,.34,.18,54,32]], # Acid volley
	[["crack",0,.12,.36,500,-65],["bubble",.02,.33,.62,335,-180],["dirt",.03,.38,.55,48,-5]], # Acid splash
	[["air",0,.13,.34,220,100],["thud",.05,.24,.75,146,-63],["crack",.055,.15,.57,345,-135]], # Slap
	[["air",0,.22,.57,330,-140],["crack",.085,.19,.55,690,-216]], # Claw
	[["scream",0,.93,.80,221,-79],["growl",.04,.63,.32,119,-20],["air",.09,.77,.27,260,-30]], # Matriarch scream
	[["growl",0,.59,.70,82,36],["crack",.20,.16,.25,430,-120],["growl",.29,.43,.47,150,-38],["dirt",.16,.49,.32,29,8]], # Summon
	[["air",0,.49,.86,190,140],["air",.15,.31,.52,400,-160],["wood",.006,.20,.22,230,-155]], # Dive
	[["bubble",0,.18,.39,350,-174],["dirt",0,.24,.72,75,-37],["crack",.019,.09,.37,580,-189]], # Spore strike
	[["air",0,.68,.90,150,-84],["air",.14,.50,.47,370,-250],["dirt",.17,.45,.35,57,-25]], # Gust
	[["growl",0,.44,.82,114,54],["crack",.12,.17,.37,225,-118],["air",.08,.34,.35,225,160]], # Leap
	[["thud",0,.39,.84,80,-50],["dirt",.016,.30,.52,88,-32],["growl",.03,.24,.37,120,-52]], # Landing
	[["howl",0,1.38,.88,168,0]], # Howl
	[["dirt",0,.61,.70,62,-24],["wood",.09,.36,.62,129,-41],["dirt",.30,.41,.47,92,-34]], # Clay block
	[["air",0,.29,.58,485,-365],["wood",.015,.23,.62,275,-120]], # Clay cast
	[["crack",0,.24,.61,384,-179],["wood",.06,.23,.51,153,-81]], # Clay bind
	[["bubble",0,.31,.67,97,66],["dirt",.09,.32,.38,64,-20],["chitter",.12,.48,.62,527,232]], # Parasites
	[["air",0,.42,.60,235,-56],["chitter",.06,.53,.66,863,-240],["air",.17,.42,.42,368,-108]], # Flock
	[["thud",0,.74,.92,57,-29],["wood",.018,.44,.75,172,-96],["dirt",.045,.62,.47,44,-14]], # Titan slam
	[["wood",0,.30,.82,203,-90],["crack",.012,.18,.55,720,-180],["wood",.09,.40,.62,317,-179],["wood",.19,.38,.63,147,-66]], # Stakes
	[["dirt",0,.54,.67,71,-28],["wood",.11,.43,.48,276,-75],["crack",.29,.27,.38,418,-139]], # Roots
	[["air",0,.18,.71,280,-110]], # Missed close swing
]

func _initialize() -> void:
	assert(LAYERS.size() == Bank.Cue.size())
	var bank := Bank.new()
	for cue in range(LAYERS.size()):
		bank.clips.append(bake(cue))
	var result := ResourceSaver.save(bank, "res://assets/audio/boss_attacks.res", ResourceSaver.FLAG_COMPRESS)
	print("Baked %d boss attack sounds" % bank.clips.size())
	quit(result)

func bake(cue: int) -> AudioStreamWAV:
	var layers: Array = LAYERS[cue]
	var duration := 0.0
	for layer in layers:
		duration = maxf(duration,layer[1]+layer[2])
	var samples := PackedFloat32Array()
	samples.resize(ceili(duration * RATE) + 1)
	var random := RandomNumberGenerator.new()
	random.seed = 2917 + cue*683
	for layer in layers:
		mix_layer(samples, layer, random)
	var peak := 0.0
	for sample in samples: peak = maxf(peak,absf(sample))
	var pcm := PackedByteArray()
	pcm.resize(samples.size()*2)
	for i in range(samples.size()):
		pcm.encode_s16(i*2, roundi(samples[i]*25500.0/peak))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = RATE
	audio.data = pcm
	return audio

func mix_layer(samples: PackedFloat32Array, layer: Array, random: RandomNumberGenerator) -> void:
	var texture: String = layer[0]
	var start := roundi(layer[1]*RATE)
	var length := mini(samples.size()-start,ceili(layer[2]*RATE))
	var gain: float = layer[3]
	var pitch: float = layer[4]
	var sweep: float = layer[5]
	var fast := 0.0
	var low := 0.0
	var dark := 0.0
	for i in range(length):
		var t := float(i)/RATE
		var p := float(i)/(length-1)
		var envelope := minf(1.0,minf(t/.008,(1.0-p)*12.0))
		var noise := random.randf_range(-1,1)
		fast += (noise-fast)*.36
		low += (fast-low)*.074
		dark += (low-dark)*.041
		var grit := (fast-low)
		var body := (low-dark)
		var phase := TAU*t*(pitch+.5*sweep*p)
		var value := 0.0
		match texture:
			"thud":
				value = (sin(phase)*.64 + sin(phase*1.83)*.14 + dark*.95 + body*.25) * exp(-p*6.5)
			"crack":
				value = (grit*.92 + body*.66 + sin(phase)*.17) * exp(-p*7.0)
			"dirt":
				var grains := .44+.56*absf(sin(phase+fast*1.8))
				value = (body*.9+grit*.22+dark*.5)*grains*sin(PI*p)*1.8
			"air":
				value = (body*1.2 + grit*.30 + sin(phase)*.075) * pow(sin(PI*p),1.5) * (.78+.22*sin(p*TAU*2))
			"bubble":
				value = (sin(phase+dark*5.0)*.42 + sin(phase*1.63)*.11 + body*.48) * sin(PI*p) * exp(-p*2.3)
			"growl", "scream":
				var voice := phase + .62*sin(TAU*7.0*t) + fast*.48
				var rasp := sin(voice)*.39 + sin(voice*1.91)*.29 + sin(voice*3.05)*.16 + body*.74
				value = rasp * pow(sin(PI*p),.83) * (.83+.17*sin(TAU*29*t))
			"howl":
				var voice := TAU*(168.0*t+52.0*t*t-42.0*t*t*t+.75*sin(TAU*4.0*t))
				value = (sin(voice)*.48+sin(voice*2.0)*.19+fast*.16)*pow(sin(PI*p),1.45)
			"wood":
				value = (sin(phase)*.50+sin(phase*2.23)*.23+sin(phase*4.3)*.13+body*.6) * exp(-p*6.4)
			"chitter":
				var pulses := pow(.5+.5*sin(TAU*19*t),4.0)
				value = (sin(phase+fast*.83)*.29 + grit*.58)*pulses*sin(PI*p)
		samples[start+i] += value * gain * envelope
