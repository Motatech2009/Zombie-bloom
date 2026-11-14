extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
	else: print("PASS: "+message)
func run() -> void:
	var account := root.get_node("Account")
	account.set_process(false); account.token = "test"; account.user_id = "world-test"; account.ledger = ProgressLedger.new()
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false
	root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	w.records.credit("host","kills",2); w.records.credit("host","scrap",12); w.sync_account_progress()
	check(account.ledger.totals.kills==2 and account.ledger.totals.scrap==12,"host gameplay totals feed the signed-in account")
	var saved: Dictionary = w.snapshot(); w.records.credit("host","kills",1); w.sync_account_progress()
	w.apply_snapshot(saved); w.sync_account_progress(); w.records.credit("host","kills",1); w.sync_account_progress()
	check(account.ledger.totals.kills==3,"checkpoint rollback and replay do not duplicate online progress")
	w.attach_peer(222,"2".repeat(32),"Guest")
	var guest = w.avatars[222]; guest.set_physics_process(false)
	w.records.credit("2".repeat(32),"kills",5)
	var state: Dictionary = w.net_state(222,true)
	check(state.get("account_run_id")==w.account_run_id and state.run_totals["2".repeat(32)].kills==5,"guest snapshots include their attributed counters and stable run ID")
	var actor = w.player; w.player = guest; w.sync_account_progress(); w.player = actor
	check(account.ledger.totals.kills==8,"guest account reads its own credited identity")
	account.user_id = "other-account"; account.ledger = ProgressLedger.new(); w.sync_account_progress()
	check(account.ledger.totals.kills==0,"switching accounts does not import the previous player's history")
	w.records.credit("host","kills",1); w.sync_account_progress()
	check(account.ledger.totals.kills==1,"new account records only subsequent progress")
	w.player.position = w.vendor_pos+Vector3(0,0,2); w.resources.scrap = 1000
	w.hud.show_shop(); await process_frame; await process_frame
	check(w.hud.desktop_shop.entries.size()>0 and not w.hud.desktop_shop.buy.disabled,"desktop vendor opens an affordable selected item")
	var before: int = w.resources.scrap; var entry: Dictionary = w.hud.desktop_shop.entries[0]
	w.hud.desktop_shop.purchase()
	check(w.resources.scrap==before-int(entry.cost) and w.player.bag.count(entry.id)==1,"desktop purchase spends stock once and delivers selected weapon")
	check(w.hud.desktop_shop.buy.disabled,"owned weapon is disabled after purchase")
	w.hud.close_modal(); account.token = ""; account.user_id = ""; account.dirty = false
	w.queue_free(); await process_frame; await process_frame
	print("ACCOUNT WORLD RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
