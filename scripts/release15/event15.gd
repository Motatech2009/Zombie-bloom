extends StaticBody3D

var world: Node3D
var event_key := ""
var kind := "nest"
var health := Health.new()
var label: Label3D
var net_id := 0
var aim_height := 1.15
var escort_rig: Node3D
var escort_heading := 0.0
var escort_motion := 0.0
var escort_recoil := 0.0
var escort_clock := 0.0
var fire_left := 0.0
var route_left := 0.0
var route := PackedVector2Array()
var waypoint := 0

func _ready() -> void:
	add_child(health)
	health.setup(Director15.NEST_MAX_HP if kind == "nest" else 100.0)
	match kind:
		"nest":
			add_to_group("enemy_nests")
			if not world.is_client:
				net_id = world.next_id()
				set_meta("uid", net_id)
				var state: Dictionary = world.v15.event_states.get(event_key, {})
				var previous_max := Director15.NEST_MAX_HP if state.get("nest17", false) else 240.0
				health.current = clampf(float(state.get("hp", previous_max)) / previous_max * health.maximum, .001, health.maximum)
				state.hp = health.current
				state.nest17 = true
			collision_layer = 4
			add_to_group("damageable")
			health.died.connect(func(): world.v15.destroy_nest(event_key))
			VisualFactory.collider(self, Vector3(2.4, 2.2, 2.4), Vector3(0, 1, 0))
			for i in range(4):
				VisualFactory.cylinder(self, .6, 1.5, Vector3((i % 2 - .5) * 1.1, .7, (i / 2 - .5) * 1.1), Color("a278c5"))
		"convoy":
			collision_layer = 1
			VisualFactory.collider(self, Vector3(3, 2, 5), Vector3(0, 1, 0))
			add_child(preload("res://assets/scenery/tripo16/comboio/convoy.tscn").instantiate())
		"escort":
			collision_layer = 0
			escort_rig = VisualFactory.human(self, Color("a5b897"), true)
	label = VisualFactory.health_label(self, 2.8)
	label.text = {
		"nest": "NINHO DE ESPOROS · destrua",
		"convoy": "COMBOIO · E / COLETAR inicia defesa de %d s" % int(Director15.CONVOY_SECONDS),
		"escort": "SOBREVIVENTE · E / COLETAR para escoltar",
	}.get(kind, kind)

func _process(delta: float) -> void:
	if escort_rig == null: return
	escort_clock += delta
	escort_recoil = maxf(0.0, escort_recoil - delta * 6.0)
	escort_rig.rotation.y = lerp_angle(escort_rig.rotation.y, escort_heading, 1.0 - exp(-delta * 14.0))
	VisualFactory.animate_human(escort_rig, escort_clock, escort_motion, escort_recoil, true)

func apply_escort_pose(heading: float, moving: float, recoil: float) -> void:
	escort_heading = heading
	escort_motion = moving
	escort_recoil = maxf(escort_recoil, recoil)

func follow_and_cover(owner: Node3D, destination: Vector3, stop_distance: float, delta: float) -> void:
	var offset := (destination - global_position) * Vector3(1, 0, 1)
	escort_motion = 0.0
	if offset.length() > stop_distance:
		var direction := escort_direction(owner.region_coord, destination, offset, delta)
		for angle in [0.0, .75, -.75, 1.4, -1.4]:
			var step := direction.rotated(Vector3.UP, angle) * minf(delta * 4.4, offset.length() - stop_distance)
			if blocked(global_position + Vector3.UP, global_position + step + Vector3.UP):
				continue
			global_position += step
			escort_heading = atan2(-step.x, -step.z)
			escort_motion = 1.0
			break
	fire_left = maxf(0.0, fire_left - delta)
	if fire_left > 0.0: return
	fire_left = .18
	var origin := global_position + Vector3.UP * 1.18
	var best := 15.0 * 15.0
	var target: Node3D
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health.dead or enemy.is_queued_for_deletion() or world.coord_at(enemy.global_position) != owner.region_coord:
			continue
		var point: Vector3 = enemy.global_position + Vector3.UP * enemy.aim_height
		var distance := origin.distance_squared_to(point)
		if distance < best and not blocked(origin, point):
			best = distance
			target = enemy
	if target == null: return
	var hit: Vector3 = target.global_position + Vector3.UP * target.aim_height
	var direction := hit - origin
	escort_heading = atan2(-direction.x, -direction.z)
	escort_recoil = .85
	fire_left = .68
	world.shot_visual(origin, hit, Color("f8d98b"))
	var previous_owner: int = world.shot_owner
	world.shot_owner = owner.peer_id
	target.take_damage(16.0)
	world.shot_owner = previous_owner

func escort_direction(coord: Vector2i, destination: Vector3, offset: Vector3, delta: float) -> Vector3:
	if not blocked(global_position + Vector3.UP, destination + Vector3.UP):
		route.clear()
		route_left = 0.0
		return offset.normalized()
	route_left -= delta
	if route_left <= 0.0:
		route_left = .55
		var origin: Vector3 = world.sector_offset(coord)
		var navigation: Arena = world.base_arena if coord == Vector2i.ZERO else world.arena
		if coord != world.sector_coord and coord != Vector2i.ZERO:
			navigation = world.regions.sessions.get(coord, {}).get("arena")
		route = navigation.route(global_position - origin, destination - origin) if is_instance_valid(navigation) else PackedVector2Array()
		waypoint = mini(1, route.size())
	var local: Vector3 = global_position - world.sector_offset(coord)
	while waypoint < route.size():
		var point := route[waypoint]
		var next := Vector3(point.x - local.x, 0, point.y - local.z)
		if next.length_squared() > .65 * .65:
			return next.normalized()
		waypoint += 1
	return offset.normalized()

func blocked(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func disappear() -> void:
	label.hide()
	escort_motion = 0.0
	var tween := create_tween()
	tween.tween_property(escort_rig, "scale", Vector3.ONE * .03, .24)
	tween.tween_callback(queue_free)

func take_damage(amount: float) -> void:
	if kind != "nest" or world.is_client or health.dead: return
	health.take_damage(amount)
	if world.v15.event_states.has(event_key):
		world.v15.event_states[event_key].hp = health.current
