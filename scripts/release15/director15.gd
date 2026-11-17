class_name Director15
extends RefCounted
static var selected_class = "engineer"
static var selected_cosmetic = 0
static var selected_mutators: Array = []
var world: Node3D
var mutators: Array = []
var day = DayCycle15.new()
var event_states: Dictionary = {}
var active_events: Dictionary = {}
var transient: Array = []
var alert_left = 0.0
var alert_clock = 0.0
var fragments = 0
var fx_clock = 0.0
var restored15 = false
func initialize(owner_world: Node3D) -> void:
	world = owner_world; day.world = world
	if not restored15: mutators = selected_mutators.duplicate()
	if not campaign_completed(): mutators.clear()
	world.core.health.damaged.connect(func(_amount): core_alert())
	if not restored15: apply_class(world.player,selected_class,true)
	if not restored15: world.player.cosmetic = mini(selected_cosmetic,RankProgress.tier(int(world.get_node("/root/Account").local_summary.get("kills",0))))
	world.player.outfit16 = world.get_node("/root/Meta16").outfit(world.player.specialization)
	decorate(world.player)
func campaign_completed() -> bool:
	var cfg = ConfigFile.new(); return cfg.load("user://meta15.cfg")==OK and bool(cfg.get_value("meta","completed",false))
func unlock_campaign() -> void:
	var cfg = ConfigFile.new(); cfg.load("user://meta15.cfg"); cfg.set_value("meta","completed",true); cfg.save("user://meta15.cfg")
func apply_class(actor: Node3D,id: String,starter: bool = false) -> void:
	actor.specialization = id if id in ["engineer","scout","shooter"] else "engineer"
	if actor.specialization=="scout": actor.bag.resize_bag(20)
	if starter and actor.specialization=="shooter": actor.weapons.tuning[0] = maxi(1,actor.weapons.tuning[0])
	world.upgrades.apply_actor(actor)
func decorate(actor: Node3D) -> void:
	Cosmetics16.decorate(actor.rig,actor.outfit16,actor)
	var previous = actor.rig.get_node_or_null("EloCosmetic")
	if previous!=null: actor.rig.remove_child(previous); previous.queue_free()
	if actor.cosmetic<=0 or (actor.cosmetic<=3 and not actor.outfit16.get("head","").is_empty()) or (actor.cosmetic>=4 and actor.cosmetic<=7 and not actor.outfit16.get("backpack","").is_empty()) or (actor.cosmetic>=8 and not actor.outfit16.get("effect","").is_empty()): return
	var root = Node3D.new(); root.name = "EloCosmetic"; actor.rig.add_child(root)
	var color = Color.from_hsv(.12 if actor.cosmetic<7 else .78,.35+actor.cosmetic*.035,.88+actor.cosmetic*.01)
	if actor.cosmetic<=3: VisualFactory.cylinder(root,.38,.15,Vector3(0,2.0,0),color)
	elif actor.cosmetic<=7: VisualFactory.box(root,Vector3(.55,.7,.25),Vector3(0,1.2,.32),color)
	else: VisualFactory.ring(root,.6,Vector3(0,.1,0),color)
	for i in range(actor.cosmetic): VisualFactory.box(root,Vector3(.07,.09,.05),Vector3(-.25+i*.055,1.6,-.28),color)
func tick(delta: float) -> void:
	alert_left = maxf(0,alert_left-delta); alert_clock = maxf(0,alert_clock-delta)
	if world.is_client: day.apply_light(); return
	day.tick(delta)
	if "no_vendor" in mutators and is_instance_valid(world.vendor_rig):
		world.vendor_rig.visible = false
		for stand in world.get_tree().get_nodes_in_group("vendor_obstacles"): stand.collision_layer = 0
		if is_instance_valid(world.vendor_tag): world.vendor_tag.visible = false
	for i in range(transient.size()-1,-1,-1):
		var entry: Dictionary = transient[i]; entry.left -= delta
		if entry.left<=0 or not is_instance_valid(entry.node):
			if is_instance_valid(entry.node): entry.node.queue_free()
			transient.remove_at(i)
	update_events(delta)
	if event_states.size()>1024:
		for key in event_states.keys():
			if event_states.size()<=1024: break
			if not active_events.has(key): event_states.erase(key)
func core_alert() -> void:
	alert_left = 4
	if alert_clock<=0: alert_clock = 4; world.audio.play_tone(220,.4,.15); world.notify("NÚCLEO SOB ATAQUE · volte ao setor (0,0)!")
func score_multiplier() -> int: return 1+mutators.size()
func timed_node(node: Node3D,life: float) -> void: transient.append({"node":node,"left":life})
func fuse(actor: Node3D) -> bool:
	if not world.base_preparing(): return false
	var first: Node3D = world.nearest_structure()
	if first==null or first==world.core or not FortressData.turret(first.spec.id) or first.get_meta("fused",false): return false
	for other in world.get_tree().get_nodes_in_group("campaign_structure"):
		if other==first or other.spec.id!=first.spec.id or other.tier!=first.tier or other.get_meta("fused",false) or other.health.dead or first.position.distance_to(other.position)>4: continue
		first.set_meta("alloy16",maxf(float(first.get_meta("alloy16",0)),float(other.get_meta("alloy16",0))))
		first.set_meta("fused",true); first.refresh_tier()
		for key in other.invested: first.invested[key] = int(first.invested.get(key,0))+int(other.invested[key])
		other.health.dead = true; other.collision_layer = 0; other.remove_from_group("campaign_structure"); other.remove_from_group("buildings"); other.queue_free()
		world.built_this_round = maxi(0,world.built_this_round-1); world.layout_revision += 1
		VisualFactory.cylinder(first.model,.22,.55,Vector3(.55,1.8,0),Color("e6c177"))
		world.notify("TORRE DUPLA · cadência aumentada, uma unidade de cota liberada."); return true
	return false
func recycle(actor: Node3D) -> bool:
	if not world.base_preparing(): return false
	var station: Node3D
	for s in world.get_tree().get_nodes_in_group("campaign_structure"):
		if s.spec.id=="recycler" and s.position.distance_to(actor.position)<4: station = s; break
	if station==null: return false
	var slot: Dictionary = actor.bag.slots[actor.bag.selected]
	if slot.id in ItemBag.WEAPON_IDS and slot.id!="pistol":
		if actor.bag.remove(slot.id,1):
			actor.weapons.ammo[ItemBag.WEAPON_IDS.find(slot.id)] = 0
			world.credit("parts",5); actor.weapons.sync_hand(); return true
	if actor.bag.remove("wood",20): world.credit("parts",2); return true
	world.notify("Reciclagem: arma selecionada → 5 componentes; ou 20 madeira → 2 componentes."); return false
func buy_beacon(actor: Node3D) -> bool:
	if not world.base_preparing() or actor.position.distance_to(world.vendor_pos)>4 or "no_vendor" in mutators: return false
	# Rare stock: one per preparation, shared by the team.
	var key = "beacon_"+str(world.waves.wave)
	var copy := ItemBag.new(); copy.restore(actor.bag.dump())
	if event_states.has(key) or copy.add("beacon",1)!=1 or not world.can_pay({"scrap":140,"parts":6}): return false
	if not world.pay({"scrap":140,"parts":6}): return false
	actor.bag.restore(copy.dump()); event_states[key] = true; return true
func extract(actor: Node3D) -> bool:
	if actor.region_coord==Vector2i.ZERO or not actor.bag.remove("beacon",1): return false
	if world.regions.enabled(): world.regions.extract_to_core(actor)
	else:
		world.player = actor; world.extract_solo15(actor)
	return true
func start_extract(actor: Node3D) -> bool:
	return actor.bag.count("beacon")>0 and actor.region_coord!=Vector2i.ZERO and world.channel15.start(actor,"extract",null)
func dump() -> Dictionary:
	return {"day":day.dump(),"mutators":mutators.duplicate(),"events":event_states.duplicate(true)}
func restore(data: Dictionary) -> void:
	restored15 = true
	alert_left = float(data.get("alert",alert_left))
	mutators = data.get("mutators",[]).duplicate()
	if data.has("events"): event_states = data.events.duplicate(true)
	if data.has("event_map"): event_states = data.event_map.duplicate(true)
	day.restore(data.get("day",{"clock":0,"blood":false,"cycle":0}))
static func valid(data: Variant) -> bool:
	if not data is Dictionary or not DayCycle15.valid(data.get("day")) or not data.get("mutators") is Array or data.mutators.size()>3 or not data.get("events") is Dictionary or data.events.size()>4096: return false
	for key in data.events:
		if not key is String or key.length()>100: return false
		var entry = data.events[key]
		if entry is bool: continue
		if not entry is Dictionary or entry.get("type") not in ["convoy","nest","escort"] or not entry.get("complete") is bool or not entry.get("started") is bool or not entry.get("bonus") is bool or not SectorMemory.number(entry.get("left"),0,45) or not SectorMemory.number(entry.get("spawn"),0,4) or not entry.get("owner") is String: return false
	for id in data.mutators:
		if id not in ["darkness","no_vendor","double_hordes"]: return false
	return true
# Sector events are activated lazily, from the authoritative loaded sector.
func sector_event_key() -> String:
	return SectorGenerator.key(world.sector_coord)+":"+str(world.descriptor.get("visit",0))
func event_for_sector(coord: Vector2i) -> Dictionary:
	var prefix = SectorGenerator.key(coord)+":"
	for key in event_states:
		if str(key).begins_with(prefix) and event_states[key] is Dictionary and not event_states[key].get("complete",false): return event_states[key]
	return {}
func update_events(delta: float) -> void:
	if world.regions.enabled():
		for coord in world.regions.sessions.keys():
			if coord!=Vector2i.ZERO: world.regions.run_in(coord,func(): tick_sector_event(delta))
	elif world.sector_coord!=Vector2i.ZERO: tick_sector_event(delta)
	for key in active_events.keys():
		var node = active_events[key]
		if not is_instance_valid(node) or not node.is_inside_tree(): active_events.erase(key); continue
		var state: Dictionary = event_states.get(key,{})
		if state.get("type","")!="escort" or not state.get("started",false) or state.get("complete",false): continue
		var actor: Node3D
		for candidate in world.avatars.values():
			if candidate.profile_id==state.get("owner",""): actor = candidate; break
		if actor==null or actor.health.dead: continue
		var region: String = SectorGenerator.key(actor.region_coord)
		if state.get("last_region",region)!=region:
			if state.get("near_owner",true): node.global_position = actor.global_position+Vector3(1,0,1)
			state.last_region = region
		state.near_owner = node.global_position.distance_to(actor.global_position)<6
		if node.global_position.distance_to(actor.global_position)>2: node.global_position = node.global_position.move_toward(actor.global_position,delta*4.4)
		if actor.region_coord==Vector2i.ZERO and node.global_position.distance_to(actor.global_position)<4:
			state.complete = true; world.credit("parts",12); node.queue_free(); world.notify("ESCOLTA CONCLUÍDA · +12 componentes no Núcleo.")
func tick_sector_event(delta: float) -> void:
	if world.descriptor.get("special16","normal")!="normal": return
	if world.descriptor.is_empty() or not is_instance_valid(world.field_root): return
	var key = sector_event_key()
	if not event_states.has(key):
		var roll = absi(hash(key+str(world.world_seed)))%4
		if roll==0: return
		var kind: String = ["none","convoy","nest","escort"][roll]
		event_states[key] = {"type":kind,"complete":false,"started":false,"left":45.0,"spawn":0.0,"bonus":false,"owner":""}
	var state: Dictionary = event_states[key]
	if state.complete: return
	var node: Node3D = active_events.get(key)
	if not is_instance_valid(node):
		node = StaticBody3D.new(); node.set_script(load("res://scripts/release15/event15.gd")); node.world = world; node.kind = state.type; node.event_key = key
		node.position = Vector3(12,0,-8)
		if state.type=="escort" and not world.descriptor.get("houses",[]).is_empty(): node.position = world.descriptor.houses[0].pos+Vector3(0,0,1)
		world.field_root.add_child(node); active_events[key] = node
	if state.type=="nest":
		if not state.bonus:
			for house in world.get_tree().get_nodes_in_group("raid_houses"):
				if world.field_root.is_ancestor_of(house):
					for id in house.contents: house.contents[id] = int(house.contents[id])*2
			state.bonus = true
		for enemy in world.get_tree().get_nodes_in_group("enemies"):
			if world.field_root.is_ancestor_of(enemy) and not enemy.get_meta("nest_speed",false): enemy.spec.values.speed *= 1.2; enemy.set_meta("nest_speed",true)
	elif state.type=="convoy" and state.started:
		var present = world.avatars.values().any(func(a): return not a.health.dead and a.region_coord==world.sector_coord and a.global_position.distance_to(node.global_position)<22)
		if not present: return
		state.left = maxf(0,float(state.left)-delta); state.spawn = float(state.spawn)-delta
		node.label.text = "COMBOIO · mantenha a posição · %d s" % ceili(state.left)
		if state.spawn<=0 and world.get_tree().get_nodes_in_group("enemies").size()<72:
			state.spawn = 4; world.make_enemy(1, node.position+Vector3(12,0,0),true,-1)
		if state.left<=0:
			state.complete = true
			world.spawn_loot(node.global_position+Vector3(0,0,4),{"rifle_ammo":60,"parts":8},0,"",0,true,true)
			var actor: Node3D
			for a in world.avatars.values():
				if a.region_coord==world.sector_coord and not a.health.dead: actor = a; break
			if actor!=null:
				actor.weapons.tuning[2] = maxi(1,actor.weapons.tuning[2])
				if actor.bag.add("rifle",1)==0 and actor.bag.count("rifle")==0: world.spawn_loot(node.global_position+Vector3(0,0,5),{"rifle":1})
			world.notify("COMBOIO ABERTO · Rifle Reforçado e munição."); node.queue_free()
func interact_event(actor: Node3D) -> bool:
	for key in active_events:
		var node = active_events[key]
		if not is_instance_valid(node) or not node.is_inside_tree() or node.global_position.distance_to(actor.global_position)>4: continue
		var state: Dictionary = event_states[key]
		if state.complete or state.started or state.type=="nest": continue
		state.started = true; state.owner = actor.profile_id; state.last_region = SectorGenerator.key(actor.region_coord); state.near_owner = true
		if state.type=="escort":
			var pos: Vector3 = node.global_position; node.get_parent().remove_child(node); world.add_child(node); node.global_position = pos; node.label.text = "ESCOLTA · leve ao refúgio (0,0)"
		return true
	return false
func destroy_nest(key: String) -> void:
	if not event_states.has(key): return
	event_states[key].complete = true
	var node = active_events.get(key)
	if is_instance_valid(node):
		for enemy in world.get_tree().get_nodes_in_group("enemies"):
			if enemy.get_meta("nest_speed",false) and world.coord_at(enemy.global_position)==world.coord_at(node.global_position): enemy.spec.values.speed /= 1.2; enemy.set_meta("nest_speed",false)
		node.queue_free()
	world.notify("NINHO DESTRUÍDO · velocidade dos infectados normalizada.")
func temporary_wall(point: Vector3) -> Node3D:
	if world.get_tree().get_nodes_in_group("clay_temp_walls").size()>=12: return null
	# Do not embed a survivor/core in newly molded terrain.
	for actor in world.avatars.values():
		if actor.global_position.distance_to(point)<3: point += Vector3(4,0,0)
	if point.distance_to(world.core.global_position)<4: return null
	var wall = StaticBody3D.new(); world.add_child(wall); wall.global_position = point*Vector3(1,0,1); wall.collision_layer = 8; wall.add_to_group("clay_temp_walls")
	VisualFactory.collider(wall,Vector3(5,2.6,1),Vector3(0,1.3,0)); VisualFactory.box(wall,Vector3(5,2.6,1),Vector3(0,1.3,0),Color("a77c60"))
	timed_node(wall,8); return wall
func make_ramp(point: Vector3) -> Node3D:
	var nearby: Node3D
	for structure in world.get_tree().get_nodes_in_group("campaign_structure"):
		if structure.spec.id in ["wall","barricade","bastion"] and structure.global_position.distance_to(point)<4: nearby = structure; break
	if nearby==null or world.get_tree().get_nodes_in_group("clay_ramps").size()>=12: return null
	var ramp = Node3D.new(); world.add_child(ramp); ramp.global_position = nearby.global_position; ramp.add_to_group("clay_ramps")
	var mesh = VisualFactory.box(ramp,Vector3(2, .35,5),Vector3(0,1.0,0),Color("a17a66")); mesh.rotation.x = -.4
	timed_node(ramp,10); return ramp
func clay_fragments(point: Vector3,color: Color) -> void:
	if world.effects.active> (12 if MobilePlatform.enabled() else 60): return
	for i in range(3 if MobilePlatform.enabled() else 4):
		var bit = VisualFactory.box(world.effects,Vector3.ONE*.18,point+Vector3.UP,color)
		world.effects.active += 1
		var direction = Vector3(world.world_rng.randf_range(-1.2,1.2),0,world.world_rng.randf_range(-1.2,1.2))
		var tween = world.create_tween()
		tween.tween_property(bit,"position",point+direction+Vector3.UP*.12,.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(1.45)
		tween.tween_callback(func(): bit.queue_free(); world.effects.active -= 1)

var client_visuals: Dictionary = {}
func net_dump(bulk: bool = true) -> Dictionary:
	var data := {"day":day.dump(),"mutators":mutators.duplicate(),"alert":alert_left}
	if bulk:
		var map := {}
		for key in event_states:
			if event_states[key] is Dictionary: map[key] = {"type":event_states[key].type,"complete":event_states[key].complete}
		data.event_map = map
	return data
func visuals() -> Array:
	var rows: Array = []
	for key in active_events:
		var node = active_events[key]
		if not is_instance_valid(node) or not node.is_inside_tree() or event_states[key].get("complete",false) or world.coord_at(node.global_position)!=world.sector_coord: continue
		if not node.has_meta("uid"): node.set_meta("uid",world.next_id())
		rows.append({"id":node.get_meta("uid"),"kind":node.kind,"p":node.global_position,"text":node.label.text})
	for entry in transient:
		var node = entry.node
		if not is_instance_valid(node) or world.coord_at(node.global_position)!=world.sector_coord: continue
		if not node.has_meta("uid"): node.set_meta("uid",world.next_id())
		rows.append({"id":node.get_meta("uid"),"kind":"wall" if node is StaticBody3D else "ramp","p":node.global_position,"text":""})
	return rows
func apply_visuals(rows: Array) -> void:
	var seen = {}
	for row in rows:
		seen[row.id] = true
		if not client_visuals.has(row.id):
			var node: Node3D
			if row.kind=="wall":
				node = StaticBody3D.new(); node.collision_layer = 8; VisualFactory.collider(node,Vector3(5,2.6,1),Vector3(0,1.3,0)); VisualFactory.box(node,Vector3(5,2.6,1),Vector3(0,1.3,0),Color("a77c60"))
			elif row.kind=="ramp":
				node = Node3D.new(); var mesh = VisualFactory.box(node,Vector3(2,.35,5),Vector3(0,1,0),Color("a17a66")); mesh.rotation.x = -.4
			else:
				node = StaticBody3D.new(); node.set_script(load("res://scripts/release15/event15.gd")); node.world = world; node.kind = row.kind
			world.add_child(node); client_visuals[row.id] = node
		var node: Node3D = client_visuals[row.id]; node.global_position = row.p
		if row.kind in ["nest","escort","convoy"]: node.label.text = row.text
	for id in client_visuals.keys():
		if not seen.has(id): client_visuals[id].queue_free(); client_visuals.erase(id)

func event_interactable(actor: Node3D) -> bool:
	for key in active_events:
		var node = active_events[key]
		if is_instance_valid(node) and node.is_inside_tree() and node.global_position.distance_to(actor.global_position)<4 and not event_states[key].get("started",false) and not event_states[key].get("complete",false) and event_states[key].type!="nest": return true
	return false
