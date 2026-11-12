class_name BetaPersistence
extends RefCounted
const FORMAT := 2

static func path(seed_value: int) -> String:
	return "user://ultimo_refugio_beta_%d.json" % seed_value

static func numeric(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func vector(value) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for coordinate in value:
		if not numeric(coordinate) or absf(coordinate) > 10000000:
			return false
	return true

static func validate(data: Dictionary) -> bool:
	if data.get("format") != FORMAT or data.get("generator") != BetaGenerator.BETA_VERSION or not numeric(data.get("seed")):
		return false
	for key in ["inventory", "containers", "changes", "explored", "player", "clock", "director", "notes"]:
		if not data.get(key) is Dictionary:
			return false
	if not data.get("structures") is Array or data.structures.size() > 80 or not data.get("drops") is Array or data.drops.size() > 2000:
		return false
	var inventory := BetaInventory.new()
	if not inventory.restore(data.inventory):
		return false
	for value in data.containers.values():
		if not value is Dictionary or not inventory.restore(value):
			return false
	for value in data.changes.values():
		if not value is Dictionary:
			return false
		if value.has("units") and (not numeric(value.units) or value.units < 0 or value.units > 10000):
			return false
		if value.has("open") and not value.open is bool:
			return false
		if value.has("window") and not value.window in ["intact", "broken", "barricaded"]:
			return false
	for key in data.notes:
		if not key in ["core", "house", "farm", "city", "industry", "signal"] or not data.notes[key] is bool:
			return false
	for key in data.explored:
		if not key is String or key.split(":").size() != 2 or not data.explored[key] is bool:
			return false
	var player: Dictionary = data.player
	if not vector(player.get("position")) or not vector(player.get("return")) or not numeric(player.get("hp")) or player.hp <= 0 or player.hp > 100 or not player.get("inside") is bool or not player.get("house") is Dictionary:
		return false
	if player.inside:
		var house: Dictionary = player.house
		if not house.get("id") is String or not house.get("pos") is Array or house.pos.size() != 2 or not numeric(house.pos[0]) or not numeric(house.pos[1]) or not numeric(house.get("width")) or not numeric(house.get("depth")) or house.width < 2 or house.width > 30 or house.depth < 2 or house.depth > 30 or not house.get("kind") in ["house", "market", "pharmacy", "workshop", "warehouse", "barn"]:
			return false
	if not player.get("ammo") is Array or player.ammo.size() != 3 or not player.get("tool") in ["axe", "pistol", "shotgun"]:
		return false
	for amount in player.ammo:
		if not numeric(amount) or amount < 0 or amount > 1000 or amount != int(amount):
			return false
	if not numeric(data.get("core_hp")) or data.core_hp <= 0 or data.core_hp > 600 or not numeric(data.get("serial")) or not numeric(data.get("kills")):
		return false
	if not numeric(data.clock.get("seconds")) or data.clock.seconds < 0 or not numeric(data.clock.get("weather")):
		return false
	var director: Dictionary = data.director
	if not numeric(director.get("remaining")) or director.remaining < 0 or director.remaining > 100000:
		return false
	if not director.get("events") is Array or director.events.size() > 12 or not numeric(director.get("remaining")) or not numeric(director.get("serial")) or not str(director.get("rng_state", "")).is_valid_int():
		return false
	for event in director.events:
		if not event is Dictionary or not event.get("id") is String or not vector(event.get("pos")) or not vector(event.get("target")) or not numeric(event.get("count")) or event.count < 0 or event.count > 40 or event.count != int(event.count) or not numeric(event.get("speed")) or event.speed < 0 or event.speed > 5 or not event.get("migration") is bool or not event.get("status") in ["moving", "finished"]:
			return false
	var ids := {}
	for building in data.structures:
		if not building is Dictionary or not building.get("uid") is String or ids.has(building.uid) or not building.get("kind") in BetaCatalog.STRUCTURES or not vector(building.get("pos")) or not numeric(building.get("rotation")) or not numeric(building.get("hp")) or building.hp <= 0 or building.hp > 1000 or not building.get("open") is bool:
			return false
		ids[building.uid] = true
	for drop in data.drops:
		if not drop is Dictionary or not drop.get("id") is String or not vector(drop.get("pos")) or not data.containers.has(drop.id):
			return false
	return true

static func collect(world: Node3D) -> Dictionary:
	var containers := {}
	for id: String in world.containers:
		containers[id] = world.containers[id].serialize()
	var structures: Array = []
	for building in world.get_tree().get_nodes_in_group("beta_structures"):
		if not building.health.dead:
			structures.append({"uid": building.uid, "kind": building.kind, "pos": BetaEvents.encode(building.position), "rotation": building.rotation.y, "hp": building.health.current, "open": building.opened})
	var house: Dictionary = world.current_house.duplicate(true)
	if house.has("pos"):
		house.pos = [house.pos.x, house.pos.y]
	return {"format": FORMAT, "generator": BetaGenerator.BETA_VERSION, "seed": world.state.world_seed, "inventory": world.inventory.serialize(), "containers": containers, "changes": world.state.changes.duplicate(true), "explored": world.state.explored.duplicate(), "player": {"position": BetaEvents.encode(world.player.position), "return": BetaEvents.encode(world.return_position), "hp": world.player.health.current, "inside": world.inside, "house": house, "tool": world.player.tool, "ammo": world.player.weapons.ammo.duplicate()}, "clock": {"seconds": world.time.seconds, "weather": world.time.weather, "lantern": world.time.lantern_on}, "director": world.director.serialize(), "notes": world.notes.duplicate(), "structures": structures, "drops": world.drops.duplicate(true), "core_hp": world.core.health.current, "serial": world.next_structure, "kills": world.kills}

static func write(world: Node3D, destination: String = "") -> Error:
	if world.phase == "ended":
		return ERR_BUSY
	if destination.is_empty():
		destination = path(world.state.world_seed)
	var data := collect(world)
	if not validate(data):
		return ERR_INVALID_DATA
	# A seed-specific path plus a guard prevents replacing another campaign by accident.
	if FileAccess.file_exists(destination):
		var old = JSON.parse_string(FileAccess.get_file_as_string(destination))
		if old is Dictionary and old.get("seed") != world.state.world_seed:
			return ERR_ALREADY_EXISTS
	var file := FileAccess.open(destination + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(destination):
		var status := DirAccess.copy_absolute(destination, destination + ".bak")
		if status != OK:
			return status
	return DirAccess.rename_absolute(destination + ".tmp", destination)

static func read(source: String) -> Dictionary:
	if not FileAccess.file_exists(source):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(source))
	return data if data is Dictionary and validate(data) else {}
