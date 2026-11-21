extends SceneTree
## Align and bind the supplied Predador Alfa mesh to the four measured leg chains.
## Run with Godot on an unmodified 1.7.2 hound scene and mesh.

const MODEL := "res://assets/enemies/tripo16/bosses/hound"
const LEGS := [
	[Vector3(-.17,.43,-.23), Vector3(-.21,.19,-.13), Vector3(-.20,.064,-.22)],
	[Vector3(.11,.44,-.24), Vector3(.10,.19,-.14), Vector3(.11,.062,-.25)],
	[Vector3(-.14,.45,.25), Vector3(-.18,.21,.33), Vector3(-.17,.063,.29)],
	[Vector3(.10,.45,.23), Vector3(.11,.21,.31), Vector3(.09,.061,.27)],
]

func _initialize() -> void:
	var rig: Node3D = load(MODEL + ".tscn").instantiate()
	if rig.has_meta("predator_stride"):
		rig.free()
		quit()
		return
	var skeleton: Skeleton3D = rig.get_node("Skeleton3D")
	var character: MeshInstance3D = skeleton.get_node("Character")
	var original: ArrayMesh = character.mesh
	var arrays := original.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var forward := Basis(Vector3.UP, deg_to_rad(-43.0))

	fit_joint(skeleton, 2, Vector3(-.04,.60,-.37))
	for i in range(4):
		var hip := 3 + i
		fit_joint(skeleton, hip, LEGS[i][0])
		var suffix := String(skeleton.get_bone_name(hip)).trim_prefix("Leg")
		var hock := skeleton.add_bone("Hock" + suffix)
		skeleton.set_bone_parent(hock, hip)
		fit_joint(skeleton, hock, LEGS[i][1])
		var foot := skeleton.add_bone("Paw" + suffix)
		skeleton.set_bone_parent(foot, hock)
		fit_joint(skeleton, foot, LEGS[i][2])
	skeleton.reset_bone_poses()

	for i in range(points.size()):
		var point := forward * points[i]
		points[i] = point
		normals[i] = forward * normals[i]
		if not tangents.is_empty():
			var j := i*4
			var tangent := forward * Vector3(tangents[j],tangents[j+1],tangents[j+2])
			tangents[j] = tangent.x
			tangents[j+1] = tangent.y
			tangents[j+2] = tangent.z

		var j := i*4
		var side := closest_leg(point)
		var anchor: Vector3 = LEGS[side][1]
		var within_legs := smoothstep(-.47,-.37,point.z) * (1.0-smoothstep(.42,.53,point.z))
		var leg_weight := within_legs * (1.0-smoothstep(.23,.49,point.y))
		var lower := 1.0-smoothstep(anchor.y-.08,anchor.y+.10,point.y)
		var paw := 1.0-smoothstep(.043,.13,point.y)
		var head := smoothstep(.34,.58,-point.z)
		if head > .01:
			bones[j] = 1
			bones[j+1] = 2
			bones[j+2] = 0
			bones[j+3] = 0
			weights[j] = 1.0-head
			weights[j+1] = head
			weights[j+2] = 0
			weights[j+3] = 0
		else:
			bones[j] = 1
			bones[j+1] = 3+side
			bones[j+2] = 7+side*2
			bones[j+3] = 8+side*2
			weights[j] = 1.0-leg_weight
			weights[j+1] = leg_weight*(1.0-lower)
			weights[j+2] = leg_weight*lower*(1.0-paw)
			weights[j+3] = leg_weight*lower*paw
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, original.surface_get_material(0))
	mesh.take_over_path(MODEL + ".res")
	assert(ResourceSaver.save(mesh,mesh.resource_path,ResourceSaver.FLAG_COMPRESS) == OK)
	character.mesh = mesh
	character.skin = skeleton.create_skin_from_rest_transforms()
	rig.set_meta("predator_stride",true)
	var packed := PackedScene.new()
	assert(packed.pack(rig) == OK)
	assert(ResourceSaver.save(packed,MODEL+".tscn") == OK)
	rig.free()
	print("PREDATOR: %d vertices rebound to four joint chains" % points.size())
	quit()

func fit_joint(skeleton: Skeleton3D, joint: int, point: Vector3) -> void:
	var parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(joint))
	skeleton.set_bone_rest(joint,Transform3D(Basis.IDENTITY,parent.affine_inverse()*point))

func closest_leg(point: Vector3) -> int:
	var closest := 0
	var distance := INF
	for i in range(4):
		var hip: Vector3 = LEGS[i][0]
		var ankle: Vector3 = LEGS[i][2]
		var hock: Vector3 = LEGS[i][1]
		var segment := hock.lerp(hip,smoothstep(hock.y,hip.y,point.y)) if point.y > hock.y else ankle.lerp(hock,smoothstep(ankle.y,hock.y,point.y))
		var candidate := Vector2(point.x-segment.x,point.z-segment.z).length_squared()
		if candidate < distance:
			distance = candidate
			closest = i
	return closest
