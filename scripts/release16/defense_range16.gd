class_name DefenseRange16
extends Node3D
var world: Node3D
var drawing := MeshInstance3D.new()
var caption: Label3D
var delay := 0.0
var last_count := 0
func _ready() -> void:
	visible = false
	add_child(drawing)
	caption = VisualFactory.health_label(self,.4); caption.font_size = 22
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	drawing.material_override = mat
func _process(delta: float) -> void:
	# Check before throttling so leaving construction hides coverage this frame.
	if not is_instance_valid(world) or not world.is_inside_tree() or not is_instance_valid(world.player) or not world.builder.active or world.phase=="ended":
		visible = false; delay = 0; return
	delay -= delta
	if delay>0: return
	delay = .2
	var index: int = world.builder.selected
	var tier := 1
	var point: Vector3 = world.builder.location
	var angle: float = world.builder.angle
	if index<0 or index>=FortressData.pieces().size(): visible = false; return
	var piece: Dictionary = FortressData.pieces()[index]
	visible = FortressData.turret(piece.id) or piece.id in ["station","spikes","wire"]
	if not visible: return
	global_position = Vector3(point.x,.10,point.z); rotation.y = 0
	var mesh := ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	last_count = 0
	if piece.id in ["spikes","wire"]:
		var half: Vector3 = piece.size*.5+Vector3(.25,0,.25)
		var corners := [Vector3(-half.x,0,-half.z),Vector3(half.x,0,-half.z),Vector3(half.x,0,half.z),Vector3(-half.x,0,half.z)]
		for i in range(4): triangle(mesh,Vector3.ZERO,corners[i].rotated(Vector3.UP,angle),corners[(i+1)%4].rotated(Vector3.UP,angle),Color(.9,.65,.25,.23))
		caption.text = piece.title+" · área de contato"
	else:
		var radius := FortressData.reach(piece.id,tier)
		var count := 32 if MobilePlatform.enabled() else 64
		var points: Array[Vector3] = []
		var origin := point+Vector3.UP*FortressData.muzzle_height(piece.id)
		for i in range(count+1):
			var v := Vector3(cos(TAU*i/count),0,sin(TAU*i/count))*radius
			if FortressData.turret(piece.id):
				var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point+v+Vector3.UP*1.15,1|8))
				if not hit.is_empty(): v = (hit.position-point)*Vector3(1,0,1)
			points.append(v)
		for i in range(count):
			triangle(mesh,Vector3.ZERO,points[i],points[i+1],Color(.35,.85,.65,.15))
			var a := Vector3(cos(TAU*i/count),0,sin(TAU*i/count))*radius
			var b := Vector3(cos(TAU*(i+1)/count),0,sin(TAU*(i+1)/count))*radius
			triangle(mesh,a*.985,a,b,Color(.65,.95,.55,.65)); triangle(mesh,a*.985,b,b*.985,Color(.65,.95,.55,.65))
		caption.text = piece.title+" · "+str(int(radius))+" m"+(" · cura 5 m / reparo 6 m" if piece.id=="station" else " · obstáculos bloqueiam")
	mesh.surface_end(); drawing.mesh = mesh
func triangle(mesh: ImmediateMesh,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	mesh.surface_set_color(color); mesh.surface_add_vertex(a); mesh.surface_add_vertex(b); mesh.surface_add_vertex(c); last_count += 1
