extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func posed_bounds(rig: Node3D) -> AABB:
	var skeleton: Skeleton3D = rig.get_node("Skeleton3D")
	var model: MeshInstance3D = rig.get_node("Skeleton3D/Character")
	var arrays: Array = model.mesh.surface_get_arrays(0); var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]; var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var box := AABB(); var found := false
	for i in range(positions.size()):
		var p := Vector3.ZERO
		for k in range(4):
			var b := bones[i*4+k]
			p += (skeleton.get_bone_global_pose(b)*model.skin.get_bind_pose(b)*positions[i])*weights[i*4+k]
		box = box.expand(p) if found else AABB(p,Vector3.ZERO); found = true
	return box
func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args(); GameSettings.volume = 0; GameSettings.music_volume = 0
	var container := Node3D.new(); root.add_child(container)
	var rig := VisualFactory.human(container,Color("56777d"),true)
	var second := VisualFactory.human(container,Color("56777d"),true)
	var skeleton: Skeleton3D = rig.get_node("Skeleton3D")
	var model: MeshInstance3D = rig.get_node("Skeleton3D/Character")
	check(skeleton.get_bone_count()==15 and model.skin.get_bind_count()==15,"new character has a bound fifteen-bone skeleton")
	check(model.mesh==second.get_node("Skeleton3D/Character").mesh,"players share the production character mesh")
	check(model.mesh.surface_get_array_index_len(0)/3<=16000,"character fits the sixteen-thousand-triangle budget")
	check(model.get_surface_override_material(0).albedo_texture.get_size()==Vector2(1024,1024),"character uses a 1024-pixel production atlas")
	var arrays: Array = model.mesh.surface_get_arrays(0); var valid := true
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		var total := 0.0
		for k in range(4):
			var weight: float = arrays[Mesh.ARRAY_WEIGHTS][i*4+k]; var bone: int = arrays[Mesh.ARRAY_BONES][i*4+k]
			valid = valid and weight>=0 and bone>=0 and bone<15; total += weight
		valid = valid and absf(total-1)<.002
	check(valid,"every vertex has normalized valid skin influences")
	rig.sync_pose(); var idle := posed_bounds(rig)
	check(idle.size.x<1.15 and idle.size.y>1.8,"idle arms close around the weapon instead of remaining in a T-pose")
	for side in ["L","R"]:
		var hand := skeleton.get_bone_global_pose(skeleton.find_bone("Hand"+side)).origin
		check(hand.z<-.12 and hand.y<1.3,"hand "+side+" reaches forward below the shoulder")
	var first_hand := skeleton.get_bone_global_pose(skeleton.find_bone("HandL"))
	rig.get_node("ArmL").rotation = Vector3(.5,0,.65); rig.sync_pose()
	check(not first_hand.is_equal_approx(skeleton.get_bone_global_pose(skeleton.find_bone("HandL"))),"reload controller moves the left hand")
	rig.get_node("ArmL").rotation = Vector3(1.1,0,.12)
	VisualFactory.animate_human(rig,.14,1,0,true); rig.sync_pose()
	check(absf(skeleton.get_bone_pose_rotation(9).x)>.1 and absf(skeleton.get_bone_pose_rotation(12).x)>.1,"walking rotates opposite weighted legs")
	rig.get_node("Gun").hide(); rig.sync_pose(); var unarmed := posed_bounds(rig)
	check(unarmed.size.x<1.15 and unarmed.position.y>-.1,"empty hands lower the arms without spreading them")
	rig.get_node("ArmL").rotation.x = .65; rig.sync_pose()
	check(skeleton.get_bone_global_pose(5).origin.z<-.3,"empty-handed gathering reaches forward")
	rig.get_node("ArmL").rotation.x = .4; rig.get_node("ArmR").rotation.x = .4; rig.sync_pose()
	check(skeleton.get_bone_global_pose(5).origin.z<-.3 and skeleton.get_bone_global_pose(8).origin.z<-.3,"empty-handed roll tucks both arms forward")
	rig.get_node("Gun").show()
	for item in Catalog16.data().cosmetics:
		if item.slot=="effect": continue
		Cosmetics16.decorate(rig,{item.slot:item.id}); rig.sync_pose()
		check(rig.get_node("Atelier16").get_child_count()==1 and rig.get_node("Skeleton3D/Character").mesh!=null,"new body wears "+str(item.id))
	Cosmetics16.decorate(rig,{"head":"COS-BAT-01","outfit":"COS-BAT-03","backpack":"COS-BAT-05"})
	check(rig.outfit_key=="covered_head" and rig.get_node("Atelier16").get_child_count()==3,"head, clothing and backpack combine on the fitted body")
	Cosmetics16.decorate(second,{"head":"COS-BAT-01","outfit":"COS-BAT-03","backpack":"COS-BAT-05"})
	check(model.mesh==second.get_node("Skeleton3D/Character").mesh,"fitted mesh variants are shared between players")
	Cosmetics16.decorate(rig,{})
	check(rig.outfit_key=="base" and model.mesh==load("res://assets/characters/player16/base.res"),"removing cosmetics restores the full base body")
	container.queue_free(); await process_frame; await process_frame
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"; load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	var seen := []
	for i in range(1,5):
		var car: StaticBody3D = w.base_arena.get_node("BaseCar"+str(i)); var visual: MeshInstance3D = car.get_child(0).get_node("Model")
		check(not seen.has(visual.mesh),"base car "+str(i)+" uses its distinct submitted model"); seen.append(visual.mesh)
		var box := visual.mesh.get_aabb(); check(box.size.x<2.7 and box.size.z<4.8 and box.position.y>=-.001,"base car "+str(i)+" fits its existing ground footprint")
		check(car.get_child(1).shape.size==Vector3(2.7,1.7,4.8),"base car "+str(i)+" preserves gameplay collision")
	var before: Transform3D = w.player.rig.get_node("Skeleton3D").get_bone_global_pose(5)
	w.player.weapons.reload_total = 1; w.player.weapons.reload_left = .5; w.player.animate_pose(0); w.player.rig.sync_pose()
	check(not before.is_equal_approx(w.player.rig.get_node("Skeleton3D").get_bone_global_pose(5)),"real survivor reload reaches the rig")
	w.player.roll_left = .15; w.player.animate_pose(0); w.player.rig.sync_pose()
	check(absf(w.player.rig.rotation.x)>.1 and w.player.rig.position.y>0,"real roll retains the existing above-ground tumble")
	var packet: Dictionary = w.net_state(1,true)
	w.is_client = true; w.client_scene_ready = true; w.last_scene_revision = int(packet.rev); w.apply_net_state(packet,1)
	check(w.player.rig.get_node("Skeleton3D/Character").skin!=null,"replicated player retains the rigged character")
	w.queue_free(); await create_timer(.3).timeout
	for scene_path in ["comboio/convoy","vendedor/stall"]:
		var scene: Node3D = load("res://assets/scenery/tripo16/"+scene_path+".tscn").instantiate(); root.add_child(scene)
		check(scene.get_node("Model").mesh.get_surface_count()==1,"prop "+scene_path+" uses one atlas surface")
		scene.queue_free(); await process_frame
	print("PLAYER MODELS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
