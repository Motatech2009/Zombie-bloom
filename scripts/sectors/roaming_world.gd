extends "res://scripts/campaign/campaign_world.gd"
var sector_coord := Vector2i.ZERO
var descriptor: Dictionary = {}
var discovered: Dictionary = {}
var world_rng := RandomNumberGenerator.new()
var world_seed: int = 1
var visit_serial: int = 0
var horde_left: float = 210
var travel_cooldown: float = 0
var exit_labels: Array[Label3D] = []
var base_exit_labels: Array[Label3D] = []
var claimed: Array[int] = []
var field_dead: int = 0
var waypoint := Vector2i.ZERO

static func frontier_path(mode: String) -> String:
	return "user://zombie_bloom_"+mode+"_v3.json"

func checkpoint_path() -> String:
	return frontier_path(game_mode)

func wave_script() -> Script:
	return load("res://scripts/sectors/roaming_waves.gd")

func hud_script() -> Script:
	return load("res://scripts/sectors/roaming_hud.gd")

func _ready() -> void:
	world_rng.randomize()
	world_seed = world_rng.randi_range(1,2147483647)
	world_rng.seed = world_seed
	discovered = {"0:0":{"visits":1,"risk":-1}}
	exit_pos = SectorGenerator.EXITS[2]
	super._ready()
	notify("REFÚGIO FIXO · Horda automática em %d s. Use as saídas N/L/S/O e M para se orientar." % ceili(horde_left))

func create_travel_markers() -> void:
	add_exits(base_root)
	base_exit_labels.assign(exit_labels)
	exit_tag = exit_labels[2]

func add_exits(parent: Node3D) -> void:
	exit_labels.clear()
	for i in range(4):
		var point: Vector3 = SectorGenerator.EXITS[i]
		VisualFactory.ring(parent,2.6,point+Vector3(0,.07,0),Color("b8de80"))
		var label := VisualFactory.health_label(parent,2)
		label.position = point+Vector3(0,2,0)
		label.font_size = 24
		label.text = "E / "+SectorGenerator.NAMES[i].to_upper()
		label.visible = false
		exit_labels.append(label)

func exit_positions() -> Array:
	return SectorGenerator.EXITS

func access_origins() -> Array[Vector2i]:
	return [Vector2i(0,-46),Vector2i(46,0),Vector2i(0,46),Vector2i(-46,0)]

func sector_offset(coord: Vector2i) -> Vector3:
	return Vector3(coord.x*120,0,coord.y*120)

func local_player() -> Vector3:
	return player.position-sector_offset(sector_coord)

func _process(delta: float) -> void:
	if phase=="ended": return
	elapsed += delta
	notice_left = maxf(0,notice_left-delta)
	grenade_cooldown = maxf(0,grenade_cooldown-delta)
	travel_cooldown = maxf(0,travel_cooldown-delta)
	var target: Vector3 = player.position*.82
	# Sector offsets belong to the camera target in full; no drift toward the origin.
	target = sector_offset(sector_coord)+local_player()*.82
	camera.position = camera.position.lerp(target+camera_offset,1-exp(-delta*5))
	camera.look_at(target)
	core.label.visible = area_index==-1 and player.position.distance_to(core.position)<4
	vendor_tag.visible = area_index==-1 and player.position.distance_to(vendor_pos)<7
	for boss in get_tree().get_nodes_in_group("boss_enemies"):
		boss.label.visible = boss.global_position.distance_to(player.position)<35
		boss.label.text = "CHEFE · %s · %d" % [boss.spec.title,ceili(boss.health.current)]
	shop_clock += delta
	if area_index==-1: VisualFactory.animate_human(vendor_rig,shop_clock,.12,0,false)
	for i in range(exit_labels.size()): exit_labels[i].visible = local_player().distance_to(SectorGenerator.EXITS[i])<9
	if area_index!=-1:
		field_spawn_left -= delta
		if field_spawn_left<=0 and not field_queue.is_empty() and field_alive()<24 and get_tree().get_nodes_in_group("enemies").size()<60:
			if spawn_field_enemy(): field_spawn_left = .45
			else: field_spawn_left = .25
		for cache in caches:
			if cache.has_meta("weapon"):
				cache.visible = not int(cache.get_meta("index")) in claimed and player.position.distance_to(cache.global_position)<10

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_wave"):
		if phase!="ended": notify("As hordas começam pelo relógio. Próxima em %d s." % ceili(horde_left))
		return
	if event.is_action_pressed("interact") and hud.mode.is_empty() and phase!="ended":
		for i in range(4):
			if local_player().distance_to(SectorGenerator.EXITS[i])<3.7:
				step_sector(i)
				return
		if area_index!=-1: field_interact(); return
	super._unhandled_input(event)

func travel(direction: int) -> bool:
	return step_sector(direction)

func step_sector(direction: int) -> bool:
	if direction<0 or direction>=4 or phase=="ended" or travel_cooldown>0 or resources.pending>0: return false
	if local_player().distance_to(SectorGenerator.EXITS[direction])>=3.7:
		notify("Vá até a saída "+SectorGenerator.NAMES[direction]+" e pressione E. M mostra o caminho.")
		return false
	var next: Vector2i = sector_coord+SectorGenerator.DIRECTIONS[direction]
	if absi(next.x)>4096 or absi(next.y)>4096: notify("Limite da região cartografada."); return false
	if waves.running and SectorGenerator.distance(next)>=SectorGenerator.distance(sector_coord):
		notify("Horda no Núcleo. Siga uma saída que aproxime você de (0,0).")
		return false
	builder.set_active(false)
	if not hud.mode.is_empty(): hud.close_modal()
	if field_root!=null:
		clear_region_hazards(SectorGenerator.key(sector_coord))
		remove_child(field_root)
		field_root.queue_free()
		field_root = null
	caches.clear()
	claimed.clear()
	sector_coord = next
	area_index = -1 if next==Vector2i.ZERO else 0
	travel_cooldown = 1
	var entry: Vector3 = SectorGenerator.EXITS[(direction+2)%4]*.94
	if area_index==-1:
		arena = base_arena
		add_exits_again_for_base()
		descriptor.clear()
		field_queue.clear()
		phase = "combat" if waves.running else "prep"
	else:
		visit_serial += 1
		var key := SectorGenerator.key(next)
		var visits: int = int(discovered.get(key,{"visits":0}).visits)+1
		descriptor = SectorGenerator.generate(world_rng.randi_range(1,2147483647),next,visits,waves.wave)
		discovered[key] = {"visits":visits,"risk":descriptor.risk}
		if discovered.size()>8192:
			for old_key in discovered.keys():
				if old_key!="0:0" and old_key!=key:
					discovered.erase(old_key)
					break
		field_root = Node3D.new()
		field_root.position = sector_offset(next)
		add_child(field_root)
		var field: Arena = load("res://scripts/sectors/sector_arena.gd").new()
		field.world = self
		field.descriptor = descriptor
		field_root.add_child(field)
		arena = field
		add_exits(field_root)
		create_caches()
		field_queue.clear()
		field_dead = 0
		for i in range(descriptor.count): field_queue.append(i)
		field_spawn_left = .4
		phase = "combat" if waves.running else "expedition"
	player.position = sector_offset(next)+entry
	player.velocity = Vector3.ZERO
	player.invulnerable = maxf(player.invulnerable,.7)
	var target := sector_offset(next)+entry*.82
	camera.position = target+camera_offset
	camera.look_at(target)
	if area_index==-1:
		notify("NÚCLEO · "+("Invasão em andamento!" if waves.running else "Próxima horda em %d s." % ceili(horde_left)))
		if not waves.running: save_checkpoint(false)
	else:
		notify("SETOR (%d,%d) · %s · %s · %d infectados. %s" % [next.x,next.y,SectorGenerator.BIOMES[descriptor.biome],SectorGenerator.RISKS[descriptor.risk],descriptor.count,return_hint()])
	return true

func add_exits_again_for_base() -> void:
	exit_labels.assign(base_exit_labels)

func create_caches() -> void:
	for i in range(descriptor.caches.size()):
		var cache := cache_model(descriptor.caches[i],i,false)
		caches.append(cache)
	if int(descriptor.rare)>=1:
		var index := caches.size()
		var cache := cache_model(descriptor.rare_pos,index,true)
		cache.set_meta("weapon",int(descriptor.rare))
		cache.hide()
		caches.append(cache)

func cache_model(pos: Vector3,index: int,rare: bool) -> Node3D:
	var cache := Node3D.new()
	field_root.add_child(cache)
	cache.position = pos
	cache.set_meta("index",index)
	VisualFactory.box(cache,Vector3(1.1,.7,.9),Vector3(0,.35,0),Color("aa8c48") if rare else Color("8e9470"))
	if rare: VisualFactory.box(cache,Vector3(.75,.1,.15),Vector3(0,.74,0),Color("e5cc7a"),true)
	return cache

func field_interact() -> bool:
	for i in range(caches.size()):
		if caches[i].visible and player.position.distance_to(caches[i].global_position)<3: return collect_cache(i)
	notify("E recolhe caixas próximas; nas bordas, E cruza para outro setor. M orienta o retorno.")
	return false

func collect_cache(index: int) -> bool:
	if area_index==-1 or index<0 or index>=caches.size() or index in claimed: return false
	var cache := caches[index]
	if player.position.distance_to(cache.global_position)>3: return false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(cache.global_position)<6:
			notify("Caixa sob ameaça. Afaste ou elimine os infectados próximos.")
			return false
	if cache.has_meta("weapon"):
		var index_weapon: int = cache.get_meta("weapon")
		if not player.weapons.owned[index_weapon]:
			player.weapons.owned[index_weapon] = true
			player.weapons.ammo[index_weapon] = player.weapons.capacity(index_weapon)
			if index_weapon==4: rockets += 3
			notify("ARMA ESCONDIDA · "+CampaignData.WEAPONS[index_weapon].title+" encontrada!")
		else:
			grenades += 2
			resources.scrap += 35
			notify("Arsenal já conhecido · +2 granadas e 35 sucata.")
	else:
		var loot := {}
		for key in descriptor.reward:
			var count: int = int(descriptor.reward[key])/3+(1 if index<int(descriptor.reward[key])%3 else 0)
			credit(key,count)
			loot[key] = count
		notify("SUPRIMENTOS · "+CampaignData.cost_text(loot))
	claimed.append(index)
	cache.hide()
	return true

func return_to_base() -> bool:
	for i in range(4):
		if sector_coord+SectorGenerator.DIRECTIONS[i]==Vector2i.ZERO: return step_sector(i)
	notify("O Núcleo está em (0,0). Volte setor por setor: "+return_hint())
	return false

func spawn_field_enemy() -> bool:
	var index: int = field_queue[0]
	var spots: Array = descriptor.spawns
	for attempt in range(spots.size()):
		var pos: Vector3 = spots[(index*11+attempt)%spots.size()]
		var global_pos := field_root.global_position+pos
		if player.position.distance_to(global_pos)<18: continue
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := SphereShape3D.new()
		shape.radius = .7
		query.shape = shape
		query.transform.origin = global_pos+Vector3(0,.9,0)
		query.collision_mask = 1|2|4|8
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		field_queue.pop_front()
		make_enemy(descriptor.roster[index],pos,true,index)
		return true
	return false

func make_enemy(kind: int,pos: Vector3,field: bool,index: int) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/campaign/campaign_enemy.gd"))
	enemy.spec = SectorGenerator.boss_spec(maxi(1,waves.wave if not field else maxi(waves.wave,SectorGenerator.distance(sector_coord)+2))) if kind==8 else CampaignData.enemy_spec(kind)
	enemy.is_boss = kind==8
	enemy.world = self
	enemy.field_enemy = field
	enemy.encounter_index = index
	enemy.position = pos
	(field_root if field else base_root).add_child(enemy)
	if not field: enemy.add_to_group("wave_enemies")
	if kind==8: enemy.add_to_group("boss_enemies")
	return enemy

func enemy_defeated(enemy: Node3D) -> void:
	if enemy.is_in_group("wave_enemies"): enemy.remove_from_group("wave_enemies")
	if enemy.is_in_group("boss_enemies"): enemy.remove_from_group("boss_enemies")
	kills += 1
	spawn_pickup(enemy.global_position,int(enemy.spec.values.xp),int(enemy.spec.values.scrap))
	if world_rng.randf()<.18: spawn_pickup(enemy.global_position,0,0,["speed","rapid","shield"][world_rng.randi_range(0,2)])
	if enemy.field_enemy:
		field_dead += 1
		if field_dead==int(descriptor.count): notify("SETOR LIMPO · Recolha o que conseguir. Ao sair, este lugar será gerado de novo.")

func spawn_pickup(pos: Vector3,experience: int,metal: int,power: String = "") -> Node3D:
	var parent: Node3D = base_root if region_at(pos)=="0:0" else field_root
	if parent==null: return null
	var count := 0
	var merge: Node3D
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.get_parent()==parent:
			count += 1
			if p.power.is_empty() and not p.collected: merge = p
	if count>=256:
		if power.is_empty() and merge!=null: merge.xp += experience; merge.scrap += metal; return merge
		return null
	var pickup := Node3D.new()
	pickup.set_script(PICKUP_SCRIPT)
	pickup.world = self
	pickup.position = pos-parent.global_position
	pickup.xp = experience
	pickup.scrap = metal
	pickup.power = power
	parent.add_child(pickup)
	return pickup

func field_alive() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.field_enemy: count += 1
	return count

func route_for_enemy(enemy: Node3D,target: Vector3) -> PackedVector2Array:
	if not enemy.field_enemy: return base_arena.route(enemy.global_position,target)
	var offset := field_root.global_position
	var result: PackedVector2Array = arena.route(enemy.global_position-offset,target-offset)
	for i in range(result.size()): result[i] += Vector2(offset.x,offset.z)
	return result

func region_at(point: Vector3) -> String:
	if absf(point.x)<=56 and absf(point.z)<=56: return "0:0"
	return SectorGenerator.key(sector_coord)

func region_active(key: String) -> bool:
	return key=="0:0" or (area_index!=-1 and key==SectorGenerator.key(sector_coord))

func clear_region_hazards(key: String) -> void:
	for group in ["campaign_projectiles","acid_pools"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.region_key==key: node.get_parent().remove_child(node); node.queue_free()

func clear_base_hazards() -> void:
	clear_region_hazards("0:0")

func base_preparing() -> bool:
	return not waves.running and phase!="ended"

func return_hint() -> String:
	if sector_coord==Vector2i.ZERO: return "Você está no Núcleo (0,0)."
	var path: Array[String] = []
	if sector_coord.x!=0: path.append("%d setor(es) %s" % [absi(sector_coord.x),"Oeste" if sector_coord.x>0 else "Leste"])
	if sector_coord.y!=0: path.append("%d setor(es) %s" % [absi(sector_coord.y),"Norte" if sector_coord.y>0 else "Sul"])
	return "Núcleo (0,0): "+" + ".join(path)

func snapshot() -> Dictionary:
	var data := super.snapshot()
	data.format = 3
	data.horde_left = horde_left
	data.world_seed = world_seed
	data.rng_state = str(world_rng.state)
	data.visit_serial = visit_serial
	data.discovered = discovered.duplicate(true)
	return data

func migrate_snapshot(data: Variant) -> Variant:
	var converted = super.migrate_snapshot(data)
	if not converted is Dictionary or converted.get("format")!=2: return converted
	converted = converted.duplicate(true)
	converted.format = 3
	converted.horde_left = 210.0
	converted.world_seed = world_seed
	converted.rng_state = str(world_rng.state)
	converted.visit_serial = 0
	converted.discovered = {"0:0":{"visits":1,"risk":-1}}
	return converted

func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.get("format")!=3: return false
	for key in ["horde_left","world_seed","rng_state","visit_serial","discovered"]:
		if not data.has(key): return false
	if not bounded(data.horde_left,0,210) or not bounded(data.world_seed,1,2147483647) or not bounded(data.visit_serial,0,100000000): return false
	if not data.rng_state is String or not data.rng_state.is_valid_int() or not data.discovered is Dictionary or data.discovered.size()>8192 or not data.discovered.has("0:0"): return false
	for key in data.discovered:
		if not key is String: return false
		var parts: PackedStringArray = key.split(":")
		if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or absi(int(parts[0]))>4096 or absi(int(parts[1]))>4096: return false
		var item = data.discovered[key]
		if not item is Dictionary or not bounded(item.get("visits"),1,10000000) or not bounded(item.get("risk"),-1,4): return false
	var old: Dictionary = data.duplicate(true)
	old.format = 2
	return super.valid_snapshot(old)

func apply_snapshot(data: Dictionary) -> void:
	super.apply_snapshot(data)
	horde_left = float(data.horde_left)
	world_seed = int(data.world_seed)
	world_rng.seed = world_seed
	world_rng.state = int(data.rng_state)
	visit_serial = int(data.visit_serial)
	discovered = data.discovered.duplicate(true)
	waves.alarm_level = 0

func load_checkpoint() -> bool:
	if area_index!=-1 or phase!="prep": notify("Restaure na preparação do Núcleo."); return false
	var path := checkpoint_path()
	if not FileAccess.file_exists(path): path = save_path(game_mode)
	if not FileAccess.file_exists(path) and game_mode=="campaign": path = CHECKPOINT
	if not FileAccess.file_exists(path): notify("Nenhum refúgio salvo."); return false
	var data = migrate_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path)))
	if not valid_snapshot(data): notify("Checkpoint inválido: a partida atual foi preservada."); return false
	apply_snapshot(data)
	notify("Refúgio e relógio restaurados. Próxima horda em %d s." % ceili(horde_left))
	return true
