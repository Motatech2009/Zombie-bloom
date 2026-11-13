extends SceneTree
var checks := 0
var failures := 0
var world: Node3D

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func frames(count: int = 2) -> void:
	for i in range(count): await physics_frame; await process_frame
func hostile(kind: int,pos: Vector3) -> Node3D:
	var actor: Node3D = world.make_enemy(kind,pos,false,1)
	actor.set_physics_process(false)
	return actor
func clear_hostiles() -> void:
	for actor in get_nodes_in_group("enemies"):
		actor.get_parent().remove_child(actor)
		actor.queue_free()
func run() -> void:
	var bag := ItemBag.new()
	check(bag.free_slots()==18 and bag.hand()=="","bag starts with eighteen empty physical slots")
	check(bag.add("wood",43)==43 and bag.slots[0].qty==20 and bag.slots[2].qty==3,"materials split across capped stacks")
	check(not bag.remove("wood",44) and bag.count("wood")==43,"failed removal does not partially spend inventory")
	check(bag.remove("wood",21) and bag.count("wood")==22 and bag.free_slots()==16,"removal clears spent stacks")
	check(bag.add("pistol",2)==1 and bag.add("pistol",1)==0,"a bag carries at most one gun of each type")
	check(bag.swap(0,17) and not bag.swap(-1,18),"belt and backpack slots can be exchanged with bounds checks")
	var packed: Dictionary = bag.dump()
	check(ItemBag.valid(JSON.parse_string(JSON.stringify(packed))),"bag survives a JSON round trip")
	packed.slots[0].qty = 999
	check(not bag.restore(packed) and bag.count("wood")==22,"invalid restore is atomic")
	bag = ItemBag.new()
	check(bag.add("scrap",10000)==720 and bag.free_slots()==0,"full bag accepts only eighteen capped stacks")
	check(bag.add("wood",1)==0,"a full bag rejects another item without deleting it")
	var bad := bag.dump()
	bad.selected = 9
	check(not ItemBag.valid(bad),"only nine hotbar slots are selectable")
	bad = bag.dump(); bad.slots[0].qty = 1.5
	check(not ItemBag.valid(bad),"fractional item quantities are invalid")
	bad = bag.dump(); bad.slots[0].id = "unknown"
	check(not ItemBag.valid(bad),"unknown item IDs are invalid")
	load("res://scripts/campaign/campaign_world.gd").next_mode = "campaign"
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	world = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	await frames()
	world.waves.set_physics_process(false)
	world.set_process(false)
	var actor: Node3D = world.player
	actor.set_physics_process(false)
	check(world.resources.scrap==85 and world.stock.wood==6,"initial depot is scarcer than the previous arena")
	check(actor.bag.count("pistol")==1 and actor.bag.count("light")==48,"starter weapon and finite reserve occupy real slots")
	check(actor.weapons.owned.size()==5 and actor.weapons.ammo.size()==5,"survival weapon initializes its full inherited arsenal")
	actor.position = Vector3(20,0,20)
	var pile: Node3D = world.spawn_loot(actor.position,{"wood":9},0)
	var bank_before: int = world.stock.wood
	world.tick_gather(actor,1)
	check(actor.bag.count("wood")==0 and actor.gather_progress==1,"holding gather briefly does not grant resources instantly")
	world.tick_gather(actor,1.9)
	check(actor.bag.count("wood")==4 and pile.contents.wood==5,"one full gather transfers only four units")
	check(world.stock.wood==bank_before,"field loot remains in the bag instead of paying construction immediately")
	world.tick_gather(actor,.5)
	actor.position.x += 1
	world.tick_gather(actor,.5)
	check(actor.gather_target==null and pile.contents.wood==5,"moving cancels gathering without taking the next batch")
	actor.position = pile.position
	world.tick_gather(actor,.4)
	actor.invulnerable = 0
	actor.take_damage(1)
	check(actor.gather_target==null,"damage interrupts gathering")
	var guard := hostile(0,actor.position+Vector3(0,0,3))
	world.tick_gather(actor,3)
	check(actor.gather_target==null and pile.contents.wood==5,"nearby hostiles block safe gathering")
	guard.queue_free(); await frames()
	actor.bag = ItemBag.new(); actor.bag.add("scrap",720)
	check(not world.transfer_source(actor,pile) and pile.contents.wood==5,"a full bag leaves uncollected resource quantities on the ground")
	actor.bag = ItemBag.new(); world.starter_bag(actor.bag)
	world.transfer_source(actor,pile)
	world.transfer_source(actor,pile)
	check(actor.bag.count("wood")==5 and pile.contents.is_empty(),"repeated manual collection conserves the remaining pile")
	check(not world.deposit_materials(actor),"deposit is rejected when far from the core")
	actor.position = world.core.position+Vector3(0,0,2.4)
	world.tick_gather(actor,1)
	check(actor.bag.count("wood")==5,"core unloading also requires uninterrupted time")
	world.tick_gather(actor,.9)
	check(actor.bag.count("wood")==0 and world.stock.wood==bank_before+5,"finished unloading credits the shared core depot exactly once")
	check(world.withdraw(actor,"wood",4) and actor.bag.count("wood")==4,"near-core withdrawal moves available materials back into the bag")
	var wood_slot := -1
	for i in range(18):
		if actor.bag.slots[i].id=="wood": wood_slot = i
	check(world.store_slot(actor,wood_slot) and actor.bag.count("wood")==0,"selected inventory stack can be stored at the core")
	actor.position = Vector3(20,0,20)
	check(not world.withdraw(actor,"wood",4),"remote depot withdrawal is rejected")
	actor.weapons.ammo[0] = 0
	actor.bag.selected = 0; actor.weapons.sync_hand()
	check(actor.weapons.reload(),"empty pistol begins reload from carried reserve")
	actor.weapons._process(10)
	check(actor.weapons.ammo[0]==12 and actor.bag.count("light")==36,"reload consumes exactly the actual rounds transferred")
	actor.weapons.ammo[0] = 0
	actor.weapons.reload()
	actor.bag.selected = 2; actor.weapons.sync_hand()
	check(actor.weapons.reload_left==0 and actor.bag.count("light")==36,"switching to an item cancels reload without spending reserve")
	check(not actor.weapons.shoot(Vector3.FORWARD),"selected grenade is not treated as a gun")
	actor.bag.selected = 0; actor.weapons.sync_hand()
	actor.bag.remove("light",36)
	check(not actor.weapons.reload() and actor.weapons.ammo[0]==0,"empty reserve cannot generate ammunition")
	actor.weapons.ammo[0] = 7
	actor.position = world.core.position+Vector3(0,0,2.4)
	check(world.store_slot(actor,0) and world.depot_count("light")==7,"storing a loaded gun unloads its rounds into the depot")
	check(world.withdraw(actor,"pistol",1) and actor.weapons.ammo[0]==0,"withdrawing a stored gun does not regenerate its magazine")
	actor.position = Vector3(20,0,20)
	var gun_slot := -1
	for i in range(18):
		if actor.bag.slots[i].id=="pistol": gun_slot = i
	actor.weapons.ammo[0] = 5
	check(world.drop_slot(actor,gun_slot) and actor.weapons.ammo[0]==0,"dropping a gun transfers ownership of loaded rounds to the pile")
	var gun_pile: Node3D
	for candidate in get_nodes_in_group("survival_loot"):
		if candidate.contents.has("pistol"): gun_pile = candidate
	check(gun_pile!=null and world.transfer_source(actor,gun_pile) and actor.weapons.ammo[0]==5,"picking up a dropped gun preserves its five loaded rounds")
	world.resources.scrap = 10000; world.stock = {"wood":1000,"parts":1000}
	actor.position = world.vendor_pos+Vector3(0,0,2)
	var before: int = world.resources.scrap
	check(world.buy_weapon(1) and actor.bag.count("shotgun")==1,"trader purchase places the weapon into the physical bag")
	check(not world.buy_weapon(1) and world.resources.scrap==before-CampaignData.PRICES[1],"duplicate weapon purchase cannot spend twice")
	var old_bag: Dictionary = actor.bag.dump()
	actor.bag = ItemBag.new(); actor.bag.add("wood",360)
	before = world.resources.scrap
	check(not world.shop_service("light") and world.resources.scrap==before,"full-bag shop purchase is atomic")
	actor.bag.restore(old_bag)
	check(world.build_quota()==6,"first preparation permits six placed defenses for the whole team")
	var builder: Node3D = world.builder
	builder.set_active(true); builder.selected = 4; builder.set_physics_process(false)
	for i in range(6):
		builder.location = Vector3(20+i%3*5,0,20+i/3*5)
		actor.position = builder.location+Vector3(0,0,3)
		await frames()
		check(builder.place()!=null,"valid placement consumes quota %d" % (i+1))
	before = world.resources.scrap
	builder.location = Vector3(35,0,25); actor.position = Vector3(35,0,29)
	check(builder.place()==null and world.built_this_round==6 and world.resources.scrap==before,"seventh placement is blocked without spending resources")
	var placed: Node3D = get_nodes_in_group("campaign_structure")[0]
	placed.dismantle()
	check(world.built_this_round==6,"dismantling does not refund the wave placement budget")
	builder.set_active(false)
	world.waves.running = true; world.waves.wave = 1; world.waves.to_spawn = 0
	world.waves.complete()
	check(world.built_this_round==0 and world.phase=="prep","surviving a wave renews the team construction budget")
	world.waves.wave = 30
	check(world.build_quota()==12,"construction allowance grows but caps at twelve per preparation")
	world.waves.wave = 0
	actor.health.setup(100); actor.invulnerable = 0
	check(world.attach_peer(2,"test-peer-two","Teste"),"host creates a second authoritative survivor")
	var guest: Node3D = world.avatars[2]
	guest.set_physics_process(false)
	check(world.team_multiplier()==2,"two players double total population")
	check(world.attach_peer(3,"test-peer-three","Teste 3") and world.team_multiplier()==4,"three players quadruple population")
	check(world.attach_peer(4,"test-peer-four","Teste 4") and world.team_multiplier()==8,"four players multiply population by eight")
	check(not world.attach_peer(5,"fifth","Teste 5"),"fifth player is rejected")
	for id in [3,4]: world.avatars[id].set_physics_process(false); world.detach_peer(id)
	await frames()
	actor.position = Vector3(20,0,20); guest.position = actor.position+Vector3(1,0,0)
	guest.invulnerable = 0; guest.take_damage(10000)
	check(guest.health.dead and world.phase!="ended","one downed teammate does not end an active cooperative game")
	var down_profile: Dictionary = world.actor_profile(guest)
	check(world.valid_profile(down_profile) and down_profile.hp==0,"profile keeps zero health instead of healing on reconnect")
	world.restore_profile(guest,down_profile)
	check(guest.health.dead and guest.downed,"restoring a downed profile preserves the revival requirement")
	var kits: int = actor.bag.count("medkit")
	world.tick_gather(actor,3.6)
	check(not guest.health.dead and guest.health.current==40 and actor.bag.count("medkit")==kits-1,"holding E spends a medkit and revives the nearby teammate")
	world.detach_peer(2); await frames()
	check(world.team_multiplier()==1,"leaving reduces future population back to solo")
	actor.health.setup(100); actor.invulnerable = 0
	world.waves.wave = 9
	check(world.waves.enemy_type(11)==9 and world.waves.enemy_type(13)==10 and world.waves.enemy_type(17)==11,"later hordes introduce exploding, summoning and healing enemies")
	var boss := hostile(8,Vector3(20,0,15))
	check(boss.health.maximum>=float(boss.spec.values.health)*CampaignData.health_scale(9)*1.59,"boss receives the extra survival durability multiplier")
	boss.ability_left = 0; boss._physics_process(.01)
	check(boss.windup>0 and is_instance_valid(boss.warning),"boss attack telegraphs its damage area before detonation")
	var state: Dictionary = world.net_state(1)
	check(state.hazards.any(func(h): return h.get("warning",false)),"remote snapshots include the boss warning zone")
	boss._physics_process(1.2)
	check(actor.health.current<100 and boss.shield_left>0,"boss power damages nearby survivor and starts temporary armor")
	check(get_nodes_in_group("enemies").size()==2,"boss power summons a real hound")
	var hp: float = boss.health.current
	boss.take_damage(100)
	check(is_equal_approx(hp-boss.health.current,35),"temporary boss armor reduces incoming damage")
	boss.health.current = boss.health.maximum*.3; boss.shield_left = 0
	var speed: float = boss.spec.values.speed
	boss._physics_process(.01)
	check(boss.enraged and boss.spec.values.speed>speed,"boss enters rage at low health")
	clear_hostiles(); await frames()
	var screamer := hostile(10,Vector3(20,0,12))
	screamer.ability_left = 0; screamer._physics_process(.01); screamer._physics_process(1.2)
	check(get_nodes_in_group("enemies").size()==3,"screamer summons two separate hounds")
	clear_hostiles(); await frames()
	var mender := hostile(11,Vector3(20,0,12))
	var ally := hostile(0,Vector3(21,0,12))
	ally.health.take_damage(30); hp = ally.health.current
	mender.special_clock = 0; mender._physics_process(.01)
	check(ally.health.current>hp,"regenerator heals a wounded nearby infected")
	clear_hostiles(); await frames()
	actor.health.setup(100); actor.invulnerable = 0
	var burster := hostile(9,actor.position+Vector3(1,0,0))
	burster.take_damage(100000)
	check(actor.health.current<100,"exploding infected damages nearby survivors on death")
	clear_hostiles(); await frames()
	world.resources.pending = 0; world.upgrades.offers.clear(); world.hud.close_modal()
	actor.health.setup(100); actor.position = Vector3(0,0,3)
	world.waves.wave = 2; world.built_this_round = 3
	var snap: Dictionary = world.snapshot()
	check(snap.format==4 and world.valid_snapshot(JSON.parse_string(JSON.stringify(snap))),"survival v4 checkpoint validates after JSON serialization")
	world.built_this_round = 0; actor.bag = ItemBag.new()
	world.apply_snapshot(snap)
	check(world.built_this_round==3 and actor.bag.dump()==snap.bag,"snapshot restores physical inventory and spent construction budget")
	var previous: Dictionary = snap.duplicate(true)
	previous.format = 3
	for key in ["bag","depot_items","profiles","loose","built"]: previous.erase(key)
	var migrated = world.migrate_snapshot(previous)
	check(world.valid_snapshot(migrated) and migrated.format==4 and previous.format==3,"v3 saves migrate to bags without mutating the source")
	var corrupt: Dictionary = snap.duplicate(true); corrupt.built = 13
	check(not world.valid_snapshot(corrupt),"corrupt construction budget is rejected")
	corrupt = snap.duplicate(true); corrupt.bag.slots[0].qty = 9999
	check(not world.valid_snapshot(corrupt),"corrupt bag rejects the whole checkpoint")
	world.hud.show_inventory()
	check(world.hud.hotbar.size()==9 and world.hud.inventory_buttons.size()==18 and not paused,"inventory has eighteen slots, nine belt buttons, and keeps time running")
	world.hud.close_modal()
	world.queue_free(); await create_timer(.35).timeout
	print("SURVIVAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
