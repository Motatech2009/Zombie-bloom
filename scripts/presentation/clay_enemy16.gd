extends Node3D

var sk: Skeleton3D
var profile := ""
var running := false
var separated := false
var anatomical_stride := false
var controls: Array[Node3D] = []
var joints: PackedInt32Array = []
var lower_joints: PackedInt32Array = []
var feet: PackedInt32Array = []
var forearms: PackedInt32Array = []
var hands: PackedInt32Array = []
var parasite_left: Node3D
var parasite_right: Node3D

func _ready() -> void:
	sk = $Skeleton3D
	profile = str(get_meta("profile16", "human"))
	separated = has_meta("separated_source16")
	anatomical_stride = separated or has_meta("anatomical_stride16")
	var names: Array[String]
	match profile:
		"human":
			names = ["ArmL", "ArmR", "LegL", "LegR"]
			lower_joints = [sk.find_bone("ShinL"), sk.find_bone("ShinR")]
			feet = [sk.find_bone("FootL"), sk.find_bone("FootR")]
			forearms = [sk.find_bone("ForearmL"), sk.find_bone("ForearmR")]
			hands = [sk.find_bone("HandL"), sk.find_bone("HandR")]
		"flyer":
			names = ["WingL", "WingR"]
		"dog":
			names = ["LegFL", "LegFR", "LegBL", "LegBR"]
			feet = [sk.find_bone("FootFL"), sk.find_bone("FootFR"), sk.find_bone("FootBL"), sk.find_bone("FootBR")]
			parasite_left = $LegL
			parasite_right = $LegR
	for name in names:
		controls.append(get_node(name))
		joints.append(sk.find_bone(name))

func _process(delta: float) -> void:
	if is_visible_in_tree():
		sync_pose(1.0 - exp(-delta * 22.0))

func sync_pose(arm_follow := 1.0) -> void:
	if sk == null:
		return
	if profile == "human":
		for i in range(2):
			var arm := controls[i]
			var shoulder := sk.get_bone_pose_rotation(joints[i]).slerp(arm.quaternion, arm_follow)
			sk.set_bone_pose_rotation(joints[i], shoulder)
			var curl := clampf(shoulder.get_euler().x, 0.0, 1.0) * .13
			sk.set_bone_pose_rotation(forearms[i], Quaternion(Vector3.RIGHT, curl))
			sk.set_bone_pose_rotation(hands[i], Quaternion(Vector3.RIGHT, -curl * .45))
			var control := controls[2 + i]
			if anatomical_stride:
				# Retarget the GLB stride to this model's joints. Godot enemies face -Z.
				var step := clampf(control.rotation.x / .65, -1.0, 1.0)
				var thigh := step * (.53 if running else .33)
				var knee := minf(step, 0.0) * .42
				var ankle := -(thigh + knee) * .72
				sk.set_bone_pose_rotation(joints[2 + i], Quaternion(Vector3.RIGHT, thigh))
				sk.set_bone_pose_rotation(lower_joints[i], Quaternion(Vector3.RIGHT, knee))
				sk.set_bone_pose_rotation(feet[i], Quaternion(Vector3.RIGHT, ankle))
			else:
				sk.set_bone_pose_rotation(joints[2 + i], control.quaternion)
				sk.set_bone_pose_rotation(lower_joints[i], Quaternion(Vector3.RIGHT, maxf(0, -control.rotation.x) * .4))
		return
	if profile == "dog" and get_meta("parasite16", false):
		controls[0].rotation = parasite_left.rotation
		controls[3].rotation = parasite_left.rotation
		controls[1].rotation = parasite_right.rotation
		controls[2].rotation = parasite_right.rotation
	for i in range(controls.size()):
		if separated and profile == "dog":
			var swing := controls[i].rotation.x * .65
			sk.set_bone_pose_rotation(joints[i], Quaternion(Vector3.RIGHT, swing))
			sk.set_bone_pose_rotation(feet[i], Quaternion(Vector3.RIGHT, -swing * .65))
		else:
			sk.set_bone_pose_rotation(joints[i], controls[i].quaternion)
