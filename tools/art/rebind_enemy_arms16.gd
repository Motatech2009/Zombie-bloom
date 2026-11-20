extends SceneTree
## Reapply the arm fit to the existing compact meshes without touching textures or leg geometry.
## godot --headless --path . --script res://tools/art/rebind_enemy_arms16.gd
## Pass -- --legs to rebind the Oleiro and Sabotador boots using their mesh connectivity.

const Arms := preload("res://tools/art/enemy_arms16.gd")
const ROOT := "res://assets/enemies/tripo16/"
# Hip, knee and ankle positions measured on each boot chain. The ceiling
# isolates the two connected leg surfaces below the crotch or suit harness.
const LEG_FITS := {
	"saboteur": [.41, .34, .57,
		[Vector3(-.18,.56,-.09), Vector3(-.25,.32,-.10), Vector3(-.30,.145,-.08)],
		[Vector3(.13,.56,-.18), Vector3(.14,.32,-.16), Vector3(.14,.145,-.23)]],
	"potter": [.59, .47, .73,
		[Vector3(-.12,.72,.16), Vector3(-.09,.39,.14), Vector3(-.14,.145,.20)],
		[Vector3(.15,.72,.04), Vector3(.13,.36,.02), Vector3(.15,.145,.055)]],
}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var legs_only := "--legs" in OS.get_cmdline_user_args()
	for kit in ["zombies", "bosses"]:
		var directory: String = ROOT + kit + "/"
		for file in DirAccess.get_files_at(directory):
			var id := file.get_basename()
			if file.get_extension() != "tscn" or not Arms.LIMBS.has(id):
				continue
			if legs_only and not LEG_FITS.has(id):
				continue
			var rig: Node3D = load(directory + file).instantiate()
			var sk: Skeleton3D = rig.get_node("Skeleton3D")
			var model: MeshInstance3D = sk.get_node("Character")
			var original: ArrayMesh = model.mesh
			var arrays := original.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var adjacency := mesh_edges(points, arrays[Mesh.ARRAY_INDEX])
			if legs_only:
				if not fit_legs(id, sk, points, adjacency, bones, weights):
					printerr("Failed to isolate both boots on ", id)
					rig.free()
					quit(1)
					return
				rig.set_meta("anatomical_stride16", true)
			else:
				var left := arm_island(points, adjacency, Arms.LIMBS[id][0], id)
				var right := arm_island(points, adjacency, Arms.LIMBS[id][1], id)
				for v in range(points.size()):
					var body := body_weights(points[v], bones, weights, v * 4)
					var rebound := Arms.relink(points[v], body, id, Vector2i(left[v], right[v]))
					write_weights(bones, weights, v * 4, rebound)
				Arms.fit_skeleton(sk, id)
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, original.surface_get_material(0))
			mesh.take_over_path(directory + id + ".res")
			assert(ResourceSaver.save(mesh, mesh.resource_path, ResourceSaver.FLAG_COMPRESS) == OK)
			model.mesh = mesh
			model.skin = sk.create_skin_from_rest_transforms()
			var result := PackedScene.new()
			assert(result.pack(rig) == OK)
			assert(ResourceSaver.save(result, directory + file) == OK)
			rig.free()
			print("Rebound ", "legs" if legs_only else "arms", " for ", kit, "/", id)
	quit()

func write_weights(bones: PackedInt32Array, weights: PackedFloat32Array, start: int, rebound: Dictionary) -> void:
	var ordered := rebound.keys()
	ordered.sort_custom(func(a: int, b: int) -> bool: return rebound[a] > rebound[b])
	var total := 0.0
	for k in range(4):
		var bone: int = ordered[k] if k < ordered.size() else 0
		bones[start + k] = bone
		var weight: float = rebound[bone] if k < ordered.size() else 0.0
		weights[start + k] = weight
		total += weight
	for k in range(4):
		weights[start + k] /= total

func fit_legs(id: String, sk: Skeleton3D, points: PackedVector3Array, adjacency: Array[PackedInt32Array], bones: PackedInt32Array, weights: PackedFloat32Array) -> bool:
	var fit: Array = LEG_FITS[id]
	var ceiling: float = fit[0]
	var sides := PackedInt32Array()
	sides.resize(points.size())
	sides.fill(-1)
	for side in range(2):
		var chain: Array = fit[3 + side]
		var ankle: Vector3 = chain[2]
		var seed := -1
		var distance := INF
		for i in range(points.size()):
			if points[i].y <= .08 and points[i].distance_squared_to(ankle) < distance:
				distance = points[i].distance_squared_to(ankle)
				seed = i
		if seed < 0 or sides[seed] != -1:
			return false
		var queue: Array[int] = [seed]
		sides[seed] = side
		var cursor := 0
		while cursor < queue.size():
			var vertex := queue[cursor]
			cursor += 1
			for neighbor in adjacency[vertex]:
				if points[neighbor].y < ceiling and sides[neighbor] == -1:
					sides[neighbor] = side
					queue.append(neighbor)
		for joint in range(3):
			var bone := 9 + side * 3 + joint
			var parent := sk.get_bone_global_rest(sk.get_bone_parent(bone))
			sk.set_bone_rest(bone, Transform3D(Basis.IDENTITY, parent.affine_inverse() * chain[joint]))
	sk.reset_bone_poses()
	var hip_left: Vector3 = fit[3][0]
	var hip_right: Vector3 = fit[4][0]
	var lateral := (hip_right - hip_left).normalized()
	for i in range(points.size()):
		var point := points[i]
		if point.y >= float(fit[2]):
			continue
		var side := sides[i]
		if side < 0:
			# Keep the Sabotador's dangling cables on the torso instead of either leg.
			if point.y < ceiling or (id == "saboteur" and absf(point.x) > .25):
				write_weights(bones, weights, i * 4, {0: 1.0})
				continue
			side = 0 if (point - (hip_left + hip_right) * .5).dot(lateral) < 0 else 1
		var leg := 9 + side * 3
		var knee: Vector3 = fit[3 + side][1]
		var ankle: Vector3 = fit[3 + side][2]
		var hip := smoothstep(float(fit[1]), float(fit[2]), point.y)
		var shin := 1.0 - smoothstep(knee.y - .065, knee.y + .065, point.y)
		var foot := 1.0 - smoothstep(ankle.y - .035, ankle.y + .065, point.y)
		write_weights(bones, weights, i * 4, {
			0: hip, leg: (1.0 - hip) * (1.0 - shin),
			leg + 1: (1.0 - hip) * shin * (1.0 - foot), leg + 2: (1.0 - hip) * shin * foot,
		})
	return true

func body_weights(point: Vector3, bones: PackedInt32Array, weights: PackedFloat32Array, start: int) -> Dictionary:
	var body := {}
	var total := 0.0
	for k in range(start, start + 4):
		var bone := bones[k]
		if bone in [3, 4, 5, 6, 7, 8] or weights[k] <= 0.0:
			continue
		body[bone] = weights[k]
		total += weights[k]
	if total <= .001:
		return {0 if point.y < .69 else 1: 1.0}
	for bone in body:
		body[bone] /= total
	return body


func mesh_edges(points: PackedVector3Array, indices: PackedInt32Array) -> Array[PackedInt32Array]:
	var edges: Array[PackedInt32Array] = []
	edges.resize(points.size())
	var coincident := {}
	for i in range(points.size()):
		var key := points[i].snapped(Vector3.ONE * .00005)
		if coincident.has(key):
			var previous: int = coincident[key]
			edges[previous].append(i)
			edges[i].append(previous)
		else:
			coincident[key] = i
	for i in range(0, indices.size(), 3):
		for corner in range(3):
			var a := indices[i + corner]
			var b := indices[i + (corner + 1) % 3]
			edges[a].append(b)
			edges[b].append(a)
	return edges

func arm_island(points: PackedVector3Array, adjacency: Array[PackedInt32Array], limb: Array, id: String) -> PackedInt32Array:
	# Below a cross-section, the hands of the neutral meshes form their own
	# connected surfaces. Follow triangles to include fingertips and inner palms
	# even when they are closer to the thigh than to the wrist.
	var palm: Vector3 = limb[3]
	var wrist: Vector3 = limb[2]
	var elbow: Vector3 = limb[1]
	var ceiling := maxf(wrist.y, elbow.y) - .035
	if id == "titan16":
		ceiling = 1.16
	elif id == "walker":
		ceiling = 1.22 if palm.x < 0 else .80
	var result := PackedInt32Array()
	result.resize(points.size())
	result.fill(-1)
	var seed := -1
	var best := .08
	for i in range(points.size()):
		if points[i].y >= ceiling:
			continue
		var distance := points[i].distance_squared_to(palm)
		if distance < best:
			best = distance
			seed = i
	if seed < 0:
		return result
	var pending := [seed]
	result[seed] = 1
	var current := 0
	while current < pending.size():
		var vertex: int = pending[current]
		current += 1
		if points[vertex].y < .225:
			# Fused source meshes require the soft fit across that joint.
			result.fill(-1)
			return result
		for neighbor in adjacency[vertex]:
			if result[neighbor] < 0 and points[neighbor].y < ceiling:
				result[neighbor] = 1
				pending.append(neighbor)
	for i in range(points.size()):
		if points[i].y < ceiling and result[i] < 0:
			result[i] = 0
	return result
