extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func run() -> void:
	var meta: Node = root.get_node("Meta16"); meta.set_process(false)
	var a: Node = load("res://tests/firebase_emulator_account.gd").new(); root.add_child(a)
	var email := "meta16-"+Crypto.new().generate_random_bytes(5).hex_encode()+"@example.test"
	await a.authenticate(email,"emulator-password",true)
	check(a.signed_in(),"test account authenticates only against local Auth emulator")
	if not a.signed_in(): quit(1); return
	var account: Node = root.get_node("Account"); account.set_process(false)
	account.token = a.token; account.user_id = a.user_id; account.refresh_token = a.refresh_token; account.token_deadline = Time.get_ticks_msec()+300000
	meta.identity_changed(); meta.backend = "service"; meta.api_url = "http://127.0.0.1:5001/demo-zombie-bloom/us-central1/account16Api"
	var reply: Dictionary = await meta.request("profile")
	check(reply.ok and int(reply.profile.balance)==0,"Godot service client receives authenticated profile JSON")
	meta.clock.total = 120; meta.sessions[meta.session_id] = 120
	await meta.sync()
	check(not meta.busy and int(meta.confirmed.balance)==0,"sync finishes without inventing a balance")
	check(meta.sessions.is_empty(),"acknowledged session queue is removed locally")
	await meta.purchase("COS-ENG-01")
	check(meta.status=="Saldo insuficiente." and meta.confirmed.owned.is_empty(),"insufficient balance never grants an item locally")
	await meta.equip("engineer","head","COS-ENG-01")
	check(meta.outfit("engineer").is_empty(),"unowned outfit is not cached as equipped")
	meta.pending = [{"match_id":"old","wave":1}]; meta.persist()
	account.user_id = "another-emulator-identity"; meta.identity_changed()
	check(meta.pending.is_empty() and meta.clock.total==0 and int(meta.confirmed.balance)==0,"switching account isolates local hours, pending credits and inventory")
	account.user_id = ""; account.token = ""; account.refresh_token = ""; a.clear_session()
	a.queue_free(); await create_timer(.2).timeout
	print("ACCOUNT16 GODOT EMULATOR RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
