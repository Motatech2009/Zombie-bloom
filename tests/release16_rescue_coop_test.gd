extends SceneTree
var checks := 0
var failures := 0
var role := "host"
var tag := "1"
var count := 4
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--players="): count = int(arg.trim_prefix("--players="))
	var link: Node = root.get_node("Coop")
	if role=="host": await host(link)
	else: await guest(link)
	link.close_session(); if is_instance_valid(current_scene): current_scene.queue_free()
	await create_timer(.4).timeout
	print("RESCUE16 %s-%s RESULT: %d checks, %d failures" % [role,tag,checks,failures]); quit(1 if failures else 0)
func travel(w: Node3D,direction: int) -> bool:
	w.player.region_travel_left = 0; w.player.position = w.sector_offset(w.player.region_coord)+SectorGenerator.EXITS[direction]
	return w.perform_action(1,"travel",{"direction":direction})
func finish_horde(w: Node3D) -> void:
	var enemy: Node3D = w.waves.spawn_enemy()
	enemy.set_physics_process(false); enemy.choose_target()
	check(enemy.target==w.core or enemy.target==w.rescue16.objective or enemy.target in w.avatars.values(),"mission enemy chooses a valid local objective")
	enemy.take_damage(1000000); await create_timer(.1).timeout
	w.rescue16.left = 0; w.waves.to_spawn = 0; w.waves.complete()
	if w.phase=="ended": return
	check(w.upgrades.choose(0),"host can select its own mission-horde upgrade")
	var deadline := Time.get_ticks_msec()+8000
	while w.combat_paused() and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(not w.combat_paused(),"remote participants resolve their own mission rewards")
func host(link: Node) -> void:
	check(link.host_session(24578)==OK,"rescue ENet server opens")
	load("res://scripts/campaign/campaign_world.gd").next_mode = "rescue"; load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var path: String = load("res://scripts/survival/survival_world.gd").survival_path("campaign")
	var old := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); root.add_child(w); current_scene = w
	w.waves.set_physics_process(false); w.set_process(false); w.player.set_physics_process(false)
	var deadline := Time.get_ticks_msec()+15000
	while w.party_count()<count and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(w.party_count()==count,"all remote expedition participants join")
	if w.party_count()!=count: return
	for a in w.avatars.values(): a.invulnerable = 3600
	check(travel(w,1) and travel(w,2),"host really explores two sectors to reach the signal")
	w.player.position = w.sector_offset(Rescue16.SIGNAL)
	check(w.perform_action(1,"mission16",{}),"host recovers the shared signal once")
	check(travel(w,1),"host reaches the station while teammates remain at the core")
	w.player.position = w.sector_offset(Rescue16.STATION)
	check(w.perform_action(1,"mission16",{}),"station interaction starts first defense")
	w.rescue16.objective.take_damage(10)
	await create_timer(.4).timeout
	await finish_horde(w); w.rescue16.tick(0)
	check(w.waves.wave==2 and w.waves.running,"second formal horde follows independent choices")
	await finish_horde(w)
	check(w.rescue16.phase=="return","station defense unlocks extraction route")
	check(travel(w,3) and travel(w,0) and travel(w,3),"return route remains traversable without restoring campaign")
	w.player.position = Vector3.ZERO
	check(w.perform_action(1,"mission16",{}),"team extraction starts third formal horde")
	await finish_horde(w)
	check(w.won and w.rescue16.phase=="complete","rescue reaches authoritative victory")
	check((FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "")==old,"rescue leaves the campaign checkpoint byte-for-byte unchanged")
	await create_timer(2).timeout
func guest(link: Node) -> void:
	MobilePlatform.force_touch = tag=="3"
	link.identity = tag.repeat(32); check(link.join_session("127.0.0.1",24578,"Rescuer "+tag)==OK,"guest joins rescue")
	var deadline := Time.get_ticks_msec()+18000
	while not is_instance_valid(link.world) and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	if not is_instance_valid(link.world): check(false,"guest receives rescue scene"); return
	var w: Node3D = link.world
	var chosen: Dictionary = {}; var saw_station := false
	deadline = Time.get_ticks_msec()+25000
	while not w.won and w.phase!="ended" and Time.get_ticks_msec()<deadline:
		saw_station = saw_station or w.rescue16.goal_hp==490
		var choice: Dictionary = w.upgrades.current(w.player)
		if not choice.is_empty() and not w.waves.running and not chosen.has(choice.id):
			chosen[choice.id] = true; w.send_action("choice",{"index":0,"choice_id":choice.id})
		await create_timer(.06).timeout
	check(w.game_mode=="rescue" and w.won,"guest receives mission mode and final victory through snapshots")
	check(saw_station,"objective damage is replicated to remote participants")
	check(chosen.size()==2,"guest independently chooses two defense upgrades before final extraction")
