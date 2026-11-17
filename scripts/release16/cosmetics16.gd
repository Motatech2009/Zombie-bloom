class_name Cosmetics16
extends RefCounted
static func valid(outfit: Variant,class_id: String) -> bool:
	if not outfit is Dictionary or outfit.size()>4: return false
	for slot in outfit:
		if slot not in ["head","outfit","backpack","effect"] or not outfit[slot] is String: return false
		if outfit[slot].is_empty(): continue
		var item := Catalog16.cosmetic(outfit[slot])
		if item.is_empty() or item.slot!=slot or item.class_id not in ["all",class_id]: return false
	return true
static func decorate(rig: Node3D,outfit: Dictionary,actor: Node3D = null) -> void:
	var previous := rig.get_node_or_null("Atelier16")
	if previous!=null: rig.remove_child(previous); previous.queue_free()
	for name in ["DefaultHat16","DefaultPack16"]:
		var default_part := rig.get_node_or_null(name)
		if default_part!=null: default_part.show()
	var torso := rig.get_node_or_null("Body16")
	if torso!=null: torso.scale = Vector3.ONE
	var root := Node3D.new(); root.name = "Atelier16"; rig.add_child(root)
	for slot in outfit:
		var item := Catalog16.cosmetic(str(outfit[slot]))
		if item.is_empty(): continue
		var path := "res://assets/cosmetics/tripo16/"+str(item.id)+".tscn"
		if slot!="effect" and ResourceLoader.exists(path):
			var visual: Node3D = load(path).instantiate(); root.add_child(visual)
			if item.id in ["COS-ENG-01","COS-ENG-02","COS-BAT-01","COS-ATI-02","COS-UNI-01","COS-TITAN-01"]:
				var hat := rig.get_node_or_null("DefaultHat16")
				if hat!=null: hat.hide()
			if slot=="outfit" and torso!=null: torso.scale = Vector3(.88,.97,.65)
			if slot=="backpack":
				var pack := rig.get_node_or_null("DefaultPack16")
				if pack!=null: pack.hide()
			continue
		if item.id=="COS-TITAN-01":
			titan_crown(root); continue
		var color := Color(str(item.palette)); var variant := int(str(item.id).right(2))
		match slot:
			"head":
				if item.class_id=="engineer":
					VisualFactory.cylinder(root,.36,.22,Vector3(0,1.94,0),color)
					if variant==2: VisualFactory.box(root,Vector3(.56,.5,.12),Vector3(0,1.79,-.3),Color("4b5658")); VisualFactory.box(root,Vector3(.33,.12,.03),Vector3(0,1.84,-.38),UI.LIME)
				elif item.class_id=="scout":
					if variant==1: VisualFactory.cylinder(root,.39,.5,Vector3(0,1.78,.08),color)
					else:
						for side in [-1,1]: VisualFactory.box(root,Vector3(.22,.16,.12),Vector3(side*.16,1.78,-.3),Color("c8a568"))
				elif item.class_id=="shooter":
					if variant==1: VisualFactory.box(root,Vector3(.5,.16,.42),Vector3(0,1.5,0),Color("9f4e5d"))
					else: VisualFactory.cylinder(root,.39,.3,Vector3(0,1.94,0),Color("6b7952"))
				else: VisualFactory.cylinder(root,.34,.3,Vector3(0,1.96,0),color)
			"outfit":
				VisualFactory.box(root,Vector3(.69,.67,.32),Vector3(0,1.06,.02),color)
				for side in [-1,1]:
					VisualFactory.box(root,Vector3(.18,.22,.09),Vector3(side*.2,.9,-.2),color.lightened(.15))
					if variant==4: VisualFactory.box(root,Vector3(.22,.15,.35),Vector3(side*.44,1.35,0),color.darkened(.3))
				if item.class_id=="scout": VisualFactory.box(root,Vector3(.82,.33,.43),Vector3(0,1.34,.08),color.darkened(.15))
			"backpack":
				VisualFactory.box(root,Vector3(.5,.56,.27),Vector3(0,1.08,.35),color)
				if item.class_id=="engineer": VisualFactory.box(root,Vector3(.25,.1,.08),Vector3(0,1.43,.38),Color("6a6052"))
				elif item.class_id=="shooter": VisualFactory.box(root,Vector3(.04,.6,.04),Vector3(.18,1.6,.38),Color("484f43"))
				elif item.class_id=="scout": VisualFactory.cylinder(root,.16,.3,Vector3(.3,.93,.36),Color("aa9a72"))
			"effect":
				if MobilePlatform.lightweight() or MobilePlatform.enabled(): continue
				var fx := Node3D.new(); fx.set_script(load("res://scripts/release16/cosmetic_effect16.gd")); fx.actor = actor; fx.class_id = item.class_id; root.add_child(fx)
				for i in range(3): VisualFactory.box(fx,Vector3(.045,.07,.04),Vector3(cos(i*2.1)*.55,.4+i*.3,sin(i*2.1)*.55),color)

static func titan_crown(root: Node3D) -> void:
	VisualFactory.cylinder(root,.37,.10,Vector3(0,1.93,0),Color("65533d"))
	for i in range(7):
		var angle := i*TAU/7
		var twig := VisualFactory.cylinder(root,.045,.25+(i%2)*.08,Vector3(cos(angle)*.30,2.06,sin(angle)*.30),Color("6f7849"))
		twig.rotation.z = cos(angle)*.35; twig.rotation.x = sin(angle)*.35
	VisualFactory.box(root,Vector3(.15,.18,.07),Vector3(0,1.96,-.36),Color("9fce59"))
