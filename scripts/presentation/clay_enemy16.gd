extends Node3D
var sk: Skeleton3D
var profile := ""
func _ready() -> void:
	sk = get_node("Skeleton3D"); profile = str(get_meta("profile16","human"))
func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	sync_pose()
func sync_pose() -> void:
	if sk==null: return
	if profile=="human":
		for entry in [["ArmL",3],["ArmR",6],["LegL",9],["LegR",12]]:
			var control: Node3D = get_node(entry[0]); sk.set_bone_pose_rotation(entry[1],control.quaternion)
			if int(entry[1]) in [9,12]: sk.set_bone_pose_rotation(int(entry[1])+1,Quaternion(Vector3.RIGHT,maxf(0,-control.rotation.x)*.4))
	elif profile=="flyer":
		for entry in [["WingL",3],["WingR",4]]: sk.set_bone_pose_rotation(entry[1],get_node(entry[0]).quaternion)
	else:
		if get_meta("parasite16",false):
			for name in ["LegFL","LegBR"]: get_node(name).rotation = get_node("LegL").rotation
			for name in ["LegFR","LegBL"]: get_node(name).rotation = get_node("LegR").rotation
		for entry in [["LegFL",3],["LegFR",4],["LegBL",5],["LegBR",6]]: sk.set_bone_pose_rotation(entry[1],get_node(entry[0]).quaternion)
