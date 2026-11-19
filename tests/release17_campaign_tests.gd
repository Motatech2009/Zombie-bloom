extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(result: bool, message: String) -> void:
	checks += 1
	if not result:
		failures += 1
		push_error("FAIL: " + message)

func has_text(node: Node, snippet: String) -> bool:
	for text in node.find_children("*", "Label", true, false):
		if text.text.contains(snippet):
			return true
	return false

func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	var campaign := load("res://scripts/campaign/campaign_world.gd")
	var survival := load("res://scripts/survival/survival_world.gd")
	campaign.next_mode = "campaign"
	campaign.resume_requested = false
	survival.opening_story_requested = true
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.waves.set_physics_process(false)
	world.player.set_physics_process(false)
	await process_frame
	check(world.hud.mode == "story17" and has_text(world.hud.modal, "Caio Vale") and paused,
		"a newly started solo campaign opens a skippable prologue")
	check(not has_text(world.hud.modal, "Recepção confirmada"), "the prologue does not spoil the ending")
	world.hud.close_modal()
	check(not paused and world.hud.mode.is_empty() and world.waves.wave == 0, "closing the journal starts play at the original wave")
	for n in [5, 10, 15]:
		world.waves.wave = n
		world.waves.running = true
		world.hud.show_story17()
		check(not has_text(world.hud.modal, CampaignStory17.new_title(n)), "the journal waits for the current siege to be defeated")
		world.hud.close_modal()
		world.waves.complete()
		check(world.notice.contains("DIÁRIO ATUALIZADO"), "surviving the siege announces the next page")
		world.hud.show_pause()
		var found := false
		for button in world.hud.modal.find_children("*", "Button", true, false):
			if button.text == "DIÁRIO DA CAMPANHA":
				button.pressed.emit()
				found = true
				break
		check(found and has_text(world.hud.modal, CampaignStory17.new_title(n)), "the new page opens from the pause menu")
		world.hud.close_modal()
	world.waves.wave = 20
	world.waves.running = true
	world.waves.complete()
	check(world.won and world.phase == "ended" and has_text(world.hud.modal, "Recepção confirmada"), "the twentieth siege awards the campaign epilogue")
	paused = false
	world.queue_free()
	await process_frame
	await process_frame
	print("RELEASE17 CAMPAIGN RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
