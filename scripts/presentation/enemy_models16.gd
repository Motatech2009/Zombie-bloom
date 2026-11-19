extends RefCounted
## Shared, offline-prepared models supplied by the creator. Gameplay remains on the actor.
static var lean_materials: Dictionary = {}
static func create(actor: Node3D,factor: float) -> Node3D:
	var id: String = actor.spec.id
	var kit := "bosses" if actor.is_boss else "zombies"
	var source_id := "hound" if id=="parasite" else id
	var filename := "res://assets/enemies/tripo16/"+kit+"/"+source_id+".tscn"
	if not ResourceLoader.exists(filename): return null
	var rig: Node3D = load(filename).instantiate(); actor.add_child(rig)
	if MobilePlatform.lightweight():
		var mesh: MeshInstance3D = rig.get_node("Skeleton3D/Character")
		var original: StandardMaterial3D = mesh.get_surface_override_material(0)
		if not lean_materials.has(original):
			var lean: StandardMaterial3D = original.duplicate()
			lean.normal_enabled = false
			lean_materials[original] = lean
		mesh.set_surface_override_material(0, lean_materials[original])
	var profile: String = rig.get_meta("profile16","human")
	rig.set_meta("source_model_id16",source_id); rig.set_meta("model_id16",id)
	rig.scale = Vector3.ONE*(factor if profile=="human" or (profile=="dog" and actor.is_boss) else .45 if id=="parasite" else 1.0)
	if id=="parasite": rig.set_meta("parasite16",true)
	actor.wings.clear()
	for name in (["WingL","WingR"] if profile=="flyer" else ["LegFL","LegFR","LegBL","LegBR"] if profile=="dog" else []):
		actor.wings.append(rig.get_node(name))
	return rig
