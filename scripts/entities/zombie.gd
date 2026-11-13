extends CharacterBody3D
@export var spec: Resource
var world: Node3D
var health := Health.new()
var rig: Node3D
var label: Label3D
var target: Node3D
var path := PackedVector2Array()
var path_index: int = 0
var think_left: float = 0
var attack_left: float = 0
var clock: float = 0
var recoil: float = 0
var state: String = "spawn"

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	collision_layer = 4
	collision_mask = 1 | 2 | 8
	var scale_factor: float = spec.values.scale
	var shape := CapsuleShape3D.new()
	shape.radius = .36 * scale_factor
	shape.height = 1.8 * scale_factor
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.height * .5
	add_child(collision)
	add_child(health)
	health.setup(float(spec.values.health) * (1.0 + maxi(0, world.waves.wave - 1) * .1))
	health.died.connect(die)
	rig = VisualFactory.human(self, spec.color, false)
	rig.scale = Vector3.ONE * scale_factor
	label = VisualFactory.health_label(self, 2.15 * scale_factor)
	label.visible = false
	think_left = randf_range(0, .65)
	clock = randf() * 10
	state = "seek"
	var tween := create_tween()
	rig.position.y = -.4
	tween.tween_property(rig, "position:y", 0.0, .25)

func _physics_process(delta: float) -> void:
	if health.dead or world.phase == "ended":
		return
	clock += delta
	attack_left = maxf(0, attack_left - delta)
	recoil = move_toward(recoil, 0, delta * 3)
	think_left -= delta
	if (think_left <= 0 or not is_instance_valid(target)) and (not world.has_method("allow_enemy_think") or world.allow_enemy_think(self)):
		think_left = randf_range(.5, .85)
		choose_target()
		path = world.route_for_enemy(self,target.global_position) if world.has_method("route_for_enemy") else world.arena.route(global_position, target.global_position)
		path_index = 1 if path.size() > 1 else 0
	if not is_instance_valid(target): choose_target()
	var goal: Vector3 = target.global_position
	if path_index < path.size():
		goal = Vector3(path[path_index].x, 0, path[path_index].y)
		if global_position.distance_to(goal) < 1.0:
			path_index += 1
	var direction := goal - global_position
	direction.y = 0
	direction = direction.normalized()
	velocity = direction * float(spec.values.speed)
	velocity.y = -1
	state = "move"
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var body := get_slide_collision(i).get_collider()
		if is_instance_valid(body) and body.has_method("take_damage") and not body.is_in_group("enemies"):
			state = "attack"
			if attack_left <= 0:
				attack_left = float(spec.values.interval)
				body.take_damage(float(spec.values.damage))
				recoil = .65
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 12))
	VisualFactory.animate_human(rig, clock * float(spec.values.speed) / 2, 1.0 if state == "move" else .15, recoil, false)
	if not label.has_meta("suppressed"):
		label.visible = health.current < health.maximum
		label.text = "%d" % ceili(health.current)

func choose_target() -> void:
	var chase_distance := 15.0 if spec.id == "runner" else 10.0
	if not world.player.health.dead and global_position.distance_to(world.player.global_position) < chase_distance:
		target = world.player
	else:
		target = world.core

func take_damage(amount: float) -> void:
	if health.dead:
		return
	recoil = .4
	health.take_damage(amount)

func die() -> void:
	state = "dead"
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	label.visible = false
	world.enemy_defeated(self)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(rig, "rotation:x", PI * .48, .3)
	tween.tween_property(rig, "scale", Vector3.ONE * .05, .5).set_delay(.2)
	tween.chain().tween_callback(queue_free)
