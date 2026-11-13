class_name Effects
extends Node3D
var active: int = 0
const LIMIT := 80
const MOBILE_LIMIT := 20
var pool: Array[MeshInstance3D] = []
var particles: Array = []
var mobile_materials: Dictionary = {}

func _ready() -> void:
	if not MobilePlatform.lightweight(): return
	var mesh := BoxMesh.new()
	for i in range(MOBILE_LIMIT):
		var node := MeshInstance3D.new(); node.mesh = mesh; node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node); pool.append(node)
		particles.append({"left":0.0,"duration":0.0,"scale":Vector3.ONE,"velocity":Vector3.ZERO,"beam":false})

func emit_mobile(pos: Vector3,extent: Vector3,color: Color,velocity: Vector3,duration: float,beam: bool = false) -> MeshInstance3D:
	for i in range(pool.size()):
		if particles[i].left>0: continue
		var node := pool[i]
		var key := color.to_html()
		if not mobile_materials.has(key):
			var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = color
			mobile_materials[key] = mat
		node.material_override = mobile_materials[key]; node.position = pos; node.rotation = Vector3.ZERO; node.scale = extent; node.show()
		particles[i] = {"left":duration,"duration":duration,"scale":extent,"velocity":velocity,"beam":beam}
		active += 1
		return node
	return null

func _process(delta: float) -> void:
	for i in range(particles.size()):
		var data: Dictionary = particles[i]
		if data.left<=0: continue
		data.left = maxf(0,data.left-delta)
		var node := pool[i]
		if data.left==0: node.hide(); active -= 1; continue
		node.position += data.velocity*delta
		var factor: float = maxf(.02,data.left/data.duration)
		node.scale = data.scale*Vector3(factor,factor,1 if data.beam else factor)

func tracer(from: Vector3, to: Vector3, color: Color = Color("eaf4a5")) -> void:
	if not pool.is_empty():
		if from.distance_squared_to(to)<.0001: return
		var beam := emit_mobile((from+to)*.5,Vector3(.04,.04,from.distance_to(to)),color,Vector3.ZERO,.085,true)
		if beam!=null: beam.look_at(to)
		return
	if active >= LIMIT or from.distance_to(to) < .01:
		return
	active += 1
	var beam := VisualFactory.box(self, Vector3(.035, .035, from.distance_to(to)), (from + to) * .5, color, true)
	beam.look_at(to)
	var tween := create_tween()
	tween.tween_property(beam, "scale", Vector3(.1, .1, 1), .085)
	tween.tween_callback(func(): beam.queue_free(); active -= 1)

func burst(pos: Vector3, color: Color, count: int = 5) -> void:
	if not pool.is_empty():
		for i in range(mini(2,count)): emit_mobile(pos,Vector3.ONE*.12,color,Vector3(randf_range(-2,2),randf_range(.5,2),randf_range(-2,2)),.22)
		return
	for i in range(mini(count, LIMIT - active)):
		active += 1
		var bit := VisualFactory.box(self, Vector3.ONE * randf_range(.07, .16), pos, color, true)
		var target := pos + Vector3(randf_range(-.9, .9), randf_range(.2, .9), randf_range(-.9, .9))
		var tween := create_tween().set_parallel(true)
		tween.tween_property(bit, "position", target, .3)
		tween.tween_property(bit, "scale", Vector3.ZERO, .32)
		tween.chain().tween_callback(func(): bit.queue_free(); active -= 1)

func flash(pos: Vector3) -> void:
	burst(pos, Color("fff3a4"), 2)
