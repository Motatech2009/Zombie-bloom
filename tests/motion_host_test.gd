extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func run() -> void:
	var link := root.get_node("Coop")
	check(link.host_session(24581)==OK,"motion fixture opens a real ENet host")
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.waves.set_physics_process(false); w.horde_left = 3600
	var deadline := Time.get_ticks_msec()+12000
	while w.party_count()<2 and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	var travelled := 0.0; var start := Vector3.ZERO; var seen := false
	deadline = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		for id in w.avatars:
			if id==1: continue
			if not seen: start = w.avatars[id].position; seen = true
			travelled = maxf(travelled,w.avatars[id].position.distance_to(start))
		if seen and w.party_count()==1: break
		await create_timer(.02).timeout
	check(seen and travelled>8 and travelled<25,"the host simulates bounded walking distance without client speed authority")
	check(w.party_count()==1,"the movement guest disconnects cleanly after its stop test")
	link.close_session(); w.queue_free(); await create_timer(.2).timeout
	print("MOTION HOST RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
