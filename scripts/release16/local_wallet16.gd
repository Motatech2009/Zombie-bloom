class_name LocalWallet16
extends RefCounted

var path := "user://wallet16.json"
var data := {"balance": 0, "owned": [], "equipped": {}, "credited": {}, "legacy_imported": false}

func load_wallet() -> void:
	if not FileAccess.file_exists(path):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Dictionary or not saved.get("owned") is Array or not saved.get("equipped") is Dictionary or not saved.get("credited") is Dictionary:
		return
	var amount = saved.get("balance")
	if (not amount is int and not amount is float) or not is_finite(float(amount)):
		return
	data = saved
	data.balance = maxi(0, int(saved.balance))

func import_legacy(profile: Dictionary) -> void:
	if data.get("legacy_imported", false):
		return
	var next := data.duplicate(true)
	var amount := maxi(0, int(profile.get("balance", 0)))
	for id in profile.get("owned", []):
		if id is String and not Catalog16.cosmetic(id).is_empty() and id not in next.owned:
			next.owned.append(id)
	if amount == 0 and next.owned == data.owned:
		return
	next.balance += amount
	for cls in ["engineer", "scout", "shooter"]:
		var previous: Dictionary = profile.get("equipped", {}).get(cls, {})
		if not Cosmetics16.valid(previous, cls):
			continue
		var current: Dictionary = next.equipped.get(cls, {})
		for slot in previous:
			if not current.has(slot) and previous[slot] in next.owned:
				current[slot] = previous[slot]
		next.equipped[cls] = current
	next.legacy_imported = true
	commit(next)

func credit(run: String, wave: int) -> int:
	if run.is_empty() or wave <= int(data.credited.get(run, 0)):
		return 0
	var reward := int(Catalog16.data().currency.horde_reward)
	var next := data.duplicate(true)
	next.balance += reward
	next.credited[run] = wave
	return reward if commit(next) else -1

func purchase(id: String) -> String:
	var item := Catalog16.cosmetic(id)
	if item.is_empty(): return "Cosmético inválido."
	if item.has("unlock"): return "Exclusivo por derrotar o Titã."
	if id in data.owned: return "Cosmético já adquirido."
	var price := int(item.price)
	if data.balance < price: return "Saldo insuficiente."
	var next := data.duplicate(true)
	next.balance -= price
	next.owned.append(id)
	return "Cosmético adquirido." if commit(next) else "Não foi possível salvar a compra."

func equip(class_id: String, slot: String, id: String) -> bool:
	if not Cosmetics16.valid({slot: id}, class_id) or (not id.is_empty() and id not in data.owned):
		return false
	var next := data.duplicate(true)
	var slots: Dictionary = next.equipped.get(class_id, {})
	if id.is_empty(): slots.erase(slot)
	else: slots[slot] = id
	next.equipped[class_id] = slots
	return commit(next)

func commit(next: Dictionary) -> bool:
	var temp := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(next))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temp, path) != OK: return false
	data = next
	return true
