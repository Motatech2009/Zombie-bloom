class_name BetaEvents
extends Node
const MAX_ACTORS := 48
var world: Node3D
var rng := RandomNumberGenerator.new()
var events: Array = []
var until_review: float = 25
var serial: int = 0
var migration_chance: float = .045
var local_chance: float = .3
var enabled: bool = true

func _ready() -> void:
	rng.seed = world.state.world_seed ^ 85937

func _process(delta: float) -> void:
	advance(delta)
	materialize()

func advance(delta: float) -> void:
	until_review -= delta
	while until_review <= 0:
		until_review += rng.randf_range(24, 67)
		if enabled:
			review()
	for event: Dictionary in events:
		if event.status != "moving":
			continue
		var current := decode(event.pos)
		var target := decode(event.target)
		current = current.move_toward(target, delta * float(event.speed))
		current.y = world.outdoor.generator.height_at(Vector2(current.x, current.z))
		event.pos = encode(current)
		if current.distance_to(target) < 3 or int(event.count) <= 0:
			event.status = "finished"
		# Off-screen attacks require an actual previously perceived light/noise stimulus.
		if event.get("attracted", false) and current.length() < 7 and (world.inside or world.player.global_position.length() > 75):
			world.core.take_damage(delta * int(event.count) * .15)
		if world.time.hour() < 6 or world.time.hour() > 18:
			if current.distance_to(Vector3.ZERO) < 12:
				event.target = encode(Vector3.ZERO)
				event.attracted = true
	events = events.filter(func(event): return event.status == "moving" or actor_count(event.id) > 0)

func review() -> void:
	var migrants := events.filter(func(event): return event.migration and event.status == "moving").size()
	var anchor: Vector3 = world.return_position if world.inside else world.player.position
	var density := .8
	for settlement: Dictionary in world.outdoor.generator.settlements:
		if Vector2(anchor.x, anchor.z).distance_to(settlement.pos) < 50:
			density = 1.45 if settlement.kind == "city" else 1.1
	var progression := 1.0 + minf(10, world.time.day() - 1) * .03
	if migrants < 2 and rng.randf() < minf(.12, migration_chance * density * progression):
		create_event(true)
	if not world.inside and events.filter(func(event): return not event.migration and event.status == "moving").size() < 1 and rng.randf() < minf(.65, local_chance * density):
		create_event(false)

func create_event(migration: bool) -> Dictionary:
	var anchor: Vector3 = world.return_position if world.inside else world.player.global_position
	var region: Vector2i = world.outdoor.generator.region_coord(Vector2(anchor.x, anchor.z))
	var horizontal := rng.randf() > .5
	var side := -1 if rng.randf() < .5 else 1
	var start: Vector3
	var target: Vector3
	if horizontal:
		start = Vector3(anchor.x + side * 90, 0, region.y * 512 - 32)
		target = start + Vector3(-side * rng.randf_range(260, 420), 0, 0)
	else:
		start = Vector3(region.x * 512, 0, anchor.z + side * 90)
		target = start + Vector3(0, 0, -side * rng.randf_range(260, 420))
	if not migration:
		var angle := rng.randf() * TAU
		start = anchor + Vector3(cos(angle), 0, sin(angle)) * 48
		target = start + Vector3(rng.randf_range(-28, 28), 0, rng.randf_range(-28, 28))
	if world.outdoor.generator.is_water(Vector2(start.x, start.z)):
		return {}
	if world.outdoor.generator.is_water(Vector2(target.x, target.z)):
		target = start + Vector3(12, 0, 0)
	start.y = world.outdoor.generator.height_at(Vector2(start.x, start.z))
	if not world.inside and world.camera.is_position_in_frustum(start + Vector3.UP):
		return {}
	serial += 1
	var event := {"id": "event:%d" % serial, "migration": migration, "pos": encode(start), "target": encode(target), "count": rng.randi_range(12, 40) if migration else rng.randi_range(3, 8), "speed": rng.randf_range(.8, 1.3), "status": "moving", "attracted": false}
	events.append(event)
	return event

func hear(pos: Vector3, radius: float) -> void:
	for event: Dictionary in events:
		if decode(event.pos).distance_to(pos) <= radius and event.status == "moving":
			event.target = encode(pos)
			event.attracted = true

func actor_count(id: String) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("beta_enemies"):
		if enemy.event_id == id and not enemy.health.dead and not enemy.is_queued_for_deletion():
			count += 1
	return count

func find_event(id: String) -> Dictionary:
	for event: Dictionary in events:
		if event.id == id:
			return event
	return {}

func materialize() -> void:
	for enemy in get_tree().get_nodes_in_group("beta_enemies"):
		if world.inside or enemy.global_position.distance_to(world.player.global_position) > 95:
			enemy.remove_from_group("beta_enemies")
			enemy.remove_from_group("enemies")
			enemy.queue_free()
	if world.inside or world.phase == "ended":
		return
	var budget := 2
	for event: Dictionary in events:
		var pos := decode(event.pos)
		if event.status != "moving" or pos.distance_to(world.player.position) > 86:
			continue
		if event.migration and pos.distance_to(world.player.position) < 60 and not event.get("captioned", false):
			event.captioned = true
			world.notify("Você ouve numerosos passos ao longe.")
			world.audio.play_tone(90, .5, .12)
		var count := actor_count(event.id)
		while count < int(event.count) and budget > 0 and get_tree().get_nodes_in_group("beta_enemies").size() < MAX_ACTORS:
			var candidate := pos + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
			if not valid_spawn(candidate):
				break
			world.spawn_beta_enemy(candidate, event.id, rng.randf() < .2)
			budget -= 1
			count += 1

func valid_spawn(pos: Vector3) -> bool:
	if world.inside or pos.distance_to(world.player.global_position) < 24 or not world.outdoor.sectors.has(WorldGenerator.sector_at(pos)):
		return false
	pos.y = world.outdoor.generator.height_at(Vector2(pos.x, pos.z))
	var visible := false
	for offset: Vector3 in [Vector3(-1, .5, 0), Vector3(1, .5, 0), Vector3(0, 1.9, -1), Vector3(0, 1.9, 1)]:
		visible = visible or world.camera.is_position_in_frustum(pos + offset)
	if visible or world.outdoor.generator.is_water(Vector2(pos.x, pos.z)):
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .7
	query.shape = shape
	query.transform.origin = pos + Vector3.UP
	query.collision_mask = 1 | 2 | 8
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func defeated(id: String) -> void:
	var event := find_event(id)
	if not event.is_empty():
		event.count = maxi(0, int(event.count) - 1)

func serialize() -> Dictionary:
	return {"events": events.duplicate(true), "remaining": until_review, "serial": serial, "rng_state": str(rng.state)}

func restore(data: Dictionary) -> void:
	events = data.events.duplicate(true)
	until_review = float(data.remaining)
	serial = int(data.serial)
	rng.state = int(data.rng_state)

static func encode(pos: Vector3) -> Array:
	return [pos.x, pos.y, pos.z]
static func decode(pos: Array) -> Vector3:
	return Vector3(pos[0], pos[1], pos[2])
