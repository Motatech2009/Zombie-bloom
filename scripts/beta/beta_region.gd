class_name BetaRegion
extends StreamedRegion

func _ready() -> void:
	generator = BetaGenerator.new(world.state.world_seed)
	focus(Vector3.ZERO, true)

func terrain(parent: Node3D, coord: Vector2i) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gen: BetaGenerator = generator
	var origin := Vector2(coord * WorldGenerator.SECTOR_SIZE)
	var height_data := PackedFloat32Array()
	var heights: Dictionary = {}
	for z in range(33):
		for x in range(33):
			var height := gen.height_at(origin + Vector2(x * 2, z * 2))
			height_data.append(height)
			heights[Vector2i(x, z)] = height
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = Vector3(origin.x + 32, 0, origin.y + 32)
	var shape := HeightMapShape3D.new()
	shape.map_width = 33
	shape.map_depth = 33
	shape.map_data = height_data
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3(2, 1, 2)
	body.add_child(collision)
	var water_barrier := StaticBody3D.new()
	parent.add_child(water_barrier)
	for x in range(32):
		for z in range(32):
			var point := origin + Vector2(x * 2 + 1, z * 2 + 1)
			var noise := gen.detail.get_noise_2d(point.x, point.y)
			var color := Color("52664b").lerp(Color("819264"), noise * .5 + .5)
			var water := gen.river_distance(point) < 5.5
			if gen.river_distance(point) < 10:
				color = Color("899979")
			if gen.road_distance(point) < 0:
				color = Color("6c6d59")
			if water:
				color = Color("347c89") if gen.is_water(point) else Color("ab9e7b")
				if gen.is_water(point):
					VisualFactory.collider(water_barrier, Vector3(2, 4, 2), Vector3(point.x, 1, point.y))
			for index: Vector2i in [Vector2i(x, z), Vector2i(x, z + 1), Vector2i(x + 1, z), Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1)]:
				surface.set_color(color)
				surface.set_normal(Vector3.UP)
				var y: float = heights[index]
				if water:
					y = -.08 if gen.is_water(point) else .035
				surface.add_vertex(Vector3(origin.x + index.x * 2, y, origin.y + index.y * 2))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	parent.add_child(mesh)
	add_grass(parent, coord)
	if coord == Vector2i.ZERO:
		VisualFactory.ring(parent, 18, Vector3(0, .08, 0), Color("93a874"))

func reload_all() -> void:
	for node: Node3D in sectors.values():
		remove_child(node)
		node.queue_free()
	sectors.clear()
	pending.clear()
	generator = BetaGenerator.new(world.state.world_seed)
	center = Vector2i(99999, 99999)
	focus(world.player.global_position, true)

func rebuild_navigation() -> void:
	super.rebuild_navigation()
	if is_instance_valid(world.core):
		mark_solid(world.core.global_position, Vector2(4.2, 4.2))
	for building in get_tree().get_nodes_in_group("beta_structures"):
		if building.kind == "foundation" or (building.kind == "gate" and building.opened):
			continue
		var data: Dictionary = BetaCatalog.DATA.values.structures[building.kind]
		var size := Vector2(data.size[0], data.size[2])
		if posmod(roundi(building.rotation.y / (PI * .5)), 2) != 0:
			size = Vector2(size.y, size.x)
		mark_solid(building.global_position, size + Vector2.ONE)

func add_grass(parent: Node3D, coord: Vector2i) -> void:
	var rng := generator.rng_for("grass:" + WorldGenerator.sector_key(coord))
	var transforms: Array[Transform3D] = []
	for i in range(70):
		var pos := Vector2(coord * 64) + Vector2(rng.randf_range(2, 62), rng.randf_range(2, 62))
		if generator.reserved(pos, .3):
			continue
		var transform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(pos.x, generator.height_at(pos) + .15, pos.y))
		transforms.append(transform)
	var mesh := CylinderMesh.new()
	mesh.top_radius = .02
	mesh.bottom_radius = .18
	mesh.height = .35
	mesh.radial_segments = 3
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = VisualFactory.material(Color("809b55"))
	parent.add_child(node)
