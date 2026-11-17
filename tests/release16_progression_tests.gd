extends SceneTree
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func pick(actor: Node3D,index: int = 0) -> bool:
	var choice: Dictionary = w.upgrades.current(actor)
	return w.perform_action(actor.peer_id,"choice",{"index":index,"choice_id":choice.get("id","")})
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false
	root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	for peer in range(2,5):
		check(w.attach_peer(peer,str(peer).repeat(32),"Same nickname"),"attach stable identity %d" % peer)
		w.avatars[peer].set_physics_process(false)
	check(not w.attach_peer(5,"2".repeat(32),"Other nickname"),"duplicate player identity cannot take another connection")
	var old_xp: int = w.resources.xp
	w.resources.add_loot(200,7)
	check(w.resources.xp!=old_xp and w.resources.level>1 and w.resources.pending==0,"XP and historical level remain but XP grants no choices")
	w.waves.wave = 1; w.waves.running = true; w.phase = "combat"
	w.waves.complete()
	check(w.combat_paused(),"successful horde pauses while connected players choose")
	var first_ids: Dictionary = {}
	for peer in w.avatars:
		var actor: Node3D = w.avatars[peer]
		var own: Dictionary = w.upgrades.private_state(actor)
		check(own.pending==1 and own.choice.offers.size()==3,"player %d receives exactly one three-card choice" % peer)
		check(not first_ids.has(own.choice.id),"choice is unique to player %d" % peer)
		first_ids[own.choice.id] = true
		var packet: Dictionary = w.net_state(peer)
		check(packet.progression16.identity==actor.profile_id and not packet.progression16.has("players"),"snapshot contains only recipient character progression %d" % peer)
	var a: Node3D = w.avatars[2]; var b: Node3D = w.avatars[3]
	var b_before: Dictionary = w.upgrades.private_state(b).duplicate(true)
	var offered: Dictionary = w.upgrades.current(a).duplicate(true)
	check(not w.perform_action(2,"choice",{"index":0}),"network-style choice without reward ID is rejected")
	check(not w.perform_action(2,"choice",{"index":0,"choice_id":w.upgrades.current(b).id}),"another player's reward ID is rejected")
	check(pick(a),"A commits its offered upgrade")
	check(w.resources.pending==1,"remote choice keeps the host pending count intact")
	check(w.upgrades.private_state(b)==b_before,"A never consumes or modifies B's choices and levels")
	check(not w.perform_action(2,"choice",{"index":0,"choice_id":offered.id}),"duplicate click/replay applies no second upgrade")
	check(w.upgrades.level_for(a,offered.offers[0].id)==1,"chosen level changes exactly once on its owner")
	var b_choice: String = w.upgrades.current(b).id
	w.detach_peer(3)
	await process_frame
	check(w.attach_peer(30,"3".repeat(32),"Renamed"),"same identity reconnects under another peer and nickname")
	b = w.avatars[30]; b.set_physics_process(false)
	check(w.upgrades.current(b).id==b_choice and w.upgrades.pending_for(b)==1,"reconnection restores the original pending reward")
	check(pick(b,1),"B may choose a different offered card independently")
	w.upgrades.award_horde(1)
	check(w.upgrades.pending_for(a)==0 and w.upgrades.pending_for(b)==0,"replayed horde never recreates spent rewards")
	for peer in [1,4]:
		var actor: Node3D = w.avatars[peer]
		check(w.perform_action(peer,"defer_choice",{"choice_id":w.upgrades.current(actor).id}),"player %d can defer selection" % peer)
	check(not w.combat_paused(),"all selected/deferred releases the shared combat pause")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.snapshot()))
	check(w.valid_snapshot(saved),"individual levels, pending cards and deferred state survive JSON validation")
	w.apply_snapshot(saved)
	check(w.upgrades.pending_for(w.player)==1 and w.upgrades.state(w.player).deferred,"restore keeps the host's deferred choice")
	check(w.upgrades.level_for(w.avatars[2],offered.offers[0].id)==1,"restore preserves A's own character upgrade")
	check(not w.combat_paused(),"loading deferred rewards does not introduce a blocking pause")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.progression16.players.host.levels.damage = 13
	check(not w.valid_snapshot(invalid),"save validator rejects over-cap individual levels")
	invalid = saved.duplicate(true); invalid.progression16.players.host.queue.append(invalid.progression16.players.host.queue[0].duplicate(true))
	check(not w.valid_snapshot(invalid),"save validator rejects duplicated pending reward IDs")
	invalid = saved.duplicate(true); invalid.progression16.players.host.through = -1
	check(not w.valid_snapshot(invalid),"save validator rejects invalid horde checkpoints")
	# Old format-six campaign: migrate shared bonuses, never invent old rewards.
	var legacy: Dictionary = saved.duplicate(true); legacy.erase("progression16")
	legacy.upgrades = {"damage":2,"cargo":2,"engineering":1}
	check(w.valid_snapshot(legacy),"unmodified format-six saves remain accepted")
	w.apply_snapshot(legacy)
	for actor in w.avatars.values():
		check(w.upgrades.level_for(actor,"damage")==2 and w.upgrades.pending_for(actor)==0,"legacy bonus migrates without retroactive rewards for "+actor.profile_id)
	w.upgrades.award_horde(1)
	check(not w.combat_paused(),"legacy completed waves cannot be claimed again")
	# Newcomers do not inherit the host's individual character improvements.
	w.detach_peer(30); await process_frame
	check(w.attach_peer(40,"4a".repeat(16),"Newcomer"),"new identity may join after a disconnect")
	var newcomer: Node3D = w.avatars[40]; newcomer.set_physics_process(false)
	check(w.upgrades.level_for(newcomer,"damage")==0 and w.upgrades.pending_for(newcomer)==0,"late joiner gets neither host upgrades nor previous wave choices")
	# Owner-only modifiers used by timed work and gathering/ammunition systems.
	w.upgrades.players[a.profile_id].levels = {"engineering":12,"gather":12,"efficiency":12}
	w.upgrades.apply_actor(a)
	check(w.upgrades.level_for(a,"engineering")==12 and w.upgrades.level_for(newcomer,"engineering")==0,"engineering and efficiency lookup is individual")
	w.waves.wave = 6
	check(w.upgrades.cap()==7,"middle-horde per-ability cap remains seven")
	w.waves.wave = 11
	check(w.upgrades.cap()==12,"late-horde per-ability cap remains twelve")
	# Filled catalogs consume no reward and cannot softlock.
	for actor in w.avatars.values():
		var full := {}; for id in IndividualProgression16.IDS: full[id] = 12
		if actor.peer_id==1: w.upgrades.levels = full
		else: w.upgrades.players[actor.profile_id].levels = full
	w.upgrades.award_horde(11)
	check(not w.combat_paused(),"fully capped players never open an empty blocking modal")
	w.queue_free(); await create_timer(.35).timeout; await process_frame
	print("RELEASE16 PROGRESSION RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
