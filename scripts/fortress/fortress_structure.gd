extends "res://scripts/campaign/campaign_structure.gd"
var visual_tier: int = -1
var muzzle_cycle := 0

func _ready() -> void:
	var data: Dictionary = FortressData.pieces()[piece_index]
	spec = GameSpec.new(); spec.id = data.id; spec.title = data.title; spec.color = data.color
	spec.values = {"health":data.health,"repair_cost":8,"repair_amount":90.0,"range":15.0,"damage":15.0,"interval":.65}
	add_to_group("buildings"); add_to_group("damageable"); add_to_group("campaign_structure")
	collision_layer = 0 if FortressData.passable(spec.id) else 8
	collision_mask = 0
	add_child(health); health.setup(data.health*(1+.65*(tier-1))); health.died.connect(die)
	obstacle = VisualFactory.collider(self,data.size,Vector3(0,data.size.y/2,0))
	model = Node3D.new(); add_child(model)
	label = VisualFactory.health_label(self,data.size.y+.45)
	label.font_size = 27; label.pixel_size = .018
	refresh_tier()

func refresh_tier() -> void:
	var data: Dictionary = FortressData.pieces()[piece_index]
	health.maximum = data.health*(1+.65*(tier-1))*(1+float(get_meta("alloy16",0)))
	spec.values.damage = (68.0 if spec.id=="cannon" else 24.0 if spec.id=="shock" else 15.0)*(1+.45*(tier-1))
	spec.values.interval = (2.4 if spec.id=="cannon" else 1.5 if spec.id=="shock" else .65)/(1+.18*(tier-1))
	spec.values.range = FortressData.reach(spec.id,tier)
	if get_meta("fused",false): spec.values.interval *= .55
	refresh_visual()

func refresh_visual() -> void:
	if visual_tier==tier: return
	visual_tier = tier
	var previous_aim := aim_pose()
	for child in model.get_children(): model.remove_child(child); child.queue_free()
	if spec.id=="raised_turret":
		build_raised_visual(); return
	var path = "res://assets/fortress/"+spec.id+"_"+str(tier)+".tscn"
	var visual: Node3D = load(path if ResourceLoader.exists(path) else "res://assets/fortress/station_"+str(tier)+".tscn").instantiate()
	visual.name = "Visual"; model.add_child(visual)
	ClayStyle.apply_tree(visual)
	head = visual.get_node_or_null("Head")
	apply_aim_pose(previous_aim)
	set_open_visual()

func set_open_visual() -> void:
	model.position.y = 0
	var door := model.get_node_or_null("Visual/Door")
	if door!=null: door.position.y = 2.25 if opened else 0.0

func _physics_process(delta: float) -> void:
	if health.dead or world.phase=="ended" or world.is_client or world.combat_paused(): return
	label.visible = health.current<health.maximum or global_position.distance_to(world.player.position)<5 or disabled_left>0
	label.text = "%s N%d · %d/%d" % [spec.title,tier,ceili(health.current),ceili(health.maximum)]
	disabled_left = maxf(0,disabled_left-delta)
	if disabled_left>0: label.text = "EMP · %.1f s" % disabled_left; return
	cooldown -= delta
	if FortressData.turret(spec.id) and cooldown<=0 and world.waves.running: fire_turret()
	elif spec.id in ["wire","spikes"] and cooldown<=0:
		var hit := false
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.spec.id=="flyer": continue
			var local: Vector3 = to_local(enemy.global_position)
			var size: Vector3 = FortressData.pieces()[piece_index].size
			if absf(local.x)<size.x/2+.25 and absf(local.z)<size.z/2+.25:
				enemy.take_damage((8.0 if spec.id=="wire" else 14.0)*tier)
				if spec.id=="wire": enemy.snare_left = maxf(enemy.snare_left,1.2)
				hit = true
		if hit:
			cooldown = .8
			if spec.id=="wire": health.take_damage(1)
	elif spec.id=="station" and cooldown<=0 and world.base_preparing():
		for actor in world.avatars.values():
			if not actor.health.dead and actor.position.distance_to(global_position)<5: actor.health.heal(5*tier)
		for building in get_tree().get_nodes_in_group("buildings"):
			if building.global_position.distance_to(global_position)<6: building.health.heal(3*tier)
		cooldown = 2

func aim_pose() -> Vector2:
	if not is_instance_valid(head): return Vector2.ZERO
	var pitch := head.get_node_or_null("Pitch")
	return Vector2(head.rotation.y,pitch.rotation.x if pitch!=null else 0.0)

func apply_aim_pose(pose: Vector2) -> void:
	if not is_instance_valid(head): return
	head.rotation.y = pose.x
	var pitch := head.get_node_or_null("Pitch")
	if pitch!=null: pitch.rotation.x = pose.y

func aim_at(point: Vector3) -> void:
	var direction: Vector3 = head.get_parent().global_basis.inverse()*(point-head.global_position)
	apply_aim_pose(Vector2(atan2(-direction.x,-direction.z),atan2(direction.y,Vector2(direction.x,direction.z).length())))

func muzzle_origin() -> Vector3:
	if is_instance_valid(head):
		var pitch := head.get_node_or_null("Pitch")
		if pitch!=null:
			var muzzles := pitch.get_children().filter(func(node): return node is Marker3D)
			if not muzzles.is_empty(): return muzzles[muzzle_cycle%muzzles.size()].global_position
	return global_position+Vector3.UP*FortressData.muzzle_height(spec.id)

func fire_turret() -> void:
	if disabled_left>0 or health.dead: return
	var candidates: Array[Node3D] = []
	var origin := global_position+Vector3.UP*FortressData.muzzle_height(spec.id)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var point: Vector3 = enemy.global_position+Vector3(0,enemy.aim_height,0)
		if point.distance_to(origin)>float(spec.values.range): continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point,1|4|8,[get_rid()]))
		if not hit.is_empty() and hit.collider==enemy: candidates.append(enemy)
	if candidates.is_empty(): return
	candidates.sort_custom(func(a,b): return a.global_position.distance_squared_to(origin)<b.global_position.distance_squared_to(origin))
	var point: Vector3 = candidates[0].global_position+Vector3(0,candidates[0].aim_height,0)
	aim_at(point)
	if spec.id=="turret":
		var actual_origin := muzzle_origin()
		var muzzle_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actual_origin,point,1|4|8,[get_rid()]))
		if muzzle_hit.is_empty() or muzzle_hit.collider!=candidates[0]: cooldown = .15; return
		origin = actual_origin
	if spec.id=="cannon":
		if world.defense_shell(origin,point,float(spec.values.damage),3.8)==null: cooldown = .25; return
	else:
		for i in range(mini(3 if spec.id=="shock" else 1,candidates.size())):
			var enemy: Node3D = candidates[i]
			var target_point: Vector3 = enemy.global_position+Vector3(0,enemy.aim_height,0)
			world.damage_origin15 = global_position
			enemy.take_damage(float(spec.values.damage)*pow(.8,i))
			world.damage_origin15 = Vector3.INF
			if spec.id=="shock": enemy.stun_left = maxf(enemy.stun_left,.35)
			world.shot_visual(origin,target_point,Color("79d4e5"))
	muzzle_cycle += 1
	cooldown = float(spec.values.interval)

func toggle() -> bool:
	if spec.id!="gate" or world.phase=="ended": return false
	if opened:
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = obstacle.shape
		query.transform = obstacle.global_transform; query.collision_mask = 2|4
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): world.notify("Portão ocupado."); return false
	opened = not opened; collision_layer = 0 if opened else 8
	set_open_visual()
	return true

func build_raised_visual() -> void:
	var color: Color = spec.color.lightened(.08*(tier-1))
	for x in [-.8,.8]:
		for z in [-.8,.8]:
			VisualFactory.box(model,Vector3(.22,3.2,.22),Vector3(x,1.6,z),Color("54675d"))
			VisualFactory.box(model,Vector3(.48,.12,.48),Vector3(x,.06,z),color)
	for y in [.8,1.8,2.8]: VisualFactory.box(model,Vector3(1.8,.14,.18),Vector3(0,y,.8),color)
	VisualFactory.box(model,Vector3(2.1,.22,2.1),Vector3(0,3.14,0),color)
	head = Node3D.new(); head.position.y = 3.6; model.add_child(head)
	VisualFactory.box(head,Vector3(.9,.45,.8),Vector3.ZERO,color)
	VisualFactory.box(head,Vector3(.18,.18,1.3),Vector3(0,0,-.7),Color("263a3a"))
	for i in range(tier): VisualFactory.box(head,Vector3(.1,.12,.24),Vector3(-.3+i*.2,.28,0),Color("d4f889"))
	ClayStyle.apply_tree(model)
