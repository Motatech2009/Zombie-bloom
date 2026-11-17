extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func run() -> void:
	check(ProjectSettings.get_setting("application/config/version")=="1.6.0-rc.6","actual exported package reports RC6")
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
	holder.queue_free(); await process_frame; await process_frame
	print("EXPORTED MODELS RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
