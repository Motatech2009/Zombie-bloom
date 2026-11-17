extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args(); GameSettings.volume = 0; GameSettings.music_volume = 0
	check(not MobilePlatform.lightweight() or ClayStyle.material(Color("56777d")).normal_texture==null,"lightweight material initializes before texture prewarming")
	var material: StandardMaterial3D = load("res://assets/cosmetics/tripo16/material.tres")
	check(material.albedo_texture.get_size()==Vector2(2048,2048),"nineteen accessories share one bounded production atlas")
	var container := Node3D.new(); root.add_child(container); var rig := VisualFactory.human(container,Color("56777d"),true); var physical := 0
	for item in Catalog16.data().cosmetics:
		if item.slot=="effect": continue
		physical += 1; Cosmetics16.decorate(rig,{item.slot:item.id})
		var accessory := rig.get_node("Atelier16/"+str(item.id))
		check(accessory.get_meta("cosmetic_id")==item.id and accessory.get_meta("slot")==item.slot,"correct imported asset equips: "+str(item.id))
		var mesh: MeshInstance3D = accessory.get_node("Accessory")
		check(mesh.get_surface_override_material(0)==material,"shared atlas material: "+str(item.id))
		check(mesh.mesh.surface_get_array_index_len(0)/3<1200,"bounded accessory geometry: "+str(item.id))
		check(accessory.find_children("*","CollisionObject3D",true,false).is_empty(),"cosmetic adds no collision or defense: "+str(item.id))
	check(physical==19,"all nineteen physical catalog items are imported")
	var outfit := {"head":"COS-ENG-01","outfit":"COS-ENG-04","backpack":"COS-ENG-05"}
	Cosmetics16.decorate(rig,outfit)
	check(not rig.get_node("DefaultHat16").visible and not rig.get_node("DefaultPack16").visible,"equipped helmet and bag replace the default visible parts")
	var second := VisualFactory.human(container,Color("56777d"),true); Cosmetics16.decorate(second,outfit)
	check(rig.get_node("Atelier16/COS-ENG-01/Accessory").mesh==second.get_node("Atelier16/COS-ENG-01/Accessory").mesh,"multiple players reuse the same imported mesh")
	Cosmetics16.decorate(rig,{})
	check(rig.get_node("DefaultHat16").visible and rig.get_node("DefaultPack16").visible and rig.get_node("Body16").scale==Vector3.ONE,"removing cosmetics restores the complete default appearance")
	Cosmetics16.decorate(rig,{"head":"COS-TITAN-01"})
	check(rig.get_children().filter(func(node): return node.name=="Atelier16").size()==1 and rig.get_node("Atelier16").get_child_count()==1,"repeated appearance changes leave a single active atelier")
	check(Catalog16.cosmetic("COS-TITAN-01").get("unlock","")=="titan16" and int(Catalog16.cosmetic("COS-TITAN-01").price)==0,"Titan crown remains an exclusive trophy")
	container.queue_free(); await process_frame
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"; load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w; w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	var before := {"hp":w.player.health.maximum,"bag":w.player.bag.capacity_slots,"items":w.player.bag.slots.duplicate(true),"gun":w.player.weapons.hand_weapon}
	w.player.outfit16 = outfit; w.v15.decorate(w.player)
	check(w.player.health.maximum==before.hp and w.player.bag.capacity_slots==before.bag and w.player.bag.slots==before.items and w.player.weapons.hand_weapon==before.gun,"wearing the real kit preserves health, inventory, capacity and weapon")
	var state: Dictionary = w.net_state(1,true); check(state.players[0].outfit16==outfit,"network snapshot includes the equipped cosmetic IDs")
	w.is_client = true; w.client_scene_ready = true; w.last_scene_revision = int(state.rev); w.apply_net_state(state,1)
	check(w.player.rig.get_node("Atelier16").get_child_count()==3 and w.player.rig.get_node("Atelier16/COS-ENG-05").get_meta("cosmetic_id")=="COS-ENG-05","client reconstructs the imported outfit from replicated IDs")
	w.queue_free(); await create_timer(.4).timeout
	print("COSMETIC MODELS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
