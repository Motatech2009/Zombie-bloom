extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world)
	current_scene = world
	world.waves.set_physics_process(false)
	world.waves.wave = 9
	world.horde_left = 210
	world.player.position = Vector3(0,0,9)
	for i in range(6):
		var enemy: Node3D = world.make_enemy([0,6,7,9,10,11][i],Vector3(-9+i*3,0,0),false,i)
		enemy.set_physics_process(false)
		enemy.health.current *= .55
	var boss: Node3D = world.make_enemy(8,Vector3(0,0,-5),false,10)
	boss.set_physics_process(false)
	boss.health.current *= .7
	world.spawn_loot(world.player.position+Vector3(1,0,0),{"wood":12,"scrap":24})
