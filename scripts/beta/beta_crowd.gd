class_name BetaCrowd
extends Node3D
## Instanced articulated crowd: a fixed number of draw calls instead of one per limb/enemy.
var parts: Array[Dictionary] = []
const LIMIT := BetaEvents.MAX_ACTORS

func _ready() -> void:
	part("", Vector3(.65, .75, .38), Vector3(0, 1.05, 0), "body")
	part("", Vector3(.68, .18, .42), Vector3(0, .69, 0), "dark")
	part("", Vector3(.41, .43, .4), Vector3(0, 1.65, 0), "skin")
	part("", Vector3(.43, .14, .43), Vector3(0, 1.87, 0), "dark")
	part("", Vector3(.28, .075, .025), Vector3(0, 1.68, -.21), "eyes")
	for side: String in ["L", "R"]:
		part("Leg" + side, Vector3(.25, .63, .29), Vector3(0, -.31, 0), "dark")
		part("Leg" + side, Vector3(.27, .17, .42), Vector3(0, -.63, -.06), "boots")
		part("Arm" + side, Vector3(.22, .62, .24), Vector3(0, -.28, 0), "body")

func part(bone: String, size: Vector3, offset: Vector3, tint: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = LIMIT
	multi.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .9
	if tint == "eyes":
		material.emission_enabled = true
		material.emission = Color("ee705a")
		material.emission_energy_multiplier = .25
	node.material_override = material
	add_child(node)
	parts.append({"multi": multi, "bone": bone, "offset": offset, "tint": tint})

func _process(_delta: float) -> void:
	var actors := get_tree().get_nodes_in_group("beta_enemies").filter(func(actor): return actor.is_inside_tree() and not actor.is_queued_for_deletion())
	var count := mini(actors.size(), LIMIT)
	for data: Dictionary in parts:
		var multi: MultiMesh = data.multi
		multi.visible_instance_count = count
		for i in range(count):
			var enemy: Node3D = actors[i]
			var transform: Transform3D = enemy.rig.global_transform
			if not str(data.bone).is_empty():
				transform = transform * enemy.rig.get_node(data.bone).transform
			transform = transform * Transform3D(Basis.IDENTITY, data.offset)
			multi.set_instance_transform(i, transform)
			var color: Color = enemy.spec.color
			match data.tint:
				"skin": color = color.lightened(.2)
				"dark": color = Color("344149")
				"boots": color = Color("19272c")
				"eyes": color = Color("ee705a")
			multi.set_instance_color(i, color)
