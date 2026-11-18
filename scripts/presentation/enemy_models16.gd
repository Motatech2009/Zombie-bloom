extends RefCounted
## Shared, offline-prepared models supplied by the creator. Gameplay remains on the actor.
static func create(actor: Node3D,factor: float) -> Node3D:
	var id: String = actor.spec.id
	var kit := "bosses" if actor.is_boss else "zombies"
	var source_id := "hound" if id=="parasite" else id
	var filename := "res://assets/enemies/tripo16/"+kit+"/"+source_id+".tscn"
	if not ResourceLoader.exists(filename): return null
	var rig: Node3D = load(filename).instantiate(); actor.add_child(rig)
	var profile: String = rig.get_meta("profile16","human")
	rig.set_meta("source_model_id16",source_id); rig.set_meta("model_id16",id)
	rig.scale = Vector3.ONE*(factor if profile=="human" else .45 if id=="parasite" else 1.0)
	if id=="parasite": rig.set_meta("parasite16",true)
	actor.wings.clear()
	for name in (["WingL","WingR"] if profile=="flyer" else ["LegFL","LegFR","LegBL","LegBR"] if profile=="dog" else []):
		actor.wings.append(rig.get_node(name))
	return rig
