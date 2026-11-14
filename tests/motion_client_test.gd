extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func run() -> void:
	Engine.max_fps = 30
	var link := root.get_node("Coop")
	link.join_session("127.0.0.1",24581,"Movement 30 FPS")
	var deadline := Time.get_ticks_msec()+12000
	while (not is_instance_valid(link.world) or not link.world.prediction.ready) and Time.get_ticks_msec()<deadline: await process_frame
	check(is_instance_valid(link.world) and link.world.prediction.ready,"a 30-FPS guest receives its scene and starts prediction")
	if not is_instance_valid(link.world) or not link.world.prediction.ready: quit(1); return
	var w: Node3D = link.world
	await create_timer(.5).timeout
	link.test_input = {"move":Vector2.RIGHT,"aim":Vector3.FORWARD,"slot":0}
	var direction := Vector3(1,0,-1).normalized()
	var start: Vector3 = w.player.position
	var previous: Vector3 = start
	var previous_basis: Basis = w.camera.basis
	var max_back := 0.0; var max_offset := 0.0; var min_throttle := 32.0; var max_camera_turn := 0.0
	deadline = Time.get_ticks_msec()+2500
	while Time.get_ticks_msec()<deadline:
		await process_frame
		var p: Vector3 = w.player.position
		max_back = maxf(max_back,-(p-previous).dot(direction))
		max_offset = maxf(max_offset,w.player.presentation_offset.length())
		min_throttle = minf(min_throttle,link.peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT))
		max_camera_turn = maxf(max_camera_turn,previous_basis.z.distance_to(w.camera.basis.z))
		previous = p; previous_basis = w.camera.basis
	check(min_throttle==32,"explicit channel count never imposes a tiny incoming-bandwidth limit on the guest")
	check(w.player.position.distance_to(start)>8 and max_back<.4 and w.prediction.hard_corrections==0,"continuous guest walking does not jump metres backwards while snapshots arrive")
	check(max_offset<1,"prediction stays close enough to the host for small visual corrections")
	check(max_camera_turn<.0001,"walking and reconciliation translate the camera without packet-driven rotation")
	link.test_input.move = Vector2.ZERO
	await create_timer(.5).timeout
	check(Vector2(w.player.velocity.x,w.player.velocity.z).length()<.15,"releasing movement stops the guest without waiting for a new movement burst")
	print("MOTION METRICS: fps_cap=30 max_backward_m=%.4f max_visual_offset_m=%.4f throttle_limit=%.0f camera_basis_change=%.7f" % [max_back,max_offset,min_throttle,max_camera_turn])
	print("MOTION CLIENT RESULT: %d checks, %d failures" % [checks,failures])
	link.close_session(); w.queue_free(); await create_timer(.2).timeout; quit(1 if failures else 0)
