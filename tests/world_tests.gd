extends SceneTree
var checks: int = 0
var failures: int = 0
var world: Node3D
const TEST_SAVE := "user://world_integration_test.json"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func find_prop(id: String) -> WorldInteraction:
	for prop: WorldInteraction in get_nodes_in_group("world_interactions"):
		if prop.id == id and not prop.is_queued_for_deletion() and prop.is_inside_tree():
			return prop
	return null

func collision_at(pos: Vector3, exclude: Array[RID] = []) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .35
	query.shape = shape
	query.transform.origin = pos + Vector3(0, 1, 0)
	query.collision_mask = 1 | 8
	query.exclude = exclude
	return not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func interior_reachable() -> bool:
	var nav := AStarGrid2D.new()
	nav.region = Rect2i(-16, -16, 33, 33)
	nav.cell_size = Vector2(.5, .5)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for x in range(-16, 17):
		for z in range(-16, 17):
			if collision_at(world.interior.global_position + Vector3(x * .5, 0, z * .5)):
				nav.set_point_solid(Vector2i(x, z))
	var start := Vector2i(-6, -12)
	for end: Vector2i in [Vector2i(-6, -6), Vector2i(6, -6), Vector2i(-6, 6), Vector2i(6, 6)]:
		if nav.is_point_solid(end) or nav.get_id_path(start, end).is_empty():
			return false
	return true

func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("FAIL: world test timeout"); quit(1))
	var generator := WorldGenerator.new(8417)
	var second := WorldGenerator.new(8417)
	var different := WorldGenerator.new(73521)
	var coord := Vector2i(-1, 2)
	var first_data := generator.sector_data(coord)
	check(first_data == second.sector_data(coord), "same seed reproduces complete sector descriptors")
	second.sector_data(Vector2i(17, -11))
	second.sector_data(Vector2i(-9, 1))
	check(first_data == second.sector_data(coord), "visiting other sectors cannot change generation")
	check(first_data != different.sector_data(coord), "another seed changes resource positions and amounts of objects")
	check(WorldGenerator.sector_at(Vector3(-.01, 0, -.01)) == Vector2i(-1, -1), "negative coordinates use floor, avoiding duplicate sector ownership")
	check(generator.interior_plan("city:0:1:0", "house") == second.interior_plan("city:0:1:0", "house"), "interior plans are reproducible independently of visit order")
	check(generator.interior_plan("one", "house") != generator.interior_plan("two", "house"), "distinct building IDs select independent floorplans")
	var entrances_valid := true
	var no_overlap := true
	for house: Dictionary in generator.houses:
		var door: Vector2 = house.pos + Vector2(0, -house.depth * .5 - 1.4)
		entrances_valid = entrances_valid and not generator.is_water(door) and generator.road_distance(house.pos) > 0
		for other: Dictionary in generator.houses:
			if house.id == other.id:
				continue
			if absf(house.pos.x - other.pos.x) < (house.width + other.width) * .5 and absf(house.pos.y - other.pos.y) < 8:
				no_overlap = false
	check(entrances_valid, "settlement buildings stay off roads and entrances stay out of the river")
	check(no_overlap, "regional building lots never overlap")
	var ids := {}
	var resource_rules := true
	for x in range(-3, 4):
		for z in range(-3, 4):
			var sector: Dictionary = generator.sector_data(Vector2i(x, z))
			for prop: Dictionary in sector.resources:
				if ids.has(prop.id) or generator.is_water(prop.pos) or generator.road_distance(prop.pos) < 0:
					resource_rules = false
				ids[prop.id] = true
	check(resource_rules, "resources across 49 sectors have unique IDs and stay off roads and water")
	check(not generator.is_water(Vector2(0, generator.river_z(0))) and generator.is_water(Vector2(20, generator.river_z(20))), "bridge is traversable while the adjacent river blocks crossing")
	var state := WorldState.new()
	check(state.put_cargo("wood", 50) == 45 and state.cargo_total() == 45, "inventory capacity clamps extraction without losing accepted units")
	check(state.put_cargo("metal", 9) == 0 and state.put_cargo("unknown", 9) == 0, "full inventory and unknown resources cannot receive cargo")
	check(state.deposit() == 45 and state.cargo_total() == 0 and state.deposit() == 0, "deposit transfers cargo exactly once")
	WorldState.resume_requested = false
	world = load("res://scenes/world/FrontierWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.ambient_timer = 99999
	await frames(4)
	check(world.outdoor.sectors.size() == 9 and world.phase == "prep", "open world boots with nine resident sectors and exploration enabled")
	var seams_solid := true
	for pos: Vector3 in [Vector3(-.01, 0, 10), Vector3(.01, 0, 10), Vector3(63.99, 0, 10), Vector3(64.01, 0, 10)]:
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2, pos + Vector3.DOWN * 2, 1)
		seams_solid = seams_solid and not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	check(seams_solid, "adjacent sector floors have continuous physical support at seams")
	check(world.get_tree().get_nodes_in_group("world_interactions").size() > 40, "loaded sectors contain real interactive resources and entrances")
	var prop := find_prop("starter:wood")
	check(is_instance_valid(prop) and prop.units == 12, "starter extraction tree is discoverable")
	check(prop.extract(.8) == 0 and world.state.cargo_total() == 0, "extraction requires sustained time")
	check(prop.extract(.81) == 3 and world.state.cargo.wood == 3 and prop.units == 9, "timed extraction transfers resources from the actual node into cargo")
	for i in range(3):
		prop.extract(1.61)
	check(prop.units == 0 and not prop.available() and world.state.cargo_total() == 12, "fully harvested resource remains depleted")
	check(prop.extract(99) == 0 and world.state.cargo_total() == 12, "depleted node cannot duplicate resources")
	world.player.position = Vector3(260, 0, 260)
	world.outdoor.focus(world.player.position, true)
	world.snap_camera()
	check(world.camera.unproject_position(world.player.global_position).distance_to(world.get_viewport().get_visible_rect().size * .5) < 2, "world camera keeps the player centered at distant coordinates")
	await frames()
	check(world.outdoor.sectors.size() <= 10 and not world.outdoor.sectors.has(Vector2i(-1, -1)), "streaming unloads distant sectors and retains only the local ring plus refuge")
	world.player.position = Vector3(3.8, 0, 4)
	world.outdoor.focus(world.player.position, true)
	await frames()
	prop = find_prop("starter:wood")
	check(prop.units == 0 and not prop.model.visible, "harvested state survives sector unload and recreation")
	var before: int = world.resources.scrap
	world.player.position = Vector3(20, 0, 4)
	check(world.deposit_cargo() == 0 and world.resources.scrap == before, "cargo cannot be deposited away from the base")
	world.player.position = Vector3(3, 0, 2)
	check(world.deposit_cargo() == 12 and world.resources.scrap == before + 12 and world.state.cargo_total() == 0, "returning to core converts carried materials to construction resources")
	world.state.cargo.wood = 44
	prop = null
	for candidate: WorldInteraction in get_nodes_in_group("world_interactions"):
		if candidate.kind == "tree" and candidate.units > 0:
			prop = candidate
			break
	var original_units: int = prop.units
	check(prop.extract(1.61) == 1 and prop.units == original_units - 1, "partially full cargo only removes the units actually accepted")
	world.state.deposit()
	var house: Dictionary = world.outdoor.generator.houses[-1]
	check(not world.enter_building(house), "remote entry into a building is rejected")
	world.player.position = Vector3(house.pos.x, 0, house.pos.y - 5.4)
	world.outdoor.focus(world.player.position, true)
	await frames()
	check(world.enter_building(house), "nearby entrance transitions to its own interior scene")
	await frames()
	check(world.inside and not world.outdoor.visible and world.arena == world.interior, "outdoor geometry is hidden and disabled during the separate interior scene")
	var door: WorldInteraction
	for candidate: WorldInteraction in get_nodes_in_group("world_interactions"):
		if candidate.kind == "door":
			door = candidate
			candidate.use()
	await frames()
	check(door.opened and door.door_shape.disabled, "opening an internal door removes its blocking collision")
	var saved_door: String = door.id
	check(interior_reachable(), "physics-derived grid connects the entry to all four furnished rooms with doors open")
	door.use()
	await frames()
	check(not door.opened and not door.door_shape.disabled, "closing a door restores physical collision")
	door.use()
	var container: WorldInteraction = find_prop(str(house.id) + ":container:0")
	for i in range(4):
		container.extract(1.61)
	check(container.units == 0 and world.state.cargo.metal == 12, "interior container extraction uses the same limited cargo system")
	var old_plan: Dictionary = world.interior.plan.duplicate(true)
	world.player.position = world.interior.position + Vector3(-3, 0, -7)
	check(world.leave_building(), "exit returns the player to its original building entrance")
	await frames()
	check(not world.inside and world.outdoor.visible and world.player.position.distance_to(Vector3(house.pos.x, 0, house.pos.y - 6.4)) < 1, "outdoor coordinates and simulation restore on exit")
	check(world.enter_building(house), "same building can be entered again")
	await frames()
	check(world.interior.plan == old_plan and find_prop(saved_door).opened and find_prop(str(house.id) + ":container:0").units == 0, "reentering preserves the floorplan, door states and emptied containers")
	world.player.position = world.interior.position + Vector3(-3, 0, -7)
	world.leave_building()
	await frames()
	world.player.position = Vector3(3, 0, 2)
	world.outdoor.focus(world.player.position, true)
	world.resources.scrap = 500
	world.builder.set_active(true)
	world.builder.selected = 0
	await frames()
	world.builder.location = Vector3(6, 0, 2)
	var defense: Node3D = world.builder.place()
	check(is_instance_valid(defense), "existing construction works on streamed ground")
	world.builder.set_active(false)
	world.player.position = Vector3(6, 0, 4.5)
	var defense_hp: float = defense.health.maximum
	check(world.upgrade_defense() and defense.health.maximum == defense_hp + 75, "resources upgrade the resistance of a nearby defense")
	world.player.position = Vector3(3, 0, 2)
	check(world.save_checkpoint(TEST_SAVE) == OK, "checkpoint serializes seed, cargo, edits, combat stats and defenses")
	var bank: int = world.resources.scrap
	world.resources.scrap = 0
	world.state.changes.clear()
	world.state.cargo.metal = 0
	check(world.load_checkpoint(TEST_SAVE) == OK, "checkpoint reload succeeds through the actual world controller")
	await frames()
	check(world.resources.scrap == bank and world.state.cargo.metal == 12 and world.state.changes["starter:wood"].units == 0, "save restores bank, carried materials and harvested resource state")
	check(world.state.changes[saved_door].open and world.state.changes[str(house.id) + ":container:0"].units == 0, "save restores interior door and loot changes")
	var restored: Node3D
	for building in get_nodes_in_group("buildings"):
		if building != world.core:
			restored = building
	check(is_instance_valid(restored) and restored.health.maximum == defense_hp + 75 and restored.get_meta("tier") == 1, "save restores placed defense and its purchased upgrade")
	var loaded := WorldState.new()
	check(loaded.read_save(TEST_SAVE) == OK and loaded.world_seed == 8417, "standalone save reader restores the generator seed")
	var file := FileAccess.open(TEST_SAVE + ".invalid", FileAccess.WRITE)
	file.store_string('{"format":99}')
	file.close()
	check(loaded.read_save(TEST_SAVE + ".invalid") == ERR_INVALID_DATA, "unknown save formats are rejected without silently regenerating")
	check(world.load_checkpoint(TEST_SAVE + ".invalid") == ERR_INVALID_DATA and world.resources.scrap == bank, "failed load leaves the current world intact")
	world.hud.show_map()
	await frames()
	check(paused and world.hud.mode == "map", "regional map opens as a real paused HUD modal")
	world.hud.close_modal()
	check(not paused, "closing map resumes the expedition")
	world.waves.wave = 5
	check(world.waves.start() and world.waves.wave == 6, "survival mode can start a sixth horde")
	check(world.save_checkpoint(TEST_SAVE) == ERR_BUSY and not world.enter_building(house), "active horde blocks saving and interior escape")
	world.waves.to_spawn = 0
	world.waves.complete()
	check(world.phase == "prep" and not world.won, "completed survival horde returns to exploration without terminal victory")
	world.queue_free()
	await frames()
	# Cold restart, not only reload in the same scene, proves the disk persistence path.
	var fresh := WorldState.new()
	check(fresh.read_save(TEST_SAVE) == OK and fresh.changes.has(saved_door), "persisted interior edits survive a fresh state instance")
	WorldState.resume_requested = true
	world = load("res://scenes/world/FrontierWorld.tscn").instantiate()
	world.save_path = TEST_SAVE
	root.add_child(world)
	current_scene = world
	await frames()
	check(world.state.changes.has(saved_door) and world.resources.scrap == bank and world.state.cargo.metal == 12, "cold scene restart resumes saved resources and interior state")
	world.queue_free()
	await frames()
	for suffix in ["", ".bak", ".invalid", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
	print("WORLD RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
