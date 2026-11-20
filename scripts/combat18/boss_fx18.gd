class_name BossFx18
extends Node3D

const COLORS := {
	"area": Color("e9a269"), "line": Color("ffd98b"), "acid": Color("a9e558"),
	"thorn": Color("e8b774"), "snare": Color("a7e383"), "wind": Color("c7f1dc"),
	"quakes": Color("e49f72"), "stakes": Color("ae7451"), "vines": Color("639b43"),
	"howl": Color("f2cb82"), "howl_wave": Color("e8d4a0"), "brood": Color("ae9a71"), "claw": Color("f5ab88"),
	"clay": Color("d38c69"), "square": Color("df9979"), "mold": Color("a77c60"), "clay_cage": Color("ba8767"),
	"burst_warning": Color("ffc080"), "rupture": Color("ff923f"), "rupture_wave": Color("ffc270"),
	"spore_warning": Color("d699ef"), "mushrooms": Color("bd72d3"),
}

var world: Node3D
var data: Dictionary
var elapsed := 0.0
var region_key := ""
var fragments: MultiMesh
var fragment_offsets := PackedVector3Array()
var fragment_bases: Array[Basis] = []
var kind := ""
var extent := 0.0
var width := 0.0
var lifetime := 0.0

static var warning_meshes: Dictionary
static var warning_materials: Dictionary
static var fragment_mesh: Mesh
static var fungus_mesh: SphereMesh
static var solid_material: StandardMaterial3D
static var light_material: StandardMaterial3D
static var warmed := false

static func warm_render(owner_world: Node3D) -> void:
	if warmed or DisplayServer.get_name() == "headless": return
	var stage := Node3D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	owner_world.add_child(stage)
	var focus: Vector3 = owner_world.player.global_position
	stage.global_position = focus - Vector3.UP * .8
	var samples := ["area", "line", "square", "mold", "wind", "howl", "mushrooms"]
	for i in range(samples.size()):
		var effect := from_state(owner_world, {"p":focus,"dir":Vector3.FORWARD,"fx18":samples[i],
			"s":1.0,"w":.5,"life":1.0,"age":.35,"warning":i<3})
		effect.position = Vector3((i % 4) * .32 - .48, 0, floorf(i / 4.0) * .4)
		effect.scale = Vector3.ONE * .13
		stage.add_child(effect)
	await RenderingServer.frame_post_draw
	if is_instance_valid(stage):
		warmed = true
		stage.queue_free()

static func prepare() -> void:
	if fragment_mesh != null: return
	fragment_mesh = ClayStyle.rounded_box(Vector3.ONE)
	fragment_mesh.get_rid()
	fungus_mesh = SphereMesh.new()
	fungus_mesh.radius = .5
	fungus_mesh.height = 1.0
	fungus_mesh.radial_segments = 10
	fungus_mesh.rings = 4
	fungus_mesh.get_rid()
	solid_material = fragment_material(false)
	light_material = fragment_material(true)
	warning_meshes = {
		"circle": build_warning("circle"),
		"line": build_warning("line"),
		"square": build_warning("square"),
		"ring": build_warning("ring"),
	}
	for id in ["area", "acid", "thorn", "snare", "line", "square", "burst_warning", "spore_warning"]:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = COLORS[id]
		material.get_rid()
		warning_materials[id] = material

static func fragment_material(unshaded: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .9
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.get_rid()
	return material

static func build_warning(shape: String) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if shape in ["circle", "ring"]:
		for i in range(32):
			var a := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 32.0)
			var b := Vector3.FORWARD.rotated(Vector3.UP, TAU * (i + 1) / 32.0)
			var inner := .94 if shape == "ring" else .973
			if shape == "circle": triangle(surface, Vector3.ZERO, a * inner, b * inner, .21)
			quad(surface, a * inner, b * inner, b, a, 1.0)
		if shape == "circle":
			for i in range(8):
				var angle := TAU * i / 8.0
				var center := Vector3(0,.01,-.885).rotated(Vector3.UP, angle)
				var right := Vector3.RIGHT.rotated(Vector3.UP, angle) * .013
				var front := Vector3.FORWARD.rotated(Vector3.UP, angle) * .06
				quad(surface, center-right-front, center+right-front, center+right+front, center-right+front, .92)
	else:
		var near_edge := 0.0 if shape == "line" else 1.0
		var far_edge := -1.0
		rectangle(surface, -1, 1, far_edge, near_edge, 0, .21)
		rectangle(surface, -.999, -.963, far_edge, near_edge, .012, 1)
		rectangle(surface, .963, .999, far_edge, near_edge, .012, 1)
		if shape == "line":
			for i in range(1, 5):
				var z := -i / 5.0
				var tip := Vector3(0,.013,z-.026)
				var notch := Vector3(0,.013,z-.016)
				for side in [-1, 1]:
					quad(surface, tip, Vector3(side*.34,.013,z), Vector3(side*.34,.013,z+.01), notch, .92)
		else:
			rectangle(surface, -1, 1, far_edge, far_edge+.036, .012, 1)
			rectangle(surface, -1, 1, near_edge-.036, near_edge, .012, 1)
	var mesh := surface.commit()
	mesh.get_rid()
	return mesh

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, opacity: float) -> void:
	surface.set_color(Color(1,1,1,opacity))
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, opacity: float) -> void:
	triangle(surface, a, b, c, opacity)
	triangle(surface, a, c, d, opacity)

static func rectangle(surface: SurfaceTool, left: float, right: float, back: float, front: float, y: float, opacity: float) -> void:
	quad(surface, Vector3(left,y,back), Vector3(right,y,back), Vector3(right,y,front), Vector3(left,y,front), opacity)

static func spawn(owner_world: Node3D, kind: String, point: Vector3, heading: Vector3, size: float, width: float, duration: float) -> Node3D:
	var row := {
		"id": owner_world.next_id(), "fx18": kind, "p": point, "dir": heading,
		"s": size, "w": width, "life": duration,
		"warning": kind in ["line", "square", "area", "acid", "thorn", "snare", "burst_warning", "spore_warning"],
	}
	var node := from_state(owner_world, row)
	owner_world.effects.add_child(node)
	node.add_to_group("boss_fx18")
	return node

static func from_state(owner_world: Node3D, row: Dictionary) -> BossFx18:
	var node := BossFx18.new()
	node.world = owner_world
	node.data = row.duplicate()
	node.position = row.p
	node.elapsed = float(row.get("age", 0.0))
	node.region_key = owner_world.region_at(row.p)
	return node

func _ready() -> void:
	prepare()
	var direction: Vector3 = data.dir
	if direction.length_squared() > .01:
		rotation.y = atan2(-direction.x, -direction.z)
	kind = data.fx18
	extent = data.s
	width = data.w
	lifetime = data.life
	if in_local_sector(): create_visual()

func in_local_sector() -> bool:
	return world.player == null or world.region_at(world.player.global_position) == region_key

func create_visual() -> void:
	if data.warning:
		create_warning()
	else:
		if kind == "mushrooms": create_warning("spore_warning")
		create_fragments()
		update_visual()

func create_warning(material_id := "") -> void:
	var shape := kind if kind in ["line", "square"] else "circle"
	var mesh := MeshInstance3D.new()
	mesh.mesh = warning_meshes[shape]
	mesh.material_override = warning_materials[kind if material_id.is_empty() else material_id]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.scale = Vector3(width if shape == "line" else extent, 1, extent)
	mesh.position.y = .07
	add_child(mesh)

func create_fragments() -> void:
	var count := 8 if MobilePlatform.lightweight() else 12
	var ring := kind in ["howl", "howl_wave", "rupture_wave"]
	match kind:
		"wind", "clay": count = 7 if MobilePlatform.lightweight() else 13
		"mold": count = 4
		"claw": count = 3
		"howl", "howl_wave", "rupture_wave": count = 2
		"mushrooms": count = 10 if MobilePlatform.lightweight() else 14
	var node := MultiMeshInstance3D.new()
	fragments = MultiMesh.new()
	fragments.transform_format = MultiMesh.TRANSFORM_3D
	fragments.use_colors = true
	fragments.mesh = warning_meshes.ring if ring else fungus_mesh if kind == "mushrooms" else fragment_mesh
	fragments.instance_count = count
	var bounds := extent * 1.25 + 1.0
	fragments.custom_aabb = AABB(Vector3(-bounds,-.2,-bounds), Vector3(bounds*2,3,bounds*2))
	node.multimesh = fragments
	node.material_override = light_material if ring or kind in ["wind","clay","claw","rupture"] else solid_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fragment_offsets.resize(count)
	fragment_bases.resize(count)
	var color: Color = COLORS[kind]
	for i in range(count):
		var origin := Vector3.ZERO
		var dimensions := Vector3.ONE
		var rotation := Vector3.ZERO
		var tone := color
		match kind:
			"wind", "clay":
				var dust := kind == "wind" and i % 3 == 1
				if dust: tone = Color("c69872")
				dimensions = Vector3(.19,.16,.7 if kind == "wind" and not dust else .39)
				origin.x = (float(i % 5) / 4.0 * 2.0 - 1.0) * width*.85
			"mold":
				dimensions = Vector3(extent,2.58,extent)
				origin = Vector3((i%2-.5)*extent,0,(floorf(i/2.0)-.5)*extent)
			"claw":
				dimensions = Vector3(.095,.085,extent*.94)
				origin = Vector3((i-1)*.33,.68,-extent*.55)
				rotation.z = -.25
			"howl", "howl_wave", "rupture_wave":
				origin.y = .10 + .14*i if kind == "rupture_wave" else .25 + .38*i
				dimensions = Vector3(extent,1,extent)
				if i == 1: tone = color.lightened(.28)
			"rupture":
				var angle := i * 2.39996
				origin = Vector3(cos(angle),0,sin(angle)) * extent * (.48+.11*float(i%5))
				dimensions = Vector3(.30,.32,.48)
				rotation = Vector3(i*.25,angle,.4)
				tone = color.lerp(Color("fff1a3"),float(i%4)*.22)
			"mushrooms":
				if i < 6:
					var group := floori(i*.5)
					var angle := group*TAU/3.0 + .6
					var size := 1.0 - group*.15
					var cap := i%2 == 1
					origin = Vector3(cos(angle)*.74,(.57 if cap else .27)*size,sin(angle)*.74)
					dimensions = (Vector3(.83,.44,.83) if cap else Vector3(.22,.59,.22))*size
					if not cap: tone = Color("e8d4df")
				else:
					var angle := i*2.39996
					origin = Vector3(cos(angle)*extent*.56,.41+.32*(i%3),sin(angle)*extent*.56)
					dimensions = Vector3(.58,.45,.58)
					tone = Color("bfa8d0").darkened(.06*(i%3))
			_:
				var angle := i * 2.39996
				var radius := extent * (.4 + float(i % 5) * .13)
				origin = Vector3(cos(angle)*radius,0,sin(angle)*radius)
				dimensions = Vector3(.22,1.1 if kind == "stakes" else .73,.22)
				rotation = Vector3(cos(angle)*.34,angle,sin(angle)*.34)
		fragment_offsets[i] = origin
		fragment_bases[i] = Basis.from_euler(rotation).scaled_local(dimensions)
		fragments.set_instance_color(i, tone)
	add_child(node)

func update_visual() -> void:
	var progress := clampf(elapsed / lifetime, 0, 1)
	var fade := 1.0 - smoothstep(.73,1.0,progress)
	var rise := smoothstep(0,.055 if kind in ["vines","clay_cage"] else .24,progress)
	for i in range(fragment_offsets.size()):
		var origin := fragment_offsets[i]
		var frame := fragment_bases[i]
		match kind:
			"wind", "clay":
				var flow := clampf(progress*1.25 - float(i%4)*.072,0,1) if kind == "wind" else maxf(0,progress - float(i%4)*.034)
				origin.z = -extent*flow
				origin.y = .29 + float(i%5)*.16 + sin(progress*TAU+i)*.2
				frame = frame.rotated(Vector3.RIGHT,progress*4+i).scaled(Vector3.ONE*maxf(.001,fade))
			"mold":
				var height := mold_height(i, progress)
				origin.y = 1.29 * height
				frame = frame.scaled_local(Vector3(1,maxf(.001,height),1))
			"howl", "howl_wave":
				var reach := maxf(.06,progress*1.17 - i*.16)
				frame = frame.scaled_local(Vector3(reach,1,reach))
			"rupture_wave":
				var reach := maxf(.02,smoothstep(0.0,.72,progress)-i*.14)
				frame = frame.scaled_local(Vector3(reach,1,reach))
			"rupture":
				var out := smoothstep(0.0,.89,progress)
				origin *= .04+.96*out
				origin.y = .13+sin(PI*progress)*(.55+.18*(i%4))
				frame = frame.rotated(Vector3.RIGHT,progress*(3.3+i*.16))
				frame = frame.scaled_local(Vector3.ONE*maxf(.001,fade))
			"mushrooms":
				var grown := smoothstep(0.0,width,elapsed)*fade
				if i < 6:
					origin.y *= grown
					frame = frame.scaled_local(Vector3.ONE*maxf(.001,grown))
				else:
					var haze := smoothstep(width,width+.30,elapsed)*fade
					origin = origin.rotated(Vector3.UP,elapsed*(.18+.05*(i%3)))
					origin.y += .28*sin(elapsed*2.2+i)
					frame = frame.scaled_local(Vector3.ONE*maxf(.001,haze))
			"claw":
				frame = frame.scaled_local(Vector3.ONE*maxf(.001,1.0-smoothstep(.25,1.0,progress)))
			_:
				origin.y = (.13 + float(i%3)*.17) * rise * fade
				frame = frame.scaled_local(Vector3(1,maxf(.001,rise*fade),1))
		fragments.set_instance_transform(i,Transform3D(frame,origin))

static func mold_height(piece: int, progress: float) -> float:
	return smoothstep(float(piece)*.055,.47,progress) * (1.0-smoothstep(.62,1.0,progress))

func _process(delta: float) -> void:
	if world.combat_paused(): return
	elapsed += delta
	if elapsed >= lifetime:
		if world.is_client:
			hide()
			set_process(false)
		else: queue_free()
		return
	if not in_local_sector():
		hide()
		return
	show()
	if get_child_count() == 0: create_visual()
	elif fragments != null: update_visual()

func state() -> Dictionary:
	var row := data.duplicate()
	row.age = elapsed
	return row
