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
func tower(w: Node3D,piece: int,tier: int = 1) -> StaticBody3D:
	var value := StaticBody3D.new(); value.set_script(load("res://scripts/fortress/fortress_structure.gd")); value.world = w; value.piece_index = piece; value.tier = tier; value.position = Vector3(35,0,15); value.rotation.y = .7; w.base_root.add_child(value); value.set_physics_process(false); return value
func run() -> void:
	GameSettings.volume = 0; GameSettings.music_volume = 0
	for id in ["cannon","shock","raised_turret","core"]:
		var material: StandardMaterial3D = load("res://assets/defenses/"+id+"/material.tres")
		check(material.albedo_texture.get_size()==Vector2(1024,1024) and material.normal_texture.get_size()==Vector2(1024,1024),id+" uses bounded production atlases")
		for tier in range(1,5 if id=="core" else 4):
			var scene: Node3D = load("res://assets/fortress/"+id+"_"+str(tier)+".tscn").instantiate(); root.add_child(scene)
			var count := 0
			for mesh in scene.find_children("*","MeshInstance3D",true,false):
				count += mesh.mesh.surface_get_array_index_len(0)/3
				check(mesh.get_surface_override_material(0)==material,id+" N"+str(tier)+" shares the textured material")
			check(count>1000 and count<8000,id+" N"+str(tier)+" stays within the per-structure triangle budget")
			check(scene.get_node("Base").mesh.get_aabb().position.y>=-.001,id+" N"+str(tier)+" rests on the ground")
			var fixed: Transform3D = scene.get_node("Base").global_transform
			if id!="core":
				scene.get_node("Head").rotation.y = 1.1; scene.get_node("Head/Pitch").rotation.x = -.25
				check(scene.get_node("Base").global_transform==fixed,id+" N"+str(tier)+" keeps its foundation fixed while aiming")
			scene.free()
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"; load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false); w.player.position = Vector3(0,0,15); w.waves.running = true; w.phase = "combat"
	var target: Node3D = w.make_enemy(0,Vector3(35,0,5),false,-1); target.set_physics_process(false); target.health.setup(10000)
	for tier in range(1,4):
		var raised := tower(w,11,tier); var barrier := tower(w,0); barrier.position = Vector3(35,0,12); barrier.rotation.y = 0; await frames()
		var fixed: Transform3D = raised.model.get_node("Visual/Base").global_transform; var hp: float = target.health.current
		raised.fire_turret()
		check(is_equal_approx(hp-target.health.current,float(raised.spec.values.damage)),"elevated N"+str(tier)+" fires over the real low barricade exactly once")
		check(raised.model.get_node("Visual/Base").global_transform==fixed,"elevated N"+str(tier)+" leaves legs and platform stationary")
		var pitch: Node3D = raised.head.get_node("Pitch"); var direction: Vector3 = (target.global_position+Vector3.UP*target.aim_height-pitch.global_position).normalized()
		check((-pitch.global_basis.z).dot(direction)>.999,"elevated N"+str(tier)+" aims the barrel from its actual hinge")
		check(raised.muzzle_origin().distance_to(raised.global_position+Vector3.UP*1.45)>1,"elevated N"+str(tier)+" uses its elevated muzzle")
		barrier.free(); var wall := tower(w,7); wall.position = Vector3(35,0,12); wall.rotation.y = 0; await frames(); hp = target.health.current; raised.fire_turret()
		check(target.health.current==hp,"elevated N"+str(tier)+" cannot fire through the real heavy wall")
		wall.free(); raised.free(); await frames()
	var cannon := tower(w,8)
	for tier in range(1,4):
		cannon.tier = tier; cannon.refresh_tier(); cannon.muzzle_cycle = 0; await frames(); var hp: float = target.health.current
		cannon.fire_turret(); var shells := get_nodes_in_group("campaign_projectiles").filter(func(node): return node.kind=="defense_shell")
		check(shells.size()==(1 if tier==1 else 2),"cannon fires once from each visible barrel")
		if not shells.is_empty():
			var shell: Node3D = shells[0]; shell.set_physics_process(false); cannon.muzzle_cycle = 0
			check(shell.start.is_equal_approx(cannon.muzzle_origin()),"cannon N"+str(tier)+" shell starts at the visible barrel")
			for projectile in shells:
				projectile.set_physics_process(false); projectile._physics_process(.61)
			await frames()
			check(is_equal_approx(hp-target.health.current,float(cannon.spec.values.damage)),"cannon N"+str(tier)+" explosion preserves the existing damage")
		var pose: Vector2 = cannon.aim_pose(); cannon.tier = 1 if tier==3 else tier+1; cannon.refresh_tier()
		check(cannon.aim_pose().is_equal_approx(pose),"cannon upgrade keeps the aiming pose")
	cannon.free(); await frames()
	var targets := [target]
	for i in range(2):
		var enemy: Node3D = w.make_enemy(0,Vector3(33+i*4,0,6),false,-1); enemy.set_physics_process(false); enemy.health.setup(10000); targets.append(enemy)
	var shock := tower(w,9)
	for tier in range(1,4):
		shock.tier = tier; shock.refresh_tier(); await frames(); var before := targets.map(func(enemy): return enemy.health.current)
		shock.fire_turret(); var damage := 0.0
		for i in range(targets.size()): damage += before[i]-targets[i].health.current
		check(is_equal_approx(damage,float(shock.spec.values.damage)*(1+.8+.64)),"Tesla N"+str(tier)+" preserves three-target falloff")
		check(targets.all(func(enemy): return enemy.stun_left>0),"Tesla N"+str(tier)+" still interrupts all three targets")
		check(shock.muzzle_origin().is_equal_approx(shock.head.global_position),"Tesla N"+str(tier)+" discharges from its coil")
	shock.free(); await frames()
	for piece in [8,9,11]:
		for tier in range(1,4):
			var value := tower(w,piece,tier); value.position.x = 20+piece*4; value.position.z = tier*5; value.aim_at(value.global_position+Vector3(-3,2,-10))
	var bolt: Node3D = w.defense_shell(Vector3(35,1.8,16),Vector3(35,1.8,5),10,2); bolt.set_physics_process(false)
	var half: Vector3 = bolt.start.lerp(bolt.destination,.5); bolt._physics_process(bolt.life*.5)
	check(bolt.position.is_equal_approx(half) and bolt.model.scale==Vector3(1.65,1.65,2.1),"cannon bolt is thick and follows a straight path")
	w.core_tier = 4; w.refresh_core_model(); var packet: Dictionary = w.net_state(1,true)
	w.is_client = true; w.client_scene_ready = true; w.last_scene_revision = int(packet.rev); w.apply_net_state(packet,1)
	var bolt_state: Dictionary = packet.hazards.filter(func(h): return h.get("shell16",false))[0]
	var replica_bolt: MeshInstance3D = w.client_hazards[int(bolt_state.id)]
	check(replica_bolt.mesh.get_aabb().size.is_equal_approx(Vector3(.38,.38,.84)) and (-replica_bolt.global_basis.z).dot(bolt_state.direction16)>.999,"client reproduces the thicker oriented cannon bolt")
	for entry in packet.structures:
		if int(entry.piece) not in [8,9,11]: continue
		var replica: Node3D = w.client_structures[int(entry.id)]
		check(replica.aim_pose().is_equal_approx(entry.aim16) and replica.model.get_node("Visual").get_meta("tier")==int(entry.tier),"replica reconstructs "+str(entry.piece)+" N"+str(entry.tier)+" with its aim")
	check(w.core.model.get_child(0).get_meta("tier")==4,"upgraded core uses the supplied fourth model")
	w.queue_free(); await create_timer(.4).timeout
	print("TRIPO MODELS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
