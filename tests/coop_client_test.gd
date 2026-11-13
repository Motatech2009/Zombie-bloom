extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)

func run() -> void:
	var tag := "1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
	var link := root.get_node("Coop")
	link.identity = tag.pad_zeros(32)
	check(link.join_session("127.0.0.1",24577,"Amigo "+tag)==OK,"client starts a real ENet connection")
	var deadline := Time.get_ticks_msec()+16000
	while (not is_instance_valid(link.world) or link.received_snapshots<5) and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	check(link.mode=="client" and is_instance_valid(link.world) and link.received_snapshots>=5,"client receives authoritative scene and state snapshots")
	if not is_instance_valid(link.world): quit(1); return
	var world: Node3D = link.world
	var start: Vector3 = world.player.position
	link.test_input = {"move":Vector2(1,0),"aim":Vector3.FORWARD,"slot":0}
	await create_timer(2).timeout
	link.test_input.move = Vector2.ZERO
	check(world.player.rig.get_node("ArmR").rotation.x>0,"replicated armed pose keeps the right arm facing forward")
	check(world.player.position.distance_to(start)>3,"replicated client avatar follows movement accepted by the host")
	link.command("roll",{"direction":Vector3.RIGHT})
	await create_timer(.15).timeout
	check(world.player.roll_left>0 and world.player.roll_cooldown>4,"reliable roll command replicates its active animation and five-second cooldown")
	var roll_before: float = world.player.roll_cooldown
	link.command("roll",{"direction":Vector3.LEFT})
	await create_timer(.15).timeout
	check(world.player.roll_cooldown<roll_before and world.player.roll_direction==Vector3.RIGHT,"host rejects repeated roll RPCs during recharge")
	deadline = Time.get_ticks_msec()+12000
	while world.phase!="combat" and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	link.test_input.fire = true
	await create_timer(3.5).timeout
	link.test_input.fire = false
	var total: int = world.player.bag.count("light")+world.player.weapons.ammo[0]
	check(total<60,"client weapon consumes authoritative finite ammunition")
	check(world.player.bag.count("medkit")==2,"walking pickup is simulated by the server and replicated without an interaction command")
	check(world.team_multiplier()==8,"client HUD state sees four-player scaling")
	link.command("damage",{"amount":999999})
	link.command("build",{"piece":0,"angle":0.0,"pos":Vector3.ZERO})
	await create_timer(.7).timeout
	check(world.core.health.current==600,"client cannot inject core damage through an unsupported action")
	deadline = Time.get_ticks_msec()+6000
	while world.phase!="prep" and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	var stock_before: int = world.player.bag.count("wood")
	link.command("withdraw",{"id":"wood","qty":4})
	await create_timer(.5).timeout
	check(world.player.bag.count("wood")==stock_before+4,"server accepts the near-core withdrawal RPC and replicates the private bag")
	var item_slot := -1
	for i in range(18):
		if world.player.bag.slots[i].id=="wood": item_slot = i
	link.command("store",{"slot":item_slot})
	await create_timer(.5).timeout
	check(world.player.bag.count("wood")==0,"store RPC returns the selected stack to the shared depot")
	check(world.player.weapons.ammo.size()==9 and world.player.bag.count("tesla")==1,"nine-weapon private profile and a newly granted Tesla replicate")
	link.test_input.slot = 4; link.test_input.fire = true
	await create_timer(1.1).timeout
	link.test_input.fire = false
	check(world.player.weapons.hand_weapon==8 and world.player.weapons.ammo[8]<2,"new gun selection, visible model and finite ammunition replicate after remote fire")
	check(world.client_enemies.values().any(func(enemy): return enemy.enemy_kind==13) and not world.client_hazards.is_empty(),"new infected model and its blue warning replicate to clients")
	check(world.client_structures.values().any(func(piece): return piece.piece_index==6 and piece.tier==2 and piece.model.get_node("Visual").get_meta("tier")==2),"new razor-wire type and reinforced material/model replicate to the guest")
	check(world.airdrops.serial==1 and world.airdrops.coord()==Vector2i(0,-1),"supply timer and remote coordinates replicate to the guest")
	deadline = Time.get_ticks_msec()+7000
	while world.sector_coord==Vector2i.ZERO and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	check(world.airdrops.crate!=null and world.descriptor.risk==4,"client sees the real supply crate and high-risk drop sector")
	var house: Node3D = world.raid_house(0)
	check(house!=null and house.guard_total==int(house.data.guards)*8,"guest builds the same house layout and cooperative guard requirement")
	check(house.activated and house.dead==[0] and house.contents.scrap==house.data.reward.scrap-7,"guest receives house lock progress and exact remaining supplies")
	check(world.sector_coord==Vector2i(0,-1) and world.field_root!=null,"reliable scene revision loads the same generated northern sector")
	deadline = Time.get_ticks_msec()+7000
	while world.sector_coord!=Vector2i.ZERO and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	check(world.sector_coord==Vector2i.ZERO and world.core.health.current==600,"return scene revision preserves the shared core state")
	print("COOP CLIENT RESULT: %d checks, %d failures" % [checks,failures])
	link.close_session()
	world.queue_free()
	await create_timer(.35).timeout
	quit(1 if failures else 0)
