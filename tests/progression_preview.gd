extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	MobilePlatform.force_touch = true
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false); world.set_process(false); world.player.set_physics_process(false)
	world.player.invulnerable = 3600; world.player.position = SectorGenerator.EXITS[0]; world.world_rng.seed = 8417; world.step_sector(0)
	world.field_queue.clear(); world.elapsed += 20
	for house in get_nodes_in_group("raid_houses"): house.set_physics_process(false)
	world.hud.show_routes(); world.hud.select_sector(world.sector_coord)
