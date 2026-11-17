extends SceneTree
## Separates connected tier kits and clips the swivel seams, preserving atlas UVs.
var config := ""
var parents: PackedInt32Array
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--config="): config = arg.trim_prefix("--config=")
	call_deferred("run")
func root_of(i: int) -> int:
	while parents[i]!=i: parents[i] = parents[parents[i]]; i = parents[i]
	return i
func join(a: int,b: int) -> void: parents[root_of(a)] = root_of(b)
func vector(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func mix_vertex(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
	return {"p":a.p.lerp(b.p,t),"n":a.n.lerp(b.n,t).normalized(),"uv":a.uv.lerp(b.uv,t)}
func clip(poly: Array,height: float,above: bool,axis: int = 1) -> Array:
	var result := []
	for i in range(poly.size()):
		var a: Dictionary = poly[i]; var b: Dictionary = poly[(i+1)%poly.size()]
		var ai: bool = a.p[axis]>=height if above else a.p[axis]<=height
		var bi: bool = b.p[axis]>=height if above else b.p[axis]<=height
		if ai: result.append(a)
		if ai!=bi: result.append(mix_vertex(a,b,(height-a.p[axis])/(b.p[axis]-a.p[axis])))
	return result
func normalized(p: Vector3,level: Dictionary,part: int) -> Vector3:
	var value := ((p-vector(level.center))*float(level.scale)).rotated(Vector3.UP,-PI/2)
	if part>0: value -= vector(level.pivot)
	if part==2: value = (value-vector(level.get("pitch_offset",[0,0,0]))).rotated(Vector3.RIGHT,-deg_to_rad(float(level.rest_pitch)))
	return value
func normal(p: Vector3,level: Dictionary,part: int) -> Vector3:
	var value := p.rotated(Vector3.UP,-PI/2)
	if part==2: value = value.rotated(Vector3.RIGHT,-deg_to_rad(float(level.rest_pitch)))
	return value
func emit(surface: SurfaceTool,poly: Array,level: Dictionary,part: int) -> void:
	for i in range(1,poly.size()-1):
		for vertex in [poly[0],poly[i],poly[i+1]]:
			surface.set_normal(normal(vertex.n,level,part)); surface.set_uv(vertex.uv); surface.add_vertex(normalized(vertex.p,level,part))
func texture_file(texture: Texture2D,dest: String) -> bool:
	if texture==null: return false
	var image := texture.get_image(); image.clear_mipmaps()
	return (image.save_png(dest) if dest.ends_with(".png") else image.save_jpg(dest,.92))==OK
func run() -> void:
	var jobs = JSON.parse_string(FileAccess.get_file_as_string(config))
	var report := []
	for job in jobs:
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(str(job.input)+".json"))
		if not manifest is Dictionary or manifest.get("source_sha256","")!=job.source_sha256 or manifest.get("output_sha256","")!=FileAccess.get_sha256(job.input) or int(manifest.get("triangles",0))!=int(job.triangles): push_error("Prepared source changed: "+str(job.id)); quit(1); return
		var doc := GLTFDocument.new(); var state := GLTFState.new()
		if doc.append_from_file(job.input,state)!=OK: quit(1); return
		var source := doc.generate_scene(state); var node: MeshInstance3D = source.find_children("*","MeshInstance3D",true,false)[0]
		var arrays: Array = node.mesh.surface_get_arrays(0); var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		parents.resize(positions.size()); var welded := {}
		for i in range(positions.size()):
			parents[i] = i; var v := positions[i]*100000; var key := Vector3i(roundi(v.x),roundi(v.y),roundi(v.z))
			if welded.has(key): join(i,welded[key])
			else: welded[key] = i
		for i in range(0,indices.size(),3): join(indices[i],indices[i+1]); join(indices[i],indices[i+2])
		var components := {}
		for i in range(positions.size()):
			var id := root_of(i)
			if not components.has(id): components[id] = {"id":id,"minx":positions[i].x}
			components[id].minx = minf(components[id].minx,positions[i].x)
		var groups := components.values(); groups.sort_custom(func(a,b): return a.minx<b.minx)
		if groups.size()!=job.levels.size(): push_error("Tier components changed: "+str(job.id)); source.free(); quit(1); return
		var out := "res://assets/defenses/"+str(job.id)+"/"; DirAccess.make_dir_recursive_absolute(out)
		var imported: StandardMaterial3D = node.mesh.surface_get_material(0)
		if not texture_file(imported.albedo_texture,out+"albedo.jpg") or not texture_file(imported.normal_texture,out+"normal.png") or not texture_file(imported.roughness_texture,out+"rough_metal.jpg"): source.free(); quit(1); return
		var material := imported.duplicate() as StandardMaterial3D
		# Use external textures after editor import; avoids embedding full atlases per mesh.
		material.albedo_texture = null; material.normal_texture = null; material.roughness_texture = null; material.metallic_texture = null
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		material.roughness = .9; material.metallic = .25
		if ResourceSaver.save(material,out+"material.tres")!=OK: quit(1); return
		# Write explicit external resource references so imports can happen in a clean checkout.
		var material_path := ProjectSettings.globalize_path(out+"material.tres")
		var text := FileAccess.get_file_as_string(material_path)
		text = text.replace('[resource]','[ext_resource type="Texture2D" path="'+out+'albedo.jpg" id="1"]\n[ext_resource type="Texture2D" path="'+out+'normal.png" id="2"]\n[ext_resource type="Texture2D" path="'+out+'rough_metal.jpg" id="3"]\n\n[resource]')
		text += '\nalbedo_texture = ExtResource("1")\nnormal_texture = ExtResource("2")\nroughness_texture = ExtResource("3")\nmetallic_texture = ExtResource("3")\n'
		var file := FileAccess.open(material_path,FileAccess.WRITE); file.store_string(text); file.close()
		var job_report := {"id":job.id,"input_triangles":indices.size()/3,"levels":[]}; var seen := 0
		for lv in range(job.levels.size()):
			var level: Dictionary = job.levels[lv]; var scene := Node3D.new(); scene.name = str(job.id)+"_N"+str(lv+1); scene.set_meta("tier",lv+1); scene.set_meta("source","Tripo/user submission")
			var head: Node3D; var pitch: Node3D
			if job.id!="core":
				head = Node3D.new(); pitch = Node3D.new()
				head.name = "Head"; head.position = vector(level.pivot); scene.add_child(head); head.owner = scene; pitch.name = "Pitch"; pitch.position = vector(level.get("pitch_offset",[0,0,0])); head.add_child(pitch); pitch.owner = scene
			var counts := []; var input_count := 0
			var parts := 3 if job.id in ["cannon","raised_turret"] else 1
			for part in range(parts):
				var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				for i in range(0,indices.size(),3):
					if root_of(indices[i])!=int(groups[lv].id): continue
					if part==0: input_count += 1; seen += 1
					var poly := []
					for k in range(3):
						var old := indices[i+k]; assert(root_of(old)==int(groups[lv].id)); poly.append({"p":positions[old],"n":arrays[Mesh.ARRAY_NORMAL][old],"uv":arrays[Mesh.ARRAY_TEX_UV][old]})
					if parts==3:
						if job.id=="raised_turret":
							if part==0: poly = clip(poly,float(level.base_cut),false)
							else: poly = clip(clip(poly,float(level.base_cut),true),float(level.barrel_cut),part==1,0)
						elif part==0: poly = clip(poly,float(level.base_cut),false)
						elif part==1: poly = clip(clip(poly,float(level.base_cut),true),float(level.gun_cut),false)
						else: poly = clip(poly,float(level.gun_cut),true)
					if poly.size()>=3: emit(surface,poly,level,part)
				surface.index(); surface.generate_tangents(); var mesh := surface.commit()
				if mesh==null: push_error("Empty part"); scene.free(); source.free(); quit(1); return
				var count := mesh.surface_get_array_index_len(0)/3; counts.append(count)
				# Stable path references; resource resolved after import.
				var mesh_path: String = out+["base_","swivel_","gun_"][part]+str(lv+1)+".res"
				if ResourceSaver.save(mesh,mesh_path,ResourceSaver.FLAG_COMPRESS)!=OK: quit(1); return
				var instance := MeshInstance3D.new(); instance.name = ["Base","Swivel","Gun"][part]; instance.mesh = load(mesh_path)
				(scene if part==0 else head if part==1 else pitch).add_child(instance); instance.owner = scene
			if job.id!="core":
				for i in range(level.muzzles.size()):
					var marker := Marker3D.new(); marker.name = "Muzzle"+str(i+1); pitch.add_child(marker); marker.owner = scene; marker.position = vector(level.muzzles[i])
			var packed := PackedScene.new(); assert(packed.pack(scene)==OK)
			var scene_path := "res://assets/fortress/"+str(job.id)+"_"+str(lv+1)+".tscn"; assert(ResourceSaver.save(packed,scene_path)==OK)
			# Link each mesh instance to the shared material without needing a pre-existing import cache.
			var scene_text := FileAccess.get_file_as_string(scene_path)
			var first_node := scene_text.find('[node name='); scene_text = scene_text.insert(first_node,'[ext_resource type="Material" path="'+out+'material.tres" id="material"]\n\n')
			var scene_lines := PackedStringArray()
			for line in scene_text.split('\n'):
				scene_lines.append(line)
				if line.begins_with('mesh = '): scene_lines.append('surface_material_override/0 = ExtResource("material")')
			scene_text = '\n'.join(scene_lines)
			file = FileAccess.open(scene_path,FileAccess.WRITE); file.store_string(scene_text); file.close()
			job_report.levels.append({"tier":lv+1,"input_triangles":input_count,"part_triangles":counts,"muzzles":level.get("muzzles",[]).size(),"pivot":level.get("pivot",[]),"scale":level.scale}); scene.free()
		assert(seen==indices.size()/3); report.append(job_report); source.free(); print("BUILT: "+JSON.stringify(job_report))
	var file := FileAccess.open("res://assets/defenses/tripo16-geometry.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close(); quit()
