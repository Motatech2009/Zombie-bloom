class_name Effects
extends Node3D
var active: int = 0
const LIMIT := 80
const MOBILE_LIMIT := 20
var pool: Array[MeshInstance3D] = []
var particles: Array = []
var materials: Dictionary = {}

func _ready() -> void:
	var mesh: Mesh = BoxMesh.new() if MobilePlatform.enabled() else ClayStyle.rounded_box(Vector3.ONE)
	for i in range(MOBILE_LIMIT if MobilePlatform.enabled() else LIMIT):
		var node := MeshInstance3D.new(); node.mesh = mesh; node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node); pool.append(node)
		particles.append({"left":0.0,"duration":0.0,"scale":Vector3.ONE,"velocity":Vector3.ZERO,"beam":false})

func emit_particle(pos: Vector3,extent: Vector3,color: Color,velocity: Vector3,duration: float,beam: bool = false) -> MeshInstance3D:
	for i in range(pool.size()):
		if particles[i].left>0: continue
		var node := pool[i]
		var key := color.to_html()
		if not materials.has(key):
			var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = color
			materials[key] = mat
		node.material_override = materials[key]; node.position = pos; node.rotation = Vector3.ZERO; node.scale = extent; node.show()
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
	if from.distance_squared_to(to)<.0001: return
	var beam := emit_particle((from+to)*.5,Vector3(.04,.04,from.distance_to(to)),color,Vector3.ZERO,.085,true)
	if beam!=null: beam.look_at(to)

func burst(pos: Vector3, color: Color, count: int = 5) -> void:
	var limit := mini(2,count) if MobilePlatform.enabled() else count
	for i in range(mini(limit, pool.size()-active)):
		var size := randf_range(.07,.16)
		var velocity := Vector3(randf_range(-3,3),randf_range(.7,3),randf_range(-3,3))
		emit_particle(pos,Vector3.ONE*size,color,velocity,.29)

func flash(pos: Vector3) -> void:
	burst(pos, Color("fff3a4"), 2)
