extends Node3D
## Shared skinned clay model; controllers preserve the existing gameplay animation API.
const HOME := Vector3(.20,1.15,-.36)
var skeleton: Skeleton3D
var skin_mesh: MeshInstance3D
var outfit_key := ""
func _ready() -> void:
	process_priority = 100
	skeleton = get_node("Skeleton3D")
	skin_mesh = get_node("Skeleton3D/Character")
	get_node("Gun").position = HOME
	sync_pose()
func _process(_delta: float) -> void:
	if is_visible_in_tree(): sync_pose()
func set_outfit16(outfit: Dictionary) -> void:
	var covered := not str(outfit.get("outfit","")).is_empty()
	var head := str(outfit.get("head",""))
	var fitted_head := head in ["COS-ENG-01","COS-ENG-02","COS-BAT-01","COS-ATI-02","COS-UNI-01","COS-TITAN-01"]
	var key := ("covered" if covered else "base")+("_head" if fitted_head else "")
	if key!=outfit_key:
		get_node("Skeleton3D/Character").mesh = load("res://assets/characters/player16/"+key+".res")
		outfit_key = key
func arm_pose(side: int,target: Vector3) -> void:
	var upper := skeleton.find_bone("ArmL" if side<0 else "ArmR")
	var lower := upper+1
	var hand := upper+2
	var shoulder := Vector3(side*.323,1.30,0)
	var delta := target-shoulder
	var reach := clampf(delta.length(),.10,.586)
	var direction := delta.normalized()
	var upper_length := .30; var lower_length := .30
	var along := (upper_length*upper_length-lower_length*lower_length+reach*reach)/(2*reach)
	var bend := Vector3(side*.75,-1,.12)
	bend = (bend-direction*bend.dot(direction)).normalized()
	var elbow := shoulder+direction*along+bend*sqrt(maxf(0,upper_length*upper_length-along*along))
	var first := Quaternion(Vector3(side,0,0),(elbow-shoulder).normalized())
	var second := Quaternion(Vector3(side,0,0),(shoulder+direction*reach-elbow).normalized())
	skeleton.set_bone_pose_rotation(upper,first)
	skeleton.set_bone_pose_rotation(lower,first.inverse()*second)
	skeleton.set_bone_pose_rotation(hand,Quaternion.IDENTITY)
func sync_pose() -> void:
	if skeleton==null: return
	var gun: Node3D = get_node("Gun")
	for side in [-1,1]:
		var control: Node3D = get_node("ArmL" if side<0 else "ArmR")
		if gun.visible:
			var target := gun.transform*Vector3(0,-.14,.08) if side>0 else gun.transform*Vector3(-.09,-.10,.10)
			if side<0 and (control.rotation.z>.3 or control.rotation.x<.85):
				target = Vector3(-.21,.96,-.18)+Vector3(0,sin(control.rotation.x*4)*.06,-control.rotation.x*.10)
			arm_pose(side,target)
		else:
			var bone := skeleton.find_bone("ArmL" if side<0 else "ArmR")
			var swing := (control.rotation.x-1.1)*1.5
			var tucked: bool = get_node("ArmL").rotation.x<.85 and get_node("ArmR").rotation.x<.85
			if tucked or (side<0 and control.rotation.x<.85): swing = .9+control.rotation.x*.3
			skeleton.set_bone_pose_rotation(bone,Quaternion.from_euler(Vector3(swing,0,-side*1.43)))
			skeleton.set_bone_pose_rotation(bone+1,Quaternion.from_euler(Vector3(0,side*.12,0)))
		var leg := skeleton.find_bone("LegL" if side<0 else "LegR")
		var angle: float = get_node("LegL" if side<0 else "LegR").rotation.x
		skeleton.set_bone_pose_rotation(leg,Quaternion(Vector3.RIGHT,angle))
		skeleton.set_bone_pose_rotation(leg+1,Quaternion(Vector3.RIGHT,-maxf(0,-angle)*.8))
		skeleton.set_bone_pose_rotation(leg+2,Quaternion(Vector3.RIGHT,-angle*.20))
