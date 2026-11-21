class_name ModelFactory
extends RefCounted
const STEEL := Color("3c535d")
const DARK := Color("142831")
const WOOD := Color("aa7950")
const GOLD := Color("e8b867")
const CYAN := Color("6ae0e0")

static func part(root: Node3D,size: Vector3,pos: Vector3,color: Color) -> MeshInstance3D:
	return VisualFactory.box(root,size,pos,color)

static func barrel(root: Node3D,radius: float,length: float,pos: Vector3,color: Color) -> Node3D:
	var node := VisualFactory.cylinder(root,radius,length,pos,color)
	node.rotation.x = PI/2
	return node

static func weapon(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_"+ItemBag.WEAPON_IDS[index]
	part(root,Vector3(.14,.34,.18),Vector3(0,-.17,.08),WOOD if index in [1,5,6] else DARK).rotation.x = -.18
	part(root,Vector3(.21,.18,.52),Vector3(0,.02,-.13),STEEL)
	var length: float = [.35,.85,1.15,.52,.95,.55,1.65,1.25,.65][index]
	if index==4:
		barrel(root,.23,1.15,Vector3(0,.04,-.35),Color("738765"))
		barrel(root,.18,.08,Vector3(0,.04,-.96),DARK)
		part(root,Vector3(.12,.15,.2),Vector3(.26,.12,-.4),GOLD)
	elif index==8:
		part(root,Vector3(.4,.24,.65),Vector3(0,.04,-.25),DARK)
		for z in [-.25,-.43,-.61]:
			barrel(root,.21,.07,Vector3(0,.04,z),CYAN)
		for x in [-.22,.22]: part(root,Vector3(.08,.09,.65),Vector3(x,.04,-.6),STEEL)
		part(root,Vector3(.15,.32,.28),Vector3(0,-.23,-.18),GOLD)
	else:
		barrel(root,.065 if index!=7 else .09,length,Vector3(0,.03,-length/2-.15),DARK)
		if index in [1,2,6,7]:
			part(root,Vector3(.22,.18,.43),Vector3(0,0,.35),WOOD if index in [1,6] else STEEL)
			part(root,Vector3(.25,.25,.09),Vector3(0,0,.6),DARK)
		if index==1:
			barrel(root,.07,.8,Vector3(.14,.03,-.56),STEEL)
			part(root,Vector3(.3,.22,.35),Vector3(0,-.02,-.45),WOOD)
		if index==5:
			var drum := VisualFactory.cylinder(root,.18,.27,Vector3(0,.02,-.15),STEEL)
			drum.rotation.z = PI/2
			for x in [-.15,.15]: part(root,Vector3(.02,.07,.14),Vector3(x,.04,-.16),GOLD)
		if index in [2,3,7]:
			part(root,Vector3(.15,.33,.26),Vector3(0,-.23,-.18),Color("596d68"))
			part(root,Vector3(.13,.06,.42),Vector3(0,.15,-.14),GOLD)
		if index==6:
			barrel(root,.1,.5,Vector3(0,.26,-.22),STEEL)
			barrel(root,.12,.06,Vector3(0,.26,-.5),CYAN)
			for z in [-.08,-.35]: part(root,Vector3(.08,.2,.08),Vector3(0,.15,z),DARK)
		if index==7:
			part(root,Vector3(.36,.3,.35),Vector3(.18,-.22,-.17),WOOD)
			for z in [-.05,-.18,-.31]: part(root,Vector3(.35,.05,.05),Vector3(.25,.04,z),GOLD)
			for x in [-.13,.13]: part(root,Vector3(.06,.36,.06),Vector3(x,-.2,-1.1),STEEL).rotation.z = x*2
		part(root,Vector3(.05,.08,.06),Vector3(0,.12,-length-.1),GOLD)
	return root

static func infected(kind: int,color: Color) -> Node3D:
	var holder := Node3D.new()
	var rig := VisualFactory.human(holder,color,false)
	holder.remove_child(rig); holder.free()
	rig.name = "Infected_"+str(kind)
	# Torn vest, jaw and asymmetrical silhouette remain legible from the game camera.
	part(rig,Vector3(.4,.42,.08),Vector3(-.1,1.08,-.23),color.darkened(.35))
	part(rig,Vector3(.3,.14,.12),Vector3(0,1.48,-.22),Color("a18a72"))
	for x in [-.08,.08]: part(rig,Vector3(.05,.075,.04),Vector3(x,1.51,-.29),Color("e5dab4"))
	if kind in [2,4,8,12]:
		for x in [-.48,.48]:
			part(rig,Vector3(.36,.28,.52),Vector3(x,1.36,0),Color("535b5b"))
		part(rig,Vector3(.62,.7,.14),Vector3(0,1.12,-.3),Color("6a6260"))
	if kind==1:
		rig.get_node("ArmL").scale = Vector3(.75,1.3,.75)
		part(rig,Vector3(.3,.3,.3),Vector3(.16,1.82,0),Color("c77e64"))
	if kind==3:
		part(rig,Vector3(.65,.22,.45),Vector3(0,1.82,0),STEEL)
		part(rig,Vector3(.42,.6,.12),Vector3(0,1.1,-.31),STEEL)
	if kind in [5,9,13]:
		for x in [-.23,.23]:
			VisualFactory.cylinder(rig,.2,.72,Vector3(x,1.14,.38),Color("82b562") if kind==5 else Color("db8953") if kind==9 else Color("81d4ee"),true)
		part(rig,Vector3(.32,.23,.25),Vector3(0,1.58,-.25),DARK)
	if kind==10:
		for x in [-.27,.27]: barrel(rig,.17,.25,Vector3(x,1.72,-.28),Color("c994c7"))
		part(rig,Vector3(.42,.23,.32),Vector3(0,1.93,0),Color("776080"))
	if kind==11:
		for x in [-.4,0,.4]:
			var crystal := part(rig,Vector3(.18,.65,.18),Vector3(x,1.38,.35),Color("7dd7a6"))
			crystal.rotation.z = x
	if kind==12:
		for x in [-.28,.28]:
			var horn := CylinderMesh.new(); horn.top_radius = 0; horn.bottom_radius = .13; horn.height = .65; horn.radial_segments = 5
			VisualFactory.mesh_node(rig,horn,Vector3(x,1.97,-.1),GOLD,false).rotation.x = -.6
		part(rig,Vector3(.72,.22,.2),Vector3(0,1.2,-.45),Color("ab634b"))
	if kind==14:
		part(rig,Vector3(.7,.75,.35),Vector3(0,1.2,.4),DARK)
		for y in [.98,1.2,1.42]: VisualFactory.ring(rig,.36,Vector3(0,y,.4),CYAN)
		for x in [-.32,.32]: part(rig,Vector3(.06,.75,.06),Vector3(x,1.9,.4),STEEL)
		part(rig,Vector3(.42,.13,.1),Vector3(0,1.7,-.25),CYAN)
	return rig

static func item(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Item_"+id
	match id:
		"wood":
			for x in [-.16,.16]: barrel(root,.14,.7,Vector3(x,.16,0),WOOD)
			part(root,Vector3(.65,.06,.1),Vector3(0,.3,0),GOLD)
		"scrap":
			for i in range(3): part(root,Vector3(.5,.09,.3),Vector3(i*.06,.09+i*.1,0),STEEL).rotation.y = i*.6
		"parts":
			part(root,Vector3(.65,.1,.5),Vector3(0,.09,0),Color("376f60"))
			part(root,Vector3(.24,.12,.25),Vector3(0,.18,0),DARK)
			for x in [-.25,.25]:
				for z in [-.12,.12]: part(root,Vector3(.08,.08,.08),Vector3(x,.16,z),GOLD)
		"medkit":
			part(root,Vector3(.55,.4,.34),Vector3(0,.22,0),Color("b86759"))
			part(root,Vector3(.3,.07,.07),Vector3(0,.46,0),DARK)
			part(root,Vector3(.3,.09,.03),Vector3(0,.23,-.185),Color("f1e8ce"))
			part(root,Vector3(.09,.27,.03),Vector3(0,.23,-.185),Color("f1e8ce"))
		"grenade":
			VisualFactory.cylinder(root,.18,.35,Vector3(0,.22,0),Color("7b9560"))
			VisualFactory.cylinder(root,.07,.1,Vector3(0,.44,0),STEEL)
			part(root,Vector3(.08,.05,.3),Vector3(0,.49,-.06),GOLD)
		"rocket":
			barrel(root,.1,.7,Vector3(0,.14,0),Color("8d9c76"))
			part(root,Vector3(.35,.05,.2),Vector3(0,.14,.25),GOLD)
		"cells":
			part(root,Vector3(.35,.5,.25),Vector3(0,.26,0),DARK)
			part(root,Vector3(.2,.35,.04),Vector3(0,.26,-.15),CYAN)
			part(root,Vector3(.17,.05,.12),Vector3(0,.53,0),GOLD)
		_:
			part(root,Vector3(.55,.24,.38),Vector3(0,.14,0),Color("8d6a49"))
			for x in [-.16,0,.16]: VisualFactory.cylinder(root,.055,.23,Vector3(x,.3,-.04),Color("d89677") if id=="shell" else GOLD)
	return root
