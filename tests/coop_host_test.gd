extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)

func wait_ready(link: Node,world: Node3D) -> void:
	var deadline := Time.get_ticks_msec()+8000
	while world.avatars.keys().any(func(id): return id!=1 and int(link.scene_confirmed.get(id,-1))!=world.scene_revision) and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(world.avatars.keys().all(func(id): return id==1 or int(link.scene_confirmed.get(id,-1))==world.scene_revision),"every connected guest acknowledges complete scene data before the next test transition")

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
		# Keep the touch player's target alive while its first collider snapshot arrives.
		if world.avatars[id].display_name=="Amigo 3": enemy.health.setup(1000)
	var targeted_input_seen := false
	var shooting_deadline := Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<shooting_deadline:
		targeted_input_seen = targeted_input_seen or world.avatars.values().any(func(actor): return actor.net_input.has("target"))
		await create_timer(.05).timeout
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
	var guest_position := 0
	for actor in world.avatars.values():
		# Keep each capsule separate and to the right of the solid core. Stacking
		# four actors in one spot lets collision resolution put the touch guest
		# behind cover, where assisted fire correctly refuses the Tesla shot.
		actor.position = Vector3(0,0,3) if actor.peer_id==1 else Vector3(2.5,0,-2+guest_position*2)
		if actor.peer_id!=1:
			guest_position += 1
			actor.bag.add("tesla",1)
			actor.weapons.ammo[8] = 2
			if actor.display_name=="Amigo 3": actor.health.current = 50
	var cryo: Node3D = world.make_enemy(13,Vector3(12,0,12),false,1)
	cryo.set_physics_process(false); cryo.windup = 5; cryo.cast_point = cryo.position
	var target_dummy: Node3D = world.make_enemy(0,Vector3(7,0,3),false,2)
	target_dummy.set_physics_process(false); target_dummy.health.setup(10000)
	var wire := StaticBody3D.new(); wire.set_script(world.structure_script())
	wire.world = world; wire.piece_index = 6; wire.tier = 2; wire.position = Vector3(20,0,20)
	world.base_root.add_child(wire)
	world.airdrops.left = .01; world.airdrops.tick(.02)
	world.airdrops.state.coord = [0,-1]
	await create_timer(5).timeout
	var weapon_deadline := Time.get_ticks_msec()+6000
	while world.avatars.values().any(func(actor): return actor.peer_id!=1 and actor.weapons.ammo[8]>=2) and Time.get_ticks_msec()<weapon_deadline:
		await create_timer(.05).timeout
	for id in world.avatars:
		if id!=1: check(world.avatars[id].bag.count("wood")==0,"client stores its withdrawn stack back into the authoritative depot")
	for id in world.avatars:
		if id!=1: check(world.avatars[id].weapons.ammo[8]<2,"remote Tesla fire consumes authoritative energy ammunition")
	check(targeted_input_seen,"the host receives targeted mobile input alongside ordinary desktop input")
	cryo.queue_free()
	target_dummy.queue_free()
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
	var sector_seed: int = world.descriptor.seed
	world.caches[0].set_meta("contents",{"rifle_ammo":7,"parts":2})
	await wait_ready(link,world)
	await create_timer(2).timeout
	world.travel_cooldown = 0
	for actor in world.avatars.values(): actor.position = world.sector_offset(world.sector_coord)+SectorGenerator.EXITS[2]
	check(world.step_sector(2) and world.sector_coord==Vector2i.ZERO,"the party returns to the persistent core sector")
	await wait_ready(link,world)
	await create_timer(2).timeout
	world.travel_cooldown = 0
	for actor in world.avatars.values(): actor.position = SectorGenerator.EXITS[0]
	check(world.step_sector(0) and world.descriptor.seed==sector_seed,"a four-player revisit keeps the same procedural generation during its cooldown")
	check(world.caches[0].get_meta("contents")=={"rifle_ammo":7,"parts":2} and world.raid_house(0).dead==[0],"host preserves partial supplies and house progress during the shared revisit")
	await wait_ready(link,world)
	await create_timer(2).timeout
	world.travel_cooldown = 0
	for actor in world.avatars.values(): actor.position = world.sector_offset(world.sector_coord)+SectorGenerator.EXITS[2]
	check(world.step_sector(2),"the party returns safely after its preserved-sector visit")
	await wait_ready(link,world)
	await create_timer(2).timeout
	deadline = Time.get_ticks_msec()+10000
	while world.party_count()>1 and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	check(world.party_count()==1 and world.team_multiplier()==1,"disconnect removes remote avatars and updates future scaling")
	link.close_session()
	world.queue_free()
	await create_timer(.35).timeout
	print("COOP HOST RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
