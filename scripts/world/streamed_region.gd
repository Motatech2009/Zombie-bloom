class_name StreamedRegion
extends Arena
const RADIUS := 1
var world: Node3D
var generator: WorldGenerator
var sectors: Dictionary = {}
var pending: Array[Vector2i] = []
var center := Vector2i(99999, 99999)
var navigation_dirty := true
var nav_origin := Vector2i.ZERO
var tick: float = 0

func _ready() -> void:
	generator = WorldGenerator.new(world.state.world_seed)
	focus(Vector3.ZERO, true)

func _process(delta: float) -> void:
	if world.inside:
		return
	focus(world.player.global_position)
	if not pending.is_empty():
		load_sector(pending.pop_front())
		navigation_dirty = true
	tick -= delta
	if navigation_dirty and tick <= 0:
		rebuild_navigation()
		tick = .35

func focus(pos: Vector3, immediate: bool = false) -> void:
	var coord := WorldGenerator.sector_at(pos)
	if coord == center and not immediate:
		return
	center = coord
	var wanted: Array[Vector2i] = [Vector2i.ZERO] # Keep the refuge ground resident.
	for x in range(-RADIUS, RADIUS + 1):
		for z in range(-RADIUS, RADIUS + 1):
			var target := coord + Vector2i(x, z)
			if not wanted.has(target):
				wanted.append(target)
	pending.clear()
	for key: Vector2i in sectors.keys():
		if not wanted.has(key):
			var node: Node3D = sectors[key]
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.hide()
			node.queue_free()
			sectors.erase(key)
	# Load the player's own ground before simulation advances; ring sectors are budgeted.
	if not sectors.has(coord):
		load_sector(coord)
	for target in wanted:
		if not sectors.has(target):
			if immediate:
				load_sector(target)
			else:
				pending.append(target)
	navigation_dirty = true
	if immediate:
		rebuild_navigation()

func load_sector(coord: Vector2i) -> void:
	if sectors.has(coord):
		return
	var sector := Node3D.new()
	sector.name = "Sector_" + WorldGenerator.sector_key(coord).replace(":", "_")
	add_child(sector)
	sectors[coord] = sector
	world.state.explored[WorldGenerator.sector_key(coord)] = true
	terrain(sector, coord)
	var data: Dictionary = generator.sector_data(coord)
	for house_data: Dictionary in data.buildings:
		var house := WorldHouse.new()
		house.world = world
		house.data = house_data
		house.position = Vector3(house_data.pos.x, 0, house_data.pos.y)
		sector.add_child(house)
	for prop_data: Dictionary in data.resources:
		var prop: WorldInteraction = world.new_interaction() if world.has_method("new_interaction") else WorldInteraction.new()
		prop.world = world
		prop.id = prop_data.id
		prop.kind = prop_data.kind
		prop.data = prop_data
		prop.position = Vector3(prop_data.pos.x, generator.height_at(prop_data.pos) if generator.has_method("height_at") else 0, prop_data.pos.y)
		sector.add_child(prop)
	if coord == Vector2i.ZERO:
		VisualFactory.ring(sector, 18, Vector3(0, .035, 0), Color("879c64"))
		var sign := VisualFactory.health_label(sector, 3)
		sign.position = Vector3(-5, 3, -7)
		sign.font_size = 24
		sign.text = "ÚLTIMO REFÚGIO\nDEPÓSITO · " + ("E" if world.has_method("new_interaction") else "F")

func terrain(parent: Node3D, coord: Vector2i) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := Vector2(coord * WorldGenerator.SECTOR_SIZE)
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = Vector3(origin.x, 0, origin.y)
	VisualFactory.collider(body, Vector3(64, .4, 64), Vector3(32, -.23, 32))
	var river_body := StaticBody3D.new()
	parent.add_child(river_body)
	var size := WorldGenerator.CELL
	for x in range(0, 64, size):
		for z in range(0, 64, size):
			var point := origin + Vector2(x + size * .5, z + size * .5)
			var noise := generator.detail.get_noise_2d(point.x, point.y)
			var color := Color("52664b").lerp(Color("748459"), noise * .5 + .5)
			var y := 0.0
			var road_distance := generator.road_distance(point)
			var river_distance := absf(point.y - generator.river_z(point.x))
			if river_distance < 9:
				color = Color("8a9475")
			if river_distance < 5.5:
				color = Color("397a84").lerp(Color("528f94"), noise * .5 + .5)
				if generator.is_water(point):
					VisualFactory.collider(river_body, Vector3(size, 3, size), Vector3(point.x, 1.2, point.y))
				else:
					color = Color("a79a7c") # Continuous north-south bridge.
			elif road_distance < 0:
				color = Color("585d53") if road_distance < -1 else Color("8b8769")
			if point.length() < 6:
				color = Color("71816a")
			for v: Vector2 in [Vector2(x, z), Vector2(x, z + size), Vector2(x + size, z), Vector2(x + size, z), Vector2(x, z + size), Vector2(x + size, z + size)]:
				surface.set_color(color)
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(origin.x + v.x, y, origin.y + v.y))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1
	mesh.material_override = material
	parent.add_child(mesh)
	# The bridge rails are in the sector which owns the crossing, never duplicated.
	if coord == Vector2i(0, 1):
		var crossing := generator.river_z(0)
		for side in [-1, 1]:
			VisualFactory.box(parent, Vector3(.2, .15, 16), Vector3(side * 4, 1.1, crossing), Color("a99d7b"))

func rebuild_navigation() -> void:
	navigation_dirty = false
	nav_origin = center * 32 - Vector2i(32, 32)
	navigation.region = Rect2i(nav_origin, Vector2i(96, 96))
	navigation.cell_size = Vector2(2, 2)
	navigation.offset = Vector2.ZERO
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(nav_origin.x, nav_origin.x + 96):
		for z in range(nav_origin.y, nav_origin.y + 96):
			if generator.is_water(Vector2(x * 2, z * 2)):
				navigation.set_point_solid(Vector2i(x, z))
	for coord: Vector2i in sectors:
		var data: Dictionary = generator.sector_data(coord)
		for house: Dictionary in data.buildings:
			mark_solid(Vector3(house.pos.x, 0, house.pos.y), Vector2(house.width + 1, house.depth + 1))
		for prop: Dictionary in data.resources:
			if int(world.state.changes.get(prop.id, {}).get("units", prop.units)) > 0:
				mark_solid(Vector3(prop.pos.x, 0, prop.pos.y), Vector2(2, 2))

func mark_solid(pos: Vector3, size: Vector2) -> void:
	var first := Vector2i(floori((pos.x - size.x * .5) / 2), floori((pos.z - size.y * .5) / 2))
	var last := Vector2i(ceili((pos.x + size.x * .5) / 2), ceili((pos.z + size.y * .5) / 2))
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1):
			if navigation.is_in_boundsv(Vector2i(x, z)):
				navigation.set_point_solid(Vector2i(x, z))

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	var start := Vector2i(roundi(from.x / 2), roundi(from.z / 2))
	var end := Vector2i(roundi(to.x / 2), roundi(to.z / 2))
	if not navigation.is_in_boundsv(start) or not navigation.is_in_boundsv(end):
		return PackedVector2Array()
	if navigation.is_point_solid(start) or navigation.is_point_solid(end):
		return PackedVector2Array()
	return navigation.get_point_path(start, end)

func reload_all() -> void:
	for node: Node3D in sectors.values():
		remove_child(node)
		node.queue_free()
	sectors.clear()
	pending.clear()
	generator = WorldGenerator.new(world.state.world_seed)
	center = Vector2i(99999, 99999)
	focus(world.player.global_position, true)
