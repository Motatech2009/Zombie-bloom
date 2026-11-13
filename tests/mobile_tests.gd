extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func touch(controls: TouchControls,id: int,point: Vector2,pressed: bool = true) -> void:
	var event := InputEventScreenTouch.new(); event.index = id; event.position = point; event.pressed = pressed
	controls._input(event)
func drag(controls: TouchControls,id: int,point: Vector2) -> void:
	var event := InputEventScreenDrag.new(); event.index = id; event.position = point
	controls._input(event)
func frames(n: int = 3) -> void:
	for i in range(n): await physics_frame; await process_frame
func run() -> void:
	MobilePlatform.force_touch = true
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false); world.set_process(false)
	await frames()
	var controls: TouchControls = world.touch_controls
	check(controls!=null and root.content_scale_size==Vector2i(960,540),"mobile world creates a fixed landscape touch interface")
	check(world.hud.hotbar.filter(func(button): return button.visible).size()==5,"first mobile hotbar page shows five large slots")
	world.hud.page = 1; world.hud.update_page()
	check(world.hud.hotbar[8].visible and not world.hud.hotbar[0].visible,"second hotbar page keeps all nine slots reachable")
	world.hud.page = 0; world.hud.update_page()
	var actor: CharacterBody3D = world.player
	actor.position = Vector3(0,0,10)
	var enemy: Node3D = world.make_enemy(0,Vector3(4,0,4),false,1)
	enemy.set_physics_process(false); enemy.health.setup(1000)
	await frames()
	touch(controls,0,controls.stick_center("move")+Vector2(65,0))
	touch(controls,1,controls.buttons.fire.get_center())
	var frame: Dictionary = world.local_input(actor)
	check(frame.move.x>.8 and frame.fire and frame.aim.is_finite(),"two independent fingers move and hold assisted fire simultaneously")
	var start: Vector3 = actor.position
	await create_timer(.18).timeout
	check(actor.position.distance_to(start)>.5,"touch movement drives the authoritative character through actual physics")
	touch(controls,1,Vector2.ZERO,false)
	check(not world.local_input(actor).fire and world.local_input(actor).move.x>.8,"releasing fire stops shots without releasing movement")
	drag(controls,0,controls.stick_center("move"))
	check(world.local_input(actor).move==Vector2.ZERO,"movement stick has a real center dead zone")
	touch(controls,0,Vector2.ZERO,false)
	enemy.queue_free(); await frames()
	var roll_point: Vector2 = controls.buttons.roll.get_center()
	touch(controls,2,roll_point)
	check(actor.roll_left>0 and actor.roll_cooldown>4.9,"touch roll uses the same authoritative five-second cooldown")
	touch(controls,2,Vector2.ZERO,false)
	actor.stop_roll(); actor.roll_cooldown = 0
	touch(controls,3,controls.buttons.reload.get_center())
	check(world.local_input(actor).reload,"reload remains held while its own finger is down")
	controls.reset_fingers()
	check(not world.local_input(actor).reload and controls.fingers.is_empty(),"clearing touch state prevents stuck actions")
	world.hud.show_inventory(); await frames()
	check(world.hud.inventory_buttons.size()==18 and world.hud.inventory_buttons[0].get_parent().columns==6,"mobile inventory exposes eighteen slots in six columns")
	touch(controls,0,controls.stick_center("move")+Vector2(70,0))
	check(world.local_input(actor).move==Vector2.ZERO and not world.local_input(actor).fire,"modal panels cannot drive movement or fire underneath")
	world.hud.close_modal()
	world.hud.show_build_catalog(); await frames()
	check(world.hud.mode=="catalog" and world.hud.find_grids(world.hud.overlay_box)[0].columns==2,"mobile construction catalog uses two touch-friendly columns")
	world.hud.close_modal()
	actor.position = Vector3(0,0,8); actor.set_physics_process(false)
	world.resources.scrap = 1000; world.stock = {"wood":100,"parts":100}
	world.builder.selected = 0; world.builder.set_active(true)
	controls.build_target = Vector3(0,0,12)
	world.builder._physics_process(.1); controls.layout_controls()
	check(world.builder.location==controls.build_target and controls.buttons.has("place"),"construction preview follows the touch target instead of the mouse")
	controls.trigger("rotate")
	check(is_equal_approx(world.builder.angle,PI/2),"touch rotate turns the preview by ninety degrees")
	var quota: int = world.built_this_round
	controls.trigger("place")
	check(world.built_this_round==quota+1,"touch placement goes through normal quota, collision and payment validation")
	controls.trigger("cancel"); controls.layout_controls()
	check(not world.builder.active and not controls.buttons.has("place"),"touch cancel restores the combat controls")
	actor.position = Vector3(0,0,3); actor.bag.add("wood",5)
	var bank_before: int = world.stock.wood
	actor.set_physics_process(true)
	touch(controls,5,controls.buttons.interact.get_center())
	check(world.local_input(actor).interact,"collect button holds interaction through its own finger")
	await create_timer(2.0).timeout
	check(actor.bag.count("wood")==0 and world.stock.wood==bank_before+5,"holding touch collect deposits carried materials after the real gather duration")
	touch(controls,5,Vector2.ZERO,false)
	check(not world.local_input(actor).interact,"releasing collect ends the held interaction")
	world.hud.show_routes(); await frames()
	check(world.hud.mode=="routes" and not paused,"mobile map preserves the live horde clock")
	world.hud.close_modal()
	world.hud.show_actions(); await frames()
	check(world.hud.mode=="actions","secondary actions have a touch-accessible menu")
	world._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(world.hud.mode.is_empty(),"Android Back closes a panel before leaving the world")
	touch(controls,4,controls.stick_center("move")+Vector2(70,0))
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(controls.move_vector==Vector2.ZERO and not controls.interact_held,"focus loss releases every held finger action")
	world.resources.pending = 1; world.upgrades.roll(); world.hud.show_upgrade()
	check(world.hud.mode=="upgrade","mobile player can review a pending team upgrade")
	world.resources.pending = 0; world.upgrades.offers.clear(); world.hud._process(0)
	check(world.hud.mode.is_empty(),"a team upgrade resolved elsewhere closes stale choice panels")
	var stale: Dictionary = world.net_state(1)
	world.is_client = true; world.last_scene_revision = world.scene_revision
	world.select_hotbar(8); world.apply_net_state(stale,1)
	check(world.player.bag.selected==8 and world.local_input(world.player).slot==8,"late snapshots cannot undo a newly tapped hotbar selection")
	stale.profile.bag.selected = 8; world.apply_net_state(stale,1)
	check(world.pending_slot==-1,"acknowledged selection clears its pending state")
	world.is_client = false
	world.queue_free(); await create_timer(.2).timeout
	MobilePlatform.force_touch = false
	print("MOBILE RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
