extends SceneTree
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.get_parent().remove_child(enemy); enemy.queue_free()
func state(kind: String) -> Dictionary:
	return {"kind":kind,"hp":20000.0,"dead":false,"reward":{},"loot_created":false,"stocks":{},"pos":[15.0,0.0]}
func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args(); GameSettings.volume = 0; GameSettings.music_volume = 0
	var inner_safe := true
	for seed_value in range(200):
		for x in range(-1,2):
			for y in range(-1,2): inner_safe = inner_safe and Exploration16.roll(seed_value+1,Vector2i(x,y))!="titan"
	check(inner_safe,"new Titans never roll inside the central three-by-three sectors")
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false; load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	var a: Node3D = w.player; a.global_position = Vector3(24,0,24); a.health.setup(100)
	w.phase = "combat"; w.waves.running = true
	for i in range(9):
		if a.bag.slots[i].id=="bat": a.bag.selected = i
	a.weapons.sync_hand(); a.weapons.cooldown = 0
	var victims := []
	for offset in [Vector3(0,0,-1.5),Vector3(-.4,0,-1.6),Vector3(.4,0,-1.7),Vector3(.8,0,-1.6),Vector3(1.2,0,-1.4)]:
		var enemy: Node3D = w.make_enemy(0,a.global_position+offset,false,-1); enemy.set_physics_process(false); enemy.health.setup(10000); victims.append(enemy)
	await physics_frame; await physics_frame
	check(a.weapons.shoot(Vector3.FORWARD),"the bat still performs an authoritative swing")
	check(victims.filter(func(e): return e.health.current<10000).size()==3,"one bat swing damages at most three simultaneous targets")
	check(victims.all(func(e): return e.health.current>=9982),"bat damage is reduced to eighteen before upgrades")
	check(victims.all(func(e): return e.stun_left==0),"bat hits do not apply or refresh zombie stun")
	check(is_equal_approx(a.weapons.cooldown,.9) and not a.weapons.shoot(Vector3.FORWARD),"bat swings respect the slower cooldown")
	var close: Node3D = victims[0]; close.global_position = a.global_position+Vector3(0,0,-.80); close.target = a; close.think_left = 99; close.ability_left = 99; close.attack_left = 0
	var hp: float = a.health.current
	for frame in range(90):
		if frame in [0,54]: a.weapons.cooldown = 0; a.weapons.shoot(Vector3.FORWARD)
		close._physics_process(1.0/60.0); await physics_frame
	check(a.health.current<hp,"a zombie touching a bat user continues its melee attack and deals damage")
	clear_enemies(); await process_frame; await physics_frame
	# Empty, deterministic sector geometry isolates spawning and interaction from procedural terrain.
	var coord := Vector2i(1,0); w.sector_coord = coord; a.region_coord = coord
	w.descriptor = SectorGenerator.generate(8842,coord,1,1); w.descriptor.special16 = "normal"
	w.field_root = Node3D.new(); w.add_child(w.field_root); w.field_root.position = w.sector_offset(coord); w.area_index = 0
	var floor_body := StaticBody3D.new(); w.field_root.add_child(floor_body); VisualFactory.collider(floor_body,Vector3(108,.3,108),Vector3(0,-.2,0))
	var key: String = w.v15.sector_event_key()
	w.v15.event_states[key] = {"type":"nest","complete":false,"started":false,"left":45.0,"spawn":0.0,"bonus":false,"owner":""}
	a.global_position = w.field_root.to_global(Vector3(12,0,0)); w.v15.tick_sector_event(.01)
	var nest: Node3D = w.v15.active_events[key]
	for i in range(12):
		w.v15.event_states[key].spawn = 0; w.v15.tick_sector_event(.1)
		for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
		await physics_frame
	var guards := get_nodes_in_group("enemies").filter(func(e): return e.get_meta("nest_owner15","")==key)
	check(guards.size()==Director15.NEST_CAP and nest.health.maximum == 520.0,"an active nest has 520 HP and caps its live defenders at nine")
	check(guards.any(func(e): return e.enemy_kind == 3) and guards.any(func(e): return e.enemy_kind == 12),
		"the nest mixes armored and charging reinforcements")
	check(guards.all(func(e): return e.get_meta("nest_speed",false)),"nest guards receive the regional speed bonus")
	check(MobileTargeting.alive(nest) and w.target_enemy(nest.net_id)==nest,"nest is a valid mobile hostile target without becoming a wave zombie")
	a.global_position = nest.global_position+Vector3(0,0,3)
	a.bag.selected = 0; a.weapons.sync_hand(); a.weapons.ammo[0] = 12; a.weapons.cooldown = 0
	await physics_frame; await physics_frame
	hp = nest.health.current; a.weapons.shoot(Vector3.FORWARD)
	check(nest.health.current<hp,"ordinary pistol shots damage the nest")
	check(w.v15.event_states[key].hp==nest.health.current,"nest damage is retained in the event save")
	var memory: Dictionary = SectorMemory.capture(w)
	check(memory.enemies.all(func(e): return e.get("nest_owner15","")==key),"saved guards retain their nest owner")
	check(Director15.valid(w.v15.dump()),"the event save accepts nest health and spawn progression")
	var count_before := guards.size(); a.region_coord = Vector2i.ZERO; w.v15.event_states[key].spawn = 0; w.v15.tick_sector_event(4)
	check(get_nodes_in_group("enemies").size()==count_before,"an empty sector does not keep spawning nest guards")
	a.region_coord = coord; nest.take_damage(10000); await process_frame
	w.v15.tick_sector_event(4)
	check(w.v15.event_states[key].complete and get_nodes_in_group("enemies").size()==count_before,"destroying the nest stops future spawns")
	check(guards.all(func(e): return not e.get_meta("nest_speed",false)),"destroying the nest removes its speed bonus")
	clear_enemies(); await process_frame
	coord = Vector2i(2,0); w.sector_coord = coord; a.region_coord = coord; w.field_root.position = w.sector_offset(coord); a.global_position = w.sector_offset(coord)
	w.exp16.sectors["2:0"] = state("post"); w.waves.running = false; w.phase = "prep"
	var context: Dictionary = w.mobile_context(a)
	check(context.get("post16",false) and context.shop and context.collect=="NEGOCIAR","safe post exposes a mobile negotiation action")
	w.is_client = true; w.client_scene_ready = true; w.remote_mobile_context = context
	w.exp16.load_sector(); var post: Node3D = w.exp16.nodes["2:0"].root; var child_count := post.get_child_count(); w.exp16.load_sector()
	check(post.find_children("*","MeshInstance3D",true,false).size()>10 and post.get_child_count()==child_count,"client builds the safe-post visual exactly once")
	if MobilePlatform.enabled():
		w.touch_controls.context = context; w.touch_controls.interaction_text = "NEGOCIAR"; w.touch_controls.layout_controls()
		check(w.touch_controls.buttons.has("interact") and not w.touch_controls.buttons.has("shop"),"safe post shows one negotiation button instead of duplicated actions")
		var tap := InputEventScreenTouch.new(); tap.index = 4; tap.pressed = true; tap.position = w.touch_controls.buttons.interact.get_center(); w.touch_controls._input(tap)
		check(w.touch_controls.fingers.is_empty() and not w.touch_controls.interact_held,"negotiation touch clears held fingers and opens immediately")
	else: w.open_shop()
	check(w.hud.mode=="post16","the shop action opens the safe-post trading screen on the client")
	w.hud.close_modal(); w.is_client = false
	a.bag.add("scrap",90); var kits: int = a.bag.count("medkit"); var scrap: int = a.bag.count("scrap")
	check(w.exp16.trade(a,"medkit") and a.bag.count("medkit")==kits+1 and a.bag.count("scrap")==scrap-45,"safe-post purchase remains authoritative and spends backpack materials")
	coord = Vector2i(3,0); w.sector_coord = coord; a.region_coord = coord; w.field_root.position = w.sector_offset(coord); a.global_position = w.sector_offset(coord)
	w.exp16.sectors["3:0"] = state("titan"); w.exp16.load_sector(); w.exp16.nodes["3:0"].boss.set_physics_process(false); w.notify("SECTOR ENTRY")
	await process_frame
	check(w.notice.contains("TITÃ") and w.notice.contains("3:0"),"Titan warning appears after the sector-entry notification")
	w.queue_free(); await process_frame; await process_frame; await create_timer(.25).timeout
	print("RC8 COMBAT EVENTS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
