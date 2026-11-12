class_name BetaInventory
extends RefCounted
var slots: Array = []
var nominal: float = 30
var loaded_mass: float = 0
var hotbar: Array = [0, 1, -1, -1, -1, -1]
var backpack: bool = false
var armor: bool = false
var equipment: Dictionary = {"primary": -1, "secondary": -1, "tool": -1, "protection": -1, "backpack": -1}

func _init(size: int = 24, capacity: float = 30) -> void:
	nominal = capacity
	slots.resize(size)
	slots.fill({})

func copy() -> BetaInventory:
	var result := BetaInventory.new(slots.size(), nominal)
	result.slots = slots.duplicate(true)
	result.loaded_mass = loaded_mass
	result.hotbar = hotbar.duplicate()
	result.backpack = backpack
	result.armor = armor
	result.equipment = equipment.duplicate()
	return result

func assign(other: BetaInventory) -> void:
	slots = other.slots.duplicate(true)
	loaded_mass = other.loaded_mass
	hotbar = other.hotbar.duplicate()
	nominal = other.nominal
	backpack = other.backpack
	armor = other.armor
	equipment = other.equipment.duplicate()

func weight() -> float:
	var total := loaded_mass
	for stack: Dictionary in slots:
		if not stack.is_empty():
			total += float(BetaCatalog.item(stack.id).weight) * int(stack.qty)
	return total

func ratio() -> float:
	return weight() / nominal

func move_factor() -> float:
	return .45 if ratio() > 1.25 + .00001 else .75 if ratio() > 1.0 + .00001 else 1.0

func agile() -> bool:
	return ratio() <= 1.25 + .00001

func count(id: String) -> int:
	var total := 0
	for stack: Dictionary in slots:
		if stack.get("id", "") == id:
			total += int(stack.qty)
	return total

func add(id: String, quantity: int) -> int:
	var spec := BetaCatalog.item(id)
	if spec.is_empty() or quantity <= 0:
		return 0
	var allowed := mini(quantity, maxi(0, floori((nominal * 1.5 - weight() + .000001) / float(spec.weight))))
	var remaining := allowed
	for i in range(slots.size()):
		if slots[i].get("id", "") == id and int(slots[i].qty) < int(spec.stack):
			var amount := mini(remaining, int(spec.stack) - int(slots[i].qty))
			slots[i] = {"id": id, "qty": int(slots[i].qty) + amount}
			remaining -= amount
	for i in range(slots.size()):
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var amount := mini(remaining, int(spec.stack))
			slots[i] = {"id": id, "qty": amount}
			remaining -= amount
	return allowed - remaining

func remove(id: String, quantity: int) -> bool:
	if quantity < 0 or count(id) < quantity or (id == "backpack" and backpack):
		return false
	var remaining := quantity
	for i in range(slots.size()):
		if slots[i].get("id", "") == id:
			var amount := mini(remaining, int(slots[i].qty))
			remaining -= amount
			slots[i] = {"id": id, "qty": int(slots[i].qty) - amount} if int(slots[i].qty) > amount else {}
			if slots[i].is_empty():
				clear_equipment(i)
				for h in range(hotbar.size()):
					if hotbar[h] == i:
						hotbar[h] = -1
			if remaining == 0:
				break
	if id == "armor" and count(id) == 0:
		armor = false
	return true

func transfer_to(target: BetaInventory, index: int, quantity: int) -> int:
	if target == self or index < 0 or index >= slots.size() or slots[index].is_empty() or quantity <= 0:
		return 0
	var stack: Dictionary = slots[index]
	if stack.id == "backpack" and backpack:
		return 0
	var next := target.copy()
	var accepted := next.add(stack.id, mini(quantity, int(stack.qty)))
	if accepted == 0:
		return 0
	# Origin slot, rather than remove(id), preserves references to other stacks.
	slots[index] = {"id": stack.id, "qty": int(stack.qty) - accepted} if int(stack.qty) > accepted else {}
	if slots[index].is_empty():
		clear_equipment(index)
		for h in range(hotbar.size()):
			if hotbar[h] == index:
				hotbar[h] = -1
	target.assign(next)
	if stack.id == "armor" and count("armor") == 0:
		armor = false
	return accepted

func equip_backpack(value: bool) -> bool:
	var size := 30 if value else 24
	var capacity := 40.0 if value else 30.0
	if value and count("backpack") == 0:
		return false
	if slots.filter(func(stack): return not stack.is_empty()).size() > size or weight() > capacity * 1.5 + .00001:
		return false
	if size < slots.size():
		var compacted: Array = []
		var remap: Dictionary = {}
		for i in range(slots.size()):
			if not slots[i].is_empty():
				remap[i] = compacted.size()
				compacted.append(slots[i].duplicate())
		for h in range(hotbar.size()):
			hotbar[h] = int(remap.get(hotbar[h], -1))
		for key: String in equipment:
			equipment[key] = int(remap.get(equipment[key], -1))
		slots = compacted
	slots.resize(size)
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = {}
	for h in range(hotbar.size()):
		if hotbar[h] >= size:
			hotbar[h] = -1
	nominal = capacity
	backpack = value
	equipment.backpack = -1
	if value:
		for i in range(slots.size()):
			if slots[i].get("id", "") == "backpack":
				equipment.backpack = i
				break
	return true

func serialize() -> Dictionary:
	return {"slots": slots.duplicate(true), "nominal": nominal, "hotbar": hotbar.duplicate(), "backpack": backpack, "armor": armor, "equipment": equipment.duplicate(), "loaded_mass": loaded_mass}

func restore(data: Dictionary) -> bool:
	if not data.get("slots") is Array or data.slots.size() < 1 or data.slots.size() > 80 or not data.get("hotbar") is Array or data.hotbar.size() != 6:
		return false
	if not (data.get("nominal") is int or data.get("nominal") is float) or data.nominal <= 0 or data.nominal > 100000:
		return false
	for stack in data.slots:
		if not stack is Dictionary:
			return false
		if stack.is_empty():
			continue
		var spec := BetaCatalog.item(str(stack.get("id", "")))
		if spec.is_empty() or not (stack.get("qty") is float or stack.get("qty") is int) or stack.qty != int(stack.qty) or stack.qty < 1 or stack.qty > spec.stack:
			return false
	for index in data.hotbar:
		if not (index is int or index is float) or index != int(index) or index < -1 or index >= data.slots.size():
			return false
	var next := BetaInventory.new(data.slots.size(), float(data.nominal))
	var mass = data.get("loaded_mass", 0)
	if not (mass is int or mass is float) or mass < 0 or mass > 1000:
		return false
	next.loaded_mass = float(mass)
	next.slots = data.slots.map(func(stack): return {} if stack.is_empty() else {"id": str(stack.id), "qty": int(stack.qty)})
	next.hotbar = data.hotbar.map(func(index): return int(index))
	next.backpack = bool(data.get("backpack", false))
	next.armor = bool(data.get("armor", false))
	var gear = data.get("equipment", equipment.duplicate())
	if not gear is Dictionary:
		return false
	for key: String in equipment:
		if not gear.has(key) or not (gear[key] is int or gear[key] is float) or gear[key] != int(gear[key]) or gear[key] < -1 or gear[key] >= next.slots.size():
			return false
		next.equipment[key] = int(gear[key])
	if next.weight() > next.nominal * 1.5 + .00001:
		return false
	assign(next)
	return true

func clear_equipment(index: int) -> void:
	for key: String in equipment:
		if equipment[key] == index:
			equipment[key] = -1
			if key == "protection":
				armor = false

func equip_slot(index: int, category: String) -> bool:
	if not equipment.has(category) or index < 0 or index >= slots.size() or slots[index].is_empty():
		return false
	var id: String = slots[index].id
	var allowed := id in ["pistol", "shotgun"] if category in ["primary", "secondary"] else id == "axe" if category == "tool" else id == "armor" if category == "protection" else id == "backpack"
	if not allowed:
		return false
	if category == "backpack":
		return equip_backpack(true)
	clear_equipment(index)
	equipment[category] = index
	if category == "protection":
		armor = true
	return true

func equipment_name(category: String) -> String:
	var index: int = equipment.get(category, -1)
	return BetaCatalog.title(slots[index].id) if index >= 0 and index < slots.size() and not slots[index].is_empty() else "—"
