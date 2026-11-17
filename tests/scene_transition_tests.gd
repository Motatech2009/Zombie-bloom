extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func make_world(mode: String) -> Node3D:
	load("res://scripts/campaign/campaign_world.gd").next_mode = mode
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.waves.set_physics_process(false); w.player.set_physics_process(false)
	return w
func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	GameSettings.volume = .5; GameSettings.music_volume = .45
	var meta: Node = root.get_node("Meta16")
	meta.uid = "scene-transition-test"; meta.api_url = ""; meta.sync_left = 999
	for scenario in ["campaign","endless","post","titan","rescue","host"]:
		meta.titan_earned = {}; meta.titan_pending = []
		if scenario=="host": check(root.get_node("Coop").host_session(24603)==OK,"real transport opens for host exit")
		var w := make_world(scenario if scenario in ["campaign","rescue"] else "endless")
		if scenario in ["endless","post","titan"]:
			w.exp16.sectors["1:0"] = {"kind":scenario if scenario!="endless" else "normal","hp":20000.0,"dead":false,"reward":{},"loot_created":false,"stocks":{},"pos":[15.0,0.0]}
			w.player.position = SectorGenerator.EXITS[1]; w.travel_cooldown = 0
			check(w.step_sector(1),scenario+" exit starts in an explored sector")
		if scenario=="titan":
			var boss: Node3D
			for enemy in get_nodes_in_group("enemies"):
				if enemy.spec.id=="titan16": boss = enemy
			if boss!=null:
				boss.set_physics_process(false); boss.roots16 = [boss.position]
				var ring := VisualFactory.ring(w.effects,2.4,boss.position,Color.GREEN)
				ring.add_to_group("titan_root_warnings"); ring.set_meta("owner16",boss.net_id)
		await create_timer(.12).timeout
		meta._process(0)
		var match_id: String = w.account_run_id
		var before: int = meta.pending.size()
		w.upgrades.state(w.player).through = 1
		w.player.set_meta("titan_owner16",meta.uid); w.player.set_meta("titan_victory16",match_id.sha256_text())
		w.hud.show_pause()
		var button: Button
		for child in w.hud.overlay_box.get_children():
			if child is Button and child.text in ["VOLTAR AO MENU","ENCERRAR SALA"]: button = child
		check(button!=null,scenario+" exposes a real return button")
		if button==null: quit(1); return
		button.pressed.emit(); button.pressed.emit()
		await create_timer(.25).timeout
		check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/main/MainMenu.tscn" and not paused,scenario+" repeated clicks reach an unpaused menu")
		check(not is_instance_valid(w) and meta.world==null,scenario+" releases the old world and account reference")
		check(meta.pending.size()==before+1 and meta.titan_earned.has(match_id.sha256_text()),scenario+" preserves the final horde credit and Titan trophy")
		var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(meta.path()))
		check(stored.pending.size()==meta.pending.size() and stored.titan_earned.has(match_id.sha256_text()),scenario+" final rewards are persisted on disk")
		var total: float = meta.clock.total
		await create_timer(.08).timeout; meta._process(0)
		check(meta.clock.total==total,scenario+" menu never adds active play time")
		check(root.get_node("Coop").mode=="offline" and root.get_node("Coop").world==null,scenario+" transport is detached")
		current_scene.queue_free(); await process_frame; await process_frame
	var w := make_world("endless")
	w.hud.show_pause(); w.hud.restart(); w.hud.restart()
	await create_timer(.3).timeout
	check(not is_instance_valid(w) and is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/survival/SurvivalWorld.tscn","repeated restart loads exactly one new game")
	check(meta.world==current_scene and meta.has_live_world(),"old scene teardown never clears the new account binding")
	current_scene.checkpoint_enabled = false; current_scene.queue_free()
	await create_timer(.3).timeout
	DirAccess.remove_absolute(meta.path())
	print("SCENE TRANSITION RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
