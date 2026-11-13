extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func frames(n: int = 2) -> void:
	for i in range(n): await physics_frame; await process_frame
func run() -> void:
	var mat := ClayStyle.material(Color("ad9573"),"brick")
	check(mat==ClayStyle.material(Color("ad9573"),"brick"),"clay materials are shared across objects")
	check(mat.albedo_texture.get_width()==128 and mat.normal_enabled and mat.uv1_triplanar,"128px tiled color and normal textures use world-space projection")
	check(ClayStyle.texture("wood")==ClayStyle.texture("wood"),"surface textures are generated once and reused")
	var mesh := ClayStyle.rounded_box(Vector3.ONE)
	check(mesh==ClayStyle.rounded_box(Vector3.ONE) and mesh.get_faces().size()==324,"rounded box meshes are cached and bounded to 108 triangles")
	var bounds := mesh.get_aabb()
	check(bounds.size.is_equal_approx(Vector3.ONE),"soft corners preserve the original collision dimensions")
	var holder := Node3D.new(); root.add_child(holder)
	var rig := VisualFactory.human(holder,Color("718b66"),true)
	for phase in [0.0,.5,1.2,3.0]:
		VisualFactory.animate_human(rig,phase,1,.25,true)
		var hand: Vector3 = rig.get_node("ArmR").transform*Vector3(0,-.55,0)
		check(hand.z<-.3,"armed hand points forward through walk/recoil phase %.1f" % phase)
	holder.queue_free()
	var layout := HouseLayout.populate(SectorGenerator.generate(123,Vector2i(0,-1),1,4),4)
	var duplicate_layout := HouseLayout.populate(SectorGenerator.generate(123,Vector2i(0,-1),1,4),4)
	check(layout==duplicate_layout and layout.houses.size()>=2 and layout.houses.size()<=4,"houses are deterministic for the procedural visit and remain bounded")
	check(layout.houses.all(func(h): return absf(h.pos.x)>18 and absf(h.pos.z)>18),"houses preserve the central return and exit lanes")
	var stashes: Array = layout.caches+[layout.rare_pos]
	var separation := INF
	for i in range(stashes.size()):
		for j in range(i+1,stashes.size()): separation = minf(separation,stashes[i].distance_to(stashes[j]))
	check(separation>=4,"regional interaction targets remain separated from the hidden armory")
	check(layout.blocks.all(func(block): return not layout.houses.any(func(h): return absf(block.pos.x-h.pos.x)<block.size.x/2+8 and absf(block.pos.z-h.pos.z)<block.size.z/2+9)),"generation removes solid props overlapping houses")
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false); world.set_process(false)
	world.player.invulnerable = 1000
	world.player.position = SectorGenerator.EXITS[0]; world.travel_cooldown = 0
	check(world.step_sector(0),"party enters a real generated exploration sector")
	world.field_queue.clear()
	await frames()
	var houses := get_nodes_in_group("raid_houses")
	check(houses.size()==world.descriptor.houses.size(),"each generated house becomes an enterable scene")
	var house: Node3D = houses[0]
	for h in houses: h.set_physics_process(false)
	var actor: CharacterBody3D = world.player
	actor.set_physics_process(false)
	actor.position = house.to_global(Vector3(0,0,-8))
	var path: PackedVector2Array = world.arena.route(house.position+Vector3(0,0,-8).rotated(Vector3.UP,house.rotation.y),house.position)
	check(not path.is_empty(),"navigation reaches the interior through the physical doorway")
	house._process(1)
	check(not house.roof.visible and house.cutaway<.3,"nearby local player reveals the interior with an opaque cutaway")
	check(not world.transfer_source(actor,house.crate),"supply crate stays locked before the house is cleared")
	house._physics_process(1)
	await frames()
	check(house.activated and house.active_guards().size()==1,"approaching a house materializes its first authoritative guard")
	var guard: Node3D = house.active_guards()[0]
	guard.set_physics_process(false)
	check(guard.health.maximum>float(guard.spec.values.health) and guard.field_enemy,"house guards have stronger health and belong to the field")
	guard.take_damage(100000)
	check(house.dead.size()==1 and house.remaining()==house.guard_total-1,"a real guard death advances only its house objective")
	check(world.field_dead==0,"house guardians do not complete the ordinary sector population")
	# Defeat successive actual guards without waiting through an entire play session.
	for turn in range(100):
		if house.remaining()==0: break
		house._physics_process(1)
		for infected in house.active_guards(): infected.set_physics_process(false); infected.take_damage(100000)
		await frames()
	check(house.can_open(),"defeating every generated guard unlocks the house supply crate")
	actor.position = house.crate.global_position+Vector3(0,0,-1.2)
	await frames()
	world.tick_gather(actor,.1)
	check(actor.gather_target==house.crate and actor.gather_duration==5,"house supplies require five seconds of gathering")
	world.tick_gather(actor,4.7)
	check(actor.bag.count("scrap")==0,"house resources are not granted before the collection duration")
	world.tick_gather(actor,.3)
	check(actor.bag.count("scrap")==ItemBag.stack("scrap"),"completed collection transfers one large stack into the bag")
	check(world.resources.scrap==85,"house cargo never credits the core bank remotely")
	var saved_contents: Dictionary = house.contents.duplicate()
	var saved_bag: Dictionary = actor.bag.dump()
	actor.position = house.to_global(Vector3(0,0,6.1))
	await frames()
	check(not world.transfer_source(actor,house.crate) and house.contents==saved_contents and actor.bag.dump()==saved_bag,"a wall blocks supply theft through the rear of the house")
	var state: Dictionary = world.net_state(1)
	check(state.houses.size()==houses.size() and state.houses[0].contents==saved_contents,"house progress and remaining loot are replicated separately")
	check(state.loot.all(func(item): return not item.p.is_equal_approx(house.crate.global_position)),"house supplies are not duplicated in generic loot snapshots")
	# New party members expand the remaining objective instead of copying loot.
	world.attach_peer(2,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","Friend")
	check(house.remaining()>0 and not house.can_open(),"joining the party scales house guards and re-locks pending supplies")
	world.detach_peer(2); await frames()
	check(house.can_open(),"leaving restores solo guard requirements without respawning defeated slots")
	actor.position = house.position+Vector3(35,0,35)+world.field_root.position
	house._process(1)
	check(house.roof.visible,"moving away restores the complete house roof")
	world.player.position = world.sector_offset(world.sector_coord)+SectorGenerator.EXITS[2]; world.travel_cooldown = 0
	check(world.step_sector(2),"return to the persistent base unloads exploration houses")
	await frames()
	check(get_nodes_in_group("raid_houses").is_empty(),"unloaded house scenes leave no active guard directors behind")
	world.queue_free(); await create_timer(.2).timeout
	print("CLAY RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
