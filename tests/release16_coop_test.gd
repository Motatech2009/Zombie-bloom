extends SceneTree
var checks := 0
var failures := 0
var role := "host"
var tag := "1"
var target_players := 4
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func total(values: Dictionary) -> int:
	var n := 0
	for value in values.values(): n += int(value)
	return n
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--players="): target_players = int(arg.trim_prefix("--players="))
	MobilePlatform.force_touch = tag=="3" and role!="host"
	root.get_node("Meta16").titan_earned = {}; root.get_node("Meta16").trophy_equipped = {}
	var link: Node = root.get_node("Coop")
	if role=="host": await host(link)
	else: await client(link)
	if is_instance_valid(current_scene) and current_scene.has_method("sync_account_progress"):
		var closing: Node3D = current_scene
		closing.hud.menu(); closing.hud.menu()
		await create_timer(.3).timeout
		check(current_scene.scene_file_path=="res://scenes/main/MainMenu.tscn" and not paused,"connected participant returns to menu after repeated clicks")
		check(not is_instance_valid(closing) and root.get_node("Meta16").world==null and link.world==null and link.mode=="offline","connected scene releases gameplay, account and transport references")
	else: link.close_session()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await create_timer(.4).timeout
	print("RELEASE16 COOP %s-%s RESULT: %d checks, %d failures" % [role,tag,checks,failures]); quit(1 if failures else 0)
func host(link: Node) -> void:
	check(link.host_session(24578)==OK,"real ENet host opens")
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.waves.set_physics_process(false)
	var deadline := Time.get_ticks_msec()+12000
	while w.avatars.size()<target_players and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(w.avatars.size()==target_players,"all real clients join compatible protocol")
	if w.avatars.size()!=target_players: return
	var direction := 0
	var coords: Dictionary = {}
	for actor in w.avatars.values():
		actor.invulnerable = 3600
		actor.bag.equip_level(2); actor.outfit16 = {"head":"COS-ENG-01"}; w.v15.decorate(actor)
		actor.position = SectorGenerator.EXITS[direction]
		check(w.perform_action(actor.peer_id,"travel",{"direction":direction}),"participant travels to its own sector before rewards")
		coords[actor.region_coord] = true
		w.regions.run_in(actor.region_coord,func():
			var boss: Node3D = w.make_enemy(20,Vector3(15,0,-4),true,-1); boss.set_physics_process(false))
		direction += 1
	check(coords.size()==target_players,"reward recipients occupy distinct quadrants")
	w.waves.wave = 1; w.waves.running = true; w.waves.to_spawn = 0; w.waves.complete()
	deadline = Time.get_ticks_msec()+12000
	while w.avatars.values().any(func(a): return a.peer_id!=1 and total(w.upgrades.levels_for(a))!=1) and Time.get_ticks_msec()<deadline:
		await create_timer(.05).timeout
	for a in w.avatars.values():
		if a.peer_id!=1: check(total(w.upgrades.levels_for(a))==1 and w.upgrades.pending_for(a)==0,"guest "+a.display_name+" independently commits exactly one upgrade")
	check(w.resources.pending==1 and w.upgrades.levels.is_empty(),"guest choices never take the host's card or upgrade it")
	check(w.combat_paused(),"host choice still pauses after guests finish")
	var own: Dictionary = w.upgrades.current(w.player)
	check(w.perform_action(1,"choice",{"index":0,"choice_id":own.id}),"host commits its own independent card")
	check(not w.combat_paused(),"all independent choices release combat")
	var visitor: Node3D
	for a in w.avatars.values():
		if a.profile_id=="1".repeat(32): visitor = a
	if visitor!=null:
		visitor.bag.add("decoy16",1)
		visitor.set_meta("titan_victory16","b".repeat(64)); visitor.set_meta("titan_owner16","")
	deadline = Time.get_ticks_msec()+5000
	while w.truce16.left<=0 and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(w.truce16.left>590 and w.truce16.pending and visitor.bag.count("decoy16")==0,"remote participant activates exactly one team diversion")
	await create_timer(3).timeout
	for a in w.avatars.values(): check(total(w.upgrades.levels_for(a))==1,"late replay changes no level for "+a.display_name)
func client(link: Node) -> void:
	link.identity = tag.repeat(32)
	check(link.join_session("127.0.0.1",24578,"Client "+tag)==OK,"guest connects")
	var deadline := Time.get_ticks_msec()+12000
	while (not is_instance_valid(link.world) or link.received_snapshots<3) and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(is_instance_valid(link.world),"guest receives world")
	if not is_instance_valid(link.world): return
	var w: Node3D = link.world
	deadline = Time.get_ticks_msec()+12000
	while w.resources.pending==0 and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(w.resources.pending==1 and w.upgrades.offers.size()==3,"recipient sees exactly its own three cards")
	check(w.player.bag.slots.size()==24 and w.player.outfit16.get("head","")=="COS-ENG-01","functional bag and equipped clay cosmetic replicate independently")
	check(w.client_enemies.values().any(func(e): return e.spec.id=="titan16" and e.health.maximum==20000),"Titan has a native remote model and fixed replicated health")
	var choice: Dictionary = w.upgrades.current(w.player)
	check(str(choice.get("id","")).ends_with(link.identity),"reward is bound to stable identity, not peer slot")
	if choice.is_empty(): return
	var index := int(tag)-1
	var chosen_id: String = choice.offers[index].id
	w.send_action("choice",{"index":index,"choice_id":choice.id})
	await create_timer(.12).timeout
	w.send_action("choice",{"index":index,"choice_id":choice.id})
	deadline = Time.get_ticks_msec()+5000
	while w.resources.pending>0 and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(w.resources.pending==0 and w.upgrades.level_for(w.player,chosen_id)==1,"host confirms own selected level through a real private snapshot")
	check(total(w.upgrades.levels_for(w.player))==1,"replayed RPC does not apply a second card")
	deadline = Time.get_ticks_msec()+5000
	if tag=="1":
		while w.player.bag.count("decoy16")==0 and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
		w.send_action("decoy16",{}); await create_timer(.15).timeout; w.send_action("decoy16",{})
	while w.truce16.left<=0 and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(w.truce16.left>590 and w.truce16.pending,"private network snapshots carry team diversion and upcoming penalty")
	await create_timer(.3).timeout
	check(root.get_node("Meta16").has_cosmetic("COS-TITAN-01")== (tag=="1"),"only the designated contributor receives the private Titan trophy")
	await create_timer(2 if tag=="1" else 4).timeout
