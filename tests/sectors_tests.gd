extends SceneTree
var world: Node3D
var checks: int = 0
var failures: int = 0
var backups := {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)

func frames(count: int = 2) -> void:
	for i in range(count): await physics_frame; await process_frame

func clear_choices() -> void:
	world.resources.pending = 0
	world.upgrades.offers.clear()
	if world.hud.mode!="result": world.hud.close_modal()

func step(direction: int) -> bool:
	world.travel_cooldown = 0
	world.player.position = world.sector_offset(world.sector_coord)+SectorGenerator.EXITS[direction]
	return world.step_sector(direction)

func structure(piece: int,pos: Vector3) -> Node3D:
	var result := StaticBody3D.new()
	result.set_script(load("res://scripts/campaign/campaign_structure.gd"))
	result.world = world
	result.piece_index = piece
	result.position = pos
	world.base_root.add_child(result)
	world.layout_revision += 1
	return result

func clear_field() -> void:
	world.field_queue.clear()
	for enemy in get_nodes_in_group("enemies"):
		if enemy.field_enemy:
			enemy.get_parent().remove_child(enemy)
			enemy.queue_free()

func run() -> void:
	var script = load("res://scripts/sectors/roaming_world.gd")
	for mode in ["campaign","endless"]:
		var path: String = script.frontier_path(mode)
		backups[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	var descriptor := SectorGenerator.generate(8417,Vector2i(1,0),1,0)
	check(descriptor==SectorGenerator.generate(8417,Vector2i(1,0),1,0),"sector generation is deterministic for the same visit inputs")
	check(descriptor!=SectorGenerator.generate(8417,Vector2i(1,0),2,0),"re-entry visit changes the generated sector")
	var risks := {}
	var rare_count := 0
	var rare_seed := -1
	for i in range(300):
		var data := SectorGenerator.generate(i+1,Vector2i(1,0),1,0)
		risks[data.risk] = true
		if data.rare>=1: rare_count += 1; rare_seed = i+1
		for block in data.blocks:
			if absf(block.pos.x)<8+block.size.x/2 or absf(block.pos.z)<8+block.size.z/2: failures += 1; push_error("Blocked return lane")
	check(risks.size()==5,"procedural sample includes quiet, patrolled, dense, infested and boss sectors")
	check(rare_count>0 and rare_count<35,"hidden weapons are rare outcomes rather than guaranteed rewards")
	check(SectorGenerator.generate(rare_seed,Vector2i(1,0),1,0).rare in [1,2,3,4],"rare stash references a valid purchasable weapon")
	load("res://scripts/campaign/campaign_world.gd").next_mode = "campaign"
	world = load("res://scenes/sectors/RoamingWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.world_rng.seed = 8417
	await frames()
	world.waves.set_physics_process(false)
	world.set_process(false)
	check(world.sector_coord==Vector2i.ZERO and world.base_root.is_inside_tree(),"core initializes as the fixed origin sector")
	check(world.exit_labels.size()==4 and world.exit_positions().size()==4,"core has four physical cardinal exits")
	check(world.horde_left>200 and not world.waves.start(),"manual wave start cannot skip the first countdown")
	check(not world.step_sector(1),"map selection does not teleport a player away from a physical exit")
	world.hud.show_routes()
	check(world.hud.mode=="routes" and not paused,"sector map keeps the world clock running")
	world.hud.select_sector(Vector2i(3,-2))
	check(world.waypoint==Vector2i(3,-2) and world.sector_coord==Vector2i.ZERO,"map cell selects information without moving player")
	world.hud.close_modal()
	var base: Node3D = world.base_root
	var core: Node3D = world.core
	var wall := structure(2,Vector3(7,0,2))
	await frames()
	check(step(1) and world.sector_coord==Vector2i(1,0),"east exit enters a generated neighboring square")
	await frames()
	check(base.is_inside_tree() and core==world.core and wall.is_inside_tree(),"core and defenses stay physically active during exploration")
	check(world.player.position.x>65 and world.arena!=world.base_arena,"active sector uses its own distant physical space")
	check(world.discovered.has("1:0") and world.discovered["1:0"].visits==1,"sector visit records its coordinates and last observed risk")
	var first: Dictionary = world.descriptor.duplicate(true)
	var queues_before: int = world.field_queue.size()
	if queues_before>0:
		check(world.spawn_field_enemy(),"procedural population materializes at a valid spawn point")
		var spawned: Node3D
		for enemy in get_nodes_in_group("enemies"):
			if enemy.field_enemy: spawned = enemy; break
		spawned.set_physics_process(false)
		spawned.choose_target()
		check(spawned.target==world.player and spawned.global_position.x>60,"sector enemy targets survivor in translated world coordinates")
		check(not world.route_for_enemy(spawned,world.player.position).is_empty(),"sector navigation translates between local and global cells")
		var before: int = world.resources.scrap
		spawned.take_damage(1000000)
		clear_choices()
		var drop: Node3D
		for p in get_nodes_in_group("pickups"):
			if p.get_parent()==world.field_root and p.scrap>0: drop = p; break
		check(drop!=null and drop.global_position.x>60 and drop.global_position.x<180,"field rewards do not double-apply the sector offset")
		if drop!=null: drop.collect()
		clear_choices()
		check(world.resources.scrap>before,"field loot remains collectable after coordinate translation")
	clear_field()
	await frames()
	var reward_before := {"scrap":world.resources.scrap,"wood":world.stock.wood,"parts":world.stock.parts}
	for i in range(3):
		world.player.position = world.caches[i].global_position
		check(world.collect_cache(i) and not world.collect_cache(i),"resource cache grants its rolled share exactly once %d" % i)
	check(world.resources.scrap-reward_before.scrap==int(first.reward.scrap) and world.stock.wood-reward_before.wood==int(first.reward.wood) and world.stock.parts-reward_before.parts==int(first.reward.parts),"three caches conserve the complete sector resource roll")
	# Inject a known rare encounter seed, not a production cheat or guaranteed spawn.
	world.descriptor = SectorGenerator.generate(rare_seed,Vector2i(1,0),1,0)
	for cache in world.caches: cache.queue_free()
	world.caches.clear()
	world.claimed.clear()
	world.create_caches()
	var last: int = world.caches.size()-1
	var weapon: int = world.descriptor.rare
	world.player.position = world.caches[last].global_position
	check(world.collect_cache(last) and world.player.weapons.owned[weapon],"rare hidden armory unlocks a real weapon")
	check(not world.collect_cache(last),"hidden weapon cannot be claimed twice in the same visit")
	check(step(3) and world.sector_coord==Vector2i.ZERO,"west exit returns from east square to the core")
	await frames()
	check(world.base_root==base and wall==world.get_tree().get_nodes_in_group("campaign_structure")[0],"return preserves the original defense instances")
	check(world.exit_labels.size()==4 and world.exit_labels[2]==world.exit_tag,"return restores the stable four core markers")
	check(step(1),"east sector can be revisited")
	await frames()
	check(world.descriptor.seed!=first.seed and world.descriptor!=first and world.claimed.is_empty(),"revisit replaces geometry, population and loot claims")
	check(world.discovered["1:0"].visits==2,"re-entry increments the sector visit record")
	clear_field()
	world.horde_left = .02
	world.waves._physics_process(.1)
	check(world.waves.running and world.waves.wave==1 and world.phase=="combat" and world.sector_coord==Vector2i(1,0),"countdown starts the first horde while survivor is away")
	var wave_enemy: Node3D = world.waves.spawn_enemy()
	wave_enemy.set_physics_process(false)
	wave_enemy.choose_target()
	check(wave_enemy.is_boss and wave_enemy.is_in_group("wave_enemies") and wave_enemy.target==core,"first wave already has a boss that targets the remote core")
	var hp_before: float = core.health.current
	wave_enemy.position = Vector3(0,0,-3)
	wave_enemy.set_physics_process(true)
	await frames(35)
	wave_enemy.set_physics_process(false)
	check(core.health.current<hp_before,"remote boss AI physically reaches and damages the core while player remains away")
	var turret := structure(1,Vector3(5,0,-4))
	var target: Node3D = world.make_enemy(0,Vector3(5,0,-8),false,800)
	target.set_physics_process(false)
	await frames()
	var target_hp: float = target.health.current
	turret.cooldown = 0
	turret._physics_process(.1)
	check(target.health.current<target_hp,"base turret still fires at enemies while active exploration is another sector")
	target.queue_free()
	await frames()
	var field_enemy: Node3D = world.make_enemy(0,Vector3(0,0,-10),true,900)
	field_enemy.set_physics_process(false)
	check(world.waves.alive()==1 and world.field_alive()==1,"wave counters do not include exploration enemies")
	check(not step(1) and world.sector_coord==Vector2i(1,0),"active invasion blocks moving farther from the core")
	var spitter: Node3D = world.make_enemy(5,Vector3(0,0,-14),false,901)
	spitter.set_physics_process(false)
	spitter.choose_target()
	spitter.acid_left = 0
	spitter._physics_process(.01)
	var acid: Node3D
	for shot in get_nodes_in_group("campaign_projectiles"):
		if shot.kind=="acid": acid = shot; break
	check(acid!=null and acid.region_key=="0:0","off-screen base projectile retains the core region identity")
	var pool: Node3D = world.spawn_acid(Vector3(0,0,0),2.5,8)
	var core_hp: float = core.health.current
	pool.tick = 0
	pool._physics_process(.01)
	check(core.health.current<core_hp and pool.region_key=="0:0","corrosive damage can reach the core while player explores elsewhere")
	check(step(3) and world.sector_coord==Vector2i.ZERO and world.phase=="combat","survivor can return into an ongoing invasion")
	await frames()
	check(pool.is_inside_tree() and not pool.is_queued_for_deletion(),"return does not erase hazards belonging to the base")
	spitter.queue_free()
	field_enemy = null
	world.clear_base_hazards()
	for enemy in get_nodes_in_group("wave_enemies"):
		enemy.take_damage(1000000)
		enemy.queue_free()
	clear_choices()
	world.waves.to_spawn = 0
	world.waves.complete()
	check(not world.waves.running and world.phase=="prep" and world.horde_left>100,"wave victory resets a timed preparation interval")
	for number in range(1,21):
		world.waves.wave = number
		check(world.waves.enemy_type(0)==8,"every wave has a boss slot %d" % number)
	world.waves.wave = 1
	var names := {}
	for number in range(1,6): names[SectorGenerator.boss_spec(number).title] = true
	check(names.size()==5,"boss cycle includes five different behavior archetypes")
	world.horde_left = 73.5
	world.player.position = Vector3(3,0,4)
	core.health.heal(100)
	check(world.save_checkpoint(false),"version-three checkpoint saves exploration history and timer")
	var snap: Dictionary = world.snapshot()
	check(world.valid_snapshot(JSON.parse_string(JSON.stringify(snap))),"world RNG string and exploration metadata survive JSON serialization")
	var expected_seed: int = world.world_rng.randi()
	world.horde_left = 1
	check(world.load_checkpoint() and is_equal_approx(world.horde_left,73.5) and world.world_rng.randi()==expected_seed,"restore preserves remaining time and exact 64-bit RNG state")
	var bad := snap.duplicate(true)
	bad.horde_left = -1
	check(not world.valid_snapshot(bad),"invalid negative horde clock is rejected")
	bad = snap.duplicate(true)
	bad.rng_state = "invalid"
	check(not world.valid_snapshot(bad),"malformed RNG state is rejected before applying")
	bad = snap.duplicate(true)
	bad.discovered["bad"] = {"visits":1,"risk":1}
	check(not world.valid_snapshot(bad),"malformed sector coordinates are rejected")
	var old := snap.duplicate(true)
	old.format = 2
	for key in ["horde_left","world_seed","rng_state","visit_serial","discovered"]: old.erase(key)
	var migrated: Dictionary = world.migrate_snapshot(old)
	check(world.valid_snapshot(migrated) and migrated.horde_left==210 and old.format==2,"old manual-wave save converts without changing its source")
	var saved_visits: int = int(world.discovered["1:0"].visits)
	world.queue_free()
	await process_frame
	load("res://scripts/campaign/campaign_world.gd").resume_requested = true
	world = load("res://scenes/sectors/RoamingWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	world.waves.set_physics_process(false)
	check(world.waves.wave==1 and world.horde_left>70 and int(world.discovered["1:0"].visits)==saved_visits,"cold restart restores core campaign, timer and visited map")
	world.queue_free()
	await process_frame
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	world = load("res://scenes/sectors/RoamingWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	world.set_process(false)
	world.waves.set_physics_process(false)
	world.waves.wave = 20
	check(step(1),"infinite mode can enter a generated sector between waves")
	world.horde_left = 0
	world.waves._physics_process(.01)
	check(world.waves.wave==21 and world.waves.running and world.waves.enemy_type(0)==8,"timed infinite wave twenty-one starts with a boss while away")
	world.waves.to_spawn = 0
	world.waves.complete()
	check(world.phase=="expedition" and not world.won and world.horde_left>100,"remote wave completion keeps exploration and the infinite loop alive")
	world.queue_free()
	await process_frame
	load("res://scripts/campaign/campaign_world.gd").next_mode = "campaign"
	for path in backups:
		if backups[path]==null: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path,FileAccess.WRITE)
			file.store_string(backups[path])
			file.close()
	await create_timer(.35).timeout
	print("SECTORS RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
