extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	MobilePlatform.force_touch = true
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false)
	world.resources.scrap = 1000; world.stock = {"wood":100,"parts":100}
	world.player.position = Vector3(0,0,8)
	world.player.invulnerable = 3600
	world.notice_left = 0
	if "--target" in OS.get_cmdline_user_args():
		var enemy: Node3D = world.make_enemy(0,Vector3(5,0,5),false,1)
		enemy.set_physics_process(false); enemy.health.setup(100000)
	if "--inventory" in OS.get_cmdline_user_args(): world.hud.show_inventory()
	if "--catalog" in OS.get_cmdline_user_args(): world.hud.show_build_catalog()
