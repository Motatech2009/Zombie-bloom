extends SceneTree
var world: Node3D
func _initialize() -> void: call_deferred("run")
func add_defense(piece: int,pos: Vector3,tier: int) -> void:
	var node := StaticBody3D.new(); node.set_script(world.structure_script())
	node.world = world; node.piece_index = piece; node.tier = tier; node.position = pos
	world.base_root.add_child(node)
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	world = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false)
	world.waves.wave = 6; world.horde_left = 180
	world.resources.scrap = 500; world.stock = {"wood":200,"parts":100}
	world.player.position = Vector3(2,0,13); world.player.invulnerable = 3600
	world.core_tier = 4; world.core.health.setup(1350); world.refresh_core_model()
	for tier in range(1,4):
		add_defense(0,Vector3(-11+tier*4,0,9),tier)
		add_defense(2,Vector3(-11+tier*4,0,-5),tier)
		add_defense(1,Vector3(-11+tier*4,0,1),tier)
	add_defense(3,Vector3(8,0,1),3)
	add_defense(6,Vector3(6,0,9),2)
	add_defense(7,Vector3(10,0,-5),3)
	add_defense(8,Vector3(-7,0,-12),3)
	add_defense(9,Vector3(0,0,-12),3)
	add_defense(5,Vector3(5,0,-12),2)
	add_defense(4,Vector3(5,0,14),3)
	if "--airdrop" in OS.get_cmdline_user_args():
		world.airdrops.left = .01; world.airdrops.tick(.02); world.airdrops.state.coord = [0,-1]
		world.player.position = SectorGenerator.EXITS[0]; world.travel_cooldown = 0; world.step_sector(0)
		world.player.position = world.sector_offset(world.sector_coord)+Vector3(0,0,18)
		world.field_queue.clear()
		world.camera.position = world.sector_offset(world.sector_coord)+Vector3(0,0,15)+world.camera_offset
		world.camera.look_at(world.sector_offset(world.sector_coord)+Vector3(0,0,15))
