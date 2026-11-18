extends SceneTree
## Deterministic offline rigging of the user's static Tripo character.
const OUT := "res://assets/characters/player16/"
var input := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input = arg.trim_prefix("--input=")
	call_deferred("run")
func height(y: float) -> float:
	var points := [Vector2(0,0),Vector2(.12,.18),Vector2(.34,.66),Vector2(.50,1.02),Vector2(.615,1.30),Vector2(.70,1.43),Vector2(.97705,1.89)]
	for i in range(1,points.size()):
		if y<=points[i].x: return lerpf(points[i-1].y,points[i].y,inverse_lerp(points[i-1].x,points[i].x,y))
	return 1.89
func position(p: Vector3,covered: bool,head: bool) -> Vector3:
	var value := Vector3(-p.x*1.90,height(p.y),-p.z*1.50)
	if p.y>.71:
		value.x *= .93; value.z *= 1.07
		if head:
			var blend := smoothstep(.71,.76,p.y)
			value.x *= lerpf(1,.83,blend); value.z *= lerpf(1,.84,blend)
			value.y = lerpf(value.y,1.65+(value.y-1.65)*.90,blend)
	if covered and p.y>.33 and p.y<.71:
		var torso := (1-smoothstep(.145,.22,absf(p.x)))*smoothstep(.33,.38,p.y)*(1-smoothstep(.68,.71,p.y))
		value.x *= lerpf(1,.87,torso); value.z *= lerpf(1,.62,torso)
	return value
func influences(p: Vector3) -> Dictionary:
	if p.y>.705: return {2:1.0}
	var side := -1 if p.x>0 else 1
	if p.y>.54 and p.y<.71 and absf(p.x)>.143:
		var upper := 3 if side<0 else 6
		var arm := smoothstep(.143,.20,absf(p.x))
		var elbow := smoothstep(.27,.35,absf(p.x))
		var wrist := smoothstep(.40,.45,absf(p.x))
		return {1:1-arm,upper:arm*(1-elbow),upper+1:arm*elbow*(1-wrist),upper+2:arm*elbow*wrist}
	if p.y<.36:
		var leg := 9 if side<0 else 12
		var pelvis := smoothstep(.29,.36,p.y)
		var knee := 1-smoothstep(.13,.22,p.y)
		var ankle := 1-smoothstep(.055,.10,p.y)
		return {0:pelvis,leg:(1-pelvis)*(1-knee),leg+1:(1-pelvis)*knee*(1-ankle),leg+2:(1-pelvis)*knee*ankle}
	return {0:1-smoothstep(.34,.44,p.y),1:smoothstep(.34,.44,p.y)}
func run() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(input+".json"))
	assert(manifest.output_sha256==FileAccess.get_sha256(input) and int(manifest.triangles)<=16000)
	var doc := GLTFDocument.new(); var state := GLTFState.new(); assert(doc.append_from_file(input,state)==OK)
	var source := doc.generate_scene(state); var original: MeshInstance3D = source.find_children("*","MeshInstance3D",true,false)[0]
	var arrays: Array = original.mesh.surface_get_arrays(0)
	DirAccess.make_dir_recursive_absolute(OUT)
	var material: StandardMaterial3D = original.mesh.surface_get_material(0).duplicate()
	for key in ["albedo_texture","normal_texture"]:
		var texture: Texture2D = material.get(key)
		var image := texture.get_image(); image.clear_mipmaps()
		var filename: String = OUT+key+(".png" if key=="normal_texture" else ".jpg")
		assert((image.save_png(filename) if filename.ends_with(".png") else image.save_jpg(filename,.93))==OK)
	material.albedo_texture = null; material.normal_texture = null; material.roughness_texture = null; material.metallic_texture = null
	material.roughness = .94; material.metallic = 0; material.metallic_specular = .25; material.normal_scale = .45; material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	assert(ResourceSaver.save(material,OUT+"material.tres")==OK)
	var text := FileAccess.get_file_as_string(OUT+"material.tres")
	text = text.replace("[resource]",'[ext_resource type="Texture2D" path="'+OUT+'albedo_texture.jpg" id="1"]
[ext_resource type="Texture2D" path="'+OUT+'normal_texture.png" id="2"]

[resource]')
	text += '
albedo_texture = ExtResource("1")
normal_texture = ExtResource("2")

'
	var file := FileAccess.open(OUT+"material.tres",FileAccess.WRITE); file.store_string(text); file.close()
	for variant in ["base","covered","base_head","covered_head"]:
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for old in arrays[Mesh.ARRAY_INDEX]:
			var p: Vector3 = arrays[Mesh.ARRAY_VERTEX][old]; var weights := influences(p); var bones := PackedInt32Array(); var values := PackedFloat32Array()
			for bone in weights:
				bones.append(bone); values.append(weights[bone])
			while bones.size()<4: bones.append(0); values.append(0)
			assert(bones.size()==4)
			surface.set_bones(bones); surface.set_weights(values)
			var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][old]
			surface.set_normal(Vector3(-n.x/1.90,n.y/2.0,-n.z/1.5).normalized()); surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][old])
			surface.add_vertex(position(p,variant.begins_with("covered"),variant.ends_with("head")))
		surface.index(); surface.generate_normals(); surface.generate_tangents(); var mesh := surface.commit(); mesh.surface_set_material(0,StandardMaterial3D.new())
		assert(ResourceSaver.save(mesh,OUT+variant+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	var scene := Node3D.new(); scene.name = "ClayPlayer16"; scene.set_meta("source","Tripo/user submission"); scene.set_meta("weapon_origin16",Vector3(.20,1.15,-.36))
	var skeleton := Skeleton3D.new(); skeleton.name = "Skeleton3D"; scene.add_child(skeleton); skeleton.owner = scene
	var names := ["Pelvis","Spine","Head","ArmL","ForearmL","HandL","ArmR","ForearmR","HandR","LegL","ShinL","FootL","LegR","ShinR","FootR"]
	var parents := [-1,0,1,1,3,4,1,6,7,0,9,10,0,12,13]
	var rests := [Vector3(0,.66,0),Vector3(0,1.02,0),Vector3(0,1.43,0),Vector3(-.323,1.30,0),Vector3(-.623,1.30,0),Vector3(-.923,1.30,0),Vector3(.323,1.30,0),Vector3(.623,1.30,0),Vector3(.923,1.30,0),Vector3(-.15,.66,0),Vector3(-.15,.34,0),Vector3(-.15,.12,0),Vector3(.15,.66,0),Vector3(.15,.34,0),Vector3(.15,.12,0)]
	for i in range(names.size()):
		skeleton.add_bone(names[i]); skeleton.set_bone_parent(i,parents[i]); skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,rests[i]-(rests[parents[i]] if parents[i]>=0 else Vector3.ZERO)))
	skeleton.reset_bone_poses()
	var instance := MeshInstance3D.new(); instance.name = "Character"; instance.mesh = load(OUT+"base.res"); skeleton.add_child(instance); instance.owner = scene; instance.skeleton = NodePath(".."); instance.skin = skeleton.create_skin_from_rest_transforms()
	instance.custom_aabb = AABB(Vector3(-1,-.3,-1.1),Vector3(2,2.5,2.2))
	for name in ["ArmL","ArmR","LegL","LegR","Body16","DefaultHat16","DefaultPack16"]:
		var control := Node3D.new(); control.name = name; scene.add_child(control); control.owner = scene
		if name.begins_with("Arm"): control.rotation.x = 1.1
	var gun := MeshInstance3D.new(); gun.name = "Gun"; gun.position = Vector3(.20,1.15,-.36); var gun_mesh := BoxMesh.new(); gun_mesh.size = Vector3(.14,.14,.6); gun.mesh = gun_mesh; var gun_material := StandardMaterial3D.new(); gun_material.albedo_color = Color("17272d"); gun_material.roughness = .95; gun.material_override = gun_material; scene.add_child(gun); gun.owner = scene
	var packed := PackedScene.new(); assert(packed.pack(scene)==OK); assert(ResourceSaver.save(packed,OUT+"player.tscn")==OK)
	text = FileAccess.get_file_as_string(OUT+"player.tscn"); var at := text.find("[sub_resource")
	text = text.insert(at,'[ext_resource type="Script" path="res://scripts/presentation/clay_player16.gd" id="rig"]
[ext_resource type="Material" path="'+OUT+'material.tres" id="material"]

')
	var lines := PackedStringArray()
	for line in text.split("
"):
		lines.append(line)
		if line.begins_with('[node name="ClayPlayer16"'): lines.append('script = ExtResource("rig")')
		if line.begins_with('mesh = ExtResource('): lines.append('surface_material_override/0 = ExtResource("material")')
	file = FileAccess.open(OUT+"player.tscn",FileAccess.WRITE); file.store_string("
".join(lines)); file.close()
	file = FileAccess.open(OUT+"geometry.json",FileAccess.WRITE); file.store_string(JSON.stringify({"source_sha256":manifest.source_sha256,"prepared_sha256":manifest.output_sha256,"triangles":int(manifest.triangles),"bones":15,"texture_limit":1024,"variants":["base","covered","base_head","covered_head"],"source_animations":0,"rig":"local offline weighted skeleton"},"  ")); file.close()
	scene.free(); source.free(); print("PLAYER BUILT: ",manifest.triangles," triangles, 15 bones, four shared fit meshes"); quit()
