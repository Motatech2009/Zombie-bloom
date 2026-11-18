extends SceneTree
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func stop_world() -> void:
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
func create_world(mode: String = "endless") -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = mode; load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w; stop_world()
func run() -> void:
	GameSettings.volume = 0
	check(Catalog16.talents().size()==9 and Catalog16.data().cosmetics.size()==22,"catalog has nine class talents and 21 shop cosmetics plus one exclusive Titan trophy")
	for base in [18,20]:
		var bag := ItemBag.new(); bag.resize_bag(base); bag.add("field_bag",1)
		check(bag.equip_field_bag() and bag.slots.size()==base+3,"field bag adds three slots on base %d" % base)
		check(not bag.equip_field_bag(),"cannot equip duplicate functional bags")
		check(bag.equip_level(2) and bag.slots.size()==base+6,"reinforced bag adds six slots total")
		bag.slots[base+5] = {"id":"parts","qty":1}
		check(not bag.equip_level(0) and bag.count("parts")==1,"capacity reduction never silently loses an occupied item")
		check(ItemBag.valid(JSON.parse_string(JSON.stringify(bag.dump()))),"bag JSON schema retains capacity/class/level")
		var restored := ItemBag.new(); restored.restore(bag.dump())
		check(restored.bag_level==2 and restored.slots.size()==base+6,"functional bag survives restoration")
	var clock := PlayClock16.new()
	clock.step(0,false)
	for i in range(1,901): clock.step(i*1000,true,true)
	check(is_equal_approx(clock.total,900) and PlayClock16.display(clock.total)=="0h 15min","15 active minutes count 900 seconds")
	for i in range(901,1501): clock.step(i*1000,false,true)
	check(is_equal_approx(clock.total,900),"ten menu minutes add no active time")
	clock.focused = false; clock.step(1501000,true,true)
	check(is_equal_approx(clock.total,900),"unfocused application adds no time")
	clock.focused = true; clock.idle = 299; clock.step(1502000,true,false)
	check(clock.afk and is_equal_approx(clock.total,900),"five-minute inactivity suspends individual time")
	clock.step(1503000,true,true); check(not clock.afk and is_equal_approx(clock.total,901),"relevant input resumes time once")
	check(PlayClock16.display(37380)=="10h 23min","hour formatting never rounds minutes incorrectly")
	var counts := {"normal":0,"post":0,"titan":0}
	for i in range(10000): counts[Exploration16.roll(500+i,Vector2i(2,-1))] += 1
	check(counts.titan>420 and counts.titan<580,"ten thousand eligible sectors yield approximately five percent Titans: "+str(counts.titan))
	check(counts.post>880 and counts.post<1120,"ten thousand eligible sectors yield approximately ten percent posts: "+str(counts.post))
	check(counts.normal+counts.post+counts.titan==10000,"special rolls are mutually exclusive and unconditional")
	create_world()
	w.waves.wave = 1; w.upgrades.award_horde(1)
	check(w.upgrades.current(w.player).offers.any(func(o): return o.get("class_id","")=="engineer"),"eligible choices contain a talent of the actor's class")
	w.upgrades.defer_for(w.player,w.upgrades.current(w.player).id)
	w.upgrades.levels = {"eng_economy":3,"eng_hands":3,"eng_alloy":3}; w.upgrades.apply_actor(w.player)
	check(is_equal_approx(Catalog16.bonus(w.player,"eng_economy"),.15),"engineer talent values apply at their third level")
	w.v15.apply_class(w.player,"scout")
	check(Catalog16.bonus(w.player,"eng_economy")==0,"wrong-class talent values confer no bonus")
	w.upgrades.levels = {"scout_escape":3}; w.upgrades.apply_actor(w.player); w.player.roll_cooldown = 0
	check(w.player.start_roll(Vector3.RIGHT) and is_equal_approx(w.player.roll_cooldown,4.25),"scout escape reduces roll recharge, not invulnerability")
	w.player.stop_roll(); w.player.roll_cooldown = 0
	w.v15.apply_class(w.player,"shooter"); w.upgrades.levels = {"shot_rate":3,"shot_reload":3}; w.upgrades.apply_actor(w.player)
	check(is_equal_approx(w.player.weapons.rate_multiplier,1.09) and is_equal_approx(w.player.weapons.reload_multiplier,.85*.88),"shooter talents combine multiplicatively with class bonuses")
	for item in Catalog16.data().cosmetics:
		var cls: String = "engineer" if item.class_id=="all" else item.class_id
		check(Cosmetics16.valid({item.slot:item.id},cls),"valid cosmetic slot/class: "+item.id)
		Cosmetics16.decorate(w.player.rig,{item.slot:item.id},w.player)
	check(not Cosmetics16.valid({"head":"COS-ENG-01"},"scout"),"wrong-class cosmetics are rejected")
	var coord := Vector2i(1,0); var key := SectorGenerator.key(coord)
	w.exp16.sectors[key] = {"kind":"post","hp":20000.0,"dead":false,"reward":{},"loot_created":false,"stocks":{},"pos":[15.0,0.0]}
	w.player.position = SectorGenerator.EXITS[1]; w.travel_cooldown = 0
	check(w.step_sector(1),"exploration enters a real safe-post sector")
	w.player.position = w.sector_offset(coord); w.player.invulnerable = 0; var hp: float = w.player.health.current
	w.player.take_damage(20); check(w.player.health.current==hp,"safe perimeter blocks ordinary incoming damage")
	w.hud.show_post16(); check(not paused,"safe-post trading never pauses the horde clock even in solo"); w.hud.close_modal()
	check(not w.player.weapons.shoot(Vector3.FORWARD),"safe perimeter blocks outward shooting exploit")
	w.player.bag.add("scrap",120); w.player.bag.add("parts",8); w.player.bag.add("field_bag",1); w.player.bag.equip_field_bag()
	check(w.exp16.trade(w.player,"bag") and w.player.bag.bag_level==2,"Mara upgrades a valid field bag using carried materials")
	check(not w.exp16.trade(w.player,"bag"),"Mara cannot charge a repeated bag upgrade")
	w.player.bag.add("scrap",120)
	check(w.exp16.trade(w.player,"medkit") and w.exp16.trade(w.player,"medkit") and not w.exp16.trade(w.player,"medkit"),"medical stock is shared and limited per preparation")
	var dump: Dictionary = JSON.parse_string(JSON.stringify(w.exp16.dump()))
	check(Exploration16.valid(dump),"special sector ownership, stock and rewards survive JSON validation")
	w.player.position = w.sector_offset(coord)+SectorGenerator.EXITS[3]; w.travel_cooldown = 0; w.step_sector(3)
	w.elapsed = 181; w.player.position = SectorGenerator.EXITS[1]; w.travel_cooldown = 0; w.step_sector(1)
	w.player.position = w.sector_offset(coord)
	check(w.exp16.kind_at(coord)=="post" and not w.exp16.trade(w.player,"medkit"),"post does not reroll or restock on 181-second revisit")
	w.player.position = w.sector_offset(coord)+SectorGenerator.EXITS[3]; w.travel_cooldown = 0; w.step_sector(3)
	coord = Vector2i(0,-1); key = SectorGenerator.key(coord)
	w.exp16.sectors[key] = {"kind":"titan","hp":20000.0,"dead":false,"reward":{},"loot_created":false,"stocks":{},"pos":[15.0,0.0]}
	w.player.position = SectorGenerator.EXITS[0]; w.travel_cooldown = 0; w.step_sector(0)
	var boss: Node3D = w.exp16.nodes[key].boss; boss.set_physics_process(false)
	check(boss.health.maximum==20000 and boss.enemy_kind==20,"optional Titan has fixed daytime 20000 HP and separate species")
	boss.exposed = 3; w.damage_point16 = boss.to_global(Vector3(0,3.4,-1)); boss.take_damage(100); w.damage_point16 = Vector3.INF
	check(is_equal_approx(boss.health.current,19850),"real chest hit while exposed receives 1.5x damage")
	boss.take_damage(100); check(is_equal_approx(boss.health.current,19750),"unlocated or ordinary damage does not get weak-point multiplier")
	boss.rig.rotation.y = PI/2; w.hit_enemy16(boss,boss.rig.to_global(Vector3(0,1.22,-.36)),100)
	check(is_equal_approx(boss.health.current,19600),"weak point follows the rotated clay chest instead of a fixed world direction")
	w.hit_enemy16(boss,boss.rig.to_global(Vector3(.5,1.22,-.36)),100)
	check(is_equal_approx(boss.health.current,19500),"an exposed arm at chest height never receives the heart multiplier")
	var old_boss_pos: Vector3 = boss.global_position; var old_player_pos: Vector3 = w.player.global_position
	boss.global_position = Vector3(500,0,500); boss.rig.rotation.y = 0; w.player.global_position = Vector3(500,0,492)
	await physics_frame; await physics_frame
	var origin: Vector3 = w.player.global_position+Vector3(0,1.15,0)
	check(w.air_aim(origin,Vector3.BACK,30).y>.1,"normal top-down aiming reaches the Titan chest height")
	w.player.bag.selected = 0; w.player.weapons.sync_hand(); w.player.weapons.cooldown = 0; w.player.weapons.ammo[0] = 3
	var random_state: int = w.world_rng.state
	var crit: bool = w.world_rng.randf()<.1+Catalog16.bonus(w.player,"shot_aim"); w.world_rng.state = random_state
	var expected: float = float(w.player.weapons.spec().values.damage)*w.player.weapons.damage_multiplier*(1.5 if crit else 1.0)*1.5
	var before_shot: float = boss.health.current
	check(w.player.weapons.shoot(Vector3.BACK) and is_equal_approx(before_shot-boss.health.current,expected),"a real pistol ray hits the exposed chest and applies exactly 1.5x weak-point damage")
	boss.global_position = old_boss_pos; w.player.global_position = old_player_pos
	boss.health.current = 10000; w.exp16.remember()
	w.player.position = w.sector_offset(coord)+SectorGenerator.EXITS[2]; w.travel_cooldown = 0; w.step_sector(2)
	w.elapsed = 400; w.player.position = SectorGenerator.EXITS[0]; w.travel_cooldown = 0; w.step_sector(0)
	boss = w.exp16.nodes[key].boss; boss.set_physics_process(false)
	check(is_equal_approx(boss.health.current,10000),"Titan HP survives sector cache expiry")
	w.shot_owner = 1; boss.take_damage(100000); w.shot_owner = 0; w.exp16.remember()
	check(str(w.player.get_meta("titan_victory16","")).length()==64,"actual contributing survivor earns Titan trophy")
	check(w.exp16.sectors[key].reward.scrap>=800 and w.exp16.sectors[key].reward.parts>=30 and not w.exp16.sectors[key].reward.has("decoy16"),"Titan drops increased resources and never a horde diversion")
	check(w.exp16.sectors[key].dead and w.exp16.sectors[key].reward.scrap>=250,"defeat records once and creates one shared rare reward")
	var reward: Dictionary = w.exp16.sectors[key].reward.duplicate(); w.exp16.defeated(boss)
	check(w.exp16.sectors[key].reward==reward,"repeated defeat does not reroll or duplicate Titan loot")
	var reward_loot: Node3D = w.exp16.nodes[key].loot
	reward_loot.set_process(false); w.player.global_position = reward_loot.global_position
	var attempts := 0
	while not reward_loot.contents.is_empty() and attempts<200:
		w.transfer_source(w.player,reward_loot); attempts += 1
		if w.player.bag.free_slots()==0:
			for i in range(w.player.bag.slots.size()): w.player.bag.slots[i] = {"id":"","qty":0}
	check(reward_loot.contents.is_empty() and w.exp16.sectors[key].reward.is_empty(),"the final item updates persistent Titan loot immediately before its node disappears")
	reward_loot.queue_free(); await process_frame
	w.player.position = w.sector_offset(coord)+SectorGenerator.EXITS[2]; w.travel_cooldown = 0; w.step_sector(2)
	w.elapsed = 800; w.player.position = SectorGenerator.EXITS[0]; w.travel_cooldown = 0; w.step_sector(0)
	check(not w.exp16.nodes[key].has("loot") and w.exp16.sectors[key].reward.is_empty(),"fully claimed Titan loot never respawns after cache expiry and sector reload")
	w.queue_free(); await create_timer(.4).timeout
	create_world("rescue")
	check(w.game_mode=="rescue" and not w.checkpoint_enabled,"rescue mode uses separate session without overwriting campaign")
	w.player.region_coord = Rescue16.SIGNAL; w.player.position = w.sector_offset(Rescue16.SIGNAL)
	check(w.rescue16.interact(w.player) and not w.rescue16.interact(w.player),"signal component can be claimed once")
	w.player.region_coord = Rescue16.STATION; w.player.position = w.sector_offset(Rescue16.STATION)
	check(w.rescue16.interact(w.player) and w.waves.running and w.waves.wave==1,"station activation starts a formal first rescue horde")
	w.rescue16.left = 0; w.waves.to_spawn = 0; w.waves.complete()
	check(w.upgrades.pending_for(w.player)==1 and w.waves.wave==1,"mission objective grants only a completed formal horde reward")
	w.upgrades.defer_for(w.player,w.upgrades.current(w.player).id); w.rescue16.tick(.1)
	check(w.waves.wave==2 and w.waves.running,"second defense starts after first independent choice is deferred")
	w.rescue16.left = 0; w.waves.to_spawn = 0; w.waves.complete()
	check(w.rescue16.phase=="return","two defense hordes unlock return objective")
	while w.upgrades.pending_for(w.player)>0: w.upgrades.choose(0)
	w.player.region_coord = Vector2i.ZERO; w.player.position = Vector3.ZERO
	check(w.rescue16.interact(w.player) and w.waves.wave==3,"extraction starts the third formal horde")
	w.rescue16.left = 0; w.waves.to_spawn = 0; w.waves.complete()
	check(w.won and w.rescue16.phase=="complete","victory requires signal, station and extraction in order")
	w.queue_free(); await create_timer(.4).timeout
	print("RELEASE16 CONTENT RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
