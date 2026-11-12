class_name BetaBuild
extends BuildManager
var rotation_step: int = 0
var ghost_good: StandardMaterial3D
var ghost_bad: StandardMaterial3D

func _ready() -> void:
	super._ready()
	ghost_good = VisualFactory.material(Color("a4e886")).duplicate()
	ghost_bad = VisualFactory.material(Color("e47b68")).duplicate()
	for material: StandardMaterial3D in [ghost_good, ghost_bad]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = .4

func set_active(value: bool) -> void:
	active = value and not world.inside and world.phase != "ended"
	preview.visible = active

func _physics_process(_delta: float) -> void:
	if not active:
		return
	if Input.is_action_just_pressed("beta_rotate"):
		rotation_step = (rotation_step + 1) % 4
	var point: Vector3 = world.mouse_ground(world.player.global_position.y)
	location = Vector3(snappedf(point.x, 2), 0, snappedf(point.z, 2))
	location.y = world.outdoor.generator.height_at(Vector2(location.x, location.z))
	preview.global_position = location
	preview.rotation.y = rotation_step * PI * .5
	var data: Dictionary = BetaCatalog.DATA.values.structures[BetaCatalog.STRUCTURES[selected]]
	marker.mesh.size = Vector3(data.size[0], data.size[1], data.size[2])
	marker.position.y = float(data.size[1]) * .5 + .1
	valid = can_place(location)
	marker.material_override = ghost_good if valid else ghost_bad

func can_place(pos: Vector3) -> bool:
	var kind: String = BetaCatalog.STRUCTURES[selected]
	if world.inside or world.phase == "ended" or pos.distance_to(world.player.global_position) > 10 or Vector2(pos.x, pos.z).length() > 64:
		reason = "Construa perto do personagem e a até 64 m do núcleo."
		return false
	if world.inventory.count(kind) <= 0:
		reason = "Fabrique primeiro: " + BetaCatalog.title(kind)
		return false
	if get_tree().get_nodes_in_group("beta_structures").size() >= 80:
		reason = "Limite da Beta: 80 estruturas."
		return false
	var data: Dictionary = BetaCatalog.DATA.values.structures[kind]
	var size := Vector3(data.size[0], data.size[1], data.size[2])
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size - Vector3(.05, .02, .05)
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, rotation_step * PI * .5), pos + Vector3(0, size.y * .5 + .08, 0))
	query.collision_mask = 1 | 2 | 4 | 8
	var exclude: Array[RID] = []
	if kind != "foundation":
		for building in get_tree().get_nodes_in_group("beta_structures"):
			if building.kind == "foundation":
				exclude.append(building.get_rid())
	query.exclude = exclude
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		reason = "Local ocupado."
		return false
	var minimum := INF
	var maximum := -INF
	for corner: Vector2 in [Vector2(-1.8, -1.8), Vector2(1.8, -1.8), Vector2(-1.8, 1.8), Vector2(1.8, 1.8)]:
		var sample := Vector2(pos.x, pos.z) + corner
		var height: float = world.outdoor.generator.height_at(sample)
		minimum = minf(minimum, height)
		maximum = maxf(maximum, height)
		if world.outdoor.generator.is_water(sample):
			reason = "Não construa na água."
			return false
	if maximum - minimum > .6:
		reason = "Terreno inclinado demais."
		return false
	if not connected(pos, kind, size):
		reason = "Preserve um acesso ao núcleo; utilize um portão."
		return false
	reason = "Clique instala · Q gira · botão direito cancela"
	return true

func connected(pos: Vector3, kind: String, size: Vector3) -> bool:
	if kind in ["foundation", "gate"]:
		return true
	var nav := AStarGrid2D.new()
	nav.region = Rect2i(-34, -34, 69, 69)
	nav.cell_size = Vector2(2, 2)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	var obstacles: Array = [{"pos": pos, "size": size, "angle": rotation_step % 2}]
	for building in get_tree().get_nodes_in_group("beta_structures"):
		if building.kind in ["foundation", "gate"]:
			continue
		var data: Dictionary = BetaCatalog.DATA.values.structures[building.kind]
		obstacles.append({"pos": building.position, "size": Vector3(data.size[0], data.size[1], data.size[2]), "angle": roundi(building.rotation.y / (PI * .5)) % 2})
	for obstacle: Dictionary in obstacles:
		var extent := Vector2(obstacle.size.x, obstacle.size.z) * .5 + Vector2(.45, .45)
		if obstacle.angle != 0:
			extent = Vector2(extent.y, extent.x)
		var center := Vector2(obstacle.pos.x, obstacle.pos.z)
		for x in range(floori((center.x - extent.x) / 2), ceili((center.x + extent.x) / 2) + 1):
			for z in range(floori((center.y - extent.y) / 2), ceili((center.y + extent.y) / 2) + 1):
				if nav.is_in_bounds(x, z) and absf(x * 2 - center.x) <= extent.x and absf(z * 2 - center.y) <= extent.y:
					nav.set_point_solid(Vector2i(x, z))
	if nav.is_point_solid(Vector2i.ZERO):
		return false
	for target: Vector2i in [Vector2i(34, 0), Vector2i(-34, 0), Vector2i(0, 34), Vector2i(0, -34)]:
		if not nav.get_id_path(Vector2i.ZERO, target).is_empty():
			return true
	return false

func place() -> Node3D:
	if not active or not can_place(location):
		world.notify(reason)
		return null
	var kind: String = BetaCatalog.STRUCTURES[selected]
	if not world.inventory.remove(kind, 1):
		return null
	world.next_structure += 1
	var building: Node3D = world.create_structure(kind, "built:%d" % world.next_structure, location, rotation_step * PI * .5)
	world.make_noise(location, 16)
	world.outdoor.navigation_dirty = true
	return building
