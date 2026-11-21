extends SceneTree
var world: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	world = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false); world.waves.wave = 4; world.horde_left = 160
	world.world_rng.seed = 2208
	world.player.position = SectorGenerator.EXITS[0]; world.travel_cooldown = 0; world.step_sector(0)
	world.field_queue.clear(); world.player.invulnerable = 3600
	var house: Node3D = world.raid_house(0)
	world.player.position = house.to_global(Vector3(0,0,-14 if "--exterior" in OS.get_cmdline_user_args() else -1))
	for other in get_nodes_in_group("raid_houses"): other.set_physics_process(false)
	if "--cleared" in OS.get_cmdline_user_args():
		house.activated = true; house.dead.assign(range(house.guard_total))
		world.player.position = house.to_global(Vector3(0,0,1))
	elif not "--exterior" in OS.get_cmdline_user_args():
		house.activated = true
		for i in range(3): house._physics_process(1)
	world.set_process(false)
	world.camera.size = 26
	world.camera.position = house.global_position+world.camera_offset
	world.camera.look_at(house.global_position)
	if "--connection" in OS.get_cmdline_user_args():
		world.network.host_session(24578); world.network.bind_world(world)
		world.hud.show_connection()
