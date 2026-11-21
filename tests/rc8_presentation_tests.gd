extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func chest_intersections(rig: Node3D) -> int:
	var mesh: MeshInstance3D = rig.get_node("Skeleton3D/Character")
	var sk: Skeleton3D = rig.get_node("Skeleton3D"); var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]; var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]; var result := 0
	for i in range(points.size()):
		if points[i].x<.65: continue
		var p := Vector3.ZERO; var right := 0.0
		for k in range(4):
			var bone := bones[i*4+k]; var weight := weights[i*4+k]
			if bone in [6,7,8]: right += weight
			p += (sk.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bone)*points[i])*weight
		if right>.75 and absf(p.x)<.26 and p.y>.85 and p.y<1.25 and p.z>-.21 and p.z<.18: result += 1
	return result
func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args(); GameSettings.volume = 0; GameSettings.music_volume = 0
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false; load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	var a: Node3D = w.player; var rig: Node3D = a.rig; var sk: Skeleton3D = rig.get_node("Skeleton3D")
	var hp: float = a.health.maximum; var capacity: int = a.bag.capacity_slots; var bag: Dictionary = a.bag.dump()
	for tier in range(1,11):
		a.cosmetic = tier; a.outfit16 = {}; w.v15.decorate(a)
		var reward: Node3D = rig.get_node("EloCosmetic"); var meshes := reward.find_children("*","MeshInstance3D",true,false)
		check(reward.get_meta("rank_tier")==tier and not meshes.is_empty(),"rank "+str(tier)+" equips visible 3D geometry")
		if tier<=7: check(meshes.any(func(m): return m.mesh is ArrayMesh and m.mesh.surface_get_array_index_len(0)>300),"rank "+str(tier)+" uses a supplied textured mesh")
		check(reward.find_children("*","CollisionObject3D",true,false).is_empty(),"rank "+str(tier)+" adds no gameplay collision")
		if tier<=3: check(rig.outfit_key=="base_head" and not rig.get_node("DefaultHat16").visible,"rank headgear fits the reduced head")
	check(a.health.maximum==hp and a.bag.capacity_slots==capacity and a.bag.dump()==bag,"rank appearance preserves player attributes and inventory")
	a.cosmetic = 1; a.outfit16 = {"head":"COS-ENG-01"}; w.v15.decorate(a)
	check(not rig.has_node("EloCosmetic") and rig.get_node("Atelier16").get_child_count()==1,"catalog headgear takes precedence over rank headgear")
	a.cosmetic = 4; a.outfit16 = {"backpack":"COS-ENG-05"}; w.v15.decorate(a)
	check(not rig.has_node("EloCosmetic"),"catalog backpack takes precedence over rank backpack")
	a.cosmetic = 8; a.outfit16 = {"effect":"COS-ENG-06"}; w.v15.decorate(a)
	check(not rig.has_node("EloCosmetic"),"catalog effect takes precedence over rank effect")
	a.cosmetic = 0; a.outfit16 = {}; w.v15.decorate(a); a.animate_pose(0); rig.sync_pose()
	check(not rig.has_node("EloCosmetic") and rig.outfit_key=="base","removing rank gear restores the original body")
	check(chest_intersections(rig)==0,"right forearm stays outside the inner torso")
	check(sk.get_bone_global_pose(6).basis.z.dot(sk.get_bone_global_pose(7).basis.z)>.999,"right arm segments share a consistent elbow plane")
	for item in Catalog16.data().cosmetics:
		if item.slot!="outfit": continue
		a.outfit16 = {"outfit":item.id}; w.v15.decorate(a); a.animate_pose(0); rig.sync_pose()
		check(chest_intersections(rig)==0,"right arm clears the torso with "+str(item.id))
		a.weapons.reload_total = 1; a.weapons.reload_left = .5; a.animate_pose(0); rig.sync_pose()
		check(chest_intersections(rig)==0,"right arm stays outside the body while reloading "+str(item.id)); a.weapons.reload_left = 0
	for id in ItemBag.WEAPON_IDS+["bat"]:
		var fresh := ItemBag.new(); fresh.add(id,1); a.bag.restore(fresh.dump()); a.weapons.sync_hand()
		a.outfit16 = {"outfit":"COS-ENG-04"}; w.v15.decorate(a); a.animate_pose(0); rig.sync_pose()
		var clears := chest_intersections(rig)==0
		if id=="bat":
			for progress in [.32,.16,.01]:
				a.weapons.swing_left = progress; a.animate_pose(0); rig.sync_pose(); clears = clears and chest_intersections(rig)==0
		check(clears,"right arm stays outside armor while holding "+str(id))
	w.queue_free(); await process_frame; await process_frame; await create_timer(.2).timeout
	print("RC8 PRESENTATION RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
