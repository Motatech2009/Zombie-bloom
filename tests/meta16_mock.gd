extends "res://scripts/release16/account_meta16.gd"
var requests := 0
var last_registration: Dictionary = {}
var new_registration := false
var calls: Array = []
func _ready() -> void:
	set_process(false); session_id = "test"; uid = "meta16-local-"+Crypto.new().generate_random_bytes(4).hex_encode(); sync_left = 999
func request(action: String,data: Dictionary = {}) -> Dictionary:
	requests += 1
	calls.append({"action":action,"data":data.duplicate(true)})
	if action=="start":
		last_registration = data.duplicate()
		return {"ok":true,"registered":true,"new_registration":new_registration,"confirmed_wave":int(data.baseline)}
	return {"ok":true,"profile":{"balance":0,"owned":[],"equipped":{},"active_seconds":120,"longest_seconds":120},"ack_sessions":data.get("sessions",{}).keys()}
