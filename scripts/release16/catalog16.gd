class_name Catalog16
extends RefCounted
static var cache: Dictionary = {}
static func data() -> Dictionary:
	if cache.is_empty(): cache = JSON.parse_string(FileAccess.get_file_as_string("res://data/release16/catalog.json"))
	return cache
static func talents() -> Array: return data().talents
static func talent(id: String) -> Dictionary:
	for item in talents():
		if item.id==id: return item
	return {}
static func cosmetic(id: String) -> Dictionary:
	for item in data().cosmetics:
		if item.id==id: return item
	return {}
static func talent_ids() -> Array: return talents().map(func(t): return t.id)
static func bonus(actor: Node3D,id: String) -> float:
	var t := talent(id)
	if t.is_empty() or t.class_id!=actor.specialization: return 0
	return actor.world.upgrades.level_for(actor,id)*float(t.step)/100.0
