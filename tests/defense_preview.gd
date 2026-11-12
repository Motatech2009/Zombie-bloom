extends SceneTree
# Visual QA fixture; excluded from exported builds.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = "endless"
	var world: Node3D = load("res://scenes/campaign/CampaignWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.player.position = Vector3(6,0,9)
	world.camera.position = world.player.position*.82+world.camera_offset
	world.resources.scrap = 5000
	world.stock = {"wood":100,"parts":100}
	world.grenades = 9
	world.rockets = 12
	world.player.weapons.owned.assign([true,true,true,true,true])
	world.player.weapons.ammo[4] = 1
	world.phase = "combat"
	world.waves.wave = 6
	for i in range(9):
		var enemy: Node3D = world.make_enemy(i,Vector3((i%3)*6,0,(i/3)*5-13),false,i)
		enemy.set_physics_process(false)
		var label := VisualFactory.health_label(enemy,3.2 if i==8 else 2.4)
		label.text = enemy.spec.title
		label.font_size = 20
