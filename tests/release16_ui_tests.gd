extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else: failures += 1; push_error("FAIL: "+text)
func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i(960,540) if MobilePlatform.enabled() else Vector2i(1440,900)
	root.size = root.content_scale_size
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	w.waves.wave = 1; w.upgrades.award_horde(1); w.upgrades.roll()
	w.hud.show_upgrade()
	await create_timer(.15).timeout
	check(w.hud.mode=="upgrade","individual card modal opens")
	var buttons: Array = w.hud.modal.find_children("*","Button",true,false)
	var picks: Array = buttons.filter(func(b): return b.text.begins_with("ESCOLHER ") and b.text!="ESCOLHER DEPOIS")
	check(picks.size()==3,"three distinct selectable card buttons")
	var later: Array = buttons.filter(func(b): return b.text=="ESCOLHER DEPOIS")
	check(later.size()==1,"explicit postpone action is available")
	var labels: Array = w.hud.modal.find_children("*","Label",true,false)
	check(labels.any(func(l): return l.text=="SUA EVOLUÇÃO"),"heading identifies personal upgrade")
	check(labels.filter(func(l): return l.text.contains("NÍVEL 0 → 1 / 2")).size()==3,"all cards show current, next and cap")
	if MobilePlatform.enabled():
		var scrolls: Array = w.hud.modal.find_children("*","ScrollContainer",true,false)
		check(scrolls.size()==1 and scrolls[0].horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"mobile cards scroll vertically without compulsory horizontal scroll")
		check(scrolls[0].get_global_rect().size.y>200,"mobile safe card viewport keeps useful height")
	else:
		var viewport := Rect2(Vector2.ZERO,Vector2(root.content_scale_size))
		for button in picks+later:
			check(viewport.encloses(button.get_global_rect()),"desktop action stays inside the viewport: "+button.text)
	check(picks.all(func(b): return b.size.y>=40),"card selection buttons preserve useful touch height")
	later[0].pressed.emit()
	check(w.upgrades.state(w.player).deferred and not w.combat_paused(),"postponing dismisses the blocking choice without losing it")
	w.hud.request_upgrade()
	check(w.hud.mode.is_empty(),"deferred choice does not reopen automatically")
	w.hud.show_systems15()
	var resume: Array = w.hud.modal.find_children("*","Button",true,false).filter(func(b): return b.text.begins_with("SUAS EVOLUÇÕES PENDENTES"))
	check(resume.size()==1,"base panel exposes deferred choices")
	resume[0].pressed.emit()
	check(w.hud.mode=="upgrade","deferred choice can be reopened deliberately")
	w.hud.close_modal(); w.queue_free(); await create_timer(.35).timeout
	print("RELEASE16 UI RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
