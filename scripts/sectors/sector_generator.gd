class_name SectorGenerator
extends RefCounted
const DIRECTIONS = [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const NAMES = ["Norte","Leste","Sul","Oeste"]
const EXITS = [Vector3(0,0,-49),Vector3(49,0,0),Vector3(0,0,49),Vector3(-49,0,0)]
const RISKS = ["TRANQUILO","PATRULHADO","DENSO","INFESTADO","DOMÍNIO DE CHEFE"]
const BIOMES = ["Subúrbio","Pátio industrial","Bosque morto","Zona agrícola","Ruínas militares"]

static func key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x,coord.y]

static func distance(coord: Vector2i) -> int:
	return absi(coord.x)+absi(coord.y)

static func generate(seed_value: int,coord: Vector2i,visit: int,wave: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d" % [seed_value,key(coord),visit])
	var roll := rng.randi_range(0,99)+mini(22,maxi(0,distance(coord)-1)*3)+mini(12,wave/2)
	var risk := 0 if roll<15 else 1 if roll<50 else 2 if roll<80 else 3 if roll<95 else 4
	var counts := [[0,5],[8,16],[28,45],[65,95],[90,140]]
	var count := rng.randi_range(counts[risk][0],counts[risk][1])
	var biome := rng.randi_range(0,4)
	var blocks: Array = []
	for i in range(100):
		if blocks.size()>=10+biome*2: break
		var pos := Vector3(rng.randf_range(-42,42),0,rng.randf_range(-42,42))
		var size := Vector3(rng.randf_range(3,8),rng.randf_range(1.5,4),rng.randf_range(3,8))
		# A clear cross connects all four entry/exit lanes; generation cannot seal a return.
		if absf(pos.x)<8+size.x/2 or absf(pos.z)<8+size.z/2: continue
		var clear := true
		for block in blocks:
			if absf(pos.x-block.pos.x)<(size.x+block.size.x)/2+2 and absf(pos.z-block.pos.z)<(size.z+block.size.z)/2+2: clear = false
		if clear: blocks.append({"pos":pos,"size":size,"style":rng.randi_range(0,2)})
	var spawns: Array[Vector3] = []
	for i in range(36):
		var pos := Vector3(rng.randf_range(-44,44),0,rng.randf_range(-44,44))
		var clear := true
		for block in blocks:
			if absf(pos.x-block.pos.x)<block.size.x/2+2 and absf(pos.z-block.pos.z)<block.size.z/2+2: clear = false
		if clear and pos.length()>12: spawns.append(pos)
	spawns.append_array([Vector3(0,0,-32),Vector3(32,0,0),Vector3(0,0,32),Vector3(-32,0,0)])
	var positions: Array[Vector3] = []
	# Caches sit in clear lanes, away from the arrival circles. Their locations reroll.
	for i in range(3):
		positions.append(Vector3(rng.randf_range(-5,5),0,rng.randf_range(-26,26)) if i%2==0 else Vector3(rng.randf_range(-26,26),0,rng.randf_range(-5,5)))
	var rewards := [[45,18,3],[90,30,8],[180,55,20],[390,110,42],[700,180,75]]
	var reward: Array = rewards[risk]
	var multiplier := rng.randf_range(.85,1.15)
	var loot := {"scrap":int(reward[0]*multiplier),"wood":int(reward[1]*multiplier),"parts":int(reward[2]*multiplier)}
	var rare: int = -1
	if rng.randf() < (.06 if risk==4 else .02): rare = rng.randi_range(1,4)
	var rare_pos := Vector3(rng.randf_range(-5,5),0,rng.randf_range(-25,25))
	var roster: Array[int] = []
	for i in range(count):
		var kind := 0
		if risk==4 and i==0: kind = 8
		elif risk>=3 and i%9==0: kind = 4
		elif (wave>=3 or risk>=2) and i%7==0: kind = 5
		elif (wave>=2 or risk>=2) and i%8==0: kind = 7
		elif risk>=1 and i%5==0: kind = 6
		elif risk>=2 and i%6==0: kind = 3
		elif risk>=2 and i%4==0: kind = 2
		elif i%3==0: kind = 1
		roster.append(kind)
	return {"seed":seed_value,"coord":coord,"visit":visit,"risk":risk,"biome":biome,"count":count,"blocks":blocks,"spawns":spawns,"caches":positions,"reward":loot,"rare":rare,"rare_pos":rare_pos,"roster":roster}

static func boss_spec(number: int) -> Resource:
	var flavors := [8,3,5,7,6]
	var names := ["Carrasco Alfa","Carapaça Alfa","Arqui-corrosivo","Matriarca Alada","Predador Alfa"]
	var index := maxi(0,number-1)%flavors.size()
	var result: Resource = CampaignData.enemy_spec(flavors[index]).duplicate(true)
	result.title = names[index]
	var stage := maxi(1,number)
	result.values.health = 650.0+110*stage+8.0*stage*stage
	result.values.damage = maxf(18,float(result.values.damage))
	result.values.xp = maxi(80+stage*6,int(result.values.xp))
	result.values.scrap = maxi(45+stage*3,int(result.values.scrap))
	result.color = Color("bf6953") if index!=2 else Color("a4c53d")
	return result
