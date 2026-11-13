extends "res://scripts/systems/game_world.gd"
const CHECKPOINT = "user://zombie_bloom_arena_campaign.json"
static var resume_requested: bool = false
static var next_mode: String = "campaign"
var game_mode: String = "campaign"
var checkpoint_enabled: bool = true
var layout_revision: int = 0
var grenades: int = 2
var rockets: int = 0
var grenade_cooldown: float = 0
var vendor_tag: Label3D
var exit_tag: Label3D

static func save_path(mode: String) -> String:
	return "user://zombie_bloom_"+mode+"_v2.json"

func checkpoint_path() -> String:
	return save_path(game_mode)
var base_root := Node3D.new()
var field_root: Node3D
var base_arena: Arena
var area_index: int = -1
var areas: Array = []
var stock := {"wood":12,"parts":4}
var core_tier: int = 1
var vendor_pos := Vector3(-6,0,5)
var exit_pos := Vector3(0,0,24)
var vendor_rig: Node3D
var shop_clock: float = 0
var field_spawn_left: float = 0
var field_queue: Array[int] = []
var caches: Array[Node3D] = []

func _ready() -> void:
	game_mode = next_mode if next_mode in ["campaign","endless"] else "campaign"
	Controls.setup()
	GameSettings.load_settings()
	sunlight = VisualFactory.lighting(self)
	sunlight.shadow_enabled = GameSettings.shadows
	add_child(base_root)
	arena.free()
	arena = load("res://scripts/campaign/defense_arena.gd").new()
	base_arena = arena
	base_root.add_child(arena)
	add_child(effects)
	add_child(resources)
	add_child(audio)
	upgrades.world = self
	add_child(upgrades)
	waves.free()
	waves = wave_script().new()
	waves.world = self
	add_child(waves)
	core = CORE_SCENE.instantiate()
	core.world = self
	base_root.add_child(core)
	player = PLAYER_SCENE.instantiate()
	player.weapons.free()
	player.weapons = load("res://scripts/campaign/campaign_weapons.gd").new()
	player.world = self
	player.position = Vector3(3.8,0,4)
	add_child(player)
	player.weapons.owned.assign([true,false,false,false,false])
	player.weapons.cooldown = .4
	builder.free()
	builder = load("res://scripts/campaign/campaign_build.gd").new()
	builder.world = self
	add_child(builder)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 38
	camera.far = 200
	camera.position = player.position+camera_offset
	camera.look_at(player.position)
	camera.current = true
	hud = CanvasLayer.new()
	hud.set_script(hud_script())
	hud.world = self
	add_child(hud)
	resources.level_earned.connect(func(): hud.request_upgrade())
	for data in CampaignData.AREAS: areas.append({"dead":[],"cleared":false,"caches":[]})
	create_vendor()
	create_travel_markers()
	for pos in [Vector3(7,0,-4),Vector3(-7,0,4),Vector3(-5,0,-7),Vector3(7,0,7)]: spawn_pickup(pos,0,15)
	if resume_requested:
		resume_requested = false
		load_checkpoint()
	else:
		notify("NOVO REFÚGIO · B constrói · V negocia perto do vendedor · M escolhe uma área.")
		save_checkpoint(false)

func create_vendor() -> void:
	var stand := StaticBody3D.new()
	base_root.add_child(stand)
	stand.position = vendor_pos
	stand.collision_layer = 1
	VisualFactory.collider(stand,Vector3(2.6,1.4,1.6),Vector3(0,.7,0))
	VisualFactory.box(stand,Vector3(2.6,1,1.6),Vector3(0,.5,0),Color("596b62"))
	VisualFactory.box(stand,Vector3(3,.16,2),Vector3(0,2.6,0),Color("b6aa70"))
	for x in [-1.3,1.3]: VisualFactory.box(stand,Vector3(.12,2.5,.12),Vector3(x,1.25,0),Color("384c51"))
	var person := Node3D.new()
	stand.add_child(person)
	person.position = Vector3(0,0,-1.6)
	person.rotation.y = PI
	vendor_rig = VisualFactory.human(person,Color("a5966b"),false)
	var tag := VisualFactory.health_label(stand,3.5)
	vendor_tag = tag
	tag.font_size = 25
	tag.text = "BENTO / ARMEIRO\nV para negociar"

func _process(delta: float) -> void:
	super._process(delta)
	if phase == "ended": return
	grenade_cooldown = maxf(0,grenade_cooldown-delta)
	core.label.visible = area_index==-1 and player.position.distance_to(core.position)<4
	vendor_tag.visible = area_index==-1 and player.position.distance_to(vendor_pos)<7
	exit_tag.visible = area_index==-1 and player.position.distance_to(exit_pos)<7
	shop_clock += delta
	if area_index == -1: VisualFactory.animate_human(vendor_rig,shop_clock,.12,0,false)
	if area_index >= 0 and phase == "expedition":
		field_spawn_left -= delta
		if field_spawn_left <= 0 and not field_queue.is_empty() and get_tree().get_nodes_in_group("enemies").size()<12:
			var index: int = field_queue.pop_front()
			var positions := [Vector3(-42,0,-40),Vector3(42,0,-40),Vector3(0,0,-48),Vector3(-48,0,5),Vector3(48,0,5)]
			var kind := 0
			if area_index>=2 and index%9==0: kind = 5
			elif area_index>=1 and index%8==0: kind = 7
			elif index%5==0: kind = 6
			elif area_index>=3 and index%7==0: kind = 4
			elif area_index>=2 and index%4==0: kind = 3
			elif area_index>=1 and index%5==0: kind = 2
			elif index%3==0: kind = 1
			make_enemy(kind,positions[index%positions.size()],true,index)
			field_spawn_left = .75

func _unhandled_input(event: InputEvent) -> void:
	if phase == "ended" or not hud.mode.is_empty(): return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and builder.active:
		var origin := camera.project_ray_origin(event.position)
		var direction := camera.project_ray_normal(event.position)
		var point = Plane(Vector3.UP,0).intersects_ray(origin,direction)
		if point!=null:
			builder.location = Vector3(snappedf(point.x,1),0,snappedf(point.z,1))
			builder.place()
		return
	if event.is_action_pressed("sector_map"): hud.show_routes()
	elif event.is_action_pressed("vendor"): open_shop()
	elif event.is_action_pressed("grenade"): throw_grenade()
	elif event.is_action_pressed("slot_4") and not builder.active: player.weapons.equip(3)
	elif event.is_action_pressed("slot_5") and not builder.active: player.weapons.equip(4)
	elif event.is_action_pressed("save_campaign"): save_checkpoint()
	elif event.is_action_pressed("load_campaign"): load_checkpoint()
	elif event.is_action_pressed("upgrade_piece"): improve_nearby()
	elif event.is_action_pressed("remove_piece"): hud.confirm_dismantle()
	elif event.is_action_pressed("use_gate"): toggle_nearby_gate()
	elif event.is_action_pressed("interact") and area_index>=0: field_interact()
	else: super._unhandled_input(event)

func make_enemy(kind: int,pos: Vector3,field: bool,index: int) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/campaign/campaign_enemy.gd"))
	enemy.spec = CampaignData.enemy_spec(kind)
	enemy.world = self
	enemy.field_enemy = field
	enemy.encounter_index = index
	enemy.position = pos
	(field_root if field else base_root).add_child(enemy)
	return enemy

func spawn_pickup(pos: Vector3,experience: int,metal: int,power: String = "") -> Node3D:
	var drops := get_tree().get_nodes_in_group("pickups")
	if drops.size()>=256:
		if power.is_empty():
			for existing in drops:
				if existing.power.is_empty() and not existing.collected:
					existing.xp += experience
					existing.scrap += metal
					return existing
		else: return null
	var pickup := Node3D.new()
	pickup.set_script(PICKUP_SCRIPT)
	pickup.world = self
	pickup.position = pos
	pickup.xp = experience
	pickup.scrap = metal
	pickup.power = power
	(field_root if area_index>=0 else base_root).add_child(pickup)
	return pickup

func enemy_defeated(enemy: Node3D) -> void:
	super.enemy_defeated(enemy)
	if area_index>=0 and enemy.field_enemy:
		if not enemy.encounter_index in areas[area_index].dead: areas[area_index].dead.append(enemy.encounter_index)
		if areas[area_index].dead.size() >= CampaignData.AREAS[area_index].count:
			areas[area_index].cleared = true
			notify("ÁREA LIMPA · Aproxime-se das três reservas e pressione E. A saída fica ao sul.")

func can_pay(cost: Dictionary) -> bool:
	return resources.scrap>=int(cost.get("scrap",0)) and stock.wood>=int(cost.get("wood",0)) and stock.parts>=int(cost.get("parts",0))

func pay(cost: Dictionary) -> bool:
	for key in cost:
		if key not in ["scrap","wood","parts"] or float(cost[key])<0: return false
	if not can_pay(cost):
		notify("Materiais insuficientes · "+CampaignData.cost_text(cost))
		return false
	resources.scrap -= int(cost.get("scrap",0))
	stock.wood -= int(cost.get("wood",0))
	stock.parts -= int(cost.get("parts",0))
	return true

func credit(key: String,amount: int) -> void:
	if key == "scrap": resources.scrap += amount
	else: stock[key] += amount

func buy_weapon(index: int) -> bool:
	if area_index!=-1 or phase!="prep" or player.position.distance_to(vendor_pos)>5 or index not in [1,2,3,4] or player.weapons.owned[index]: return false
	var price: int = CampaignData.PRICES[index]
	if not pay({"scrap":price}): return false
	player.weapons.owned[index] = true
	player.weapons.ammo[index] = player.weapons.capacity(index)
	if index==4: rockets += 5
	player.weapons.equip(index)
	notify("%s comprada. Equipe com %d." % [CampaignData.WEAPONS[index].title,index+1])
	return true

func shop_service(id: String) -> bool:
	if area_index!=-1 or phase!="prep" or player.position.distance_to(vendor_pos)>5: return false
	match id:
		"heal":
			if player.health.current>=player.health.maximum or not pay({"scrap":25}): return false
			player.health.heal(60)
		"wood":
			if not pay({"scrap":30}): return false
			stock.wood += 10
		"parts":
			if not pay({"scrap":45}): return false
			stock.parts += 4
		"grenades":
			if not pay({"scrap":45}): return false
			grenades += 3
		"rockets":
			if not player.weapons.owned[4] or not pay({"scrap":60}): return false
			rockets += 5
		_: return false
	return true

func open_shop() -> void:
	if phase!="prep" or area_index!=-1: notify("O armeiro negocia no refúgio entre hordas.")
	elif player.position.distance_to(vendor_pos)>5: notify("Aproxime-se da barraca do Bento, à esquerda do Núcleo.")
	else:
		builder.set_active(false)
		hud.show_shop()

func nearest_structure() -> Node3D:
	var nearest: Node3D
	var distance := 4.5
	for s in get_tree().get_nodes_in_group("buildings"):
		var d: float = player.position.distance_to(s.position)
		if d<distance:
			nearest = s
			distance = d
	return nearest

func improve_nearby() -> bool:
	if phase!="prep" or area_index!=-1: return false
	var s := nearest_structure()
	if s == null: notify("Aproxime-se de uma defesa ou do Núcleo para melhorar."); return false
	if s == core:
		if core_tier>=4: notify("Núcleo no nível máximo."); return false
		var price := {"scrap":75*core_tier,"wood":10*core_tier,"parts":5*core_tier}
		if not pay(price): return false
		core_tier += 1
		core.health.maximum += 250
		core.health.heal(250)
		refresh_core_model()
		notify("NÚCLEO N%d · %d de integridade máxima." % [core_tier,core.health.maximum])
		return true
	if not s.improve(): notify("Melhoria recusada: nível máximo ou materiais insuficientes."); return false
	return true

func toggle_nearby_gate() -> bool:
	for s in get_tree().get_nodes_in_group("campaign_structure"):
		if s.spec.id=="gate" and s.position.distance_to(player.position)<4: return s.toggle()
	notify("F abre ou fecha um portão próximo.")
	return false

func refresh_core_model() -> void:
	for child in core.model.get_children():
		if child.name.begins_with("Fortify_"):
			core.model.remove_child(child)
			child.queue_free()
	for i in range(1,core_tier):
		var ring := VisualFactory.ring(core.model,1.3+i*.3,Vector3(0,.5+i*.4,0),Color("d4f889"))
		ring.name = "Fortify_%d" % i

func travel(index: int) -> bool:
	if area_index!=-1 or phase!="prep" or index<0 or index>=areas.size() or waves.wave<int(CampaignData.AREAS[index].wave) or resources.pending>0: return false
	builder.set_active(false)
	hud.close_modal()
	clear_hazards()
	remove_child(base_root)
	area_index = index
	field_root = Node3D.new()
	add_child(field_root)
	var field: Arena = load("res://scripts/campaign/campaign_arena.gd").new()
	field.area = index
	field_root.add_child(field)
	arena = field
	player.position = Vector3(0,0,22)
	player.velocity = Vector3.ZERO
	player.invulnerable = 1
	camera.position = player.position*.82+camera_offset
	phase = "expedition"
	field_queue.clear()
	for i in range(CampaignData.AREAS[index].count):
		if not i in areas[index].dead: field_queue.append(i)
	field_spawn_left = 1.8
	caches.clear()
	for i in range(3):
		var cache := Node3D.new()
		field_root.add_child(cache)
		cache.position = [Vector3(-5,0,-17),Vector3(5,0,-2),Vector3(-4,0,12)][i]
		VisualFactory.box(cache,Vector3(1.3,.9,1.1),Vector3(0,.45,0),Color("b0a471"))
		var label := VisualFactory.health_label(cache,1.7)
		label.text = "RESERVA %d\nE / RECOLHER" % (i+1)
		cache.visible = not i in areas[index].caches
		caches.append(cache)
	notify(CampaignData.AREAS[index].title+" · Elimine os hostis, recolha as reservas e retorne pela saída ao sul.")
	return true

func field_interact() -> bool:
	if player.position.distance_to(Vector3(0,0,24))<4: return return_to_base()
	for i in range(caches.size()):
		if player.position.distance_to(caches[i].position)<3: return collect_cache(i)
	notify("E recolhe uma reserva próxima ou retorna pela zona de extração ao sul.")
	return false

func collect_cache(index: int) -> bool:
	if area_index<0 or index<0 or index>=3 or index in areas[area_index].caches: return false
	if not areas[area_index].cleared: notify("Limpe todos os infectados desta área antes de recolher as reservas."); return false
	if player.position.distance_to(caches[index].position)>3: return false
	var reward: Dictionary = CampaignData.AREAS[area_index].reward
	var paid := {}
	for key in reward:
		var quantity := int(reward[key])/3 + (1 if index<int(reward[key])%3 else 0)
		credit(key,quantity)
		paid[key] = quantity
	areas[area_index].caches.append(index)
	caches[index].hide()
	notify("RESERVA RECUPERADA · "+CampaignData.cost_text(paid))
	return true

func return_to_base() -> bool:
	if area_index<0 or phase!="expedition" or player.position.distance_to(Vector3(0,0,24))>=4: return false
	# All loose drops are collected on extraction; deaths/cache claims remain finite.
	for p in get_tree().get_nodes_in_group("pickups"): p.collect()
	if not hud.mode.is_empty(): hud.close_modal()
	clear_hazards()
	remove_child(field_root)
	field_root.queue_free()
	field_root = null
	caches.clear()
	area_index = -1
	arena = base_arena
	add_child(base_root)
	player.position = Vector3(0,0,21)
	player.velocity = Vector3.ZERO
	camera.position = player.position*.82+camera_offset
	phase = "prep"
	notify("DE VOLTA AO REFÚGIO · Materiais mantidos. B constrói; G melhora; E repara.")
	if resources.pending==0: save_checkpoint(false)
	return true

func save_checkpoint(show_notice: bool = true) -> bool:
	if not checkpoint_enabled: return false
	if area_index!=-1 or phase!="prep" or resources.pending>0:
		if show_notice: notify("Salve no refúgio entre hordas, após escolher as melhorias de XP.")
		return false
	var data := snapshot()
	if not valid_snapshot(data): notify("Estado atual não pôde ser validado para salvar."); return false
	var file := FileAccess.open(checkpoint_path()+".tmp",FileAccess.WRITE)
	if file==null: notify("Falha ao gravar o checkpoint."); return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var dst := ProjectSettings.globalize_path(checkpoint_path())
	if FileAccess.file_exists(checkpoint_path()): DirAccess.copy_absolute(dst,dst+".bak")
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(checkpoint_path()+".tmp"),dst)
	if error!=OK: notify("Não foi possível concluir o checkpoint."); return false
	if show_notice: notify("Refúgio salvo. F9 restaura o último checkpoint.")
	return true

func snapshot() -> Dictionary:
	var structures: Array = []
	for s in get_tree().get_nodes_in_group("campaign_structure"):
		structures.append({"piece":s.piece_index,"tier":s.tier,"hp":s.health.current,"pos":[s.position.x,s.position.z],"angle":s.rotation.y,"open":s.opened,"invested":s.invested.duplicate()})
	var drops: Array = []
	for p in get_tree().get_nodes_in_group("pickups"):
		if not p.collected: drops.append({"pos":[p.position.x,p.position.z],"xp":p.xp,"scrap":p.scrap,"power":p.power})
	var gun: WeaponSystem = player.weapons
	return {"format":2,"mode":game_mode,"grenades":grenades,"rockets":rockets,"wave":waves.wave,"stock":stock.duplicate(),"scrap":resources.scrap,"level":resources.level,"xp":resources.xp,"kills":kills,"elapsed":elapsed,"areas":areas.duplicate(true),"core_tier":core_tier,"core_hp":core.health.current,"hp":player.health.current,"max_hp":player.health.maximum,"position":[player.position.x,player.position.z],"owned":gun.owned.duplicate(),"ammo":gun.ammo.duplicate(),"slot":gun.slot,"gun":[gun.damage_multiplier,gun.rate_multiplier,gun.capacity_multiplier,gun.reload_multiplier,gun.level],"speed":player.speed_multiplier,"upgrades":upgrades.levels.duplicate(),"structures":structures,"drops":drops}

func load_checkpoint() -> bool:
	if area_index!=-1 or phase!="prep": notify("Restaure no refúgio entre hordas."); return false
	var path := checkpoint_path()
	if not FileAccess.file_exists(path) and game_mode=="campaign": path = CHECKPOINT
	if not FileAccess.file_exists(path): notify("Nenhum refúgio salvo."); return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	data = migrate_snapshot(data)
	if not valid_snapshot(data): notify("Checkpoint inválido: o refúgio atual foi preservado."); return false
	apply_snapshot(data)
	notify("Refúgio restaurado · horda %d concluída." % waves.wave)
	return true

func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in ["format","mode","grenades","rockets","wave","stock","scrap","level","xp","kills","elapsed","areas","core_tier","core_hp","hp","max_hp","position","owned","ammo","slot","gun","speed","upgrades","structures","drops"]:
		if not data.has(key): return false
	if data.format!=2 or data.mode!=game_mode or not bounded(data.grenades,0,100000) or not bounded(data.rockets,0,100000) or not bounded(data.wave,0,19 if game_mode=="campaign" else 100000000) or not bounded(data.scrap,0,10000000) or not bounded(data.level,1,10000) or not bounded(data.xp,0,10000000) or not bounded(data.kills,0,10000000) or not bounded(data.elapsed,0,100000000) or not bounded(data.core_tier,1,4): return false
	if not bounded(data.max_hp,100,1000000) or not bounded(data.hp,1,data.max_hp) or not bounded(data.core_hp,1,600+250*(data.core_tier-1)) or not bounded(data.speed,.1,1000): return false
	if not point_valid(data.position) or not data.stock is Dictionary or not data.upgrades is Dictionary: return false
	for key in data.upgrades:
		if key not in ["damage","rate","capacity","reload","speed","health"] or not bounded(data.upgrades[key],0,10000): return false
	for key in ["wood","parts"]:
		if not data.stock.has(key) or not bounded(data.stock[key],0,10000000): return false
	if not data.owned is Array or data.owned.size()!=5 or data.owned[0]!=true or not data.ammo is Array or data.ammo.size()!=5 or not bounded(data.slot,0,4): return false
	for i in range(5):
		if not data.owned[i] is bool or not bounded(data.ammo[i],0,100000): return false
	if data.ammo[4]>1: return false
	if not data.owned[int(data.slot)] or not data.gun is Array or data.gun.size()!=5: return false
	for value in data.gun:
		if not bounded(value,.01,100000): return false
	if not data.areas is Array or data.areas.size()!=4 or not data.structures is Array or data.structures.size()>120 or not data.drops is Array or data.drops.size()>2000: return false
	for i in range(4):
		var area = data.areas[i]
		if not area is Dictionary or not area.get("dead") is Array or not area.get("caches") is Array or not area.get("cleared") is bool: return false
		if not unique_indices(area.dead,int(CampaignData.AREAS[i].count)) or not unique_indices(area.caches,3) or area.cleared!=(area.dead.size()==int(CampaignData.AREAS[i].count)) or (not area.cleared and not area.caches.is_empty()): return false
	for s in data.structures:
		if not s is Dictionary: return false
		for key in ["piece","tier","hp","pos","angle","open","invested"]:
			if not s.has(key): return false
		if not bounded(s.piece,0,5) or not bounded(s.tier,1,3) or not point_valid(s.pos) or not bounded(s.angle,0,TAU) or not s.open is bool: return false
		if not bounded(s.hp,.01,float(CampaignData.PIECES[int(s.piece)].health)*(1+.65*(s.tier-1))+.001) or not s.invested is Dictionary: return false
		for key in ["scrap","wood","parts"]:
			if not s.invested.has(key) or not bounded(s.invested[key],0,100000): return false
	for p in data.drops:
		if not p is Dictionary or not point_valid(p.get("pos")) or not bounded(p.get("xp"),0,100000) or not bounded(p.get("scrap"),0,100000) or p.get("power") not in ["","speed","rapid","shield"]: return false
	return true

func bounded(value: Variant,minimum: float,maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum

func point_valid(value: Variant) -> bool:
	return value is Array and value.size()==2 and bounded(value[0],-55,55) and bounded(value[1],-55,55)

func unique_indices(values: Array,limit: int) -> bool:
	var seen := {}
	for value in values:
		if not bounded(value,0,limit-1) or float(value)!=int(value) or seen.has(int(value)): return false
		seen[int(value)] = true
	return true

func apply_snapshot(data: Dictionary) -> void:
	clear_hazards()
	layout_revision += 1
	grenades = int(data.grenades)
	rockets = int(data.rockets)
	builder.set_active(false)
	for s in get_tree().get_nodes_in_group("campaign_structure"):
		s.get_parent().remove_child(s)
		s.queue_free()
	for p in get_tree().get_nodes_in_group("pickups"):
		p.get_parent().remove_child(p)
		p.queue_free()
	waves.wave = int(data.wave)
	waves.to_spawn = 0
	waves.running = false
	stock = {"wood":int(data.stock.wood),"parts":int(data.stock.parts)}
	resources.scrap = int(data.scrap)
	resources.level = int(data.level)
	resources.xp = int(data.xp)
	resources.pending = 0
	upgrades.offers.clear()
	upgrades.levels = data.upgrades.duplicate()
	kills = int(data.kills)
	elapsed = float(data.elapsed)
	areas = data.areas.duplicate(true)
	core_tier = int(data.core_tier)
	core.health.setup(600+250*(core_tier-1))
	core.health.current = float(data.core_hp)
	refresh_core_model()
	player.health.setup(data.max_hp)
	player.health.current = float(data.hp)
	player.position = Vector3(data.position[0],0,data.position[1])
	player.velocity = Vector3.ZERO
	player.speed_multiplier = data.speed
	player.powers.clear()
	player.shield = 0
	var gun: WeaponSystem = player.weapons
	gun.owned.assign(data.owned)
	gun.ammo.assign(data.ammo)
	gun.slot = int(data.slot)
	gun.damage_multiplier = data.gun[0]
	gun.rate_multiplier = data.gun[1]
	gun.capacity_multiplier = data.gun[2]
	gun.reload_multiplier = data.gun[3]
	gun.level = int(data.gun[4])
	gun.cooldown = .2
	gun.reload_left = 0
	for s in data.structures:
		var structure := StaticBody3D.new()
		structure.set_script(load("res://scripts/campaign/campaign_structure.gd"))
		structure.world = self
		structure.piece_index = int(s.piece)
		structure.tier = int(s.tier)
		structure.position = Vector3(s.pos[0],0,s.pos[1])
		structure.rotation.y = float(s.angle)
		structure.invested = s.invested.duplicate()
		base_root.add_child(structure)
		structure.health.current = float(s.hp)
		if s.open and structure.spec.id=="gate": structure.toggle()
	for p in data.drops: spawn_pickup(Vector3(p.pos[0],0,p.pos[1]),int(p.xp),int(p.scrap),p.power)
	if not hud.mode.is_empty(): hud.close_modal()

func _exit_tree() -> void:
	if not base_root.is_inside_tree(): base_root.free()

func migrate_snapshot(data: Variant) -> Variant:
	if not data is Dictionary or data.get("format")!=1: return data
	var converted: Dictionary = data.duplicate(true)
	if not converted.get("owned") is Array or converted.owned.size()!=3 or not converted.get("ammo") is Array or converted.ammo.size()!=3: return data
	converted.format = 2
	converted.mode = "campaign"
	converted.grenades = 2
	converted.rockets = 0
	converted.owned.append_array([false,false])
	converted.ammo.append_array([40,0])
	return converted

func clear_hazards() -> void:
	for group in ["campaign_projectiles","acid_pools"]:
		for node in get_tree().get_nodes_in_group(group):
			node.get_parent().remove_child(node)
			node.queue_free()

func projectile(kind: String,from: Vector3,to: Vector3,power: float,radius: float,travel_time: float) -> Node3D:
	if get_tree().get_nodes_in_group("campaign_projectiles").size()>=32: return null
	var shot := Node3D.new()
	shot.set_script(load("res://scripts/campaign/campaign_projectile.gd"))
	shot.world = self
	shot.kind = kind
	shot.start = from
	shot.destination = to
	shot.damage = power
	shot.radius = radius
	shot.life = travel_time
	add_child(shot)
	return shot

func throw_grenade() -> bool:
	if phase not in ["combat","expedition"] or builder.active or not hud.mode.is_empty(): return false
	if grenades<=0: notify("Sem granadas. Compre com Bento."); return false
	if grenade_cooldown>0: return false
	var point := mouse_ground(0)
	var offset := point-player.position
	offset.y = 0
	if offset.length()>18: offset = offset.normalized()*18
	if projectile("grenade",player.position+Vector3(0,1.2,0),player.position+offset+Vector3(0,.15,0),105,4.5,.85)==null: return false
	grenades -= 1
	grenade_cooldown = 1.5
	return true

func explode(point: Vector3,radius: float,power: float) -> void:
	effects.burst(point,Color("f6b666"),14)
	effects.flash(point)
	audio.play_tone(65,.25,.18)
	var ring := VisualFactory.ring(effects,radius,point,Color("e6b762"))
	var fade := create_tween()
	fade.tween_property(ring,"scale",Vector3.ONE*.01,.4)
	fade.tween_callback(ring.queue_free)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var target_point: Vector3 = enemy.global_position+Vector3(0,enemy.aim_height,0)
		var d := point.distance_to(target_point)
		if d>radius: continue
		var ray := PhysicsRayQueryParameters3D.create(point+Vector3(0,.25,0),target_point,1|8)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		enemy.take_damage(power*lerpf(1,.45,d/radius))
	if player.position.distance_to(point)<radius*.7: player.take_damage(power*.25)

func spawn_acid(point: Vector3,radius: float,power: float) -> Node3D:
	if get_tree().get_nodes_in_group("acid_pools").size()>=16: return null
	var pool := Node3D.new()
	pool.set_script(load("res://scripts/campaign/acid_pool.gd"))
	pool.world = self
	pool.position = point
	pool.radius = radius
	pool.damage = power
	add_child(pool)
	return pool

func air_aim(origin: Vector3,direction: Vector3,range_limit: float) -> Vector3:
	var nearest: Node3D
	var distance := range_limit
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.spec.id not in ["hound","flyer"]: continue
		var offset: Vector3 = enemy.global_position-origin
		offset.y = 0
		var forward := offset.dot(direction)
		if forward<=0 or forward>=distance: continue
		if (offset-direction*forward).length()>.85: continue
		nearest = enemy
		distance = forward
	if nearest==null: return direction
	return (nearest.global_position+Vector3(0,nearest.aim_height,0)-origin).normalized()

func wave_script() -> Script:
	return load("res://scripts/campaign/campaign_waves.gd")

func hud_script() -> Script:
	return load("res://scripts/campaign/campaign_hud.gd")

func exit_positions() -> Array:
	return [exit_pos]

func access_origins() -> Array[Vector2i]:
	return [Vector2i(0,24)]

func create_travel_markers() -> void:
	VisualFactory.ring(base_root,3,exit_pos+Vector3(0,.08,0),Color("b8de80"))
	var sign := VisualFactory.health_label(base_root,2)
	exit_tag = sign
	sign.font_size = 25
	sign.position = exit_pos+Vector3(0,2,0)
	sign.text = "ROTAS DE COLETA\nM / ÁREAS"
