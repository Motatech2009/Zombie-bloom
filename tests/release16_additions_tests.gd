extends SceneTree
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func building(index: int,pos: Vector3) -> Node3D:
	var s := StaticBody3D.new(); s.set_script(load("res://scripts/fortress/fortress_structure.gd")); s.world = w; s.piece_index = index; s.position = pos; w.base_root.add_child(s); return s
func run() -> void:
	GameSettings.volume = 0; GameSettings.music_volume = 0
	var rng := RandomNumberGenerator.new(); rng.seed = 76701
	var drops := 0; var other := 0
	for i in range(10000):
		if LootTables.boss(10,rng,true).has("decoy16"): drops += 1
		if LootTables.boss(10,rng,false).has("decoy16"): other += 1
	check(drops>2800 and drops<3200,"horde boss drop distribution is approximately 30 percent: "+str(drops))
	check(other==0,"non-horde bosses never receive the diversion item")
	var bag := ItemBag.new(); bag.add("decoy16",2)
	check(bag.count("decoy16")==2 and ItemBag.stack("decoy16")==1 and ItemBag.valid(bag.dump()),"diversion occupies one slot per item and serializes")
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"; load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	var item_loot: Node3D = w.spawn_loot(Vector3(40,0,40),{"decoy16":1})
	check(item_loot!=null and is_instance_valid(item_loot.model),"diversion drop has its own native model")
	item_loot.queue_free()
	w.horde_left = 120; w.player.bag.add("decoy16",2)
	check(w.perform_action(1,"decoy16",{}),"owner consumes diversion through the authoritative action")
	check(w.player.bag.count("decoy16")==1 and w.truce16.left==600 and w.truce16.pending,"activation consumes exactly one and grants 600 seconds")
	check(not w.perform_action(1,"decoy16",{}) and w.player.bag.count("decoy16")==1,"repeated activation never spends a second item")
	w.waves._physics_process(599)
	check(w.horde_left==120 and is_equal_approx(w.truce16.left,1),"599 seconds of diversion do not consume original preparation")
	w.waves._physics_process(2)
	check(is_equal_approx(w.horde_left,119) and w.truce16.left==0,"expiration preserves the original countdown including fractional frame time")
	check(not w.perform_action(1,"decoy16",{}),"expired diversion cannot be chained during the same preparation")
	var state: Dictionary = JSON.parse_string(JSON.stringify(w.snapshot()))
	check(w.valid_snapshot(state),"pending stronger horde survives valid campaign JSON")
	w.truce16.restore({}); w.apply_snapshot(state)
	check(w.truce16.pending and w.truce16.used_after==0 and w.horde_left==119,"restoration keeps debt and remaining preparation")
	var bad: Dictionary = state.duplicate(true); bad.truce16.left = -1
	check(not w.valid_snapshot(bad),"negative diversion timer is rejected before applying save")
	bad = state.duplicate(true); bad.truce16.left = 601
	check(not w.valid_snapshot(bad),"excess diversion time is rejected")
	var old: Dictionary = state.duplicate(true); old.erase("truce16")
	check(w.valid_snapshot(old),"previous version saves remain compatible without diversion fields")
	w.horde_left = 0
	check(w.waves.start() and w.waves.to_spawn==22,"next horde has ceil 18 times 1.2 enemies")
	w.waves.rescale()
	check(w.waves.to_spawn==22,"population recomputation preserves the one-horde penalty")
	check(w.waves.enemy_type(0)==8 and w.waves.enemy_type(1)!=8,"extra population preserves one formal boss")
	w.waves.to_spawn = 0; w.waves.complete()
	w.upgrades.defer_for(w.player,w.upgrades.current(w.player).id)
	w.horde_left = 0; check(w.waves.start() and w.waves.to_spawn==CampaignData.wave_count(2),"following horde returns to normal population")
	w.waves.running = false; w.phase = "prep"; w.horde_left = 120
	w.game_mode = "rescue"
	check(not w.perform_action(1,"decoy16",{}),"diversion does not bypass scripted rescue objectives")
	w.game_mode = "endless"
	var index := FortressData.pieces().size()-1
	check(FortressData.pieces()[index].id=="raised_turret" and FortressData.turret("raised_turret"),"raised turret appends without renumbering existing structures")
	var tower := building(index,Vector3(35,0,15)); var regular := building(1,Vector3(35,0,15)); regular.collision_layer = 0
	tower.set_physics_process(false); regular.set_physics_process(false)
	var barrier := building(0,Vector3(35,0,10.5)); barrier.set_physics_process(false)
	var enemy: Node3D = w.make_enemy(0,Vector3(35,0,5),false,-1); enemy.set_physics_process(false); enemy.health.setup(1000)
	await physics_frame; await physics_frame
	var hp: float = enemy.health.current
	regular.fire_turret(); check(enemy.health.current==hp,"regular low turret is blocked by the barricade")
	tower.fire_turret(); check(enemy.health.current<hp,"real elevated firing ray clears the low barricade")
	barrier.queue_free(); await physics_frame; await physics_frame
	var wall := building(7,Vector3(35,0,10.5)); wall.set_physics_process(false)
	await physics_frame; await physics_frame
	hp = enemy.health.current; tower.fire_turret()
	check(enemy.health.current==hp,"heavy wall still physically blocks the elevated turret")
	tower.tier = 3; tower.refresh_tier()
	check(is_equal_approx(tower.spec.values.range,19) and is_equal_approx(tower.head.position.y,3.6),"upgraded raised model and actual firing height agree")
	w.player.position = Vector3(35,0,18)
	var overlay := DefenseRange16.new(); overlay.world = w; w.add_child(overlay); overlay._process(.3)
	check(overlay.visible and overlay.drawing.mesh!=null and overlay.last_count>0,"nearby structure produces bounded ground coverage")
	MobilePlatform.force_touch = true; overlay._process(.3)
	check(overlay.last_count==96,"mobile range preview uses 32 bounded sectors")
	MobilePlatform.force_touch = false
	var outfit := {"head":"COS-TITAN-01"}
	for cls in ["engineer","scout","shooter"]: check(Cosmetics16.valid(outfit,cls),"Titan trophy can be worn by "+cls)
	var meta: Node = root.get_node("Meta16")
	var prior: Dictionary = meta.titan_earned.duplicate(); var prior_equipped: Dictionary = meta.trophy_equipped.duplicate()
	meta.titan_earned = {}; meta.trophy_equipped = {}
	check(not meta.has_cosmetic("COS-TITAN-01"),"unearned trophy stays locked")
	meta.titan_victory(w.account_run_id,"a".repeat(64)); var queued: int = meta.titan_pending.size()
	meta.titan_victory(w.account_run_id,"a".repeat(64))
	check(meta.has_cosmetic("COS-TITAN-01") and meta.titan_earned.size()==1 and meta.titan_pending.size()==queued,"trophy grants once without spending coins")
	await meta.equip("engineer","head","COS-TITAN-01")
	check(meta.outfit("engineer").head=="COS-TITAN-01","earned trophy equips locally while offline")
	meta.titan_earned = prior; meta.trophy_equipped = prior_equipped; meta.persist()
	w.queue_free(); await create_timer(.4).timeout
	print("RELEASE16 ADDITIONS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
