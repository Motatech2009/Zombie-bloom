class_name BetaCatalog
extends RefCounted
const DATA = preload("res://resources/beta/catalog.tres")
const STRUCTURES := ["foundation", "wall", "gate", "barricade", "crate", "workbench"]
static func item(id: String) -> Dictionary:
	return DATA.values.items.get(id, {})
static func title(id: String) -> String:
	return str(item(id).get("title", id))
static func recipe(id: String) -> Dictionary:
	for row: Dictionary in DATA.values.recipes:
		if row.id == id:
			return row
	return {}
