extends StaticBody3D
@export var spec: Resource
var world: Node3D
var health := Health.new()
var model: Node3D
var head: Node3D
var label: Label3D
var cooldown: float = 0.0
var pulse: float = 0.0

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("damageable")
	collision_layer = 8
	collision_mask = 0
	add_child(health)
	health.setup(float(spec.values.health))
	health.died.connect(die)
	var radius: float = spec.values.radius
	VisualFactory.collider(self, Vector3(radius * 2, 1.9, radius * 2), Vector3(0, .95, 0))
	model = Node3D.new()
	add_child(model)
	if spec.id == "barricade":
		for x in [-.8, .8]:
			VisualFactory.box(model, Vector3(.19, 1.75, .2), Vector3(x, .875, 0), Color("514639"))
		for y in [.45, .95, 1.45]:
			VisualFactory.box(model, Vector3(2.1, .3, 1.2), Vector3(0, y, 0), spec.color)
		var bar := VisualFactory.box(model, Vector3(.15, 1.7, .12), Vector3(0, .92, -.67), Color("b8a16a"))
		bar.rotation.z = -.8
	elif spec.id == "turret":
		VisualFactory.cylinder(model, .83, .3, Vector3(0, .15, 0), Color("2e4548"))
		VisualFactory.cylinder(model, .28, 1.0, Vector3(0, .8, 0), spec.color)
		head = Node3D.new()
		model.add_child(head)
		head.position.y = 1.45
		VisualFactory.box(head, Vector3(.9, .5, .8), Vector3.ZERO, spec.color)
		VisualFactory.box(head, Vector3(.18, .18, 1.3), Vector3(0, 0, -.7), Color("1c303a"))
		VisualFactory.box(head, Vector3(.18, .12, .04), Vector3(.27, .05, -.42), Color("c9ec8b"), true)
	else:
		VisualFactory.cylinder(model, 1.8, .35, Vector3(0, .17, 0), Color("243d43"))
		VisualFactory.box(model, Vector3(2.3, 1.65, 2.3), Vector3(0, 1.05, 0), Color("476160"))
		VisualFactory.box(model, Vector3(1.6, .8, 1.6), Vector3(0, 2.2, 0), Color("283e48"))
		VisualFactory.cylinder(model, .45, .8, Vector3(0, 2.35, 0), spec.color, true)
		VisualFactory.ring(model, 1.2, Vector3(0, 2, 0), spec.color)
		var light := OmniLight3D.new()
		model.add_child(light)
		light.position.y = 3
		light.light_color = Color("c7e687")
		light.light_energy = 2
		light.omni_range = 9
	label = VisualFactory.health_label(self, 3.2 if spec.id == "core" else 2.1)
	model.scale = Vector3.ONE * .1
	create_tween().tween_property(model, "scale", Vector3.ONE, .3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	if health.dead or world.phase == "ended":
		return
	pulse += delta
	label.text = ("NÚCLEO  " if spec.id == "core" else "") + "%d / %d" % [ceili(health.current), ceili(health.maximum)]
	label.visible = spec.id == "core" or health.current < health.maximum
	cooldown -= delta
	if spec.id == "turret" and cooldown <= 0 and world.phase == "combat":
		fire_turret()

func fire_turret() -> void:
	var nearest: Node3D = null
	var distance: float = spec.values.range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(enemy.global_position)
		if d < distance:
			var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.45, 0), enemy.global_position + Vector3(0, 1.15, 0), 1 | 4 | 8, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider == enemy:
				nearest = enemy
				distance = d
	if nearest == null:
		return
	var direction: Vector3 = nearest.global_position - global_position
	head.rotation.y = atan2(-direction.x, -direction.z)
	cooldown = float(spec.values.interval)
	world.effects.tracer(global_position + Vector3(0, 1.45, 0), nearest.global_position + Vector3(0, 1.15, 0), Color("72dce0"))
	nearest.take_damage(float(spec.values.damage))
	world.audio.play_tone(440, .035, .045)

func take_damage(amount: float) -> void:
	if health.dead or world.phase == "ended":
		return
	health.take_damage(amount)
	world.effects.burst(global_position + Vector3.UP, Color("f1b96e"), 2)

func repair() -> bool:
	if world.phase != "prep" or health.dead or health.current >= health.maximum:
		return false
	if not world.resources.spend(int(spec.values.repair_cost)):
		world.notify("Sucata insuficiente para reparar.")
		return false
	health.heal(float(spec.values.repair_amount))
	world.effects.burst(global_position + Vector3.UP, Color("bde995"), 8)
	world.notify("Reparo concluído · −%d sucata" % spec.values.repair_cost)
	return true

func die() -> void:
	collision_layer = 0
	remove_from_group("buildings")
	world.effects.burst(global_position + Vector3.UP, Color("efb566"), 12)
	if spec.id == "core":
		world.finish(false, "O núcleo foi destruído.")
	else:
		queue_free()
