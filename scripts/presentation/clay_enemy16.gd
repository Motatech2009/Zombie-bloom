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
var predator_stride := false
var hive_stride := false
var striding := false
var knee_angles := Vector4.ZERO
var paw_angles := Vector4.ZERO
var head_angle := 0.0
var head_joint := -1
const HIVE_FACING := -0.51

func _ready() -> void:
	sk = $Skeleton3D
	profile = str(get_meta("profile16", "human"))
	predator_stride = has_meta("predator_stride")
	hive_stride = get_meta("model_id16", "") == "hive"
	if hive_stride: sk.rotation.y = HIVE_FACING
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
			if predator_stride:
				for side in ["FL","FR","BL","BR"]:
					lower_joints.append(sk.find_bone("Hock"+side))
					feet.append(sk.find_bone("Paw"+side))
				head_joint = sk.find_bone("Head")
			else:
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
			if hive_stride:
				var axis := Vector3.RIGHT.rotated(Vector3.UP, -HIVE_FACING)
				sk.set_bone_pose_rotation(joints[2+i], Quaternion(axis,control.rotation.x))
				sk.set_bone_pose_rotation(lower_joints[i], Quaternion(axis,knee_angles[i] if striding else 0.0))
				sk.set_bone_pose_rotation(feet[i], Quaternion(axis,paw_angles[i] if striding else 0.0))
			elif anatomical_stride:
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
	if predator_stride:
		sk.set_bone_pose_rotation(head_joint,Quaternion(Vector3.RIGHT,head_angle if striding else 0.0))
	for i in range(controls.size()):
		if predator_stride:
			sk.set_bone_pose_rotation(joints[i],controls[i].quaternion)
			var hock := knee_angles[i] if striding else clampf(-controls[i].rotation.x*.4,-.40,.40)
			sk.set_bone_pose_rotation(lower_joints[i],Quaternion(Vector3.RIGHT,hock))
			sk.set_bone_pose_rotation(feet[i],Quaternion(Vector3.RIGHT,paw_angles[i] if striding else -hock*.55))
		elif separated and profile == "dog":
			var swing := controls[i].rotation.x * .65
			sk.set_bone_pose_rotation(joints[i], Quaternion(Vector3.RIGHT, swing))
			sk.set_bone_pose_rotation(feet[i], Quaternion(Vector3.RIGHT, -swing * .65))
		else:
			sk.set_bone_pose_rotation(joints[i], controls[i].quaternion)

func stride_pose(phase: float, weight: float) -> void:
	striding = true
	if predator_stride:
		var offsets := Vector4(0.0,.5,.57,.07)
		for i in range(4):
			var cycle := fposmod(phase + offsets[i], 1.0)
			var wave := sin(cycle * TAU)
			var lift := maxf(0,cos(cycle * TAU))
			var foreleg := i < 2
			controls[i].rotation = Vector3(wave * (.33 if foreleg else .39) * weight,0,0)
			knee_angles[i] = lift * (-.41 if foreleg else .45) * weight
			paw_angles[i] = (-controls[i].rotation.x*.78 - knee_angles[i]) * .86
		var bounce := cos(phase * TAU * 2.0) * weight
		position.y = (.026*weight + .018*bounce) * scale.y
		rotation.x = .045 * bounce
		rotation.z = sin(phase * TAU) * .022 * weight
		head_angle = -.04 * bounce
	elif hive_stride:
		var bob := cos(phase * TAU * 2.0) * .013 * weight
		position.y = bob * scale.y
		rotation.x = -.045 * weight
		rotation.z = sin(phase * TAU) * .037 * weight
		for i in range(2):
			var cycle := fposmod(phase + .5*i, 1.0)
			var swing := clampf((cycle-.63)/.37,0,1)
			var depth := lerpf(-.18,.18,cycle/.63) if cycle < .63 else lerpf(.18,-.18,smoothstep(0,1,swing))
			var height := sin(swing*PI)*.12
			hive_leg(i,depth*weight,height*weight-bob,weight)

func hive_leg(side: int, depth: float, lift: float, weight: float) -> void:
	# Solve hip and knee along the walking plane so the heavy feet stay flat.
	const THIGH := .38
	const SHIN := .288
	var vertical := THIGH + SHIN - lift - .045*weight
	var reach := clampf(Vector2(depth,vertical).length(), .15, THIGH + SHIN)
	var cosine := (reach*reach - THIGH*THIGH - SHIN*SHIN)/(2.0*THIGH*SHIN)
	var knee := -acos(clampf(cosine,-1,1))
	var hip := atan2(-depth,vertical) + atan2(-SHIN*sin(knee),THIGH + SHIN*cos(knee))
	controls[2+side].rotation.x = hip
	knee_angles[side] = knee
	paw_angles[side] = -(hip+knee)
