extends RefCounted
## Rank rewards reuse the supplied clay meshes with their own insignia and shared tint.
static var materials: Dictionary = {}
const MODELS := ["COS-UNI-01","COS-ATI-02","COS-ENG-01","COS-BAT-05","COS-ENG-05","COS-ATI-05","COS-BAT-05"]
static func decorate(rig: Node3D,tier: int) -> void:
	if tier<1 or tier>10: return
	var root := Node3D.new(); root.name = "EloCosmetic"; root.set_meta("rank_tier",tier); rig.add_child(root)
	var color := Color("82979f") if tier<4 else Color("e9ae4e") if tier<7 else Color("ae79d4") if tier<10 else Color("efb8d2")
	if tier<=7:
		var visual: Node3D = load("res://assets/cosmetics/tripo16/"+str(MODELS[tier-1])+".tscn").instantiate(); root.add_child(visual)
		for part in visual.find_children("*","MeshInstance3D",true,false):
			var key := str(tier)+":"+str(part.mesh.get_instance_id())
			if not materials.has(key):
				var mat: StandardMaterial3D = part.get_surface_override_material(0).duplicate()
				mat.albedo_color = color.lightened(.65); materials[key] = mat
			part.set_surface_override_material(0,materials[key])
		var base := rig.get_node_or_null("DefaultHat16" if tier<=3 else "DefaultPack16")
		if base!=null: base.hide()
		var badge := Vector3(0,1.93,-.28) if tier<=3 else Vector3(0,1.20,.51)
		var seal := VisualFactory.cylinder(root,.085 if tier<=3 else .12,.045,badge,color); seal.rotation.x = PI/2
		for i in range(1+(tier-1)%3): VisualFactory.box(root,Vector3(.025,.065,.018),badge+Vector3((i-(float((tier-1)%3))*.5)*.045,0,-.028 if tier<=3 else .028),Color("ede4bf"))
	else:
		var seal := VisualFactory.cylinder(root,.22,.08,Vector3(0,1.64,.74),color); seal.rotation.x = PI/2
		VisualFactory.box(root,Vector3(.21,.21,.10),Vector3(0,1.64,.80),color.lightened(.3)).rotation.z = PI/4
		for i in range(tier-6):
			var angle := i*TAU/float(tier-6)
			var pos := Vector3(cos(angle)*.31,1.64+sin(angle)*.31,.74)
			var gem := VisualFactory.box(root,Vector3(.10,.14,.10),pos,color,true); gem.rotation.z = PI/4
			var tween := root.create_tween().set_loops()
			tween.tween_property(gem,"position:y",pos.y+.045,.8).set_trans(Tween.TRANS_SINE)
			tween.tween_property(gem,"position:y",pos.y-.045,.8).set_trans(Tween.TRANS_SINE)
