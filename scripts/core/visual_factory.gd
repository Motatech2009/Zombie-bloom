class_name VisualFactory
extends RefCounted
## All geometry is original and generated locally. No external assets required.
static var materials: Dictionary = {}
static var clay_enabled: bool = true

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key := color.to_html() + str(glow)+str(MobilePlatform.lightweight())
	if not materials.has(key):
		var mat := StandardMaterial3D.new() if glow or not clay_enabled else ClayStyle.material(color)
		mat.albedo_color = color
		mat.roughness = 0.9
		if glow:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = .25
		materials[key] = mat
	return materials[key]

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh: Mesh = ClayStyle.rounded_box(size) if clay_enabled else BoxMesh.new()
	if mesh is BoxMesh: mesh.size = size
	return mesh_node(parent, mesh, pos, color, glow)

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return mesh_node(parent, mesh, pos, color, glow)

static func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, glow)
	parent.add_child(node)
	node.position = pos
	return node

static func collider(parent: CollisionObject3D, size: Vector3, pos: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = pos
	parent.add_child(node)
	return node

static func human(parent: Node3D, color: Color, armed: bool) -> Node3D:
	var rig := Node3D.new()
	parent.add_child(rig)
	box(rig, Vector3(.65, .75, .38), Vector3(0, 1.05, 0), color)
	box(rig, Vector3(.68, .18, .42), Vector3(0, .69, 0), Color("27353c"))
	box(rig, Vector3(.41, .43, .4), Vector3(0, 1.65, 0), Color("c9b58b") if armed else color.lightened(.22))
	box(rig, Vector3(.43, .14, .43), Vector3(0, 1.87, 0), Color("263e42"))
	box(rig, Vector3(.28, .075, .025), Vector3(0, 1.68, -.21), Color("bfe96e") if armed else Color("ef725c"), true)
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		rig.add_child(leg)
		leg.position = Vector3(side * .19, .7, 0)
		box(leg, Vector3(.25, .63, .29), Vector3(0, -.31, 0), Color("344149"))
		box(leg, Vector3(.27, .17, .42), Vector3(0, -.63, -.06), Color("19272c"))
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		rig.add_child(arm)
		arm.position = Vector3(side * .43, 1.33, 0)
		box(arm, Vector3(.22, .62, .24), Vector3(0, -.28, 0), color.darkened(.15))
		if armed:
			arm.rotation.x = 1.1
	if armed:
		var gun := box(rig, Vector3(.16, .16, .9), Vector3(.34, 1.1, -.64), Color("17272d"))
		gun.name = "Gun"
		box(rig, Vector3(.14, .07, .18), Vector3(.34, 1.2, -.56), Color("c8df73"))
		box(rig, Vector3(.42, .5, .22), Vector3(0, 1.08, .27), Color("8b8252"))
	return rig

static func animate_human(rig: Node3D, clock: float, moving: float, recoil: float, armed: bool) -> void:
	if rig.has_meta("mobile_batch"):
		var now := Time.get_ticks_msec()
		if now-int(rig.get_meta("animation_at",-100))<50: return
		rig.set_meta("animation_at",now)
	var stride := sin(clock * 11.0) * minf(moving, 1.0) * .65
	rig.get_node("LegL").rotation.x = stride
	rig.get_node("LegR").rotation.x = -stride
	rig.get_node("ArmL").rotation.x = (1.1 if armed else .7) - stride * .16 - recoil*.25
	rig.get_node("ArmR").rotation.x = (1.1 if armed else .7) + stride * .16 - recoil*.25
	rig.get_node("ArmL").rotation.z = .12 if armed else .05
	rig.get_node("ArmR").rotation.z = -.08 if armed else -.05
	rig.position.y = absf(sin(clock * 11.0)) * .055 * moving
	rig.rotation.z = sin(clock * 5.0) * .025

static func ring(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - .035
	mesh.outer_radius = radius + .035
	mesh.rings = 32
	mesh.ring_segments = 6
	return mesh_node(parent, mesh, pos, color, true)

static func health_label(parent: Node3D, height: float) -> Label3D:
	var label := Label3D.new()
	parent.add_child(label)
	label.position.y = height
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = .015
	label.outline_size = 8
	label.modulate = Color("dcf1dc")
	return label

static func lighting(parent: Node3D) -> DirectionalLight3D:
	var env := WorldEnvironment.new()
	var data := Environment.new()
	data.background_mode = Environment.BG_COLOR
	data.background_color = Color("091a22")
	data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	data.ambient_light_color = Color("9cb9c3")
	data.ambient_light_energy = .72
	data.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = data
	parent.add_child(env)
	var light := DirectionalLight3D.new()
	parent.add_child(light)
	light.rotation_degrees = Vector3(-52, -30, 0)
	light.light_color = Color("c6d9cf")
	light.light_energy = 1.25
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 80
	return light
