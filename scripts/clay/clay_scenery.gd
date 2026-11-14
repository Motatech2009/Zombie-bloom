class_name ClayScenery
extends RefCounted
static func box(parent: Node3D,size: Vector3,pos: Vector3,color: Color,kind: String = "clay") -> MeshInstance3D:
	var part := VisualFactory.box(parent,size,pos,color)
	part.material_override = ClayStyle.material(color,kind)
	return part

static func decorate(arena: Node3D,seed_value: int,biome: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var grass: Color = [Color("465740"),Color("525a50"),Color("3f5139"),Color("736f48"),Color("4b5748")][biome]
	for child in arena.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh and child.position.y<0:
			child.material_override = ClayStyle.material(grass if child.position.y<-.1 else Color("465457"),"grass" if child.position.y<-.1 else "road")
	# A bounded set of animated props, away from the central cross and exits.
	for i in range(8):
		var root := Node3D.new(); arena.add_child(root)
		root.position = Vector3((-1 if i%2==0 else 1)*(46+rng.randf()*3),0,(i/2)*22-33)
		var trunk := box(root,Vector3(.45,2.6,.5),Vector3(0,1.3,0),Color("8e7159"),"wood")
		trunk.rotation.z = .05
		var crown := Node3D.new(); crown.set_script(load("res://scripts/clay/scenery_motion.gd")); crown.phase = i; crown.speed = 1.1
		root.add_child(crown); crown.position.y = 2.2
		for offset in [Vector3(0,.7,0),Vector3(-.7,.2,0),Vector3(.7,.3,.2)]:
			var foliage := VisualFactory.cylinder(crown,1.15,1.5,offset,Color("718957") if biome!=2 else Color("8f8a63"))
			foliage.mesh.radial_segments = 8
			foliage.mesh.top_radius = .8
			foliage.material_override = ClayStyle.material(grass.lightened(.08),"grass")
	for i in range(20):
		var x := rng.randf_range(-48,48); var z := rng.randf_range(-48,48)
		if absf(x)<9 or absf(z)<9: continue
		box(arena,Vector3(.65,.18,.4),Vector3(x,.02,z),grass.lightened(.15)).rotation.y = rng.randf()*TAU
