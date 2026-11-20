extends SceneTree
## Split four cars and atlas the supplied stall, keeping their source materials.
const HASHES := {"carros":"4315ee811db9510d5c9a0b7d13ab9aa04deb8bc03b812db573dee83c31631891","COMBOIO":"8668d623475fe0c2099dea02cb41556225e90b1097fd87330e14edfd71a4d744","VENDEDOR":"8139153eb29c684e553836c52a256a8a9fa82944192e5a1db5161cbe5c638420"}
var folder := ""
var parents: PackedInt32Array
func _initialize() -> void:
	folder = OS.get_cmdline_user_args()[0]
	call_deferred("run")
func root_of(i: int) -> int:
	while parents[i]!=i: parents[i] = parents[parents[i]]; i = parents[i]
	return i
func join(a: int,b: int) -> void: parents[root_of(a)] = root_of(b)
func parts(arrays: Array) -> Array:
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	parents.resize(positions.size()); var weld := {}
	for i in range(positions.size()):
		parents[i] = i; var p := positions[i]*100000; var key := Vector3i(roundi(p.x),roundi(p.y),roundi(p.z))
		if weld.has(key): join(i,weld[key])
		else: weld[key] = i
	for i in range(0,indices.size(),3): join(indices[i],indices[i+1]); join(indices[i],indices[i+2])
	var groups := {}
	for i in range(0,indices.size(),3):
		var id := root_of(indices[i])
		if not groups.has(id): groups[id] = {"indices":PackedInt32Array(),"box":AABB(positions[indices[i]],Vector3.ZERO)}
		for k in range(3):
			groups[id].indices.append(indices[i+k]); groups[id].box = groups[id].box.expand(positions[indices[i+k]])
	var result := groups.values(); result.sort_custom(func(a,b): return a.box.position.x<b.box.position.x); return result
func nodes(node: Node3D,transform: Transform3D = Transform3D.IDENTITY) -> Array:
	var result := []
	if node is MeshInstance3D: result.append({"node":node,"transform":transform})
	for child in node.get_children():
		if child is Node3D: result.append_array(nodes(child,transform*child.transform))
	return result
func save_mesh(surface: SurfaceTool,out: String,name: String) -> void:
	surface.index(); surface.generate_tangents(); var mesh := surface.commit(); mesh.surface_set_material(0,StandardMaterial3D.new())
	assert(ResourceSaver.save(mesh,out+name+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	var scene := Node3D.new(); scene.name = name; scene.set_meta("source","Tripo/user submission")
	var model := MeshInstance3D.new(); model.name = "Model"; model.mesh = load(out+name+".res"); scene.add_child(model); model.owner = scene
	var packed := PackedScene.new(); assert(packed.pack(scene)==OK); assert(ResourceSaver.save(packed,out+name+".tscn")==OK); scene.free()
	var text := FileAccess.get_file_as_string(out+name+".tscn")
	text = text.insert(text.find("[node name="),'[ext_resource type="Material" path="'+out+'material.tres" id="material"]

')
	var lines := PackedStringArray()
	for line in text.split("
"):
		lines.append(line)
		if line.begins_with("mesh = "): lines.append('surface_material_override/0 = ExtResource("material")')
	var file := FileAccess.open(out+name+".tscn",FileAccess.WRITE); file.store_string("
".join(lines)); file.close()
func run() -> void:
	var report := []
	for name in ["carros","COMBOIO","VENDEDOR"]:
		var filename: String = folder+"/"+name+".glb"; assert(FileAccess.get_sha256(filename)==HASHES[name],"Prepared prop source changed")
		var doc := GLTFDocument.new(); var state := GLTFState.new(); assert(doc.append_from_file(filename,state)==OK)
		var source := doc.generate_scene(state); var objects := nodes(source)
		var out: String = "res://assets/scenery/tripo16/"+name.to_lower()+"/"; DirAccess.make_dir_recursive_absolute(out)
		var atlas_size := 2048 if name=="VENDEDOR" else 1024
		var atlas := Image.create(atlas_size,atlas_size,false,Image.FORMAT_RGB8); atlas.fill(Color("737b66"))
		var vertices := []; var box := AABB(); var found := false; var triangles := 0; var part := 0
		for entry in objects:
			var mesh: Mesh = entry.node.mesh; var transform: Transform3D = entry.transform
			for s in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(s); var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]; var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for i in range(positions.size()): indices.append(i)
				var material: StandardMaterial3D = mesh.surface_get_material(s)
				var image := material.albedo_texture.get_image() if material.albedo_texture!=null else Image.create(4,4,false,Image.FORMAT_RGB8)
				if material.albedo_texture==null: image.fill(material.albedo_color)
				image.clear_mipmaps(); image.convert(Image.FORMAT_RGB8)
				var tile := 240 if name=="VENDEDOR" else 1008; var stride := tile+16; var cols := 8 if name=="VENDEDOR" else 1
				image.resize(tile,tile,Image.INTERPOLATE_LANCZOS); var offset := Vector2i((part%cols)*stride+8,(part/cols)*stride+8)
				assert(offset.y+tile+8<=atlas_size)
				atlas.blit_rect(image,Rect2i(0,0,tile,tile),offset)
				for y in range(-8,tile+8):
					for x in range(-8,tile+8):
						if x>=0 and x<tile and y>=0 and y<tile: continue
						atlas.set_pixelv(offset+Vector2i(x,y),image.get_pixel(clampi(x,0,tile-1),clampi(y,0,tile-1)))
				for i in range(0,indices.size(),3):
					triangles += 1
					for k in range(3):
						var old := indices[i+k]; var p := transform*positions[old]
						vertices.append({"p":p,"n":(transform.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][old]).normalized(),"uv":(Vector2(offset)+Vector2.ONE*.5+uv[old]*(tile-1))/float(atlas_size)})
						box = box.expand(p) if found else AABB(p,Vector3.ZERO); found = true
				part += 1
		assert(atlas.save_jpg(out+"atlas.jpg",.94)==OK)
		var file := FileAccess.open(out+"material.tres",FileAccess.WRITE)
		file.store_string('[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="'+out+'atlas.jpg" id="atlas"]

[resource]
roughness = 0.94
texture_repeat = false
albedo_texture = ExtResource("atlas")
'); file.close()
		if name=="carros":
			var arrays: Array = objects[0].node.mesh.surface_get_arrays(0); var groups := parts(arrays); assert(groups.size()==4)
			for i in range(groups.size()):
				var group: Dictionary = groups[i]; var local: AABB = group.box; var scale := Vector3(4.5/local.size.x,1.75/local.size.y,2.35/local.size.z)
				var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				for old in group.indices:
					var p: Vector3 = arrays[Mesh.ARRAY_VERTEX][old]; var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][old]; var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][old]
					p = ((p-Vector3(local.get_center().x,local.position.y,local.get_center().z))*scale).rotated(Vector3.UP,-PI/2)
					surface.set_normal((n/scale).normalized().rotated(Vector3.UP,-PI/2)); surface.set_uv((Vector2(8.5,8.5)+uv*1007)/1024.0); surface.add_vertex(p)
				save_mesh(surface,out,"car_"+str(i+1))
		else:
			var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var scale := Vector3.ONE*5.1 if name=="COMBOIO" else Vector3(3.0/box.size.x,2.65/box.size.y,2.0/box.size.z)
			for v in vertices:
				var p: Vector3 = (v.p-Vector3(box.get_center().x,box.position.y,box.get_center().z))*scale
				var normal: Vector3 = (v.n/scale).normalized()
				var yaw := -PI/2 if name=="COMBOIO" else PI
				p = p.rotated(Vector3.UP,yaw); normal = normal.rotated(Vector3.UP,yaw)
				surface.set_normal(normal); surface.set_uv(v.uv); surface.add_vertex(p)
			save_mesh(surface,out,"convoy" if name=="COMBOIO" else "stall")
		report.append({"id":name,"triangles":triangles,"source_surfaces":part,"draw_calls":4 if name=="carros" else 1,"source_bounds":str(box)})
		source.free(); print("PROP BUILT: ",name," ",triangles)
	var file := FileAccess.open("res://assets/scenery/tripo16/geometry.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close(); quit()
