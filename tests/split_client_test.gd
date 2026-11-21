extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func wait_notice(w: Node3D,label_text: String,seconds: float = 12) -> bool:
	var end := Time.get_ticks_msec()+int(seconds*1000)
	while w.notice!=label_text and Time.get_ticks_msec()<end: await create_timer(.02).timeout
	return w.notice==label_text
func run() -> void:
	var tag := "1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
	var link: Node = root.get_node("Coop"); link.identity = tag.pad_zeros(32)
	link.join_session("127.0.0.1",24585,"South "+tag)
	var deadline := Time.get_ticks_msec()+14000
	while (not is_instance_valid(link.world) or not link.world.client_scene_ready) and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(is_instance_valid(link.world) and link.world.client_scene_ready,"the guest receives its own base scene")
	if not is_instance_valid(link.world): quit(1); return
	var w: Node3D = link.world
	link.test_input = {"move":Vector2.ZERO,"aim":Vector3.FORWARD,"slot":0}
	await wait_notice(w,"SPLIT_READY")
	link.command("travel",{"direction":2})
	deadline = Time.get_ticks_msec()+8000
	while (w.sector_coord!=Vector2i(0,1) or not w.client_scene_ready) and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	check(w.sector_coord==Vector2i(0,1) and w.client_scene_ready,"the guest receives southern geometry while the host is exploring north")
	check(w.avatars.has(1) and w.avatars[1].region_coord==Vector2i(0,-1),"the guest's party state tracks the host's different quadrant")
	await wait_notice(w,"SPLIT_LOOT")
	link.test_input.interact = true
	deadline = Time.get_ticks_msec()+8000
	while w.player.bag.count("wood")<4 and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	link.test_input.interact = false
	check(w.player.bag.count("wood")==4,"holding collect transfers the southern loot into the guest's private bag")
	await wait_notice(w,"SPLIT_BAT")
	var ammo: Array = w.player.weapons.ammo.duplicate()
	var bat_slot := -1
	for i in range(9):
		if w.player.bag.slots[i].id=="bat": bat_slot = i
	link.test_input.slot = bat_slot; link.test_input.fire = true
	deadline = Time.get_ticks_msec()+5000
	while not w.client_enemies.values().any(func(e): return e.health.current<500) and Time.get_ticks_msec()<deadline: await create_timer(.02).timeout
	link.test_input.fire = false
	check(w.client_enemies.values().any(func(e): return e.health.current<500) and w.player.weapons.ammo==ammo,"the guest sees its bat damage confirmed without spending firearm ammunition")
	await wait_notice(w,"SPLIT_WAVE")
	check(w.waves.running and w.sector_coord==Vector2i(0,1),"the automatic core horde reaches guests without teleporting them home")
	await wait_notice(w,"SPLIT_DONE")
	link.close_session(); w.queue_free(); await create_timer(.25).timeout
	print("SPLIT CLIENT RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
