class_name WorldGenerator
extends RefCounted
## Pure, versioned world data. No SceneTree state or global RNG is consulted.
const VERSION := 1
const SECTOR_SIZE := 64
const CELL := 2
var world_seed: int
var climate := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var settlements: Array[Dictionary] = []
var houses: Array[Dictionary] = []
var roads: Array[Dictionary] = []

func _init(value: int = 8417) -> void:
	world_seed = value
	climate.seed = value
	climate.frequency = .009
	detail.seed = value ^ 73493
	detail.frequency = .027
	plan_region()

func stable_seed(key: String) -> int:
	return (str(world_seed) + ":v%d:" % VERSION + key).hash()

func rng_for(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = stable_seed(key)
	return rng

static func sector_at(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / SECTOR_SIZE), floori(pos.z / SECTOR_SIZE))

static func sector_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]

func river_z(x: float) -> float:
	return 74.0 + sin(x * .012 + float(posmod(world_seed, 37)) * .03) * 13.0

func is_water(pos: Vector2) -> bool:
	return absf(pos.y - river_z(pos.x)) < 5.5 and road_distance(pos) >= 0

func region_at(pos: Vector2) -> String:
	var bend := climate.get_noise_2d(pos.x, pos.y) * 65
	if pos.x + bend > 220:
		return "Terras Altas"
	if pos.y + bend > 200:
		return "Mata do Sul"
	return "Vale do Cedro"

func biome_at(pos: Vector2) -> String:
	if absf(pos.y - river_z(pos.x)) < 13:
		return "Mata ribeirinha"
	if pos.distance_to(Vector2(96, 124)) < 40:
		return "Campos agrícolas"
	return "Floresta temperada" if climate.get_noise_2d(pos.x, pos.y) > -.04 else "Campo aberto"

func road_distance(pos: Vector2) -> float:
	var closest := INF
	for road in roads:
		var projected := Geometry2D.get_closest_point_to_segment(pos, road.a, road.b)
		closest = minf(closest, pos.distance_to(projected) - road.width * .5)
	return closest

func road(a: Vector2, b: Vector2, width: float = 6) -> void:
	roads.append({"a": a, "b": b, "width": width})

func plan_region() -> void:
	# The starter geography is fixed in purpose, varied in lots, foliage and resources by seed.
	road(Vector2(-512, -32), Vector2(512, -32), 8)
	road(Vector2(0, -512), Vector2(0, 512), 8)
	settlements = [
		{"name": "Cedro · centro", "pos": Vector2(128, -104), "kind": "city"},
		{"name": "Vila Esperança", "pos": Vector2(-96, -96), "kind": "village"},
		{"name": "Fazenda Boa Vista", "pos": Vector2(96, 124), "kind": "farm"},
		{"name": "Pátio industrial", "pos": Vector2(-112, 124), "kind": "industry"}
	]
	for settlement in settlements:
		var p: Vector2 = settlement.pos
		road(Vector2(p.x, -32 if p.y < 0 else 0), p, 5)
		if p.y > 0:
			road(Vector2.ZERO, Vector2(p.x, 0), 5)
		var count := 4 if settlement.kind == "city" else 2
		for row in range(count):
			var z := p.y + (row - count / 2.0) * 20
			road(Vector2(p.x - 33, z), Vector2(p.x + 33, z), 5)
			for column in [-1, 1]:
				for lane in range(2 if count == 4 else 1):
					var id := "%s:%d:%d:%d" % [settlement.kind, row, column, lane]
					var rng := rng_for(id)
					var location := Vector2(p.x + column * (13 + lane * 17), z + 10)
					var kind := "house"
					if settlement.kind == "city" and row == 0:
						kind = "market" if column < 0 else "pharmacy"
					elif settlement.kind == "farm":
						kind = "barn" if column > 0 else "house"
					elif settlement.kind == "industry":
						kind = "workshop" if column > 0 else "warehouse"
					houses.append({"id": id, "pos": location, "kind": kind, "width": rng.randf_range(7.5, 9.5), "depth": 8.0, "tone": rng.randf(), "zone": settlement.name})
	# A nearby abandoned dwelling makes the first expedition discoverable on foot.
	road(Vector2(0, -32), Vector2(30, -32), 4)
	houses.append({"id": "starter:house", "pos": Vector2(30, -21), "kind": "house", "width": 9.0, "depth": 8.0, "tone": .4, "zone": "Estrada do refúgio"})

func buildings_at(coord: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for house in houses:
		var p: Vector2 = house.pos
		if sector_at(Vector3(p.x, 0, p.y)) == coord:
			result.append(house.duplicate(true))
	return result

func reserved(pos: Vector2, padding: float = 0) -> bool:
	if pos.length() < 19 + padding or road_distance(pos) < 2.5 + padding or absf(pos.y - river_z(pos.x)) < 9 + padding:
		return true
	for house in houses:
		var p: Vector2 = house.pos
		if absf(p.x - pos.x) < house.width * .5 + 4 + padding and absf(p.y - pos.y) < house.depth * .5 + 5 + padding:
			return true
	return false

func sector_data(coord: Vector2i) -> Dictionary:
	var result := {"coord": sector_key(coord), "buildings": buildings_at(coord), "resources": []}
	var rng := rng_for("sector:" + sector_key(coord))
	for i in range(35):
		var pos := Vector2(coord.x * SECTOR_SIZE + rng.randf_range(3, 61), coord.y * SECTOR_SIZE + rng.randf_range(3, 61))
		if reserved(pos, 1):
			continue
		var overlap := false
		for existing: Dictionary in result.resources:
			if pos.distance_to(existing.pos) < 3:
				overlap = true
		if overlap or (coord == Vector2i.ZERO and pos.distance_to(Vector2(20, 9)) < 3):
			continue
		var kind := "tree" if i % 4 < 2 else "rock" if i % 4 == 2 else "salvage"
		if kind == "tree" and biome_at(pos) == "Campo aberto" and i % 3 != 0:
			continue
		result.resources.append({"id": "sector:%s:resource:%d" % [sector_key(coord), i], "pos": pos, "kind": kind, "units": 12 if kind == "tree" else 9, "size": rng.randf_range(.8, 1.25)})
	if coord == Vector2i.ZERO:
		result.resources.append({"id": "starter:wood", "pos": Vector2(20, 9), "kind": "tree", "units": 12, "size": 1.1})
	return result

func interior_plan(id: String, kind: String) -> Dictionary:
	var rng := rng_for("interior:" + id)
	return {"id": id, "kind": kind, "split_x": rng.randf_range(-1.2, 1.2), "split_z": rng.randf_range(-.8, .8), "rooms": ["Sala", "Cozinha", "Quarto", "Banheiro"] if kind == "house" else ["Atendimento", "Depósito", "Serviço", "Estoque"], "tone": rng.randf()}

static func building_title(kind: String) -> String:
	return {"house": "Residência", "market": "Mercado", "pharmacy": "Farmácia", "barn": "Celeiro", "warehouse": "Armazém", "workshop": "Oficina"}.get(kind, "Edifício")
