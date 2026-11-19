extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + title)

func valid_core(world: Node3D, visual: MeshInstance3D, tier: int) -> bool:
	return world.core.model.get_child_count() == 1 and world.core_visual == visual and visual.is_visible_in_tree() \
		and visual.mesh == world.CORE_MESHES[tier - 1] and visual.get_aabb().size.y > 2.0 \
		and visual.get_surface_override_material(0).albedo_texture != null

func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	var campaign := load("res://scripts/campaign/campaign_world.gd")
	campaign.next_mode = "endless"
	campaign.resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.player.set_physics_process(false)
	world.waves.set_physics_process(false)
	world.player.position = Vector3(0, 0, 3)
	world.resources.scrap = 3000
	world.stock = {"wood": 1000, "parts": 1000}
	var visual: MeshInstance3D = world.core_visual
	var original: Dictionary = world.snapshot()
	check(valid_core(world, visual, 1), "the arena begins with a single correctly textured visible core")
	for tier in range(2, 5):
		check(world.improve_nearby(), "upgrade channel starts for tier %d" % tier)
		world.channel15.tick(4.0)
		await process_frame
		check(world.core_tier == tier and valid_core(world, visual, tier), "tier %d renders without replacing the core instance" % tier)
	var saved: Dictionary = world.snapshot()
	var packet: Dictionary = world.net_state(1, true)
	world.apply_snapshot(original)
	check(valid_core(world, visual, 1), "restoring an earlier checkpoint changes the same mesh synchronously")
	world.apply_snapshot(saved)
	check(valid_core(world, visual, 4), "the upgraded checkpoint restores its tier without an invisible frame")
	world.apply_snapshot(original)
	world.is_client = true
	world.last_scene_revision = int(packet.rev)
	world.apply_net_state(packet, 1)
	check(valid_core(world, visual, 4), "a cooperative snapshot updates a visible core in place")
	world.is_client = false

	for cue in GameAudio.Cue.values():
		var effect := GameAudio.synthesize(cue)
		var pcm := effect.data
		var peak := 0
		for frame in range(0, pcm.size(), 2):
			peak = maxi(peak, absi(pcm.decode_s16(frame)))
		check(effect.mix_rate == 22050 and effect.get_length() <= 2.4 and peak > 512 and peak < 23001,
			"cue %d has short audible samples below the clipping threshold" % cue)
		check(pcm.decode_s16(0) == 0 and pcm.decode_s16(pcm.size() - 2) == 0, "cue %d has click-free boundaries" % cue)
	check(GameAudio.synthesize(GameAudio.Cue.HOWL, 0).data != GameAudio.synthesize(GameAudio.Cue.HOWL, 1).data,
		"the two howl variants use distinct waveforms")
	world.queue_free()
	await process_frame
	await process_frame
	print("CORE171 RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
