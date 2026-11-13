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
func enemy(kind: int,pos: Vector3) -> Node3D:
	var actor: Node3D = world.make_enemy(kind,pos,false,1)
	actor.set_physics_process(false); return actor
func structure(piece: int,pos: Vector3,tier: int = 1) -> Node3D:
	var actor := StaticBody3D.new(); actor.set_script(world.structure_script())
	actor.world = world; actor.piece_index = piece; actor.position = pos; actor.tier = tier
	actor.invested = FortressData.pieces()[piece].cost.duplicate()
	world.base_root.add_child(actor); actor.set_physics_process(false)
	world.layout_revision += 1; return actor
func clear_enemies() -> void:
	for actor in get_nodes_in_group("enemies"): actor.get_parent().remove_child(actor); actor.queue_free()
func clear_choices() -> void:
	world.resources.pending = 0; world.upgrades.offers.clear(); world.hud.close_modal()
func step(direction: int) -> bool:
	world.travel_cooldown = 0
	world.player.position = world.sector_offset(world.sector_coord)+SectorGenerator.EXITS[direction]
	return world.step_sector(direction)
func first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found := first_mesh(child)
		if found!=null: return found
	return null
func run() -> void:
	check(FortressData.pieces().size()==10,"ten defenses keep original indices and add four distinct tools")
	for piece in range(10):
		for tier in range(1,4):
			var id: String = FortressData.pieces()[piece].id
			var model: Node3D = load("res://assets/fortress/"+id+"_"+str(tier)+".tscn").instantiate()
			check(model.get_meta("tier")==tier and model.get_child_count()>2 and first_mesh(model)!=null,"editable defense model imports: %s N%d" % [id,tier])
			model.free()
	for tier in range(1,5):
		var model: Node3D = load("res://assets/fortress/core_"+str(tier)+".tscn").instantiate()
		check(model.get_meta("tier")==tier and model.get_child_count()>=8,"Nucleus has a distinct fortified model N%d" % tier)
		model.free()
	var cargo: Node3D = load("res://assets/fortress/airdrop.tscn").instantiate()
	check(cargo.has_node("Parachute") and cargo.get_child_count()>4,"supply crate contains an actual parachute and multiple meshes")
	cargo.free()
	load("res://scripts/campaign/campaign_world.gd").next_mode = "campaign"
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	world = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	await frames(); world.set_process(false); world.waves.set_physics_process(false)
	var actor: Node3D = world.player; actor.set_physics_process(false)
	actor.position = Vector3(20,0,20)
	var bag_before: int = actor.bag.count("scrap")
	var bank_before: int = world.resources.scrap
	var target := enemy(0,actor.position+Vector3(1,0,0))
	target.take_damage(1000000)
	await create_timer(.25).timeout
	check(actor.bag.count("scrap")>bag_before,"walking over an actual infected death drop collects it without holding E")
	check(world.resources.scrap==bank_before,"automatic drops still go to the bag, never directly to the core wallet")
	clear_choices()
	bag_before = actor.bag.count("scrap")
	target = enemy(7,actor.position+Vector3(1,0,0)); target.take_damage(1000000)
	await create_timer(.25).timeout
	check(actor.bag.count("scrap")>bag_before,"flying infected drops land on the ground and collect while passing underneath")
	clear_choices()
	actor.bag = ItemBag.new(); actor.bag.add("scrap",720)
	var pile: Node3D = world.spawn_loot(actor.position,{"wood":10},2)
	var xp: int = world.resources.xp
	await create_timer(.25).timeout
	check(pile.contents.wood==10 and actor.bag.count("wood")==0,"full bag leaves the physical material surplus on the ground")
	check(world.resources.xp==xp+2,"XP collects instantly even when material stacks do not fit")
	await create_timer(.2).timeout
	check(world.resources.xp==xp+2,"walking pickup cannot grant the same experience twice")
	actor.bag.remove("scrap",40); await create_timer(.25).timeout
	check(actor.bag.count("wood")==10 and not is_instance_valid(pile),"freeing one bag slot allows the remaining ground stack to collect automatically")
	actor.bag = ItemBag.new(); world.starter_bag(actor.bag)
	check(world.attach_peer(2,"fixture-friend","Amigo"),"second authoritative survivor is available for pickup ownership")
	var guest: Node3D = world.avatars[2]; guest.set_physics_process(false); guest.position = Vector3(24,0,20)
	pile = world.spawn_loot(guest.position,{"parts":3})
	await create_timer(.25).timeout
	check(guest.bag.count("parts")==3 and actor.bag.count("parts")==0,"nearest co-op survivor receives the stack exactly once")
	world.detach_peer(2); await frames()
	check(step(1),"timed crate test reaches a real generated sector")
	var cache: Node3D = world.caches[0]
	actor.position = cache.global_position
	var contents: Dictionary = cache.get_meta("contents").duplicate(true)
	await create_timer(.25).timeout
	check(cache.get_meta("contents")==contents,"walking across a regional supply box does not collect it")
	var id: String = contents.keys()[0]; var before: int = actor.bag.count(id)
	world.tick_gather(actor,1)
	check(actor.bag.count(id)==before,"regional box still requires uninterrupted gathering time")
	world.tick_gather(actor,1.9)
	check(actor.bag.count(id)>before,"finished regional gathering transfers a small batch")
	check(step(3),"party returns from timed crate test to the fixed base")
	clear_choices(); actor.bag = ItemBag.new(); world.starter_bag(actor.bag)
	world.resources.scrap = 50000; world.stock = {"wood":5000,"parts":5000}
	var wall := structure(0,Vector3(20,0,15))
	var n1_color: Color = first_mesh(wall.model).material_override.albedo_color
	actor.position = wall.position+Vector3(0,0,3)
	wall.take_damage(20)
	check(wall.improve() and wall.tier==2,"paid improvement raises an actual barricade to N2")
	var n2_color: Color = first_mesh(wall.model).material_override.albedo_color
	check(n1_color!=n2_color and wall.model.get_node("Visual").get_meta("material")==FortressData.MATERIALS[1],"N2 replaces wood geometry/material with reinforced steel")
	check(wall.improve() and wall.tier==3,"paid improvement reaches N3")
	check(first_mesh(wall.model).material_override.albedo_color!=n2_color and wall.model.get_node("Visual").get_meta("material")==FortressData.MATERIALS[2],"N3 replaces the model/material again with concrete and armor")
	check(not wall.improve(),"third-tier defense cannot charge for a fourth defense level")
	var gate := structure(3,Vector3(28,0,15)); actor.position = Vector3(20,0,20)
	await frames()
	check(gate.toggle() and gate.collision_layer==0 and gate.model.position.y==0 and gate.model.get_node("Visual/Door").position.y>2,"opening a gate lifts its door while the frame stays fixed")
	actor.position = gate.position; await frames()
	check(not gate.toggle() and gate.opened,"gate refuses to close over a survivor")
	actor.position = Vector3(20,0,20); await frames(); gate.toggle()
	var wire := structure(6,Vector3(20,0,25))
	var walker := enemy(0,wire.position+Vector3(.2,0,0)); walker.health.setup(500)
	var flyer := enemy(7,wire.position+Vector3(-.2,0,0)); flyer.health.setup(500)
	wire.cooldown = 0; wire._physics_process(.01)
	check(wire.collision_layer==0 and walker.health.current<500 and walker.snare_left>0,"razor wire allows passage while cutting and slowing ground infected")
	check(flyer.health.current==500,"airborne infected are unaffected by razor wire")
	check(wire.health.current<wire.health.maximum,"razor wire wears down rather than granting permanent free contact damage")
	clear_enemies(); await frames()
	var cannon := structure(8,Vector3(35,0,25))
	var a := enemy(0,Vector3(35,0,18)); a.health.setup(500)
	var b := enemy(0,Vector3(37,0,18)); b.health.setup(500)
	await frames(); cannon.fire_turret()
	var shots: Array = get_nodes_in_group("campaign_projectiles")
	check(not shots.is_empty() and shots[0].kind=="defense_shell","cannon launches a delayed physical-flight shell")
	actor.position = Vector3(35,0,17); actor.health.setup(100)
	if not shots.is_empty(): shots[0].set_physics_process(false); shots[0]._physics_process(.7)
	check(a.health.current<500 and b.health.current<500,"cannon shell deals area damage to multiple infected")
	check(actor.health.current==100 and world.core.health.current==600,"defensive shells do not damage allied survivors or the core")
	clear_enemies(); await frames()
	var shock := structure(9,Vector3(20,0,30))
	a = enemy(0,Vector3(20,0,24)); a.health.setup(500)
	b = enemy(7,Vector3(22,0,24)); b.health.setup(500)
	await frames(); shock.fire_turret()
	check(a.health.current<500 and b.health.current<500 and a.stun_left>0 and b.stun_left>0,"electric defense hits and briefly interrupts both ground and flying targets")
	world.emp_blast(shock.position)
	check(shock.disabled_left>0 and cannon.disabled_left==0,"EMP disables new electric defense based on range")
	var hp: float = a.health.current; shock.fire_turret()
	check(a.health.current==hp,"EMP prevents new electric defense from firing")
	clear_enemies(); await frames()
	world.built_this_round = 0; actor.position = Vector3(42,0,24)
	check(world.perform_action(1,"build",{"pos":Vector3(42,0,20),"piece":7,"angle":0.0}),"authoritative build command accepts a new defense index above five")
	check(world.built_this_round==1,"new defenses consume the existing shared placement quota")
	actor.position = Vector3(0,0,3)
	var core_before: Node3D = world.core.model.get_child(0)
	check(world.improve_nearby() and world.core_tier==2 and world.core.model.get_child(0)!=core_before,"core upgrade replaces its complete fortified model")
	world.airdrops.left = 600; world.airdrops.state = {}; world.airdrops.serial = 0
	world.airdrops.tick(599)
	check(world.airdrops.state.is_empty() and world.airdrops.left==1,"airdrop does not occur before ten minutes")
	world.airdrops.tick(1)
	check(world.airdrops.serial==1 and world.airdrops.left==600 and AirdropDirector.valid(world.airdrops.dump()),"ten-minute deadline generates one valid synchronized supply event")
	check(world.airdrops.coord()!=Vector2i.ZERO and SectorGenerator.distance(world.airdrops.coord())<=3,"random supply area is reachable and never replaces the fixed core")
	world.airdrops.state.coord = [1,0]
	check(step(1) and world.descriptor.risk==4 and world.descriptor.count>=48,"entering the supply sector creates a heavily infested high-risk area")
	check(world.airdrops.crate!=null and world.airdrops.crate.cargo.get_node("Parachute").visible,"crate physically descends under a visible parachute")
	check(not world.airdrops.can_open(),"descending/guarded crate cannot open early")
	world.airdrops.tick(8)
	for guard in get_nodes_in_group("airdrop_guards"): guard.set_physics_process(false)
	check(world.airdrops.active_guards().size()==1 and world.airdrops.active_guards()[0].is_boss,"landed drop starts its escort with a real boss")
	var guard: Node3D = world.airdrops.active_guards()[0]
	check(guard.health.maximum>1000,"drop leader has elite durability above an ordinary early infected")
	var crate: Node3D = world.airdrops.crate
	actor.position = crate.global_position+Vector3(1,0,0)
	check(not world.collect_ground(actor,crate) and not world.transfer_source(actor,crate),"neither automatic nor manual transfer bypasses the escort lock")
	for i in range(30): world.airdrops.spawn_guard()
	for active in world.airdrops.active_guards(): active.set_physics_process(false)
	check(world.airdrops.active_guards().size()==12,"escort materialization caps at twelve active guards")
	for i in range(2): world.airdrops.active_guards()[0].take_damage(1000000)
	var remaining: int = world.airdrops.remaining()
	check(world.field_dead==0 and remaining==world.airdrops.total_guards()-2,"escort deaths are counted once without advancing the ordinary sector population")
	check(step(3) and step(1),"supply sector supports retreat and procedural re-entry")
	check(world.airdrops.remaining()==remaining,"defeated supply guards do not respawn on a sector reroll")
	world.airdrops.spawn_guard()
	check(world.airdrops.active_guards().all(func(guard): return int(guard.get_meta("supply_index"))>=2),"re-entry starts at an undefeated guard index rather than regenerating the boss")
	var safety := 0
	while world.airdrops.remaining()>0 and safety<100:
		world.airdrops.spawn_guard()
		for active in world.airdrops.active_guards(): active.set_physics_process(false); active.take_damage(1000000)
		safety += 1
	check(world.airdrops.can_open(),"crate unlocks only when all required escort guards are defeated")
	for cache_node in world.caches: cache_node.hide(); cache_node.remove_from_group("survival_sources")
	crate = world.airdrops.crate
	actor.position = crate.global_position+Vector3(1,0,0)
	actor.bag = ItemBag.new(); world.starter_bag(actor.bag); actor.cancel_gather()
	world.tick_gather(actor,2.9)
	check(actor.bag.count("scrap")==0,"unlocked airdrop still requires three seconds of solo gathering")
	world.tick_gather(actor,.2)
	check(actor.bag.count("scrap")==40 and world.airdrops.state.contents.scrap==120,"finished airdrop gathering transfers one capped stack and preserves its remainder")
	bank_before = world.resources.scrap
	while not world.airdrops.state.contents.is_empty():
		if not world.transfer_source(actor,crate): break
	check(world.airdrops.state.collected and world.airdrops.state.contents.is_empty(),"supply event becomes collected exactly once when all contents are recovered")
	check(world.resources.scrap==bank_before,"airdrop resources also require transport back to the core")
	clear_choices(); check(step(3),"returning preserves the existing fortress after supply recovery")
	var snap: Dictionary = world.snapshot()
	check(snap.format==6 and world.valid_snapshot(JSON.parse_string(JSON.stringify(snap))),"v6 checkpoint validates ten defense types and full supply state")
	var supply_backup: Dictionary = world.airdrops.dump()
	world.airdrops.left = 1; world.built_this_round = 0; world.apply_snapshot(snap)
	check(world.airdrops.dump()==supply_backup and world.built_this_round==1,"checkpoint restores supply clock/progress and spent construction quota")
	check(get_nodes_in_group("campaign_structure").any(func(node): return node.piece_index==7 and node.visual_tier==1),"checkpoint reconstructs the new heavy wall through the fortress factory")
	var old: Dictionary = snap.duplicate(true); old.format = 5; old.erase("airdrops"); old.structures = old.structures.filter(func(entry): return entry.piece<6)
	var migrated: Dictionary = world.migrate_snapshot(old)
	check(migrated.format==6 and world.valid_snapshot(migrated) and not old.has("airdrops"),"v5 migration supplies a clean ten-minute clock without mutating the old save")
	var bad := snap.duplicate(true); bad.airdrops.state.dead.append(99999)
	check(not world.valid_snapshot(bad),"invalid escort indices reject the whole save")
	bad = snap.duplicate(true); bad.structures[0].piece = 99
	check(not world.valid_snapshot(bad),"invalid new defense index is rejected")
	world.airdrops.state.collected = false; world.airdrops.state.contents = {"wood":20}
	world.hud.show_routes()
	check(world.hud.airdrop_map_info.text.contains("AIRDROP") and not paused,"live map displays supply status without pausing the siege clock")
	world.hud.close_modal(); world.hud.show_build_catalog()
	check(world.hud.mode=="catalog" and not world.builder.piece_specs().size()<10,"scrollable construction catalog covers all ten defense types")
	world.hud.close_modal()
	var previous_serial: int = world.airdrops.serial
	world.airdrops.left = 1; world.airdrops.tick(1)
	check(world.airdrops.serial==previous_serial+1 and world.airdrops.left==600 and not world.airdrops.state.collected,"next ten-minute interval replaces the previous supply with a new random event")
	bad = world.snapshot(); bad.airdrops.left = 601
	check(not world.valid_snapshot(bad),"invalid supply timer is rejected")
	bad = world.snapshot(); bad.airdrops.state.dead = [0,0]
	check(not world.valid_snapshot(bad),"duplicate escort deaths cannot unlock a drop")
	world.queue_free(); await create_timer(.35).timeout
	print("FORTRESS RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
