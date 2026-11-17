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
	if view in ["menu","profile","elos","shop","account","trophy"]:
		scene = load("res://scenes/main/MainMenu.tscn").instantiate(); root.add_child(scene); current_scene = scene
		match view:
			"profile": Menu16.profile(scene)
			"elos": Menu16.ranks(scene,"elos")
			"shop": Menu16.shop(scene)
			"account": scene.show_account()
			"trophy":
				Menu16.shop(scene,"all")
				var actor: Node3D = scene.content.find_child("Preview",true,false)
				Cosmetics16.decorate(actor.get_child(0),{"head":"COS-TITAN-01"})
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
		if view=="defenses":
			for entry in [[FortressData.pieces().size()-1,Vector3(10,0,0)],[0,Vector3(10,0,-3.5)],[7,Vector3(14,0,-6)]]:
				var piece := StaticBody3D.new(); piece.set_script(load("res://scripts/fortress/fortress_structure.gd")); piece.world = scene; piece.piece_index = entry[0]; piece.position = entry[1]; scene.base_root.add_child(piece)
			scene.player.position = Vector3(10,0,3)
			scene.builder.active = true; scene.builder.selected = FortressData.pieces().size()-1; scene.builder.location = Vector3(10,0,0); scene.builder.set_physics_process(false)
			scene.set_process(false); scene.camera.size = 24; scene.camera.position = Vector3(28,23,22); scene.camera.look_at(Vector3(10,0,-1))
			scene.truce16.left = 600; scene.truce16.pending = true
		if view in ["turret-models","cannon-models","tesla-models","raised-models"]:
			var selected_piece: int = {"turret-models":1,"cannon-models":8,"tesla-models":9,"raised-models":11}[view]
			for tier in range(1,4):
				var piece := StaticBody3D.new(); piece.set_script(load("res://scripts/fortress/fortress_structure.gd")); piece.world = scene; piece.piece_index = selected_piece; piece.tier = tier; piece.position = Vector3(5+tier*5,0,16); piece.rotation.y = tier*.5; scene.base_root.add_child(piece); piece.set_physics_process(false)
				piece.aim_at(piece.global_position+Vector3(0,1.45,-20)); piece.label.visible = true; piece.label.text = str(FortressData.pieces()[selected_piece].title)+" · NV. "+str(tier)
			scene.player.position = Vector3(14,0,19); scene.player.set_physics_process(false)
			scene.set_process(false); scene.camera.size = 13; scene.camera.position = Vector3(27,16,32); scene.camera.look_at(Vector3(15,.6,16))
		if view=="core-models":
			for tier in range(1,5):
				var model: Node3D = load("res://assets/fortress/core_"+str(tier)+".tscn").instantiate(); model.position = Vector3(3+tier*5,0,16); scene.base_root.add_child(model)
				var label := VisualFactory.health_label(model,3.5); label.text = "NÚCLEO · NV. "+str(tier); label.font_size = 24
			scene.player.position = Vector3(0,0,8); scene.player.set_physics_process(false); scene.set_process(false); scene.camera.size = 18; scene.camera.position = Vector3(29,19,33); scene.camera.look_at(Vector3(15,.6,16))
		if view=="cosmetic-models":
			var outfits := [
				{"head":"COS-ENG-01","outfit":"COS-ENG-03","backpack":"COS-ENG-05"},
				{"head":"COS-ENG-02","outfit":"COS-ENG-04","backpack":"COS-ENG-05"},
				{"head":"COS-BAT-01","outfit":"COS-BAT-03","backpack":"COS-BAT-05"},
				{"head":"COS-BAT-02","outfit":"COS-BAT-04","backpack":"COS-BAT-05"},
				{"head":"COS-ATI-01","outfit":"COS-ATI-03","backpack":"COS-ATI-05"},
				{"head":"COS-ATI-02","outfit":"COS-ATI-04","backpack":"COS-ATI-05"},
				{"head":"COS-UNI-01","outfit":"COS-UNI-02","backpack":"COS-UNI-03"},
				{"head":"COS-TITAN-01"}]
			for i in range(outfits.size()):
				var rig := VisualFactory.human(scene.base_root,Color("56777d"),true); rig.position = Vector3(7+(i%4)*4,0,13+(i/4)*5); Cosmetics16.decorate(rig,outfits[i])
			scene.player.position = Vector3(0,0,8); scene.player.set_physics_process(false); scene.set_process(false); scene.camera.size = 15; scene.camera.position = Vector3(28,17,33); scene.camera.look_at(Vector3(13,.8,16))
		if view=="diversion":
			scene.player.bag.add("decoy16",1); scene.hud.show_inventory()
			scene.spawn_loot(Vector3(3,0,1),{"decoy16":1})

	await create_timer(1.3).timeout; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/review16")
	var tag := ("mobile-" if MobilePlatform.enabled() else "desktop-")+view
	print("PREVIEW16 ",tag," result=",root.get_texture().get_image().save_png("res://builds/review16/"+tag+".png"))
	scene.queue_free(); await create_timer(.35).timeout; quit()
