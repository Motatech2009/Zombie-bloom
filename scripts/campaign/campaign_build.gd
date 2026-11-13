extends BuildManager
const STRUCTURE_SCRIPT = preload("res://scripts/campaign/campaign_structure.gd")
var angle: float = 0
var ghost: MeshInstance3D
var good_material: StandardMaterial3D
var bad_material: StandardMaterial3D
var access_grid := AStarGrid2D.new()
var access_revision: int = -1
var access_rebuilds: int = 0
var preview_left: float = 0
var preview_checks: int = 0
var access_checks: int = 0
var last_place_usec: int = 0

func _ready() -> void:
	preview = Node3D.new()
	add_child(preview)
	ghost = VisualFactory.box(preview,Vector3.ONE,Vector3.ZERO,Color("a4e886"))
	preview.visible = false
	for color in [Color(.65,.91,.5,.4),Color(.95,.3,.25,.4)]:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color
		if good_material==null: good_material = mat
		else: bad_material = mat
	access_grid.region = Rect2i(-47,-47,95,95)
	access_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	access_grid.update()

func set_active(value: bool) -> void:
	active = value and world.phase == "prep" and world.area_index == -1
	preview.visible = active
	if active: world.notify("1–9 / 0 selecionam peças · Q gira · clique instala · botão direito cancela")

func _physics_process(delta: float) -> void:
	if not active: return
	for i in range(piece_specs().size()):
		if Input.is_action_just_pressed("slot_%d" % (i+1)): selected = i
	if Input.is_action_just_pressed("rotate_piece"): angle = fmod(angle+PI/2,TAU)
	var point: Vector3 = world.mouse_ground(0)
	location = Vector3(snappedf(point.x,1),0,snappedf(point.z,1))
	preview.global_position = location
	preview.rotation.y = angle
	var size: Vector3 = piece_specs()[selected].size
	ghost.scale = size
	ghost.position.y = size.y/2
	preview_left -= delta
	if preview_left<=0:
		preview_left = .1
		preview_checks += 1
		valid = can_place(location,false)
	ghost.material_override = good_material if valid else bad_material

func can_place(pos: Vector3,check_access: bool = true) -> bool:
	reason = ""
	if world.phase != "prep" or world.area_index != -1: reason = "Construa no refúgio entre hordas."
	elif absf(pos.x)>46 or absf(pos.z)>46: reason = "Fora do terreno da base."
	elif pos.distance_to(world.player.global_position)>12: reason = "Aproxime-se: alcance de 12 m."
	elif get_tree().get_nodes_in_group("campaign_structure").size()>=120: reason = "Limite de 120 estruturas."
	elif not world.can_pay(piece_specs()[selected].cost): reason = "Materiais insuficientes."
	elif pos.distance_to(world.vendor_pos)<3.5: reason = "Mantenha o vendedor livre."
	for exit in world.exit_positions():
		if pos.distance_to(exit)<3.5: reason = "Mantenha as saídas livres."
	if not reason.is_empty(): return false
	var size: Vector3 = piece_specs()[selected].size
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x-.05,maxf(.3,size.y-.25),size.z-.05)
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP,angle),pos+Vector3(0,size.y/2+.15,0))
	query.collision_mask = 1|2|4|8
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		reason = "Local ocupado."
		return false
	for structure in get_tree().get_nodes_in_group("campaign_structure"):
		if footprint_overlaps(pos,size,angle,structure.position,piece_specs()[structure.piece_index].size,structure.rotation.y):
			reason = "Outra estrutura ocupa esta posição."
			return false
	if check_access and not preserves_access(pos,size):
		reason = "Deixe passagem ao Núcleo ou use um portão."
		return false
	reason = "%s · %s" % [piece_specs()[selected].title,CampaignData.cost_text(piece_specs()[selected].cost)]
	return true

func footprint_overlaps(a: Vector3,sa: Vector3,ra: float,b: Vector3,sb: Vector3,rb: float) -> bool:
	if absf(sin(ra))>.5: sa = Vector3(sa.z,sa.y,sa.x)
	if absf(sin(rb))>.5: sb = Vector3(sb.z,sb.y,sb.x)
	return absf(a.x-b.x)<(sa.x+sb.x)/2-.02 and absf(a.z-b.z)<(sa.z+sb.z)/2-.02

func cells_for(pos: Vector3,size: Vector3,rotation_y: float) -> Array[Vector2i]:
	if absf(sin(rotation_y))>.5: size = Vector3(size.z,size.y,size.x)
	var result: Array[Vector2i] = []
	for x in range(floori(pos.x-size.x/2),ceili(pos.x+size.x/2)+1):
		for z in range(floori(pos.z-size.z/2),ceili(pos.z+size.z/2)+1):
			if access_grid.is_in_boundsv(Vector2i(x,z)) and absf(x-pos.x)<size.x/2+.3 and absf(z-pos.z)<size.z/2+.3: result.append(Vector2i(x,z))
	return result

func preserves_access(pos: Vector3,size: Vector3) -> bool:
	if piece_specs()[selected].id in ["gate","spikes","wire"]: return true
	access_checks += 1
	if access_revision!=world.layout_revision:
		access_grid.fill_solid_region(access_grid.region,false)
		for s in get_tree().get_nodes_in_group("campaign_structure"):
			if s.spec.id not in ["gate","spikes","wire"]:
				for cell in cells_for(s.position,piece_specs()[s.piece_index].size,s.rotation.y): access_grid.set_point_solid(cell)
		access_revision = world.layout_revision
		access_rebuilds += 1
	var changed: Array[Vector2i] = []
	for cell in cells_for(pos,size,angle):
		if not access_grid.is_point_solid(cell):
			access_grid.set_point_solid(cell)
			changed.append(cell)
	var valid_path := true
	for origin in world.access_origins():
		if access_grid.get_id_path(origin,Vector2i.ZERO).is_empty(): valid_path = false; break
	for cell in changed: access_grid.set_point_solid(cell,false)
	return valid_path

func place() -> Node3D:
	var begin := Time.get_ticks_usec()
	if not active or not can_place(location):
		world.notify(reason)
		return null
	var cost: Dictionary = piece_specs()[selected].cost
	if not world.pay(cost): return null
	var s := StaticBody3D.new()
	s.set_script(structure_script())
	s.world = world
	s.piece_index = selected
	s.position = location
	s.rotation.y = angle
	s.invested = cost.duplicate()
	world.base_root.add_child(s)
	world.layout_revision += 1
	last_place_usec = Time.get_ticks_usec()-begin
	world.effects.burst(location+Vector3.UP,Color("c8df9a"),8)
	world.notify("%s instalada. G melhora a estrutura próxima." % piece_specs()[selected].title)
	return s

func piece_specs() -> Array: return CampaignData.PIECES
func structure_script() -> Script: return STRUCTURE_SCRIPT
