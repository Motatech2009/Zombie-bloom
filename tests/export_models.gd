extends SceneTree
func own_tree(node: Node,scene_root: Node) -> void:
	for child in node.get_children(): child.owner = scene_root; own_tree(child,scene_root)
func save_model(node: Node3D,path: String) -> void:
	own_tree(node,node)
	var scene := PackedScene.new()
	assert(scene.pack(node)==OK)
	assert(ResourceSaver.save(scene,path)==OK)
	node.free()
func _initialize() -> void:
	for i in range(ItemBag.WEAPON_IDS.size()): save_model(ModelFactory.weapon(i),"res://assets/models/weapon_"+ItemBag.WEAPON_IDS[i]+".tscn")
	for kind in [0,1,2,3,4,5,8,9,10,11,12,13,14]:
		var color: Color = CampaignData.enemy_spec(kind).color if kind<9 else Color("b67962") if kind==12 else Color("72b6c9") if kind==13 else Color("68829b") if kind==14 else Color("ba7b6e") if kind==9 else Color("a67baf") if kind==10 else Color("5eb38e")
		save_model(ModelFactory.infected(kind,color),"res://assets/models/infected_"+str(kind)+".tscn")
	for id in ItemBag.IDS:
		if id not in ItemBag.WEAPON_IDS: save_model(ModelFactory.item(id),"res://assets/models/item_"+id+".tscn")
	print("MODEL EXPORT: 33 editable Godot scenes")
	quit()
