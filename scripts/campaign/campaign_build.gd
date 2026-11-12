extends BuildManager
var angle: float = 0
var ghost: MeshInstance3D

func _ready() -> void:
	preview = Node3D.new()
	add_child(preview)
	ghost = VisualFactory.box(preview,Vector3.ONE,Vector3.ZERO,Color("a4e886"))
	preview.visible = false

func set_active(value: bool) -> void:
	active = value and world.phase == "prep" and world.area_index == -1
	preview.visible = active
	if active: world.notify("1–6 selecionam peças · Q gira · clique instala · botão direito cancela")

func _physics_process(_delta: float) -> void:
	if not active: return
	for i in range(6):
		if Input.is_action_just_pressed("slot_%d" % (i+1)): selected = i
	if Input.is_action_just_pressed("rotate_piece"): angle = fmod(angle+PI/2,TAU)
	var point: Vector3 = world.mouse_ground(0)
	location = Vector3(snappedf(point.x,1),0,snappedf(point.z,1))
	preview.global_position = location
	preview.rotation.y = angle
	var size: Vector3 = CampaignData.PIECES[selected].size
	ghost.scale = size
	ghost.position.y = size.y/2
	valid = can_place(location)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(.65,.91,.5,.45) if valid else Color(.95,.3,.25,.45)
	ghost.material_override = mat

func can_place(pos: Vector3) -> bool:
	reason = ""
	if world.phase != "prep" or world.area_index != -1: reason = "Construa no refúgio entre hordas."
	elif absf(pos.x)>24 or absf(pos.z)>24: reason = "Fora do terreno da base."
	elif pos.distance_to(world.player.global_position)>12: reason = "Aproxime-se: alcance de 12 m."
	elif get_tree().get_nodes_in_group("campaign_structure").size()>=80: reason = "Limite de 80 estruturas."
	elif not world.can_pay(CampaignData.PIECES[selected].cost): reason = "Materiais insuficientes."
	elif pos.distance_to(world.vendor_pos)<3.5 or pos.distance_to(world.exit_pos)<3.5: reason = "Mantenha o vendedor e a saída livres."
	if not reason.is_empty(): return false
	var size: Vector3 = CampaignData.PIECES[selected].size
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
		if footprint_overlaps(pos,size,angle,structure.position,CampaignData.PIECES[structure.piece_index].size,structure.rotation.y):
			reason = "Outra estrutura ocupa esta posição."
			return false
	if not preserves_access(pos,size):
		reason = "Deixe passagem ao Núcleo ou use um portão."
		return false
	reason = "%s · %s" % [CampaignData.PIECES[selected].title,CampaignData.cost_text(CampaignData.PIECES[selected].cost)]
	return true

func footprint_overlaps(a: Vector3,sa: Vector3,ra: float,b: Vector3,sb: Vector3,rb: float) -> bool:
	if absf(sin(ra))>.5: sa = Vector3(sa.z,sa.y,sa.x)
	if absf(sin(rb))>.5: sb = Vector3(sb.z,sb.y,sb.x)
	return absf(a.x-b.x)<(sa.x+sb.x)/2-.02 and absf(a.z-b.z)<(sa.z+sb.z)/2-.02

func preserves_access(pos: Vector3,size: Vector3) -> bool:
	if CampaignData.PIECES[selected].id in ["gate","spikes"]: return true
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-25,-25,51,51)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var blocks: Array = [{"pos":pos,"size":size,"angle":angle}]
	for s in get_tree().get_nodes_in_group("campaign_structure"):
		if s.spec.id not in ["gate","spikes"]: blocks.append({"pos":s.position,"size":CampaignData.PIECES[s.piece_index].size,"angle":s.rotation.y})
	for block in blocks:
		var extent: Vector3 = block.size
		if absf(sin(block.angle))>.5: extent = Vector3(extent.z,extent.y,extent.x)
		for x in range(floori(block.pos.x-extent.x/2),ceili(block.pos.x+extent.x/2)+1):
			for z in range(floori(block.pos.z-extent.z/2),ceili(block.pos.z+extent.z/2)+1):
				if grid.is_in_boundsv(Vector2i(x,z)) and absf(x-block.pos.x)<extent.x/2+.3 and absf(z-block.pos.z)<extent.z/2+.3: grid.set_point_solid(Vector2i(x,z))
	return not grid.get_id_path(Vector2i(0,24),Vector2i.ZERO).is_empty()

func place() -> Node3D:
	if not active or not can_place(location):
		world.notify(reason)
		return null
	var cost: Dictionary = CampaignData.PIECES[selected].cost
	if not world.pay(cost): return null
	var s := StaticBody3D.new()
	s.set_script(load("res://scripts/campaign/campaign_structure.gd"))
	s.world = world
	s.piece_index = selected
	s.position = location
	s.rotation.y = angle
	s.invested = cost.duplicate()
	world.base_root.add_child(s)
	world.effects.burst(location+Vector3.UP,Color("c8df9a"),8)
	world.notify("%s instalada. G melhora a estrutura próxima." % CampaignData.PIECES[selected].title)
	return s
