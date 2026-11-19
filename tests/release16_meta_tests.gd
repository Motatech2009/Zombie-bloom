extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func run() -> void:
	var meta: Node = load("res://tests/meta16_mock.gd").new(); root.add_child(meta)
	meta.api_url = "http://127.0.0.1/mock"; meta.profile_loaded = true
	await meta.sync()
	check(meta.requests==0,"idle signed-in profile makes zero service/database operations")
	meta.sessions = {"session":120}; await meta.sync()
	check(meta.requests==1 and meta.sessions.is_empty(),"active time is sent as one acknowledged batch")
	await meta.sync(); check(meta.requests==1,"acknowledged idle state does not resend unchanged counters")
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	meta.api_url = ""; meta.world = w; meta.sync_left = 999; meta._process(0)
	w.waves.wave = 1; w.waves.running = true; meta._process(0)
	check(meta.pending.is_empty(),"starting a horde never creates pending currency")
	w.waves.complete(); meta._process(0)
	check(meta.pending.size()==1 and int(meta.pending[0].wave)==1,"only a completed horde creates its one pending credit")
	meta._process(0); check(meta.pending.size()==1,"repeated observation does not duplicate the pending credit")
	var state: Dictionary = w.net_state(1)
	check(int(state.progression16.through)==1,"private snapshots expose the completed reward watermark")
	w.waves.wave = 2; w.waves.running = true
	check(int(w.net_state(1).progression16.through)==1,"in-progress wave index remains separate from reward watermark")
	meta.api_url = "http://127.0.0.1/mock"; meta.new_registration = true
	await meta.sync()
	check(int(meta.last_registration.baseline)==1,"online registration uses completed watermark, never running horde index")
	check(meta.pending.is_empty() and meta.status.contains("anteriores ao registro"),"pre-registration offline rewards are reconciled once with an explicit status")
	meta.pending = [{"match_id":"abandoned-run","wave":1},{"match_id":w.account_run_id,"wave":1}]
	meta.registered["abandoned-run"] = true; meta.calls.clear()
	await meta.sync()
	var credits: Array = meta.calls.filter(func(c): return c.action=="horde")
	check(credits.size()==1 and credits[0].data.match_id==w.account_run_id,"an abandoned match never blocks credits from the currently bound match")
	check(meta.pending.size()==1 and meta.pending[0].match_id=="abandoned-run","old-match pending credit is retained without repeated invalid requests")
	meta.world = null; meta.persist()
	var stored = JSON.parse_string(FileAccess.get_file_as_string(meta.path()))
	check(stored.observed_hordes.has(w.account_run_id),"reward observation watermark is persisted with the queue")
	DirAccess.remove_absolute(meta.path())
	meta.local_economy = true; meta.uid = ""; meta.pending = []
	meta.wallet.path = "user://wallet16-test-" + Crypto.new().generate_random_bytes(4).hex_encode() + ".json"
	meta.observed_hordes = {}; meta.bound_run = ""; meta.world = w; meta._process(0)
	var requests_before: int = meta.requests
	for wave in range(2, 5):
		w.waves.wave = wave; w.waves.running = true
		w.waves.complete(); meta._process(0)
	check(meta.balance() == 300 and meta.pending.is_empty() and meta.requests == requests_before,
		"three completed hordes award 300 immediately to a guest with no service request")
	meta.horde(w.account_run_id, 4); meta.horde(w.account_run_id, 2)
	check(meta.balance() == 300, "replaying the same wave or restoring an older checkpoint grants no duplicate")
	await meta.purchase("COS-ENG-01")
	await meta.purchase("COS-ENG-01")
	check(meta.balance() == 0 and meta.wallet.data.owned.size() == 1, "offline purchase debits exactly once")
	await meta.equip("scout", "head", "COS-ENG-01")
	await meta.equip("engineer", "head", "COS-ENG-01")
	var reloaded := LocalWallet16.new()
	reloaded.path = meta.wallet.path; reloaded.load_wallet()
	check(reloaded.data.owned == ["COS-ENG-01"] and reloaded.data.equipped.engineer.head == "COS-ENG-01" and not reloaded.data.equipped.has("scout"),
		"purchase and class-validated equipment persist with the offline wallet")
	check(reloaded.credit(w.account_run_id, 3) == 0, "disk reload preserves the anti-duplicate watermark")
	DirAccess.remove_absolute(meta.wallet.path); meta.world = null
	meta.queue_free(); w.queue_free(); await create_timer(.35).timeout
	print("RELEASE16 META RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
