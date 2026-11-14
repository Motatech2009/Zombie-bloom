extends SceneTree
var checks := 0
var failures := 0
var world: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func frames(n: int = 3) -> void:
	for i in range(n): await physics_frame; await process_frame
func step(direction: int) -> bool:
	world.resources.pending = 0; world.upgrades.offers.clear(); world.hud.close_modal(); world.travel_cooldown = 0
	for actor in world.avatars.values(): actor.position = world.sector_offset(world.sector_coord)+SectorGenerator.EXITS[direction]
	var result: bool = world.step_sector(direction)
	for house in get_nodes_in_group("raid_houses"): house.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	return result
func enemy(kind: int,pos: Vector3,index: int) -> Node3D:
	var actor: Node3D = world.make_enemy(kind,pos,true,index); actor.set_physics_process(false)
	return actor
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	world = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false); world.set_process(false); world.player.set_physics_process(false)
	world.player.invulnerable = 100000; world.world_rng.seed = 8417; world.elapsed = 0
	check(step(0),"first expedition enters the northern sector")
	await frames()
	check(world.descriptor.count>=2 and world.sector_deadline==180,"a new generation receives an exact three-minute lifetime")
	var initial_seed: int = world.descriptor.seed
	var actor: Node3D = world.player
	var cache: Node3D = world.caches[0]
	cache.set_meta("contents",{"rifle_ammo":12,"wood":8}); actor.position = cache.global_position
	check(world.transfer_source(actor,cache) and actor.bag.count("rifle_ammo")==4,"taking a real partial stack leaves supplies in the regional box")
	var remaining: Dictionary = cache.get_meta("contents").duplicate()
	var house: Node3D = world.raid_house(0)
	house.activated = true; house.dead.append(0); house.contents.scrap -= 7
	var house_contents: Dictionary = house.contents.duplicate()
	var guard := enemy(0,house.position,-3)
	guard.set_meta("house_id",0); guard.set_meta("house_guard",1); guard.add_to_group("house_guards"); guard.health.setup(200); guard.health.current = 71
	var boss := enemy(8,Vector3(20,0,0),0); boss.health.current *= .63
	var boss_hp: float = boss.health.current; var boss_id: String = boss.spec.id
	var ordinary := enemy(0,Vector3(-20,0,0),1); ordinary.take_damage(1000000)
	world.spawn_loot(world.field_root.to_global(Vector3(12,0,15)),{"cells":8},0,"",0,false)
	check(world.field_defeated==[1],"a real field death records the exact encounter index")
	var bag: Dictionary = actor.bag.dump()
	check(step(2),"leaving the area returns to the persistent core")
	await frames()
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.snapshot()))
	check(world.valid_snapshot(data),"cached geometry, partial loot, houses and enemies survive JSON checkpoint validation")
	var old: Dictionary = data.duplicate(true); old.erase("sector_memory")
	check(world.valid_snapshot(old),"existing v6 saves without sector memory remain compatible")
	var bad: Dictionary = data.duplicate(true); bad.sector_memory["0:-1"].caches[0].fake_item = 1
	check(not world.valid_snapshot(bad),"unknown cached item types reject a checkpoint without mutating the live game")
	bad = data.duplicate(true); bad.sector_memory["0:-1"].expires = 999999
	check(not world.valid_snapshot(bad),"an invalid regeneration deadline is rejected")
	world.elapsed = 60; world.waves.wave = 4
	check(step(0),"the same area can be re-entered before its timer expires")
	await frames()
	check(world.descriptor.seed==initial_seed and world.sector_deadline==180,"quick revisits neither reroll the map nor extend its generation timer")
	check(world.caches[0].get_meta("contents")==remaining and actor.bag.dump()==bag,"re-entry preserves partially harvested loot without copying it into the bag")
	house = world.raid_house(0)
	check(house.dead==[0] and house.activated and house.contents==house_contents,"house deaths and partially emptied supplies are restored exactly")
	var guards: Array = house.active_guards()
	check(guards.size()==1 and guards[0].health.current==71,"a living house guard returns with its remaining health")
	var bosses := get_nodes_in_group("boss_enemies").filter(func(e): return e.field_enemy)
	check(bosses.size()==1 and is_equal_approx(bosses[0].health.current,boss_hp) and bosses[0].spec.id==boss_id,"a wounded boss keeps its health and identity even after a wave advances")
	check(world.field_defeated==[1] and not 1 in world.field_queue and not 0 in world.field_queue,"defeated and already materialized enemies cannot be queued twice")
	check(get_nodes_in_group("survival_loot").filter(func(p): return p.get_parent()==world.field_root and p.contents=={"cells":8}).size()==1,"a dropped pile is restored once with its original contents")
	check(step(2),"party leaves the preserved area again")
	world.elapsed = 179.99; check(step(0) and world.descriptor.seed==initial_seed,"the old layout remains active immediately before the deadline")
	check(step(2),"party can leave at the cooldown boundary")
	world.elapsed = 180.01; check(step(0),"the area can be entered after its regeneration deadline")
	await frames()
	check(world.descriptor.seed!=initial_seed and world.field_defeated.is_empty() and world.sector_deadline>360,"only the next entry after three minutes regenerates layout, enemies and loot")
	check(world.raid_house(0).dead.is_empty() and not world.caches[0].get_meta("contents")==remaining,"a fresh generation has fresh houses and cache contents")
	check(step(2),"return to base permits checkpoint restoration")
	world.apply_snapshot(data); world.elapsed = 60
	check(step(0) and world.descriptor.seed==initial_seed and world.caches[0].get_meta("contents")==remaining,"save/load cannot bypass the cooldown or restore already taken supplies")
	check(step(2),"loot and boss tests return to base")
	for e in get_nodes_in_group("enemies"): e.queue_free()
	await frames()
	actor.position = Vector3(0,0,12); actor.bag = ItemBag.new(); world.starter_bag(actor.bag)
	var supply: Node3D = world.spawn_loot(actor.position,{"wood":8},0,"",0,false)
	actor.cancel_gather(); world.tick_gather(actor,1.67)
	check(actor.bag.count("wood")==0 and is_equal_approx(actor.gather_duration,1.68),"solo gathering remains timed but uses forty percent less time")
	world.tick_gather(actor,.02)
	check(actor.bag.count("wood")==4,"solo gathering completes at its reduced threshold")
	actor.cancel_gather(); world.tick_gather(actor,.4)
	var fraction: float = actor.gather_progress/actor.gather_duration
	world.attach_peer(2,"22222222222222222222222222222222","Friend"); world.avatars[2].set_physics_process(false)
	world.tick_gather(actor,0)
	check(is_equal_approx(actor.gather_duration,2.8) and is_equal_approx(actor.gather_progress/actor.gather_duration,fraction),"a joining player restores co-op timing without granting free gather progress")
	check(world.collect_seconds("loot",5)==5 and world.collect_seconds("deposit",1.8)==1.8,"cooperative rare-crate and deposit times stay unchanged")
	world.detach_peer(2); actor.cancel_gather()
	check(is_equal_approx(world.collect_seconds("loot",5),3) and is_equal_approx(world.collect_seconds("deposit",1.8),1.08) and world.collect_seconds("repair",1.8)==1.8,"solo acceleration affects supplies and deposit while repair timing remains unchanged")
	world.attach_peer(2,"22222222222222222222222222222222","Friend"); world.avatars[2].set_physics_process(false)
	var guest: Node3D = world.avatars[2]; guest.bag.add("wood",9)
	var checkpoint: Dictionary = world.snapshot()
	guest.bag.add("parts",5); world.apply_snapshot(checkpoint)
	check(guest.bag.count("wood")==9 and guest.bag.count("parts")==0,"restoring supplies also rewinds connected guest inventories to prevent save/load duplication")
	world.attach_peer(3,"33333333333333333333333333333333","Later friend"); world.avatars[3].set_physics_process(false)
	world.avatars[3].bag.add("wood",17); world.apply_snapshot(checkpoint)
	check(world.avatars[3].bag.count("wood")==0,"a guest joining after a checkpoint cannot carry future supplies into the restored world")
	world.detach_peer(2); world.detach_peer(3)
	var military := 0; var forest := 0; var varieties := {}
	for i in range(400):
		var descriptor := {"seed":i+1,"visit":1,"biome":4}
		var loot := LootTables.regional(descriptor,0)
		check_once_valid_loot(loot,varieties)
		if loot.keys().any(func(id): return id in ItemBag.AMMO_IDS): military += 1
		descriptor.biome = 2
		if LootTables.regional(descriptor,0).keys().any(func(id): return id in ItemBag.AMMO_IDS): forest += 1
	check(military>250 and forest<100 and military>forest*3,"military caches roll ammunition much more often than forest caches")
	check(varieties.has("rocket") and varieties.has("cells") and varieties.has("grenade") and varieties.has("medkit"),"regional loot includes several ammunition families and consumables")
	var fixture := {"seed":1234,"visit":2,"biome":4}
	check(LootTables.regional(fixture,1)==LootTables.regional(fixture,1),"a cache's supply roll is deterministic within its generation")
	world.waves.wave = 1
	var first: Node3D = world.make_enemy(8,Vector3(20,0,20),false,0); first.set_physics_process(false)
	var first_hp: float = first.health.maximum
	check(first_hp>1200,"the first solo boss has substantially more than one thousand health")
	world.attach_peer(2,"22222222222222222222222222222222","Friend"); world.avatars[2].set_physics_process(false)
	var pair: Node3D = world.make_enemy(8,Vector3(25,0,20),false,1); pair.set_physics_process(false)
	check(pair.health.maximum>=first_hp*1.49,"a cooperative boss also gains additional health per player")
	world.detach_peer(2); world.waves.wave = 10
	var later: Node3D = world.make_enemy(8,Vector3(30,0,20),false,2); later.set_physics_process(false)
	check(later.health.maximum>first_hp*5,"boss endurance continues growing with later waves")
	first.take_damage(100000000)
	var rewards := get_nodes_in_group("survival_loot").filter(func(p): return p.get_meta("boss_drop",false))
	check(rewards.size()==1 and rewards[0].contents.has("light") and rewards[0].contents.has("parts") and rewards[0].has_node("BossReward"),"boss death creates a distinct extra supply drop with ammunition and components")
	var bonus := LootTables.boss(3,world.world_rng)
	check(bonus.light>=24 and bonus.parts>=6 and bonus.scrap>=45,"boss rewards guarantee useful supplies independently of optional rare rolls")
	actor.bag = ItemBag.new(); world.starter_bag(actor.bag); actor.position = rewards[0].global_position
	var bank: int = world.resources.scrap
	check(world.collect_ground(actor,rewards[0]) and actor.bag.count("parts")>=6 and actor.bag.count("light")>48 and world.resources.scrap==bank,"extra boss loot is carried in the player's bag and still needs transport to the core")
	var piles: int = get_nodes_in_group("survival_loot").filter(func(p): return p.get_parent()==world.base_root).size()
	for i in range(piles,128): world.spawn_loot(Vector3(40,0,-20),{"scrap":1})
	var merged: Node3D = world.spawn_loot(Vector3(40,0,-20),{"rifle":1,"rifle_ammo":12,"parts":6})
	check(merged!=null and merged.visible and merged.contents.get("rifle",0)>=1 and merged.contents.get("parts",0)>=6,"a full ground-drop budget merges an unloaded rare reward instead of losing boss supplies")
	world.queue_free(); await create_timer(.2).timeout
	print("PROGRESSION RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func check_once_valid_loot(loot: Dictionary,varieties: Dictionary) -> void:
	for id in loot:
		if id not in ItemBag.IDS or int(loot[id])<=0: failures += 1; push_error("Invalid regional supply")
		varieties[id] = true
