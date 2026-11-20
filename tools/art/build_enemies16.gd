extends SceneTree
const OUT := "res://assets/enemies/tripo16/"
var folder := ""
func _initialize() -> void:
	folder = OS.get_cmdline_user_args()[0]
	call_deferred("run")
func part_arrays(arrays: Array,ids: PackedInt32Array,center: Vector3,factor: float,budget: int) -> Array:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for id in ids:
		var p: Vector3 = arrays[Mesh.ARRAY_VERTEX][id]-center
		var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][id]
		surface.set_normal(Vector3(-n.x,n.y,-n.z)); surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][id]); surface.add_vertex(Vector3(-p.x,p.y,-p.z)*factor)
	surface.index(); surface.generate_tangents()
	var mesh := surface.commit()
	var result := mesh.surface_get_arrays(0)
	if ids.size()/3>budget:
		var im := ImporterMesh.new(); im.add_surface(Mesh.PRIMITIVE_TRIANGLES,result); im.generate_lods(60,25,[])
		var selected: PackedInt32Array = result[Mesh.ARRAY_INDEX]
		for lod in range(im.get_surface_lod_count(0)):
			var candidate := im.get_surface_lod_indices(0,lod)
			if selected.size()/3>budget and candidate.size()/3<=budget: selected = candidate
		result = im.get_surface_arrays(0); result[Mesh.ARRAY_INDEX] = selected
	return result
func normalized_weights(w: Dictionary) -> Dictionary:
	var total := 0.0
	for value in w.values(): total += float(value)
	for key in w: w[key] = float(w[key])/maxf(.0001,total)
	return w
func influences(p: Vector3,profile: String,box: AABB) -> Dictionary:
	var h := box.size.y
	if profile=="flyer":
		var wing := smoothstep(.16,.42,absf(p.x))
		if wing>0: return {1:1-wing,3 if p.x<0 else 4:wing}
		var head := 1-smoothstep(-.32,-.16,p.z)
		return {1:1-head,2:head}
	if profile=="dog":
		var leg := 1-smoothstep(h*.20,h*.48,p.y)
		var side := 0 if p.x<0 else 1
		var front := 0 if p.z<0 else 2
		if leg>0: return {1:1-leg,3+side+front:leg}
		var head := (1-smoothstep(-box.size.z*.18,box.size.z*.04,p.z))*smoothstep(h*.35,h*.62,p.y)
		return {1:1-head,2:head}
	var side := 3 if p.x<0 else 6
	var head := smoothstep(h*.75,h*.84,p.y)
	if head>0: return {1:1-head,2:head}
	var arm := smoothstep(box.size.x*.21,box.size.x*.34,absf(p.x))*smoothstep(h*.30,h*.44,p.y)*(1-smoothstep(h*.81,h*.87,p.y))
	if arm>.001:
		var elbow := 1-smoothstep(h*.46,h*.63,p.y)
		var hand := 1-smoothstep(h*.34,h*.44,p.y)
		return normalized_weights({1:1-arm,side:arm*(1-elbow),side+1:arm*elbow*(1-hand),side+2:arm*elbow*hand})
	if p.y<h*.48:
		var leg := 9 if p.x<0 else 12
		var hips := smoothstep(h*.38,h*.48,p.y)
		var knee := 1-smoothstep(h*.19,h*.29,p.y)
		var ankle := 1-smoothstep(h*.06,h*.11,p.y)
		return normalized_weights({0:hips,leg:(1-hips)*(1-knee),leg+1:(1-hips)*knee*(1-ankle),leg+2:(1-hips)*knee*ankle})
	return {0:1-smoothstep(h*.40,h*.55,p.y),1:smoothstep(h*.40,h*.55,p.y)}
func skeleton_data(profile: String,box: AABB) -> Dictionary:
	var h := box.size.y
	if profile=="dog":
		var x := box.size.x*.31; var z := box.size.z*.25
		return {"names":["Pelvis","Spine","Head","LegFL","LegFR","LegBL","LegBR"],"parents":[-1,0,1,1,1,1,1],"points":[Vector3(0,h*.5,0),Vector3(0,h*.55,0),Vector3(0,h*.68,-z),Vector3(-x,h*.45,-z),Vector3(x,h*.45,-z),Vector3(-x,h*.45,z),Vector3(x,h*.45,z)]}
	if profile=="flyer":
		return {"names":["Pelvis","Spine","Head","WingL","WingR"],"parents":[-1,0,1,1,1],"points":[Vector3(0,h*.5,0),Vector3(0,h*.5,0),Vector3(0,h*.65,-.2),Vector3(-.16,h*.55,0),Vector3(.16,h*.55,0)]}
	var shoulder := box.size.x*.25
	return {"names":["Pelvis","Spine","Head","ArmL","ForearmL","HandL","ArmR","ForearmR","HandR","LegL","ShinL","FootL","LegR","ShinR","FootR"],"parents":[-1,0,1,1,3,4,1,6,7,0,9,10,0,12,13],"points":[Vector3(0,h*.42,0),Vector3(0,h*.58,0),Vector3(0,h*.80,0),Vector3(-shoulder,h*.74,0),Vector3(-shoulder*1.2,h*.54,0),Vector3(-shoulder*1.25,h*.37,0),Vector3(shoulder,h*.74,0),Vector3(shoulder*1.2,h*.54,0),Vector3(shoulder*1.25,h*.37,0),Vector3(-.16,h*.42,0),Vector3(-.16,h*.22,0),Vector3(-.16,h*.07,-.04),Vector3(.16,h*.42,0),Vector3(.16,h*.22,0),Vector3(.16,h*.07,-.04)]}
func write_material(original: Material,out: String) -> void:
	var material: StandardMaterial3D = original.duplicate()
	for key in ["albedo_texture","normal_texture"]:
		var image: Image = material.get(key).get_image(); image.clear_mipmaps()
		var filename: String = out+key+(".jpg" if key=="albedo_texture" else ".png")
		assert((image.save_jpg(filename,.93) if key=="albedo_texture" else image.save_png(filename))==OK)
	material.albedo_texture = null; material.normal_texture = null; material.roughness_texture = null; material.metallic_texture = null
	material.roughness = .94; material.metallic = 0; material.metallic_specular = .22; material.normal_scale = .45
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	assert(ResourceSaver.save(material,out+"material.tres")==OK)
	var text := FileAccess.get_file_as_string(out+"material.tres")
	text = text.replace("[resource]",'[ext_resource type="Texture2D" path="'+out+'albedo_texture.jpg" id="albedo"]\n[ext_resource type="Texture2D" path="'+out+'normal_texture.png" id="normal"]\n\n[resource]')
	text += '\nalbedo_texture = ExtResource("albedo")\nnormal_texture = ExtResource("normal")\n'
	var file := FileAccess.open(out+"material.tres",FileAccess.WRITE); file.store_string(text)
func run() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder+"/build.json"))
	var report := []
	for job in config.sources:
		var input: String = folder+"/"+job.input
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input+".json"))
		assert(FileAccess.get_sha256(input)==manifest.output_sha256)
		var doc := GLTFDocument.new(); var state := GLTFState.new(); assert(doc.append_from_file(input,state)==OK)
		var source := doc.generate_scene(state); var original: MeshInstance3D = source.find_children("*","MeshInstance3D",true,false)[0]
		var arrays := original.mesh.surface_get_arrays(0); var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var labels := FileAccess.get_file_as_bytes(input.trim_suffix(".glb")+".components.bin").to_int32_array()
		assert(labels.size()==positions.size())
		var out: String = OUT+job.kit+"/"; DirAccess.make_dir_recursive_absolute(out); write_material(original.mesh.surface_get_material(0),out)
		var groups := {}
		for i in range(0,arrays[Mesh.ARRAY_INDEX].size(),3):
			var id: int = arrays[Mesh.ARRAY_INDEX][i]; var label := labels[id]
			if not groups.has(label): groups[label] = PackedInt32Array()
			for k in range(3): groups[label].append(arrays[Mesh.ARRAY_INDEX][i+k])
		for entry in job.models:
			var id: String = entry[1]; var profile: String = entry[2]; var indices: PackedInt32Array = groups[int(entry[0])]
			var box := AABB(positions[indices[0]],Vector3.ZERO)
			for index in indices: box = box.expand(positions[index])
			var center := box.get_center(); center.y = box.position.y
			var desired := .95 if profile=="dog" else .75 if profile=="flyer" else 1.9
			if id=="titan16": desired = 2.5 # Antlers extend above the 1.9m anatomical body.
			var factor := desired/box.size.y
			var budget: int = 10000 if id=="titan16" else job.budget
			var reduced := part_arrays(arrays,indices,center,factor,budget)
			var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var fit := AABB()
			for p in reduced[Mesh.ARRAY_VERTEX]: fit = fit.expand(p)
			var skin_fit := fit
			if id=="titan16": skin_fit.size.y = 1.9
			for index in reduced[Mesh.ARRAY_INDEX]:
				var p: Vector3 = reduced[Mesh.ARRAY_VERTEX][index]
				var weights := influences(p,profile,skin_fit); var bones := PackedInt32Array(); var values := PackedFloat32Array()
				for bone in weights: bones.append(bone); values.append(weights[bone])
				while bones.size()<4: bones.append(0); values.append(0)
				assert(bones.size()==4)
				surface.set_bones(bones); surface.set_weights(values)
				surface.set_normal(reduced[Mesh.ARRAY_NORMAL][index]); surface.set_uv(reduced[Mesh.ARRAY_TEX_UV][index]); surface.add_vertex(p)
			surface.index(); surface.generate_tangents(); var mesh := surface.commit(); mesh.surface_set_material(0,StandardMaterial3D.new())
			assert(ResourceSaver.save(mesh,out+id+".res",ResourceSaver.FLAG_COMPRESS)==OK)
			var rig := Node3D.new(); rig.name = "ClayEnemy16"; rig.set_meta("imported_enemy16",true); rig.set_meta("model_id16",id); rig.set_meta("profile16",profile)
			if id=="titan16":
				var front := -.28
				for p in reduced[Mesh.ARRAY_VERTEX]:
					if absf(p.x)<.26 and p.y>1.08 and p.y<1.36: front = minf(front,p.z-.06)
				rig.set_meta("heart_origin16",Vector3(0,1.22,front))
			var sk := Skeleton3D.new(); sk.name = "Skeleton3D"; rig.add_child(sk); sk.owner = rig
			var bones := skeleton_data(profile,skin_fit)
			for i in range(bones.names.size()):
				sk.add_bone(bones.names[i]); sk.set_bone_parent(i,bones.parents[i]); sk.set_bone_rest(i,Transform3D(Basis.IDENTITY,bones.points[i]-(bones.points[bones.parents[i]] if bones.parents[i]>=0 else Vector3.ZERO)))
			sk.reset_bone_poses()
			var model := MeshInstance3D.new(); model.name = "Character"; model.mesh = load(out+id+".res"); sk.add_child(model); model.owner = rig; model.skeleton = NodePath(".."); model.skin = sk.create_skin_from_rest_transforms()
			model.custom_aabb = fit.grow(.5)
			for control in ["ArmL","ArmR","LegL","LegR"]+(["WingL","WingR"] if profile=="flyer" else ["LegFL","LegFR","LegBL","LegBR"] if profile=="dog" else []):
				var node := Node3D.new(); node.name = control; rig.add_child(node); node.owner = rig
			var packed := PackedScene.new(); assert(packed.pack(rig)==OK); assert(ResourceSaver.save(packed,out+id+".tscn")==OK)
			var text := FileAccess.get_file_as_string(out+id+".tscn"); var at := text.find("[sub_resource")
			text = text.insert(at,'[ext_resource type="Script" path="res://scripts/presentation/clay_enemy16.gd" id="rig"]\n[ext_resource type="Material" path="'+out+'material.tres" id="mat"]\n\n')
			var lines := PackedStringArray()
			for line in text.split("\n"):
				lines.append(line)
				if line.begins_with('[node name="ClayEnemy16"'): lines.append('script = ExtResource("rig")')
				if line.begins_with('mesh = ExtResource('): lines.append('surface_material_override/0 = ExtResource("mat")')
			var file := FileAccess.open(out+id+".tscn",FileAccess.WRITE); file.store_string("\n".join(lines)); file.close()
			report.append({"kit":job.kit,"id":id,"component":int(entry[0]),"triangles":mesh.surface_get_array_index_len(0)/3,"bones":bones.names.size(),"bounds":str(fit),"profile":profile})
			print("BUILT ",job.kit,"/",id," triangles=",mesh.surface_get_array_index_len(0)/3)
			rig.free()
		source.free()
	var file := FileAccess.open(OUT+"geometry.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("ENEMY BUILD COMPLETE ",report.size()); quit()
