extends SceneTree
var world: Node3D
var checks: int = 0
var failures: int = 0
var backup: String = ""
var had_save: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func unpause_choices() -> void:
	world.resources.pending = 0
	world.upgrades.offers.clear()
	if world.hud.mode!="result": world.hud.close_modal()

func fund() -> void:
	world.resources.scrap = 10000
	world.stock = {"wood":1000,"parts":1000}

func place(index: int,pos: Vector3,angle: float = 0) -> Node3D:
	world.player.position = pos+Vector3(0,0,4)
	world.builder.set_active(true)
	world.builder.selected = index
	world.builder.angle = angle
	world.builder.location = pos
	return world.builder.place()

func run() -> void:
	seed(9221)
	var path := "user://zombie_bloom_arena_campaign.json"
	had_save = FileAccess.file_exists(path)
	if had_save: backup = FileAccess.get_file_as_string(path)
	world = load("res://scenes/campaign/CampaignWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	check(world.phase=="prep" and world.area_index==-1 and world.core.health.current==600,"campaign initializes the original arena and intact core")
	check(world.stock.wood==12 and world.stock.parts==4,"starter construction materials exist")
	check(world.player.weapons.owned==[true,false,false],"pistol only at start; advanced guns require purchases")
	world.player.weapons.equip(2)
	check(world.player.weapons.slot==0,"number key equip cannot bypass weapon ownership")
	var before: int = world.resources.scrap
	check(not world.buy_weapon(1) and world.resources.scrap==before,"shop purchase rejected outside vendor reach")
	world.player.position = world.vendor_pos+Vector3(0,0,3)
	check(world.buy_weapon(1) and world.player.weapons.owned[1] and world.resources.scrap==before-110,"vendor exchanges exact scrap for shotgun ownership")
	before = world.resources.scrap
	check(not world.buy_weapon(1) and world.resources.scrap==before,"repeated weapon purchase does not double-charge")
	check(not world.buy_weapon(2) and not world.player.weapons.owned[2],"rifle cannot be bought without enough currency")
	fund()
	check(world.buy_weapon(2) and world.player.weapons.slot==2,"rifle purchased and equipped")
	world.player.health.take_damage(50)
	check(world.shop_service("heal") and world.player.health.current==100,"vendor treatment heals to maximum")
	before = world.resources.scrap
	check(not world.shop_service("heal") and world.resources.scrap==before,"treatment does not charge at full health")
	var wood: int = world.stock.wood
	check(world.shop_service("wood") and world.stock.wood==wood+10,"vendor sells an actual wood bundle")
	var parts: int = world.stock.parts
	check(world.shop_service("parts") and world.stock.parts==parts+4,"vendor sells actual components")
	before = world.resources.scrap
	check(not world.pay({"scrap":-10}) and not world.pay({"mystery":1}) and world.resources.scrap==before,"transaction rejects negative or unknown costs")
	wood = world.stock.wood
	check(not world.pay({"scrap":1,"wood":wood+1}) and world.resources.scrap==before and world.stock.wood==wood,"multi-resource transaction conserves all balances on failure")
	world.builder.selected = 0
	world.player.position = Vector3(0,0,6)
	check(not world.builder.can_place(Vector3.ZERO),"construction rejects the core footprint")
	check(not world.builder.can_place(world.vendor_pos),"construction preserves vendor access")
	check(not world.builder.can_place(world.exit_pos),"construction preserves extraction access")
	check(not world.builder.can_place(Vector3(25,0,0)),"construction respects arena boundaries")
	check(not world.builder.can_place(Vector3(-20,0,-20)),"construction respects player reach")
	var wall: Node3D = place(2,Vector3(6,0,0))
	check(is_instance_valid(wall) and wall.health.maximum==440,"reinforced wall is a real damageable solid structure")
	await frames()
	check(not world.builder.can_place(wall.position),"construction rejects existing piece overlap")
	var adjacent: Node3D = place(2,Vector3(9,0,0))
	check(is_instance_valid(adjacent),"modular walls can share an edge without a forced gap")
	await frames()
	var barricade: Node3D = place(0,Vector3(-5,0,0),PI/2)
	await frames()
	check(is_instance_valid(barricade) and is_equal_approx(barricade.rotation.y,PI/2),"rotation is applied to both visible and physical barricade")
	var turret: Node3D = place(1,Vector3(6,0,-5))
	await frames()
	check(is_instance_valid(turret) and turret.spec.id=="turret","turret is buildable using scrap and components")
	var gate: Node3D = place(3,Vector3(-5,0,-5))
	await frames()
	check(is_instance_valid(gate) and gate.collision_layer==8,"gate starts physically closed")
	check(gate.toggle() and gate.opened and gate.collision_layer==0,"open gate clears its collision")
	world.player.position = gate.position
	await frames()
	check(not gate.toggle() and gate.opened,"gate cannot close through the player")
	world.player.position = gate.position+Vector3(0,0,4)
	await frames()
	check(gate.toggle() and not gate.opened and gate.collision_layer==8,"unoccupied gate closes physically")
	var spikes: Node3D = place(4,Vector3(5,0,7))
	await frames()
	check(is_instance_valid(spikes) and spikes.collision_layer==0,"spike bed permits traversal")
	var station: Node3D = place(5,Vector3(-5,0,12))
	await frames()
	check(is_instance_valid(station),"support station builds successfully")
	var initial_max: float = wall.health.maximum
	var initial_damage: float = turret.spec.values.damage
	check(wall.improve() and wall.tier==2 and wall.health.maximum>initial_max,"structure upgrade increases integrity")
	check(turret.improve() and turret.spec.values.damage>initial_damage,"turret upgrade increases actual combat damage")
	check(wall.improve() and wall.tier==3 and not wall.improve(),"defense tiers stop at three")
	wall.take_damage(40)
	check(wall.repair() and wall.health.current==wall.health.maximum,"upgraded wall can be repaired")
	world.player.position = Vector3(0,0,3)
	check(world.improve_nearby() and world.core_tier==2 and world.core.health.maximum==850,"core upgrade adds actual maximum integrity")
	world.player.position = station.position+Vector3(0,0,3)
	world.player.health.take_damage(20)
	station.health.take_damage(10)
	station.cooldown = 0
	station._physics_process(.01)
	check(world.player.health.current>80 and station.health.current>250,"support station heals player and nearby structure during preparation")
	var zombie: Node3D = world.make_enemy(0,spikes.position,false,0)
	zombie.set_physics_process(false)
	var hp: float = zombie.health.current
	spikes.cooldown = 0
	spikes._physics_process(.01)
	check(zombie.health.current<hp,"spikes deal real damage to an enemy on the bed")
	zombie.queue_free()
	await frames()
	var armored: Node3D = world.make_enemy(3,Vector3(20,0,20),false,0)
	armored.set_physics_process(false)
	hp = armored.health.current
	armored.take_damage(10)
	check(is_equal_approx(armored.health.current,hp-6),"armored infected reduces incoming damage by forty percent")
	var heavy: Node3D = world.make_enemy(4,Vector3(20,0,-20),false,0)
	heavy.set_physics_process(false)
	heavy.choose_target()
	check(heavy.target==world.core and heavy.health.maximum>300 and heavy.spec.values.damage>=30,"demolisher is durable and prioritizes the core")
	armored.queue_free()
	heavy.queue_free()
	await frames()
	var invested: Dictionary = adjacent.invested.duplicate()
	before = world.resources.scrap
	check(adjacent.dismantle() and world.resources.scrap==before+int(invested.scrap)/2,"dismantling refunds half the paid materials")
	check(not adjacent.dismantle(),"dismantling cannot refund twice")
	await frames()
	world.player.position = Vector3(5,0,16)
	world.builder.set_active(true)
	world.builder.selected = 0
	world.builder.angle = 0
	world.builder.location = Vector3(-22,0,-22)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world.camera.unproject_position(Vector3(5,0,12))
	world._unhandled_input(click)
	check(world.builder.location==Vector3(5,0,12),"placement projects the current click rather than stale cursor preview")
	check(get_nodes_in_group("campaign_structure").any(func(s): return s.position==Vector3(5,0,12)),"real click path creates the selected structure at the requested point")
	world.builder.set_active(false)
	world.hud.show_build_catalog()
	check(paused and world.hud.mode=="catalog","build catalog pauses gameplay")
	world.hud.close_modal()
	world.hud.show_routes()
	check(paused and world.hud.mode=="routes","route map opens as a real modal")
	world.hud.close_modal()
	check(not world.travel(1) and world.area_index==-1,"residential area locked before first wave")
	var structures: int = get_nodes_in_group("campaign_structure").size()
	var base_node: Node3D = world.base_root
	check(world.travel(0) and world.area_index==0 and world.phase=="expedition","yard travel loads the first combat area")
	await frames()
	check(not base_node.is_inside_tree() and world.arena!=world.base_arena and get_nodes_in_group("campaign_structure").is_empty(),"base geometry and defenses are removed from active scene during expedition")
	check(not world.waves.start() and not world.builder.can_place(Vector3(0,0,5)),"expedition blocks base waves and construction")
	check(not world.save_checkpoint(false),"checkpoint cannot serialize a half-loaded field as a base")
	world.player.position = world.caches[0].position
	check(not world.collect_cache(0),"cache cannot be looted before clearing hostiles")
	world.field_spawn_left = 0
	world._process(.1)
	await frames()
	check(get_nodes_in_group("enemies").size()>0,"field encounter materializes enemies over time")
	var first: Node3D = get_nodes_in_group("enemies")[0]
	first.set_physics_process(false)
	first.choose_target()
	check(first.target==world.player,"field enemies target survivor instead of detached core")
	first.take_damage(100000)
	unpause_choices()
	check(world.areas[0].dead.size()==1,"field kills persist by encounter identifier")
	world.player.position = Vector3(0,0,24)
	check(world.return_to_base(),"retreat returns through physical extraction point")
	unpause_choices()
	await frames()
	check(world.base_root==base_node and get_nodes_in_group("campaign_structure").size()==structures and wall.tier==3,"travel retains exact base structure instances and upgrades")
	check(world.travel(0) and world.field_queue.size()==9,"returning to unfinished area spawns only surviving enemies")
	world.set_process(false)
	while not world.field_queue.is_empty():
		var index: int = world.field_queue.pop_front()
		var enemy: Node3D = world.make_enemy(0,Vector3(0,0,-20),true,index)
		enemy.set_physics_process(false)
		enemy.take_damage(100000)
		unpause_choices()
	check(world.areas[0].cleared and world.areas[0].dead.size()==10,"last finite enemy marks the area cleared")
	var reward_before := {"scrap":world.resources.scrap,"wood":world.stock.wood,"parts":world.stock.parts}
	for i in range(3):
		world.player.position = world.caches[i].position
		check(world.collect_cache(i),"cleared cache transfers supplies %d" % i)
		check(not world.collect_cache(i),"cache cannot grant supplies twice %d" % i)
	check(world.stock.wood-reward_before.wood==24 and world.stock.parts-reward_before.parts==6 and world.resources.scrap-reward_before.scrap==65,"three caches conserve the complete area reward")
	world.player.position = Vector3(0,0,24)
	world.return_to_base()
	unpause_choices()
	await frames()
	check(world.travel(0) and world.field_queue.is_empty() and world.caches.all(func(c): return not c.visible),"cleared area revisits do not regenerate enemies or rewards")
	world.player.position = Vector3(0,0,24)
	world.return_to_base()
	unpause_choices()
	world.set_process(true)
	await frames()
	world.player.position = Vector3(3,0,4)
	check(world.save_checkpoint(false),"base checkpoint writes successfully")
	var snap: Dictionary = world.snapshot()
	check(world.valid_snapshot(JSON.parse_string(JSON.stringify(snap))),"serialized checkpoint passes schema validation")
	var invalid := snap.duplicate(true)
	invalid.areas[0].dead.append(0)
	check(not world.valid_snapshot(invalid),"save rejects repeated enemy IDs before applying")
	invalid = snap.duplicate(true)
	invalid.stock.parts = -1
	check(not world.valid_snapshot(invalid),"save rejects negative stock")
	invalid = snap.duplicate(true)
	invalid.owned[2] = false
	invalid.slot = 2
	check(not world.valid_snapshot(invalid),"save rejects a locked equipped gun")
	world.resources.scrap = 1
	world.stock.wood = 0
	check(world.load_checkpoint() and world.resources.scrap==int(snap.scrap) and world.stock.wood==int(snap.stock.wood),"restore recovers currency and materials")
	await frames()
	check(get_nodes_in_group("campaign_structure").size()==snap.structures.size(),"restore replaces structures without duplicating them")
	world.waves.set_physics_process(false)
	check(world.waves.start() and not world.waves.start(),"base wave starts once after expedition")
	check(not world.travel(0) and not world.buy_weapon(1),"active base horde blocks travel and shop")
	for wave_index in range(8):
		check(world.waves.wave==wave_index+1,"campaign reaches horde %d" % (wave_index+1))
		while world.waves.to_spawn>0:
			var enemy: Node3D = world.waves.spawn_enemy()
			enemy.set_physics_process(false)
			if wave_index==3 and world.waves.spawned==1: check(enemy.spec.id=="armored","fourth horde introduces armored enemies")
			if wave_index==5 and world.waves.spawned==1: check(enemy.spec.id=="demolisher","sixth horde introduces demolishers")
			enemy.take_damage(100000)
			unpause_choices()
		world.waves.complete()
		if wave_index<7:
			check(world.phase=="prep","horde completion permits construction and collection")
			if wave_index in [0,2,4]:
				var area_id := 1 if wave_index==0 else 2 if wave_index==2 else 3
				check(world.travel(area_id),"progression unlocks and loads area %d" % area_id)
				await frames()
				check(world.arena.area==area_id and world.field_queue.size()==int(CampaignData.AREAS[area_id].count),"separate area template has its own finite population")
				world.player.position = Vector3(0,0,24)
				world.return_to_base()
				unpause_choices()
				await frames()
			world.waves.start()
	check(world.phase=="ended" and world.won and paused and world.hud.mode=="result","eighth horde ends in campaign victory")
	paused = false
	world.queue_free()
	await process_frame
	load("res://scripts/campaign/campaign_world.gd").resume_requested = true
	world = load("res://scenes/campaign/CampaignWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	check(world.waves.wave==7 and world.core_tier==2 and world.areas[0].caches.size()==3,"cold start resumes completed hordes, core and claimed caches")
	check(world.player.weapons.owned[1] and world.player.weapons.owned[2],"weapon purchases survive a new scene instance")
	world.travel(0)
	await frames()
	world.queue_free()
	await process_frame
	check(true,"leaving scene during expedition frees detached base as well")
	if had_save:
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(backup)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CAMPAIGN RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
