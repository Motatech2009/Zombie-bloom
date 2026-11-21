class_name Director15
extends RefCounted
const CONVOY_SECONDS := 60.0
const CONVOY_SCALE := 1.6
const CONVOY_REACH := 6.0
const CONVOY_CAP := 12
const CONVOY_THREATS := [1, 3, 1, 5, 12, 1, 4, 9, 1, 3, 12, 5]
const CONVOY_SUPPLIES := {"rifle_ammo": 90, "parts": 28, "scrap": 180}
const NEST_MAX_HP := 520.0
const NEST_CAP := 9
const NEST_THREATS := [1, 0, 1, 3, 5, 1, 12, 10, 4]
const CLASSES := {"engineer":"Engenheiro","scout":"Batedor","shooter":"Atirador","medic":"Médico"}
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
	actor.specialization = id if CLASSES.has(id) else "engineer"
	actor.bag.medical = actor.specialization == "medic"
	if actor.specialization=="scout": actor.bag.resize_bag(20)
	if starter and actor.specialization=="shooter": actor.weapons.tuning[0] = maxi(1,actor.weapons.tuning[0])
	world.upgrades.apply_actor(actor)
func decorate(actor: Node3D) -> void:
	if actor.rig.has_method("set_rank16"): actor.rig.set_rank16(int(actor.cosmetic))
	Cosmetics16.decorate(actor.rig,actor.outfit16,actor)
	var previous = actor.rig.get_node_or_null("EloCosmetic")
	if previous!=null: actor.rig.remove_child(previous); previous.queue_free()
	if actor.cosmetic<=0 or (actor.cosmetic<=3 and not actor.outfit16.get("head","").is_empty()) or (actor.cosmetic>=4 and actor.cosmetic<=7 and not actor.outfit16.get("backpack","").is_empty()) or (actor.cosmetic>=8 and not actor.outfit16.get("effect","").is_empty()): return
	preload("res://scripts/presentation/rank_cosmetics16.gd").decorate(actor.rig,int(actor.cosmetic))
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
		if not entry is Dictionary or entry.get("type") not in ["convoy","nest","escort"] or not entry.get("complete") is bool or not entry.get("started") is bool or not entry.get("bonus") is bool or not SectorMemory.number(entry.get("left"),0,CONVOY_SECONDS) or not SectorMemory.number(entry.get("spawn"),0,4) or not entry.get("owner") is String: return false
		if not SectorMemory.number(entry.get("hp",NEST_MAX_HP),0,NEST_MAX_HP) or not SectorMemory.number(entry.get("brood15",0),0,1000000,true): return false
		if not SectorMemory.number(entry.get("convoy_serial17", 0), 0, 1000000, true): return false
		if entry.has("nest17") and not entry.nest17 is bool: return false
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
		if not is_instance_valid(node) or not node.is_inside_tree():
			active_events.erase(key)
	for key in event_states:
		var state = event_states[key]
		if state is Dictionary and state.get("type") == "escort" and state.started and not state.complete:
			update_escort(key, state, delta)

func update_escort(key: String, state: Dictionary, delta: float) -> void:
	var actor: Node3D
	for candidate in world.avatars.values():
		if candidate.profile_id == state.owner and not candidate.health.dead:
			actor = candidate
			break
	if actor == null: return
	var node: Node3D = active_events.get(key)
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		node = make_event(key, "escort", world, actor.global_position + Vector3(1, 0, 1))
		node.label.text = "ESCOLTA · leve ao Núcleo (0,0)"
	if world.coord_at(node.global_position) != actor.region_coord:
		node.global_position = actor.global_position + Vector3(1, 0, 1)
	var core_pos: Vector3 = world.core.global_position
	var at_core: bool = actor.region_coord == Vector2i.ZERO and actor.global_position.distance_to(core_pos) <= 9.0
	var destination: Vector3 = core_pos if at_core else actor.global_position
	node.follow_and_cover(actor, destination, 3.5 if at_core else 2.0, delta)
	if at_core and node.global_position.distance_to(core_pos) <= 5.0:
		state.complete = true
		world.credit("parts", 12)
		node.disappear()
		world.notify("ESCOLTA CONCLUÍDA · Sobrevivente a salvo. +12 componentes no Núcleo.")

func make_event(key: String, kind: String, parent: Node3D, position: Vector3) -> Node3D:
	var node := StaticBody3D.new()
	node.set_script(load("res://scripts/release15/event15.gd"))
	node.world = world
	node.kind = kind
	node.event_key = key
	node.position = position
	parent.add_child(node)
	active_events[key] = node
	return node

func tick_sector_event(delta: float) -> void:
	if world.descriptor.get("special16","normal")!="normal": return
	if world.descriptor.is_empty() or not is_instance_valid(world.field_root): return
	var key = sector_event_key()
	if not event_states.has(key):
		var roll = absi(hash(key+str(world.world_seed)))%4
		if roll==0: return
		var kind: String = ["none","convoy","nest","escort"][roll]
		event_states[key] = {"type":kind,"complete":false,"started":false,"left":CONVOY_SECONDS,"spawn":0.0,"bonus":false,"owner":""}
	var state: Dictionary = event_states[key]
	if state.complete or (state.type == "escort" and state.started): return
	var node: Node3D = active_events.get(key)
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		var location := Vector3(12, 0, -8)
		if state.type == "convoy":
			# Park along the clear crossroad, with room to walk around the expanded truck.
			var points: Array = world.descriptor.caches.duplicate()
			if int(world.descriptor.get("rare",-1)) >= 0: points.append(world.descriptor.rare_pos)
			location = Vector3(30,0,-3)
			for x in [12,18,24]:
				var candidate := Vector3(x,0,-3)
				if not points.any(func(p): return absf(p.x-candidate.x)<3.0 and absf(p.z-candidate.z)<5.4):
					location = candidate
					break
		if state.type == "escort" and not world.descriptor.get("houses", []).is_empty():
			location = world.descriptor.houses[0].pos + Vector3(0, 0, 1)
		node = make_event(key, state.type, world.field_root, location)
	if state.type=="nest":
		tick_nest(node,state,key,delta)
		if not state.bonus:
			for house in world.get_tree().get_nodes_in_group("raid_houses"):
				if world.field_root.is_ancestor_of(house):
					for id in house.contents: house.contents[id] = int(house.contents[id])*2
			state.bonus = true
		for enemy in world.get_tree().get_nodes_in_group("enemies"):
			if world.field_root.is_ancestor_of(enemy) and not enemy.get_meta("nest_speed",false): enemy.spec.values.speed *= 1.2; enemy.set_meta("nest_speed",true)
	elif state.type == "convoy" and state.started:
		tick_convoy(node, state, key, delta)

func guards_for(meta: String, key: String) -> Array:
	return world.get_tree().get_nodes_in_group("enemies").filter(func(enemy):
		return not enemy.health.dead and not enemy.is_queued_for_deletion() and enemy.get_meta(meta, "") == key
	)

func present_near(node: Node3D, distance: float) -> Array:
	return world.avatars.values().filter(func(actor):
		return not actor.health.dead and actor.region_coord == world.sector_coord and actor.global_position.distance_to(node.global_position) < distance
	)

func tick_convoy(node: Node3D, state: Dictionary, key: String, delta: float) -> void:
	if world.is_client or world.combat_paused(): return
	var nearby := present_near(node, 22.0)
	if nearby.is_empty(): return
	var guards := guards_for("convoy_owner17", key)
	state.left = maxf(0.0, float(state.left) - delta)
	state.spawn = maxf(0.0, float(state.spawn) - delta)
	if state.left > 0.0:
		node.label.text = "COMBOIO · %d s · %d atacantes" % [ceili(state.left), guards.size()]
		if state.spawn == 0.0 and guards.size() < CONVOY_CAP:
			send_reinforcements(node, state, key, "convoy_owner17", "convoy_serial17",
				CONVOY_THREATS, mini(4 if state.left <= 25.0 else 3, CONVOY_CAP - guards.size()), 8.5, 2.6 if state.left <= 25.0 else 3.4)
		return
	if not guards.is_empty():
		node.label.text = "COMBOIO · elimine os %d atacantes restantes" % guards.size()
		return
	var reward: Node3D = world.spawn_loot(node.global_position + Vector3(0, 0, 5.2), CONVOY_SUPPLIES, 0, "", 0, true, true, true)
	if reward == null: return
	state.complete = true
	world.mark_boss_drop(reward)
	var actor: Node3D = nearby[0]
	actor.weapons.tuning[2] = maxi(1, actor.weapons.tuning[2])
	if actor.bag.count("rifle") == 0 and actor.bag.add("rifle", 1) == 0:
		reward.contents["rifle"] = 1
		reward.refresh_model()
	world.notify("COMBOIO ABERTO · Rifle reforçado, munição, 180 sucatas e 28 componentes.")
	node.queue_free()

func tick_nest(node: Node3D, state: Dictionary, key: String, delta: float) -> void:
	if world.is_client or world.combat_paused(): return
	var guards := guards_for("nest_owner15", key)
	var enraged: bool = node.health.current <= node.health.maximum * .5
	node.label.text = "NINHO DE ESPOROS · %d/%d · %d/%d guardas" % [ceili(node.health.current), ceili(node.health.maximum), guards.size(), NEST_CAP]
	if present_near(node, 32.0).is_empty(): return
	state.spawn = maxf(0.0, float(state.spawn) - delta)
	if state.spawn > 0.0 or guards.size() >= NEST_CAP: return
	send_reinforcements(node, state, key, "nest_owner15", "brood15",
		NEST_THREATS, mini(3 if enraged else 2, NEST_CAP - guards.size()), 4.5, 1.8 if enraged else 2.8)

func send_reinforcements(node: Node3D, state: Dictionary, key: String, meta: String, counter: String, threats: Array, count: int, radius: float, interval: float) -> void:
	var serial := int(state.get(counter, 0))
	var first := serial
	for i in range(count):
		if not spawn_event_guard(node, meta, key, threats[serial % threats.size()], serial, radius):
			break
		serial += 1
	state[counter] = serial
	state.spawn = interval if serial > first else .7

func spawn_event_guard(node: Node3D, meta: String, key: String, kind: int, serial: int, radius: float) -> bool:
	if world.get_tree().get_nodes_in_group("enemies").size() >= 72: return false
	var sphere := SphereShape3D.new()
	sphere.radius = .85 if kind == 4 else .62
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1 | 2 | 4 | 8
	query.exclude = [node.get_rid()]
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for i in range(16):
		var angle := (i + serial) * TAU / 8.0
		var distance := radius if i < 8 else radius + 2.0
		var point := node.global_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		if world.avatars.values().any(func(actor): return actor.global_position.distance_to(point) < 3.0): continue
		query.transform.origin = point + Vector3.UP
		if not space.intersect_shape(query, 1).is_empty(): continue
		var enemy: Node3D = world.make_enemy(kind, world.field_root.to_local(point), true, -1)
		enemy.set_meta(meta, key)
		return true
	return false

func interact_event(actor: Node3D) -> bool:
	for key in active_events:
		var node = active_events[key]
		if not event_in_reach(node,actor): continue
		var state: Dictionary = event_states[key]
		if state.complete or state.started or state.type=="nest": continue
		state.started = true; state.owner = actor.profile_id
		if state.type == "convoy":
			state.left = CONVOY_SECONDS
			state.spawn = 0.0
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
		var row := {"id":node.get_meta("uid"),"kind":node.kind,"p":node.global_position,"text":node.label.text}
		if node.kind == "escort":
			row.merge({"heading": node.escort_heading, "moving": node.escort_motion, "fire": node.escort_recoil})
		rows.append(row)
	for entry in transient:
		var node = entry.node
		if not is_instance_valid(node) or world.coord_at(node.global_position)!=world.sector_coord: continue
		if not node.has_meta("uid"): node.set_meta("uid",world.next_id())
		rows.append({"id":node.get_meta("uid"),"kind":"ramp","p":node.global_position,"text":""})
	return rows
func apply_visuals(rows: Array) -> void:
	var seen = {}
	for row in rows:
		if row.kind == "wall": continue
		seen[row.id] = true
		if not client_visuals.has(row.id):
			var node: Node3D
			if row.kind=="ramp":
				node = Node3D.new(); var mesh = VisualFactory.box(node,Vector3(2,.35,5),Vector3(0,1,0),Color("a17a66")); mesh.rotation.x = -.4
			else:
				node = StaticBody3D.new(); node.set_script(load("res://scripts/release15/event15.gd")); node.world = world; node.kind = row.kind
			world.add_child(node); client_visuals[row.id] = node
		var node: Node3D = client_visuals[row.id]; node.global_position = row.p
		if row.kind in ["nest","escort","convoy"]: node.label.text = row.text
		if row.kind=="nest": node.net_id = int(row.id)
		if row.kind == "escort":
			node.apply_escort_pose(float(row.get("heading", 0)), float(row.get("moving", 0)), float(row.get("fire", 0)))
	for id in client_visuals.keys():
		if not seen.has(id): client_visuals[id].queue_free(); client_visuals.erase(id)

func event_interactable(actor: Node3D) -> bool:
	for key in active_events:
		var node = active_events[key]
		if event_in_reach(node,actor) and not event_states[key].get("started",false) and not event_states[key].get("complete",false) and event_states[key].type!="nest": return true
	return false

func event_in_reach(node: Variant, actor: Node3D) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree(): return false
	var reach := CONVOY_REACH if node.kind == "convoy" else 4.0
	return node.global_position.distance_squared_to(actor.global_position) < reach * reach
