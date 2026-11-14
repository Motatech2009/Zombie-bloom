extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	seed(8417)
	MobilePlatform.force_touch = true
	GameSettings.shadows = false
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false); world.set_process(false)
	world.player.position = Vector3(0,0,10); world.player.invulnerable = 3600
	world.player.set_physics_process(false)
	world.camera.position = world.player.position+world.camera_offset; world.camera.look_at(world.player.position)
	Engine.max_fps = 0
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var output: Array = []
	for count in [0,24,72]:
		var existing := get_nodes_in_group("enemies").size()
		for i in range(existing,count):
			var enemy: Node3D = world.make_enemy(i%15,Vector3((i%12-5.5)*1.4,0,4-(i/12)*1.8),false,i)
			enemy.set_physics_process(false)
		for i in range(8): await process_frame
		var samples: Array[float] = []
		var draws: Array[float] = []
		var primitives: Array[float] = []
		var stamp := Time.get_ticks_usec()
		for i in range(40):
			await process_frame
			var now := Time.get_ticks_usec(); samples.append((now-stamp)/1000.0); stamp = now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		samples.sort()
		var meshes := 0
		for enemy in get_nodes_in_group("enemies"): meshes += enemy.rig.find_children("*","MeshInstance3D",true,false).size()
		output.append({"enemies":count,"frame_ms_median":samples[20],"frame_ms_tail":samples[38],"draw_calls":draws.reduce(func(a,b): return a+b,0.0)/40,"primitives":primitives.reduce(func(a,b): return a+b,0.0)/40,"enemy_mesh_nodes":meshes,"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
	print("MOBILE BENCHMARK "+JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"samples":output}))
	world.queue_free(); await process_frame; await process_frame; quit()
