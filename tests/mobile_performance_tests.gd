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
func run() -> void:
	MobilePlatform.force_touch = true
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false); world.set_process(false)
	var actor: Node3D = world.player; actor.position = Vector3(0,0,10); actor.invulnerable = 3600; actor.set_physics_process(false)
	world.camera.position = actor.position+world.camera_offset; world.camera.look_at(actor.position)
	var controls: TouchControls = world.touch_controls
	await frames()
	check(MobilePlatform.lightweight() and is_equal_approx(root.scaling_3d_scale,.85),"mobile defaults to reduced 3D resolution while keeping the 960x540 UI")
	check(not world.sunlight.shadow_enabled,"lightweight mode disables realtime shadows")
	GameSettings.mobile_performance = false
	world.apply_mobile_quality()
	check(not MobilePlatform.lightweight() and is_equal_approx(root.scaling_3d_scale,1.0),"switching to detailed restores full resolution immediately")
	GameSettings.mobile_performance = true; world.apply_mobile_quality()
	var material := ClayStyle.material(Color("3c695f"))
	check(not material.normal_enabled and not material.uv1_triplanar,"mobile clay avoids normal-map and triplanar texture samples")
	var near: Node3D = world.make_enemy(0,Vector3(4,0,4),false,1); near.set_physics_process(false); near.health.setup(1000)
	var far: Node3D = world.make_enemy(0,Vector3(-4,0,2),false,2); far.set_physics_process(false); far.health.setup(1000)
	await frames()
	check(near.rig.find_children("*","MeshInstance3D",true,false).size()==5,"a humanoid uses five batches while preserving its animated limbs")
	check(near.rig.get_node("MobileBatch").mesh==far.rig.get_node("MobileBatch").mesh,"equal infected reuse the same baked body mesh")
	check(near.rig.get_node("ArmR").has_node("MobileBatch") and near.rig.get_node("LegL").has_node("MobileBatch"),"arms and legs remain independently animated after batching")
	check(world.hud.root.find_children("*","ProgressBar",true,false).size()<20,"infected do not create per-enemy health-bar Controls on mobile")
	check(controls.buttons.fire.size.x>=110 and not controls.buttons.fire.intersects(controls.buttons.get("interact",Rect2())),"compact fire retains a large hit area without overlapping context controls")
	touch(controls,1,controls.buttons.fire.get_center())
	check(controls.fire_held and controls.locked_target==near and controls.frame().fire,"holding fire assists toward the nearest visible reachable zombie")
	touch(controls,0,controls.stick_center("move"))
	var move_event := InputEventScreenDrag.new(); move_event.index = 0; move_event.position = controls.stick_center("move")+Vector2(72,0); controls._input(move_event)
	check(controls.frame().move.x>.9 and controls.frame().fire,"movement and assisted fire use independent fingers")
	var before: int = actor.weapons.ammo[0]; actor.weapons.cooldown = 0; actor._physics_process(.016)
	check(actor.weapons.ammo[0]==before-1 and near.health.current<1000,"assisted fire produces an authoritative damaging shot with normal ammo cost")
	var request: Dictionary = controls.frame()
	var rays := MobileTargeting.ray_checks
	for i in range(100): controls.frame(); MobileTargeting.resolve(world,actor,request)
	check(MobileTargeting.ray_checks==rays,"repeated input polling and weapon cooldown do not repeat cover raycasts")
	near.health.current = 0; near.health.dead = true; controls._process(.2)
	check(controls.locked_target==far and controls.frame().fire,"while held, fire acquires another live target after a kill")
	touch(controls,1,Vector2.ZERO,false)
	check(not controls.frame().fire and controls.frame().move.x>.9,"releasing fire stops attack while keeping movement")
	controls.reset_fingers(); near.queue_free(); far.queue_free(); await frames()
	before = actor.weapons.ammo[0]; touch(controls,1,controls.buttons.fire.get_center()); actor.weapons.cooldown = 0; actor._physics_process(.016)
	check(controls.locked_target==null and actor.weapons.ammo[0]==before,"holding fire without a live target cannot waste ammunition")
	var enemy: Node3D = world.make_enemy(0,Vector3(4,0,4),false,3); enemy.set_physics_process(false); enemy.health.setup(1000)
	await frames(); controls._process(.2)
	check(controls.locked_target==enemy,"a held fire button can acquire an enemy that arrives later")
	var drag := InputEventScreenDrag.new(); drag.index = 1; drag.position = Vector2(450,200); controls._input(drag)
	check(not controls.fire_held and not controls.frame().fire,"dragging a firing finger away cancels it instead of sticking")
	for i in range(20):
		var extra: Node3D = world.make_enemy(i%15,Vector3((i%8-3)*1.2,0,(i/8)*2),false,10+i)
		extra.set_physics_process(false); extra.health.current *= .5
	await frames(8)
	var bars: Array = world.hud.root.get_children().filter(func(node): return node is MobileEnemyBars)
	check(bars.size()==1 and bars[0].rows.size()<=12,"one batched canvas bounds visible health indicators in a dense crowd")
	var node_count: int = world.effects.get_child_count()
	for i in range(100): world.effects.tracer(Vector3(2,1,3),Vector3(5,1,3)); world.effects.burst(Vector3(4,0,4),Color.RED,20)
	check(world.effects.active<=20 and world.effects.get_child_count()==node_count,"one hundred effect bursts reuse the bounded pool without adding nodes")
	await create_timer(.4).timeout
	check(world.effects.active==0 and world.effects.pool.size()==20,"expired effect slots return to the same fixed pool")
	controls.reset_fingers(); actor.health.current = 40
	world.select_hotbar(3); var kits: int = actor.bag.count("medkit"); actor.weapons.cooldown = 0
	touch(controls,2,controls.buttons.fire.get_center()); await create_timer(.2).timeout
	check(actor.bag.count("medkit")==kits-1 and actor.health.current>40 and not controls.frame().fire,"the same button uses one selected medkit instead of holding item use")
	touch(controls,2,Vector2.ZERO,false); actor.bag.add("grenade",2); world.select_hotbar(2); actor.weapons.cooldown = 0
	world.phase = "combat"
	controls.select_target(Vector2(650,240)); var grenades: int = actor.bag.count("grenade")
	touch(controls,2,controls.buttons.fire.get_center()); await create_timer(1.5).timeout
	check(actor.bag.count("grenade")==grenades-1,"holding the grenade button launches only once per press")
	touch(controls,2,Vector2.ZERO,false)
	check(not world.perform_action(1,"consume",{"slot":0,"aim":Vector3.RIGHT}),"the consumable command cannot fire a gun or bypass normal shooting")
	var uid: int = enemy.net_id; enemy.queue_free(); await frames()
	check(world.target_enemy(uid)==null,"removing an infected also removes its authoritative target index")
	await create_timer(.5).timeout
	check(world.hud.performance_text.text.contains("FPS"),"mobile HUD exposes a readable on-device FPS counter")
	world.queue_free(); await create_timer(.2).timeout
	MobilePlatform.force_touch = false
	print("MOBILE PERFORMANCE RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
