extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = "campaign"
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false)
	world.waves.wave = 12; world.horde_left = 152
	world.player.position = Vector3(0,0,10)
	world.player.bag = ItemBag.new()
	for id in ItemBag.WEAPON_IDS: world.player.bag.add(id,1)
	for id in ["light","shell","rifle_ammo","heavy","cells","rocket"]: world.player.bag.add(id,3 if id=="rocket" else 12)
	world.player.bag.add("grenade",2); world.player.bag.add("medkit",1)
	world.player.bag.selected = 8
	world.player.weapons.sync_hand()
	world.player.weapons.ammo[8] = 12
	for i in range(6):
		var enemy: Node3D = world.make_enemy([9,10,11,12,13,14][i],Vector3(-12+i*4,0,0),false,i)
		enemy.set_physics_process(false)
		enemy.health.current *= .7
	for i in range(5): world.spawn_loot(Vector3(-8+i*4,0,15),{["wood","parts","grenade","medkit","cells"][i]:2})
