class_name FortressModels
extends RefCounted
static var materials: Dictionary = {}
static func skin(color: Color,metal: bool = false) -> StandardMaterial3D:
	var key := color.to_html()+str(metal)
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color; mat.metallic = .72 if metal else .02
		mat.roughness = .37 if metal else .93
		materials[key] = mat
	return materials[key]
static func box(root: Node3D,size: Vector3,pos: Vector3,color: Color,metal: bool = false) -> MeshInstance3D:
	var node := VisualFactory.box(root,size,pos,color)
	node.material_override = skin(color,metal)
	return node
static func post(root: Node3D,radius: float,height: float,pos: Vector3,color: Color,metal: bool = false) -> MeshInstance3D:
	var node := VisualFactory.cylinder(root,radius,height,pos,color)
	node.material_override = skin(color,metal)
	return node
static func braces(root: Node3D,width: float,height: float,color: Color) -> void:
	for side in [-1,1]:
		var beam := box(root,Vector3(.13,height*1.05,.12),Vector3(0,height/2,-.39),color,true)
		beam.rotation.z = side*atan(width/height)*.7
static func bolts(root: Node3D,width: float,height: float,z: float) -> void:
	for x in [-width/2,width/2]:
		for y in [.35,height-.25]: post(root,.065,.045,Vector3(x,y,z),Color("e0c58c"),true).rotation.x = PI/2

static func defense(piece: int,tier: int) -> Node3D:
	var root := Node3D.new()
	var data: Dictionary = FortressData.pieces()[piece]
	root.name = data.id+"_N"+str(tier)
	root.set_meta("tier",tier); root.set_meta("material",FortressData.MATERIALS[tier-1])
	var body: Color = [Color("a47b52"),Color("6d8792"),Color("929a91")][tier-1]
	var trim: Color = [Color("594a3b"),Color("324d5c"),Color("354248")][tier-1]
	var metal := tier>=2
	var width: float = data.size.x
	var height: float = data.size.y
	if data.id in ["barricade","wall","bastion","gate"]:
		for x in [-width/2+.15,width/2-.15]: box(root,Vector3(.32,height,.65),Vector3(x,height/2,0),trim,metal)
		var wall: Node3D = root
		if data.id=="gate":
			wall = Node3D.new(); wall.name = "Door"; root.add_child(wall)
			box(root,Vector3(width+.1,.25,.8),Vector3(0,height+.1,0),trim,metal)
		if tier==1:
			for y in range(4): box(wall,Vector3(width-.35,height/5,.42),Vector3(0,.25+y*(height-.3)/4,0),body)
			braces(wall,width,height,trim)
		elif tier==2:
			box(wall,Vector3(width-.35,height-.15,.58),Vector3(0,height/2,0),body,true)
			for x in [-width*.28,0,width*.28]: box(wall,Vector3(.1,height-.05,.09),Vector3(x,height/2,-.34),trim,true)
			bolts(wall,width-.7,height,-.38)
		else:
			for side in [-1,1]: box(wall,Vector3((width-.4)/2,height-.15,.85),Vector3(side*(width-.4)/4,height/2,0),body)
			box(wall,Vector3(width,.18,.95),Vector3(0,height-.05,0),trim,true)
			box(wall,Vector3(width-.5,.15,.14),Vector3(0,height*.55,-.5),trim,true)
			bolts(wall,width-.8,height,-.48)
		if data.id=="bastion":
			for x in [-width*.3,width*.3]:
				box(root,Vector3(.45,height*.65,.8),Vector3(x,height*.325,.72),body,metal)
			for x in [-width*.35,0,width*.35]: box(wall,Vector3(.3,.28,.9),Vector3(x,height+.06,0),trim,metal)
	elif FortressData.turret(data.id):
		post(root,data.size.x*.47,.25,Vector3(0,.13,0),trim,metal)
		for x in [-.62,.62]:
			for z in [-.62,.62]: box(root,Vector3(.25,.18,.35),Vector3(x,.17,z),body,metal)
		post(root,.28,1.1,Vector3(0,.75,0),body,metal)
		if tier>=2: box(root,Vector3(.7,.65,.7),Vector3(0,.65,0),trim,true)
		var head := Node3D.new(); root.add_child(head); head.name = "Head"; head.position.y = 1.45
		if data.id=="shock":
			post(head,.16,.8,Vector3(0,.15,0),trim,true)
			for y in [0,.25,.5]:
				post(head,.4,.09,Vector3(0,y,0),body,true)
				VisualFactory.ring(head,.31,Vector3(0,y+.06,0),Color("79d4e5"))
			post(head,.22,.15,Vector3(0,.7,0),Color("c9eeed"),true)
		else:
			box(head,Vector3(.9,.45,.7),Vector3.ZERO,body,metal)
			var barrel := post(head,.15 if data.id=="cannon" else .08,1.4 if data.id=="cannon" else 1.05,Vector3(0,.03,-.7),trim,true)
			barrel.rotation.x = PI/2
			box(head,Vector3(.3,.23,.14),Vector3(0,.03,-1.36 if data.id=="cannon" else -1.23),trim,true)
			if tier>=2:
				for x in [-.48,.48]: box(head,Vector3(.12,.58,.85),Vector3(x,0,.02),trim,true)
			if tier==3 and data.id=="turret": post(head,.065,1.05,Vector3(.2,.03,-.7),trim,true).rotation.x = PI/2
			box(head,Vector3(.18,.12,.06),Vector3(.3,.1,-.39),Color("b4df9a"),true)
	elif data.id=="wire":
		for x in [-1.35,1.35]: box(root,Vector3(.1,.95,.1),Vector3(x,.47,0),trim,true)
		for x in [-1.0,-.5,0,.5,1.0]:
			var coil := VisualFactory.ring(root,.42+.025*tier,Vector3(x,.5,0),body)
			coil.rotation.z = PI/2
			for side in [-1,1]: box(root,Vector3(.05,.18,.05),Vector3(x,.72,side*.33),trim,true).rotation.x = side*.7
		box(root,Vector3(2.8,.045,.045),Vector3(0,.7,0),trim,true)
	elif data.id=="spikes":
		box(root,Vector3(2,.15,2),Vector3(0,.09,0),trim,metal)
		for x in [-.65,0,.65]:
			for z in [-.65,0,.65]:
				var stake := CylinderMesh.new(); stake.bottom_radius = .12; stake.top_radius = 0; stake.height = .65; stake.radial_segments = 5
				VisualFactory.mesh_node(root,stake,Vector3(x,.45,z),body,false)
	else:
		box(root,Vector3(1.9,.95,1.7),Vector3(0,.5,0),body,metal)
		box(root,Vector3(2.1,.16,1.9),Vector3(0,1.03,0),trim,true)
		for x in [-.55,.55]: box(root,Vector3(.5,.55,.08),Vector3(x,.55,-.9),trim,true)
		box(root,Vector3(.6,.12,.08),Vector3(0,.65,-.95),Color("e3e9cf"))
		box(root,Vector3(.12,.5,.08),Vector3(0,.65,-.95),Color("e3e9cf"))
		post(root,.13,.3,Vector3(.7,1.2,.55),Color("a8de9e"))
	if tier==3:
		box(root,Vector3(data.size.x*.75,.18,data.size.z*.8),Vector3(0,.12,0),Color("7d857f"))
	return root

static func core(tier: int) -> Node3D:
	var root := Node3D.new(); root.name = "Core_N"+str(tier)
	root.set_meta("tier",tier)
	var body: Color = [Color("7c826a"),Color("657e8c"),Color("8b9694"),Color("354c59")][tier-1]
	post(root,1.85,.3,Vector3(0,.15,0),Color("33474e"),true)
	box(root,Vector3(2.5,1.5,2.5),Vector3(0,1.0,0),body,tier>1)
	for x in [-1.15,1.15]:
		for z in [-1.15,1.15]: box(root,Vector3(.35,1.85,.35),Vector3(x,.95,z),Color("344a51"),true)
	box(root,Vector3(1.6,.55,1.6),Vector3(0,1.95,0),body,true)
	post(root,.4,.85,Vector3(0,2.47,0),Color("a4d87d"))
	VisualFactory.ring(root,1.0,Vector3(0,2.08,0),Color("a6dc8b"))
	if tier>=2:
		for x in [-1.5,1.5]: box(root,Vector3(.35,1.4,2.7),Vector3(x,.85,0),body,true)
	if tier>=3:
		for z in [-1.5,1.5]: box(root,Vector3(2.7,1.4,.35),Vector3(0,.85,z),body)
	if tier==4:
		for x in [-.9,.9]:
			for z in [-.9,.9]: post(root,.14,.8,Vector3(x,2.4,z),Color("87d4dc"),true)
		VisualFactory.ring(root,1.2,Vector3(0,2.75,0),Color("79c5d4"))
	return root

static func airdrop() -> Node3D:
	var root := Node3D.new(); root.name = "Airdrop"
	box(root,Vector3(1.8,1.2,1.4),Vector3(0,.6,0),Color("648077"),true)
	for x in [-.65,.65]: box(root,Vector3(.14,1.3,1.55),Vector3(x,.65,0),Color("e7ae63"),true)
	box(root,Vector3(1.95,.16,1.55),Vector3(0,1.25,0),Color("304a55"),true)
	box(root,Vector3(.5,.22,.08),Vector3(0,.65,-.74),Color("edf0d8"))
	box(root,Vector3(.22,.6,.08),Vector3(0,.65,-.74),Color("edf0d8"))
	var canopy := Node3D.new(); canopy.name = "Parachute"; root.add_child(canopy)
	var dome := SphereMesh.new(); dome.radius = 2.6; dome.height = 2.4; dome.radial_segments = 12; dome.rings = 5; dome.is_hemisphere = true
	VisualFactory.mesh_node(canopy,dome,Vector3(0,4.4,0),Color("cfa26a"),false)
	for x in [-1.3,1.3]:
		for z in [-1,1]:
			var rope := box(canopy,Vector3(.035,3.5,.035),Vector3(x*.5,2.8,z*.5),Color("d1d4bb"))
			rope.rotation.z = -x*.15; rope.rotation.x = z*.15
	return root
