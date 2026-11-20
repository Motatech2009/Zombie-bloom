extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)

func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	Director15.selected_class = "medic"
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	w.checkpoint_enabled = false
	root.add_child(w)
	current_scene = w
	w.waves.set_physics_process(false)
	w.player.set_physics_process(false)
	var actor: Node3D = w.player
	var fx_nodes: int = w.effects.get_child_count()
	for i in range(20): w.effects.burst(actor.position,Color("e79a65"),12)
	check(w.effects.get_child_count()==fx_nodes and w.effects.active<=fx_nodes,"attack bursts reuse a fixed set of meshes")
	var med_slot := 3
	actor.bag.add("medkit",5)
	check(actor.specialization=="medic" and actor.bag.slots[med_slot].qty==6,"Médico starts with room for six kits in one slot")
	var legacy := ItemBag.new()
	legacy.add("medkit",6)
	check(legacy.slots[0].qty==3 and legacy.slots[1].qty==3,"other classes retain the usual stack limit")
	check(w.valid_profile(w.actor_profile(actor)),"medic inventory and cooldown belong to a valid saved profile")
	w.attach_peer(2,"2".repeat(32),"Aliado")
	var ally: Node3D = w.avatars[2]
	ally.set_physics_process(false)
	actor.position = Vector3(10,0,10)
	ally.position = actor.position+Vector3.RIGHT*2
	ally.health.current = 22
	await physics_frame
	check(w.local_heal_available(),"injured living partner exposes the contextual healing action")
	if MobilePlatform.enabled():
		w.touch_controls.context = w.local_mobile_context()
		w.touch_controls.layout_controls()
		check(w.touch_controls.buttons.has("heal"),"touch HUD renders its CURAR action")
		w.touch_controls.trigger("heal")
	else:
		w.hud._process(.15)
		check(w.hud.heal_action.visible,"desktop HUD renders its clickable healing action")
		w.hud.heal_action.pressed.emit()
	check(actor.gather_kind=="heal" and actor.gather_duration==4,"one press starts a four-second channel")
	w.tick_gather(actor,3.99)
	check(ally.health.current==22 and actor.bag.count("medkit")==6,"there is no early HP gain or kit consumption")
	w.tick_gather(actor,.02)
	check(ally.health.current==72 and actor.bag.count("medkit")==5 and actor.heal_cooldown==30,"completed treatment restores 50 HP and spends one kit")
	check(not w.perform_action(1,"heal",{}),"second treatment is blocked by the cooldown")
	actor.heal_cooldown = 0
	check(w.perform_action(1,"heal",{}),"next treatment can start after the cooldown")
	ally.position += Vector3.RIGHT * 4
	w.tick_gather(actor,4)
	check(actor.gather_kind.is_empty() and actor.bag.count("medkit")==5 and ally.health.current==72,"moving out of reach cancels without spending a kit")

	var link: Node = root.get_node("Coop")
	link.mode = "host"
	actor.position = SectorGenerator.EXITS[0]
	ally.position = SectorGenerator.EXITS[0]+Vector3.RIGHT
	check(w.regions.travel(actor,0) and w.regions.travel(ally,0),"both players enter the same co-op sector")
	var coord := Vector2i(0,-1)
	actor.position = w.sector_offset(coord)+SectorGenerator.EXITS[2]
	actor.region_travel_left = 0
	check(w.regions.travel(actor,2) and w.sector_remaining(coord)==-1,"one player leaves while ally keeps the sector active")
	ally.position = w.sector_offset(coord)+SectorGenerator.EXITS[2]
	ally.region_travel_left = 0
	check(w.regions.travel(ally,2) and w.sector_remaining(coord)==300,"the last player's exit starts the co-op countdown")
	link.mode = "offline"

	w.detach_peer(2)
	await process_frame
	w.queue_free()
	await process_frame
	await process_frame
	print("RELEASE178 RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
