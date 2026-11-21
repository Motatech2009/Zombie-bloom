extends SceneTree
# Rebuilds the submitted Tripo atlas without cutting triangles or changing UVs.
const OUT := "res://assets/defenses/basic_turret/"
const SOURCE := "res://art_source/basic_turret/defense_turret_3d_models.fbx"
const CENTERS := [Vector3(-.255127,0,-.35498),Vector3(.083496,0,-.022705),Vector3(.354492,0,.333008)]
const GROUNDS := [.031738266,0.0,.056152359]
const BARREL_Y := [.254882805,.300537109,.333984375]
const HEAD_START := [.17,.215,.24]
const NECK_TOP := [.21289061,.265625,.298828125]
const MUZZLES := [[Vector3(-.5005,.254882805,-.358643)],[Vector3(-.206,.300537109,.015625),Vector3(-.206,.300537109,-.057617)],[Vector3(.086,.333984375,.273926),Vector3(.086,.333984375,.387207)]]
var parents: PackedInt32Array
func _initialize() -> void: call_deferred("run")
func find_root(i: int) -> int:
	while parents[i]!=i: parents[i] = parents[parents[i]]; i = parents[i]
	return i
func join(a: int,b: int) -> void: parents[find_root(a)] = find_root(b)
func level_of(v: Vector3) -> int: return 0 if v.z<-.2 else 1 if v.z<.165 else 2
func normalized(v: Vector3,level: int) -> Vector3:
	return ((v-CENTERS[level]-Vector3.UP*GROUNDS[level])*(1.45/(BARREL_Y[level]-GROUNDS[level]))).rotated(Vector3.UP,-PI/2)
func run() -> void:
	assert(FileAccess.get_sha256(SOURCE)=="e602310b55295b2c71f8f6dfc20b3835a8a950372dbe68b9cdee5065704b98d2", "Source changed: recalibrate level boundaries and pivot locations before rebuilding")
	var imported: Node3D = load(SOURCE).instantiate()
	var source: ArrayMesh = imported.get_child(0).mesh
	var arrays: Array = source.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	parents.resize(positions.size())
	var welded := {}
	for i in range(positions.size()):
		parents[i] = i
		var v := positions[i]*100000.0; var key := Vector3i(roundi(v.x),roundi(v.y),roundi(v.z))
		if welded.has(key): join(i,welded[key])
		else: welded[key] = i
	for i in range(0,indices.size(),3): join(indices[i],indices[i+1]); join(indices[i],indices[i+2])
	var components := {}
	for i in range(positions.size()):
		var id := find_root(i)
		if not components.has(id): components[id] = {"min":positions[i].y,"max":positions[i].y,"minx":positions[i].x,"maxx":positions[i].x,"minz":positions[i].z,"maxz":positions[i].z}
		components[id].min = minf(components[id].min,positions[i].y); components[id].max = maxf(components[id].max,positions[i].y)
		components[id].minx = minf(components[id].minx,positions[i].x); components[id].maxx = maxf(components[id].maxx,positions[i].x)
		components[id].minz = minf(components[id].minz,positions[i].z); components[id].maxz = maxf(components[id].maxz,positions[i].z)
	var material := StandardMaterial3D.new(); material.albedo_texture = load(OUT+"atlas.jpg"); material.roughness = .88; material.metallic = .04
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	assert(ResourceSaver.save(material,OUT+"material.tres")==OK)
	material = load(OUT+"material.tres")
	var report := []
	var total := 0
	for level in range(3):
		var root := Node3D.new(); root.name = "turret_N"+str(level+1); root.set_meta("tier",level+1); root.set_meta("source","Tripo/user submission")
		var head := Node3D.new(); head.name = "Head"; head.position.y = 1.45; root.add_child(head); head.owner = root
		var pitch := Node3D.new(); pitch.name = "Pitch"; head.add_child(pitch); pitch.owner = root
		var counts := []
		for part in range(2):
			var mapped := {}; var data := []; data.resize(Mesh.ARRAY_MAX)
			data[Mesh.ARRAY_VERTEX] = PackedVector3Array(); data[Mesh.ARRAY_NORMAL] = PackedVector3Array(); data[Mesh.ARRAY_TEX_UV] = PackedVector2Array(); data[Mesh.ARRAY_INDEX] = PackedInt32Array()
			for t in range(0,indices.size(),3):
				var old := indices[t]; var component: Dictionary = components[find_root(old)]
				var mount: bool = absf((float(component.minx)+float(component.maxx))*.5-CENTERS[level].x)<.02 and absf((float(component.minz)+float(component.maxz))*.5-CENTERS[level].z)<.02 and float(component.max)<=NECK_TOP[level]+.00001
				var moving: bool = (float(component.min)+float(component.max))*.5>HEAD_START[level] and not mount
				if level_of(positions[old])!=level or int(moving)!=part: continue
				for k in range(3):
					old = indices[t+k]; assert(level_of(positions[old])==level)
					if not mapped.has(old):
						mapped[old] = data[Mesh.ARRAY_VERTEX].size()
						data[Mesh.ARRAY_VERTEX].append(normalized(positions[old],level)-Vector3.UP*1.45*part)
						data[Mesh.ARRAY_NORMAL].append(arrays[Mesh.ARRAY_NORMAL][old].rotated(Vector3.UP,-PI/2))
						data[Mesh.ARRAY_TEX_UV].append(arrays[Mesh.ARRAY_TEX_UV][old])
					data[Mesh.ARRAY_INDEX].append(mapped[old])
			var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data); mesh.surface_set_material(0,material)
			var filename := OUT+("base_" if part==0 else "head_")+str(level+1)+".res"
			assert(ResourceSaver.save(mesh,filename,ResourceSaver.FLAG_COMPRESS)==OK)
			var instance := MeshInstance3D.new(); instance.name = "Base" if part==0 else "Gun"; instance.mesh = load(filename)
			(pitch if part==1 else root).add_child(instance); instance.owner = root
			counts.append(data[Mesh.ARRAY_INDEX].size()/3); total += data[Mesh.ARRAY_INDEX].size()/3
		for i in range(MUZZLES[level].size()):
			var marker := Marker3D.new(); marker.name = "Muzzle"+str(i+1); pitch.add_child(marker); marker.owner = root
			marker.position = normalized(MUZZLES[level][i],level)-Vector3.UP*1.45
		var packed := PackedScene.new(); assert(packed.pack(root)==OK)
		assert(ResourceSaver.save(packed,"res://assets/fortress/turret_"+str(level+1)+".tscn")==OK)
		report.append({"tier":level+1,"base_triangles":counts[0],"head_triangles":counts[1],"total_triangles":counts[0]+counts[1],"muzzles":MUZZLES[level].size()})
		root.free()
	assert(total==indices.size()/3)
	var file := FileAccess.open(OUT+"geometry.json",FileAccess.WRITE); file.store_string(JSON.stringify({"triangles":total,"levels":report},"  ")); file.close()
	imported.free(); print("TURRET ASSETS: ",total," triangles preserved across three independent tiers"); quit()
