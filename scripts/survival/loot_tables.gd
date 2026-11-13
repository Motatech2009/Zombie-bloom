class_name LootTables
extends RefCounted

static func regional(data: Dictionary,index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("supplies-v1:%d:%d:%d" % [int(data.seed),int(data.visit),index])
	var biome: int = data.biome
	var items := {}
	var ammo_chance: float = [.28,.40,.12,.20,.80][biome]
	if rng.randf()<ammo_chance:
		var choices: Array = ["light","shell","rifle_ammo"]
		if biome==4: choices = ["rifle_ammo","rifle_ammo","shell","light","heavy","cells","rocket"]
		elif biome==1: choices = ["light","heavy","cells","rifle_ammo"]
		var id: String = choices[rng.randi_range(0,choices.size()-1)]
		items[id] = ammo_quantity(id,rng)
	if rng.randf()<(.24 if biome==0 else .14): items.medkit = 1
	if rng.randf()<(.25 if biome==4 else .08 if biome==1 else .025): items.grenade = 1
	return items

static func ammo_quantity(id: String,rng: RandomNumberGenerator) -> int:
	match id:
		"rocket": return 1
		"shell","heavy": return rng.randi_range(4,8)
		"cells": return rng.randi_range(6,12)
	return rng.randi_range(8,18)

static func boss(wave: int,rng: RandomNumberGenerator) -> Dictionary:
	var tier := mini(30,maxi(1,wave))
	var result := {"scrap":45+tier*3,"parts":6+tier/3,"light":24+tier}
	var ammo: String = ["shell","rifle_ammo","heavy","cells"][rng.randi_range(0,3)]
	result[ammo] = ammo_quantity(ammo,rng)+tier/2
	if rng.randf()<.65: result.grenade = 1
	if rng.randf()<.45: result.medkit = 1
	if rng.randf()<minf(.06,.02+tier*.001):
		var weapon := rng.randi_range(1,Arsenal.WEAPONS.size()-1)
		result[ItemBag.WEAPON_IDS[weapon]] = 1
		result[ItemBag.AMMO_IDS[weapon]] = maxi(int(result.get(ItemBag.AMMO_IDS[weapon],0)),1 if weapon==4 else 12)
	return result

static func infected(biome: int,rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf()>(.28 if biome==4 else .10): return {}
	var id: String = ["light","shell","rifle_ammo"][rng.randi_range(0,2)]
	return {id:2 if id=="shell" else rng.randi_range(3,6)}
