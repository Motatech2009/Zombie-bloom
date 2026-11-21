extends "res://scripts/online/account_service.gd"
## Only used by the Firebase Emulator Suite. Never included in game exports.
func _ready() -> void:
	project_id = "demo-zombie-bloom"; api_key = "fake-emulator-key"; set_process(false)
func documents_url() -> String:
	return "http://127.0.0.1:8080/v1/projects/"+project_id+"/databases/(default)/documents"
func auth_url(action: String) -> String:
	return "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:"+action+"?key="+api_key
func refresh_url() -> String:
	return "http://127.0.0.1:9099/securetoken.googleapis.com/v1/token?key="+api_key
