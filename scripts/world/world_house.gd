class_name WorldHouse
extends Node3D
var world: Node3D
var data: Dictionary
var wall_mesh: MeshInstance3D
var roof_mesh: MeshInstance3D
var faded: bool = false

func _ready() -> void:
	var width: float = data.width
	var depth: float = data.depth
	var commercial: bool = data.kind != "house"
	var wall := Color("b2a78b").lerp(Color("718b7c"), float(data.tone))
	if data.kind in ["barn", "warehouse", "workshop"]:
		wall = Color("765d4b")
	var body := StaticBody3D.new()
	add_child(body)
	wall_mesh = VisualFactory.box(body, Vector3(width, 3.2, depth), Vector3(0, 1.6, 0), wall)
	VisualFactory.collider(body, Vector3(width, 3.2, depth), Vector3(0, 1.6, 0))
	roof_mesh = VisualFactory.box(body, Vector3(width + .7, .35, depth + .7), Vector3(0, 3.35, 0), Color("3b4a48"))
	for side in [-1, 1]:
		VisualFactory.box(body, Vector3(1.6, 1.1, .09), Vector3(side * width * .31, 1.8, -depth * .5 - .06), Color("527b80"))
		VisualFactory.box(body, Vector3(1.75, .14, .17), Vector3(side * width * .31, 1.2, -depth * .5 - .08), Color("d1c3a5"))
	VisualFactory.box(body, Vector3(1.5, 2.3, .12), Vector3(0, 1.15, -depth * .5 - .08), Color("524f3e"))
	VisualFactory.box(body, Vector3(width + 1, .1, depth + 1), Vector3(0, .01, 0), Color("787969"))
	if commercial:
		VisualFactory.box(body, Vector3(width * .85, .7, .3), Vector3(0, 2.7, -depth * .5 - .25), Color("344e4b"))
	var entry: WorldInteraction = world.new_interaction() if world.has_method("new_interaction") else WorldInteraction.new()
	entry.world = world
	entry.id = str(data.id) + ":entry"
	entry.kind = "entry"
	entry.data = data.duplicate(true)
	entry.data.title = WorldGenerator.building_title(data.kind)
	entry.position = Vector3(0, 0, -depth * .5 - 1.4)
	add_child(entry)
	var sign := VisualFactory.health_label(self, 4.5)
	sign.font_size = 22
	sign.text = str(entry.data.title).to_upper()
	# A path joins each entrance to the street; generation reserves it from vegetation.
	VisualFactory.box(self, Vector3(1.6, .03, 3.4), Vector3(0, .025, -depth * .5 - 1.7), Color("aa9b78"))
	if data.kind == "barn":
		for row in range(4):
			VisualFactory.box(self, Vector3(width, .16, .5), Vector3(0, .1, depth * .5 + 2 + row), Color("6c8050"))

func _process(_delta: float) -> void:
	if not is_instance_valid(world.player) or world.inside:
		return
	var relative: Vector3 = world.player.global_position - global_position
	var should_fade := relative.length() < 10 and relative.z < 1
	if should_fade == faded:
		return
	faded = should_fade
	for mesh: MeshInstance3D in [wall_mesh, roof_mesh]:
		var material: StandardMaterial3D = mesh.material_override.duplicate()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if faded else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = .2 if faded else 1.0
		mesh.material_override = material
