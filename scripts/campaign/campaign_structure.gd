extends "res://scripts/entities/building.gd"
var piece_index: int = 0
var tier: int = 1
var disabled_left: float = 0
var opened: bool = false
var obstacle: CollisionShape3D
var invested: Dictionary = {"scrap":0,"wood":0,"parts":0}

func _ready() -> void:
	var data: Dictionary = CampaignData.PIECES[piece_index]
	spec = GameSpec.new()
	spec.id = data.id
	spec.title = data.title
	spec.color = data.color
	spec.values = {"health":data.health,"radius":1.0,"cost":data.cost.scrap,"range":15.0,"interval":.65,"damage":15.0,"repair_cost":8,"repair_amount":90.0}
	add_to_group("buildings")
	add_to_group("damageable")
	add_to_group("campaign_structure")
	collision_layer = 0 if spec.id == "spikes" else 8
	collision_mask = 0
	add_child(health)
	health.setup(data.health)
	health.died.connect(die)
	obstacle = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = data.size
	obstacle.shape = shape
	obstacle.position.y = data.size.y/2
	add_child(obstacle)
	model = Node3D.new()
	add_child(model)
	if spec.id == "turret":
		VisualFactory.cylinder(model,.8,.35,Vector3(0,.18,0),Color("2e4548"))
		VisualFactory.cylinder(model,.25,.9,Vector3(0,.7,0),data.color)
		head = Node3D.new()
		model.add_child(head)
		head.position.y = 1.45
		VisualFactory.box(head,Vector3(.9,.5,.8),Vector3.ZERO,data.color)
		VisualFactory.box(head,Vector3(.18,.18,1.3),Vector3(0,0,-.7),Color("1c303a"))
	elif spec.id in ["barricade","gate"]:
		for x in [-1.3,1.3]: VisualFactory.box(model,Vector3(.2,data.size.y,.5),Vector3(x,data.size.y/2,0),Color("554c3b"))
		for y in [.45,1.0,1.55]: VisualFactory.box(model,Vector3(2.8,.28,.6),Vector3(0,y,0),data.color)
	elif spec.id == "spikes":
		VisualFactory.box(model,Vector3(2,.16,2),Vector3(0,.08,0),Color("4b5147"))
		for x in [-.65,0,.65]:
			for z in [-.65,0,.65]:
				var stake := VisualFactory.box(model,Vector3(.15,.8,.15),Vector3(x,.4,z),data.color)
				stake.rotation.z = .3
	elif spec.id == "station":
		VisualFactory.box(model,Vector3(2,1.1,2),Vector3(0,.55,0),data.color)
		VisualFactory.box(model,Vector3(.9,.14,.35),Vector3(0,1.2,0),Color("e0ead0"))
		VisualFactory.box(model,Vector3(.35,.14,.9),Vector3(0,1.2,0),Color("e0ead0"))
	else:
		VisualFactory.box(model,data.size,Vector3(0,data.size.y/2,0),data.color)
		VisualFactory.box(model,Vector3(3.1,.18,1.2),Vector3(0,data.size.y,0),Color("3d5057"))
	label = VisualFactory.health_label(self,data.size.y+.5)
	refresh_tier()

func _physics_process(delta: float) -> void:
	if health.dead or world.phase == "ended": return
	label.text = "%s N%d · %d/%d" % [spec.title,tier,ceili(health.current),ceili(health.maximum)]
	label.visible = health.current < health.maximum or global_position.distance_to(world.player.global_position) < 5
	disabled_left = maxf(0,disabled_left-delta)
	if disabled_left>0:
		label.visible = true
		label.text = "EMP · %.1f s" % disabled_left
		return
	cooldown -= delta
	if spec.id == "turret" and cooldown <= 0 and world.phase == "combat": fire_turret()
	if spec.id == "spikes" and cooldown <= 0:
		var hit := false
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if absf(enemy.global_position.x-global_position.x)<1.3 and absf(enemy.global_position.z-global_position.z)<1.3:
				enemy.take_damage(14.0*tier)
				hit = true
		if hit: cooldown = .8
	if spec.id == "station" and cooldown <= 0 and (world.phase == "prep" or (world.has_method("base_preparing") and world.base_preparing())):
		world.player.health.heal(5*tier) if global_position.distance_to(world.player.global_position)<5 else 0
		for building in get_tree().get_nodes_in_group("buildings"):
			if building.global_position.distance_to(global_position)<6: building.health.heal(3*tier)
		cooldown = 2

func toggle() -> bool:
	if spec.id != "gate" or world.phase == "ended": return false
	if opened:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = obstacle.shape
		query.transform = obstacle.global_transform
		query.collision_mask = 2|4
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			world.notify("Portão ocupado: afaste o personagem ou o infectado antes de fechar.")
			return false
	opened = not opened
	collision_layer = 0 if opened else 8
	model.position.y = -1.65 if opened else 0
	return true

func upgrade_cost() -> Dictionary:
	return {"scrap":20*tier,"wood":3*tier,"parts":2*tier}

func improve() -> bool:
	if tier >= 3 or world.phase != "prep" or world.area_index != -1 or health.dead: return false
	var price := upgrade_cost()
	if not world.pay(price): return false
	for key in invested: invested[key] += price[key]
	tier += 1
	var old_max := health.maximum
	refresh_tier()
	health.heal(health.maximum-old_max)
	world.notify("%s reforçada para N%d." % [spec.title,tier])
	return true

func refresh_tier() -> void:
	health.maximum = float(CampaignData.PIECES[piece_index].health)*(1+.65*(tier-1))
	spec.values.damage = 15.0*(1+.45*(tier-1))
	spec.values.interval = .65/(1+.18*(tier-1))
	spec.values.range = 15.0 + tier-1
	for i in range(1,tier):
		if not model.has_node("Tier%d" % i):
			var bar := VisualFactory.box(model,Vector3(.18,1.1,.18),Vector3(-.45+i*.3,1.8,0),Color("d4f889"))
			bar.name = "Tier%d" % i

func dismantle() -> bool:
	if world.phase != "prep" or world.area_index != -1 or health.dead: return false
	for key in invested: world.credit(key,int(invested[key]) / 2)
	health.dead = true
	collision_layer = 0
	remove_from_group("buildings")
	remove_from_group("campaign_structure")
	world.layout_revision += 1
	queue_free()
	world.notify("Estrutura desmontada · 50% dos materiais recuperados.")
	return true

func die() -> void:
	world.layout_revision += 1
	remove_from_group("campaign_structure")
	super.die()

func fire_turret() -> void:
	if disabled_left>0: return
	var nearest: Node3D
	var distance: float = spec.values.range
	var origin := global_position+Vector3(0,1.45,0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var point: Vector3 = enemy.global_position+Vector3(0,enemy.aim_height,0)
		var d := origin.distance_to(point)
		if d>=distance: continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point,1|4|8,[get_rid()]))
		if not hit.is_empty() and hit.collider==enemy:
			nearest = enemy
			distance = d
	if nearest==null: return
	var point: Vector3 = nearest.global_position+Vector3(0,nearest.aim_height,0)
	var direction := point-origin
	head.rotation.y = atan2(-direction.x,-direction.z)
	cooldown = float(spec.values.interval)
	world.effects.tracer(origin,point,Color("72dce0"))
	nearest.take_damage(float(spec.values.damage))
