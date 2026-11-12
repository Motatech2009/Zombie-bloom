extends "res://scripts/systems/game_world.gd"
const SAVE_PATH := "user://ultimo_refugio_v1.json"
const INTERIOR_SCENE = preload("res://scenes/world/Interior.tscn")
const FRONTIER_HUD = preload("res://scripts/world/frontier_hud.gd")
var state := WorldState.new()
var outdoor: StreamedRegion
var inside: bool = false
var interior: InteriorRoom
var current_house: Dictionary = {}
var return_position := Vector3.ZERO
var suspended: Array[Node] = []
var focused: WorldInteraction
var interaction_text: String = ""
var ambient_timer: float = 12
var save_path: String = SAVE_PATH
var checkpoint_requested: bool = false
var load_requested: bool = false

func _ready() -> void:
	arena.free()
	waves.free()
	outdoor = StreamedRegion.new()
	outdoor.world = self
	arena = outdoor
	waves = FrontierWaves.new()
	waves.world = self
	state.world_seed = WorldState.next_seed
	if WorldState.resume_requested:
		var candidate := WorldState.new()
		var status := candidate.read_save(save_path)
		if status == OK and snapshot_valid(candidate.snapshot):
			state = candidate
		else:
			notify("Não foi possível carregar o refúgio (%d)." % status)
	WorldState.resume_requested = false
	super._ready()
	# Replace only the HUD; the classic arena remains available as a separate mode.
	remove_child(hud)
	hud.queue_free()
	hud = CanvasLayer.new()
	hud.set_script(FRONTIER_HUD)
	hud.world = self
	add_child(hud)
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	if not state.snapshot.is_empty():
		restore_snapshot()
	notice = "F extrai e interage · M abre o mapa · Deposite a carga no núcleo."
	notice_left = 9

func _process(delta: float) -> void:
	if phase != "ended":
		elapsed += delta
		notice_left = maxf(0, notice_left - delta)
	if not inside:
		var target := player.global_position
		camera.global_position = camera.global_position.lerp(target + camera_offset, 1.0 - exp(-delta * 5))
		camera.look_at(target)
	if phase == "ended":
		return
	if not inside:
		outdoor.focus(player.global_position)
		ambient_timer -= delta
		if ambient_timer <= 0:
			ambient_timer = 10
			spawn_wanderer()
	update_interaction(delta)
	if checkpoint_requested:
		checkpoint_requested = false
		save_checkpoint()
	if load_requested:
		load_requested = false
		load_checkpoint()

func _unhandled_input(event: InputEvent) -> void:
	if phase == "ended":
		return
	if event.is_action_pressed("field_use") and not event.is_echo():
		if not inside and player.global_position.length() < 5:
			deposit_cargo()
		elif is_instance_valid(focused):
			focused.use.call_deferred()
	if event.is_action_pressed("save_world"):
		checkpoint_requested = true
	if event.is_action_pressed("load_world"):
		load_requested = true
	if event.is_action_pressed("upgrade_defense"):
		upgrade_defense()
	if inside:
		return
	super._unhandled_input(event)

func update_interaction(delta: float) -> void:
	var previous := focused
	focused = null
	var distance := 2.8
	for prop: WorldInteraction in get_tree().get_nodes_in_group("world_interactions"):
		prop.label.visible = false
		if not prop.available() or not prop.is_visible_in_tree() or prop.is_queued_for_deletion():
			continue
		var d := player.global_position.distance_to(prop.global_position)
		if d < distance:
			# Interactions cannot pass through walls or a different prop.
			var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, prop.global_position + Vector3.UP, 1 | 8, [player.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.position.distance_to(prop.global_position + Vector3.UP) > 1.15 and not prop.is_ancestor_of(hit.collider):
				continue
			distance = d
			focused = prop
	if is_instance_valid(previous) and previous != focused:
		previous.progress = 0
	interaction_text = "F · Depositar carga no refúgio" if not inside and player.global_position.length() < 5 else "Procure árvores, rochas, caixas e entradas."
	if is_instance_valid(focused):
		focused.label.visible = true
		focused.label.text = "F" if focused.kind in ["entry", "exit", "door"] else "RECURSO"
		if Input.is_action_pressed("field_use") and not builder.active:
			focused.extract(delta)
		else:
			focused.progress = 0
		interaction_text = focused.prompt()

func deposit_cargo() -> int:
	if inside or player.global_position.length() >= 5:
		return 0
	var amount := state.deposit()
	resources.add_loot(0, amount)
	notify("DEPÓSITO · +%d sucata reaproveitável para construção e reparos." % amount if amount > 0 else "Depósito vazio. Explore e extraia recursos com F.")
	return amount

func enter_building(data: Dictionary) -> bool:
	if inside or phase != "prep" or builder.active:
		return false
	var entry := Vector3(data.pos.x, 0, data.pos.y - data.depth * .5 - 1.4)
	if player.global_position.distance_to(entry) > 3:
		return false
	if enemies_nearby(18):
		notify("Afaste os hostis antes de entrar.")
		return false
	inside = true
	current_house = data.duplicate(true)
	return_position = entry + Vector3(0, 0, -1)
	suspended.clear()
	for child in get_children():
		if child is Node3D and child not in [player, camera, effects, builder]:
			suspended.append(child)
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.hide()
	waves.set_physics_process(false)
	builder.set_active(false)
	interior = INTERIOR_SCENE.instantiate()
	interior.world = self
	interior.data = current_house
	interior.position = Vector3(10000, 0, 10000)
	add_child(interior)
	arena = interior
	player.global_position = interior.global_position + Vector3(-3, 0, -6)
	player.velocity = Vector3.ZERO
	camera_offset = Vector3(15, 23, 15)
	snap_camera()
	notify("INTERIOR · " + WorldGenerator.building_title(data.kind).to_upper() + " · F abre portas, extrai e sai.")
	return true

func leave_building() -> bool:
	if not inside:
		return false
	var exit_pos: Vector3 = interior.global_position + Vector3(-3, 0, -7.5)
	if player.global_position.distance_to(exit_pos) > 3:
		return false
	remove_child(interior)
	interior.queue_free()
	interior = null
	inside = false
	arena = outdoor
	for child in suspended:
		if is_instance_valid(child):
			child.process_mode = Node.PROCESS_MODE_INHERIT
			child.show()
	suspended.clear()
	waves.set_physics_process(true)
	player.global_position = return_position
	player.velocity = Vector3.ZERO
	camera_offset = Vector3(20, 26, 20)
	snap_camera()
	focused = null
	notify("Você voltou à estrada. A carga permanece na mochila.")
	return true

func snap_camera() -> void:
	var target := player.global_position
	if inside:
		target = interior.global_position
	camera.global_position = target + camera_offset
	camera.look_at(target)

func _physics_process(_delta: float) -> void:
	# Interior coordinates are separate from global outdoor coordinates.
	if inside:
		camera.global_position = interior.global_position + camera_offset
		camera.look_at(interior.global_position)

func spawn_pickup(pos: Vector3, experience: int, metal: int, power: String = "") -> Node3D:
	var pickup := Node3D.new()
	pickup.set_script(preload("res://scripts/world/frontier_pickup.gd"))
	pickup.world = self
	pickup.position = pos
	pickup.xp = experience
	pickup.scrap = metal
	pickup.power = power
	add_child(pickup)
	return pickup

func enemies_nearby(radius: float) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(player.global_position) < radius:
			return true
	return false

func spawn_wanderer() -> void:
	for old_enemy in get_tree().get_nodes_in_group("wanderers"):
		if old_enemy.global_position.distance_to(player.global_position) > 85:
			old_enemy.remove_from_group("enemies")
			old_enemy.remove_from_group("wanderers")
			old_enemy.queue_free()
	if inside or player.global_position.length() < 24 or get_tree().get_nodes_in_group("enemies").size() >= 12:
		return
	var angle := randf() * TAU
	var pos := player.global_position + Vector3(cos(angle), 0, sin(angle)) * 23
	if not outdoor.sectors.has(WorldGenerator.sector_at(pos)) or outdoor.generator.reserved(Vector2(pos.x, pos.z), .8):
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .65
	query.shape = shape
	query.transform.origin = pos + Vector3.UP
	query.collision_mask = 1 | 8
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return
	var enemy := CharacterBody3D.new()
	enemy.set_script(preload("res://scripts/world/frontier_enemy.gd"))
	enemy.spec = Catalog.ENEMIES[0]
	enemy.world = self
	enemy.position = pos
	add_child(enemy)
	enemy.add_to_group("wanderers")

func upgrade_defense() -> bool:
	if inside or phase != "prep":
		return false
	var nearest: Node3D = null
	var distance := 4.0
	for building in get_tree().get_nodes_in_group("buildings"):
		var d := player.global_position.distance_to(building.global_position)
		if d < distance:
			distance = d
			nearest = building
	if nearest == null:
		notify("Aproxime-se de uma defesa ou do núcleo para melhorar com U.")
		return false
	var tier: int = nearest.get_meta("tier", 0)
	if tier >= 3:
		notify("Esta estrutura já recebeu as três melhorias de resistência.")
		return false
	if not resources.spend(40 * (tier + 1)):
		notify("Melhoria de resistência custa %d sucata." % (40 * (tier + 1)))
		return false
	nearest.set_meta("tier", tier + 1)
	nearest.health.maximum += 75
	nearest.health.heal(75)
	notify("ESTRUTURA NV. %d · +75 de resistência máxima." % (tier + 2))
	return true

func save_checkpoint(path: String = "") -> Error:
	if path.is_empty():
		path = save_path
	if inside or phase != "prep" or player.global_position.length() > 8 or enemies_nearby(20):
		notify("Salve no refúgio, entre hordas e sem hostis próximos.")
		return ERR_BUSY
	var gun: WeaponSystem = player.weapons
	var defenses: Array = []
	for building in get_tree().get_nodes_in_group("buildings"):
		if building == core:
			continue
		defenses.append({"kind": building.spec.id, "pos": encode_position(building.position), "hp": building.health.current, "maximum": building.health.maximum, "tier": building.get_meta("tier", 0)})
	state.snapshot = {"position": encode_position(player.global_position), "hp": player.health.current, "maximum": player.health.maximum, "core_hp": core.health.current, "core_maximum": core.health.maximum, "core_tier": core.get_meta("tier", 0), "scrap": resources.scrap, "xp": resources.xp, "level": resources.level, "pending": resources.pending, "wave": waves.wave, "kills": kills, "elapsed": elapsed, "defenses": defenses, "weapon": {"slot": gun.slot, "ammo": gun.ammo, "damage": gun.damage_multiplier, "rate": gun.rate_multiplier, "capacity": gun.capacity_multiplier, "reload": gun.reload_multiplier, "level": gun.level}, "speed": player.speed_multiplier}
	var status := state.write(path)
	notify("REFÚGIO SALVO · F9 restaura este ponto." if status == OK else "Falha ao salvar (%d)." % status)
	return status

static func encode_position(pos: Vector3) -> Array:
	return [pos.x, pos.y, pos.z]

func snapshot_valid(data: Dictionary) -> bool:
	if not data.get("position") is Array or data.position.size() != 3 or not data.get("defenses") is Array or not data.get("weapon") is Dictionary:
		return false
	for key in ["hp", "maximum", "core_hp", "core_maximum", "core_tier", "scrap", "xp", "level", "pending", "wave", "kills", "elapsed", "speed"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])) or float(data[key]) < 0:
			return false
	if data.hp <= 0 or data.core_hp <= 0 or data.maximum < data.hp or data.core_maximum < data.core_hp or data.defenses.size() > 24:
		return false
	for coordinate in data.position:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(coordinate) > 10:
			return false
	for building in data.defenses:
		if not building is Dictionary or not building.get("kind") in ["barricade", "turret"] or not building.get("pos") is Array or building.pos.size() != 3:
			return false
		for key in ["hp", "maximum", "tier"]:
			if not (building.get(key) is float or building.get(key) is int) or not is_finite(float(building[key])) or building[key] < 0:
				return false
		for coordinate in building.pos:
			if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(coordinate) > 24:
				return false
	var gun: Dictionary = data.weapon
	if not gun.get("ammo") is Array or gun.ammo.size() != 3:
		return false
	for key in ["slot", "damage", "rate", "capacity", "reload", "level"]:
		if not (gun.get(key) is float or gun.get(key) is int) or not is_finite(float(gun[key])) or gun[key] < 0:
			return false
	for amount in gun.ammo:
		if not (amount is float or amount is int) or amount < 0 or amount > 100000:
			return false
	return gun.slot <= 2 and gun.capacity > 0 and gun.rate > 0 and gun.reload > 0

func load_checkpoint(path: String = "") -> Error:
	if path.is_empty():
		path = save_path
	if inside or phase != "prep" or enemies_nearby(20):
		notify("Restaure fora dos interiores e do combate.")
		return ERR_BUSY
	var loaded := WorldState.new()
	var status := loaded.read_save(path)
	if status != OK or not snapshot_valid(loaded.snapshot):
		notify("Salvamento ausente, incompatível ou inválido.")
		return status if status != OK else ERR_INVALID_DATA
	state = loaded
	restore_snapshot()
	notify("REFÚGIO RESTAURADO · Recursos e interiores preservados.")
	return OK

func restore_snapshot() -> void:
	var data: Dictionary = state.snapshot
	if not snapshot_valid(data):
		state.snapshot.clear()
		return
	for group in ["enemies", "pickups"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	for building in get_tree().get_nodes_in_group("buildings"):
		if building != core:
			remove_child(building)
			building.queue_free()
	phase = "prep"
	builder.set_active(false)
	upgrades.offers.clear()
	waves.wave = int(data.wave)
	waves.running = false
	waves.to_spawn = 0
	kills = int(data.kills)
	elapsed = float(data.elapsed)
	player.position = Vector3(data.position[0], data.position[1], data.position[2])
	player.velocity = Vector3.ZERO
	player.health.maximum = data.maximum
	player.health.current = data.hp
	player.speed_multiplier = data.speed
	player.powers.clear()
	player.shield = 0
	core.health.maximum = data.core_maximum
	core.health.current = data.core_hp
	core.set_meta("tier", int(data.core_tier))
	resources.scrap = int(data.scrap)
	resources.xp = int(data.xp)
	resources.level = int(data.level)
	resources.pending = int(data.pending)
	var gun: WeaponSystem = player.weapons
	gun.slot = int(data.weapon.slot)
	gun.ammo.assign(data.weapon.ammo.map(func(value): return int(value)))
	gun.damage_multiplier = data.weapon.damage
	gun.rate_multiplier = data.weapon.rate
	gun.capacity_multiplier = data.weapon.capacity
	gun.reload_multiplier = data.weapon.reload
	gun.level = int(data.weapon.level)
	gun.reload_left = 0
	gun.cooldown = .3
	for saved in data.defenses:
		var building: Node3D = BuildManager.SCENES[0 if saved.kind == "barricade" else 1].instantiate()
		building.world = self
		building.position = Vector3(saved.pos[0], saved.pos[1], saved.pos[2])
		add_child(building)
		building.health.maximum = saved.maximum
		building.health.current = saved.hp
		building.set_meta("tier", int(saved.tier))
	outdoor.reload_all()
	snap_camera()
