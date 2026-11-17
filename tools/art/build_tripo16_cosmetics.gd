extends SceneTree
## Separates the nineteen creator accessories, packs one atlas and fits the human rig.
const OUT := "res://assets/cosmetics/tripo16/"
var source_path := ""
var plan_path := ""
var parents: PackedInt32Array
func find_root(i: int) -> int:
	while parents[i]!=i: parents[i] = parents[parents[i]]; i = parents[i]
	return i
func join(a: int,b: int) -> void: parents[find_root(a)] = find_root(b)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source_path = arg.trim_prefix("--source=")
		if arg.begins_with("--plan="): plan_path = arg.trim_prefix("--plan=")
	call_deferred("run")
func vec(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func cell(point: Vector3,plan: Array) -> int:
	var nearest := -1; var distance := INF
	for i in range(plan.size()):
		var d := Vector2(point.x-float(plan[i].center[0]),point.y-float(plan[i].center[1])).length_squared()
		if d<distance: nearest = i; distance = d
	return nearest
func run() -> void:
	if FileAccess.get_sha256(source_path)!="a4635f3faa591956989b87920f6f136a46bd8ebc26a228632b1b2dc59149f8ec": push_error("Cosmetic source changed; review cell layout"); quit(1); return
	var plan: Array = JSON.parse_string(FileAccess.get_file_as_string(plan_path)); assert(plan.size()==19)
	var doc := GLTFDocument.new(); var state := GLTFState.new(); assert(doc.append_from_file(source_path,state)==OK)
	var source := doc.generate_scene(state); var nodes := source.find_children("*","MeshInstance3D",true,false); assert(nodes.size()==17)
	var atlas := Image.create(2048,2048,false,Image.FORMAT_RGB8); atlas.fill(Color("5f5546"))
	var groups := []; var boxes := []; var found := []
	for i in range(plan.size()): groups.append([]); boxes.append(AABB()); found.append(false)
	var input_triangles := 0
	for part in range(nodes.size()):
		var mesh: Mesh = nodes[part].mesh; assert(mesh.get_surface_count()==1)
		var material: StandardMaterial3D = mesh.surface_get_material(0); var picture := material.albedo_texture.get_image(); picture.clear_mipmaps(); picture.convert(Image.FORMAT_RGB8); picture.resize(384,384,Image.INTERPOLATE_LANCZOS)
		var offset := Vector2i((part%5)*400+8,(part/5)*400+8)
		atlas.blit_rect(picture,Rect2i(0,0,384,384),offset)
		# Extruded border prevents neighbouring accessories bleeding into mipmaps.
		for y in range(-8,392):
			for x in range(-8,392):
				if x>=0 and x<384 and y>=0 and y<384: continue
				atlas.set_pixelv(offset+Vector2i(x,y),picture.get_pixel(clampi(x,0,383),clampi(y,0,383)))
		var arrays: Array = mesh.surface_get_arrays(0); var p: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		parents.resize(p.size()); var welded := {}
		for i in range(p.size()):
			parents[i] = i; var q := p[i]*100000; var key := Vector3i(roundi(q.x),roundi(q.y),roundi(q.z))
			if welded.has(key): join(i,int(welded[key]))
			else: welded[key] = i
		for t in range(0,indices.size(),3): join(indices[t],indices[t+1]); join(indices[t],indices[t+2])
		var components := {}
		for i in range(p.size()):
			var id := find_root(i)
			components[id] = components[id].expand(p[i]) if components.has(id) else AABB(p[i],Vector3.ZERO)
		for t in range(0,indices.size(),3):
			var component: AABB = components[find_root(indices[t])]
			assert(component.size.x<.3 and component.size.y<.3,"Unexpected geometry joining two accessories")
			var group := cell(component.get_center(),plan); input_triangles += 1
			for k in range(3):
				var old := indices[t+k]
				var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][old]
				groups[group].append({"p":p[old],"n":arrays[Mesh.ARRAY_NORMAL][old],"uv":(Vector2(offset)+Vector2.ONE*.5+uv*383)/2048.0})
				boxes[group] = boxes[group].expand(p[old]) if found[group] else AABB(p[old],Vector3.ZERO); found[group] = true
	DirAccess.make_dir_recursive_absolute(OUT); assert(atlas.save_jpg(OUT+"atlas.jpg",.93)==OK)
	var file := FileAccess.open(OUT+"material.tres",FileAccess.WRITE)
	file.store_string('[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="'+OUT+'atlas.jpg" id="1"]

[resource]
roughness = 0.94
texture_repeat = false
albedo_texture = ExtResource("1")
'); file.close()
	var report := {"source_triangles":input_triangles,"atlas_size":2048,"items":[]}; var total := 0
	for i in range(plan.size()):
		assert(found[i]); var entry: Dictionary = plan[i]; var box: AABB = boxes[i]; var scale := vec(entry.size)/box.size; var angle := deg_to_rad(float(entry.yaw))
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in groups[i]:
			var position: Vector3 = ((vertex.p-box.get_center())*scale).rotated(Vector3.UP,angle)+vec(entry.position)
			var normal: Vector3 = (vertex.n/scale).normalized().rotated(Vector3.UP,angle)
			surface.set_normal(normal); surface.set_uv(vertex.uv); surface.add_vertex(position)
		surface.index(); var mesh := surface.commit(); var count := mesh.surface_get_array_index_len(0)/3; total += count
		assert(ResourceSaver.save(mesh,OUT+str(entry.id)+".res",ResourceSaver.FLAG_COMPRESS)==OK)
		var scene := Node3D.new(); scene.name = entry.id; scene.set_meta("cosmetic_id",entry.id); scene.set_meta("slot",entry.slot); scene.set_meta("source","Tripo/user submission")
		var instance := MeshInstance3D.new(); instance.name = "Accessory"; instance.mesh = load(OUT+str(entry.id)+".res"); scene.add_child(instance); instance.owner = scene
		var packed := PackedScene.new(); assert(packed.pack(scene)==OK); var scene_path := OUT+str(entry.id)+".tscn"; assert(ResourceSaver.save(packed,scene_path)==OK); scene.free()
		var text := FileAccess.get_file_as_string(scene_path); text = text.insert(text.find("[node name="),'[ext_resource type="Material" path="'+OUT+'material.tres" id="material"]

')
		var lines := PackedStringArray()
		for line in text.split("
"):
			lines.append(line)
			if line.begins_with("mesh = "): lines.append('surface_material_override/0 = ExtResource("material")')
		file = FileAccess.open(scene_path,FileAccess.WRITE); file.store_string("
".join(lines)); file.close()
		report.items.append({"id":entry.id,"triangles":count,"target_size":entry.size,"position":entry.position}); print("COSMETIC: "+str(entry.id)+" "+str(count))
	assert(total==input_triangles); file = FileAccess.open(OUT+"geometry.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close(); source.free(); print("COSMETICS BUILT: ",plan.size()," accessories, ",total," triangles"); quit()
