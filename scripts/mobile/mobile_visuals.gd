class_name MobileVisuals
extends RefCounted
## Merge static pieces into one shared mesh per animated limb, keeping the rig.
static var batches: Dictionary = {}
static var batch_material: StandardMaterial3D

static func prewarm(world: Node3D) -> void:
	var holder := Node3D.new(); holder.visible = false; world.add_child(holder)
	var entries: Array = []
	for kind in range(15):
		if kind in [6,7]: continue
		var spec: Resource = CampaignData.enemy_spec(kind) if kind<9 else InfectedRoster.extra_spec(kind)
		entries.append({"model":kind,"key":str(kind)+spec.id})
	for kind in [3,5]: entries.append({"model":kind,"key":"8"+CampaignData.enemy_spec(kind).id})
	for entry in entries:
		if batches.has(entry.key+":0"): continue
		var rig: Node3D = load("res://assets/models/infected_"+str(entry.model)+".tscn").instantiate()
		holder.add_child(rig); ClayStyle.apply_tree(rig); compact(rig,entry.key)
		holder.remove_child(rig); rig.free()
	holder.queue_free()

static func material() -> StandardMaterial3D:
	if batch_material==null:
		batch_material = StandardMaterial3D.new()
		batch_material.vertex_color_use_as_albedo = true
		batch_material.roughness = .94
	return batch_material

static func compact(rig: Node3D,key: String) -> void:
	var groups: Array[Node3D] = [rig]
	for child in rig.get_children():
		if child is Node3D and not child is MeshInstance3D: groups.append(child)
	for i in range(groups.size()):
		var group: Node3D = groups[i]
		var parts: Array[MeshInstance3D] = []
		for child in group.get_children():
			if child is MeshInstance3D: parts.append(child)
		if parts.is_empty(): continue
		var cache_key := key+":"+str(i)
		if not batches.has(cache_key):
			var builder := SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for part in parts:
				var transform := group.global_transform.affine_inverse()*part.global_transform
				var normal_basis := transform.basis.inverse().transposed()
				var color: Color = part.material_override.albedo_color if part.material_override is StandardMaterial3D else Color.WHITE
				for surface in range(part.mesh.get_surface_count()):
					var arrays := part.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
					for vertex in range(indices.size() if not indices.is_empty() else vertices.size()):
						var index := indices[vertex] if not indices.is_empty() else vertex
						builder.set_color(color)
						builder.set_normal((normal_basis*normals[index]).normalized())
						builder.add_vertex(transform*vertices[index])
			batches[cache_key] = builder.commit()
		for part in parts: group.remove_child(part); part.queue_free()
		var batch := MeshInstance3D.new(); batch.name = "MobileBatch"
		batch.mesh = batches[cache_key]; batch.material_override = material()
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(batch)
	rig.set_meta("mobile_batch",true)
