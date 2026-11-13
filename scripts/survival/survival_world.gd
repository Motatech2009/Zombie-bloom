extends "res://scripts/sectors/roaming_world.gd"
var is_client: bool = false
var network: Node
var avatars: Dictionary = {}
var profiles: Dictionary = {}
var depot_items: Dictionary = {}
var built_this_round: int = 0
var next_uid: int = 1
var client_enemies: Dictionary = {}
var client_structures: Dictionary = {}
var client_loot: Dictionary = {}
var client_hazards: Dictionary = {}
var last_scene_revision: int = -1
var scene_revision: int = 0
var shot_owner: int = 1

static func survival_path(mode: String) -> String:
	return "user://zombie_bloom_"+mode+"_v4.json"

func checkpoint_path() -> String: return survival_path(game_mode)
func hud_script() -> Script: return load("res://scripts/survival/survival_hud.gd")
func wave_script() -> Script: return load("res://scripts/survival/survival_waves.gd")
func builder_script() -> Script: return load("res://scripts/survival/survival_build.gd")
func weapon_script() -> Script: return load("res://scripts/survival/survival_weapons.gd")
func create_starting_loot() -> void: pass

func make_player() -> CharacterBody3D:
	var actor := CharacterBody3D.new()
	actor.set_script(load("res://scripts/survival/survivor.gd"))
	starter_bag(actor.bag)
	avatars[1] = actor
	return actor

func starter_bag(bag: ItemBag) -> void:
	bag.add("pistol",1)
	bag.add("light",48)
	bag.add("grenade",1)
	bag.add("medkit",1)

func _ready() -> void:
	network = get_node_or_null("/root/Coop")
	is_client = network!=null and network.mode=="client"
	if is_client: checkpoint_enabled = false
	resources.scrap = 85
	stock = {"wood":6,"parts":2}
	super._ready()
	player.weapons.sync_hand()
	if network!=null and network.mode=="host": player.display_name = network.nickname
	if is_client:
		player.proxy = true
		waves.set_physics_process(false)
		core.set_physics_process(false)
	if network!=null: network.bind_world(self)
	notify("BOLSA 18 espaços · 1–9 barra rápida · Segure E para coletar · Deposite no Núcleo · I mochila")

func party_count() -> int: return maxi(1,avatars.size())
func team_multiplier() -> int: return 1 << (mini(4,party_count())-1)
func build_quota() -> int: return mini(12,6+waves.wave/3)
func connected_game() -> bool: return network!=null and network.mode in ["host","client"]

func local_input(actor: Node3D) -> Dictionary:
	var blocked: bool = hud!=null and not hud.mode.is_empty()
	var hovering_button := get_viewport().gui_get_hovered_control() is Button
	var mouse_aim := mouse_ground(1.15)-actor.position
	mouse_aim.y = 0
	return {"move":Vector2.ZERO if blocked else Input.get_vector("move_left","move_right","move_up","move_down"),"aim":mouse_aim.normalized(),"sprint":not blocked and Input.is_action_pressed("sprint"),"fire":not blocked and not hovering_button and Input.is_action_pressed("fire"),"reload":not blocked and Input.is_action_pressed("reload"),"interact":not blocked and Input.is_action_pressed("interact"),"slot":actor.bag.selected}

func _process(delta: float) -> void:
	if is_client:
		var target: Vector3 = sector_offset(sector_coord)+(player.position-sector_offset(sector_coord))*.82
		camera.position = camera.position.lerp(target+camera_offset,1-exp(-delta*5))
		camera.look_at(target)
		for actor in avatars.values():
			actor.position = actor.position.lerp(actor.target_position,minf(1,delta*14))
			VisualFactory.animate_human(actor.rig,Time.get_ticks_msec()/1000.0,actor.position.distance_to(actor.target_position),0,true)
		for enemy in client_enemies.values(): enemy.position = enemy.position.lerp(enemy.get_meta("target",enemy.position),minf(1,delta*14))
		notice_left = maxf(0,notice_left-delta)
		return
	super._process(delta)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.label.hide()
	for cache in caches:
		if cache.has_meta("weapon"):
			cache.visible = not int(cache.get_meta("index")) in claimed and avatars.values().any(func(actor): return actor.position.distance_to(cache.global_position)<10)
	if resources.pending>0 and upgrades.offers.is_empty(): upgrades.roll()
	grenades = player.bag.count("grenade")
	rockets = player.bag.count("rocket")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if hud.mode=="inventory": hud.close_modal()
		elif hud.mode.is_empty(): hud.show_inventory()
		return
	if not builder.active:
		for i in range(9):
			if event.is_action_pressed("slot_%d" % (i+1)):
				player.bag.selected = i
				if not is_client: player.weapons.sync_hand()
				return
	if event.is_action_pressed("grenade") and hud.mode.is_empty(): send_action("grenade",{}); return
	if event.is_action_pressed("interact"):
		if hud.mode.is_empty():
			for i in range(4):
				if local_player().distance_to(SectorGenerator.EXITS[i])<3.7: send_action("travel",{"direction":i}); break
		return
	if is_client:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: builder.set_active(false)
		if event.is_action_pressed("sector_map") and hud.mode.is_empty(): hud.show_routes()
		elif event.is_action_pressed("vendor") and hud.mode.is_empty(): open_shop()
		elif event.is_action_pressed("build"):
			if builder.active: builder.set_active(false)
		elif event.is_action_pressed("upgrade_piece"): send_action("upgrade",{})
		elif event.is_action_pressed("use_gate"): send_action("gate",{})
		elif event.is_action_pressed("remove_piece"): hud.confirm_dismantle()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and builder.active:
			var point = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
			if point!=null: builder.location = Vector3(snappedf(point.x,1),0,snappedf(point.z,1)); builder.place()
		return
	super._unhandled_input(event)

func send_action(action: String,data: Dictionary) -> void:
	if is_client: network.command(action,data)
	else: perform_action(1,action,data)

func perform_action(peer: int,action: String,data: Dictionary) -> bool:
	if is_client or not avatars.has(peer) or phase=="ended": return false
	var actor: Node3D = avatars[peer]
	if actor.health.dead: return false
	var saved: CharacterBody3D = player
	player = actor
	var result := false
	match action:
		"grenade": result = throw_for(actor)
		"travel":
			if data.get("direction") is int: result = step_sector(data.direction)
		"buy":
			if data.get("weapon") is int: result = buy_weapon(data.weapon)
		"service":
			if data.get("id") is String: result = shop_service(data.id)
		"swap":
			if data.get("a") is int and data.get("b") is int: result = actor.bag.swap(data.a,data.b)
		"withdraw":
			if data.get("id") is String: result = withdraw(actor,data.id,mini(20,int(data.get("qty",1))))
		"store":
			if data.get("slot") is int: result = store_slot(actor,data.slot)
		"drop":
			if data.get("slot") is int: result = drop_slot(actor,data.slot)
		"upgrade": result = improve_nearby()
		"gate": result = toggle_nearby_gate()
		"dismantle":
			var target := nearest_structure()
			if target!=null and target!=core: result = target.dismantle()
		"choice":
			if data.get("index") is int: result = choose_team_upgrade(data.index)
		"build":
			var pos = data.get("pos")
			var piece = data.get("piece")
			var angle = data.get("angle")
			if pos is Vector3 and piece is int and piece>=0 and piece<6 and (angle is float or angle is int) and is_finite(pos.x) and is_finite(pos.z) and is_finite(float(angle)):
				var previous := {"active":builder.active,"location":builder.location,"selected":builder.selected,"angle":builder.angle}
				builder.active = true
				builder.location = Vector3(snappedf(pos.x,1),0,snappedf(pos.z,1))
				builder.selected = piece
				builder.angle = fposmod(snappedf(float(angle),PI/2),TAU)
				result = builder.place()!=null
				builder.active = previous.active
				builder.location = previous.location
				builder.selected = previous.selected
				builder.angle = previous.angle
	player = saved
	return result

func step_sector(direction: int) -> bool:
	if is_client: return false
	if direction<0 or direction>3: return false
	for actor in avatars.values():
		if actor.health.dead: continue
		if (actor.position-sector_offset(sector_coord)).distance_to(SectorGenerator.EXITS[direction])>6:
			notify("Reúna o grupo na mesma saída. O cooperativo viaja junto entre setores.")
			return false
	var save_enabled := checkpoint_enabled
	checkpoint_enabled = false
	var traveled := super.step_sector(direction)
	checkpoint_enabled = save_enabled
	if not traveled: return false
	var entry := player.position
	var i := 0
	for actor in avatars.values():
		actor.cancel_gather()
		if actor!=player: actor.position = entry+Vector3(i%2*1.2,0,i/2*1.2)
		i += 1
	if area_index!=-1: scale_field_population()
	scene_revision += 1
	if area_index==-1 and phase=="prep" and resources.pending==0: save_checkpoint(false)
	return true

func scale_field_population() -> void:
	if descriptor.is_empty(): return
	if not descriptor.has("base_count"): descriptor.base_count = descriptor.count; descriptor.base_roster = descriptor.roster.duplicate()
	descriptor.count = int(descriptor.base_count)*team_multiplier()
	descriptor.roster.clear()
	for i in range(descriptor.count):
		var kind: int = descriptor.base_roster[i%maxi(1,descriptor.base_roster.size())]
		if i>0 and kind==8: kind = 4
		if descriptor.risk>=2 and i%13==0 and i>0: kind = 9+i%3
		descriptor.roster.append(kind)
	field_queue.clear()
	var normal_alive := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.field_enemy and enemy.encounter_index>=0: normal_alive += 1
	for i in range(maxi(0,field_dead+normal_alive),descriptor.count): field_queue.append(i)

func next_id() -> int:
	var result := next_uid
	next_uid += 1
	return result

func make_enemy(kind: int,pos: Vector3,field: bool,index: int) -> Node3D:
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/survival/survival_enemy.gd"))
	enemy.enemy_kind = kind
	enemy.net_id = next_id()
	if kind==8: enemy.spec = SectorGenerator.boss_spec(maxi(1,waves.wave if not field else maxi(waves.wave,SectorGenerator.distance(sector_coord)+2)))
	elif kind<9: enemy.spec = CampaignData.enemy_spec(kind)
	else:
		enemy.spec = GameSpec.new()
		enemy.spec.id = ["burster","screamer","mender"][clampi(kind-9,0,2)]
		enemy.spec.title = ["Estourador","Berrador","Regenerador"][clampi(kind-9,0,2)]
		enemy.spec.color = [Color("c16d4a"),Color("a67baf"),Color("5eb38e")][clampi(kind-9,0,2)]
		enemy.spec.values = {"health":85.0 if kind==9 else 120.0,"speed":2.6 if kind==9 else 1.8,"damage":14.0,"interval":1.1,"scale":1.0,"xp":12,"scrap":8}
	enemy.is_boss = kind==8
	enemy.world = self
	enemy.field_enemy = field
	enemy.encounter_index = index
	enemy.position = pos
	(field_root if field else base_root).add_child(enemy)
	if not field: enemy.add_to_group("wave_enemies")
	if kind==8: enemy.add_to_group("boss_enemies")
	return enemy

func spawn_minion(parent: Node3D,kind: int,index: int) -> void:
	if get_tree().get_nodes_in_group("enemies").size()>=72: return
	var root_node: Node3D = field_root if parent.field_enemy else base_root
	var pos: Vector3 = parent.global_position-root_node.global_position+Vector3(1.5+index,0,1)
	make_enemy(kind,pos,parent.field_enemy,-1)

func hostile_blast(point: Vector3,radius: float,damage: float) -> void:
	if is_client: return
	effects.burst(point,Color("e79a65"),12)
	for body in get_tree().get_nodes_in_group("damageable"):
		if body.is_in_group("enemies") or body.health.dead: continue
		var offset: Vector3 = body.global_position-point
		offset.y = 0
		if offset.length()<radius: body.take_damage(damage)

func enemy_defeated(enemy: Node3D) -> void:
	if enemy.encounter_index<0:
		if enemy.is_in_group("wave_enemies"): enemy.remove_from_group("wave_enemies")
		kills += 1
		return
	super.enemy_defeated(enemy)

func create_caches() -> void:
	super.create_caches()
	for i in range(caches.size()):
		var contents := {}
		if caches[i].has_meta("weapon"):
			contents[ItemBag.WEAPON_IDS[int(caches[i].get_meta("weapon"))]] = 1
		else:
			for id in descriptor.reward: contents[id] = maxi(1,int(descriptor.reward[id]*.45)/3+(1 if i<int(descriptor.reward[id]*.45)%3 else 0))
		caches[i].set_meta("contents",contents)
		caches[i].set_meta("uid",next_id())
		caches[i].add_to_group("survival_sources")

func spawn_pickup(pos: Vector3,experience: int,metal: int,power: String = "") -> Node3D:
	if metal<=0 and experience<=0 and power.is_empty(): return null
	return spawn_loot(pos,{"scrap":maxi(1,metal/2)} if metal>0 else {},experience,power)

func spawn_loot(pos: Vector3,contents: Dictionary,experience: int = 0,power: String = "",loaded: int = 0) -> Node3D:
	var parent: Node3D = base_root if region_at(pos)=="0:0" else field_root
	if parent==null: return null
	var items := get_tree().get_nodes_in_group("survival_loot")
	if items.size()>=128:
		for pile in items:
			if pile.get_parent()==parent and pile.power.is_empty() and power.is_empty() and loaded==0 and not contents.keys().any(func(id): return id in ItemBag.WEAPON_IDS):
				for id in contents: pile.contents[id] = int(pile.contents.get(id,0))+int(contents[id])
				pile.set_meta("xp",int(pile.get_meta("xp",0))+experience)
				return pile
		return null
	var loot := Node3D.new()
	loot.set_script(load("res://scripts/survival/survival_loot.gd"))
	loot.world = self
	loot.uid = next_id()
	loot.contents = contents.duplicate()
	loot.power = power
	loot.loaded = loaded
	loot.position = pos-parent.global_position
	loot.set_meta("contents",loot.contents)
	loot.set_meta("uid",loot.uid)
	loot.set_meta("xp",experience)
	loot.set_meta("power",power)
	loot.set_meta("loaded",loaded)
	loot.add_to_group("survival_sources")
	parent.add_child(loot)
	return loot

func nearest_source(actor: Node3D) -> Node3D:
	var result: Node3D
	var distance := 2.8
	for source in get_tree().get_nodes_in_group("survival_sources"):
		if source.is_queued_for_deletion() or source.get_meta("contents",{}).is_empty() and int(source.get_meta("xp",0))==0 and source.get_meta("power","")=="": continue
		var d: float = source.global_position.distance_to(actor.position)
		if d<distance: result = source; distance = d
	return result

func tick_gather(actor: Node3D,delta: float) -> void:
	if is_client: return
	if actor.gather_target==null:
		for other in avatars.values():
			if other!=actor and other.health.dead and actor.position.distance_to(other.position)<2.8 and actor.bag.count("medkit")>0:
				begin_gather(actor,other,"revive",3.5)
				break
		if actor.gather_target==null and area_index==-1 and actor.position.distance_to(core.position)<4 and has_materials(actor.bag): begin_gather(actor,core,"deposit",1.8)
		if actor.gather_target==null:
			var source := nearest_source(actor)
			if source!=null: begin_gather(actor,source,"loot",5.0 if source.has_meta("weapon") else 2.8)
		if actor.gather_target==null and area_index==-1 and phase=="prep":
			for structure in get_tree().get_nodes_in_group("buildings"):
				if not structure.health.dead and structure.health.current<structure.health.maximum and actor.position.distance_to(structure.global_position)<2.8:
					begin_gather(actor,structure,"repair",1.8)
					break
	if actor.gather_target==null: return
	var target: Node3D = actor.gather_target
	if not is_instance_valid(target) or target.is_queued_for_deletion() or actor.position.distance_to(actor.gather_start)>.45 or actor.last_damage!=actor.gather_damage_mark or actor.position.distance_to(target.global_position)>(4.2 if target==core else 3.1): actor.cancel_gather(); return
	if actor.gather_kind=="loot":
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(target.global_position)<4.5: actor.cancel_gather(); return
	actor.gather_progress += delta
	if actor.gather_progress<actor.gather_duration: return
	var kind: String = actor.gather_kind
	actor.cancel_gather()
	if kind=="deposit": deposit_materials(actor)
	elif kind=="repair": target.repair()
	elif kind=="revive":
		if target.health.dead and actor.bag.remove("medkit",1): target.revive()
	else: transfer_source(actor,target)

func begin_gather(actor: Node3D,target: Node3D,kind: String,duration: float) -> void:
	actor.gather_target = target
	actor.gather_kind = kind
	actor.gather_duration = duration
	actor.gather_progress = 0
	actor.gather_damage_mark = actor.last_damage
	actor.gather_start = actor.position

func transfer_source(actor: Node3D,source: Node3D) -> bool:
	var contents: Dictionary = source.get_meta("contents",{})
	var transferred := false
	for id in contents.keys():
		var amount: int = mini(int(contents[id]),4 if id not in ItemBag.WEAPON_IDS else 1)
		var taken: int = actor.bag.add(id,amount)
		if taken<=0: continue
		contents[id] -= taken
		if contents[id]<=0: contents.erase(id)
		if id in ItemBag.WEAPON_IDS:
			var index := ItemBag.WEAPON_IDS.find(id)
			actor.weapons.ammo[index] = clampi(int(source.get_meta("loaded",actor.weapons.capacity(index))),0,actor.weapons.capacity(index))
		transferred = true
		break
	if contents.is_empty():
		var xp: int = source.get_meta("xp",0)
		var power: String = source.get_meta("power","")
		if xp>0: resources.add_loot(xp,0); source.set_meta("xp",0); transferred = true
		if not power.is_empty(): actor.grant_power(power); source.set_meta("power",""); transferred = true
		if source.has_meta("index") and not int(source.get_meta("index")) in claimed: claimed.append(int(source.get_meta("index")))
		source.hide()
	actor.weapons.sync_hand()
	if not transferred: notify("Bolsa cheia ou arma já carregada. Deposite no Núcleo ou reorganize com I.")
	return transferred

func has_materials(bag: ItemBag) -> bool:
	return bag.count("scrap")+bag.count("wood")+bag.count("parts")>0

func deposit_materials(actor: Node3D) -> bool:
	if area_index!=-1 or actor.position.distance_to(core.position)>4: return false
	for id in ["scrap","wood","parts"]:
		var amount: int = actor.bag.count(id)
		if amount>0: actor.bag.remove(id,amount); credit(id,amount)
	notify("Materiais guardados no Núcleo. O estoque compartilhado paga construções.")
	return true

func depot_count(id: String) -> int:
	if id=="scrap": return resources.scrap
	if id in ["wood","parts"]: return int(stock[id])
	return int(depot_items.get(id,0))

func withdraw(actor: Node3D,id: String,quantity: int) -> bool:
	if id not in ItemBag.IDS or quantity<=0 or area_index!=-1 or actor.position.distance_to(core.position)>4: return false
	var count := mini(quantity,depot_count(id))
	var moved: int = actor.bag.add(id,count)
	if moved<=0: return false
	if id=="scrap": resources.scrap -= moved
	elif id in ["wood","parts"]: stock[id] -= moved
	else: depot_items[id] -= moved
	actor.weapons.sync_hand()
	return true

func store_slot(actor: Node3D,index: int) -> bool:
	if index<0 or index>=ItemBag.SIZE or area_index!=-1 or actor.position.distance_to(core.position)>4: return false
	var item: Dictionary = actor.bag.slots[index].duplicate()
	if item.qty<=0: return false
	if item.id in ["scrap","wood","parts"]: credit(item.id,item.qty)
	else:
		depot_items[item.id] = int(depot_items.get(item.id,0))+int(item.qty)
		if item.id in ItemBag.WEAPON_IDS:
			var gun := ItemBag.WEAPON_IDS.find(item.id)
			var ammo_id: String = ItemBag.AMMO_IDS[gun]
			depot_items[ammo_id] = int(depot_items.get(ammo_id,0))+actor.weapons.ammo[gun]
			actor.weapons.ammo[gun] = 0
	actor.bag.slots[index] = {"id":"","qty":0}
	actor.weapons.sync_hand()
	return true

func drop_slot(actor: Node3D,index: int) -> bool:
	if index<0 or index>=ItemBag.SIZE: return false
	var item: Dictionary = actor.bag.slots[index].duplicate()
	if item.qty<=0: return false
	var loaded := 0
	if item.id in ItemBag.WEAPON_IDS:
		var gun := ItemBag.WEAPON_IDS.find(item.id)
		loaded = actor.weapons.ammo[gun]
	if spawn_loot(actor.position+Vector3(1,0,0),{item.id:item.qty},0,"",loaded)==null: return false
	if item.id in ItemBag.WEAPON_IDS: actor.weapons.ammo[ItemBag.WEAPON_IDS.find(item.id)] = 0
	actor.bag.slots[index] = {"id":"","qty":0}
	actor.weapons.sync_hand()
	return true

func buy_weapon(index: int) -> bool:
	if index<1 or index>4 or area_index!=-1 or phase!="prep" or player.position.distance_to(vendor_pos)>5: return false
	var id: String = ItemBag.WEAPON_IDS[index]
	var copy := ItemBag.new()
	copy.restore(player.bag.dump())
	if copy.add(id,1)!=1 or resources.scrap<int(CampaignData.PRICES[index]): return false
	resources.scrap -= int(CampaignData.PRICES[index])
	player.bag.restore(copy.dump())
	player.weapons.ammo[index] = player.weapons.capacity(index)
	player.weapons.sync_hand()
	return true

func shop_service(id: String) -> bool:
	if area_index!=-1 or phase!="prep" or player.position.distance_to(vendor_pos)>5: return false
	var packs := {"light":[24,12],"shell":[8,18],"rifle_ammo":[30,25],"rocket":[3,60],"grenade":[2,45],"medkit":[1,30],"wood":[8,35],"parts":[3,45]}
	if not packs.has(id): return false
	var quantity: int = packs[id][0]
	var price: int = packs[id][1]
	var copy := ItemBag.new()
	copy.restore(player.bag.dump())
	if copy.add(id,quantity)!=quantity or resources.scrap<price: return false
	resources.scrap -= price
	player.bag.restore(copy.dump())
	return true

func throw_grenade() -> bool: return throw_for(player)

func throw_for(actor: Node3D) -> bool:
	if is_client or phase not in ["combat","expedition"] or actor.bag.count("grenade")==0 or actor.weapons.cooldown>0: return false
	var aim: Vector3 = actor.aim
	var shot: Node3D = projectile("grenade",actor.position+Vector3(0,1.2,0),actor.position+aim*14+Vector3(0,.15,0),105,4.5,.85)
	if shot==null: return false
	shot.owner_peer = actor.peer_id
	actor.bag.remove("grenade",1)
	actor.weapons.cooldown = 1.5
	return true

func explode_from(point: Vector3,radius: float,power: float,owner: int) -> void:
	var saved: CharacterBody3D = player
	if avatars.has(owner): player = avatars[owner]
	super.explode(point,radius,power)
	player = saved
	if network!=null and network.mode=="host": network.blast_event(point,radius)

func survivor_down(actor: Node3D) -> void:
	for id in ["scrap","wood","parts"]:
		var qty: int = actor.bag.count(id)
		if qty>0 and spawn_loot(actor.position,{id:qty})!=null: actor.bag.remove(id,qty)
	if party_count()==1: finish(false,"O sobrevivente caiu com a carga. Retome o último checkpoint."); return
	for teammate in avatars.values():
		if not teammate.health.dead:
			notify(actor.display_name+" caiu. Segure E perto dele com um kit médico para reanimar.")
			return
	finish(false,"Todos os sobreviventes caíram.")

func choose_team_upgrade(index: int) -> bool:
	var host: Node3D = avatars[1]
	var saved: CharacterBody3D = player
	player = host
	var hp_before: float = host.health.maximum
	var result: bool = upgrades.choose(index)
	if result:
		for actor in avatars.values():
			if actor==host: continue
			for key in ["damage_multiplier","rate_multiplier","capacity_multiplier","reload_multiplier","level"]: actor.weapons.set(key,host.weapons.get(key))
			actor.speed_multiplier = host.speed_multiplier
			actor.health.maximum += host.health.maximum-hp_before
			actor.health.heal(host.health.maximum-hp_before)
	player = saved
	return result

func actor_profile(actor: Node3D) -> Dictionary:
	return {"bag":actor.bag.dump(),"ammo":actor.weapons.ammo.duplicate(),"gun":[actor.weapons.damage_multiplier,actor.weapons.rate_multiplier,actor.weapons.capacity_multiplier,actor.weapons.reload_multiplier,actor.weapons.level],"max_hp":actor.health.maximum,"hp":maxf(0,actor.health.current),"downed":actor.health.dead,"speed":actor.speed_multiplier}

func valid_profile(data: Variant) -> bool:
	if not data is Dictionary or not ItemBag.valid(data.get("bag")) or not data.get("ammo") is Array or data.ammo.size()!=5 or not data.get("gun") is Array or data.gun.size()!=5: return false
	for value in data.ammo:
		if not bounded(value,0,100000): return false
	for value in data.gun:
		if not bounded(value,.01,100000): return false
	return bounded(data.get("max_hp"),100,1000000) and bounded(data.get("hp"),0,data.max_hp) and bounded(data.get("speed"),.1,1000)

func restore_profile(actor: Node3D,data: Dictionary) -> void:
	actor.bag.restore(data.bag)
	actor.weapons.ammo.assign(data.ammo)
	actor.weapons.damage_multiplier = data.gun[0]
	actor.weapons.rate_multiplier = data.gun[1]
	actor.weapons.capacity_multiplier = data.gun[2]
	actor.weapons.reload_multiplier = data.gun[3]
	actor.weapons.level = int(data.gun[4])
	actor.health.setup(data.max_hp)
	actor.health.current = data.hp
	actor.health.dead = data.hp<=0
	actor.downed = actor.health.dead
	actor.rig.rotation.z = PI*.5 if actor.downed else 0.0
	actor.speed_multiplier = data.speed
	actor.weapons.sync_hand()

func snapshot() -> Dictionary:
	var saved_player: CharacterBody3D = player
	player = avatars.get(1,player)
	grenades = player.bag.count("grenade")
	rockets = player.bag.count("rocket")
	var data := super.snapshot()
	data.format = 4
	data.bag = player.bag.dump()
	data.depot_items = depot_items.duplicate()
	data.built = built_this_round
	for actor in avatars.values(): profiles[actor.profile_id] = actor_profile(actor)
	data.profiles = profiles.duplicate(true)
	data.loose = []
	for loot in get_tree().get_nodes_in_group("survival_loot"):
		if loot.get_parent()==base_root: data.loose.append({"pos":[loot.position.x,loot.position.z],"contents":loot.contents.duplicate(),"xp":int(loot.get_meta("xp",0)),"power":loot.get_meta("power",""),"loaded":int(loot.get_meta("loaded",0))})
	player = saved_player
	return data

func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.get("format")!=4 or not ItemBag.valid(data.get("bag")) or not data.get("depot_items") is Dictionary or not bounded(data.get("built"),0,12) or not data.get("profiles") is Dictionary or data.profiles.size()>64 or not data.get("loose") is Array or data.loose.size()>128: return false
	for id in data.depot_items:
		if id not in ItemBag.IDS or not bounded(data.depot_items[id],0,10000000): return false
	for id in data.profiles:
		if not id is String or id.length()>64 or not valid_profile(data.profiles[id]): return false
	for item in data.loose:
		if not item is Dictionary or not point_valid(item.get("pos")) or not item.get("contents") is Dictionary or not bounded(item.get("xp"),0,1000000) or item.get("power") not in ["","speed","rapid","shield"] or not bounded(item.get("loaded"),0,100000): return false
		for id in item.contents:
			if id not in ItemBag.IDS or not bounded(item.contents[id],1,1000000): return false
	var old: Dictionary = data.duplicate(true)
	old.format = 3
	return super.valid_snapshot(old)

func migrate_snapshot(data: Variant) -> Variant:
	var converted = super.migrate_snapshot(data)
	if not converted is Dictionary or converted.get("format")!=3: return converted
	converted = converted.duplicate(true)
	var bag := ItemBag.new()
	for i in range(5):
		if converted.owned[i]: bag.add(ItemBag.WEAPON_IDS[i],1)
	bag.add("light",48)
	var remainder := {}
	for entry in [["grenade",int(converted.grenades)],["rocket",int(converted.rockets)]]:
		var moved := bag.add(entry[0],entry[1])
		if moved<entry[1]: remainder[entry[0]] = entry[1]-moved
	converted.format = 4
	converted.bag = bag.dump()
	converted.depot_items = remainder
	converted.built = 0
	converted.profiles = {}
	converted.loose = []
	return converted

func apply_snapshot(data: Dictionary) -> void:
	super.apply_snapshot(data)
	player.bag.restore(data.bag)
	player.weapons.sync_hand()
	depot_items = data.depot_items.duplicate()
	built_this_round = int(data.built)
	profiles = data.profiles.duplicate(true)
	for loot in get_tree().get_nodes_in_group("survival_loot"):
		loot.get_parent().remove_child(loot)
		loot.queue_free()
	for item in data.loose: spawn_loot(Vector3(item.pos[0],0,item.pos[1]),item.contents,int(item.xp),item.power,int(item.loaded))

func load_checkpoint() -> bool:
	if is_client or area_index!=-1 or phase!="prep": return false
	var paths := [checkpoint_path(),frontier_path(game_mode),save_path(game_mode)]
	if game_mode=="campaign": paths.append(CHECKPOINT)
	for path in paths:
		if not FileAccess.file_exists(path): continue
		var data = migrate_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path)))
		if not valid_snapshot(data): notify("Checkpoint inválido; partida preservada."); return false
		apply_snapshot(data)
		return true
	return false

func projectile(kind: String,from: Vector3,to: Vector3,power: float,radius: float,travel_time: float) -> Node3D:
	var shot := super.projectile(kind,from,to,power,radius,travel_time)
	if shot!=null: shot.owner_peer = shot_owner; shot.set_meta("uid",next_id())
	return shot

func spawn_acid(point: Vector3,radius: float,power: float) -> Node3D:
	var pool := super.spawn_acid(point,radius,power)
	if pool!=null: pool.set_meta("uid",next_id())
	return pool

func use_medkit(actor: Node3D) -> bool:
	if actor.weapons.cooldown>0 or actor.health.current>=actor.health.maximum or not actor.bag.remove("medkit",1): return false
	actor.health.heal(45)
	actor.weapons.cooldown = 1
	return true

func attach_peer(peer: int,identity: String,nickname: String) -> bool:
	if is_client or avatars.has(peer) or avatars.size()>=4 or (not profiles.has(identity) and profiles.size()>=64) or phase=="ended": return false
	var actor := CharacterBody3D.new()
	actor.set_script(load("res://scripts/survival/survivor.gd"))
	actor.world = self
	actor.peer_id = peer
	actor.profile_id = identity
	actor.display_name = nickname.left(16)
	starter_bag(actor.bag)
	actor.weapons.free()
	actor.weapons = weapon_script().new()
	actor.position = player.position+Vector3(avatars.size()*1.1,0,1)
	avatars[peer] = actor
	add_child(actor)
	if profiles.has(identity): restore_profile(actor,profiles[identity])
	else:
		actor.weapons.damage_multiplier = avatars[1].weapons.damage_multiplier
		actor.weapons.rate_multiplier = avatars[1].weapons.rate_multiplier
		actor.weapons.capacity_multiplier = avatars[1].weapons.capacity_multiplier
		actor.weapons.reload_multiplier = avatars[1].weapons.reload_multiplier
		actor.weapons.level = avatars[1].weapons.level
		actor.speed_multiplier = avatars[1].speed_multiplier
		actor.health.setup(avatars[1].health.maximum)
		actor.weapons.sync_hand()
	actor.invulnerable = 3
	waves.rescale()
	if area_index!=-1: scale_field_population()
	notify("%s entrou · %d jogadores · população x%d" % [actor.display_name,party_count(),team_multiplier()])
	return true

func detach_peer(peer: int) -> void:
	if not avatars.has(peer) or peer==1: return
	var actor: Node3D = avatars[peer]
	profiles[actor.profile_id] = actor_profile(actor)
	avatars.erase(peer)
	actor.queue_free()
	waves.rescale()
	if area_index!=-1: scale_field_population()

func net_scene() -> Dictionary:
	return {"rev":scene_revision,"coord":sector_coord,"descriptor":descriptor.duplicate(true),"mode":game_mode}

func apply_net_scene(data: Dictionary) -> void:
	if not is_client: return
	clear_hazards()
	for node in client_enemies.values(): node.queue_free()
	for node in client_structures.values(): node.queue_free()
	for node in client_loot.values(): node.queue_free()
	for node in client_hazards.values(): node.queue_free()
	client_enemies.clear()
	client_structures.clear()
	client_loot.clear()
	client_hazards.clear()
	if field_root!=null: field_root.queue_free(); field_root = null
	sector_coord = data.coord
	area_index = -1 if sector_coord==Vector2i.ZERO else 0
	game_mode = data.mode
	descriptor = data.descriptor.duplicate(true)
	if area_index!=-1:
		field_root = Node3D.new()
		field_root.position = sector_offset(sector_coord)
		add_child(field_root)
		var field: Arena = load("res://scripts/sectors/sector_arena.gd").new()
		field.world = self
		field.descriptor = descriptor
		field_root.add_child(field)
		arena = field
		add_exits(field_root)
	else: arena = base_arena; add_exits_again_for_base()
	last_scene_revision = int(data.rev)

func net_state(peer: int) -> Dictionary:
	var actors: Array = []
	for id in avatars:
		var actor: Node3D = avatars[id]
		actors.append({"id":id,"name":actor.display_name,"p":actor.position,"aim":actor.aim,"hp":actor.health.current,"max":actor.health.maximum,"gun":actor.weapons.hand_weapon,"down":actor.health.dead,"gather":actor.gather_progress,"duration":actor.gather_duration,"kind":actor.gather_kind})
	var enemies: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemies.append({"id":enemy.net_id,"k":enemy.enemy_kind,"p":enemy.global_position,"r":enemy.rig.rotation.y,"hp":enemy.health.current,"max":enemy.health.maximum,"boss":enemy.is_boss,"field":enemy.field_enemy,"title":enemy.spec.title,"spec":enemy.spec.id})
	var structures: Array = []
	for s in get_tree().get_nodes_in_group("campaign_structure"):
		if not s.has_meta("uid"): s.set_meta("uid",next_id())
		structures.append({"id":s.get_meta("uid"),"piece":s.piece_index,"tier":s.tier,"p":s.position,"r":s.rotation.y,"hp":s.health.current,"max":s.health.maximum,"open":s.opened})
	var loot: Array = []
	for s in get_tree().get_nodes_in_group("survival_sources"):
		if s.is_queued_for_deletion(): continue
		loot.append({"id":s.get_meta("uid"),"p":s.global_position,"contents":s.get_meta("contents",{}).duplicate(),"rare":s.has_meta("weapon"),"visible":s.visible})
	var hazards: Array = []
	for group in ["campaign_projectiles","acid_pools"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node.has_meta("uid"): node.set_meta("uid",next_id())
			hazards.append({"id":node.get_meta("uid"),"p":node.global_position,"pool":group=="acid_pools","warning":false,"radius":node.radius})
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.windup>0: hazards.append({"id":-enemy.net_id,"p":enemy.cast_point,"pool":true,"warning":true,"radius":6.0 if enemy.is_boss else 2.5})
	return {"rev":scene_revision,"phase":phase,"mode":game_mode,"wave":waves.wave,"remaining":waves.remaining(),"running":waves.running,"clock":horde_left,"core_hp":core.health.current,"core_max":core.health.maximum,"core_tier":core_tier,"scrap":resources.scrap,"stock":stock.duplicate(),"depot":depot_items.duplicate(),"built":built_this_round,"level":resources.level,"xp":resources.xp,"pending":resources.pending,"offers":upgrades.offers.duplicate(true),"profile":actor_profile(avatars[peer]),"players":actors,"enemies":enemies,"structures":structures,"loot":loot,"hazards":hazards,"notice":notice if notice_left>0 else "","dead":field_dead,"discovered":discovered.duplicate(true),"won":won,"reason":ending_reason}

func apply_net_state(data: Dictionary,own_id: int) -> void:
	if not is_client or int(data.rev)!=last_scene_revision: return
	if player.peer_id!=own_id:
		avatars.erase(1)
		player.peer_id = own_id
		avatars[own_id] = player
	phase = data.phase
	game_mode = data.mode
	waves.wave = int(data.wave)
	waves.running = data.running
	waves.to_spawn = int(data.remaining)
	horde_left = data.clock
	core.health.maximum = data.core_max
	core.health.current = data.core_hp
	core_tier = int(data.core_tier)
	resources.scrap = int(data.scrap)
	stock = data.stock.duplicate()
	depot_items = data.depot.duplicate()
	built_this_round = int(data.built)
	resources.level = int(data.level)
	resources.xp = int(data.xp)
	resources.pending = int(data.pending)
	upgrades.offers = data.offers.duplicate(true)
	field_dead = int(data.dead)
	discovered = data.discovered.duplicate(true)
	if not data.notice.is_empty(): notice = data.notice; notice_left = .25
	if valid_profile(data.profile): restore_profile(player,data.profile)
	var seen := {}
	for state in data.players:
		var id := int(state.id)
		seen[id] = true
		if not avatars.has(id):
			var actor := CharacterBody3D.new()
			actor.set_script(load("res://scripts/survival/survivor.gd"))
			actor.world = self
			actor.peer_id = id
			actor.display_name = state.name
			actor.proxy = true
			actor.weapons.free()
			actor.weapons = weapon_script().new()
			actor.position = state.p
			add_child(actor)
			avatars[id] = actor
		var actor: Node3D = avatars[id]
		if actor.position.distance_to(state.p)>15: actor.position = state.p
		actor.target_position = state.p
		actor.aim = state.aim
		actor.rig.rotation.y = atan2(-actor.aim.x,-actor.aim.z)
		actor.health.maximum = state.max
		actor.health.current = state.hp
		actor.health.dead = state.down
		actor.rig.rotation.z = PI*.5 if state.down else 0
		actor.gather_progress = state.gather
		actor.gather_duration = state.duration
		actor.gather_kind = state.kind
		actor.weapons.hand_weapon = int(state.gun)
		if actor.weapons.last_model!=actor.weapons.hand_weapon: actor.weapons.rebuild_model()
	for id in avatars.keys():
		if not seen.has(id): avatars[id].queue_free(); avatars.erase(id)
	seen.clear()
	for state in data.enemies:
		var id := int(state.id)
		seen[id] = true
		if not client_enemies.has(id):
			var enemy: Node3D = make_enemy(int(state.k),Vector3.ZERO,false,-1)
			enemy.proxy = true
			enemy.remove_from_group("wave_enemies")
			enemy.set_physics_process(false)
			enemy.collision_mask = 0
			enemy.position = state.p
			client_enemies[id] = enemy
		var enemy: Node3D = client_enemies[id]
		enemy.field_enemy = state.field
		enemy.set_meta("target",state.p)
		enemy.rig.rotation.y = state.r
		enemy.health.maximum = state.max
		enemy.health.current = state.hp
		enemy.spec.title = state.title
		enemy.label.hide()
	for id in client_enemies.keys():
		if not seen.has(id): client_enemies[id].queue_free(); client_enemies.erase(id)
	seen.clear()
	for state in data.structures:
		var id := int(state.id)
		seen[id] = true
		if not client_structures.has(id):
			var s := StaticBody3D.new()
			s.set_script(load("res://scripts/campaign/campaign_structure.gd"))
			s.world = self
			s.piece_index = int(state.piece)
			s.position = state.p
			s.rotation.y = state.r
			base_root.add_child(s)
			s.set_physics_process(false)
			client_structures[id] = s
		var s: Node3D = client_structures[id]
		s.tier = int(state.tier)
		s.health.maximum = state.max
		s.health.current = state.hp
		s.opened = state.open
		s.collision_layer = 0 if state.open or s.spec.id=="spikes" else 8
		s.model.position.y = -1.65 if state.open else 0
	for id in client_structures.keys():
		if not seen.has(id): client_structures[id].queue_free(); client_structures.erase(id)
	seen.clear()
	for state in data.loot:
		var id := int(state.id)
		seen[id] = true
		if not client_loot.has(id): client_loot[id] = VisualFactory.box(self,Vector3(.6,.45,.6),state.p+Vector3(0,.3,0),Color("a49e70"))
		client_loot[id].visible = state.visible
		client_loot[id].position = state.p+Vector3(0,.3,0)
	for id in client_loot.keys():
		if not seen.has(id): client_loot[id].queue_free(); client_loot.erase(id)
	seen.clear()
	for state in data.hazards:
		var id := int(state.id)
		seen[id] = true
		if not client_hazards.has(id):
			if state.get("warning",false): client_hazards[id] = VisualFactory.ring(self,state.radius,Vector3.ZERO,Color("e67f5f"))
			else: client_hazards[id] = VisualFactory.cylinder(self,state.radius if state.pool else .15,.04 if state.pool else .25,Vector3.ZERO,Color("9dc45f") if state.pool else Color("e1af64"))
		client_hazards[id].position = state.p
	for id in client_hazards.keys():
		if not seen.has(id): client_hazards[id].queue_free(); client_hazards.erase(id)
	if phase=="ended" and hud.mode!="result": won = data.won; ending_reason = data.reason; hud.show_result()
