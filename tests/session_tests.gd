extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
	else: print("PASS: "+message)
func account() -> Node:
	var value = load("res://tests/account_mock.gd").new()
	root.add_child(value); value.persist_to_disk = true
	value.project_id = "demo-zombie-bloom"; value.api_key = "test-public"
	return value
func renewal() -> Dictionary:
	return {"ok":true,"data":{"id_token":"fresh-id","refresh_token":"rotated-refresh","user_id":"session-test-user","expires_in":"3600"}}
func profile() -> Dictionary:
	return {"ok":true,"data":{"fields":{"nickname":{"stringValue":"Session Test"},"kills":{"integerValue":"50"}}}}
func run() -> void:
	var a = account(); a.clear_session()
	a.user_id = "session-test-user"
	if FileAccess.file_exists(a.ledger_path()): DirAccess.remove_absolute(a.ledger_path())
	a.user_id = ""
	a.replies = [{"ok":true,"data":{"idToken":"temporary-id","localId":"session-test-user","refreshToken":"persistent-refresh","expiresIn":"3600"}},profile()]
	await a.authenticate("session@example.test","password123")
	check(FileAccess.file_exists(a.session_path()),"login saves a reusable session immediately")
	var cfg := ConfigFile.new()
	check(cfg.load_encrypted(a.session_path(),FileAccess.get_file_as_bytes(a.session_key_path()))==OK,"session can be read using this installation key")
	check(cfg.get_value("session","refresh","")=="persistent-refresh","refresh credential survives restart")
	check(not cfg.has_section_key("session","password") and not cfg.has_section_key("session","token"),"password and short-lived ID token are not stored")
	a.record_progress("session-run",{"kills":7,"hordes":1,"scrap":10}); a.persist()
	a.queue_free(); await process_frame
	var b = account(); b.transport_failure = true
	await b.restore_session()
	check(b.signed_in() and b.token.is_empty(),"offline restart retains remembered account without pretending to have an ID token")
	check(b.ledger.totals.kills==7,"pending progress reloads with the same device identity")
	b.record_progress("session-run",{"kills":9,"hordes":1,"scrap":10})
	check(b.ledger.totals.kills==9,"offline play continues accumulating for remembered account")
	check(b.paths.size()==1 and b.paths[0].contains("securetoken.googleapis.com"),"offline restore does not query or write Firestore")
	b.transport_failure = false; b.replies = [renewal(),profile()]
	await b.reconnect_session()
	check(b.token=="fresh-id" and b.nickname=="Session Test","network recovery restores login and loads profile")
	cfg = ConfigFile.new(); cfg.load_encrypted(b.session_path(),FileAccess.get_file_as_bytes(b.session_key_path()))
	check(cfg.get_value("session","refresh","")=="rotated-refresh","rotated refresh credential is saved")
	var requests: int = b.paths.size(); await b.ensure_token()
	check(b.paths.size()==requests,"valid ID token is reused without another request")
	await b.logout()
	check(not FileAccess.file_exists(b.session_path()) and not FileAccess.file_exists(b.session_key_path()),"explicit logout removes remembered session and local key")
	requests = b.paths.size(); await b.restore_session()
	check(not b.signed_in() and b.paths.size()==requests,"reopening after logout does not automatically log in")
	b.token = "expired"; b.token_deadline = 0; b.user_id = "session-test-user"; b.refresh_token = "revoked"; b.save_session()
	b.replies = [{"ok":false,"code":400,"data":{"error":{"message":"TOKEN_EXPIRED"}}}]
	check(not await b.ensure_token() and not b.signed_in(),"revoked session returns to login")
	check(not FileAccess.file_exists(b.session_path()),"revoked credential cannot be reused at next launch")
	b.user_id = "session-test-user"; b.refresh_token = "wrong-project"; b.save_session(); b.user_id = ""; b.refresh_token = ""
	b.project_id = "another-project"; requests = b.paths.size(); await b.restore_session()
	check(not b.signed_in() and b.paths.size()==requests,"credentials never restore across Firebase projects")
	b.user_id = "session-test-user"
	if FileAccess.file_exists(b.ledger_path()): DirAccess.remove_absolute(b.ledger_path())
	b.clear_session(); b.queue_free(); await process_frame
	print("SESSION RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
