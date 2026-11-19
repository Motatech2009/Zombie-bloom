extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func run() -> void:
	check(ProjectSettings.get_setting("application/config/version")=="1.7.4","actual exported package reports 1.7.4")
	check(FortressData.BUILD_LIMITS == {"turret": 12, "cannon": 5, "raised_turret": 5, "shock": 5, "wire": 30, "spikes": 30},
		"export contains the RC11 construction limits")
	check(FortressData.BUILD_LIMIT_UNLOCK_WAVE == 20, "export unlocks the construction limits after horde twenty")
	check(root.get_node("Coop").PROTOCOL_VERSION == 29, "export uses the 1.7 cooperative protocol")
	check(root.get_node("Meta16").local_economy, "export enables the local Brotos wallet")
	for id in ["cannon","shock","raised_turret","core"]:
		for tier in range(1,5 if id=="core" else 4):
			var scene: Node3D = load("res://assets/fortress/"+id+"_"+str(tier)+".tscn").instantiate()
			check(scene.get_meta("tier")==tier and scene.get_node("Base").mesh!=null,"export contains "+id+" N"+str(tier)); scene.free()
	for item in Catalog16.data().cosmetics:
		if item.slot=="effect": continue
		var visual: Node3D = load("res://assets/cosmetics/tripo16/"+str(item.id)+".tscn").instantiate()
		check(visual.get_meta("cosmetic_id")==item.id and visual.get_node("Accessory").get_surface_override_material(0).albedo_texture!=null,"export contains textured "+str(item.id)); visual.free()
	var holder := Node3D.new(); root.add_child(holder); var rig := VisualFactory.human(holder,Color("56777d"),true)
	Cosmetics16.decorate(rig,{"head":"COS-ENG-01","outfit":"COS-ENG-03","backpack":"COS-ENG-05"})
	check(rig.get_node("Atelier16").get_child_count()==3 and not rig.get_node("DefaultPack16").visible,"export equips the imported kit")
	var character: MeshInstance3D = rig.get_node("Skeleton3D/Character")
	check(character.skin.get_bind_count()==15 and character.mesh.surface_get_array_index_len(0)/3<=16000,"export contains the weighted production player")
	rig.sync_pose(); check(rig.get_node("Skeleton3D").get_bone_global_pose(5).origin.z<-.1,"exported player holds arms forward")
	for path in ["carros/car_1","carros/car_2","carros/car_3","carros/car_4","comboio/convoy","vendedor/stall"]:
		var prop: Node3D = load("res://assets/scenery/tripo16/"+path+".tscn").instantiate(); holder.add_child(prop)
		check(prop.get_node("Model").get_surface_override_material(0).albedo_texture!=null,"export contains textured "+path)
	for tier in range(1,11):
		rig.set_rank16(tier); Cosmetics16.decorate(rig,{})
		var previous := rig.get_node_or_null("EloCosmetic")
		if previous!=null: rig.remove_child(previous); previous.queue_free()
		preload("res://scripts/presentation/rank_cosmetics16.gd").decorate(rig,tier)
		check(rig.get_node("EloCosmetic").get_meta("rank_tier")==tier,"export contains the 3D rank "+str(tier))
	for kit in ["zombies","bosses"]:
		var ids := ["walker","runner","brute","armored","demolisher","spitter","hound","flyer","alpha_legacy","burster","screamer","mender","charger","cryo","saboteur","lobber","cleaver","shieldbearer","bridge"] if kit=="zombies" else ["mauler","mortar","broodmother","flyer","hound","potter","hive","titan16"]
		for id in ids:
			var visual: Node3D = load("res://assets/enemies/tripo16/"+kit+"/"+id+".tscn").instantiate(); holder.add_child(visual)
			var model: MeshInstance3D = visual.get_node("Skeleton3D/Character")
			check(visual.get_meta("imported_enemy16",false) and model.skin.get_bind_count()>0 and model.get_surface_override_material(0).albedo_texture.get_width()==(512 if kit=="zombies" and id=="runner" else 2048),"export contains supplied skinned "+kit+"/"+id)
			if kit == "zombies":
				check(visual.has_meta("separated_source16"), "export contains the separated GLB bake for " + id)
	holder.queue_free(); await process_frame; await process_frame
	print("EXPORTED MODELS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
