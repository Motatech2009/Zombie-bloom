extends SceneTree
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
	else: print("PASS: "+message)
func enemy(kind: int,pos: Vector3) -> Node3D:
	var value: Node3D = w.make_enemy(kind,pos,false,-1); value.set_physics_process(false); return value
func build(piece: int,pos: Vector3) -> Node3D:
	w.player.position = pos+Vector3(3,0,0)
	var result: Node3D = w.builder.commit_channel({"piece":piece,"pos":pos,"angle":0})
	return result
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	Director15.selected_mutators = []; Director15.selected_class = "engineer"
	w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false); w.resources.scrap = 10000; w.stock = {"wood":10000,"parts":10000}
	await physics_frame; await process_frame
	check(w.player.specialization=="engineer","new player receives selected class")
	check(w.build_quota()==7,"engineer grants one extra construction this preparation")
	check(Arsenal.WEAPONS[0].values.interval==.22,"starter pistol fires faster")
	var a = enemy(0,Vector3(25,0,25)); var maximum: float = a.health.maximum; a.health.current = maximum*.5
	w.v15.day.clock = 900; w.v15.day.blood = false; w.v15.day.apply_enemy(a)
	check(is_equal_approx(a.health.maximum,maximum*1.3) and is_equal_approx(a.health.current/a.health.maximum,.5),"night health bonus preserves health fraction")
	w.v15.day.blood = true; w.v15.day.apply_enemy(a)
	check(is_equal_approx(a.health.maximum,maximum*1.5),"red night replaces rather than stacks normal night HP")
	var damage: float = a.spec.values.damage; w.v15.day.apply_enemy(a)
	check(is_equal_approx(a.spec.values.damage,damage),"repeated night updates never stack damage")
	w.v15.day.clock = 1800; w.v15.day.blood = false; w.v15.day.apply_enemy(a)
	check(is_equal_approx(a.health.maximum,maximum),"dawn removes night maximum health bonus")
	w.v15.day.clock = 900; w.v15.day.blood = true; w.player.health.setup(100); w.player.invulnerable = 0
	w.hostile_blast(w.player.global_position,2,10)
	check(is_equal_approx(w.player.health.current,87),"red night also scales hostile area damage by thirty percent")
	w.v15.day.clock = 1800; w.v15.day.blood = false
	w.waves.wave = 5; check(w.upgrades.cap()==2,"waves 1-5 cap each ability at two")
	w.waves.wave = 6; check(w.upgrades.cap()==7,"waves 6-10 cap each ability at seven")
	w.waves.wave = 11; check(w.upgrades.cap()==12,"later waves cap abilities at twelve")
	w.upgrades.levels = {"gather":12,"engineering":12,"efficiency":12,"cargo":12,"damage":12,"health":12}; w.upgrades.apply_actor(w.player)
	check(is_equal_approx(w.player.weapons.damage_multiplier,1.48),"damage curve is bounded and linear")
	check(w.player.bag.stack_limit("light")==120 and w.player.bag.stack_limit("pistol")==1,"cargo increases ammo stacks but never weapon stacks")
	w.v15.apply_class(w.player,"scout"); check(w.player.bag.slots.size()==20 and ItemBag.valid(w.player.bag.dump()),"scout inventory persists twenty valid slots")
	w.v15.apply_class(w.player,"shooter",true); check(w.player.weapons.tuning[0]>=1 and w.player.weapons.reload_multiplier<1,"shooter starts reinforced and reloads faster")
	w.player.position = Vector3(0,0,8); var scrap: int = w.resources.scrap
	check(w.channel15.start(w.player,"build",null,{"pos":Vector3(0,0,12),"piece":0,"angle":0}),"build starts a timed job")
	check(w.resources.scrap==scrap,"starting construction never charges resources")
	w.player.last_damage += 1; w.channel15.tick(.1)
	check(w.channel15.jobs.is_empty() and w.resources.scrap==scrap,"damage cancels without spending")
	w.channel15.start(w.player,"build",null,{"pos":Vector3(0,0,12),"piece":0,"angle":0}); w.player.position += Vector3(1,0,0); w.channel15.tick(.1)
	check(w.channel15.jobs.is_empty() and w.resources.scrap==scrap,"moving cancels without spending")
	w.player.position = Vector3(0,0,8); w.channel15.start(w.player,"build",null,{"pos":Vector3(0,0,12),"piece":0,"angle":0}); w.channel15.tick(5)
	check(w.resources.scrap==scrap-20 and w.built_this_round==1,"completed valid construction pays once and counts once")
	w.channel15.tick(5); check(w.resources.scrap==scrap-20,"completed job cannot charge twice")
	w.built_this_round = 0
	var t1 = build(1,Vector3(20,0,15)); await physics_frame
	var t2 = build(1,Vector3(23,0,15)); await physics_frame
	check(t1!=null and t2!=null,"adjacent fusion fixtures build")
	w.player.position = t1.position+Vector3(0,0,2); var count: int = w.built_this_round
	check(w.v15.fuse(w.player) and w.built_this_round==count-1,"fusion frees a preparation unit without refunding materials")
	check(t1.get_meta("fused",false) and not w.v15.fuse(w.player),"double tower cannot be fused repeatedly")
	var shield = enemy(18,Vector3(20,0,0)); shield.rig.rotation.y = 0; var hp: float = shield.health.current
	w.damage_origin15 = shield.global_position+Vector3(0,0,-4); shield.take_damage(10)
	check(is_equal_approx(hp-shield.health.current,2),"shield blocks eighty percent of frontal bullets")
	hp = shield.health.current; w.explosive15 = true; shield.take_damage(10); w.explosive15 = false
	check(is_equal_approx(hp-shield.health.current,10),"explosives bypass frontal shield")
	var boss_ids: Array = []
	for i in range(1,8): boss_ids.append(SectorGenerator.boss_spec(i).id)
	check(boss_ids.has("potter") and boss_ids.has("hive") and boss_ids.size()==7,"seven bosses have distinct behavior IDs")
	check(InfectedRoster.extra_spec(17).id=="parasite" and InfectedRoster.extra_spec(19).id=="bridge","new infected are registered")
	var wall = w.v15.temporary_wall(Vector3(30,0,10))
	check(wall!=null and wall.collision_layer==8,"Oleiro creates physical cover blocking turret rays")
	w.v15.tick(9); check(wall.is_queued_for_deletion(),"temporary wall expires")
	var saved: Dictionary = w.snapshot()
	check(w.valid_snapshot(saved),"new progression and world state pass save validation")
	var before: float = w.v15.day.clock; w.v15.day.clock = 25; w.apply_snapshot(saved)
	check(is_equal_approx(w.v15.day.clock,before),"world cycle survives checkpoint restore")
	var state: Dictionary = w.net_state(1,true)
	check(state.has("visuals15") and state.systems15.has("day") and state.profile.has("class"),"network snapshot carries world, events and class")
	w.v15.mutators = ["darkness","double_hordes"]; check(w.v15.score_multiplier()==3,"mutators multiply points only")
	var ledger := ProgressLedger.new(); ledger.observe("challenge",{"kills":2,"points":6})
	check(ledger.totals.kills==2 and ledger.totals.points==6,"real kills remain separate from bonus challenge score")
	w.queue_free(); await process_frame; await process_frame
	print("RELEASE15 RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
