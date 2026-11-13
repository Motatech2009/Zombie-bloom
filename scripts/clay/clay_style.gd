class_name ClayStyle
extends RefCounted
## Small shared textures and beveled meshes; no per-frame material generation.
static var textures: Dictionary = {}
static var normals: Dictionary = {}
static var materials: Dictionary = {}
static var meshes: Dictionary = {}

static func prewarm() -> void:
	for kind in ["clay","wood","brick","grass","road"]: texture(kind)

static func texture(kind: String) -> Texture2D:
	if textures.has(kind): return textures[kind]
	var noise := FastNoiseLite.new()
	noise.seed = 2301
	noise.frequency = .07
	noise.fractal_octaves = 3
	var image := Image.create(128,128,false,Image.FORMAT_RGB8)
	for y in range(128):
		for x in range(128):
			var n := noise.get_noise_2d(x,y)
			var grain := sin(x*.43+sin(y*.12)*2)*.008
			var value := .93+n*.055+grain
			if kind=="wood": value = .93+sin(x*.19+noise.get_noise_2d(x,y*.23)*3)*.025+n*.025
			elif kind=="brick":
				var line := y%24<2 or (x+(32 if (y/24)%2 else 0))%64<2
				value = .67 if line else .92+n*.08
			elif kind=="grass": value = .91+n*.07+grain
			elif kind=="road": value = .87+n*.08
			image.set_pixel(x,y,Color(value,value,value))
	image.generate_mipmaps()
	textures[kind] = ImageTexture.create_from_image(image)
	var bump := image.duplicate()
	bump.clear_mipmaps()
	bump.bump_map_to_normal_map(1.0)
	bump.generate_mipmaps()
	normals[kind] = ImageTexture.create_from_image(bump)
	return textures[kind]

static func material(color: Color,kind: String = "clay",metallic: float = 0) -> StandardMaterial3D:
	var key := color.to_html()+kind+str(metallic)
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = texture(kind)
	mat.normal_enabled = true
	mat.normal_texture = normals[kind]
	mat.normal_scale = .10
	mat.roughness = .94 if metallic==0 else .72
	mat.metallic = metallic
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE*(.45 if kind=="brick" else .7)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.set_meta("clay_surface",kind)
	materials[key] = mat
	return mat

static func rounded_box(size: Vector3) -> ArrayMesh:
	var key := str(size)
	if meshes.has(key): return meshes[key]
	var half := size*.5
	var radius := minf(.14,minf(half.x,minf(half.y,half.z))*.4)
	var core := half-Vector3.ONE*radius
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[Vector3.RIGHT,Vector3.BACK,Vector3.UP],[Vector3.LEFT,Vector3.FORWARD,Vector3.UP],[Vector3.UP,Vector3.RIGHT,Vector3.BACK],[Vector3.DOWN,Vector3.RIGHT,Vector3.FORWARD],[Vector3.FORWARD,Vector3.RIGHT,Vector3.UP],[Vector3.BACK,Vector3.LEFT,Vector3.UP]]
	for face in faces:
		var normal: Vector3 = face[0]; var u: Vector3 = face[1]; var v: Vector3 = face[2]
		var hu: float = half.dot(u.abs()); var hv: float = half.dot(v.abs())
		var us := [-hu,-hu+radius,hu-radius,hu]; var vs := [-hv,-hv+radius,hv-radius,hv]
		for i in range(3):
			for j in range(3):
				for corner in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
					var point: Vector3 = normal*half.dot(normal.abs())+u*us[corner.x]+v*vs[corner.y]
					var center: Vector3 = point.clamp(-core,core)
					var outward: Vector3 = (point-center).normalized()
					surface.set_normal(outward)
					surface.set_uv(Vector2(float(corner.x)/3,float(corner.y)/3))
					surface.add_vertex(center+outward*radius)
	var mesh := surface.commit()
	if meshes.size()>=384: meshes.erase(meshes.keys()[0])
	meshes[key] = mesh
	return mesh

static func apply_tree(node: Node) -> void:
	if node is MeshInstance3D:
		if node.mesh is BoxMesh: node.mesh = rounded_box(node.mesh.size)
		var mat = node.material_override
		if mat is StandardMaterial3D and not mat.emission_enabled and not mat.has_meta("clay_surface"):
			node.material_override = material(mat.albedo_color,"clay",mat.metallic)
	for child in node.get_children(): apply_tree(child)
