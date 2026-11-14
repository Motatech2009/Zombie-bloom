extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func run() -> void:
	var link: Node = root.get_node("Coop"); link.host_session(24585)
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false
	root.add_child(w); current_scene = w; w.waves.set_physics_process(false); w.set_process(false)
	var deadline := Time.get_ticks_msec()+14000
	while (w.party_count()<3 or w.avatars.keys().any(func(id): return id!=1 and int(link.scene_confirmed.get(id,-1))!=w.peer_revision(id))) and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(w.party_count()==3,"two real remote guests finish their initial scene handshake")
	if w.party_count()!=3: quit(1); return
	for actor in w.avatars.values():
		actor.invulnerable = 3600
		actor.position = SectorGenerator.EXITS[0 if actor.peer_id==1 else 2]
	w.player.set_physics_process(false)
	check(w.perform_action(1,"travel",{"direction":0}),"the host travels north while remote guests remain at the base's southern exit")
	w.notify("SPLIT_READY"); w.notice_left = 30
	deadline = Time.get_ticks_msec()+10000
	while w.avatars.values().any(func(a): return a.peer_id!=1 and a.region_coord!=Vector2i(0,1)) and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(w.avatars.values().all(func(a): return a.region_coord==(Vector2i(0,-1) if a.peer_id==1 else Vector2i(0,1))),"both guests independently enter one southern sector while the host remains north")
	for house in get_nodes_in_group("raid_houses"): house.set_physics_process(false)
	var i := 0
	for actor in w.avatars.values():
		if actor.peer_id==1: continue
		actor.position = w.sector_offset(actor.region_coord)+Vector3(-5+i*10,0,-40); i += 1
		w.spawn_loot(actor.position+Vector3(0,0,-1),{"wood":4},0,"",0,false)
	w.notify("SPLIT_LOOT"); w.notice_left = 30
	deadline = Time.get_ticks_msec()+9000
	while w.avatars.values().any(func(a): return a.peer_id!=1 and a.bag.count("wood")<4) and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(w.avatars.values().all(func(a): return a.peer_id==1 or a.bag.count("wood")==4),"guests collect separate southern crates through authoritative held input")
	var bats: Array = []
	for actor in w.avatars.values():
		if actor.peer_id==1: continue
		var enemy: Node3D = w.regions.run_in(actor.region_coord,func(): return w.make_enemy(0,actor.position-w.sector_offset(actor.region_coord)+Vector3(0,0,-1.8),true,-1))
		enemy.set_physics_process(false); enemy.health.setup(500); bats.append(enemy)
	w.notify("SPLIT_BAT"); w.notice_left = 30
	deadline = Time.get_ticks_msec()+7000
	while bats.any(func(e): return e.health.current>=500) and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(bats.all(func(e): return e.health.current<500),"both remote baseball bats damage nearby southern enemies on the host")
	check(w.sector_coord==Vector2i(0,-1) and w.player.region_coord==Vector2i(0,-1),"remote actions do not change the host's local sector or player pointer")
	w.horde_left = 0; w.waves.start(); w.notify("SPLIT_WAVE"); w.notice_left = 30
	await create_timer(.8).timeout
	check(w.waves.running and w.party_count()==3,"one core horde starts while the party is split across quadrants")
	w.notify("SPLIT_DONE"); w.notice_left = 30
	deadline = Time.get_ticks_msec()+8000
	while w.party_count()>1 and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(w.party_count()==1,"the split-sector guests can disconnect without losing the host")
	link.close_session(); w.queue_free(); await create_timer(.25).timeout
	print("SPLIT HOST RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
