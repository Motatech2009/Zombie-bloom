extends SceneTree

const ORIGIN := Vector3(23, 0, 18)
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.waves.set_physics_process(false)
	var player: Node3D = world.player
	player.set_physics_process(false)
	player.position = ORIGIN + Vector3.BACK * 1.7
	player.invulnerable = 0

	var burster: Node3D = world.make_enemy(9, ORIGIN, false, -1)
	burster.set_physics_process(false)
	await physics_frame
	var hp: float = player.health.current
	burster._physics_process(.016)
	check(burster.burster_fuse > .5 and player.health.current == hp and not burster.health.dead,
		"an approaching survivor arms a fuse without taking instant damage")
	var packet: Dictionary = world.net_state(1)
	check(packet.hazards.any(func(row): return row.get("fx18") == "burst_warning"),
		"co-op snapshots include the explosion warning")
	burster._physics_process(.57)
	check(not burster.health.dead and player.health.current == hp, "the warning gives time to retreat")
	burster._physics_process(.04)
	check(burster.health.dead and player.health.current < hp and not burster.is_in_group("enemies"),
		"the fuse kills the Burster and deals area damage")
	var actual_blasts := get_nodes_in_group("boss_fx18").filter(func(fx): return fx.data.fx18 == "rupture")
	check(actual_blasts.size() == 1, "a fuse produces exactly one explosion")

	player.position = ORIGIN + Vector3.BACK * 7.0
	player.invulnerable = 0
	hp = player.health.current
	var shot_burster: Node3D = world.make_enemy(9, ORIGIN, false, -1)
	shot_burster.set_physics_process(false)
	await physics_frame
	shot_burster._physics_process(.016)
	check(shot_burster.burster_fuse == 0.0, "a distant survivor does not arm the fuse")
	shot_burster.take_damage(100000)
	shot_burster.take_damage(100000)
	check(get_nodes_in_group("boss_fx18").filter(func(fx): return fx.data.fx18 == "rupture").size() == 2
		and player.health.current == hp, "shooting a Burster also detonates it once and respects the radius")

	player.position = ORIGIN + Vector3.BACK * 10.0
	var lobber: Node3D = world.make_enemy(15, ORIGIN, false, -1)
	lobber.set_physics_process(false)
	lobber.target = player
	lobber.think_left = 5.0
	lobber.ranged_left = 0
	await physics_frame
	lobber._physics_process(.016)
	var shots := get_nodes_in_group("campaign_projectiles")
	check(shots.size() == 1 and shots[0].kind == "spore", "the Spore Lobber fires a different projectile")
	if shots.is_empty():
		world.queue_free()
		await process_frame
		quit(1)
		return
	var launched: Node3D = shots[0]
	launched.set_physics_process(false)
	packet = world.net_state(1)
	check(packet.hazards.any(func(row): return row.get("spore", false))
		and packet.hazards.any(func(row): return row.get("fx18") == "spore_warning"),
		"co-op snapshots distinguish the projectile and its purple warning")
	launched._physics_process(1.26)
	var patches := get_nodes_in_group("spore_patches")
	check(patches.size() == 1 and get_nodes_in_group("acid_pools").is_empty(),
		"landing plants mushrooms and does not produce an acid pool")
	if patches.is_empty():
		world.queue_free()
		await process_frame
		quit(1)
		return
	var patch: Node = patches[0]
	patch.set_physics_process(false)
	player.invulnerable = 0
	hp = player.health.current
	patch._physics_process(.016)
	check(player.health.current == hp and player.slow_left == 0.0, "shooting spores allows time for germination")
	patch.effect.elapsed = 1.1
	patch._physics_process(.016)
	check(player.health.current < hp and hp - player.health.current < 4.0
		and is_equal_approx(player.slow_left, SporePatch.LINGER_SLOW),
		"active mushrooms deal light poison damage and slow a survivor")
	packet = world.net_state(1)
	check(packet.hazards.any(func(row): return row.get("fx18") == "mushrooms")
		and packet.players[0].slow > 0.0, "co-op carries mushroom growth and the slow status")
	player.position += Vector3.BACK * 4.5
	hp = player.health.current
	patch._physics_process(1.1)
	check(player.health.current == hp, "poison damage ends when the survivor leaves the area")
	patch.effect.elapsed = SporePatch.LIFETIME
	patch.effect._process(.016)
	check(patch.effect.is_queued_for_deletion(), "fungal growth expires after seven seconds")

	await process_frame
	player.slow_left = 0.0
	player.position = ORIGIN + Vector3.BACK * 10.0
	var spitter: Node3D = world.make_enemy(5, ORIGIN, false, -1)
	spitter.set_physics_process(false)
	spitter.target = player
	spitter.think_left = 5.0
	spitter.ranged_left = 0
	await physics_frame
	spitter._physics_process(.016)
	shots = get_nodes_in_group("campaign_projectiles")
	check(shots.size() == 1 and shots[0].kind == "acid", "the Corrosive still spits acid")
	if shots.size() == 1:
		shots[0]._physics_process(1.21)
		check(get_nodes_in_group("acid_pools").size() == 1 and player.slow_left == 0.0,
			"acid forms a corrosive pool without the fungal slow")

	world.queue_free()
	await process_frame
	await process_frame
	print("INFECTED HAZARDS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
