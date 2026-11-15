class_name ItemBag
extends RefCounted
const SIZE := 18
const IDS = ["pistol","shotgun","rifle","smg","launcher","scrap","wood","parts","light","shell","rifle_ammo","rocket","grenade","medkit","revolver","sniper","lmg","tesla","heavy","cells","bat","beacon"]
const TITLES = {"beacon":"Sinalizador de extração","bat":"Taco de beisebol","pistol":"Pistola","shotgun":"Espingarda","rifle":"Rifle","smg":"Submetralhadora","launcher":"Lança-foguetes","scrap":"Sucata","wood":"Madeira","parts":"Componentes","light":"Munição leve","shell":"Cartuchos","rifle_ammo":"Munição de rifle","rocket":"Foguetes","grenade":"Granadas","medkit":"Kit médico","revolver":"Revólver","sniper":"Rifle de precisão","lmg":"Metralhadora","tesla":"Arco Tesla","heavy":"Munição pesada","cells":"Células de energia"}
const SHORT = {"beacon":"EXTR","bat":"TACO","pistol":"PST","shotgun":"ESC","rifle":"RFL","smg":"SMG","launcher":"FOG","scrap":"SUC","wood":"MAD","parts":"CMP","light":"9mm","shell":"12g","rifle_ammo":"5.56","rocket":"Fgt","grenade":"GRA","medkit":"MED","revolver":"REV","sniper":"SNP","lmg":"LMG","tesla":"ARC","heavy":".357","cells":"CEL"}
const WEAPON_IDS = ["pistol","shotgun","rifle","smg","launcher","revolver","sniper","lmg","tesla"]
const AMMO_IDS = ["light","shell","rifle_ammo","light","rocket","heavy","rifle_ammo","rifle_ammo","cells"]
var cargo_level := 0
var capacity_slots := 18
var slots: Array = []
var selected: int = 0

func _init() -> void:
	for i in range(SIZE): slots.append({"id":"","qty":0})

static func stack(id: String) -> int:
	if id in WEAPON_IDS or id=="bat": return 1
	match id:
		"wood": return 20
		"parts": return 12
		"scrap": return 40
		"light","rifle_ammo": return 60
		"shell": return 20
		"heavy","cells": return 30
		"rocket": return 3
		"grenade": return 4
		"medkit": return 3
		"beacon": return 2
	return 0

func stack_limit(id: String) -> int:
	return ceili(stack(id)*(1+cargo_level/12.0)) if id in ["scrap","wood","parts","light","shell","rifle_ammo","heavy","cells","rocket"] else stack(id)

func resize_bag(size: int) -> void:
	capacity_slots = clampi(size,18,20)
	while slots.size()<capacity_slots: slots.append({"id":"","qty":0})

func count(id: String) -> int:
	var result := 0
	for slot in slots:
		if slot.id==id: result += int(slot.qty)
	return result

func add(id: String,quantity: int) -> int:
	if id not in IDS or quantity<=0: return 0
	if id in WEAPON_IDS or id=="bat":
		if count(id)>0: return 0
		quantity = mini(quantity,1)
	var remaining := quantity
	for slot in slots:
		if slot.id==id:
			var take := mini(stack_limit(id)-int(slot.qty),remaining)
			slot.qty += take
			remaining -= take
	for slot in slots:
		if remaining==0: break
		if slot.qty==0:
			var take := mini(stack_limit(id),remaining)
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
	if a<0 or b<0 or a>=slots.size() or b>=slots.size(): return false
	var temp: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = temp
	return true

func hand() -> String:
	return slots[selected].id

func free_slots() -> int:
	return slots.filter(func(s): return s.qty==0).size()

func dump() -> Dictionary:
	return {"slots":slots.duplicate(true),"selected":selected,"cargo":cargo_level}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("slots") is Array or data.slots.size() not in [18,20]: return false
	var select = data.get("selected")
	if not (select is int or select is float) or select<0 or select>8 or int(select)!=select: return false
	var weapons := {}
	for slot in data.slots:
		if not slot is Dictionary or not slot.has("id") or not slot.has("qty") or not slot.id is String: return false
		var qty = slot.qty
		if not (qty is int or qty is float) or not is_finite(float(qty)) or int(qty)!=qty or qty<0: return false
		if qty==0:
			if slot.id!="": return false
		elif slot.id not in IDS or qty>ceili(stack(slot.id)*(1+int(data.get("cargo",0))/12.0 if slot.id in ["scrap","wood","parts","light","shell","rifle_ammo","heavy","cells","rocket"] else 1)):
			return false
		if not SectorMemory.number(data.get("cargo",0),0,12,true): return false
		if slot.id in WEAPON_IDS:
			if weapons.has(slot.id): return false
			weapons[slot.id] = true
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data): return false
	slots = data.slots.duplicate(true)
	for slot in slots: slot.qty = int(slot.qty)
	selected = int(data.selected)
	cargo_level = int(data.get("cargo",0)); capacity_slots = slots.size()
	return true
