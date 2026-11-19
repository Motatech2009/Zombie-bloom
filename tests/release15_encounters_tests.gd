extends SceneTree
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func boss(stage: int,pos: Vector3) -> Node3D:
	w.restoring_boss_stage = stage
	var actor: Node3D = w.make_enemy(8,pos,false,-1); actor.set_physics_process(false); w.restoring_boss_stage = 0; return actor
func structure(piece: int,pos: Vector3) -> Node3D:
	var node := StaticBody3D.new(); node.set_script(load("res://scripts/fortress/fortress_structure.gd")); node.world = w; node.piece_index = piece; node.position = pos; node.invested = FortressData.pieces()[piece].cost.duplicate(); w.base_root.add_child(node); node.set_physics_process(false); return node
func clear_enemies() -> void:
	for actor in get_nodes_in_group("enemies"): actor.get_parent().remove_child(actor); actor.queue_free()
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); preload("res://tests/legacy_sector_fixture16.gd").normal(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false); w.resources.scrap = 10000; w.stock = {"wood":10000,"parts":10000}
	var mauler = boss(1,Vector3(30,0,30)); mauler.cast_point = Vector3(30,0,15); mauler.boss_cast()
	check(mauler.rush_left>0 and mauler.rush_direction.z<-.9,"Quebra-Muros starts a directed siege charge")
	var mortar = boss(2,Vector3(30,0,30)); mortar.cast_point = Vector3(35,0,35); mortar.boss_cast()
	var shot = get_nodes_in_group("campaign_projectiles").back(); shot.set_physics_process(false); shot._physics_process(1.3)
	check(get_nodes_in_group("acid_pools").back().life==6,"Caldeirao leaves a six-second corrosive pool")
	clear_enemies(); await process_frame
	var mother = boss(3,Vector3(30,0,30)); mother.boss_cast(); mother.health.current = mother.health.maximum*.5
	var hp: float = mother.health.current; mother._physics_process(1.1)
	check(mother.health.current>hp,"Matriarch heals while her own summoned dogs survive")
	for dog in get_nodes_in_group("enemies"):
		if dog!=mother: dog.get_parent().remove_child(dog); dog.queue_free()
	hp = mother.health.current; mother._physics_process(1.1)
	check(is_equal_approx(mother.health.current,hp),"killing linked dogs stops regeneration")
	clear_enemies(); await process_frame
	var flyer = boss(4,Vector3(25,2.8,25)); flyer.cast_point = Vector3(25,0,10); flyer.boss_cast(); flyer._physics_process(.3)
	check(flyer.extra_motion=="rain" and flyer.leap_left>0 and flyer.get_meta("rain_step",0)>0,"Tempestade performs a moving aerial spore run")
	var predator = boss(5,Vector3(20,0,20)); w.player.position = Vector3(20,0,16); w.player.health.setup(100); predator.cast_point = w.player.position; predator.boss_cast(); predator._physics_process(.85)
	check(w.player.pinned_left==1.5 and w.player.pin_owner==predator,"Predator landing pins its survivor target")
	w.player.roll_cooldown = 0; w.player.start_roll(Vector3.RIGHT)
	check(w.player.pinned_left==0,"rolling breaks the predatory pin")
	w.player.stop_roll(); w.player.pinned_left = 1.5; w.player.pin_owner = predator; w.shot_owner = 222; predator.take_damage(1); w.shot_owner = 0
	check(w.player.pinned_left==0,"an allied hit releases the pinned survivor")
	clear_enemies(); await process_frame
	var tower = structure(1,Vector3(32,0,25)); var parasite: Node3D = w.make_enemy(17,Vector3(33,0,25),false,-1); parasite.set_physics_process(false)
	parasite._physics_process(5)
	check(tower.disabled_left>0 and parasite.growth>0,"parasite attaches to a turret and drains it")
	parasite._physics_process(5.1)
	check(parasite.spec.id=="brute" and parasite.is_in_group("wave_enemies"),"parasite grows into a Bruto without losing wave accounting")
	var wall = structure(2,Vector3(35,0,30)); var bridge: Node3D = w.make_enemy(19,Vector3(35,0,29),false,-1); bridge.set_physics_process(false); bridge.take_damage(100000)
	check(get_nodes_in_group("clay_ramps").size()==1,"Ponte de Carne leaves a temporary ramp next to defenses")
	w.v15.tick(10.1); check(get_nodes_in_group("clay_ramps")[0].is_queued_for_deletion(),"ramp expires after ten seconds")
	var recycler = structure(10,Vector3(25,0,30)); w.player.position = recycler.position+Vector3(2,0,0); w.player.bag.add("wood",20); var parts: int = w.stock.parts
	check(w.v15.recycle(w.player) and w.stock.parts==parts+2 and w.player.bag.count("wood")==0,"recycler atomically converts wood into components")
	w.player.position = w.vendor_pos+Vector3(0,0,2)
	check(w.v15.buy_beacon(w.player) and not w.v15.buy_beacon(w.player),"Bento's rare beacon stock is limited to one per preparation")
	clear_enemies(); await process_frame
	w.player.position = SectorGenerator.EXITS[1]; w.travel_cooldown = 0; w.resources.pending = 0; w.step_sector(1)
	var key: String = w.v15.sector_event_key(); w.v15.event_states[key] = {"type":"convoy","complete":false,"started":false,"left":45.0,"spawn":0.0,"bonus":false,"owner":""}
	w.v15.tick_sector_event(.1); var convoy = w.v15.active_events[key]; w.player.position = convoy.global_position+Vector3(0,0,3)
	check(w.v15.event_interactable(w.player) and w.v15.interact_event(w.player),"convoy exposes the same PC and touch interaction")
	w.v15.tick_sector_event(1.0)
	var attackers: Array = w.v15.guards_for("convoy_owner17", key)
	for attacker in attackers: attacker.set_physics_process(false)
	check(attackers.size() >= 2, "convoy sends multiple attackers from its perimeter")
	var saved_guards: Dictionary = SectorMemory.capture(w)
	check(saved_guards.enemies.any(func(entry): return entry.get("convoy_owner17") == key),
		"event attackers stay linked to their convoy when the sector is saved")
	w.v15.tick_sector_event(59.1)
	check(not w.v15.event_states[key].complete, "convoy requires clearing surviving attackers after sixty seconds")
	for attacker in attackers: attacker.take_damage(100000.0)
	w.v15.tick_sector_event(.1)
	check(w.v15.event_states[key].complete and w.player.weapons.tuning[2]>=1,"defending convoy unlocks reinforced rifle reward once")
	var supplies := get_nodes_in_group("survival_loot").filter(func(pile): return pile.contents.get("scrap", 0) == 180)
	check(supplies.size() == 1 and supplies[0].contents.parts == 28 and supplies[0].contents.rifle_ammo == 90,
		"one convoy reward includes scrap, components and rifle ammunition")
	check(w.v15.start_extract(w.player),"beacon starts a four-second return channel in a distant sector")
	w.channel15.tick(4.1)
	check(w.sector_coord==Vector2i.ZERO and w.player.bag.count("beacon")==0,"successful extraction consumes one beacon and returns to the core")
	w.v15.core_alert(); var state: Dictionary = w.net_state(1,true)
	check(state.systems15.alert>0,"remote clients receive the core attack alert")

	w.v15.active_events.clear(); w.player.position = SectorGenerator.EXITS[1]; w.travel_cooldown = 0; w.resources.pending = 0; w.step_sector(1)
	key = w.v15.sector_event_key(); w.v15.event_states[key] = {"type":"nest","complete":false,"started":false,"left":45.0,"spawn":0.0,"bonus":false,"owner":""}
	var infected: Node3D = w.make_enemy(0,Vector3(30,0,30),true,100); infected.set_physics_process(false); var speed: float = infected.spec.values.speed
	w.v15.tick_sector_event(.1)
	check(is_equal_approx(infected.spec.values.speed,speed*1.2),"spore nest boosts only enemies in its loaded sector")
	check(w.v15.event_for_sector(w.sector_coord).type=="nest","nest is exposed to the sector map")
	w.v15.active_events[key].take_damage(10000)
	check(w.v15.event_states[key].complete and is_equal_approx(infected.spec.values.speed,speed),"destroying nest removes regional speed bonus")
	await process_frame; w.v15.active_events.erase(key)
	w.v15.event_states[key] = {"type":"escort","complete":false,"started":false,"left":45.0,"spawn":0.0,"bonus":false,"owner":""}
	w.v15.tick_sector_event(.1); var npc = w.v15.active_events[key]; w.player.position = npc.global_position+Vector3(0,0,2)
	check(w.v15.interact_event(w.player),"lost survivor accepts an escort interaction")
	clear_enemies(); await physics_frame
	var hostile: Node3D = w.make_enemy(0, w.field_root.to_local(npc.global_position + Vector3(0,0,5)), true, -1)
	hostile.set_physics_process(false)
	await physics_frame
	var hostile_hp: float = hostile.health.current
	w.v15.update_escort(key, w.v15.event_states[key], .75)
	check(hostile.health.current < hostile_hp and npc.escort_recoil > 0.0, "the survivor helps shoot a visible zombie during the rescue")
	w.extract_solo15(w.player); parts = w.stock.parts
	w.player.global_position = Vector3(18,0,0)
	w.v15.update_events(.1)
	check(not w.v15.event_states[key].complete and is_instance_valid(npc), "entering the base sector alone does not finish the rescue")
	w.player.global_position = Vector3(3,0,1)
	for i in range(30): w.v15.update_events(.2)
	check(w.v15.event_states[key].complete and w.stock.parts==parts+12,"survivor escort rewards components once when delivered to the actual core")
	await create_timer(.3).timeout
	check(not is_instance_valid(npc) and w.stock.parts == parts + 12, "delivered survivor disappears without duplicating the reward")
	var hive = boss(7,Vector3(30,0,30)); var number: int = get_nodes_in_group("enemies").size(); hive.health.current = hive.health.maximum*.69; hive._physics_process(.01)
	check(get_nodes_in_group("enemies").size()==number+6,"hive releases separate swarms for each fifteen-percent health threshold")
	w.queue_free(); await process_frame; await process_frame; await create_timer(.2).timeout
	print("RELEASE15 ENCOUNTERS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
