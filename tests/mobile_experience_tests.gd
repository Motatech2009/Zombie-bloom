extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func frames(n: int = 3) -> void:
	for i in range(n): await physics_frame; await process_frame
func touch(c: TouchControls,id: int,p: Vector2,pressed: bool = true) -> void:
	var e := InputEventScreenTouch.new(); e.index = id; e.position = p; e.pressed = pressed; c._input(e)
func drag(c: TouchControls,id: int,p: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = id; e.position = p; c._input(e)
func run() -> void:
	MobilePlatform.force_touch = true; GameSettings.mobile_performance = true
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false
	root.add_child(w); current_scene = w; w.waves.set_physics_process(false); w.set_process(false); w.set_physics_process(false)
	var a: Node3D = w.player; a.set_physics_process(false); a.position = Vector3(0,0,12); a.invulnerable = 3600
	w.camera.position = a.position+w.camera_offset; w.camera.look_at(a.position)
	await frames()
	var c: TouchControls = w.touch_controls
	touch(c,0,Vector2(260,350))
	check(c.stick_center("move").distance_to(Vector2(260,350))<1 and c.move_vector==Vector2.ZERO,"a new left thumb creates its own neutral joystick center")
	drag(c,0,Vector2(332,350))
	check(c.move_vector.x>.99,"floating joystick measures displacement from the actual thumb origin")
	a._physics_process(1.0/60)
	check(a.aim.dot(a.movement_direction(c.move_vector).normalized())>.999,"walking without fire faces the movement direction")
	var e: Node3D = w.make_enemy(0,a.position+Vector3(-5,0,-5),false,1); e.set_physics_process(false); e.health.setup(1000)
	await frames(); c.set_target(e); touch(c,1,c.buttons.fire.get_center())
	check(c.frame().aim.dot(MobileTargeting.direction(a,e))>.999 and c.frame().move.x>.99,"holding fire aims independently while the left thumb keeps moving")
	touch(c,1,Vector2.ZERO,false)
	check(not c.frame().fire and c.frame().aim.dot(a.movement_direction(c.move_vector).normalized())>.999,"releasing fire immediately restores movement-facing rotation")
	c.reset_fingers(); c._process(.2)
	check(not c.buttons.has("interact"),"collect control disappears when no interaction is available")
	a.position = Vector3(0,0,3); a.bag.add("wood",1); c._process(.2)
	check(c.buttons.has("interact") and c.interaction_text=="GUARDAR","collect control appears with the actual nearby deposit action")
	check(c.pad_style.bg_color.a<.15 and c.pad_style.border_color.a>=.3 and c.pad_style.border_color.a<=.4,"ghost controls leave the world visible with a readable idle outline")
	var hp: float = e.health.current; var id: int = e.net_id
	GameSettings.mobile_performance = false; w.apply_mobile_quality(); await frames()
	check(not MobilePlatform.lightweight() and is_equal_approx(root.scaling_3d_scale,1),"detailed mode applies immediately inside the same world")
	check(not e.rig.has_meta("mobile_batch") and e.health.current==hp and e.net_id==id,"quality restoration rebuilds the model without resetting enemy state")
	var mat := ClayStyle.material(Color("486352"),"brick")
	check(mat.albedo_texture!=null and mat.normal_enabled and mat.uv1_world_triplanar,"detailed mode restores textures, normals and projection")
	GameSettings.mobile_performance = true; w.apply_mobile_quality(); await frames()
	check(e.rig.has_meta("mobile_batch") and ClayStyle.material(Color("486352"),"brick").albedo_texture==null,"light mode switches back to stable opaque clay without stretched UV textures")
	w.hud.show_inventory(); await frames(6)
	var close: Button
	for b in w.hud.modal.find_children("*","Button",true,false):
		if b.text=="FECHAR": close = b
	check(close!=null and close.get_global_rect().position.y<66 and close.get_global_rect().end.x<=960,"menu close stays outside the scroll content and inside the screen")
	check(w.hud.belt.get_global_rect().end.x<=960 and w.hud.belt.get_global_rect().end.y<=540,"compact hotbar fits within the mobile viewport")
	w.hud.close_modal(); c.reset_fingers(); a.position = Vector3(0,0,16); a.velocity = Vector3.ZERO
	e.queue_free(); await frames()
	# Withhold all authoritative snapshots for 200 ms, then acknowledge half of the movement.
	w.is_client = true; a.proxy = true; w.last_scene_revision = w.scene_revision
	var state := {"p":a.position,"velocity":Vector3.ZERO,"ack":0,"roll":0.0,"roll_cd":0.0,"roll_dir":Vector3.FORWARD,"down":false}
	w.prediction.reconcile(state)
	touch(c,0,Vector2(260,350)); drag(c,0,Vector2(332,350))
	var start: Vector3 = a.position; var middle := Vector3.ZERO; var middle_velocity := Vector3.ZERO
	for i in range(12):
		w.prediction.tick(); await physics_frame
		if i==5: middle = a.position; middle_velocity = a.velocity
	check(a.position.distance_to(start)>.7 and w.prediction.history.size()==12,"client moves immediately through a 200 ms gap in host snapshots")
	var before: Vector3 = a.position
	state.p = middle; state.velocity = middle_velocity; state.ack = 6
	w.prediction.reconcile(state)
	check(a.position.distance_to(before)<.15 and w.prediction.history.size()==6,"acknowledgement replays only pending inputs without repeating accepted movement")
	c.reset_fingers(); w.prediction.history.clear(); a.velocity = Vector3.ZERO; a.roll_cooldown = 0
	check(w.prediction.roll(Vector3.RIGHT),"client accepts an eligible roll before a host reply")
	w.prediction.tick(); await physics_frame
	check(a.roll_left>0 and a.roll_cooldown>4.9,"predicted roll starts on the next local physics tick")
	# Predicted weapon feedback is cosmetic until a server snapshot accepts ammunition and damage.
	a.stop_roll(); a.roll_cooldown = 0; w.prediction.history.clear(); w.prediction.visual_shots.clear(); w.prediction.fire_left = 0
	a.bag.selected = 0; a.weapons.sync_hand(); a.weapons.ammo[0] = 12
	var ammo_before: int = a.weapons.ammo[0]
	var health_before: float = a.health.current
	w.prediction.preview_fire({"seq":99,"aim":Vector3.FORWARD,"fire":true})
	check(w.effects.active>0 and w.prediction.visual_shots.size()==1,"a guest gets immediate shot feedback without waiting for a host packet")
	check(a.weapons.ammo[0]==ammo_before and a.health.current==health_before,"predicted shot feedback cannot mutate inventory or combat health")
	var effects_before: int = w.effects.active
	w.network._shot_visual(a.position,a.position+Vector3.FORWARD,Color.WHITE,1)
	check(w.effects.active==effects_before,"own authoritative shot feedback does not play a second tracer")
	w.prediction.reset(); check(w.prediction.history.is_empty() and not w.prediction.ready,"sector/checkpoint reset discards stale prediction history")
	var node := Node3D.new(); w.add_child(node)
	SnapshotTrack.push(node,Vector3.ZERO,1); SnapshotTrack.push(node,Vector3(10,0,0),1.1)
	check(is_equal_approx(SnapshotTrack.position_at(node,1.15).x,5),"remote interpolation samples 100 ms behind instead of snapping to a packet")
	check(SnapshotTrack.position_at(node,3).x<=10,"interpolation holds the last confirmed point during a packet gap")
	w.is_client = false; w.queue_free(); await create_timer(.25).timeout; MobilePlatform.force_touch = false
	print("MOBILE EXPERIENCE RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
