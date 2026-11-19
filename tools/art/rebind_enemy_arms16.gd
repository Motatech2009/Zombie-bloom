extends SceneTree
## Reapply the arm fit to the existing compact meshes without touching textures or leg geometry.
## godot --headless --path . --script res://tools/art/rebind_enemy_arms16.gd

const Arms := preload("res://tools/art/enemy_arms16.gd")
const ROOT := "res://assets/enemies/tripo16/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for kit in ["zombies", "bosses"]:
		var directory: String = ROOT + kit + "/"
		for file in DirAccess.get_files_at(directory):
			var id := file.get_basename()
			if file.get_extension() != "tscn" or not Arms.LIMBS.has(id):
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
			var left := arm_island(points, adjacency, Arms.LIMBS[id][0], id)
			var right := arm_island(points, adjacency, Arms.LIMBS[id][1], id)
			for v in range(points.size()):
				var body := body_weights(points[v], bones, weights, v * 4)
				var rebound := Arms.relink(points[v], body, id, Vector2i(left[v], right[v]))
				var ordered := rebound.keys()
				ordered.sort_custom(func(a: int, b: int) -> bool: return rebound[a] > rebound[b])
				var total := 0.0
				for k in range(4):
					var bone: int = ordered[k] if k < ordered.size() else 0
					bones[v * 4 + k] = bone
					var weight: float = rebound[bone] if k < ordered.size() else 0.0
					weights[v * 4 + k] = weight
					total += weight
				for k in range(4):
					weights[v * 4 + k] /= total
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, original.surface_get_material(0))
			mesh.take_over_path(directory + id + ".res")
			assert(ResourceSaver.save(mesh, mesh.resource_path, ResourceSaver.FLAG_COMPRESS) == OK)
			model.mesh = mesh
			Arms.fit_skeleton(sk, id)
			model.skin = sk.create_skin_from_rest_transforms()
			var result := PackedScene.new()
			assert(result.pack(rig) == OK)
			assert(ResourceSaver.save(result, directory + file) == OK)
			rig.free()
			print("Rebound arms for ", kit, "/", id)
	quit()

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
