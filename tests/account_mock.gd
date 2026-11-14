extends "res://scripts/online/account_service.gd"
var replies: Array = []
var paths: Array = []
var payloads: Array = []
var sync_document: Dictionary = {}
var server_totals := {"kills":0,"hordes":0,"scrap":0}
var commits := 0
var lose_commit_response := false
var transport_failure := false
var writes_during_request: Dictionary = {}
func _ready() -> void: set_process(false)
func request_json(path: String,_method: int,payload: Dictionary = {},_form: bool = false) -> Dictionary:
	paths.append(path); payloads.append(payload.duplicate(true))
	await get_tree().process_frame
	if path.ends_with(":commit") and not writes_during_request.is_empty():
		record_progress("active",writes_during_request); writes_during_request.clear()
	if not replies.is_empty(): return replies.pop_front()
	if transport_failure: return {"ok":false,"code":0,"data":{}}
	if path.contains("/devices/"):
		return {"ok":true,"code":200,"data":sync_document.duplicate(true)} if not sync_document.is_empty() else {"ok":false,"code":404,"data":{}}
	if path.ends_with(":commit") and payload.get("writes",[]).size()==2:
		commits += 1
		sync_document = {"fields":payload.writes[0].update.fields.duplicate(true),"updateTime":"revision-"+str(commits)}
		for entry in payload.writes[1].updateTransforms: server_totals[entry.fieldPath] += int(entry.increment.integerValue)
		if lose_commit_response:
			lose_commit_response = false; return {"ok":false,"code":0,"data":{}}
		return {"ok":true,"code":200,"data":{}}
	return {"ok":false,"code":503,"data":{}}
func persist() -> void: dirty = false
func save_nickname(value: String) -> void: nickname = value.left(16)
