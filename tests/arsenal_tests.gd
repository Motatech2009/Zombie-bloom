extends SceneTree
var checks := 0
var failures := 0
var world: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func frames(count: int = 2) -> void:
	for i in range(count): await physics_frame; await process_frame
func enemy(kind: int,pos: Vector3) -> Node3D:
	var result: Node3D = world.make_enemy(kind,pos,false,1)
	result.set_physics_process(false)
	return result
func clear_enemies() -> void:
	for node in get_nodes_in_group("enemies"):
		node.get_parent().remove_child(node); node.queue_free()
func run() -> void:
	check(Arsenal.WEAPONS.size()==9 and ItemBag.WEAPON_IDS.size()==9,"nine weapon specs agree with inventory IDs")
	for id in ItemBag.IDS:
		var texture: Texture2D = ItemIcons.get_icon(id)
		check(texture!=null and texture.get_width()==96,"original vector icon imports at full resolution: "+id)
		var model: Node3D = load("res://assets/models/"+("weapon_" if id in ItemBag.WEAPON_IDS else "item_")+id+".tscn").instantiate()
		check(model.get_child_count()>=2,"editable multi-part model is available: "+id)
		model.free()
	for kind in [0,1,2,3,4,5,8,9,10,11,12,13,14]:
		var model: Node3D = load("res://assets/models/infected_"+str(kind)+".tscn").instantiate()
		check(model.has_node("LegL") and model.has_node("ArmR") and model.get_child_count()>10,"infected model keeps animation hierarchy and unique attachments: %d" % kind)
		model.free()
	load("res://scripts/campaign/campaign_world.gd").next_mode = "campaign"
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	world = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	var save_path: String = world.checkpoint_path()
	var existed := FileAccess.file_exists(save_path)
	var backup := FileAccess.get_file_as_string(save_path) if existed else ""
	root.add_child(world); current_scene = world
	check(FileAccess.file_exists(save_path) and world.valid_snapshot(JSON.parse_string(FileAccess.get_file_as_string(save_path))),"initial automatic checkpoint already contains nine valid weapon states")
	world.checkpoint_enabled = false
	if existed:
		var file := FileAccess.open(save_path,FileAccess.WRITE); file.store_string(backup); file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	await frames()
	world.set_process(false); world.waves.set_physics_process(false)
	var actor: Node3D = world.player
	actor.set_physics_process(false)
	actor.bag = ItemBag.new()
	for id in ItemBag.WEAPON_IDS: actor.bag.add(id,1)
	actor.weapons.sync_hand()
	check(actor.weapons.ammo.size()==9 and actor.weapons.owned.all(func(value): return value),"survivor initializes all nine weapon states from the physical bag")
	for i in range(5,9):
		actor.bag.selected = i; actor.weapons.sync_hand()
		check(actor.weapons.slot==i and actor.rig.get_node("Gun").get_child_count()==1,"new weapon equips its actual model: "+ItemBag.WEAPON_IDS[i])
	actor.position = Vector3(20,0,20)
	var targets: Array[Node3D] = []
	for i in range(4):
		var target := enemy(0,Vector3(20,0,16-i*3)); target.health.setup(500); targets.append(target)
	await frames()
	actor.bag.selected = 6; actor.weapons.sync_hand(); actor.weapons.ammo[6] = 1; actor.weapons.cooldown = 0
	check(actor.weapons.shoot(Vector3.FORWARD) and actor.weapons.ammo[6]==0,"sniper fires and consumes one loaded round")
	check(targets[0].health.current<500 and targets[1].health.current<500 and targets[2].health.current<500 and targets[3].health.current==500,"sniper penetrates exactly three aligned infected")
	check(targets[0].health.current<targets[1].health.current and targets[1].health.current<targets[2].health.current,"penetrating damage decreases at each impact")
	clear_enemies(); await frames()
	for i in range(4):
		var target := enemy(0,Vector3(20+i*2,0,15)); target.health.setup(500); targets[i] = target
	await frames()
	actor.bag.selected = 8; actor.weapons.sync_hand(); actor.weapons.ammo[8] = 2; actor.weapons.cooldown = 0
	check(actor.weapons.shoot(Vector3.FORWARD),"Tesla initiates a discharge against a raycast target")
	check(targets.all(func(target): return target.health.current<500),"Tesla reaches up to four connected nearby targets")
	check(targets[0].health.current<targets[1].health.current and targets[1].health.current<targets[2].health.current,"chain damage decays rather than duplicating primary damage")
	clear_enemies(); await frames()
	var wall := StaticBody3D.new(); world.add_child(wall); wall.position = Vector3(23,0,15); wall.collision_layer = 1
	VisualFactory.collider(wall,Vector3(1,4,5),Vector3(0,2,0))
	var front := enemy(0,Vector3(20,0,15)); front.health.setup(500)
	var behind := enemy(0,Vector3(25,0,15)); behind.health.setup(500)
	await frames(); actor.weapons.cooldown = 0; actor.weapons.shoot(Vector3.FORWARD)
	check(front.health.current<500 and behind.health.current==500,"solid cover blocks the Tesla chain")
	wall.queue_free(); clear_enemies(); await frames()
	actor.bag.selected = 5; actor.weapons.sync_hand(); actor.weapons.ammo[5] = 0; actor.bag.add("heavy",3)
	check(actor.weapons.reload(),"revolver reload accepts carried heavy ammunition")
	actor.weapons._process(5)
	check(actor.weapons.ammo[5]==3 and actor.bag.count("heavy")==0,"partial heavy-ammo reload conserves three rounds")
	actor.position = world.vendor_pos+Vector3(0,0,2)
	world.resources.scrap = 5000
	actor.bag.remove("tesla",1); actor.weapons.ammo[8] = 0; actor.weapons.sync_hand()
	var price_before: int = world.resources.scrap
	check(world.buy_weapon(8) and world.resources.scrap==price_before-Arsenal.PRICES[8] and actor.bag.count("tesla")==1,"new Tesla model is purchasable through the real vendor transaction")
	check(world.shop_service("cells") and actor.bag.count("cells")==16,"vendor sells the finite energy-cell pack")
	world.waves.wave = 12
	check(world.waves.enemy_type(7)==12 and world.waves.enemy_type(19)==13 and world.waves.enemy_type(23)==14,"new infected enter the live horde roster progressively")
	actor.position = Vector3(20,0,20)
	var charger := enemy(12,Vector3(20,0,12))
	charger.ability_left = 0; charger._physics_process(.01)
	check(charger.windup>0 and charger.warning_radius()<2,"charger announces a narrow rush before moving")
	charger._physics_process(1.2)
	check(charger.rush_left>0 and charger.rush_direction.z>0,"charger commits a direction toward the last target position")
	var start: Vector3 = charger.position
	for i in range(6): charger._physics_process(1.0/60); await physics_frame
	check(charger.position.distance_to(start)>.7,"charge produces actual fast physical movement")
	charger.queue_free(); await frames()
	var cryo := enemy(13,actor.position+Vector3(0,0,-7))
	cryo.ability_left = 0; cryo._physics_process(.01)
	check(cryo.windup>0 and cryo.warning_color().b>.8,"cryo attack uses a distinct blue warning")
	actor.health.setup(100); actor.invulnerable = 0
	cryo._physics_process(1.2)
	check(actor.slow_left==5 and actor.health.current<100,"cryo pulse damages and applies temporary slow to a survivor in the area")
	var state: Dictionary = world.net_state(1)
	check(state.players[0].slow==5,"cooperative state includes the slow duration")
	cryo.queue_free(); await frames()
	var turret := StaticBody3D.new(); turret.set_script(load("res://scripts/campaign/campaign_structure.gd")); turret.world = world; turret.piece_index = 1; turret.position = Vector3(26,0,20); world.base_root.add_child(turret)
	var saboteur := enemy(14,Vector3(26,0,16)); saboteur.ability_left = 0; saboteur._physics_process(.01)
	check(saboteur.windup>0 and saboteur.warning_radius()==8,"saboteur announces a larger EMP area")
	saboteur._physics_process(1.2)
	check(turret.disabled_left==5,"EMP disables the nearby actual turret for five seconds")
	saboteur.queue_free(); await frames()
	front = enemy(0,Vector3(26,0,14)); front.health.setup(500)
	await frames(); var hp: float = front.health.current; turret.fire_turret()
	check(front.health.current==hp,"disabled turret cannot bypass EMP through its firing method")
	turret._physics_process(5.1); turret.fire_turret()
	check(front.health.current<hp,"turret resumes firing after the effect expires")
	clear_enemies(); await frames()
	world.waves.wave = 2; world.resources.pending = 0; world.upgrades.offers.clear(); world.hud.close_modal()
	actor.position = Vector3(0,0,3); actor.health.setup(100)
	var snap: Dictionary = world.snapshot()
	check(snap.format==6 and world.valid_snapshot(JSON.parse_string(JSON.stringify(snap))),"v6 serializes and validates the full nine-weapon arsenal")
	actor.bag.remove("pistol",1); actor.bag.remove("tesla",1); actor.weapons.sync_hand()
	var no_pistol: Dictionary = world.snapshot()
	check(world.valid_snapshot(no_pistol),"saving remains valid when a gun, including the starter pistol, is stored elsewhere")
	actor.bag = ItemBag.new(); world.apply_snapshot(snap)
	check(actor.bag.count("tesla")==1 and actor.weapons.ammo.size()==9,"v6 restores new guns and loaded ammunition")
	var old: Dictionary = snap.duplicate(true); old.format = 4; old.owned.resize(5); old.ammo.resize(5); old.slot = 0
	for profile in old.profiles.values(): profile.ammo.resize(5)
	var migrated: Dictionary = world.migrate_snapshot(old)
	check(migrated.format==6 and migrated.ammo.size()==9 and old.ammo.size()==5,"v4 migration extends weapon states without modifying the original save")
	check(world.valid_snapshot(migrated),"migrated v4 world and guest profiles pass validation")
	world.hud.show_inventory(); await frames()
	check(world.hud.inventory_buttons[0] is ItemSlot and world.hud.hotbar[0] is ItemSlot,"inventory and hotbar use real icon slots")
	world.hud.close_modal(); world.hud.show_shop()
	check(world.hud.mode=="shop","expanded arsenal shop opens with all nine weapon entries")
	world.hud.close_modal()
	world.travel_cooldown = 0; actor.position = SectorGenerator.EXITS[1]
	check(world.step_sector(1),"survival world enters a real procedural sector with the expanded arsenal")
	for cache in world.caches: cache.get_parent().remove_child(cache); cache.queue_free()
	world.caches.clear(); world.claimed.clear()
	world.descriptor.rare = 1; world.descriptor.seed = 7; world.create_caches()
	var rare: Node3D = world.caches.back()
	check(rare.get_meta("weapon")==8 and rare.get_meta("contents").has("tesla"),"rare stash can hold a new weapon beyond the original five")
	actor.bag.remove("tesla",1); actor.weapons.ammo[8] = 0
	actor.position = rare.global_position+Vector3(.5,0,0); actor.cancel_gather()
	world.tick_gather(actor,4.9)
	check(actor.bag.count("tesla")==0,"new hidden weapon still requires the full five-second gathering time")
	world.tick_gather(actor,.2)
	check(actor.bag.count("tesla")==1 and actor.weapons.ammo[8]==12,"finishing the rare gather grants one Tesla with its loaded magazine")
	world.queue_free(); await create_timer(.35).timeout
	print("ARSENAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
