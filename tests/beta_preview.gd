extends SceneTree
## Reproducible native visual QA and render timing; no production teleport input.
var world: Node3D
var samples: Array[float] = []
var warmup: int = 90
var benchmark: bool = false
var import_msec: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var start := Time.get_ticks_msec()
	WorldState.resume_requested = false
	world = load("res://scenes/beta/BetaWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.director.enabled = false
	var zone := "refuge"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="): zone = arg.trim_prefix("--zone=")
		if arg == "--benchmark": benchmark = true
	match zone:
		"interior":
			var house: Dictionary = world.outdoor.generator.houses.filter(func(row): return row.id == "beta:starter:house")[0]
			world.player.position = Vector3(house.pos.x, 0, house.pos.y - 5.4)
			world.enter_building(house)
		"night":
			world.time.seconds = 23 * 120
			world.time.weather = .9
			world.time.lantern_on = true
		"city":
			var settlement: Dictionary = world.outdoor.generator.settlements[0]
			world.player.position = Vector3(settlement.pos.x, 0, settlement.pos.y - 30)
			world.outdoor.focus(world.player.position, true)
		"migration":
			world.player.position = Vector3(0, 0, -20)
			var event: Dictionary = {"id": "preview:migration", "migration": true, "pos": [0, 0, -40], "target": [0, 0, 150], "count": 32, "speed": 1.0, "status": "moving", "attracted": false}
			world.director.events.append(event)
			for i in range(32):
				world.spawn_beta_enemy(Vector3((i % 8) * .8 - 3, 0, -40 - (i / 8) * 1.4), event.id, i % 6 == 0)
	if "--low" in OS.get_cmdline_user_args():
		BetaOptions.render_scale = .5
		BetaOptions.shadows = false
		BetaOptions.fog_strength = .3
	world.snap_camera()
	world.time.apply(0)
	import_msec = Time.get_ticks_msec() - start
	if benchmark:
		process_frame.connect(record_frame)

func record_frame() -> void:
	world.player.invulnerable = 1 # Stress fixture only: keep simulation alive through all samples.
	if warmup > 0:
		warmup -= 1
		return
	samples.append(root.get_process_delta_time() * 1000)
	if samples.size() >= 300:
		samples.sort()
		var total := 0.0
		for value in samples: total += value
		var data := {"renderer": RenderingServer.get_video_adapter_name(), "frames": samples.size(), "average_fps": 1000 / (total / samples.size()), "frame_p50_ms": samples[150], "frame_p95_ms": samples[285], "frame_max_ms": samples[-1], "startup_ms": import_msec, "resident_sectors": world.outdoor.sectors.size(), "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "render_scale": BetaOptions.render_scale, "shadows": BetaOptions.shadows, "active_enemies": get_nodes_in_group("enemies").size(), "crowd_draw_parts": world.crowd.parts.size()}
		var file := FileAccess.open("user://beta_benchmark.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		print("BETA BENCHMARK: ", JSON.stringify(data))
		quit()
