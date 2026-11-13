extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)

func run() -> void:
	var link := root.get_node("Coop")
	check(link.host_session(24577)==OK,"ENet server opens a real UDP session")
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world)
	current_scene = world
	world.waves.set_physics_process(false)
	var deadline := Time.get_ticks_msec()+16000
	while world.party_count()<4 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	check(world.party_count()==4 and world.team_multiplier()==8,"three remote clients join; four players yield x8 population")
	await create_timer(3.5).timeout
	for id in world.avatars:
		if id!=1: check(world.avatars[id].position.distance_to(world.player.position)>4,"server simulates remote movement for peer %d" % id)
	for id in world.avatars:
		if id!=1: check(world.avatars[id].roll_cooldown>0 and world.avatars[id].roll_cooldown<5,"server owns the remote roll cooldown for peer %d" % id)
	for id in world.avatars:
		if id!=1: world.spawn_loot(world.avatars[id].position,{"medkit":1})
	world.horde_left = 0
	world.waves._physics_process(.01)
	check(world.waves.to_spawn==CampaignData.wave_count(1)*8,"server scales the pending horde by the exact cooperative multiplier")
	for id in world.avatars:
		if id==1: continue
		var enemy: Node3D = world.make_enemy(0,world.avatars[id].position+Vector3(0,0,-3),false,id)
		enemy.set_physics_process(false)
	await create_timer(5).timeout
	check(world.kills>0,"client shooting RPC input causes authoritative enemy deaths")
	check(world.core.health.current==600 and world.built_this_round==0,"unsupported damage/build commands cannot mutate protected host state")
	var private_bags := true
	for id in world.avatars:
		if id!=1:
			var profile: Dictionary = world.net_state(id).profile
			private_bags = private_bags and ItemBag.valid(profile.bag)
	check(private_bags,"each connected peer receives a valid private bag profile")
	# Exercise reliable inventory actions and a scene revision across all real peers.
	for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
	world.waves.running = false
	world.phase = "prep"
	world.resources.pending = 0; world.upgrades.offers.clear(); world.hud.close_modal()
	world.horde_left = 150
	world.stock.wood = 100
	for actor in world.avatars.values():
		actor.position = Vector3(1,0,2)
		if actor.peer_id!=1:
			actor.bag.add("tesla",1)
			actor.weapons.ammo[8] = 2
	var cryo: Node3D = world.make_enemy(13,Vector3(12,0,12),false,1)
	cryo.set_physics_process(false); cryo.windup = 5; cryo.cast_point = cryo.position
	var wire := StaticBody3D.new(); wire.set_script(world.structure_script())
	wire.world = world; wire.piece_index = 6; wire.tier = 2; wire.position = Vector3(20,0,20)
	world.base_root.add_child(wire)
	world.airdrops.left = .01; world.airdrops.tick(.02)
	world.airdrops.state.coord = [0,-1]
	await create_timer(5).timeout
	for id in world.avatars:
		if id!=1: check(world.avatars[id].bag.count("wood")==0,"client stores its withdrawn stack back into the authoritative depot")
	for id in world.avatars:
		if id!=1: check(world.avatars[id].weapons.ammo[8]<2,"remote Tesla fire consumes authoritative energy ammunition")
	cryo.queue_free()
	check(link.max_snapshot_packed>0 and link.max_snapshot_packed<link.max_snapshot_raw,"compressed authoritative snapshots reduce transport size without losing state")
	check(world.stock.wood==100,"three concurrent withdraw/store transactions conserve the shared depot")
	world.travel_cooldown = 0
	for actor in world.avatars.values(): actor.position = SectorGenerator.EXITS[0]
	check(world.step_sector(0),"the complete party crosses the northern exit")
	check(world.airdrops.at_sector() and world.descriptor.risk==4 and world.airdrops.crate!=null,"server loads the guarded airdrop into the same procedural party sector")
	var house: Node3D = world.raid_house(0)
	check(house!=null and house.guard_total==int(house.data.guards)*8,"house scene and guard objective use the same four-player scaling")
	house.activated = true; house.dead.append(0); house.contents.scrap -= 7; house.set_physics_process(false)
	check(world.net_state(1).houses[0].dead==[0],"host includes authoritative house progress in snapshots")
	check(world.descriptor.count==world.descriptor.base_count*8,"procedural field population also uses the exact x8 multiplier")
	await create_timer(2).timeout
	world.travel_cooldown = 0
	for actor in world.avatars.values(): actor.position = world.sector_offset(world.sector_coord)+SectorGenerator.EXITS[2]
	check(world.step_sector(2) and world.sector_coord==Vector2i.ZERO,"the party returns to the persistent core sector")
	await create_timer(2).timeout
	deadline = Time.get_ticks_msec()+10000
	while world.party_count()>1 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	check(world.party_count()==1 and world.team_multiplier()==1,"disconnect removes remote avatars and updates future scaling")
	link.close_session()
	world.queue_free()
	await create_timer(.35).timeout
	print("COOP HOST RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
