extends SceneTree
## Reproducible visual QA entry point, not an in-game teleport feature.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	WorldState.resume_requested = false
	var world: Node3D = load("res://scenes/world/FrontierWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.ambient_timer = 999999
	await physics_frame
	await process_frame
	var zone := "refuge"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			zone = arg.trim_prefix("--zone=")
	match zone:
		"interior":
			var house: Dictionary = world.outdoor.generator.houses[-1]
			world.player.position = Vector3(house.pos.x, 0, house.pos.y - 5.4)
			world.outdoor.focus(world.player.position, true)
			world.enter_building(house)
		"city":
			world.player.position = Vector3(128, 0, -140)
			world.outdoor.focus(world.player.position, true)
		"bridge":
			world.player.position = Vector3(0, 0, world.outdoor.generator.river_z(0) - 8)
			world.outdoor.focus(world.player.position, true)
	world.snap_camera()
