extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func frames() -> void:
	await physics_frame; await physics_frame
func run() -> void:
	GameSettings.volume = 0; GameSettings.music_volume = 0
	var triangle_counts := [2410,3368,3830]
	var material: StandardMaterial3D = load("res://assets/defenses/basic_turret/material.tres")
	check(material.albedo_texture.get_width()==1024 and material.albedo_texture.get_height()==1024,"shared production atlas is limited to 1024 squared")
	for tier in range(1,4):
		var scene: Node3D = load("res://assets/fortress/turret_"+str(tier)+".tscn").instantiate(); root.add_child(scene)
		var base: MeshInstance3D = scene.get_node("Base"); var head: Node3D = scene.get_node("Head"); var gun: MeshInstance3D = head.get_node("Pitch/Gun")
		var triangles: int = base.mesh.surface_get_array_index_len(0)/3+gun.mesh.surface_get_array_index_len(0)/3
		check(triangles==triangle_counts[tier-1],"N"+str(tier)+" retains every original triangle and no geometry from another level")
		check(base.mesh.surface_get_material(0)==gun.mesh.surface_get_material(0),"N"+str(tier)+" base and head share one textured material")
		check(base.get_aabb().position.y>=-.001 and gun.get_aabb().end.y+1.45<=1.91,"N"+str(tier)+" rests on the ground and stays within the existing collision height")
		var fixed_base := base.global_transform; head.rotation.y = 1.2
		check(base.global_transform==fixed_base and gun.global_basis!=base.global_basis,"N"+str(tier)+" head rotates independently of the fixed base")
		for marker in head.get_node("Pitch").get_children():
			if marker is Marker3D: check(is_equal_approx(marker.global_position.y,1.45),"N"+str(tier)+" barrel marker matches the actual firing height")
		scene.free()
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"; load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	w.waves.running = true; w.phase = "combat"; w.player.position = Vector3(0,0,15)
	var target: Node3D = w.make_enemy(0,Vector3(35,0,5),false,-1); target.set_physics_process(false); target.health.setup(10000)
	var tower := StaticBody3D.new(); tower.set_script(load("res://scripts/fortress/fortress_structure.gd")); tower.world = w; tower.piece_index = 1; tower.position = Vector3(35,0,15); tower.rotation.y = PI/2; w.base_root.add_child(tower); tower.set_physics_process(false)
	await frames()
	for tier in range(1,4):
		tower.tier = tier; tower.refresh_tier(); tower.muzzle_cycle = 0
		var base: Node3D = tower.model.get_node("Visual/Base"); var fixed := base.global_transform
		var hp: float = target.health.current
		tower.fire_turret()
		check(is_equal_approx(hp-target.health.current,float(tower.spec.values.damage)),"N"+str(tier)+" real shot applies the original damage exactly once")
		check(base.global_transform==fixed,"N"+str(tier)+" combat never rotates or moves the base")
		var pitch: Node3D = tower.head.get_node("Pitch")
		var direction: Vector3 = (target.global_position+Vector3.UP*target.aim_height-tower.head.global_position).normalized()
		check((-pitch.global_basis.z).dot(direction)>.999,"N"+str(tier)+" barrel aims at the enemy even on a rotated foundation")
		var origin_b: Vector3 = tower.muzzle_origin(); tower.muzzle_cycle = 0; var origin_a: Vector3 = tower.muzzle_origin()
		check(origin_a.distance_to(origin_b)>.1 if tier>1 else origin_a.is_equal_approx(origin_b),"N"+str(tier)+" uses its real barrel markers without multiplying damage")
		var pose: Vector2 = tower.aim_pose(); tower.tier = 1 if tier==3 else tier+1; tower.refresh_tier()
		check(tower.aim_pose().is_equal_approx(pose),"changing level preserves the current aiming pose")
	target.position = Vector3(35,0,13.5); await frames()
	for tier in range(1,4):
		tower.tier = tier; tower.refresh_tier(); var close_hp: float = target.health.current; tower.fire_turret()
		check(target.health.current<close_hp,"N"+str(tier)+" still hits an enemy touching the barrel")
	target.position = Vector3(35,3,5); await frames(); var hp: float = target.health.current; tower.fire_turret()
	check(tower.head.get_node("Pitch").rotation.x>0 and target.health.current<hp,"head elevates and real ray hits a target above the base")
	var packet: Dictionary = w.net_state(1,true)
	var entry: Dictionary = packet.structures.filter(func(s): return int(s.piece)==1)[0]
	check(entry.aim16.is_equal_approx(tower.aim_pose()),"authoritative snapshot contains the visible yaw and elevation")
	w.is_client = true; w.client_scene_ready = true; w.last_scene_revision = int(packet.rev); w.apply_net_state(packet,1)
	var replica: Node3D = w.client_structures[int(entry.id)]
	check(replica.aim_pose().is_equal_approx(entry.aim16) and replica.model.get_node("Visual").get_meta("tier")==int(entry.tier),"client reconstructs the correct level and both aiming axes")
	entry.erase("aim16"); w.apply_net_state(packet,1)
	check(replica.aim_pose()==Vector2.ZERO,"legacy snapshots without aiming fields remain compatible")
	w.queue_free(); await create_timer(.4).timeout
	print("BASIC TURRET MODELS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
