extends SceneTree
var world: Node3D
var checks: int = 0
var failures: int = 0
var backups := {}
var busy_place_usec: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)

func frames(count: int = 2) -> void:
	for i in range(count): await physics_frame; await process_frame

func clear_choices() -> void:
	world.resources.pending = 0
	world.upgrades.offers.clear()
	if world.hud.mode!="result": world.hud.close_modal()

func enemy(kind: int,pos: Vector3) -> Node3D:
	var result: Node3D = world.make_enemy(kind,pos,false,0)
	result.set_physics_process(false)
	return result

func structure(piece: int,pos: Vector3) -> Node3D:
	var result := StaticBody3D.new()
	result.set_script(load("res://scripts/campaign/campaign_structure.gd"))
	result.world = world
	result.piece_index = piece
	result.position = pos
	world.base_root.add_child(result)
	world.layout_revision += 1
	return result

func run() -> void:
	var script = load("res://scripts/campaign/campaign_world.gd")
	for mode in ["campaign","endless"]:
		var path: String = script.save_path(mode)
		backups[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	script.next_mode = "campaign"
	world = load("res://scenes/campaign/CampaignWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	check(world.arena.navigation.region.size==Vector2i(55,55),"larger arena has physical terrain and navigation across 110 metres")
	world.player.position = Vector3(45,0,10)
	await frames(3)
	check(world.player.is_on_floor() and world.player.position.x>40,"outer terrain beyond previous map border supports the real player")
	check(CampaignData.WAVES.size()==20 and CampaignData.wave_count(20)>200,"campaign contains twenty increasingly populated waves")
	check(CampaignData.health_scale(20)>CampaignData.health_scale(8)*2,"later waves scale durability faster than the old campaign")
	check(CampaignData.wave_count(60)>CampaignData.wave_count(21),"infinite population formula continues beyond campaign length")
	var builder: Node3D = world.builder
	world.player.position = Vector3(18,0,8)
	world.resources.scrap = 50000
	world.stock = {"wood":5000,"parts":5000}
	builder.set_active(true)
	var access_count: int = builder.access_checks
	var material_a: int = builder.good_material.get_instance_id()
	for i in range(120): builder._physics_process(1.0/60)
	check(builder.access_checks==access_count,"preview does not run full path validation every frame")
	check(builder.preview_checks<=21,"preview collision checks are throttled to ten per second")
	check(builder.good_material.get_instance_id()==material_a,"preview reuses its two materials")
	var samples: Array[int] = []
	for i in range(8):
		builder.selected = 2
		var spot := Vector3(20+i%4*4,0,15+i/4*5)
		world.player.position = spot+Vector3(0,0,4)
		await frames()
		builder.location = spot
		check(builder.place()!=null,"construction commits without a deferred phantom piece %d" % i)
		samples.append(builder.last_place_usec)
	var rev: int = builder.access_rebuilds
	builder.preserves_access(Vector3(20,0,25),CampaignData.PIECES[2].size)
	rev = builder.access_rebuilds
	builder.preserves_access(Vector3(21,0,25),CampaignData.PIECES[2].size)
	check(builder.access_rebuilds==rev,"path grid is reused until structure layout changes")
	# A closed dividing row is a worst case path rejection; temporary cells must be restored.
	builder.access_grid.fill_solid_region(builder.access_grid.region,false)
	for x in range(-47,48):
		if absi(x)>1: builder.access_grid.set_point_solid(Vector2i(x,3))
	builder.access_revision = world.layout_revision
	builder.selected = 2
	check(not builder.preserves_access(Vector3(0,0,3),Vector3(3,2.4,1)),"cached access validation still rejects sealing the core route")
	check(not builder.access_grid.is_point_solid(Vector2i(0,3)),"temporary placement cells are rolled back after validation")
	builder.access_revision = -1
	builder.set_active(false)
	world.player.position = world.vendor_pos+Vector3(0,0,3)
	check(world.buy_weapon(3) and world.player.weapons.slot==3,"SMG is purchased through the trader and selected")
	check(world.buy_weapon(4) and world.rockets==5 and world.player.weapons.ammo[4]==1,"launcher purchase grants one loaded and five reserve rockets")
	var before: int = world.grenades
	check(world.shop_service("grenades") and world.grenades==before+3,"grenade packs add finite inventory")
	check(world.shop_service("rockets") and world.rockets==10,"rocket packs add finite reserve")
	world.player.position = Vector3(20,0,20)
	await frames()
	var gun: Node = world.player.weapons
	gun.cooldown = 0
	check(gun.shoot(Vector3.FORWARD) and gun.ammo[4]==0 and world.rockets==10,"rocket firing consumes the loaded round only")
	check(gun.reload(),"launcher begins a finite reload")
	gun.equip(0)
	check(world.rockets==10 and gun.ammo[4]==0 and gun.reload_left==0,"switching cancels launcher reload without spending reserve")
	gun.equip(4)
	gun.reload()
	gun._process(3)
	check(gun.ammo[4]==1 and world.rockets==9,"finished launcher reload consumes exactly one reserve rocket")
	world.rockets = 0
	gun.ammo[4] = 0
	check(not gun.reload() and gun.ammo[4]==0,"empty reserve cannot refill a launcher for free")
	world.clear_hazards()
	world.phase = "combat"
	before = world.grenades
	check(world.throw_grenade() and world.grenades==before-1,"grenade input launches a delayed explosive and spends one grenade")
	check(not world.throw_grenade() and world.grenades==before-1,"grenade cooldown prevents duplicate throws")
	check(get_nodes_in_group("campaign_projectiles").size()==1,"grenade is a physical-flight gameplay object before detonation")
	world.clear_hazards()
	world.player.position = Vector3(20,0,-20)
	var a := enemy(3,Vector3(22,0,-20))
	var b := enemy(0,Vector3(23,0,-20))
	await frames()
	var ha: float = a.health.current
	var hb: float = b.health.current
	world.player.invulnerable = 0
	world.explode(Vector3(22,.2,-20),4.5,20)
	check(a.health.current<ha and b.health.current<hb,"explosion applies area damage to several enemies")
	check(world.player.health.current<100,"explosive proximity can hurt the survivor")
	var blocker := StaticBody3D.new()
	world.add_child(blocker)
	blocker.position = Vector3(22,0,-23)
	VisualFactory.collider(blocker,Vector3(6,3,1),Vector3(0,1.5,0))
	var covered := enemy(3,Vector3(22,0,-25))
	await frames()
	ha = covered.health.current
	world.explode(Vector3(22,.5,-21),5,25)
	check(covered.health.current==ha,"solid geometry shields enemies from blast damage")
	for node in [a,b,covered,blocker]: node.queue_free()
	await frames()
	world.player.position = Vector3(20,0,20)
	var support := structure(0,Vector3(22,0,20))
	var pool: Node3D = world.spawn_acid(Vector3(20,0,20),2.5,8)
	ha = support.health.current
	world.player.invulnerable = 0
	hb = world.player.health.current
	pool.tick = 0
	pool._physics_process(.1)
	check(support.health.current<ha and world.player.health.current<hb,"corrosive ground damages both defenses and survivor")
	pool.life = .05
	pool._physics_process(.1)
	await frames()
	check(get_nodes_in_group("acid_pools").is_empty(),"acid pool expires instead of accumulating forever")
	var spitter := enemy(5,Vector3(0,0,-14))
	world.player.position = Vector3(20,0,20)
	spitter.acid_left = 0
	spitter._physics_process(.01)
	check(get_nodes_in_group("campaign_projectiles").size()>0,"corrosive infected casts an actual delayed acid projectile")
	spitter.queue_free()
	world.clear_hazards()
	var dog := enemy(6,Vector3(5,0,-8))
	var flyer := enemy(7,Vector3(8,0,-8))
	check(dog.spec.values.speed>4 and dog.aim_height<1,"infected hound has fast movement and a quadruped hit height")
	check(flyer.position.y>2.5 and flyer.collision_mask==0,"flyer occupies air space and bypasses ground obstacles")
	world.player.position = Vector3(5,0,-2)
	gun.equip(0)
	gun.cooldown = 0
	ha = dog.health.current
	await frames()
	gun.shoot(Vector3.FORWARD)
	check(dog.health.current<ha,"ground firearm can hit the low hound silhouette")
	world.player.position = Vector3(8,0,-2)
	gun.cooldown = 0
	ha = flyer.health.current
	await frames()
	gun.shoot(Vector3.FORWARD)
	check(flyer.health.current<ha,"firearm adjusts elevation to hit an aimed-at flyer")
	var turret := structure(1,Vector3(8,0,-4))
	dog.queue_free()
	await frames()
	ha = flyer.health.current
	turret.fire_turret()
	check(flyer.health.current<ha,"turret line of sight and damage include air targets")
	flyer.queue_free()
	var alpha := enemy(8,Vector3(20,0,-20))
	check(alpha.health.maximum>=850,"periodic Alpha introduces boss-scale durability")
	alpha.queue_free()
	await frames()
	clear_choices()
	world.phase = "prep"
	world.player.health.heal(100)
	world.player.position = Vector3(3,0,4)
	world.rockets = 7
	world.grenades = 4
	for i in range(80-get_nodes_in_group("campaign_structure").size()):
		structure(0,Vector3(-42+(i%12)*7,0,-42+(i/12)*5))
	world.player.position = Vector3(0,0,40)
	await frames()
	builder.set_active(true)
	builder.selected = 0
	builder.location = Vector3(0,0,36)
	check(builder.place()!=null,"construction remains valid with eighty existing defenses")
	busy_place_usec = builder.last_place_usec
	builder.set_active(false)
	world.player.position = Vector3(3,0,4)
	var snap: Dictionary = world.snapshot()
	check(world.valid_snapshot(JSON.parse_string(JSON.stringify(snap))),"five weapons and finite explosive inventory validate after serialization")
	var old := snap.duplicate(true)
	old.format = 1
	old.erase("mode")
	old.erase("rockets")
	old.erase("grenades")
	old.owned.resize(3)
	old.ammo.resize(3)
	old.slot = 0
	var upgraded: Dictionary = world.migrate_snapshot(old)
	check(world.valid_snapshot(upgraded) and old.format==1 and upgraded.owned.size()==5,"legacy save migration preserves source and extends arsenal safely")
	world.hud.show_shop()
	check(paused and world.hud.mode=="shop","expanded shop opens inside a scrollable modal")
	world.hud.close_modal()
	world.hud.show_equipment()
	check(paused and world.hud.mode=="equipment","arsenal describes all five weapons and explosives")
	world.hud.close_modal()
	world.queue_free()
	await process_frame
	script.next_mode = "endless"
	world = load("res://scenes/campaign/CampaignWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames()
	check(world.game_mode=="endless" and world.checkpoint_path()!=script.save_path("campaign"),"infinite mode uses a separate checkpoint")
	world.waves.set_physics_process(false)
	world.waves.wave = 20
	check(world.waves.start() and world.waves.wave==21 and world.waves.to_spawn>240,"infinite mode starts wave twenty-one")
	world.waves.to_spawn = 0
	world.waves.complete()
	check(world.phase=="prep" and not world.won,"infinite wave completion never opens campaign victory")
	check(world.waves.start() and world.waves.wave==22,"infinite mode starts the following wave normally")
	world.waves.to_spawn = 0
	world.waves.complete()
	world.grenades = 6
	world.rockets = 11
	check(world.save_checkpoint(false),"infinite checkpoint saves past campaign length")
	world.grenades = 0
	world.rockets = 0
	check(world.load_checkpoint() and world.grenades==6 and world.rockets==11,"checkpoint restores finite explosive ammunition")
	check(not world.valid_snapshot(snap),"infinite mode rejects applying a campaign snapshot")
	world.queue_free()
	await process_frame
	script.next_mode = "campaign"
	for path in backups:
		if backups[path]==null: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path,FileAccess.WRITE)
			file.store_string(backups[path])
			file.close()
	await create_timer(.35).timeout
	samples.sort()
	print("BUILD BENCHMARK ",JSON.stringify({"placements":samples.size(),"median_ms":samples[samples.size()/2]/1000.0,"max_ms":samples.back()/1000.0,"renderer":"headless","preview_path_checks":0,"existing_80_ms":busy_place_usec/1000.0}))
	print("DEFENSE RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
