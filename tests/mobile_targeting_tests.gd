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
func touch(controls: TouchControls,id: int,point: Vector2,pressed: bool = true) -> void:
	var event := InputEventScreenTouch.new(); event.index = id; event.position = point; event.pressed = pressed
	controls._input(event)
func tap_enemy(controls: TouchControls,enemy: Node3D) -> void:
	if controls.fingers.has(9): touch(controls,9,Vector2.ZERO,false)
	var screen: Vector2 = controls.world.camera.unproject_position(MobileTargeting.point(enemy))
	touch(controls,7,screen); touch(controls,7,screen,false)
func run() -> void:
	MobilePlatform.force_touch = true
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false); world.set_process(false)
	var actor: Node3D = world.player
	actor.position = Vector3(0,0,10); actor.set_physics_process(false)
	world.camera.position = actor.position+world.camera_offset; world.camera.look_at(actor.position)
	var controls: TouchControls = world.touch_controls
	var enemy: Node3D = world.make_enemy(0,Vector3(0,0,4),false,1)
	enemy.set_physics_process(false); enemy.health.setup(1000)
	await frames()
	tap_enemy(controls,enemy)
	check(controls.locked_target==enemy and not controls.frame().fire,"a tap selects a zombie without firing or wasting ammunition")
	check(controls.fingers.is_empty(),"releasing the targeting tap leaves the lock active without a stuck finger")
	touch(controls,9,controls.buttons.fire.get_center())
	touch(controls,0,controls.stick_center("move"))
	var motion := InputEventScreenDrag.new(); motion.index = 0; motion.position = controls.stick_center("move")+Vector2(72,0); controls._input(motion)
	check(controls.frame().move.x>.9 and controls.frame().fire,"a separate movement finger preserves the selected target")
	touch(controls,0,Vector2.ZERO,false)
	enemy.position = Vector3(4,0,4); await frames()
	check(controls.frame().aim.dot(MobileTargeting.direction(actor,enemy))>.999,"locked aim follows a moving target instead of its original ground location")
	var before: int = actor.weapons.ammo[0]
	actor.weapons.cooldown = 0; actor._physics_process(.016)
	check(actor.weapons.ammo[0]==before-1 and enemy.health.current<1000,"a targeted input actually spends one round and damages the selected zombie")
	var request: Dictionary = controls.frame()
	var wall := StaticBody3D.new(); wall.collision_layer = 8
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(4,4,1)
	shape.shape = box; wall.add_child(shape); world.add_child(wall); wall.position = (actor.position+enemy.position)*.5+Vector3.UP
	await create_timer(.15).timeout
	check(not controls.frame().fire and controls.locked_target==enemy,"cover suspends fire while keeping the selected target")
	before = actor.weapons.ammo[0]; actor.weapons.cooldown = 0; actor._physics_process(.016)
	check(actor.weapons.ammo[0]==before,"holding a blocked target cannot spend ammunition")
	request.fire = true; actor.weapons.cooldown = 0
	check(not MobileTargeting.resolve(world,actor,request.duplicate(true)).fire,"host independently rejects a stale fire request through cover")
	wall.queue_free(); await create_timer(.15).timeout
	check(controls.frame().fire,"fire resumes when the existing target becomes unobstructed")
	var near: Vector3 = enemy.position
	enemy.position = actor.position+Vector3(0,0,-30); await frames()
	request.fire = true
	check(not MobileTargeting.resolve(world,actor,request.duplicate(true)).fire,"host rejects a target beyond the equipped weapon's range")
	enemy.position = near; await frames(); tap_enemy(controls,enemy); touch(controls,9,controls.buttons.fire.get_center())
	request = controls.frame(); request.target.rev += 1
	check(not MobileTargeting.resolve(world,actor,request).fire,"a target from another scene revision cannot trigger a shot")
	request = controls.frame(); request.fire = false
	check(not MobileTargeting.resolve(world,actor,request).fire,"host never converts a released fire request into an automatic shot")
	tap_enemy(controls,enemy); touch(controls,9,controls.buttons.fire.get_center())
	request = controls.frame(); request.target.id = 999999
	check(not MobileTargeting.resolve(world,actor,request).fire,"a missing network target fails closed instead of shooting into empty space")
	request = controls.frame(); enemy.health.current = 0; enemy.health.dead = true
	check(not MobileTargeting.resolve(world,actor,request).fire and not controls.frame().fire and controls.locked_target==null,"target death stops local fire and stale remote fire before another round is consumed")
	touch(controls,9,Vector2.ZERO,false)
	enemy.health.setup(1000); tap_enemy(controls,enemy)
	touch(controls,8,Vector2(480,230)); touch(controls,8,Vector2.ZERO,false)
	check(controls.locked_target==null and not controls.frame().fire,"tapping empty ground cancels target lock")
	tap_enemy(controls,enemy)
	touch(controls,8,controls.buttons.fire.get_center())
	check(controls.locked_target==enemy and controls.fire_held and controls.frame().fire,"the assisted fire button preserves an explicitly tapped target")
	touch(controls,8,Vector2.ZERO,false)
	check(not controls.frame().fire,"releasing the fire button stops shooting while keeping a selected target")
	actor.position = Vector3(0,0,3); actor.bag.add("wood",1); controls._process(.2)
	tap_enemy(controls,enemy); touch(controls,8,controls.buttons.interact.get_center())
	check(controls.locked_target==null and controls.frame().interact and not controls.frame().fire,"starting collection cancels automatic combat input")
	controls.reset_fingers(); tap_enemy(controls,enemy)
	world.hud.show_inventory(); world.hud.close_modal()
	check(controls.locked_target==null,"opening a panel clears target lock so closing it cannot resume surprise fire")
	tap_enemy(controls,enemy); controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(controls.locked_target==null and not controls.frame().fire,"backgrounding the app clears target lock")
	tap_enemy(controls,enemy)
	var cancel := InputEventScreenTouch.new(); cancel.index = 0; cancel.canceled = true
	controls._input(cancel)
	check(controls.locked_target==null and not controls.frame().fire,"an operating-system touch cancellation also clears automatic fire")
	tap_enemy(controls,enemy); world.select_hotbar(1)
	check(not controls.frame().fire and controls.locked_target==null,"changing hotbar item cancels the previous weapon's lock")
	tap_enemy(controls,enemy)
	check(controls.locked_target==null,"grenades never auto-throw from a zombie targeting tap")
	world.select_hotbar(3); tap_enemy(controls,enemy)
	check(controls.locked_target==null,"medkits never auto-use from a zombie targeting tap")
	world.select_hotbar(0); tap_enemy(controls,enemy); world.scene_revision += 1
	check(not controls.frame().fire and controls.locked_target==null,"sector changes discard the old target")
	tap_enemy(controls,enemy); world.builder.set_active(true)
	check(not controls.frame().fire and controls.locked_target==null,"construction mode cancels combat targeting")
	world.builder.set_active(false); controls.layout_controls()
	tap_enemy(controls,enemy); enemy.queue_free(); await frames()
	check(not controls.frame().fire and controls.locked_target==null,"freed target references are safely discarded")
	var flyer: Node3D = world.make_enemy(7,Vector3(3,0,4),false,2)
	flyer.set_physics_process(false); flyer.health.setup(1000)
	await frames(); tap_enemy(controls,flyer)
	touch(controls,9,controls.buttons.fire.get_center())
	before = actor.weapons.ammo[0]; actor.weapons.cooldown = 0; actor._physics_process(.016)
	check(controls.locked_target==flyer and flyer.health.current<1000 and actor.weapons.ammo[0]==before-1,"targeted fire reaches an airborne zombie at its real height")
	flyer.queue_free(); await frames()
	var dog: Node3D = world.make_enemy(6,Vector3(3,0,4),false,3)
	dog.set_physics_process(false); dog.health.setup(1000)
	await frames(); tap_enemy(controls,dog)
	touch(controls,9,controls.buttons.fire.get_center())
	actor.weapons.cooldown = 0; actor._physics_process(.016)
	check(dog.health.current<1000,"targeted fire reaches a low-profile zombie dog")
	controls.reset_fingers(); actor.bag.add("launcher",1)
	var launcher_slot := -1
	for i in range(9):
		if actor.bag.slots[i].id=="launcher": launcher_slot = i
	world.select_hotbar(launcher_slot); actor.weapons.ammo[4] = 1
	tap_enemy(controls,dog); touch(controls,9,controls.buttons.fire.get_center()); actor.weapons.cooldown = 0; actor._physics_process(.016)
	check(actor.weapons.ammo[4]==0 and not controls.frame().fire and controls.locked_target==null,"a launcher tap fires once and clears its lock before reload or another rocket")
	world.select_hotbar(0); tap_enemy(controls,dog); actor.health.dead = true
	check(not controls.frame().fire and controls.locked_target==null,"a downed player cannot keep a live target lock")
	actor.health.dead = false; tap_enemy(controls,dog); dog.position = actor.position+Vector3(200,0,0)
	check(not controls.frame().fire and controls.locked_target==null,"a target leaving the screen cancels automatic fire")
	controls.reset_fingers()
	var hud_point: Vector2 = world.hud.hotbar[0].get_global_rect().get_center()
	touch(controls,9,hud_point)
	check(not controls.fingers.has(9) and controls.locked_target==null,"hotbar touches remain GUI input and never select world targets underneath")
	world.queue_free(); await create_timer(.2).timeout
	MobilePlatform.force_touch = false
	print("TARGETING RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
