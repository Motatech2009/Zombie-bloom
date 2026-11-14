extends "res://scripts/online/account_service.gd"
var replies: Array = []
var paths: Array = []
func request_json(path: String,_method: int,_payload: Dictionary = {}) -> Dictionary:
	paths.append(path)
	await get_tree().process_frame
	return replies.pop_front() if not replies.is_empty() else {"ok":false,"data":{}}

func save_nickname(value: String) -> void:
	nickname = value.left(16)
