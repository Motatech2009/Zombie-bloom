class_name RunRecords
extends RefCounted
## Checkpoint-local, explicitly unverified. Never uploaded as competitive scores.
var totals: Dictionary = {}
var victories: Dictionary = {}
func credit(identity: String,metric: String,amount: int) -> void:
	if identity.is_empty() or metric not in ["kills","hordes","scrap"] or amount<=0: return
	if not totals.has(identity): totals[identity] = {"kills":0,"hordes":0,"scrap":0}
	totals[identity][metric] += amount
func victory(wave: int,identities: Array) -> void:
	for identity in identities:
		var event := "%d:%s" % [wave,identity]
		if victories.has(event): continue
		victories[event] = true; credit(identity,"hordes",1)
func dump() -> Dictionary: return {"totals":totals.duplicate(true),"victories":victories.duplicate()}
func restore(data: Dictionary) -> void:
	totals = data.get("totals",{}).duplicate(true); victories = data.get("victories",{}).duplicate()
static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("totals") is Dictionary or not data.get("victories") is Dictionary: return false
	if data.totals.size()>1024 or data.victories.size()>100000: return false
	for id in data.totals:
		if not id is String or not data.totals[id] is Dictionary: return false
		for metric in ["kills","hordes","scrap"]:
			var value = data.totals[id].get(metric)
			if not (value is int or value is float) or not is_finite(value) or value<0 or value>1e12 or value!=floor(value): return false
	return true
