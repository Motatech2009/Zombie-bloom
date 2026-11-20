extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func seed_doc(a: Node,suffix: String,value: Dictionary) -> void:
	var req := HTTPRequest.new(); root.add_child(req)
	var url: String = a.documents_url()+"/community16/"+a.user_id+suffix
	req.request(url,["Content-Type: application/json","Authorization: Bearer owner"],HTTPClient.METHOD_PATCH,JSON.stringify({"fields":FirestoreEconomy16.encode(value).mapValue.fields}))
	var reply: Array = await req.request_completed
	check(int(reply[1])==200,"emulator-only fixture seeds successfully"); req.queue_free()
func run() -> void:
	var meta: Node = root.get_node("Meta16"); meta.set_process(false)
	var a: Node = load("res://tests/firebase_emulator_account.gd").new(); root.add_child(a)
	await a.authenticate("spark-godot-"+Crypto.new().generate_random_bytes(5).hex_encode()+"@example.test","emulator-password",true)
	check(a.signed_in(),"Godot authenticates against local emulator")
	if not a.signed_in(): quit(1); return
	var service := FirestoreEconomy16.new(a)
	var reply := await service.request("profile")
	check(reply.ok and int(reply.profile.balance)==0,"Godot initializes and decodes nested Firestore wallet")
	if not reply.ok: print(reply); quit(1); return
	reply = await service.request("purchase",{"item_id":"COS-ENG-01"})
	check(not reply.ok and reply.error=="Saldo insuficiente.","insufficient balance grants nothing")
	reply = await service.request("start",{"match_id":"0123_test-run","mode":"endless","baseline":0})
	check(reply.ok and reply.new_registration and int(reply.confirmed_wave)==0,"numeric-leading match ID registers atomically")
	reply = await service.request("horde",{"match_id":"0123_test-run","wave":1})
	check(not reply.ok,"client respects server horde interval")
	var remote := await service.read_doc(); var wallet: Dictionary = remote.value
	wallet.created_at = {"timestampValue":"2020-01-01T00:00:00Z"}
	await seed_doc(a,"",wallet)
	await seed_doc(a,"/matches/0123_test-run",{"mode":"endless","baseline":0,"wave":0,"created_at":{"timestampValue":"2020-01-01T00:00:00Z"},"rewarded_at":{"timestampValue":"2020-01-01T00:00:00Z"}})
	reply = await service.request("horde",{"match_id":"0123_test-run","wave":1})
	check(reply.ok and int(reply.profile.balance)==100,"Godot credits completed horde through actual rules")
	reply = await service.request("horde",{"match_id":"0123_test-run","wave":1})
	check(reply.ok and reply.duplicate and int(reply.profile.balance)==100,"retry after lost response does not duplicate currency")
	remote = await service.read_doc(); wallet = remote.value; wallet.balance = 600; await seed_doc(a,"",wallet)
	reply = await service.request("purchase",{"item_id":"COS-ENG-01"})
	check(reply.ok and int(reply.profile.balance)==300 and "COS-ENG-01" in reply.profile.owned,"purchase persists debit and inventory")
	reply = await service.request("equip",{"class_id":"engineer","slot":"head","item_id":"COS-ENG-01"})
	check(reply.ok and reply.profile.equipped.engineer.head=="COS-ENG-01","equipment map round-trips through Firestore")
	reply = await service.request("equip",{"class_id":"scout","slot":"head","item_id":"COS-ENG-01"})
	check(not reply.ok,"wrong class is rejected")
	reply = await service.request("sync",{"sessions":{"1234_session":120}})
	check(reply.ok and int(reply.profile.active_seconds)==120,"active time sync works without Functions")
	reply = await service.request("sync",{"sessions":{"1234_session":120}})
	check(reply.ok and int(reply.profile.active_seconds)==120,"same session watermark is idempotent")
	await a.publish_playtime(int(reply.profile.active_seconds))
	await a.fetch_ranking("active_seconds")
	check(a.rows.any(func(row): return row.nickname == a.nickname and row.active_seconds == 120), "Godot publishes confirmed hours and reads them in the real ranking")
	reply = await service.request("titan",{"match_id":"0123_test-run","encounter_id":"fixture"})
	check(reply.ok and "COS-TITAN-01" in reply.profile.owned,"Titan trophy remains unlockable on Spark")
	a.user_id = "different-user"
	reply = await service.request("profile")
	check(not reply.ok,"account switch invalidates in-flight wallet service")
	a.user_id = ""; a.token = ""; a.refresh_token = ""; a.clear_session(); a.queue_free(); await process_frame
	print("SPARK GODOT RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
