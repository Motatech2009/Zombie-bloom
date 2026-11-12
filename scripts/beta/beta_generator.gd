class_name BetaGenerator
extends WorldGenerator
const BETA_VERSION := 2
const REGION_SIZE := 512
var planned: Dictionary = {}

func stable_seed(key: String) -> int:
	return (str(world_seed) + ":beta2:" + key).hash()

func plan_region() -> void:
	ensure_region(Vector2i.ZERO)

func region_coord(pos: Vector2) -> Vector2i:
	return Vector2i(floori((pos.x + 256) / 512), floori((pos.y + 256) / 512))

func ensure_region(coord: Vector2i) -> void:
	var key := sector_key(coord)
	if planned.has(key):
		return
	planned[key] = true
	var origin := Vector2(coord * REGION_SIZE)
	var rng := rng_for("region:" + key)
	road(origin + Vector2(-256, -32), origin + Vector2(256, -32), 8)
	road(origin + Vector2(0, -256), origin + Vector2(0, 256), 8)
	var sites := [Vector2(rng.randf_range(105, 140), rng.randf_range(-140, -110)), Vector2(rng.randf_range(-145, -100), rng.randf_range(-120, -90)), Vector2(rng.randf_range(90, 125), rng.randf_range(140, 165)), Vector2(rng.randf_range(-145, -105), rng.randf_range(140, 165))]
	var kinds := ["city", "village", "farm", "industry"]
	var names := ["Cedro", "Vila Esperança", "Fazenda Boa Vista", "Pátio industrial"]
	for i in range(4):
		var point: Vector2 = origin + sites[i]
		settlements.append({"name": names[i] + (" · " + key if coord != Vector2i.ZERO else ""), "pos": point, "kind": kinds[i]})
		road(Vector2(point.x, origin.y - 32), point, 5)
		var rows := rng.randi_range(3, 4) if i == 0 else 2
		var lanes := 2 if i == 0 else 1
		for row in range(rows):
			var z := point.y + (row - rows / 2.0) * 20
			road(Vector2(point.x - 35, z), Vector2(point.x + 35, z), 5)
			for side in [-1, 1]:
				for lane in range(lanes):
					var id := "r:%s:%s:%d:%d:%d" % [key, kinds[i], row, side, lane]
					var local_rng := rng_for(id)
					var pos := Vector2(point.x + side * (13 + lane * 17), z + 10)
					var kind := "house"
					if i == 0 and row == 0:
						kind = "market" if side < 0 else "pharmacy"
					elif i == 2 and side > 0:
						kind = "barn"
					elif i == 3:
						kind = "workshop" if side > 0 else "warehouse"
					houses.append({"id": id, "pos": pos, "kind": kind, "width": local_rng.randf_range(7.5, 9), "depth": 8.0, "tone": local_rng.randf(), "zone": names[i], "elevation": 0.0})
	if coord == Vector2i.ZERO:
		var point := Vector2(rng.randf_range(28, 33), -21)
		houses.append({"id": "beta:starter:house", "pos": point, "kind": "house", "width": 9.0, "depth": 8.0, "tone": rng.randf(), "zone": "Estrada do refúgio", "elevation": 0.0})
		road(Vector2(0, -32), Vector2(point.x, -32), 5)

func ground_raw(pos: Vector2) -> float:
	var hills := (climate.get_noise_2d(pos.x * .28, pos.y * .28) + .6) * 7
	return hills * smoothstep(22, 60, pos.length())

func river_distance(pos: Vector2) -> float:
	var center := river_z(pos.x)
	return absf(wrapf(pos.y - center, -256, 256))

func is_water(pos: Vector2) -> bool:
	ensure_region(region_coord(pos))
	return river_distance(pos) < 5.5 and road_distance(pos) >= 0

func height_at(pos: Vector2) -> float:
	ensure_region(region_coord(pos))
	var height := ground_raw(pos)
	var river_dist := river_distance(pos)
	height = lerpf(-.55, height, smoothstep(6, 19, river_dist))
	height = lerpf(0, height, smoothstep(1, 9, road_distance(pos)))
	for house: Dictionary in houses:
		var delta: Vector2 = (pos - house.pos).abs() - Vector2(house.width * .5, house.depth * .5)
		var edge := maxf(delta.x, delta.y)
		if edge < 5:
			height = lerpf(0, height, smoothstep(0, 5, edge))
	return height

func region_at(pos: Vector2) -> String:
	var warp := Vector2(climate.get_noise_2d(pos.x, pos.y), detail.get_noise_2d(pos.x, pos.y)) * 35
	var coord := region_coord(pos + warp)
	return "Vale do Cedro" if coord == Vector2i.ZERO else "Terras do Cedro · " + sector_key(coord)

func sector_data(coord: Vector2i) -> Dictionary:
	ensure_region(region_coord(Vector2(coord * SECTOR_SIZE) + Vector2.ONE * 32))
	return super.sector_data(coord)

func biome_at(pos: Vector2) -> String:
	ensure_region(region_coord(pos))
	if river_distance(pos) < 16:
		return "Mata ribeirinha"
	for settlement: Dictionary in settlements:
		if settlement.kind == "farm" and pos.distance_to(settlement.pos) < 45:
			return "Campos agrícolas"
	if height_at(pos) > 4:
		return "Colinas temperadas"
	return "Floresta temperada" if climate.get_noise_2d(pos.x, pos.y) > -.05 else "Campo aberto"

func interior_plan(id: String, kind: String) -> Dictionary:
	var plan := super.interior_plan(id, kind)
	var functions := {"market": ["Vendas", "Estoque", "Atendimento", "Depósito"], "pharmacy": ["Atendimento", "Medicamentos", "Arquivo", "Depósito"], "barn": ["Galpão", "Insumos", "Armazenagem", "Ferramentas"], "workshop": ["Oficina", "Ferramentas", "Peças", "Depósito"], "warehouse": ["Recebimento", "Componentes", "Expedição", "Depósito"]}
	if functions.has(kind):
		plan.rooms = functions[kind]
	return plan
