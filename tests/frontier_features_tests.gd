extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func frames(n: int = 3) -> void:
	for i in range(n): await physics_frame; await process_frame
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false
	root.add_child(w); current_scene = w; w.set_process(false); w.waves.set_physics_process(false)
	var a: Node3D = w.player; a.set_physics_process(false); a.invulnerable = 3600
	await frames()
	check(w.horde_left==600,"a new refuge provides ten minutes before its first automatic horde")
	w.waves.running = true; w.waves.wave = 1; w.waves.complete()
	check(w.horde_left==600,"winning a horde restores the full ten-minute exploration interval")
	check(w.valid_snapshot(w.snapshot()),"a ten-minute timer remains valid in the current checkpoint format")
	a.position = Vector3(0,0,12)
	var enemy: Node3D = w.make_enemy(0,Vector3(0,0,10),false,1); enemy.health.setup(1000)
	var acid: Node3D = w.projectile("acid",Vector3(0,1,8),Vector3(0,0,12),10,2,1)
	w.resources.pending = 1; w.upgrades.roll()
	var p: Vector3 = enemy.position; var t: float = acid.elapsed; var clock: float = w.horde_left
	enemy._physics_process(.5); acid._physics_process(.5); w.waves._physics_process(.5)
	check(enemy.position==p and acid.elapsed==t and w.horde_left==clock,"upgrade selection freezes infected, incoming acid and the horde countdown")
	check(w.choose_team_upgrade(0) and not w.combat_paused(),"the first valid team choice releases the synchronized combat pause")
	acid.queue_free(); await frames()
	var bat_slot := -1
	for i in range(9):
		if a.bag.slots[i].id=="bat": bat_slot = i
	check(bat_slot>=0 and a.bag.count("bat")==1,"every new survivor starts with a reachable baseball bat")
	a.bag.selected = bat_slot; a.weapons.sync_hand(); a.weapons.cooldown = 0
	var ammo: Array = a.weapons.ammo.duplicate(); var before: float = enemy.health.current
	check(a.weapons.shoot(Vector3.FORWARD) and enemy.health.current<before and a.weapons.ammo==ammo,"a bat swing deals authoritative nearby damage without consuming ammunition")
	before = enemy.health.current; a.weapons.shoot(Vector3.FORWARD)
	check(enemy.health.current==before,"holding attack cannot bypass the bat swing cooldown")
	enemy.set_physics_process(false); enemy.position = Vector3(0,0,3); a.weapons.cooldown = 0
	a.weapons.shoot(Vector3.FORWARD)
	check(enemy.health.current==before,"the baseball bat cannot hit a distant infected")
	check(a.rig.get_node("Gun").visible and a.rig.get_node("Gun").get_child_count()>0,"equipping the bat builds its visible clay weapon model")
	var music: MusicDirector
	for child in w.get_children():
		if child is MusicDirector: music = child
	music._process(.6)
	check(music!=null and music.voices.size()==10 and not music.cache.is_empty(),"an original layered soundtrack creates reusable audio streams")
	w.waves.running = true; music._process(.6)
	check(music.combat,"the soundtrack switches to its combat arrangement during a horde")
	w.waves.running = false; enemy.queue_free(); await frames()
	var link: Node = root.get_node("Coop"); link.host_session(24583); link.bind_world(w)
	check(w.attach_peer(222,"2".repeat(32),"Sul A") and w.attach_peer(333,"3".repeat(32),"Sul B"),"the independent-sector fixture has three authoritative survivors")
	for actor in w.avatars.values(): actor.set_physics_process(false); actor.invulnerable = 3600
	var b: Node3D = w.avatars[222]; var c: Node3D = w.avatars[333]
	a.position = SectorGenerator.EXITS[0]; b.position = SectorGenerator.EXITS[2]; c.position = SectorGenerator.EXITS[2]+Vector3.RIGHT
	var b_before: Vector3 = b.position
	check(w.perform_action(1,"travel",{"direction":0}),"the host can travel north without gathering friends at the exit")
	check(a.region_coord==Vector2i(0,-1) and b.region_coord==Vector2i.ZERO and b.position==b_before,"host travel leaves other survivors and their positions unchanged")
	check(w.perform_action(222,"travel",{"direction":2}) and w.perform_action(333,"travel",{"direction":2}),"two friends can independently travel south while the host is north")
	check(w.sector_coord==Vector2i(0,-1) and b.region_coord==Vector2i(0,1) and c.region_coord==b.region_coord,"simultaneously occupied north and south sectors keep distinct server contexts")
	var south_root: Node3D = w.regions.root_at(b.region_coord)
	check(south_root!=null and south_root!=w.field_root and w.regions.sessions.size()==3,"friends share one southern scene while the northern scene and core remain loaded")
	var north_scene: Dictionary = w.net_scene(1); var south_scene: Dictionary = w.net_scene(222)
	check(north_scene.coord==Vector2i(0,-1) and south_scene.coord==Vector2i(0,1),"each connection receives its own sector geometry descriptor")
	var southern: Node3D = w.regions.run_in(b.region_coord,func(): return w.make_enemy(0,Vector3.ZERO,true,-1))
	southern.set_physics_process(false); southern.choose_target()
	check(southern.target==b or southern.target==c,"southern infected target a survivor in their own quadrant")
	check(not w.net_state(1).enemies.any(func(e): return e.id==southern.net_id) and w.net_state(222).enemies.any(func(e): return e.id==southern.net_id),"enemy snapshots are filtered to the receiving player's sector")
	w.horde_left = 0; w.waves.start()
	check(w.waves.running and w.core.health.current>0,"the shared core horde can start while all survivors are exploring elsewhere")
	var base_enemy: Node3D = w.make_enemy(0,Vector3(10,0,10),false,1); base_enemy.set_physics_process(false); base_enemy.choose_target()
	check(base_enemy.target==w.core,"unattended base enemies attack the core instead of chasing players across quadrants")
	a.region_travel_left = 0; a.position = w.sector_offset(a.region_coord)+SectorGenerator.EXITS[2]
	check(w.perform_action(1,"travel",{"direction":2}),"the host can return north-to-core during the active horde")
	check(w.sector_coord==Vector2i.ZERO and b.region_coord==Vector2i(0,1) and w.regions.root_at(b.region_coord)==south_root,"returning to the core preserves the friends' live southern scene")
	check(w.peer_revision(1)!=w.peer_revision(222) and w.net_scene(222).rev==b.region_revision,"scene revisions are independent for players who travel a different number of times")
	w.waves.running = false; w.phase = "prep"
	check(w.mobile_context(a).build and not w.mobile_context(b).build,"construction is offered only to the player actually standing in the refuge")
	var checkpoint: Dictionary = w.snapshot()
	check(w.valid_snapshot(JSON.parse_string(JSON.stringify(checkpoint))),"saving from the core includes valid memory for independently occupied sectors")
	w.detach_peer(222); w.regions.tick(0)
	check(w.regions.root_at(c.region_coord)==south_root,"one guest leaving does not unload the remaining friend's sector")
	w.detach_peer(333); w.regions.tick(0)
	check(w.regions.root_at(Vector2i(0,1))==null and w.sector_memory.has("0:1"),"the last departure unloads southern geometry while preserving its three-minute loot memory")
	a.region_travel_left = 0; a.position = SectorGenerator.EXITS[1]
	w.perform_action(1,"travel",{"direction":1})
	w.attach_peer(444,"4".repeat(32),"Joining east")
	check(w.avatars[444].region_coord==Vector2i(1,0) and w.net_scene(444).coord==Vector2i(1,0),"a new guest joins the host's current quadrant even when the host is away from the core")
	link.close_session(); w.queue_free(); await create_timer(.25).timeout
	print("FRONTIER FEATURES RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
