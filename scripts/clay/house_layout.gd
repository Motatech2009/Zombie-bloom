class_name HouseLayout
extends RefCounted
static func populate(data: Dictionary,wave: int) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(str(data.seed)+"houses:"+str(data.visit))
	var houses: Array = []
	var count := 2 if data.biome==2 else 3 if data.biome in [1,3,4] else 4
	for i in range(count):
		var x := (-1 if i%2==0 else 1)*(25+rng.randf_range(-3,3))
		var z := (-1 if i<2 else 1)*(25+rng.randf_range(-3,3))
		houses.append({"id":i,"pos":Vector3(x,0,z),"yaw":PI if z<0 else 0.0,"style":(int(data.biome)+i)%3,"guards":mini(12,4+int(data.risk)*2+wave/4),"reward":{"scrap":70+int(data.risk)*30,"wood":40+int(data.risk)*20,"parts":12+int(data.risk)*8}})
	var blocks: Array = []
	for block in data.blocks:
		if not houses.any(func(house): return absf(block.pos.x-house.pos.x)<block.size.x/2+8 and absf(block.pos.z-house.pos.z)<block.size.z/2+9): blocks.append(block)
	data.blocks = blocks
	data.houses = houses
	# Keep separate interaction targets from occupying the same patch of road.
	var placed: Array[Vector3] = []
	for i in range(data.caches.size()+1):
		var point: Vector3 = data.caches[i] if i<data.caches.size() else data.rare_pos
		for attempt in range(24):
			if not placed.any(func(other): return other.distance_to(point)<4): break
			point = Vector3(rng.randf_range(-4,4),0,rng.randf_range(-25,25))
		if placed.any(func(other): return other.distance_to(point)<4):
			for z in [-24,-16,-8,0,8,16,24]:
				var fallback := Vector3(0,0,z)
				if not placed.any(func(other): return other.distance_to(fallback)<4): point = fallback; break
		placed.append(point)
		if i<data.caches.size(): data.caches[i] = point
		else: data.rare_pos = point
	# Ordinary encounter spawn points stay outside the new buildings.
	var spawns: Array = []
	for point in data.spawns:
		if not houses.any(func(house): return absf(point.x-house.pos.x)<7 and absf(point.z-house.pos.z)<7): spawns.append(point)
	data.spawns = spawns
	return data
