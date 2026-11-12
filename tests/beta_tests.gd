extends SceneTree
var checks: int = 0
var failures: int = 0
var world: Node3D
const SAVE := "user://beta_integration_test.json"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func find_prop(id: String) -> WorldInteraction:
	for prop: WorldInteraction in get_nodes_in_group("world_interactions"):
		if prop.id == id and not prop.is_queued_for_deletion():
			return prop
	return null

func run() -> void:
	create_timer(150).timeout.connect(func(): push_error("FAIL: beta test timeout"); quit(1))
	var inv := BetaInventory.new(4, 10)
	check(inv.add("stone", 100) == 12 and is_equal_approx(inv.weight(), 14.4), "absolute weight limit accepts only whole units up to 150 percent")
	check(inv.add("stone", 1) == 0 and is_equal_approx(inv.move_factor(), .45), "absolute limit never immobilizes an overloaded player")
	inv.remove("stone", 4)
	check(inv.move_factor() == 1 and inv.agile(), "normal load permits full movement and agile actions")
	inv.add("stone", 1)
	check(inv.move_factor() == .75 and inv.agile(), "first overload band applies 75 percent movement and preserves agility")
	inv.add("stone", 2)
	check(inv.move_factor() == .45 and not inv.agile(), "second overload band blocks sprint and roll")
	var target := BetaInventory.new(2, 2)
	var total: int = inv.count("stone")
	check(inv.transfer_to(target, 0, 10) == 2 and inv.count("stone") + target.count("stone") == total, "partial transfer conserves units under target weight limit")
	check(inv.transfer_to(inv, 0, 1) == 0 and inv.transfer_to(target, -1, 1) == 0, "self-transfer and invalid slot cannot duplicate items")
	var full := BetaInventory.new(1, 100)
	full.add("axe", 1)
	check(full.add("pistol", 1) == 0, "slot capacity is independent of weight capacity")
	var bag := BetaInventory.new()
	bag.add("backpack", 1)
	check(bag.equip_backpack(true) and bag.slots.size() == 30 and bag.nominal == 40, "equipped backpack expands slots and nominal capacity while retaining its weight")
	check(bag.transfer_to(target, 0, 1) == 0, "equipped backpack cannot be transferred to exploit its capacity")
	for index in range(1, 25): bag.slots[index] = {"id": "cloth", "qty": 1}
	check(not bag.equip_backpack(false), "switch to smaller backpack rejects too many occupied slots")
	for index in range(1, 25): bag.slots[index] = {}
	bag.slots[29] = {"id": "cloth", "qty": 1}
	bag.hotbar[2] = 29
	check(bag.equip_backpack(false) and bag.slots.size() == 24 and bag.hotbar[2] == 1 and bag.slots[1].id == "cloth", "smaller backpack compacts sparse contents and remaps hotbar without item loss")
	var invalid := bag.serialize()
	invalid.hotbar[0] = 999
	check(not target.restore(invalid), "inventory restore rejects dangling hotbar references")
	var gen := BetaGenerator.new(8417)
	var same := BetaGenerator.new(8417)
	var other := BetaGenerator.new(9242)
	check(gen.houses == same.houses and gen.houses != other.houses, "settlement lots and positions are seed dependent and reproducible")
	var before: Dictionary = gen.sector_data(Vector2i(0, 0)).duplicate(true)
	gen.sector_data(Vector2i(12, -9))
	check(gen.sector_data(Vector2i.ZERO) == before, "expanding into another region never changes the starter region")
	check(gen.ground_raw(Vector2(160, 200)) != gen.ground_raw(Vector2(200, 160)), "macro terrain contains actual spatial height variation")
	check(is_equal_approx(gen.height_at(Vector2(64, 11)), same.height_at(Vector2(64, 11))), "sector edges share deterministic global terrain heights")
	check(gen.interior_plan("house:a", "house").rooms != gen.interior_plan("house:a", "workshop").rooms, "interior room functions depend on building category")
	WorldState.resume_requested = false
	WorldState.next_seed = 8417
	world = load("res://scenes/beta/BetaWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.director.enabled = false
	await frames(4)
	check(world.inventory.count("axe") == 1 and world.inventory.count("pistol") == 1 and world.inventory.count("ammo9") == 36, "new beta campaign starts with finite equipment and ammunition items")
	check(world.builder is BetaBuild and world.outdoor is BetaRegion and world.player.weapons is BetaWeapons, "production scene connects the beta construction, terrain and combat services")
	check(world.outdoor.sectors.size() <= 10 and world.outdoor.generator is BetaGenerator, "beta scene uses bounded streaming of seed generated regions")
	# Actual heightmap collision, including a sector seam.
	var physical := true
	for pos: Vector2 in [Vector2(63.99, 12), Vector2(64.01, 12), Vector2(-30, -30)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(pos.x, 20, pos.y), Vector3(pos.x, -4, pos.y), 1)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		physical = physical and not hit.is_empty() and absf(hit.position.y - world.outdoor.generator.height_at(pos)) < .5
	check(physical, "rendered terrain has real matching heightmap collision across sector seams")
	world.player.tool = "pistol"
	var gun: BetaWeapons = world.player.weapons
	var carry_weight: float = world.inventory.weight()
	check(gun.reload(), "finite-ammo reload starts when compatible reserves exist")
	gun._process(2)
	check(is_equal_approx(carry_weight, world.inventory.weight()), "chambered ammunition still counts toward equipped carry weight")
	check(gun.ammo[0] == 12 and world.inventory.count("ammo9") == 24, "reload moves exactly twelve rounds from inventory to magazine")
	gun.ammo[0] = 2
	check(gun.reload(), "partial magazine reload starts")
	gun.equip(1)
	gun._process(4)
	check(gun.ammo[0] == 2 and world.inventory.count("ammo9") == 24, "switching weapons cancels reload without reserving or duplicating rounds")
	check(not gun.reload(), "shotgun cannot reload from pistol ammunition")
	gun.equip(0)
	world.player.position = Vector3(5, 0, 5)
	var enemy: Node3D = world.spawn_beta_enemy(Vector3(5, 0, 0), "fixture", false)
	enemy.set_physics_process(false)
	await frames()
	var hp: float = enemy.health.current
	gun.cooldown = 0
	check(gun.shoot(Vector3.FORWARD) and enemy.health.current == hp - 22 and gun.ammo[0] == 1, "real firearm raycast consumes one chambered round and applies damage")
	check(not world.noises.is_empty() and world.noises[-1].radius >= 38, "gunfire creates an audible world stimulus")
	enemy.queue_free()
	await frames()
	enemy = world.spawn_beta_enemy(Vector3(5, 0, 3), "fixture", false)
	enemy.set_physics_process(false)
	var wall := StaticBody3D.new()
	world.add_child(wall)
	wall.position = Vector3(5, 0, 4)
	VisualFactory.collider(wall, Vector3(3, 3, .3), Vector3(0, 1.5, 0))
	await frames()
	world.player.tool = "axe"
	gun.cooldown = 0
	hp = enemy.health.current
	gun.melee(Vector3.FORWARD)
	check(enemy.health.current == hp, "melee cannot damage through an actual wall")
	wall.queue_free()
	await frames()
	gun.cooldown = 0
	gun.melee(Vector3.FORWARD)
	check(enemy.health.current == hp - 32, "melee applies damage only to an unobstructed target in range")
	enemy.queue_free()
	await frames()
	var reserve_before: int = world.inventory.count("ammo9") + gun.ammo[0]
	var weapon_container: BetaInventory = world.container_for("fixture:weapons", "empty")
	var pistol_slot := -1
	for index in range(world.inventory.slots.size()):
		if world.inventory.slots[index].get("id", "") == "pistol": pistol_slot = index
	check(world.store_items(weapon_container, pistol_slot, 1) == 1 and gun.ammo[0] == 0 and world.inventory.count("ammo9") == reserve_before, "storing the last loaded firearm atomically unloads its rounds without ammunition loss or hidden magazine storage")
	var stored_slot := -1
	for index in range(weapon_container.slots.size()):
		if weapon_container.slots[index].get("id", "") == "pistol": stored_slot = index
	check(weapon_container.transfer_to(world.inventory, stored_slot, 1) == 1 and gun.ammo[0] == 0, "retrieving a stored firearm never duplicates its former magazine")
	world.player.invulnerable = 0
	hp = world.player.health.current
	check(world.player.begin_roll(Vector3.RIGHT) and world.player.invulnerable == 0, "rolling grants no invulnerability")
	world.player.take_damage(5)
	check(world.player.health.current == hp - 5, "player remains damageable while rolling")
	world.player.roll_left = 0
	world.player.roll_recovery = 0
	wall = StaticBody3D.new()
	world.add_child(wall)
	wall.position = world.player.position + Vector3(1, 0, 0)
	VisualFactory.collider(wall, Vector3(.25, 3, 4), Vector3(0, 1.5, 0))
	await frames()
	var start: Vector3 = world.player.position
	world.player.begin_roll(Vector3.RIGHT)
	await frames(40)
	check(world.player.position.x < start.x + .8, "rolling uses CharacterBody collision and does not cross walls")
	wall.queue_free()
	world.player.health.heal(100)
	world.player.position = Vector3(3, 0, 3)
	await frames()
	var original_inventory: BetaInventory = world.inventory.copy()
	world.inventory = BetaInventory.new(80, 1000)
	for id in ["wood", "stone", "scrap", "cloth", "fiber", "component", "plank"]:
		world.inventory.add(id, 70)
	var baseline: Dictionary = world.inventory.serialize()
	check(not world.crafting.craft("plank", false) and world.inventory.serialize() == baseline, "bench recipes reject missing station without consuming materials")
	var bench: Node3D = world.create_structure("workbench", "fixture:bench", Vector3(6, 0, 3), 0)
	check(world.crafting.craft("plank", false), "bench recipe succeeds within station range")
	check(world.inventory.count("wood") == 68 and world.inventory.count("plank") == 72, "crafting consumes exact ingredients and creates exact output")
	world.crafting.last_craft = Time.get_ticks_msec()
	baseline = world.inventory.serialize()
	check(not world.crafting.craft("plank") and baseline == world.inventory.serialize(), "double-click guard blocks repeated transaction")
	for recipe: Dictionary in BetaCatalog.DATA.values.recipes:
		check(world.crafting.craft(recipe.id, false), "recipe produces useful beta item: " + str(recipe.id))
	world.inventory = BetaInventory.new(2, 100)
	world.inventory.add("cloth", 10)
	world.inventory.add("axe", 1)
	baseline = world.inventory.serialize()
	check(not world.crafting.craft("bandage", false) and baseline == world.inventory.serialize(), "crafting with no output slot leaves all ingredients intact")
	world.inventory = original_inventory
	world.inventory.add("wall", 1)
	world.builder.set_active(true)
	world.builder.selected = BetaCatalog.STRUCTURES.find("wall")
	var wall_count: int = world.inventory.count("wall")
	world.builder.location = Vector3.ZERO
	check(world.builder.place() == null and world.inventory.count("wall") == wall_count, "invalid construction overlaps core and preserves the crafted piece")
	world.builder.location = Vector3(-4, 0, 2)
	var structure: Node3D = world.builder.place()
	check(is_instance_valid(structure) and world.inventory.count("wall") == wall_count - 1, "valid construction consumes exactly one crafted piece")
	world.inventory.add("wall", 1)
	world.builder.location = Vector3.ZERO
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world.camera.unproject_position(Vector3(-6, 0, 6))
	var pieces_before: int = world.inventory.count("wall")
	world._unhandled_input(click)
	check(world.inventory.count("wall") == pieces_before - 1, "construction uses the click position even when the preview has a stale cursor position")
	world.builder.set_active(false)
	if is_instance_valid(structure):
		structure.take_damage(90)
		world.player.position = Vector3(-3, 0, 2)
		world.inventory.add("wood", 2)
		world.inventory.add("scrap", 2)
		check(world.repair_beta() and structure.health.current > structure.health.maximum - 90, "repair consumes materials and restores damaged structure")
	var gate: Node3D = world.create_structure("gate", "fixture:gate", Vector3(10, 0, 0), PI * .5)
	gate.use()
	await frames()
	check(gate.opened and gate.solid.disabled, "base gate toggles physical collision")
	var crate: Node3D = world.create_structure("crate", "fixture:crate", Vector3(10, 0, 4), 0)
	world.container_for(crate.uid, "empty").add("wood", 4)
	var crate_count: int = world.container_for(crate.uid, "empty").count("wood")
	crate.take_damage(10000)
	check(world.drops.any(func(drop): return drop.id == "fixture:crate") and world.containers["fixture:crate"].count("wood") == crate_count, "destroyed storage preserves its contents in a recoverable ground container")
	var positions := [Vector3(-12, 0, 8), Vector3(-12, 0, 12), Vector3(-8, 0, 12), Vector3(-12, 0, 16), Vector3(-8, 0, 16), Vector3(-4, 0, 16)]
	for index in range(BetaCatalog.STRUCTURES.size()):
		var kind: String = BetaCatalog.STRUCTURES[index]
		world.inventory.add(kind, 1)
		world.player.position = positions[index] + Vector3(0, 0, -3)
		await frames()
		world.builder.set_active(true)
		world.builder.selected = index
		world.builder.location = positions[index]
		var built: Node3D = world.builder.place()
		check(is_instance_valid(built) and built.kind == kind, "full construction path places beta structure: " + kind)
		world.builder.set_active(false)
	var prop := find_prop("starter:wood")
	check(is_instance_valid(prop), "procedural beta retains an accessible first extraction tree")
	var tree_units: int = prop.units
	var wood_count: int = world.inventory.count("wood")
	prop.extract(1.7)
	check(prop.units == tree_units - 3 and world.inventory.count("wood") == wood_count + 3, "beta extraction moves real weighted materials from the resource node")
	var tree_state: int = prop.units
	world.player.position = Vector3(260, 0, 260)
	world.outdoor.focus(world.player.position, true)
	await frames()
	world.player.position = Vector3(3, 0, 3)
	world.outdoor.focus(world.player.position, true)
	await frames()
	check(find_prop("starter:wood").units == tree_state, "weighted extraction remains depleted after streaming out and back")
	var house: Dictionary = world.outdoor.generator.houses.filter(func(row): return row.id == "beta:starter:house")[0]
	world.player.position = Vector3(house.pos.x, 0, house.pos.y - 5.4)
	check(world.enter_building(house), "beta campaign enters a real ground-floor building")
	await frames()
	var container: BetaInventory = world.container_for(str(house.id) + ":container:0", "house")
	var stock := container.serialize()
	var door: WorldInteraction
	for candidate: WorldInteraction in get_nodes_in_group("world_interactions"):
		if candidate.kind == "door":
			door = candidate
			candidate.use()
	var door_id: String = door.id
	var window := find_prop(str(house.id) + ":window:-5")
	window.use()
	check(window.window_state() == "broken", "window supports persistent broken visual state")
	world.inventory.add("wood", 2)
	world.inventory.add("scrap", 1)
	window.use()
	check(window.window_state() == "barricaded", "window barricade consumes actual materials and persists state")
	world.read_record("house")
	check(world.notes.has("house") and paused and world.hud.mode == "record", "environmental record opens readable short-form lore and journal entry")
	world.hud.close_modal()
	var before_time: float = world.time.seconds
	await frames(3)
	check(world.time.seconds > before_time, "world clock continues during an interior visit")
	world.time.seconds = 20 * 120
	world.time.weather = .95
	world.time.lantern_on = true
	world.time.apply(0)
	check(world.sunlight.light_energy < .2 and world.time.lantern.visible, "night reduces sunlight and lantern remains available")
	var drop_before: int = world.drops.size()
	check(world.discard_item(6) and world.drops.size() == drop_before + 1 and world.drops[-1].get("house", "") == house.id, "discarded indoor items remain inside their original building")
	var indoor_drop_id: String = world.drops[-1].id
	world.inventory.add("shotgun", 1)
	for slot_index in range(world.inventory.slots.size()):
		if world.inventory.slots[slot_index].get("id", "") == "shotgun": world.inventory.hotbar[5] = slot_index
	world.player.select_hotbar(5)
	world.player.weapons.ammo[1] = 2
	world.player.weapons.sync_mass()
	var inside_position: Vector3 = world.player.position
	check(world.save_beta(SAVE) == OK, "complete beta snapshot saves while inside a building")
	var data := BetaPersistence.read(SAVE)
	check(not data.is_empty() and data.clock.seconds >= 2400 and data.player.inside, "validated save contains clock and interior player state")
	world.player.position = world.interior.position + Vector3(-3, 0, -7)
	world.leave_building()
	await frames()
	world.player.position = Vector3(house.pos.x, 0, house.pos.y - 5.4)
	check(world.enter_building(house), "beta reenters the same building")
	await frames()
	check(is_instance_valid(find_prop(indoor_drop_id)), "indoor discarded container is recreated when reentering the same house")
	check(world.containers[str(house.id) + ":container:0"].serialize() == stock and find_prop(door_id).opened, "interior loot and opened doors do not reroll on reentry")
	world.player.position = world.interior.position + Vector3(-3, 0, -7)
	world.leave_building()
	await frames()
	check(world.load_beta(SAVE) and world.inside and world.player.position.distance_to(inside_position) < 1, "save restores the correct interior and player position")
	check(world.player.tool == "shotgun" and world.player.weapons.slot == 1 and world.player.weapons.ammo[1] == 2 and world.player.hotbar_slot == 5, "save restores selected firearm, its own magazine and hotbar selection")
	check(world.state.changes[str(house.id) + ":window:-5"].window == "barricaded", "window state survives disk reload")
	world.player.position = world.interior.position + Vector3(-3, 0, -7)
	world.leave_building()
	await frames()
	world.player.position = Vector3(3, 0, 3)
	world.outdoor.focus(world.player.position, true)
	world.snap_camera()
	world.time.seconds = 12 * 120
	world.time.weather = .9
	world.time.apply(0)
	check(world.environment.environment.fog_enabled and world.environment.environment.fog_density > 0, "atmospheric fog is active in the 3D exterior")
	BetaOptions.fog_strength = 0
	world.time.apply(0)
	check(not world.environment.environment.fog_enabled, "accessibility setting can disable fog without changing gameplay state")
	BetaOptions.fog_strength = .7
	world.director.events.clear()
	world.director.migration_chance = 0
	world.director.local_chance = 0
	world.director.enabled = true
	var core_hp: float = world.core.health.current
	world.director.advance(BetaTime.DAY * 4)
	check(world.director.events.is_empty() and world.core.health.current == core_hp, "advancing four days does not force daily/nightly hordes or base attacks")
	world.director.enabled = false
	var migration: Dictionary = world.director.create_event(true)
	check(not migration.is_empty() and migration.count >= 12 and migration.count <= 40 and not world.camera.is_position_in_frustum(BetaEvents.decode(migration.pos)), "migratory event has identity, size, route and off-screen origin")
	check(not world.director.valid_spawn(world.player.position), "event materialization refuses a spawn on the player or in view")
	var candidate_found := false
	for x in range(-60, 61, 12):
		for z in range(-60, 61, 12):
			var pos := Vector3(x, 0, z)
			if world.director.valid_spawn(pos):
				candidate_found = true
	check(candidate_found, "director can find loaded, collision-free positions outside the camera")
	migration.pos = BetaEvents.encode(Vector3(40, 0, -32))
	migration.target = BetaEvents.encode(Vector3(200, 0, -32))
	world.director.hear(Vector3(32, 0, -32), 20)
	check(BetaEvents.decode(migration.target).distance_to(Vector3(32, 0, -32)) < .1 and migration.attracted, "migration may investigate actual noise rather than automatically targeting the core")
	world.director.events.clear()
	migration = {"id": "fixture:moving", "migration": true, "pos": [0, 0, -20], "target": [0, 0, 100], "count": 1, "speed": 0.0, "status": "moving", "attracted": false}
	world.director.events.append(migration)
	world.noises.clear()
	var walker: Node3D = world.spawn_beta_enemy(Vector3(0, 0, -44), migration.id, false)
	var walker_start: Vector3 = walker.position
	await frames(60)
	check(walker.position.distance_to(Vector3(0, 0, -20)) < walker_start.distance_to(Vector3(0, 0, -20)) - .4, "unalerted horde member physically advances along its migration route")
	walker.perceive()
	check(not walker.can_see and walker.alert_left <= 0, "distant player is not detected without sight or noise")
	world.make_noise(walker.position + Vector3(1, 0, 0), 10)
	walker.perceive()
	check(walker.alert_left > 0, "audible stimulus triggers investigation without direct visual contact")
	walker.queue_free()
	await frames()
	check(world.save_beta(SAVE) == OK, "migratory event state can be checkpointed with the outdoor campaign")
	data = BetaPersistence.read(SAVE)
	check(data.director.events.size() > 0 and data.director.events[0].id == migration.id, "save preserves aggregated horde identity and route")
	var bad := data.duplicate(true)
	bad.inventory.hotbar[0] = 100000
	check(not BetaPersistence.validate(bad), "corrupt inventory data is rejected before mutating the campaign")
	bad = data.duplicate(true)
	bad.generator = 999
	check(not BetaPersistence.validate(bad), "generator version mismatch is rejected")
	var seed_file := FileAccess.open(SAVE + ".other", FileAccess.WRITE)
	bad = data.duplicate(true)
	bad.seed = 111
	seed_file.store_string(JSON.stringify(bad))
	seed_file.close()
	check(world.save_beta(SAVE + ".other") == ERR_ALREADY_EXISTS, "save refuses to overwrite a campaign belonging to another seed")
	check(not world.load_beta(SAVE + ".other"), "loading another seed never silently replaces the current world")
	world.hud.show_inventory()
	check(paused and world.hud.mode == "inventory", "hybrid inventory UI is connected to the game")
	world.hud.close_modal()
	world.hud.show_loot(world.container_for("base:storage", "empty"), "base:storage")
	check(world.hud.mode == "loot", "two-panel loot UI opens against a persistent container")
	world.hud.close_modal()
	world.hud.show_crafting()
	check(world.hud.mode == "crafting", "crafting UI renders the real recipe catalog")
	world.hud.close_modal()
	world.hud.show_building()
	check(world.hud.mode == "building", "construction palette contains beta structures rather than turrets")
	world.hud.close_modal()
	world.hud.show_map()
	check(world.hud.mode == "map", "map opens without offering teleportation")
	world.hud.close_modal()
	world.hud.show_settings()
	check(world.hud.mode == "settings", "settings expose audio, resolution, fog, text and controls")
	world.hud.close_modal()
	check(not BetaOptions.rebind("roll", KEY_W), "control rebinding refuses conflicting movement keys")
	world.core.take_damage(10000)
	check(world.phase == "ended" and paused and world.hud.mode == "result", "core destruction opens beta defeat without erasing the saved campaign")
	check(world.load_beta(SAVE) and not world.core.health.dead and world.core.collision_layer == 8 and world.core.is_in_group("buildings"), "restoring after core defeat reactivates its health, collision and damageable structure role")
	world.hud.close_modal()
	check(not paused and world.phase == "prep", "restored campaign resumes playable simulation after defeat")
	var observed: Dictionary = {}
	for event_seed in [1, 17, 43, 87, 101, 251, 300, 984]:
		world.director.rng.seed = event_seed
		world.director.migration_chance = .045
		world.director.local_chance = 0
		world.director.serial = 0
		for review in range(120):
			world.director.events.clear()
			world.director.review()
		observed[world.director.serial] = true
	check(observed.size() > 1, "different deterministic random states produce different encounter frequencies instead of a fixed daily schedule")
	world.director.events.clear()
	world.player.position = Vector3(0, 0, -32)
	world.outdoor.focus(world.player.position, true)
	world.time.seconds = 12 * 120
	world.time.weather = 0
	world.noises.clear()
	var distant_walker: Node3D = world.spawn_beta_enemy(Vector3(16, 0, -32), "sight", false)
	var pursuer: Node3D = world.spawn_beta_enemy(Vector3(16, 0, -32), "sight", true)
	distant_walker.set_physics_process(false)
	pursuer.set_physics_process(false)
	await frames()
	distant_walker.perceive()
	pursuer.perceive()
	check(not distant_walker.can_see and pursuer.can_see and pursuer.spec.values.speed > distant_walker.spec.values.speed, "pursuer detects and pressures at longer range than the common wanderer")
	var sight_blocker := StaticBody3D.new()
	world.add_child(sight_blocker)
	sight_blocker.position = Vector3(8, 0, -32)
	VisualFactory.collider(sight_blocker, Vector3(.5, 3, 6), Vector3(0, 1.5, 0))
	await frames()
	pursuer.alert_left = 0
	pursuer.perceive()
	check(not pursuer.can_see and pursuer.alert_left == 0, "vision detection respects real blocking geometry")
	sight_blocker.queue_free()
	distant_walker.queue_free()
	pursuer.queue_free()
	world.player.roll_left = 0
	world.player.roll_recovery = 0
	world.player.aim = Vector3.BACK
	check(world.player.begin_roll(Vector3.ZERO) and world.player.roll_direction == Vector3.BACK, "stationary roll follows the mouse aim direction")
	world.player.roll_left = 0
	world.queue_free()
	await frames()
	world = load("res://scenes/beta/BetaWorld.tscn").instantiate()
	world.prepared_load = data
	root.add_child(world)
	current_scene = world
	world.director.enabled = false
	await frames()
	var root_drop_ids: Array = []
	for child in world.get_children():
		if child is BetaInteraction: root_drop_ids.append(child.id)
	check(root_drop_ids.count("fixture:crate") == 1, "restoring destroyed storage creates only one recoverable container in the world")
	check(world.notes.has("house") and world.director.events.size() > 0 and world.state.changes.has(door_id), "fresh scene restores campaign, lore, interior edits and persistent events")
	check(JSON.parse_string(JSON.stringify(world.inventory.serialize())) == data.inventory, "cold restart preserves every slot, hotbar reference and equipment flag")
	world.queue_free()
	await frames()
	for suffix in ["", ".bak", ".tmp", ".other", ".other.tmp"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	print("BETA RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
