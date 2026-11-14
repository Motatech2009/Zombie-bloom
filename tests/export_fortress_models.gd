extends SceneTree
func own_tree(node: Node,root_node: Node) -> void:
	for child in node.get_children(): child.owner = root_node; own_tree(child,root_node)
func save_model(node: Node3D,path: String) -> void:
	own_tree(node,node)
	var scene := PackedScene.new(); assert(scene.pack(node)==OK)
	assert(ResourceSaver.save(scene,path)==OK); node.free()
func _initialize() -> void:
	VisualFactory.clay_enabled = false
	for i in range(FortressData.pieces().size()):
		for tier in range(1,4): save_model(FortressModels.defense(i,tier),"res://assets/fortress/"+FortressData.pieces()[i].id+"_"+str(tier)+".tscn")
	for tier in range(1,5): save_model(FortressModels.core(tier),"res://assets/fortress/core_"+str(tier)+".tscn")
	save_model(FortressModels.airdrop(),"res://assets/fortress/airdrop.tscn")
	print("FORTRESS MODEL EXPORT: 35 models"); quit()
