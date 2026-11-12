class_name WorldState
extends RefCounted
const FORMAT := 1
static var next_seed: int = 8417
static var resume_requested: bool = false
var world_seed: int = 8417
var changes: Dictionary = {}
var explored: Dictionary = {}
var cargo: Dictionary = {"wood": 0, "stone": 0, "metal": 0}
const CAPACITY := 45
var snapshot: Dictionary = {}

func cargo_total() -> int:
	var total := 0
	for amount in cargo.values():
		total += int(amount)
	return total

func put_cargo(kind: String, units: int) -> int:
	if not cargo.has(kind):
		return 0
	var accepted := mini(maxi(units, 0), CAPACITY - cargo_total())
	cargo[kind] += accepted
	return accepted

func deposit() -> int:
	var total := cargo_total()
	cargo = {"wood": 0, "stone": 0, "metal": 0}
	return total

func write(path: String) -> Error:
	var data := {"format": FORMAT, "generator": WorldGenerator.VERSION, "seed": world_seed, "changes": changes, "explored": explored, "cargo": cargo, "snapshot": snapshot}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	# Keep the previous valid save until the replacement has been fully written.
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(path + ".tmp", path)

func read_save(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("format") != FORMAT or data.get("generator") != WorldGenerator.VERSION:
		return ERR_INVALID_DATA
	for key in ["changes", "explored", "cargo", "snapshot"]:
		if not data.get(key) is Dictionary:
			return ERR_INVALID_DATA
	if not data.get("seed") is float and not data.get("seed") is int:
		return ERR_INVALID_DATA
	for key in data.changes:
		var change = data.changes[key]
		if not key is String or key.length() > 200 or not change is Dictionary:
			return ERR_INVALID_DATA
		for field in change:
			if field == "units":
				var units = change[field]
				if not (units is int or units is float) or units < 0 or units > 10000 or units != int(units):
					return ERR_INVALID_DATA
			elif field == "open":
				if not change[field] is bool:
					return ERR_INVALID_DATA
			else:
				return ERR_INVALID_DATA
	for key in data.explored:
		if not key is String or not data.explored[key] is bool:
			return ERR_INVALID_DATA
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return ERR_INVALID_DATA
	var total := 0
	for kind in ["wood", "stone", "metal"]:
		var amount = data.cargo.get(kind)
		if not (amount is float or amount is int) or amount < 0 or amount > CAPACITY or amount != int(amount):
			return ERR_INVALID_DATA
		total += int(amount)
	if total > CAPACITY or data.cargo.size() != 3:
		return ERR_INVALID_DATA
	world_seed = int(data.seed)
	changes = data.changes
	explored = data.explored
	cargo = data.cargo
	snapshot = data.snapshot
	return OK
