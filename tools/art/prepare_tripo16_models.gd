extends SceneTree
## Offline mesh reduction. Creator GLBs are hash-checked; no generation service is used.
var config := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--config="): config = arg.trim_prefix("--config=")
	call_deferred("run")
func resized(texture: Texture2D,size: int) -> Texture2D:
	if texture==null: return null
	var image := texture.get_image()
	image.clear_mipmaps(); image.resize(size,size,Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
func run() -> void:
	var jobs = JSON.parse_string(FileAccess.get_file_as_string(config))
	if not jobs is Array: push_error("Pass a JSON job array with --config="); quit(1); return
	for job in jobs:
		job.source = ProjectSettings.globalize_path(str(job.source)); job.output = ProjectSettings.globalize_path(str(job.output)); DirAccess.make_dir_recursive_absolute(str(job.output).get_base_dir())
		if FileAccess.get_sha256(job.source)!=job.sha256: push_error("Unexpected source: "+str(job.source)); quit(1); return
		var doc := GLTFDocument.new(); var state := GLTFState.new()
		if doc.append_from_file(job.source,state)!=OK: quit(1); return
		var original := doc.generate_scene(state); var instances := original.find_children("*","MeshInstance3D",true,false)
		if instances.size()!=1 or instances[0].mesh.get_surface_count()!=1: original.free(); push_error("Unexpected topology"); quit(1); return
		var mesh: Mesh = instances[0].mesh; var arrays: Array = mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]; var source_triangles := indices.size()/3
		var choices := []
		if source_triangles>int(job.budget):
			var im := ImporterMesh.new(); im.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},mesh.surface_get_material(0)); im.generate_lods(60,25,[])
			for lod in range(im.get_surface_lod_count(0)):
				var candidate := im.get_surface_lod_indices(0,lod); choices.append(candidate.size()/3)
				if indices.size()/3>int(job.budget) and candidate.size()/3<=int(job.budget): indices = candidate
			arrays = im.get_surface_arrays(0)
		if indices.size()/3>int(job.budget): original.free(); push_error("No suitable LOD"); quit(1); return
		var mapped := {}; var ids := []; var compact := PackedInt32Array()
		for old in indices:
			if not mapped.has(old): mapped[old] = ids.size(); ids.append(old)
			compact.append(int(mapped[old]))
		var data := []; data.resize(Mesh.ARRAY_MAX)
		for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
			if arrays[channel]==null: continue
			var target = arrays[channel].duplicate(); var stride := 4 if channel==Mesh.ARRAY_TANGENT else 1; target.resize(ids.size()*stride)
			for i in range(ids.size()):
				for j in range(stride): target[i*stride+j] = arrays[channel][int(ids[i])*stride+j]
			data[channel] = target
		data[Mesh.ARRAY_INDEX] = compact
		var material: StandardMaterial3D = mesh.surface_get_material(0).duplicate()
		material.albedo_texture = resized(material.albedo_texture,1024)
		material.normal_texture = resized(material.normal_texture,1024)
		var rm := resized(material.roughness_texture,1024); material.roughness_texture = rm; material.metallic_texture = rm
		var output := ArrayMesh.new(); output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data); output.surface_set_material(0,material)
		var stage := Node3D.new(); var instance := MeshInstance3D.new(); instance.mesh = output; stage.add_child(instance)
		var out_doc := GLTFDocument.new(); var out_state := GLTFState.new(); var error := out_doc.append_from_scene(stage,out_state)
		if error==OK: error = out_doc.write_to_filesystem(out_state,job.output)
		var report := {"source_sha256":job.sha256,"source_triangles":source_triangles,"lods":choices,"triangles":compact.size()/3,"vertices":ids.size(),"texture_size":1024,"error":error,"output_sha256":FileAccess.get_sha256(job.output)}
		var file := FileAccess.open(str(job.output)+".json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
		print("PREPARED: "+str(job.output)+" "+JSON.stringify(report)); stage.free(); original.free()
		if error!=OK: quit(1); return
	quit()
