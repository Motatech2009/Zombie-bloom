class_name SectorMemory
extends RefCounted
const LIFETIME := 180.0
const LIMIT := 256

static func vector(point: Vector3) -> Array:
	return [point.x,point.y,point.z]
static func point(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])
static func items(saved: Dictionary) -> Dictionary:
	var result := {}
	for id in saved: result[id] = int(saved[id])
	return result

static func encode_layout(layout: Dictionary) -> Dictionary:
	var d := layout.duplicate(true)
	d.coord = [layout.coord.x,layout.coord.y]
	for block in d.blocks: block.pos = vector(block.pos); block.size = vector(block.size)
	d.spawns = layout.spawns.map(func(v): return vector(v))
	d.caches = layout.caches.map(func(v): return vector(v))
	d.rare_pos = vector(layout.rare_pos)
	for house in d.get("houses",[]): house.pos = vector(house.pos)
	return d

static func decode_layout(saved: Dictionary) -> Dictionary:
	var d := saved.duplicate(true)
	d.coord = Vector2i(d.coord[0],d.coord[1])
	for field in ["seed","visit","risk","biome","count","rare","base_count"]: d[field] = int(d[field])
	d.roster = d.roster.map(func(k): return int(k)); d.base_roster = d.base_roster.map(func(k): return int(k))
	d.reward = items(d.reward)
	for block in d.blocks: block.pos = point(block.pos); block.size = point(block.size)
	d.spawns = saved.spawns.map(func(v): return point(v))
	d.caches = saved.caches.map(func(v): return point(v))
	d.rare_pos = point(saved.rare_pos)
	for house in d.get("houses",[]):
		house.pos = point(house.pos)
		house.reward = items(house.reward)
		for field in ["id","style","guards"]: house[field] = int(house[field])
	return d

static func capture(world: Node3D) -> Dictionary:
	var state := {"expires":world.sector_deadline,"layout":encode_layout(world.descriptor),"claimed":world.claimed.duplicate(),"dead":world.field_defeated.duplicate(),"caches":[],"houses":[],"enemies":[],"loose":[]}
	for cache in world.caches: state.caches.append(cache.get_meta("contents",{}).duplicate())
	for house in world.get_tree().get_nodes_in_group("raid_houses"):
		if world.field_root.is_ancestor_of(house): state.houses.append(house.dump())
	for enemy in world.get_tree().get_nodes_in_group("enemies"):
		if not world.field_root.is_ancestor_of(enemy) or enemy.health.dead: continue
		state.enemies.append({"kind":enemy.enemy_kind,"stage":int(enemy.get_meta("boss_stage",0)),"index":enemy.encounter_index,"pos":vector(enemy.position),"hp":enemy.health.current,"max":enemy.health.maximum,"damage":enemy.spec.values.damage,"speed":enemy.spec.values.speed,"enraged":enemy.enraged,"shield":enemy.shield_left,"ability":.3 if enemy.windup>0 else clampf(enemy.ability_left,-1,100),"summons":enemy.summon_casts,"house":int(enemy.get_meta("house_id",-1)),"guard":int(enemy.get_meta("house_guard",-1)),"event":int(enemy.get_meta("supply_event",-1)),"supply_index":int(enemy.get_meta("supply_index",-1))})
	for loot in world.get_tree().get_nodes_in_group("survival_loot"):
		if loot.get_parent()!=world.field_root or loot.is_queued_for_deletion(): continue
		state.loose.append({"pos":vector(loot.position),"contents":loot.contents.duplicate(),"xp":int(loot.get_meta("xp",0)),"power":str(loot.get_meta("power","")),"loaded":int(loot.get_meta("loaded",0)),"auto":bool(loot.get_meta("auto",true)),"boss":bool(loot.get_meta("boss_drop",false)),"origin":bool(loot.get_meta("world_origin",false))})
	return state

static func restore(world: Node3D,state: Dictionary) -> void:
	world.claimed.assign(state.claimed); world.field_defeated.assign(state.dead)
	world.field_dead = world.field_defeated.size()
	for i in range(mini(world.caches.size(),state.caches.size())):
		world.caches[i].set_meta("contents",items(state.caches[i]))
		world.caches[i].visible = not state.caches[i].is_empty() and not world.caches[i].has_meta("weapon")
	for item in state.houses:
		var house: Node3D = world.raid_house(int(item.id))
		if house!=null:
			var restored: Dictionary = item.duplicate(true); restored.contents = items(item.contents)
			house.apply_state(restored)
	for item in state.enemies:
		if item.event>=0 and (world.airdrops.state.is_empty() or item.event!=world.airdrops.serial or int(item.supply_index) in world.airdrops.state.dead): continue
		world.restoring_boss_stage = int(item.stage)
		var enemy: Node3D = world.make_enemy(int(item.kind),point(item.pos),true,int(item.index))
		world.restoring_boss_stage = 0
		enemy.health.setup(float(item.max)); enemy.health.current = float(item.hp)
		enemy.spec.values.damage = float(item.damage); enemy.spec.values.speed = float(item.speed)
		enemy.enraged = item.enraged; enemy.shield_left = float(item.shield); enemy.ability_left = float(item.ability); enemy.summon_casts = int(item.summons)
		# Flyer initialization sets altitude; preserve the saved physical position afterwards.
		enemy.position = point(item.pos)
		if item.house>=0:
			enemy.set_meta("house_id",int(item.house)); enemy.set_meta("house_guard",int(item.guard)); enemy.add_to_group("house_guards")
		if item.event>=0:
			enemy.set_meta("supply_event",int(item.event)); enemy.set_meta("supply_index",int(item.supply_index)); enemy.add_to_group("airdrop_guards")
	for item in state.loose:
		var loot: Node3D = world.spawn_loot(world.sector_offset(world.sector_coord)+point(item.pos),items(item.contents),int(item.xp),item.power,int(item.loaded),item.auto,bool(item.get("origin",false)))
		if loot!=null and item.boss: world.mark_boss_drop(loot)

static func number(value,low: float,high: float,integer: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and (not integer or int(value)==value)
static func vec(value,limit: float = 60) -> bool:
	return value is Array and value.size()==3 and value.all(func(v): return number(v,-limit,limit))
static func contents(value) -> bool:
	if not value is Dictionary or value.size()>ItemBag.IDS.size(): return false
	for id in value:
		if id not in ItemBag.IDS or not number(value[id],1,1000000,true): return false
	return true
static func indices(value,maximum: int) -> bool:
	if not value is Array or value.size()>maximum: return false
	var seen := {}
	for index in value:
		if not number(index,0,maximum-1,true) or seen.has(int(index)): return false
		seen[int(index)] = true
	return true

static func valid_layout(d,key: String) -> bool:
	if not d is Dictionary: return false
	for field in ["seed","coord","visit","risk","biome","count","blocks","spawns","caches","reward","rare","rare_pos","roster","houses"]:
		if not d.has(field): return false
	if not number(d.seed,1,2147483647,true) or not number(d.visit,1,10000000,true) or not number(d.risk,0,4,true) or not number(d.biome,0,4,true) or not number(d.count,0,1120,true) or not number(d.rare,-1,8,true): return false
	if not d.coord is Array or d.coord.size()!=2 or not d.coord.all(func(v): return number(v,-4096,4096,true)) or SectorGenerator.key(Vector2i(d.coord[0],d.coord[1]))!=key or key=="0:0": return false
	if not d.blocks is Array or d.blocks.size()>24 or not d.spawns is Array or d.spawns.size()>44 or not d.caches is Array or d.caches.size()!=3 or not vec(d.rare_pos) or not contents(d.reward) or not d.houses is Array or d.houses.size()>4: return false
	for block in d.blocks:
		if not block is Dictionary or not vec(block.get("pos")) or not vec(block.get("size"),12) or not number(block.get("style"),0,2,true): return false
	for pos in d.spawns+d.caches:
		if not vec(pos): return false
	for house in d.houses:
		if not house is Dictionary or not number(house.get("id"),0,3,true) or not vec(house.get("pos")) or not number(house.get("yaw"),-TAU,TAU) or not number(house.get("style"),0,2,true) or not number(house.get("guards"),1,12,true) or not contents(house.get("reward")): return false
	if not d.roster is Array or d.roster.size()!=int(d.count) or not d.roster.all(func(k): return number(k,0,16,true)): return false
	if not number(d.get("base_count"),0,140,true) or not d.get("base_roster") is Array or d.base_roster.size()!=int(d.base_count) or not d.base_roster.all(func(k): return number(k,0,16,true)): return false
	return true

static func valid(memory,elapsed: float) -> bool:
	if not memory is Dictionary or memory.size()>LIMIT: return false
	for key in memory:
		if not key is String: return false
		var s = memory[key]
		if not s is Dictionary or not number(s.get("expires"),0,elapsed+LIFETIME+.01) or not valid_layout(s.get("layout"),key): return false
		if not indices(s.get("claimed"),4) or not indices(s.get("dead"),1120) or not s.get("caches") is Array or s.caches.size() not in [3,4] or not s.caches.all(func(c): return contents(c)): return false
		if not s.get("houses") is Array or s.houses.size()>4 or not s.get("enemies") is Array or s.enemies.size()>72 or not s.get("loose") is Array or s.loose.size()>128: return false
		for house in s.houses:
			if not house is Dictionary or not number(house.get("id"),0,3,true) or not indices(house.get("dead"),96) or not house.get("activated") is bool or not number(house.get("total"),1,96,true) or not contents(house.get("contents")): return false
		for enemy in s.enemies:
			if not enemy is Dictionary or not number(enemy.get("kind"),0,16,true) or not number(enemy.get("index"),-3,1119,true) or not vec(enemy.get("pos"),120) or not number(enemy.get("max"),1,100000000) or not number(enemy.get("hp"),.001,enemy.max) or not number(enemy.get("damage"),0,100000000) or not number(enemy.get("speed"),0,1000) or not enemy.get("enraged") is bool or not number(enemy.get("shield"),0,10) or not number(enemy.get("ability"),-100,100) or not number(enemy.get("summons"),0,3,true): return false
			for field in ["house","guard","event","supply_index"]:
				if not number(enemy.get(field),-1,100000000,true): return false
			if not number(enemy.get("stage"),0,100000,true): return false
		for item in s.loose:
			if not item is Dictionary or not vec(item.get("pos"),120) or not contents(item.get("contents")) or not number(item.get("xp"),0,1000000,true) or item.get("power") not in ["","speed","rapid","shield"] or not number(item.get("loaded"),0,100000,true) or not item.get("auto") is bool or not item.get("boss") is bool: return false
	return true
