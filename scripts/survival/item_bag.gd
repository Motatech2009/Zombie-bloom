class_name ItemBag
extends RefCounted
const SIZE := 18
const IDS = ["pistol","shotgun","rifle","smg","launcher","scrap","wood","parts","light","shell","rifle_ammo","rocket","grenade","medkit"]
const TITLES = {"pistol":"Pistola","shotgun":"Espingarda","rifle":"Rifle","smg":"Submetralhadora","launcher":"Lança-foguetes","scrap":"Sucata","wood":"Madeira","parts":"Componentes","light":"Munição leve","shell":"Cartuchos","rifle_ammo":"Munição de rifle","rocket":"Foguetes","grenade":"Granadas","medkit":"Kit médico"}
const SHORT = {"pistol":"PST","shotgun":"ESC","rifle":"RFL","smg":"SMG","launcher":"FOG","scrap":"SUC","wood":"MAD","parts":"CMP","light":"9mm","shell":"12g","rifle_ammo":"5.56","rocket":"Fgt","grenade":"GRA","medkit":"MED"}
const WEAPON_IDS = ["pistol","shotgun","rifle","smg","launcher"]
const AMMO_IDS = ["light","shell","rifle_ammo","light","rocket"]
var slots: Array = []
var selected: int = 0

func _init() -> void:
	for i in range(SIZE): slots.append({"id":"","qty":0})

static func stack(id: String) -> int:
	if id in WEAPON_IDS: return 1
	match id:
		"wood": return 20
		"parts": return 12
		"scrap": return 40
		"light","rifle_ammo": return 60
		"shell": return 20
		"rocket": return 3
		"grenade": return 4
		"medkit": return 3
	return 0

func count(id: String) -> int:
	var result := 0
	for slot in slots:
		if slot.id==id: result += int(slot.qty)
	return result

func add(id: String,quantity: int) -> int:
	if id not in IDS or quantity<=0: return 0
	if id in WEAPON_IDS:
		if count(id)>0: return 0
		quantity = mini(quantity,1)
	var remaining := quantity
	for slot in slots:
		if slot.id==id:
			var take := mini(stack(id)-int(slot.qty),remaining)
			slot.qty += take
			remaining -= take
	for slot in slots:
		if remaining==0: break
		if slot.qty==0:
			var take := mini(stack(id),remaining)
			slot.id = id
			slot.qty = take
			remaining -= take
	return quantity-remaining

func remove(id: String,quantity: int) -> bool:
	if quantity<=0 or count(id)<quantity: return false
	var remaining := quantity
	for slot in slots:
		if slot.id==id:
			var take := mini(int(slot.qty),remaining)
			slot.qty -= take
			remaining -= take
			if slot.qty==0: slot.id = ""
		if remaining==0: break
	return true

func swap(a: int,b: int) -> bool:
	if a<0 or b<0 or a>=SIZE or b>=SIZE: return false
	var temp: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = temp
	return true

func hand() -> String:
	return slots[selected].id

func free_slots() -> int:
	return slots.filter(func(s): return s.qty==0).size()

func dump() -> Dictionary:
	return {"slots":slots.duplicate(true),"selected":selected}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("slots") is Array or data.slots.size()!=SIZE: return false
	var select = data.get("selected")
	if not (select is int or select is float) or select<0 or select>8 or int(select)!=select: return false
	var weapons := {}
	for slot in data.slots:
		if not slot is Dictionary or not slot.has("id") or not slot.has("qty") or not slot.id is String: return false
		var qty = slot.qty
		if not (qty is int or qty is float) or not is_finite(float(qty)) or int(qty)!=qty or qty<0: return false
		if qty==0:
			if slot.id!="": return false
		elif slot.id not in IDS or qty>stack(slot.id): return false
		if slot.id in WEAPON_IDS:
			if weapons.has(slot.id): return false
			weapons[slot.id] = true
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data): return false
	slots = data.slots.duplicate(true)
	for slot in slots: slot.qty = int(slot.qty)
	selected = int(data.selected)
	return true
