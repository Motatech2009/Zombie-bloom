class_name ProgressLedger
extends RefCounted
## Device-local cumulative counters; checkpoints may rewind, credited progress does not.
const METRICS := ["kills","hordes","scrap"]
var device := ""
var totals := {"kills":0,"hordes":0,"scrap":0}
var runs: Dictionary = {}

func observe(run: String, values: Dictionary, baseline: bool = false) -> bool:
	if run.is_empty(): return false
	var previous: Dictionary = runs.get(run,{"kills":0,"hordes":0,"scrap":0})
	var changed := false
	for metric in METRICS:
		var value := maxi(0,int(values.get(metric,0)))
		var high := int(previous.get(metric,0))
		if value>high:
			if not baseline: totals[metric] += value-high
			previous[metric] = value
			changed = true
	runs[run] = previous
	return changed

func dump() -> Dictionary:
	return {"device":device,"totals":totals.duplicate(),"runs":runs.duplicate(true)}

func restore(data: Dictionary) -> void:
	device = str(data.get("device",""))
	for metric in METRICS: totals[metric] = maxi(0,int(data.get("totals",{}).get(metric,0)))
	runs = data.get("runs",{}).duplicate(true)

func delta_from(remote: Dictionary) -> Dictionary:
	var delta := {}
	for metric in METRICS: delta[metric] = maxi(0,int(totals[metric])-int(remote.get(metric,0)))
	return delta
