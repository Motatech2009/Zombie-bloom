extends "res://scripts/entities/zombie.gd"
var event_id: String = ""
var last_known := Vector3.ZERO
var alert_left: float = 0
var can_see: bool = false

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	add_to_group("beta_enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 8
	var factor: float = spec.values.scale
	var shape := CapsuleShape3D.new()
	shape.radius = .36 * factor
	shape.height = 1.8 * factor
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.height * .5
	add_child(collision)
	add_child(health)
	health.setup(spec.values.health)
	health.died.connect(die)
	rig = Node3D.new()
	add_child(rig)
	rig.scale = Vector3.ONE * factor
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		rig.add_child(leg)
		leg.position = Vector3(side * .19, .7, 0)
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		rig.add_child(arm)
		arm.position = Vector3(side * .43, 1.33, 0)
	label = VisualFactory.health_label(self, 2.15 * factor)
	label.visible = false
	think_left = float(get_instance_id() % 11) * .04
	last_known = position

func _physics_process(delta: float) -> void:
	if health.dead or world.phase == "ended" or world.inside:
		return
	clock += delta
	attack_left = maxf(0, attack_left - delta)
	alert_left = maxf(0, alert_left - delta)
	recoil = move_toward(recoil, 0, delta * 3)
	think_left -= delta
	if think_left <= 0:
		think_left = .45 + float(get_instance_id() % 7) * .03
		perceive()
	var goal := last_known
	if alert_left <= 0:
		var event: Dictionary = world.director.find_event(event_id)
		if not event.is_empty():
			goal = BetaEvents.decode(event.pos)
	elif can_see:
		goal = world.player.global_position
	if think_left < .04 or path.is_empty():
		path = world.outdoor.route(global_position, goal)
		path_index = 1 if path.size() > 1 else 0
	if path_index < path.size():
		var point: Vector2 = path[path_index]
		var step := Vector3(point.x, global_position.y, point.y)
		if global_position.distance_to(step) < .8:
			path_index += 1
		else:
			goal = step
	var direction := goal - global_position
	direction.y = 0
	if direction.length() < .8:
		direction = Vector3.ZERO
	else:
		direction = direction.normalized()
	velocity = direction * float(spec.values.speed) * (1.0 if alert_left > 0 else .7)
	velocity.y = -2
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var body := get_slide_collision(i).get_collider()
		if attack_left <= 0 and alert_left > 0 and is_instance_valid(body) and body.has_method("take_damage") and not body.is_in_group("enemies"):
			body.take_damage(float(spec.values.damage))
			attack_left = float(spec.values.interval)
			recoil = .65
	if direction.length_squared() > 0:
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 12))
	VisualFactory.animate_human(rig, clock * float(spec.values.speed) / 2, direction.length(), recoil, false)
	label.visible = health.current < health.maximum
	label.text = str(ceili(health.current))

func perceive() -> void:
	can_see = false
	var radius := 18.0 if spec.id == "runner" else 13.0
	if world.time.hour() < 6 or world.time.hour() > 18:
		radius *= .65 if not world.time.lantern_on else 1.3
	radius *= 1 - world.time.weather * BetaOptions.fog_strength * .25
	if global_position.distance_to(world.player.global_position) < radius:
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, world.player.global_position + Vector3.UP, 1 | 2 | 8, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		can_see = not hit.is_empty() and hit.collider == world.player
	if can_see:
		last_known = world.player.global_position
		alert_left = 7
	else:
		for sound: Dictionary in world.noises:
			var pos := BetaEvents.decode(sound.pos)
			if global_position.distance_to(pos) < float(sound.radius):
				last_known = pos
				alert_left = 5
	var goal := last_known
	if alert_left <= 0:
		var event: Dictionary = world.director.find_event(event_id)
		if not event.is_empty():
			goal = BetaEvents.decode(event.pos)
	path = world.outdoor.route(global_position, goal)
	path_index = 1 if path.size() > 1 else 0
