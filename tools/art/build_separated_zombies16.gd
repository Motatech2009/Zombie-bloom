extends SceneTree
## Bake the creator's separated GLBs into the gameplay scenes and shared RC9 atlas.
## godot --headless --path . --script res://tools/art/build_separated_zombies16.gd -- /path/to/ZombieBloom_Modelos_Separados

const OUT := "res://assets/enemies/tripo16/zombies/"
const RIG := preload("res://scripts/presentation/clay_enemy16.gd")
const MODELS := {
	"walker": "errante", "runner": "corredor", "brute": "bruto",
	"armored": "blindado", "demolisher": "demolidor", "spitter": "corrosivo",
	"hound": "cao_infectado", "flyer": "asa_infectada", "alpha_legacy": "colosso_alfa",
	"burster": "estourador", "screamer": "berrador", "mender": "revestidor",
	"cryo": "criogenico", "charger": "investidor", "saboteur": "sabotador",
	"lobber": "lancador_de_esporos", "cleaver": "cutelo",
	"shieldbearer": "escudeiro", "bridge": "ponte_de_carne",
}
# Hip height by anatomy. Some models have short legs or gear above the head.
const HIP_HEIGHT := {
	"walker": .44, "runner": .46, "brute": .32, "armored": .44,
	"demolisher": .40, "spitter": .34, "alpha_legacy": .30, "burster": .23,
	"screamer": .35, "mender": .34, "charger": .36, "cryo": .37,
	"saboteur": .37, "lobber": .32, "cleaver": .33, "shieldbearer": .34, "bridge": .42,
}
# The primary fixes use per-side knee and ankle landmarks from the supplied mesh.
# Coordinates here use the game-facing axes and the source GLB's 2.2 unit scale.
const LEG_LANDMARKS := {
	"walker": [
		Vector3(-.18, .46, .06), Vector3(-.16, .14, .11),
		Vector3(.16, .46, .02), Vector3(.14, .14, .04),
	],
	"armored": [
		Vector3(-.20, .46, .09), Vector3(-.19, .13, .02),
		Vector3(.18, .46, .09), Vector3(.17, .13, .02),
	],
	"charger": [
		Vector3(-.18, .41, .02), Vector3(-.20, .13, .01),
		Vector3(.14, .41, .04), Vector3(.17, .13, .00),
	],
}
const HUMAN_NAMES := [
	"Pelvis", "Spine", "Head", "ArmL", "ForearmL", "HandL", "ArmR",
	"ForearmR", "HandR", "LegL", "ShinL", "FootL", "LegR", "ShinR", "FootR",
]
const HUMAN_PARENTS := [-1, 0, 1, 1, 3, 4, 1, 6, 7, 0, 9, 10, 0, 12, 13]
const DOG_NAMES := [
	"Pelvis", "Spine", "Head", "LegFL", "LegFR", "LegBL", "LegBR",
	"FootFL", "FootFR", "FootBL", "FootBR",
]
const DOG_PARENTS := [-1, 0, 1, 1, 1, 1, 1, 3, 4, 5, 6]
const TRIANGLE_BUDGET := 3000

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Pass the directory containing the separated GLBs.")
		quit(1)
		return
	for id: String in MODELS:
		var source := args[0].path_join(MODELS[id] + ".glb")
		if not FileAccess.file_exists(source):
			printerr("Missing source: ", source)
			quit(1)
			return

	var report_path := OUT.trim_suffix("/").get_base_dir().path_join("geometry.json")
	var previous: Array = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	var report: Array = []
	for id: String in MODELS:
		var path := args[0].path_join(MODELS[id] + ".glb")
		var info := bake_model(path, id)
		if info.is_empty():
			printerr("Failed to bake ", id)
			quit(1)
			return
		report.append(info)
	report.append_array(previous.filter(func(row: Dictionary) -> bool: return row.kit == "bosses"))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	quit()

func bake_model(path: String, id: String) -> Dictionary:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image = GLTFState.HANDLE_BINARY_DISCARD_TEXTURES
	if document.append_from_file(path, state) != OK:
		return {}
	var source := document.generate_scene(state)
	var source_mesh := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var data := source_mesh.mesh.surface_get_arrays(0)
	source.free()

	var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
	var profile := "dog" if id == "hound" else "flyer" if id == "flyer" else "human"
	var height := .95 if profile == "dog" else .75 if profile == "flyer" else 1.9
	var factor := height / source_mesh_height(points)
	var flip := Vector3(-1, 1, -1)
	var fit := AABB(points[0] * flip * factor, Vector3.ZERO)
	for i in range(points.size()):
		points[i] *= flip * factor
		normals[i] *= flip
		fit = fit.expand(points[i])
	var skeleton := make_skeleton(points, fit, profile, id, factor)

	# Choose the highest-detail LOD inside the horde rendering budget.
	var geometry := []
	geometry.resize(Mesh.ARRAY_MAX)
	geometry[Mesh.ARRAY_VERTEX] = points
	geometry[Mesh.ARRAY_NORMAL] = normals
	geometry[Mesh.ARRAY_TEX_UV] = uvs
	geometry[Mesh.ARRAY_INDEX] = data[Mesh.ARRAY_INDEX]
	var lods := ImporterMesh.new()
	lods.add_surface(Mesh.PRIMITIVE_TRIANGLES, geometry)
	lods.generate_lods(60, 25, [])
	var indices := PackedInt32Array()
	for i in range(lods.get_surface_lod_count(0)):
		var lod := lods.get_surface_lod_indices(0, i)
		if lod.size() <= TRIANGLE_BUDGET * 3 and lod.size() > indices.size():
			indices = lod
	if indices.is_empty():
		skeleton.free()
		return {}
	geometry = lods.get_surface_arrays(0)
	points = geometry[Mesh.ARRAY_VERTEX]
	normals = geometry[Mesh.ARRAY_NORMAL]
	uvs = geometry[Mesh.ARRAY_TEX_UV]
	var cut_sides := PackedInt32Array()
	if LEG_LANDMARKS.has(id):
		var left := skeleton.get_bone_global_rest(9).origin
		var right := skeleton.get_bone_global_rest(12).origin
		var seam := (left.x + right.x) * .5 + .00037
		var cut := separate_legs(geometry, indices, seam, left.y, false)
		if cut.indices.size() > TRIANGLE_BUDGET * 3:
			cut = separate_legs(geometry, indices, seam, left.y, true)
		points = cut.points
		normals = cut.normals
		uvs = cut.uvs
		indices = cut.indices
		cut_sides = cut.sides
	if indices.size() > TRIANGLE_BUDGET * 3:
		printerr(id, " exceeded the triangle budget: ", indices.size() / 3)
		skeleton.free()
		return {}

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var remap := {}
	for index in indices:
		if not remap.has(index):
			remap[index] = remap.size()
			var weights := get_weights(points[index], skeleton, fit, profile, id, cut_sides[index] if not cut_sides.is_empty() else -1)
			var bones := PackedInt32Array([0, 0, 0, 0])
			var values := PackedFloat32Array([0, 0, 0, 0])
			var sorted := weights.keys()
			sorted.sort_custom(func(a: int, b: int) -> bool: return weights[a] > weights[b])
			var total := 0.0
			for i in range(mini(4, sorted.size())):
				bones[i] = sorted[i]
				values[i] = weights[bones[i]]
				total += values[i]
			surface.set_bones(bones)
			for i in range(4):
				values[i] /= total
			surface.set_weights(values)
			surface.set_normal(normals[index])
			surface.set_uv(uvs[index])
			surface.add_vertex(points[index])
		surface.add_index(remap[index])
	surface.generate_tangents()
	var mesh := surface.commit()
	var mesh_path := OUT + id + ".res"
	if ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS) != OK:
		skeleton.free()
		return {}

	var rig := Node3D.new()
	rig.name = "ClayEnemy16"
	rig.set_script(RIG)
	rig.set_meta("imported_enemy16", true)
	rig.set_meta("model_id16", id)
	rig.set_meta("profile16", profile)
	rig.set_meta("separated_source16", MODELS[id])
	rig.add_child(skeleton)
	skeleton.owner = rig
	var model := MeshInstance3D.new()
	model.name = "Character"
	model.mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	skeleton.add_child(model)
	model.owner = rig
	model.skeleton = NodePath("..")
	model.skin = skeleton.create_skin_from_rest_transforms()
	model.custom_aabb = fit.grow(.5)
	model.set_surface_override_material(0, load(OUT + "material.tres"))

	var controls := ["ArmL", "ArmR", "LegL", "LegR"]
	if profile == "flyer":
		controls.append_array(["WingL", "WingR"])
	elif profile == "dog":
		controls.append_array(["LegFL", "LegFR", "LegBL", "LegBR"])
	for control in controls:
		var node := Node3D.new()
		node.name = control
		rig.add_child(node)
		node.owner = rig

	var packed := PackedScene.new()
	var result := packed.pack(rig)
	if result == OK:
		result = ResourceSaver.save(packed, OUT + id + ".tscn")
	var bones_count := skeleton.get_bone_count()
	rig.free()
	if result != OK:
		return {}
	print("BAKED ", id, " triangles=", indices.size() / 3, " bones=", bones_count)
	return {
		"kit": "zombies", "id": id, "source": MODELS[id] + ".glb",
		"sha256": FileAccess.get_sha256(path), "triangles": indices.size() / 3,
		"bones": bones_count, "bounds": str(fit), "profile": profile,
	}

# The source boots share triangles between the two feet. Duplicate the center
# cut, give each side its own weights, and close the exposed inner surfaces.
func separate_legs(geometry: Array, index: PackedInt32Array, seam: float, hip_height: float, simplify_caps: bool) -> Dictionary:
	var points: PackedVector3Array = geometry[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = geometry[Mesh.ARRAY_NORMAL].duplicate()
	var uvs: PackedVector2Array = geometry[Mesh.ARRAY_TEX_UV].duplicate()
	var sides := PackedInt32Array()
	for point in points:
		sides.append(0 if point.x < seam else 1)
	var result := PackedInt32Array()
	var cut_vertices := {}
	var outlines := {}
	var cut_uvs := {}
	for face in range(0, index.size(), 3):
		var a := index[face]
		var b := index[face + 1]
		var c := index[face + 2]
		if sides[a] == sides[b] and sides[b] == sides[c]:
			result.append_array([a, b, c])
			continue
		var poly := [[], []]
		var segment: Array[Vector2i] = []
		var corners := [a, b, c]
		for edge in range(3):
			var first: int = corners[edge]
			var second: int = corners[(edge + 1) % 3]
			var side := sides[first]
			poly[side].append(first)
			if side == sides[second]:
				continue
			var key := Vector2i(mini(first, second), maxi(first, second))
			if not cut_vertices.has(key):
				var t := (seam - points[first].x) / (points[second].x - points[first].x)
				var point := points[first].lerp(points[second], t)
				var normal := normals[first].lerp(normals[second], t).normalized()
				var uv := uvs[first].lerp(uvs[second], t)
				var outline := Vector2i(roundi(point.y * 10000), roundi(point.z * 10000))
				cut_uvs[outline] = uv
				cut_vertices[key] = [points.size(), outline]
				for cut_side in range(2):
					points.append(point)
					normals.append(normal)
					uvs.append(uv)
					sides.append(cut_side)
			var cut: Array = cut_vertices[key]
			poly[side].append(cut[0] + side)
			poly[1 - side].append(cut[0] + 1 - side)
			segment.append(cut[1])
		if minf(points[a].y, minf(points[b].y, points[c].y)) >= hip_height:
			result.append_array([a, b, c])
		else:
			for part: Array in poly:
				for i in range(1, part.size() - 1):
					result.append_array([part[0], part[i], part[i + 1]])
		if segment[0] != segment[1]:
			for i in range(2):
				var from := segment[i]
				var to := segment[1 - i]
				if not outlines.has(from):
					outlines[from] = []
				if to not in outlines[from]:
					outlines[from].append(to)
	for loop in closed_outlines(outlines):
		var contour := PackedVector2Array()
		for point: Vector2i in loop:
			contour.append(Vector2(point) / 10000.0)
		# The cap stops where both sides share the pelvis weight.
		var below_hip := PackedVector2Array([
			Vector2(-4, -4), Vector2(hip_height, -4),
			Vector2(hip_height, 4), Vector2(-4, 4),
		])
		for raw_cap in Geometry2D.intersect_polygons(contour, below_hip):
			var cap: PackedVector2Array = simplify_cap(raw_cap) if simplify_caps else raw_cap
			var triangles := Geometry2D.triangulate_polygon(cap)
			if triangles.is_empty():
				continue
			for side in range(2):
				var start := points.size()
				for vertex in cap:
					points.append(Vector3(seam, vertex.x, vertex.y))
					normals.append(Vector3.RIGHT if side == 0 else Vector3.LEFT)
					var nearest: Vector2i = loop[0]
					var quantized := Vector2i((vertex * 10000.0).round())
					for candidate: Vector2i in loop:
						if candidate.distance_squared_to(quantized) < nearest.distance_squared_to(quantized):
							nearest = candidate
					uvs.append(cut_uvs[nearest])
					sides.append(side)
				for i in range(0, triangles.size(), 3):
					var first := start + triangles[i]
					var second := start + triangles[i + 1]
					var third := start + triangles[i + 2]
					var ccw := (points[second] - points[first]).cross(points[third] - points[first]).x > 0
					if ccw == (side == 0):
						result.append_array([first, third, second])
					else:
						result.append_array([first, second, third])
	return {"points": points, "normals": normals, "uvs": uvs, "sides": sides, "indices": result}

func simplify_cap(contour: PackedVector2Array) -> PackedVector2Array:
	var result := contour.duplicate()
	var i := 0
	while result.size() > 3 and i < result.size():
		var previous := result[(i + result.size() - 1) % result.size()]
		var next := result[(i + 1) % result.size()]
		var closest := Geometry2D.get_closest_point_to_segment(result[i], previous, next)
		if result[i].distance_squared_to(closest) < .00002025:
			result.remove_at(i)
		else:
			i += 1
	return result

func closed_outlines(graph: Dictionary) -> Array:
	var seen := {}
	var loops := []
	for start: Vector2i in graph:
		if seen.has(start) or graph[start].size() != 2:
			continue
		var loop: Array[Vector2i] = []
		var point := start
		var previous: Vector2i = graph[start][0]
		while not seen.has(point) and graph[point].size() == 2:
			seen[point] = true
			loop.append(point)
			var next: Vector2i = graph[point][0] if graph[point][0] != previous else graph[point][1]
			previous = point
			point = next
		if point == start and loop.size() > 2:
			loops.append(loop)
	return loops

func source_mesh_height(points: PackedVector3Array) -> float:
	var height := 0.0
	for point in points:
		height = maxf(height, point.y)
	return height

func make_skeleton(points: PackedVector3Array, fit: AABB, profile: String, id: String, factor: float) -> Skeleton3D:
	var h := fit.size.y
	if profile == "flyer":
		var shoulder := h * .37
		return make_bones(
			["Pelvis", "Spine", "Head", "WingL", "WingR"], [-1, 0, 1, 1, 1],
			[Vector3(0, h * .52, 0), Vector3(0, h * .59, 0), Vector3(0, h * .73, -.22),
			Vector3(-shoulder, h * .61, 0), Vector3(shoulder, h * .61, 0)]
		)
	if profile == "dog":
		# The hind paws are higher in the source pose and sit farther back than the forepaws.
		return make_bones(DOG_NAMES, DOG_PARENTS, [
			Vector3(0, .50, .16), Vector3(0, .54, .11), Vector3(0, .67, -.31),
			Vector3(-.14, .44, .08), Vector3(.14, .44, .08),
			Vector3(-.16, .47, .48), Vector3(.17, .47, .48),
			Vector3(-.15, .10, .15), Vector3(.13, .10, .13),
			Vector3(-.12, .17, .45), Vector3(.18, .17, .44),
		])

	var hips := h * float(HIP_HEIGHT[id])
	var shoulder := clampf(fit.size.x * .22, h * .12, h * .25)
	var chest_z := -.03
	var joints: Array[Vector3] = [
		Vector3(0, hips, 0), Vector3(0, h * .58, chest_z), Vector3(0, h * .80, chest_z),
		Vector3(-shoulder, h * .71, chest_z), Vector3(-shoulder * 1.16, h * .53, 0),
		Vector3(-shoulder * 1.27, h * .37, 0),
		Vector3(shoulder, h * .71, chest_z), Vector3(shoulder * 1.16, h * .53, 0),
		Vector3(shoulder * 1.27, h * .37, 0),
	]
	for side in [-1, 1]:
		var ankle := Vector3.ZERO
		var samples := 0
		for point in points:
			if point.y < h * .075 and point.x * side > 0.0:
				ankle += point
				samples += 1
		ankle = ankle / samples if samples else Vector3(side * h * .08, 0, 0)
		ankle.y = h * .075
		var knee := Vector3(ankle.x * .85, lerpf(ankle.y, hips, .52), ankle.z - h * .015)
		if LEG_LANDMARKS.has(id):
			var offset := 0 if side < 0 else 2
			knee = LEG_LANDMARKS[id][offset] * factor
			ankle = LEG_LANDMARKS[id][offset + 1] * factor
		joints.append(Vector3(knee.x * .84, hips, knee.z))
		joints.append(knee)
		joints.append(ankle)
	return make_bones(HUMAN_NAMES, HUMAN_PARENTS, joints)

func make_bones(names: Array, parents: Array, points: Array) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	for i in range(names.size()):
		var parent: int = parents[i]
		var pivot: Vector3 = points[i] - (points[parent] if parent >= 0 else Vector3.ZERO)
		skeleton.add_bone(names[i])
		skeleton.set_bone_parent(i, parent)
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, pivot))
	skeleton.reset_bone_poses()
	return skeleton

func get_weights(p: Vector3, sk: Skeleton3D, fit: AABB, profile: String, id: String, leg_side: int) -> Dictionary:
	var height := fit.size.y
	if profile == "flyer":
		var wing := smoothstep(height * .20, height * .66, absf(p.x))
		return {1: 1.0 - wing, 3 if p.x < 0 else 4: wing}
	if profile == "dog":
		var head := (1.0 - smoothstep(-.53, -.28, p.z)) * smoothstep(.32, .55, p.y)
		if head > .001:
			return {1: 1.0 - head, 2: head}
		var leg := (3 if p.x < 0 else 4) + (2 if p.z > .30 else 0)
		var hip := sk.get_bone_global_rest(leg).origin
		var paw := sk.get_bone_global_rest(leg + 4).origin
		var strength := 1.0 - smoothstep(hip.y * .61, hip.y * 1.19, p.y)
		strength *= 1.0 - smoothstep(.14, .31, absf(p.z - paw.z))
		var foot := 1.0 - smoothstep(paw.y, paw.y + .10, p.y)
		return {1: 1.0 - strength, leg: strength * (1.0 - foot), leg + 4: strength * foot}

	var pelvis := sk.get_bone_global_rest(0).origin
	var side := 3 if p.x < 0 else 6
	var shoulder := absf(sk.get_bone_rest(side).origin.x)
	var rear_kit := smoothstep(.08, .23, p.z) if id in ["charger", "lobber", "saboteur"] else 0.0
	var arm := smoothstep(shoulder * .77, shoulder * 1.45, absf(p.x))
	arm *= smoothstep(pelvis.y * .72, height * .48, p.y)
	arm *= (1.0 - smoothstep(height * .73, height * .82, p.y)) * (1.0 - rear_kit)
	if id == "charger":
		var breastplate := (1.0 - smoothstep(-.22, -.12, p.z)) * smoothstep(.72, .92, p.y)
		arm *= 1.0 - breastplate
	var weights := human_body_weights(p, sk, height, pelvis.y, rear_kit, leg_side)
	if arm > .001:
		var elbow := 1.0 - smoothstep(height * .47, height * .60, p.y)
		var hand := 1.0 - smoothstep(height * .33, height * .41, p.y)
		for bone in weights:
			weights[bone] *= 1.0 - arm
		weights[side] = arm * (1.0 - elbow)
		weights[side + 1] = arm * elbow * (1.0 - hand)
		weights[side + 2] = arm * elbow * hand
	return weights

func human_body_weights(p: Vector3, sk: Skeleton3D, height: float, hips: float, rear_kit: float, leg_side: int) -> Dictionary:
	if p.y >= hips:
		var spine := smoothstep(hips, maxf(hips + .1, height * .58), p.y)
		var head := smoothstep(height * .75, height * .86, p.y) * (1.0 - rear_kit)
		return {0: 1.0 - spine, 1: spine - head, 2: head}

	var left := sk.get_bone_global_rest(9).origin
	var right := sk.get_bone_global_rest(12).origin
	var center := (left.x + right.x) * .5
	var right_weight := float(leg_side) if leg_side >= 0 else smoothstep(center - height * .024, center + height * .024, p.x)
	var hip_weight := smoothstep(hips * .68, hips, p.y)
	var weights := {0: hip_weight}
	for leg in [9, 12]:
		var weight := (1.0 - hip_weight) * ((1.0 - right_weight) if leg == 9 else right_weight)
		var knee := sk.get_bone_global_rest(leg + 1).origin
		var ankle := sk.get_bone_global_rest(leg + 2).origin
		var shin := 1.0 - smoothstep(knee.y - height * .048, knee.y + height * .048, p.y)
		var foot := 1.0 - smoothstep(ankle.y - height * .023, ankle.y + height * .038, p.y)
		weights[leg] = weight * (1.0 - shin)
		weights[leg + 1] = weight * shin * (1.0 - foot)
		weights[leg + 2] = weight * shin * foot
	return weights
