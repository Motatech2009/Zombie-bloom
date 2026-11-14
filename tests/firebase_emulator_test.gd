extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
	else: print("PASS: "+message)
func run() -> void:
	var script = load("res://tests/firebase_emulator_account.gd")
	var a = script.new(); root.add_child(a)
	a.nickname = "First survivor"
	var email := "survivor-"+Crypto.new().generate_random_bytes(6).hex_encode()+"@example.test"
	await a.authenticate(email,"emulator-test-password",true)
	check(a.signed_in(),"real HTTP signup against Auth emulator")
	if not a.signed_in(): quit(1); return
	var first_uid: String = a.user_id
	a.record_progress("run",{"kills":7,"hordes":2,"scrap":45}); await a.flush_progress()
	var profile: Dictionary = await a.request_json(a.documents_url()+"/players/"+a.user_id,HTTPClient.METHOD_GET)
	check(profile.ok and a.decode_fields(profile.data.get("fields",{})).get("kills",0)==7,"Firestore commit accepts owner counters under deployed rules")
	await a.flush_progress()
	profile = await a.request_json(a.documents_url()+"/players/"+a.user_id,HTTPClient.METHOD_GET)
	check(a.decode_fields(profile.data.get("fields",{})).get("kills",0)==7,"repeated flush leaves real Firestore counters unchanged")
	a.token_deadline = 0
	check(await a.ensure_token(),"real HTTP session refresh against Auth emulator")
	await a.save_online_profile("New nickname")
	profile = await a.request_json(a.documents_url()+"/players/"+a.user_id,HTTPClient.METHOD_GET)
	var values: Dictionary = a.decode_fields(profile.data.get("fields",{}))
	check(values.get("nickname")=="New nickname" and values.get("kills")==7,"nickname change preserves counters")
	await a.fetch_ranking("kills")
	check(a.rows.size()==1 and a.rows[0].score==7,"authenticated limited ranking query works with rules")
	var sync_url: String = a.documents_url()+"/players/"+a.user_id+"/devices/"+a.ledger.device
	var sync: Dictionary = await a.request_json(sync_url,HTTPClient.METHOD_GET)
	var stale: Dictionary = {"update":{"name":a.player_name()+"/devices/"+a.ledger.device,"fields":sync.data.fields},"currentDocument":{"updateTime":sync.data.updateTime}}
	a.record_progress("run",{"kills":8,"hordes":2,"scrap":45}); await a.flush_progress()
	var duplicate: Dictionary = await a.request_json(a.documents_url()+":commit",HTTPClient.METHOD_POST,{"writes":[stale]})
	check(not duplicate.ok,"Firestore rejects stale device checkpoint precondition")
	var second = script.new(); root.add_child(second); second.nickname = "Second survivor"
	await second.authenticate("other-"+email,"emulator-test-password",true)
	check(second.signed_in() and second.user_id!=first_uid,"second account has a distinct identity")
	second.record_progress("run",{"kills":3,"hordes":1,"scrap":10}); await second.flush_progress()
	var forbidden: Dictionary = await second.request_json(second.documents_url()+":commit",HTTPClient.METHOD_POST,{"writes":[{"update":{"name":a.player_name(),"fields":{"nickname":{"stringValue":"Intruder"}}},"updateMask":{"fieldPaths":["nickname"]}}]})
	check(not forbidden.ok and int(forbidden.code)==403,"one account cannot write another account's public profile")
	forbidden = await second.request_json(sync_url,HTTPClient.METHOD_GET)
	check(not forbidden.ok and int(forbidden.code)==403,"device synchronization state remains private to owner")
	forbidden = await second.request_json(second.documents_url()+":runQuery",HTTPClient.METHOD_POST,{"structuredQuery":{"from":[{"collectionId":"players"}],"limit":26}})
	check(not forbidden.ok,"security rules reject ranking requests over 25 documents")
	forbidden = await second.request_json(second.documents_url()+":commit",HTTPClient.METHOD_POST,{"writes":[{"update":{"name":second.player_name(),"fields":{"email":{"stringValue":"private@example.test"}}},"updateMask":{"fieldPaths":["email"]}}]})
	check(not forbidden.ok,"public ranking documents cannot contain private e-mail fields")
	await a.logout(); await a.authenticate(email,"emulator-test-password")
	check(a.signed_in() and a.user_id==first_uid and a.nickname=="New nickname","email login restores same public profile")
	await a.recover(email)
	check(a.status.contains("link"),"password reset is handled by Auth emulator")
	for account in [a,second]:
		var path: String = account.ledger_path()
		await account.logout(); DirAccess.remove_absolute(path); account.queue_free()
	await process_frame
	print("FIREBASE EMULATOR RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
