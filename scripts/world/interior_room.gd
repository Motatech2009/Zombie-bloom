class_name InteriorRoom
extends Arena
var world: Node3D
var data: Dictionary
var plan: Dictionary
const EXTENT := 9.0

func _ready() -> void:
	plan = world.outdoor.generator.interior_plan(data.id, data.kind)
	var split_x: float = plan.split_x
	var split_z: float = plan.split_z
	var colors := [Color("b3a283"), Color("91a18d"), Color("8899a0"), Color("afa994")]
	for x in range(2):
		for z in range(2):
			var min_x := -EXTENT if x == 0 else split_x
			var max_x := split_x if x == 0 else EXTENT
			var min_z := -EXTENT if z == 0 else split_z
			var max_z := split_z if z == 0 else EXTENT
			VisualFactory.box(self, Vector3(max_x - min_x, .18, max_z - min_z), Vector3((max_x + min_x) * .5, -.12, (max_z + min_z) * .5), colors[z * 2 + x])
			var tag := VisualFactory.health_label(self, .05)
			tag.position = Vector3((max_x + min_x) * .5, .05, (max_z + min_z) * .5)
			tag.text = plan.rooms[z * 2 + x].to_upper()
			tag.font_size = 19
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	VisualFactory.collider(floor_body, Vector3(18, .3, 18), Vector3(0, -.2, 0))
	wall(Vector3(0, 1.4, -9), Vector3(18, 2.8, .3))
	wall(Vector3(-9, 1.4, 0), Vector3(.3, 2.8, 18))
	# Foreground walls are kept low visually; their full-height collision is retained.
	wall(Vector3(9, 1.4, 0), Vector3(.3, 2.8, 18), true)
	wall(Vector3(0, 1.4, 9), Vector3(18, 2.8, .3), true)
	partition(Vector3(split_x, 0, (-9 + split_z) * .5), Vector3(.2, 2.6, split_z + 9), true, -4)
	partition(Vector3((-9 + split_x) * .5, 0, split_z), Vector3(split_x + 9, 2.6, .2), false, -4)
	partition(Vector3((9 + split_x) * .5, 0, split_z), Vector3(9 - split_x, 2.6, .2), false, 4)
	wall(Vector3(split_x, 1.3, (split_z + 9) * .5), Vector3(.2, 2.6, 9 - split_z), true)
	# Furniture stays against exterior walls, clear of the connected circulation cross.
	if data.kind == "house":
		furniture(Vector3(-6, 0, -7), Vector3(3, .85, 1.2), Color("54664e"))
		furniture(Vector3(5, 0, -7), Vector3(5, .95, .9), Color("65776b"))
		furniture(Vector3(-6, 0, 6.5), Vector3(2.8, .6, 3.3), Color("72898b"))
		furniture(Vector3(6.5, 0, 6.5), Vector3(1.6, .8, 1.6), Color("c5c5ad"))
	else:
		furniture(Vector3(-6, 0, -7), Vector3(4, 1.1, 1.2), Color("8f8266"))
		furniture(Vector3(5, 0, -7), Vector3(5, 1.6, .9), Color("65776b"))
		furniture(Vector3(-6, 0, 6.5), Vector3(3, 1.3, 1.3), Color("72898b"))
		furniture(Vector3(6.5, 0, 6.5), Vector3(1.6, 1.8, 1.6), Color("a49371"))
	for i in range(2):
		var loot: WorldInteraction = world.new_interaction() if world.has_method("new_interaction") else WorldInteraction.new()
		loot.world = world
		loot.id = str(data.id) + ":container:%d" % i
		loot.kind = "container"
		loot.data = {"units": 12}
		loot.position = Vector3(-7 if i == 0 else 7, 0, -2)
		add_child(loot)
	var exit: WorldInteraction = world.new_interaction() if world.has_method("new_interaction") else WorldInteraction.new()
	exit.world = world
	exit.id = str(data.id) + ":exit"
	exit.kind = "exit"
	exit.data = {}
	exit.position = Vector3(-3, 0, -7.5)
	add_child(exit)
	# Windows are visual states in this prototype; no view into the exterior scene.
	if not world.has_method("container_for"):
		for x in [-5, 5]:
			VisualFactory.box(self, Vector3(1.7, 1, .05), Vector3(x, 1.6, -8.82), Color("719ba0"))
	navigation.region = Rect2i(-9, -9, 19, 19)
	navigation.cell_size = Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()

func wall(pos: Vector3, size: Vector3, low: bool = false) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	VisualFactory.collider(body, size, pos)
	var visual_size := size
	visual_size.y = .65 if low else size.y
	var visual_pos := pos
	visual_pos.y = visual_size.y * .5
	VisualFactory.box(body, visual_size, visual_pos, Color("56645b"))
	VisualFactory.box(body, Vector3(size.x + .05, .08, size.z + .05), Vector3(pos.x, visual_size.y, pos.z), Color("a8ae91"))

func partition(center_pos: Vector3, size: Vector3, along_z: bool, opening: float) -> void:
	var minimum := center_pos.z - size.z * .5 if along_z else center_pos.x - size.x * .5
	var maximum := center_pos.z + size.z * .5 if along_z else center_pos.x + size.x * .5
	for bounds: Vector2 in [Vector2(minimum, opening - .9), Vector2(opening + .9, maximum)]:
		if bounds.y <= bounds.x:
			continue
		var pos := center_pos
		var part := size
		if along_z:
			pos.z = (bounds.x + bounds.y) * .5
			part.z = bounds.y - bounds.x
		else:
			pos.x = (bounds.x + bounds.y) * .5
			part.x = bounds.y - bounds.x
		pos.y = size.y * .5
		wall(pos, part, true)
	var door: WorldInteraction = world.new_interaction() if world.has_method("new_interaction") else WorldInteraction.new()
	door.world = world
	door.kind = "door"
	door.id = str(data.id) + ":door:%s:%s" % [along_z, opening]
	door.data = {}
	door.position = Vector3(center_pos.x, 0, opening) if along_z else Vector3(opening, 0, center_pos.z)
	if along_z:
		door.rotation.y = PI * .5
	add_child(door)

func furniture(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	VisualFactory.box(body, size, pos + Vector3(0, size.y * .5, 0), color)
	VisualFactory.collider(body, size, pos + Vector3(0, size.y * .5, 0))

func route(_from: Vector3, _to: Vector3) -> PackedVector2Array:
	return PackedVector2Array() # No indoor enemies in the first world slice.
