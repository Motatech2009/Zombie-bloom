extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	MobilePlatform.force_touch = "--mobile" in args
	root.content_scale_size = Vector2i(960,540) if MobilePlatform.enabled() else Vector2i(1440,900)
	var scene: Node
	if "--shop" in args:
		scene = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); scene.checkpoint_enabled = false
		root.add_child(scene); current_scene = scene
		scene.waves.set_physics_process(false); scene.resources.scrap = 1000; scene.player.position = scene.vendor_pos+Vector3(0,0,2)
		scene.hud.show_shop()
	else:
		scene = load("res://scenes/main/MainMenu.tscn").instantiate(); root.add_child(scene); current_scene = scene
		if "--account" in args: scene.show_account()
		if "--ranks" in args: scene.show_rankings()
	GameSettings.fullscreen = false; root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648) if MobilePlatform.enabled() else Vector2i(1280,800)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var file := "mobile" if MobilePlatform.enabled() else "desktop"
	if "--shop" in args: file += "-shop"
	if "--account" in args: file += "-account"
	if "--ranks" in args: file += "-ranks"
	var error := root.get_texture().get_image().save_png("res://builds/"+file+"-1.0.png")
	print("PREVIEW: ",file," error=",error)
	scene.queue_free()
	await create_timer(.3).timeout
	quit()
