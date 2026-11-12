extends "res://scripts/world/frontier_world.gd"
const BETA_PLAYER = preload("res://scripts/beta/beta_player.gd")
const BETA_HUD = preload("res://scripts/beta/beta_hud.gd")
const BETA_ENEMY = preload("res://scripts/beta/beta_enemy.gd")
var inventory := BetaInventory.new()
var containers: Dictionary = {}
var crafting := BetaCrafting.new()
var director := BetaEvents.new()
var time := BetaTime.new()
var environment: WorldEnvironment
var crowd := BetaCrowd.new()
var noises: Array = []
var notes: Dictionary = {}
var drops: Array = []
var next_structure: int = 0
var beta_focus: Node3D
var extracting: bool = false
var prepared_load: Dictionary = {}
const LORE := {
"core": ["Registro do refúgio", "A máquina ainda responde, mas os operadores discordavam sobre a finalidade do sinal. Um registro chama o procedimento de contenção; outro, de amplificação. Nada aqui comprova uma cura."],
"house": ["Bilhete na cozinha", "Se voltar antes de mim, deixe a luz baixa. Eles não seguem apenas pessoas. Ontem passaram pela estrada sem entrar no quintal. Foi o barulho do rádio que os fez parar."],
"farm": ["Caderno da fazenda", "O solo continua fértil. Os animais sumiram antes do primeiro silêncio na cidade. Encontramos caixas do mesmo fornecedor do refúgio, mas ninguém lembra de tê-las encomendado."],
"city": ["Aviso interrompido", "A transmissão manda procurar abrigo e evitar o centro. O verso da folha traz uma orientação oposta: manter receptores ligados para orientar os deslocados. Qual aviso veio primeiro?"],
"industry": ["Relatório técnico", "A alimentação do Núcleo era isolada da rede pública. O equipamento não estava aguardando uma falha: já operava antes do colapso. O motivo permanece ilegível."],
"signal": ["Sinal de outra região", "Entre a estática, uma sequência se repete a leste. Parece uma resposta ao pulso do refúgio. Pode haver alguém transmitindo, ou outra máquina ainda ativa. A expedição continua."]}

func _ready() -> void:
	arena.free()
	builder.free()
	BetaOptions.setup()
	GameSettings.load_settings()
	DisplayServer.window_set_size([Vector2i(1280, 800), Vector2i(1600, 900), Vector2i(1920, 1080)][BetaOptions.resolution_index])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			WorldState.next_seed = int(argument.trim_prefix("--seed="))
	state.world_seed = WorldState.next_seed
	if "--continue" in OS.get_cmdline_user_args():
		WorldState.resume_requested = true
	if WorldState.resume_requested:
		prepared_load = BetaPersistence.read(BetaPersistence.path(state.world_seed))
	WorldState.resume_requested = false
	if not prepared_load.is_empty():
		state.changes = prepared_load.changes.duplicate(true)
		state.explored = prepared_load.explored.duplicate()
	outdoor = BetaRegion.new()
	outdoor.world = self
	arena = outdoor
	builder = BetaBuild.new()
	builder.world = self
	sunlight = VisualFactory.lighting(self)
	environment = get_child(get_child_count() - 2)
	add_child(outdoor)
	add_child(effects)
	add_child(resources)
	waves.world = self
	add_child(waves)
	waves.set_physics_process(false)
	upgrades.world = self
	add_child(upgrades)
	add_child(audio)
	core = CORE_SCENE.instantiate()
	core.world = self
	add_child(core)
	player = CharacterBody3D.new()
	player.set_script(BETA_PLAYER)
	player.world = self
	player.position = Vector3(4, 0, 4)
	add_child(player)
	add_child(builder)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32
	camera.far = 160
	camera.current = true
	crafting.world = self
	time.world = self
	add_child(time)
	director.world = self
	add_child(director)
	add_child(crowd)
	hud = CanvasLayer.new()
	hud.set_script(BETA_HUD)
	hud.world = self
	add_child(hud)
	starter_inventory()
	container_for("base:storage", "empty")
	if not prepared_load.is_empty():
		apply_save(prepared_load)
	else:
		notify("ÚLTIMO REFÚGIO · E interage · I inventário · C crafting · B construção")
	snap_camera()
	time.apply()
	if "--beta-smoke" in OS.get_cmdline_user_args():
		get_tree().create_timer(3).timeout.connect(func(): get_tree().quit())

func starter_inventory() -> void:
	for row in [["axe", 1], ["pistol", 1], ["ammo9", 36], ["wood", 8], ["stone", 2], ["scrap", 6], ["cloth", 6], ["component", 2], ["bandage", 2], ["lantern", 1]]:
		inventory.add(row[0], row[1])
	inventory.hotbar = [0, 1, 8, 9, -1, -1]
	inventory.equip_slot(0, "tool")
	inventory.equip_slot(1, "primary")

func new_interaction() -> WorldInteraction:
	return BetaInteraction.new()

func _process(delta: float) -> void:
	if phase == "ended":
		return
	elapsed += delta
	notice_left = maxf(0, notice_left - delta)
	noises = noises.filter(func(noise): return float(noise.expires) > time.seconds)
	if not inside:
		outdoor.focus(player.position)
		camera.global_position = camera.global_position.lerp(player.global_position + camera_offset, 1 - exp(-delta * 6))
		camera.look_at(player.global_position)
	else:
		camera.global_position = interior.global_position + camera_offset
		camera.look_at(interior.global_position)
	update_beta_interaction(delta)
	interaction_text = interaction_text.replace("SEGURE E", "SEGURE " + BetaOptions.key_hint("beta_interact")).replace("E ·", BetaOptions.key_hint("beta_interact") + " ·")

func _physics_process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if phase == "ended":
		return
	if event.is_action_pressed("beta_build"):
		if builder.active:
			builder.set_active(false)
		else:
			hud.show_building()
	if event.is_action_pressed("beta_interact") and not event.is_echo():
		if is_instance_valid(beta_focus):
			if beta_focus == core:
				hud.show_loot(container_for("base:storage", "empty"), "base:storage")
			elif beta_focus.has_method("use"):
				beta_focus.use.call_deferred()
	if event.is_action_pressed("beta_repair"):
		repair_beta()
	if event.is_action_pressed("save_world"):
		save_beta()
	if event.is_action_pressed("load_world"):
		load_beta()
	if event.is_action_pressed("beta_light"):
		time.lantern_on = not time.lantern_on
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size = clampf(camera.size + (-2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2), 26, 40)
		elif event.button_index == MOUSE_BUTTON_LEFT and builder.active:
			var origin := camera.project_ray_origin(event.position)
			var direction := camera.project_ray_normal(event.position)
			var projected = Plane(Vector3.UP, player.global_position.y).intersects_ray(origin, direction)
			if projected == null:
				return
			var point: Vector3 = projected
			builder.location = Vector3(snappedf(point.x, 2), 0, snappedf(point.z, 2))
			builder.location.y = outdoor.generator.height_at(Vector2(builder.location.x, builder.location.z))
			builder.place()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			builder.set_active(false)

func update_beta_interaction(delta: float) -> void:
	var old := focused
	extracting = false
	focused = null
	beta_focus = null
	var distance := 2.7
	for prop: WorldInteraction in get_tree().get_nodes_in_group("world_interactions"):
		if not is_instance_valid(prop.label):
			continue
		prop.label.visible = false
		if not prop.available() or not prop.is_visible_in_tree() or prop.is_queued_for_deletion():
			continue
		var d := player.global_position.distance_to(prop.global_position)
		if d < distance:
			var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, prop.global_position + Vector3.UP, 1 | 8, [player.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and not prop.is_ancestor_of(hit.collider) and hit.position.distance_to(prop.global_position + Vector3.UP) > 1.1:
				continue
			distance = d
			focused = prop
			beta_focus = prop
	if is_instance_valid(old) and old != focused:
		old.progress = 0
	interaction_text = "%s interage · Segure %s para extrair · %s repara" % [BetaOptions.key_hint("beta_interact"), BetaOptions.key_hint("beta_interact"), BetaOptions.key_hint("beta_repair")]
	if is_instance_valid(focused):
		focused.label.visible = true
		focused.label.text = "E"
		if Input.is_action_pressed("beta_interact") and not builder.active and player.roll_left <= 0 and Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() < .01:
			extracting = focused.kind in ["tree", "rock"]
			focused.extract(delta)
		else:
			focused.progress = 0
		interaction_text = focused.prompt()
	if not inside:
		if player.global_position.distance_to(core.global_position) < 5.5 and focused == null:
			beta_focus = core
			interaction_text = "E · Depósito do refúgio e registros do Núcleo"
		for building in get_tree().get_nodes_in_group("beta_structures"):
			if building.global_position.distance_to(player.global_position) < distance:
				beta_focus = building
				interaction_text = "E · " + BetaCatalog.title(building.kind) + " · F repara"

func container_for(id: String, context: String) -> BetaInventory:
	if containers.has(id):
		return containers[id]
	var bag := BetaInventory.new(24, 10000)
	containers[id] = bag
	if context == "empty":
		return bag
	var rng := outdoor.generator.rng_for("loot:" + id)
	var table: Array = [["cloth", 2], ["food", 1], ["water", 1]]
	if context in ["workshop", "warehouse", "industry"]:
		table = [["scrap", 5], ["component", 2], ["shell", 4]]
	elif context == "pharmacy":
		table = [["bandage", 3], ["cloth", 4], ["water", 1]]
	elif context == "market":
		table = [["food", 4], ["water", 3], ["cloth", 2]]
	elif context in ["barn", "farm"]:
		table = [["wood", 5], ["fiber", 6], ["scrap", 3]]
	elif context == "field":
		table = [["scrap", 3], ["component", 1], ["cloth", 2]]
	for row in table:
		if rng.randf() > .15:
			bag.add(row[0], rng.randi_range(1, row[1]))
	if context in ["workshop", "warehouse"] and rng.randf() < .3:
		bag.add("shotgun", 1)
	if rng.randf() < .5:
		bag.add("ammo9", rng.randi_range(3, 9))
	return bag

func near_station(kind: String) -> bool:
	if inside:
		return false
	for building in get_tree().get_nodes_in_group("beta_structures"):
		if building.kind == kind and not building.health.dead and player.global_position.distance_to(building.global_position) < 4:
			return true
	return false

func create_structure(kind: String, uid: String, pos: Vector3, angle: float) -> BetaStructure:
	var structure := BetaStructure.new()
	structure.world = self
	structure.kind = kind
	structure.uid = uid
	structure.position = pos
	structure.rotation.y = angle
	add_child(structure)
	return structure

func repair_beta() -> bool:
	if inside:
		return false
	var nearest: Node3D = null
	var distance := 4.5
	for building in get_tree().get_nodes_in_group("buildings"):
		var d := player.global_position.distance_to(building.global_position)
		if d < distance and building.health.current < building.health.maximum and not building.health.dead:
			nearest = building
			distance = d
	if nearest == null:
		notify("Aproxime-se de uma estrutura danificada.")
		return false
	if inventory.remove("repair_kit", 1):
		nearest.health.heal(100)
	elif inventory.count("scrap") > 0 and inventory.count("wood") > 0:
		inventory.remove("scrap", 1)
		inventory.remove("wood", 1)
		nearest.health.heal(60)
	else:
		notify("Reparo requer kit ou 1 madeira + 1 sucata.")
		return false
	make_noise(player.global_position, 8)
	return true

func use_item(index: int) -> bool:
	if index < 0 or index >= inventory.slots.size() or inventory.slots[index].is_empty():
		return false
	var id: String = inventory.slots[index].id
	if id in ["axe", "pistol", "shotgun"]:
		inventory.equip_slot(index, "tool" if id == "axe" else "primary" if id == "pistol" else "secondary")
		player.tool = id
		player.weapons.reload_left = 0
		if id != "axe":
			player.weapons.equip(0 if id == "pistol" else 1)
		return true
	if id == "lantern":
		time.lantern_on = not time.lantern_on
		return true
	if id == "backpack":
		var result := inventory.equip_backpack(not inventory.backpack)
		notify("Mochila equipada." if result else "A mochila menor não comporta os itens atuais.")
		return result
	if id == "armor":
		if inventory.armor:
			inventory.armor = false
			inventory.equipment.protection = -1
		else:
			inventory.equip_slot(index, "protection")
		return true
	if id in ["bandage", "food", "water"]:
		if player.health.current >= player.health.maximum:
			notify("Vida completa. O item foi preservado.")
			return false
		inventory.remove(id, 1)
		player.health.heal(25 if id == "bandage" else 5 if id == "food" else 2)
		return true
	return false

func make_noise(pos: Vector3, radius: float) -> void:
	if inside:
		pos = return_position
	noises.append({"pos": BetaEvents.encode(pos), "radius": radius, "expires": time.seconds + 3})
	director.hear(pos, radius)

func spawn_beta_enemy(pos: Vector3, event_id: String, runner: bool = false) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.set_script(BETA_ENEMY)
	enemy.world = self
	enemy.spec = Catalog.ENEMIES[1 if runner else 0]
	enemy.event_id = event_id
	pos.y = outdoor.generator.height_at(Vector2(pos.x, pos.z))
	enemy.position = pos
	add_child(enemy)
	return enemy

func enemy_defeated(enemy: Node3D) -> void:
	kills += 1
	director.defeated(enemy.event_id)
	next_structure += 1
	var id := "drop:%d" % next_structure
	var bag := container_for(id, "empty")
	bag.add("scrap", 1)
	drop_container(id, enemy.position)

func drop_container(id: String, pos: Vector3, house_id: String = "") -> void:
	if not drops.any(func(drop): return drop.id == id):
		drops.append({"id": id, "pos": BetaEvents.encode(pos), "house": house_id})
	var prop := BetaInteraction.new()
	prop.world = self
	prop.id = id
	prop.kind = "salvage"
	prop.data = {"context": "empty"}
	prop.position = pos
	if not house_id.is_empty():
		if inside and str(current_house.id) == house_id:
			interior.add_child(prop)
		else:
			prop.free()
	else:
		add_child(prop)

func read_record(id: String) -> void:
	if not LORE.has(id):
		id = "house"
	notes[id] = true
	if notes.size() >= 5:
		notes["signal"] = true
	hud.show_record(id)

func enter_building(data: Dictionary) -> bool:
	if inside or builder.active or enemies_nearby(12):
		notify("Afaste os hostis e saia da construção antes de entrar.")
		return false
	var entered := super.enter_building(data)
	if entered:
		# Persistent time and aggregate events continue, even though exterior actors are suspended.
		var record := BetaInteraction.new()
		record.world = self
		record.id = str(data.id) + ":record"
		record.kind = "record"
		record.data = {"record": "farm" if data.kind == "barn" else "city" if data.kind in ["market", "pharmacy"] else "industry" if data.kind in ["warehouse", "workshop"] else "house"}
		record.position = Vector3(-5, 0, -2)
		interior.add_child(record)
		for x in [-5, 5]:
			var window := BetaInteraction.new()
			window.world = self
			window.id = str(data.id) + ":window:%d" % x
			window.kind = "window"
			window.data = {}
			window.position = Vector3(x, 0, -8.7)
			interior.add_child(window)
		for drop: Dictionary in drops:
			if str(drop.get("house", "")) == str(data.id):
				drop_container(drop.id, BetaEvents.decode(drop.pos), str(data.id))
	return entered

func leave_building() -> bool:
	return super.leave_building()

func save_beta(destination: String = "") -> Error:
	var status := BetaPersistence.write(self, destination)
	if status == OK and destination.is_empty():
		BetaOptions.last_seed = state.world_seed
		BetaOptions.save()
	notify("CAMPANHA SALVA · Seed %d" % state.world_seed if status == OK else "Não foi possível salvar (%d)." % status)
	return status

func load_beta(source: String = "") -> bool:
	if source.is_empty():
		source = BetaPersistence.path(state.world_seed)
	var data := BetaPersistence.read(source)
	if data.is_empty() or int(data.seed) != state.world_seed:
		notify("Salvamento inválido, incompatível ou de outra seed. Nada foi alterado.")
		return false
	apply_save(data)
	notify("CAMPANHA RESTAURADA")
	return true

func apply_save(data: Dictionary) -> void:
	if inside:
		player.position = interior.position + Vector3(-3, 0, -7)
		leave_building()
	for group in ["beta_enemies", "beta_structures"]:
		for node in get_tree().get_nodes_in_group(group):
			node.get_parent().remove_child(node)
			node.queue_free()
	for child in get_children():
		if child is BetaInteraction:
			remove_child(child)
			child.queue_free()
	inventory.restore(data.inventory)
	state.changes = data.changes.duplicate(true)
	state.explored = data.explored.duplicate()
	containers.clear()
	for id: String in data.containers:
		var bag := BetaInventory.new()
		bag.restore(data.containers[id])
		containers[id] = bag
	notes = data.notes.duplicate()
	drops = data.drops.duplicate(true)
	next_structure = int(data.serial)
	kills = int(data.kills)
	core.health.setup(600)
	core.collision_layer = 8
	if not core.is_in_group("buildings"): core.add_to_group("buildings")
	core.health.current = data.core_hp
	player.health.setup(100)
	player.reset_life_pose()
	player.health.current = data.player.hp
	player.position = BetaEvents.decode(data.player["return"] if data.player.inside else data.player.position)
	player.velocity = Vector3.ZERO
	player.roll_left = 0
	player.roll_recovery = 0
	player.tool = data.player.tool
	player.weapons.slot = 1 if player.tool == "shotgun" else 0
	player.hotbar_slot = 0
	for h in range(inventory.hotbar.size()):
		var reference: int = inventory.hotbar[h]
		if reference >= 0 and inventory.slots[reference].get("id", "") == player.tool:
			player.hotbar_slot = h
			break
	player.weapons.ammo.assign(data.player.ammo.map(func(amount): return int(amount)))
	player.weapons.reload_left = 0
	player.weapons.sync_mass()
	time.seconds = float(data.clock.seconds)
	time.weather = float(data.clock.weather)
	time.lantern_on = bool(data.clock.get("lantern", false))
	director.restore(data.director)
	outdoor.reload_all()
	for saved in data.structures:
		var structure := create_structure(saved.kind, saved.uid, BetaEvents.decode(saved.pos), saved.rotation)
		structure.health.current = saved.hp
		structure.opened = saved.open
		structure.apply_gate()
	for drop in drops.duplicate(true):
		if str(drop.get("house", "")).is_empty():
			drop_container(drop.id, BetaEvents.decode(drop.pos))
	phase = "prep"
	builder.set_active(false)
	if data.player.inside:
		var house: Dictionary = data.player.house.duplicate(true)
		house.pos = Vector2(house.pos[0], house.pos[1])
		enter_building(house)
		player.position = BetaEvents.decode(data.player.position)
	snap_camera()
	time.apply()

func finish(victory: bool, reason: String) -> void:
	if phase == "ended":
		return
	phase = "ended"
	ending_reason = reason
	builder.set_active(false)
	if is_instance_valid(hud):
		hud.show_result()

func discard_item(index: int) -> bool:
	if index < 0 or index >= inventory.slots.size() or inventory.slots[index].is_empty():
		return false
	var destination := Vector3.ZERO
	var found := false
	for offset: Vector3 in [Vector3(1.8, 0, 0), Vector3(-1.8, 0, 0), Vector3(0, 0, 1.8), Vector3(0, 0, -1.8)]:
		var candidate := player.global_position + offset
		if inside:
			var relative := candidate - interior.global_position
			if absf(relative.x) > 8 or absf(relative.z) > 8:
				continue
		else:
			candidate.y = outdoor.generator.height_at(Vector2(candidate.x, candidate.z))
			if outdoor.generator.is_water(Vector2(candidate.x, candidate.z)):
				continue
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := SphereShape3D.new()
		shape.radius = .65
		query.shape = shape
		query.transform.origin = candidate + Vector3.UP
		query.collision_mask = 1 | 2 | 8
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		destination = candidate
		found = true
		break
	if not found:
		notify("Não há espaço livre para deixar o item aqui.")
		return false
	next_structure += 1
	var id := "drop:%d" % next_structure
	var target := container_for(id, "empty")
	if store_items(target, index, 1) != 1:
		containers.erase(id)
		return false
	drop_container(id, destination - interior.global_position if inside else destination, str(current_house.id) if inside else "")
	return true

func store_items(target: BetaInventory, index: int, quantity: int) -> int:
	if index < 0 or index >= inventory.slots.size() or inventory.slots[index].is_empty():
		return 0
	var id: String = inventory.slots[index].id
	var source := inventory.copy()
	var destination := target.copy()
	var accepted := source.transfer_to(destination, index, quantity)
	if accepted <= 0:
		return 0
	var weapon_index := 0 if id == "pistol" else 1 if id == "shotgun" else -1
	var unload := 0
	if weapon_index >= 0 and source.count(id) == 0:
		unload = player.weapons.ammo[weapon_index]
		var ammunition: String = BetaWeapons.AMMO_TYPES[weapon_index]
		source.loaded_mass = maxf(0, source.loaded_mass - unload * float(BetaCatalog.item(ammunition).weight))
		if source.add(ammunition, unload) != unload:
			notify("Não há espaço para descarregar a arma; nada foi transferido.")
			return 0
	inventory.assign(source)
	target.assign(destination)
	if weapon_index >= 0 and source.count(id) == 0:
		player.weapons.ammo[weapon_index] = 0
		player.weapons.reload_left = 0
		if player.tool == id:
			player.tool = "axe"
	player.weapons.sync_mass()
	return accepted
