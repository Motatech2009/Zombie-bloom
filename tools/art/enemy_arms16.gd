extends RefCounted
## Model-space landmarks measured on the supplied meshes, from shoulder to palm.
## Each limb has its own fit because the source poses and equipment are asymmetric.

const LIMBS := {
	"mauler": [
		[Vector3(-.50, 1.44, .19), Vector3(-.68, .98, .41), Vector3(-.70, .57, .31), Vector3(-.65, .37, .42), .19],
		[Vector3(.43, 1.42, -.19), Vector3(.67, 1.03, -.39), Vector3(.65, .64, -.50), Vector3(.58, .36, -.58), .20]],
	"hive": [
		[Vector3(-.47, 1.40, .27), Vector3(-.66, .97, .38), Vector3(-.73, .54, .30), Vector3(-.67, .38, .25), .20],
		[Vector3(.43, 1.42, -.19), Vector3(.67, 1.03, -.43), Vector3(.69, .60, -.59), Vector3(.62, .42, -.59), .20]],
	"mortar": [
		[Vector3(-.63, 1.34, .11), Vector3(-.82, .92, .39), Vector3(-.88, .55, .46), Vector3(-.88, .38, .48), .23],
		[Vector3(.62, 1.30, -.27), Vector3(.81, .92, -.46), Vector3(.79, .60, -.60), Vector3(.74, .41, -.61), .23]],
	"titan16": [
		[Vector3(-.49, 1.35, -.38), Vector3(-.57, 1.01, -.60), Vector3(-.64, .67, -.73), Vector3(-.49, .41, -.78), .23],
		[Vector3(.48, 1.35, .31), Vector3(.66, 1.04, .46), Vector3(.70, .72, .46), Vector3(.57, .41, .38), .24]],
	"broodmother": [
		[Vector3(-.28, 1.28, .18), Vector3(-.43, .91, .32), Vector3(-.51, .64, .25), Vector3(-.49, .47, .22), .17],
		[Vector3(.35, 1.24, -.12), Vector3(.50, .93, -.25), Vector3(.54, .64, -.32), Vector3(.50, .48, -.33), .16]],
	"potter": [
		[Vector3(-.27, 1.30, .23), Vector3(-.46, 1.09, .22), Vector3(-.60, 1.01, .12), Vector3(-.72, .97, .05), .12],
		[Vector3(.30, 1.30, -.01), Vector3(.49, 1.09, -.19), Vector3(.63, 1.01, -.31), Vector3(.73, .98, -.40), .12]],
	"walker": [
		[Vector3(-.28, 1.34, .06), Vector3(-.44, 1.15, -.05), Vector3(-.59, 1.13, -.14), Vector3(-.65, 1.02, -.08), .12],
		[Vector3(.28, 1.34, .03), Vector3(.33, 1.01, -.02), Vector3(.35, .78, -.08), Vector3(.35, .70, -.12), .11]],
	"runner": [
		[Vector3(-.27, 1.39, .04), Vector3(-.35, 1.06, .03), Vector3(-.34, .80, -.06), Vector3(-.34, .67, .00), .10],
		[Vector3(.27, 1.40, .07), Vector3(.34, 1.05, .08), Vector3(.33, .80, .00), Vector3(.33, .66, .03), .10]],
	"armored": [
		[Vector3(-.39, 1.31, .10), Vector3(-.41, .98, .19), Vector3(-.42, .75, .12), Vector3(-.42, .66, .11), .14],
		[Vector3(.43, 1.31, -.10), Vector3(.46, .97, -.13), Vector3(.47, .75, -.17), Vector3(.46, .66, -.20), .14]],
	"charger": [
		[Vector3(-.31, 1.27, .17), Vector3(-.32, 1.02, .16), Vector3(-.30, .82, .07), Vector3(-.31, .70, .04), .12],
		[Vector3(.41, 1.26, -.05), Vector3(.43, .99, -.12), Vector3(.43, .79, -.12), Vector3(.43, .68, -.13), .13]],
	"demolisher": [
		[Vector3(-.44, 1.36, .18), Vector3(-.47, 1.03, .17), Vector3(-.45, .82, .04), Vector3(-.46, .63, .18), .16],
		[Vector3(.47, 1.37, -.05), Vector3(.51, 1.04, -.13), Vector3(.49, .81, -.20), Vector3(.47, .63, -.11), .15]],
	"brute": [
		[Vector3(-.48, 1.37, .20), Vector3(-.59, .96, .37), Vector3(-.64, .57, .26), Vector3(-.63, .40, .24), .18],
		[Vector3(.43, 1.36, -.11), Vector3(.58, .96, -.31), Vector3(.62, .57, -.42), Vector3(.55, .42, -.46), .19]],
	"alpha_legacy": [
		[Vector3(-.52, 1.43, .14), Vector3(-.64, 1.02, .29), Vector3(-.71, .62, .29), Vector3(-.69, .43, .25), .16],
		[Vector3(.47, 1.45, -.20), Vector3(.68, 1.02, -.33), Vector3(.69, .66, -.47), Vector3(.63, .47, -.50), .19]],
	"bridge": [
		[Vector3(-.32, 1.24, -.08), Vector3(-.56, 1.19, -.22), Vector3(-.70, 1.18, -.31), Vector3(-.83, 1.18, -.36), .14],
		[Vector3(.37, 1.15, -.13), Vector3(.57, .85, -.21), Vector3(.64, .62, -.29), Vector3(.67, .49, -.35), .16]],
	"burster": [
		[Vector3(-.43, 1.22, .28), Vector3(-.54, .83, .30), Vector3(-.62, .59, .31), Vector3(-.63, .44, .28), .18],
		[Vector3(.42, 1.24, -.17), Vector3(.54, .88, -.34), Vector3(.55, .64, -.39), Vector3(.51, .48, -.42), .17]],
	"cleaver": [
		[Vector3(-.39, 1.37, .17), Vector3(-.54, 1.06, .20), Vector3(-.50, .82, .03), Vector3(-.51, .72, -.10), .15],
		[Vector3(.29, 1.38, -.04), Vector3(.35, 1.08, -.02), Vector3(.34, .82, -.04), Vector3(.34, .72, -.04), .12]],
	"cryo": [
		[Vector3(-.32, 1.34, .08), Vector3(-.41, 1.02, .14), Vector3(-.40, .77, .11), Vector3(-.38, .65, .10), .13],
		[Vector3(.33, 1.32, -.01), Vector3(.39, 1.01, -.11), Vector3(.37, .78, -.19), Vector3(.34, .65, -.21), .13]],
	"lobber": [
		[Vector3(-.39, 1.33, -.18), Vector3(-.55, 1.44, -.24), Vector3(-.68, 1.56, -.39), Vector3(-.73, 1.59, -.45), .17],
		[Vector3(.37, 1.34, .19), Vector3(.54, 1.40, .31), Vector3(.67, 1.47, .46), Vector3(.73, 1.54, .52), .15]],
	"mender": [
		[Vector3(-.29, 1.31, .13), Vector3(-.43, 1.33, .17), Vector3(-.49, 1.39, .17), Vector3(-.53, 1.47, .18), .13],
		[Vector3(.30, 1.28, -.11), Vector3(.49, 1.28, -.19), Vector3(.52, 1.36, -.20), Vector3(.57, 1.42, -.21), .14]],
	"saboteur": [
		[Vector3(-.34, 1.36, .13), Vector3(-.46, 1.11, .17), Vector3(-.43, .82, .04), Vector3(-.40, .72, .00), .12],
		[Vector3(.38, 1.36, -.03), Vector3(.47, 1.13, -.14), Vector3(.43, .84, -.24), Vector3(.41, .74, -.25), .12]],
	"screamer": [
		[Vector3(-.28, 1.24, .19), Vector3(-.35, .94, .23), Vector3(-.34, .71, .20), Vector3(-.34, .62, .20), .12],
		[Vector3(.38, 1.24, -.08), Vector3(.43, .93, -.12), Vector3(.42, .73, -.16), Vector3(.41, .62, -.17), .13]],
	"shieldbearer": [
		[Vector3(-.28, 1.34, .20), Vector3(-.34, 1.04, .13), Vector3(-.33, .80, .07), Vector3(-.34, .72, .05), .10],
		[Vector3(.43, 1.34, -.02), Vector3(.43, 1.06, -.03), Vector3(.41, .83, -.10), Vector3(.40, .72, -.12), .14]],
	"spitter": [
		[Vector3(-.33, 1.36, .12), Vector3(-.43, 1.06, .20), Vector3(-.41, .83, .11), Vector3(-.38, .71, .09), .13],
		[Vector3(.34, 1.35, -.09), Vector3(.39, 1.07, -.14), Vector3(.39, .82, -.20), Vector3(.37, .73, -.21), .13]],
}

static func fit_skeleton(skeleton: Skeleton3D, id: String) -> void:
	for side in range(2):
		var arm := 3 + side * 3
		for joint in range(3):
			var bone := arm + joint
			var parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone))
			skeleton.set_bone_rest(bone, Transform3D(Basis.IDENTITY, parent.affine_inverse() * LIMBS[id][side][joint]))
	skeleton.reset_bone_poses()

static func relink(point: Vector3, base: Dictionary, id: String, island: Vector2i) -> Dictionary:
	var limbs: Array = LIMBS[id]
	var left_elbow: Vector3 = limbs[0][1]
	var right_elbow: Vector3 = limbs[1][1]
	var lateral := ((right_elbow - left_elbow) * Vector3(1, 0, 1)).normalized()
	var left := arm_weights(point, limbs[0], -lateral, island.x)
	var right := arm_weights(point, limbs[1], lateral, island.y)
	var side := 3 if left.w > right.w else 6
	var arm := left if side == 3 else right
	# The front shield is a rigid part of the body. The blade follows the gripping hand.
	if id == "shieldbearer" and point.x < .22 and point.z + .43 * point.x < -.13 and point.y > .31:
		return {1: 1.0}
	if id == "cleaver" and point.y < 1.12:
		if point.x < -.39 and point.z < -.15:
			return {5: 1.0}
		if point.x > -.18 and point.z < -.25:
			return {8: 1.0}
	if arm.w <= .001:
		return base
	for bone in base:
		base[bone] *= 1.0 - arm.w
	base[side] = arm.x
	base[side + 1] = arm.y
	base[side + 2] = arm.z
	return base

static func arm_weights(point: Vector3, limb: Array, lateral_axis: Vector3, island: int) -> Vector4:
	if island == 0:
		return Vector4.ZERO
	var shoulder: Vector3 = limb[0]
	var elbow: Vector3 = limb[1]
	var wrist: Vector3 = limb[2]
	var palm: Vector3 = limb[3]
	var radius: float = limb[4]
	var upper := Geometry3D.get_closest_point_to_segment(point, shoulder, elbow)
	var lower := Geometry3D.get_closest_point_to_segment(point, elbow, wrist)
	var hand := Geometry3D.get_closest_point_to_segment(point, wrist, palm)
	var distance := minf(point.distance_to(upper), minf(point.distance_to(lower), point.distance_to(hand)))
	var elbow_width := elbow.dot(lateral_axis)
	var wrist_width := wrist.dot(lateral_axis)
	var shoulder_width := shoulder.dot(lateral_axis)
	var side_width := point.dot(lateral_axis)
	var elbow_progress := smoothstep(shoulder.y + radius * .3, elbow.y, point.y)
	var inner := lerpf(shoulder_width - radius * .37, minf(elbow_width, wrist_width) - radius * 1.16, elbow_progress)
	var lateral := smoothstep(inner - radius * .37, inner + radius * .28, side_width)
	# The capsule stops at the shoulder and beyond the fingertips. A broader
	# cross section for the lower arm keeps the entire hand weighted together.
	var strength := lateral * (1.0 - smoothstep(radius * 1.48, radius * 2.08, distance))
	var top := maxf(shoulder.y, palm.y)
	strength *= 1.0 - smoothstep(top + radius * .66, top + radius * 1.22, point.y)
	if island == 1:
		strength = 1.0
	var elbow_axis := (wrist - shoulder).normalized()
	var forearm := smoothstep(-radius * .78, radius * .64, (point - elbow).dot(elbow_axis))
	var palm_axis := (palm - elbow).normalized()
	var grip := smoothstep(-radius * .46, radius * .34, (point - wrist).dot(palm_axis))
	return Vector4(strength * (1.0 - forearm), strength * forearm * (1.0 - grip), strength * forearm * grip, strength)
