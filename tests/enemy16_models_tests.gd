extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func weights_valid(mesh: MeshInstance3D,sk: Skeleton3D) -> bool:
	var data := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = data[Mesh.ARRAY_BONES]; var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
	if bones.size()!=data[Mesh.ARRAY_VERTEX].size()*4 or weights.size()!=bones.size(): return false
	for i in range(data[Mesh.ARRAY_VERTEX].size()):
		var total := 0.0
		for k in range(4):
			if bones[i*4+k]<0 or bones[i*4+k]>=sk.get_bone_count() or not is_finite(weights[i*4+k]) or weights[i*4+k]<0: return false
			total += weights[i*4+k]
		if absf(total-1)>.001: return false
	return true
func skinned_soles(mesh: MeshInstance3D, sk: Skeleton3D) -> Array[Vector3]:
	var matrices: Array[Transform3D] = []
	for i in range(mesh.skin.get_bind_count()):
		matrices.append(sk.get_bone_global_pose(mesh.skin.get_bind_bone(i)) * mesh.skin.get_bind_pose(i))
	var data := mesh.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = data[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
	var soles: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var counts := [0, 0]
	for i in range(points.size()):
		var p := points[i]
		if p.y > .07 or absf(p.x) < .10:
			continue
		var side := 0 if p.x < 0.0 else 1
		for k in range(i * 4, i * 4 + 4):
			soles[side] += matrices[bones[k]] * p * weights[k]
		counts[side] += 1
	for i in range(2):
		soles[i] /= maxi(1, counts[i])
	return soles

func has_joined_soles(mesh: MeshInstance3D, sk: Skeleton3D) -> bool:
	var data := mesh.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = data[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
	var left := [sk.find_bone("LegL"), sk.find_bone("ShinL"), sk.find_bone("FootL")]
	var right := [sk.find_bone("LegR"), sk.find_bone("ShinR"), sk.find_bone("FootR")]
	var sides := PackedByteArray()
	sides.resize(points.size())
	for i in range(points.size()):
		if points[i].y > .24:
			continue
		for k in range(i * 4, i * 4 + 4):
			if weights[k] < .1:
				continue
			if bones[k] in left:
				sides[i] |= 1
			elif bones[k] in right:
				sides[i] |= 2
	for face in range(0, indices.size(), 3):
		if (sides[indices[face]] | sides[indices[face + 1]] | sides[indices[face + 2]]) == 3:
			return true
	return false

func check_leg_deformation(enemy: Node3D, rig: Node3D, mesh: MeshInstance3D, sk: Skeleton3D) -> void:
	var id: String = enemy.spec.id
	check(not has_joined_soles(mesh, sk), id + " has no triangle joining the lower legs")
	var left := rig.get_node("LegL") as Node3D
	var right := rig.get_node("LegR") as Node3D
	left.rotation.x = 0.0
	right.rotation.x = 0.0
	rig.sync_pose()
	var rest := skinned_soles(mesh, sk)
	check(rest[0].x < -.10 and rest[1].x > .10, id + " has two separately weighted soles")
	var before := sk.get_bone_pose_rotation(sk.find_bone("ArmL"))
	for direction in [1.0, -1.0]:
		left.rotation.x = .65 * direction
		right.rotation.x = -.65 * direction
		rig.sync_pose()
		var stride := skinned_soles(mesh, sk)
		check((stride[0].z - rest[0].z) * direction < -.08 and
			(stride[1].z - rest[1].z) * direction > .08, id + " alternates the visible feet in opposite directions")
		check(stride[0].y > -.06 and stride[1].y > -.06 and
			stride[0].distance_to(rest[0]) < .58 and stride[1].distance_to(rest[1]) < .58,
			id + " stride keeps feet above ground and within reach")
		check(sk.get_bone_pose_rotation(sk.find_bone("ArmL")).is_equal_approx(before),
			id + " leg motion leaves the arm pose independent")
	enemy.animate_ground(.15, 1.0, id == "charger")
	rig.sync_pose()
	check(rig.running == (id == "charger"), id + " selects the expected walk or charge stride")
	enemy.animate_ground(.15, 0.0)
	rig.sync_pose()
	check(sk.get_bone_pose_rotation(sk.find_bone("FootL")).is_equal_approx(Quaternion.IDENTITY) and
		sk.get_bone_pose_rotation(sk.find_bone("ShinR")).is_equal_approx(Quaternion.IDENTITY),
		id + " returns the knees and ankles to their resting pose")

func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args(); GameSettings.volume = 0; GameSettings.music_volume = 0
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false; load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	var rows := []
	for kind in range(20):
		if kind!=8: rows.append([kind,0])
	for stage in range(1,8): rows.append([8,stage])
	rows.append([20,0])
	var materials := {}; var models := {}; var actors := []
	for row in rows:
		w.restoring_boss_stage = row[1]
		var enemy: Node3D = w.make_enemy(row[0],Vector3(20,0,20),false,-1); enemy.set_physics_process(false); enemy.set_process(false); actors.append(enemy)
		w.restoring_boss_stage = 0
		var id: String = enemy.spec.id; var rig: Node3D = enemy.rig
		check(rig.get_meta("imported_enemy16",false) and rig.get_meta("model_id16","")==id,"actual gameplay selects supplied model "+id)
		if not rig.has_node("Skeleton3D/Character"): continue
		var mesh: MeshInstance3D = rig.get_node("Skeleton3D/Character"); var sk: Skeleton3D = rig.get_node("Skeleton3D")
		check(weights_valid(mesh,sk) and mesh.skin.get_bind_count()==sk.get_bone_count(),"normalized skin and complete bind poses for "+id)
		check(mesh.mesh.surface_get_array_index_len(0)/3<=(10000 if enemy.is_boss else 3000),"triangle budget is respected by "+id)
		if not enemy.is_boss:
			var source: String = rig.get_meta("separated_source16", "")
			var expected_sources := {"walker": "errante", "armored": "blindado", "charger": "investidor", "parasite": "cao_infectado"}
			check(not source.is_empty() and source == expected_sources.get(id, source), id + " selects its separated GLB bake")
		if not enemy.is_boss and id in ["walker", "armored", "charger"]:
			check_leg_deformation(enemy, rig, mesh, sk)
		var material: StandardMaterial3D = mesh.get_surface_override_material(0)
		check(material.albedo_texture.get_width()==2048 and material.normal_texture.get_width()==2048,"shared 2K clay atlas is present for "+id)
		check(material.normal_enabled==not MobilePlatform.lightweight() and not material.uv1_triplanar,"material quality matches desktop/touch mode for "+id)
		var kit := "bosses" if enemy.is_boss else "zombies"
		if materials.has(kit): check(material==materials[kit],"atlas material is shared within "+kit+" for "+id)
		else: materials[kit] = material
		var hp: float = enemy.health.maximum; var damage: float = enemy.spec.values.damage
		var profile: String = rig.get_meta("profile16"); rig.show()
		if profile=="human" or id=="parasite": VisualFactory.animate_human(rig,.15,1,0,false)
		elif profile=="dog": rig.get_node("LegFL").rotation.x = .6
		else: rig.get_node("WingL").rotation.z = .45
		rig.sync_pose()
		check(sk.get_bone_pose_rotation(3).angle_to(Quaternion.IDENTITY)>.1,"the supplied mesh articulates during "+profile+" animation for "+id)
		check(enemy.health.maximum==hp and enemy.spec.values.damage==damage and rig.find_children("*","CollisionObject3D",true,false).is_empty(),"model animation adds no collision or stat changes for "+id)
		var shape: CapsuleShape3D = enemy.get_children().filter(func(child): return child is CollisionShape3D)[0].shape
		var expected: float = .9 if id=="hound" else 1 if id=="flyer" else 1.8*float(enemy.spec.values.scale)
		check(is_equal_approx(shape.height,expected),"gameplay hitbox is preserved for "+id)
		if id=="parasite": check(rig.get_meta("source_model_id16")=="hound" and rig.scale.is_equal_approx(Vector3.ONE*.45),"parasite uses the supplied small quadruped without a fabricated separate source")
		if id=="titan16": check(is_instance_valid(enemy.heart) and enemy.heart.get_parent()==rig,"Titan retains its exposed-heart presentation")
		models[kit+"/"+id] = true
	check(models.size()==27 and materials.size()==2,"nineteen normal types and eight bosses use two shared atlas materials")
	var parasite: Node3D = actors.filter(func(e): return e.enemy_kind==17)[0]
	parasite.enemy_kind = 2; parasite.spec = CampaignData.enemy_spec(2).duplicate(true); parasite.refresh_quality()
	check(parasite.rig.get_meta("model_id16")=="brute" and parasite.rig.has_node("Skeleton3D/Character"),"parasite transformation rebuilds the supplied skinned brute")
	w.queue_free(); await process_frame; await process_frame; await create_timer(.25).timeout
	print("ENEMY MODELS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
