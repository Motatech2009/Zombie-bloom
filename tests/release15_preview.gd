extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	MobilePlatform.force_touch = "--mobile" in args
	root.content_scale_size = Vector2i(960,540) if MobilePlatform.enabled() else Vector2i(1440,900)
	var scene: Node
	if "--loadout" in args:
		scene = load("res://scenes/main/MainMenu.tscn").instantiate(); root.add_child(scene); current_scene = scene; scene.show_loadout15("campaign",true)
	else:
		load("res://scripts/campaign/campaign_world.gd").resume_requested = false
		scene = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); scene.checkpoint_enabled = false; root.add_child(scene); current_scene = scene
		scene.waves.set_physics_process(false); scene.horde_left = 600; scene.resources.pending = 0
		if "--blood" in args: scene.v15.day.clock = 990; scene.v15.day.blood = true; scene.v15.day.apply_light(); scene.v15.core_alert()
		if "--systems" in args: scene.hud.show_systems15()
		if "--events" in args:
			scene.player.position = SectorGenerator.EXITS[1]; scene.travel_cooldown = 0; scene.step_sector(1); scene.v15.tick_sector_event(.1)
			var key: String = scene.v15.sector_event_key()
			if scene.v15.active_events.has(key): scene.player.position = scene.v15.active_events[key].global_position+Vector3(0,0,5)
		if "--map" in args: scene.hud.show_routes()
	GameSettings.fullscreen = false; root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648) if MobilePlatform.enabled() else Vector2i(1280,800)
	await create_timer(1.2).timeout; await RenderingServer.frame_post_draw
	var tag := ("mobile" if MobilePlatform.enabled() else "desktop")+"-"+("loadout" if "--loadout" in args else "systems" if "--systems" in args else "events" if "--events" in args else "map" if "--map" in args else "blood" if "--blood" in args else "day")
	DirAccess.make_dir_recursive_absolute("res://builds/review15")
	print("PREVIEW15 ",tag," ",root.get_texture().get_image().save_png("res://builds/review15/"+tag+".png"))
	scene.queue_free(); await create_timer(.3).timeout; quit()
