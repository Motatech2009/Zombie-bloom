extends SceneTree
# Visual navigation fixture; excluded from exports and never writes a player save.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	var world: Node3D = load("res://scenes/sectors/RoamingWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world)
	current_scene = world
	world.player.position = Vector3(0,0,-47)
	world.camera.position = world.player.position*.82+world.camera_offset
	world.world_rng.seed = 8417
	world.horde_left = 80
