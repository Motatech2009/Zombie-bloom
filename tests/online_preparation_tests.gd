extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
	else: print("PASS: "+message)
func run() -> void:
	GameSettings.volume = 0
	var campaign = load("res://scripts/campaign/campaign_world.gd")
	campaign.resume_requested = false
	var w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false
	root.add_child(w); current_scene = w; w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	check(w.horde_left==600,"new game prepares first wave for 600s")
	for mode in ["campaign","endless"]:
		w.game_mode = mode
		for wave in range(1,9):
			w.waves.wave = wave; w.waves.running = true; w.waves.complete()
			var expected: int = [600,480,360,300,180,180,180,180][wave-1]
			check(w.horde_left==expected,"%s victory %d prepares following wave" % [mode,wave])
			w.horde_left -= 17
			var saved: Dictionary = w.snapshot()
			check(w.valid_snapshot(saved),"new checkpoint validates")
			w.apply_snapshot(saved)
			check(w.horde_left==expected-17,"restore preserves remaining new-policy time")
			check(w.hud.clock_text()=="%02d:%02d" % [(expected-17)/60,(expected-17)%60],"HUD matches remaining clock")
			saved.erase("preparation_policy"); saved.horde_left = 599
			w.apply_snapshot(saved)
			check(w.horde_left==mini(599,expected),"legacy fixed timer clamps to upcoming wave budget")
	w.waves.wave = 0
	w.player.position = Vector3(0,0,12)
	var loot = w.spawn_loot(w.player.position,{"scrap":5})
	check(w.collect_ground(w.player,loot),"world scrap collected")
	check(w.records.totals.host.scrap==5,"only accepted world amount counted")
	w.collect_ground(w.player,loot)
	check(w.records.totals.host.scrap==5,"retry empty source cannot duplicate collection")
	w.deposit_materials(w.player); w.withdraw(w.player,"scrap",1)
	check(w.records.totals.host.scrap==5,"deposit and withdrawal do not count as collection")
	var dropped = w.spawn_loot(w.player.position,{"scrap":4},0,"",0,true,false)
	w.collect_ground(w.player,dropped)
	check(w.records.totals.host.scrap==5,"player dropped scrap cannot be farmed")
	var enemy = w.make_enemy(0,Vector3(0,0,10),false,-1); enemy.set_physics_process(false)
	enemy.set_meta("killer_peer",1); w.enemy_defeated(enemy); w.enemy_defeated(enemy)
	check(w.records.totals.host.kills==1,"duplicate death credits one authored kill")
	var defense = w.make_enemy(0,Vector3(4,0,10),false,-1); defense.set_physics_process(false)
	w.enemy_defeated(defense)
	check(w.records.totals.team_defenses.kills==1 and w.records.totals.host.kills==1,"team defenses never falsely credit host")
	w.record_victory(10); w.record_victory(10)
	check(w.records.totals.host.hordes==9,"repeated wave event is idempotent per participant")
	var saved: Dictionary = w.snapshot(); check(w.valid_snapshot(saved),"records serialize in v6 without replacing saves")
	var before: Dictionary = w.records.dump(); w.records.credit("host","scrap",90); w.apply_snapshot(saved)
	check(w.records.dump()==before,"local statistics rewind together with loot and bags")
	w.attach_peer(222,"2".repeat(32),"Guest")
	var guest = w.avatars[222]; guest.set_physics_process(false); guest.position = Vector3(0,0,12)
	var target = w.make_enemy(0,Vector3(0,0,10),false,-1); target.set_physics_process(false); target.health.setup(10)
	guest.bag.selected = 1
	for i in range(9):
		if guest.bag.slots[i].id=="bat": guest.bag.selected = i
	guest.weapons.sync_hand(); guest.weapons.cooldown = 0; guest.weapons.swing(Vector3.FORWARD)
	check(w.records.totals.get("2".repeat(32),{}).get("kills",0)==1,"guest bat kill credits guest rather than host")
	guest.health.dead = true; w.record_victory(12)
	check(w.records.totals["2".repeat(32)].hordes==0,"downed guest does not receive survival victory")
	var uncollected = w.spawn_loot(Vector3(0,0,20),{"scrap":8},0,"",0,true,false)
	saved = w.snapshot(); w.apply_snapshot(saved)
	var restored = get_nodes_in_group("survival_loot").filter(func(p): return not p.is_queued_for_deletion() and p.contents.get("scrap",0)==8)
	check(restored.size()==1 and not restored[0].get_meta("world_origin",true),"dropped scrap provenance survives checkpoint restore")
	check(not root.get_node("Account").configured() and root.get_node("Account").token.is_empty(),"unconfigured auth fails closed without blocking offline world")
	w.queue_free(); await create_timer(.2).timeout
	print("ONLINE PREPARATION RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
