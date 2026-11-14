extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
	else: print("PASS: "+message)
func run() -> void:
	var account = load("res://tests/account_mock.gd").new(); root.add_child(account)
	await account.authenticate("a@b.c","12345678")
	check(account.paths.is_empty(),"missing Firebase configuration does not send requests")
	account.project_id = "demo-zombie-bloom"; account.api_key = "public-test"
	await account.authenticate("bad","short")
	check(account.paths.is_empty(),"invalid login form does not call Firebase")
	account.replies = [{"ok":true,"data":{"idToken":"test-token","localId":"test-id","refreshToken":"refresh","expiresIn":"3600"}},{"ok":true,"data":{"fields":{"nickname":{"stringValue":"Saved profile"},"kills":{"integerValue":"12"}}}}]
	await account.authenticate("a@b.c","12345678")
	check(account.token=="test-token" and account.user_id=="test-id" and account.nickname=="Saved profile","Firebase login loads the account profile")
	check(account.paths[0].contains("accounts:signInWithPassword"),"login uses Firebase email-password endpoint")
	check(account.local_summary.kills==12,"Firestore integer counters decode correctly")
	account.ledger = ProgressLedger.new(); account.ledger.device = "device-a"
	account.record_progress("active",{"kills":5,"hordes":1,"scrap":20})
	check(account.paths.size()==2,"individual game events never make database requests")
	await account.flush_progress()
	check(account.server_totals=={"kills":5,"hordes":1,"scrap":20},"one batch writes all three counters")
	check(account.commits==1 and account.payloads[-1].writes.size()==2,"batch uses one private checkpoint and one public player write")
	var requests: int = account.paths.size(); await account.flush_progress()
	check(account.paths.size()==requests,"idle flush does not read or write Firebase")
	account.record_progress("active",{"kills":8,"hordes":1,"scrap":25}); account.lose_commit_response = true
	await account.flush_progress()
	check(account.server_totals.kills==8,"server can accept a batch whose response is lost")
	await account.flush_progress()
	check(account.server_totals.kills==8 and account.commits==2,"retry reads device checkpoint and does not duplicate accepted totals")
	account.record_progress("active",{"kills":9,"hordes":2,"scrap":30}); account.transport_failure = true
	await account.flush_progress()
	check(account.server_totals.kills==8 and account.flush_clock<=120,"offline batch stays pending with bounded retry delay")
	account.transport_failure = false; account.writes_during_request = {"kills":11,"hordes":2,"scrap":35}
	await account.flush_progress(); await account.flush_progress()
	check(account.server_totals=={"kills":11,"hordes":2,"scrap":35},"progress earned during an in-flight request is preserved")
	var ledger_copy := ProgressLedger.new(); ledger_copy.restore(account.ledger.dump())
	ledger_copy.observe("active",{"kills":3,"hordes":1,"scrap":10}); ledger_copy.observe("active",{"kills":11,"hordes":2,"scrap":35})
	check(ledger_copy.totals==account.ledger.totals,"loading and replaying an older checkpoint does not duplicate account stats")
	ledger_copy.observe("old-save",{"kills":100,"hordes":20,"scrap":900},true)
	check(ledger_copy.totals==account.ledger.totals,"importing a historical save establishes a baseline")
	account.token_deadline = 0
	account.replies = [{"ok":true,"data":{"id_token":"renewed","refresh_token":"next","expires_in":"3600"}}]
	check(await account.ensure_token() and account.token=="renewed","long sessions renew Firebase ID tokens")
	account.replies = [{"ok":true,"data":[{"document":{"fields":{"nickname":{"stringValue":"Player"},"kills":{"integerValue":"30"}}}}]}]
	await account.fetch_ranking("kills")
	check(account.rows.size()==1 and account.rows[0].score==30,"top ranking parses Firestore query documents")
	requests = account.paths.size(); await account.fetch_ranking("kills")
	check(account.paths.size()==requests,"reopening a recent ranking uses the cache")
	await account.fetch_ranking("arbitrary")
	check(account.paths.size()==requests,"ranking rejects unrecognized metrics")
	await account.fetch_ranking("scrap")
	check(account.paths.size()==requests,"ranking refresh throttle avoids repeated reads")
	account.rank_request_at = -60000; account.replies = [{"ok":false,"data":{}}]; await account.fetch_ranking("scrap")
	check(account.rows.is_empty(),"failed query clears stale category results")
	account.replies = [{"ok":true,"data":{}}]; await account.recover("a@b.c")
	check(account.paths[-1].contains("accounts:sendOobCode") and account.payloads[-1].requestType=="PASSWORD_RESET","recovery sends Firebase password-reset link")
	await account.logout()
	check(account.token.is_empty() and account.refresh_token.is_empty() and account.user_id.is_empty(),"logout clears credentials and account state")
	account.queue_free(); await process_frame
	for touch in [false,true]:
		MobilePlatform.force_touch = touch
		var menu = load("res://scenes/main/MainMenu.tscn").instantiate(); root.add_child(menu)
		menu.show_account(); await process_frame; await process_frame
		check(menu.content.get_parent() is ScrollContainer,"account form scrolls on desktop and mobile")
		var passwords: Array = menu.content.get_children().filter(func(c): return c is LineEdit and c.secret)
		check(passwords.size()==1,"password remains masked on both platforms")
		menu.show_main(); await process_frame; await process_frame
		check(menu.menu_panel.size.x<menu.root.size.x*.5,"home buttons leave over half the background unobstructed")
		check(menu.root.get_node("VersionLabel").text=="v"+str(ProjectSettings.get_setting("application/config/version")),"menu version is read from project metadata")
		menu.queue_free(); await process_frame; await process_frame
	MobilePlatform.force_touch = false
	print("ACCOUNT RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
