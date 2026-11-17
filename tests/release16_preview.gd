extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args(); var view := "menu"
	for arg in args:
		if arg.begins_with("--view="): view = arg.trim_prefix("--view=")
	MobilePlatform.force_touch = "--mobile" in args
	root.content_scale_size = Vector2i(960,540) if MobilePlatform.enabled() else Vector2i(1440,900)
	GameSettings.fullscreen = false; root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1152,648) if MobilePlatform.enabled() else Vector2i(1280,800)
	var scene: Node3D
	if view in ["menu","profile","elos","shop","account"]:
		scene = load("res://scenes/main/MainMenu.tscn").instantiate(); root.add_child(scene); current_scene = scene
		match view:
			"profile": Menu16.profile(scene)
			"elos": Menu16.ranks(scene,"elos")
			"shop": Menu16.shop(scene)
			"account": scene.show_account()
	else:
		load("res://scripts/campaign/campaign_world.gd").resume_requested = false
		load("res://scripts/campaign/campaign_world.gd").next_mode = "rescue" if view=="rescue" else "endless"
		scene = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); scene.checkpoint_enabled = false; root.add_child(scene); current_scene = scene
		scene.waves.set_physics_process(false); scene.horde_left = 600
		if view=="cards": scene.waves.wave = 1; scene.upgrades.award_horde(1); scene.upgrades.roll(); scene.hud.show_upgrade()
		if view in ["post","titan"]:
			var key := "1:0"; scene.exp16.sectors[key] = {"kind":view,"hp":20000.0,"dead":false,"reward":{},"loot_created":false,"stocks":{},"pos":[15.0,0.0]}
			scene.player.position = SectorGenerator.EXITS[1]; scene.travel_cooldown = 0; scene.step_sector(1)
			scene.player.position = scene.sector_offset(Vector2i(1,0))+Vector3(5,0,7)
			if view=="post": scene.hud.show_post16()
		if view=="rescue": scene.hud.show_systems15()
	await create_timer(1.3).timeout; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/review16")
	var tag := ("mobile-" if MobilePlatform.enabled() else "desktop-")+view
	print("PREVIEW16 ",tag," result=",root.get_texture().get_image().save_png("res://builds/review16/"+tag+".png"))
	scene.queue_free(); await create_timer(.35).timeout; quit()
