extends SceneTree
## Integration tests run against real Godot scenes and physics, without test plugins.
var failures: int = 0
var checks: int = 0
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func clear_choices() -> void:
	world.resources.pending = 0
	world.upgrades.offers.clear()
	if world.hud.mode != "result":
		world.hud.close_modal()

func make_enemy(pos: Vector3, kind: int = 0) -> Node3D:
	var enemy: Node3D = WaveManager.ENEMY_SCENES[kind].instantiate()
	enemy.world = world
	enemy.position = pos
	world.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func run() -> void:
	seed(1874)
	var component := Health.new()
	root.add_child(component)
	component.setup(40)
	component.take_damage(-8)
	check(component.current == 40, "negative damage is rejected")
	component.take_damage(12)
	check(component.heal(80) == 12 and component.current == 40, "healing clamps to maximum")
	component.take_damage(100)
	component.take_damage(10)
	check(component.dead and component.current == 0 and component.heal(10) == 0, "death is terminal and damage clamps to zero")
	component.queue_free()
	world = load("res://scenes/main/GameWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	check(world.phase == "prep" and world.player.health.current == 100, "world initializes in preparation with a live player")
	check(world.waves.remaining() == 0, "no enemies before the first wave")
	var start: Vector3 = world.player.position
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	await frames(6)
	check(world.player.position.distance_to(start) > .6, "WASD input moves the actual CharacterBody3D")
	world.player.position = Vector3(5, 0, 5)
	await frames()
	var enemy := make_enemy(Vector3(5, 0, 0))
	await frames()
	var gun: WeaponSystem = world.player.weapons
	gun.cooldown = 0
	check(gun.shoot(Vector3.FORWARD), "pistol fires with ammunition")
	check(enemy.health.current == 22 and gun.ammo[0] == 11, "raycast hits an enemy and applies configured damage")
	check(not gun.shoot(Vector3.FORWARD) and gun.ammo[0] == 11, "cadence prevents repeated shots")
	check(gun.reload(), "partial magazine starts reloading")
	check(not gun.shoot(Vector3.FORWARD), "firing is blocked during reload")
	gun._process(2)
	check(gun.ammo[0] == 12 and gun.reload_left == 0, "reload replenishes only the current magazine")
	gun.ammo[0] = 0
	gun.cooldown = 0
	check(not gun.shoot(Vector3.FORWARD) and gun.reload_left > 0, "empty gun automatically starts reload")
	gun.equip(1)
	check(gun.slot == 1 and gun.reload_left == 0 and gun.ammo[0] == 0, "switching cancels reload without refilling the old gun")
	gun.equip(2)
	check(gun.capacity() == 30, "rifle has a separate magazine")
	gun.equip(0)
	gun.ammo[0] = 12
	var heavy := make_enemy(Vector3(5, 0, 3), 2)
	await frames()
	gun.equip(1)
	gun.cooldown = 0
	gun.shoot(Vector3.FORWARD)
	check(heavy.health.current == 102 and gun.ammo[1] == 5, "shotgun casts all six pellets and consumes one shell")
	gun.equip(2)
	gun.cooldown = 0
	gun.shoot(Vector3.FORWARD)
	check(heavy.health.current == 90 and gun.ammo[2] == 29, "rifle applies its own damage and magazine accounting")
	heavy.queue_free()
	gun.equip(0)
	await frames()
	enemy.take_damage(1000)
	check(world.kills == 1 and not enemy.is_in_group("enemies"), "death registers exactly one kill and removes the enemy from active counts")
	enemy.take_damage(1000)
	check(world.kills == 1, "repeated damage does not duplicate loot or kills")
	var wallet: ResourceManager = world.resources
	var before := wallet.scrap
	check(not wallet.spend(before + 1) and not wallet.spend(-10) and wallet.scrap == before, "wallet rejects overdrafts and negative spending")
	var pickup: Node3D = world.spawn_pickup(world.player.position, 7, 9)
	pickup.collect()
	pickup.collect()
	check(wallet.scrap == before + 9 and wallet.xp == 7, "pickup grants loot once")
	wallet.add_loot(200, 0)
	check(wallet.level >= 3 and wallet.pending >= 2 and paused, "XP queues multiple level choices and pauses combat")
	for upgrade in Catalog.UPGRADES:
		wallet.pending = 1
		world.upgrades.offers = [upgrade]
		var old_damage := gun.damage_multiplier
		var old_rate := gun.rate_multiplier
		var old_capacity := gun.capacity()
		var old_reload := gun.reload_multiplier
		var old_speed: float = world.player.speed_multiplier
		var old_health: float = world.player.health.maximum
		check(world.upgrades.choose(0), "upgrade applies: " + upgrade.id)
		match upgrade.id:
			"damage": check(gun.damage_multiplier > old_damage, "damage upgrade changes combat damage")
			"rate": check(gun.rate_multiplier > old_rate, "rate upgrade changes cadence")
			"capacity": check(gun.capacity() > old_capacity, "capacity upgrade changes magazine size")
			"reload": check(gun.reload_multiplier < old_reload, "reload upgrade reduces reload duration")
			"speed": check(world.player.speed_multiplier > old_speed, "speed upgrade changes movement")
			"health": check(world.player.health.maximum == old_health + 25, "health upgrade increases maximum health")
		check(not world.upgrades.choose(0), "consumed offer rejects duplicate selection")
	clear_choices()
	world.player.grant_power("shield")
	var hp: float = world.player.health.current
	world.player.take_damage(20)
	check(world.player.shield == 25 and world.player.health.current == hp, "shield absorbs damage before health")
	world.player.grant_power("shield")
	check(world.player.shield == 45 and world.player.power_left("shield") == 10, "power pickup refreshes duration without stacking intensity")
	world.player.grant_power("speed")
	world.player.grant_power("rapid")
	world.player._physics_process(10.1)
	check(world.player.powers.is_empty() and world.player.shield == 0, "all three temporary powers expire completely")
	await frames()
	world.player.position = Vector3(3.8, 0, 4)
	wallet.scrap = 500
	var build: BuildManager = world.builder
	build.set_active(true)
	check(not build.can_place(Vector3.ZERO), "construction rejects overlap with core")
	check(not build.can_place(world.player.position), "construction rejects overlap with player")
	check(not build.can_place(Vector3(26, 0, 0)), "construction rejects map border")
	check(not build.can_place(Vector3(-20, 0, -20)), "construction rejects distant positions")
	build.selected = 0
	build.location = Vector3(6, 0, 2)
	check(build.can_place(build.location), "free nearby construction site is accepted")
	var barricade: Node3D = build.place()
	check(is_instance_valid(barricade) and wallet.scrap == 475, "barricade construction spends exactly its cost")
	await frames()
	check(not build.can_place(Vector3(6, 0, 2)), "construction rejects overlap with existing defenses")
	wallet.scrap = 0
	check(not build.can_place(Vector3(7, 0, -2)), "construction rejects insufficient resources")
	wallet.scrap = 500
	build.selected = 1
	build.location = Vector3(6, 0, -2)
	var turret: Node3D = build.place()
	await frames()
	check(is_instance_valid(turret) and wallet.scrap == 425, "turret construction spends its own cost")
	barricade.take_damage(70)
	check(barricade.repair() and barricade.health.current == 175 and wallet.scrap == 417, "repair applies health and spends resources")
	barricade.repair()
	before = wallet.scrap
	check(barricade.health.current == 180 and not barricade.repair() and wallet.scrap == before, "full structure cannot consume repair resources")
	var dummy := make_enemy(Vector3(6, 0, -7))
	await frames()
	turret.fire_turret()
	check(dummy.health.current == 29, "turret raycast automatically damages a visible target")
	var blocker := StaticBody3D.new()
	world.add_child(blocker)
	blocker.position = Vector3(6, 0, -5)
	VisualFactory.collider(blocker, Vector3(3, 3, 1), Vector3(0, 1.5, 0))
	await frames()
	turret.fire_turret()
	check(dummy.health.current == 29, "turret cannot shoot through a solid obstacle")
	blocker.queue_free()
	dummy.queue_free()
	await frames()
	var attacker := make_enemy(Vector3(6, 0, 4))
	attacker.set_physics_process(true)
	world.player.position = Vector3(6, 0, -6)
	var wall_hp: float = barricade.health.current
	var penetrated := false
	for i in range(90):
		await frames(1)
		if absf(attacker.position.x - 6) < 1.30 and absf(attacker.position.z - 2) < 1.30:
			penetrated = true
	check(barricade.health.current < wall_hp, "zombie attacks a barricade obstructing its route")
	check(not penetrated, "solid barricade prevents zombie from penetrating its occupied volume")
	attacker.queue_free()
	await frames()
	world.player.position = Vector3(3.8, 0, 4)
	check(world.waves.start() and not world.waves.start(), "wave starts only once and leaves preparation")
	check(not build.active and not build.can_place(Vector3(7, 0, 2)) and not barricade.repair(), "combat disables construction and repair")
	await frames(24)
	check(world.waves.spawned > 0 and world.waves.to_spawn < 12, "live wave timer generates enemies automatically")
	world.waves.set_physics_process(false)
	world.hud.show_pause()
	var elapsed: float = world.elapsed
	await process_frame
	await process_frame
	check(paused and world.elapsed == elapsed, "pause freezes the world and survival clock")
	world.hud.close_modal()
	check(not paused, "continue resumes the scene tree")
	# Complete the five configured waves using actual spawns and actual death signals.
	for wave_index in range(5):
		check(world.waves.wave == wave_index + 1, "wave progression reaches %d" % (wave_index + 1))
		var count: int = Catalog.WAVES[wave_index]
		var initial_kills: int = world.kills
		for live_enemy in get_nodes_in_group("enemies"):
			live_enemy.take_damage(10000)
		for i in range(world.waves.to_spawn):
			var spawned_enemy: Node3D = world.waves.spawn_enemy()
			spawned_enemy.set_physics_process(false)
			if wave_index == 4 and i == 0:
				check(spawned_enemy.spec.id == "brute", "final wave introduces brutes")
			if wave_index == 2 and i == 0:
				check(spawned_enemy.spec.id == "runner", "third wave introduces runners")
			spawned_enemy.take_damage(10000)
		check(world.waves.to_spawn == 0 and world.waves.alive() == 0 and world.kills - initial_kills == count, "wave %d counts spawns, kills and remaining enemies" % (wave_index + 1))
		world.waves._physics_process(.01)
		if wave_index < 4:
			check(world.phase == "prep", "completed wave reopens preparation")
			world.waves.start()
	check(world.won and world.phase == "ended" and paused and world.hud.mode == "result", "fifth wave opens victory and freezes the game")
	check(not world.waves.start(), "victory cannot start another wave")
	world.finish(false, "duplicate ending")
	check(world.won, "terminal result cannot be overwritten")
	paused = false
	world.queue_free()
	await process_frame
	# Separate fresh runs prove both defeat routes.
	for route in ["player", "core"]:
		world = load("res://scenes/main/GameWorld.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		await frames()
		world.get(route).take_damage(10000)
		check(world.phase == "ended" and not world.won and world.hud.mode == "result", "defeat from " + route + " death opens terminal result")
		paused = false
		world.queue_free()
		await process_frame
	# Check the actual menu scene and its settings/help routes.
	var main_menu: Node3D = load("res://scenes/main/MainMenu.tscn").instantiate()
	root.add_child(main_menu)
	current_scene = main_menu
	await process_frame
	main_menu.show_help()
	main_menu.show_settings()
	main_menu.show_main()
	check(main_menu.content.get_child_count() > 6, "menu, help and settings build successfully")
	main_menu.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
