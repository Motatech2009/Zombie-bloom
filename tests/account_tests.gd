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
	check(account.paths.is_empty(),"missing configuration never attempts login")
	account.url = "https://example.invalid"; account.public_key = "public-test"
	await account.authenticate("bad","short")
	check(account.paths.is_empty(),"invalid form never calls provider")
	account.replies = [{"ok":true,"data":{"access_token":"test-token","user":{"id":"test-id"}}},{"ok":true,"data":[{"nickname":"Saved profile"}]}]
	await account.authenticate("a@b.c","12345678")
	check(account.token=="test-token" and account.user_id=="test-id" and account.nickname=="Saved profile","successful auth fetches cross-device profile")
	check(account.paths[0]=="/auth/v1/token?grant_type=password","password login uses provider endpoint")
	account.replies = [{"ok":true,"data":[{"position":1,"nickname":"Player","score":3}]}]
	await account.fetch_ranking("kills","endless")
	check(account.rows.size()==1,"verified ranking response displayed separately")
	var size: int = account.paths.size(); await account.fetch_ranking("arbitrary","endless")
	check(account.paths.size()==size,"ranking whitelist rejects arbitrary metrics")
	account.replies = [{"ok":false,"data":{}}]; await account.fetch_ranking("scrap","campaign")
	check(account.rows.is_empty(),"network failure clears stale ranking")
	account.replies = [{"ok":true,"data":{}}]; await account.logout()
	check(account.token.is_empty() and account.user_id.is_empty(),"logout clears in-memory credentials")
	account.replies = [{"ok":true,"data":{"user":{"id":"unconfirmed"}}}]
	await account.authenticate("a@b.c","12345678",true)
	check(account.token.is_empty() and account.user_id.is_empty(),"confirmation required signup never pretends to authenticate")
	account.replies = [{"ok":true,"data":{"access_token":"recovery-token"}},{"ok":true,"data":{}},{"ok":true,"data":{}}]
	await account.reset_password("a@b.c","123456","newpassword")
	check(account.token.is_empty() and account.paths.has("/auth/v1/user"),"recovery updates password and discards recovery session")
	account.queue_free(); await process_frame
	for touch in [false,true]:
		MobilePlatform.force_touch = touch
		var menu = load("res://scenes/main/MainMenu.tscn").instantiate(); root.add_child(menu)
		menu.show_account(); await process_frame; await process_frame
		check(menu.content.get_parent() is ScrollContainer,"account form scrolls on PC and touch layout")
		var passwords: Array = menu.content.get_children().filter(func(c): return c is LineEdit and c.secret)
		check(passwords.size()==1,"password field is masked on each platform")
		menu.show_main(); await process_frame
		menu.queue_free(); await process_frame; await process_frame
	MobilePlatform.force_touch = false
	print("ACCOUNT RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
