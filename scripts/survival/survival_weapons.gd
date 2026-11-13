extends "res://scripts/campaign/campaign_weapons.gd"
var hand_weapon: int = -1
var visual_item: String = ""
var last_item: String = ""
var last_model: int = -2

func _init() -> void:
	super()
	owned.resize(Arsenal.WEAPONS.size())
	ammo.assign([12,0,0,0,0,0,0,0,0])

func sync_hand() -> void:
	owned.resize(Arsenal.WEAPONS.size())
	ammo.resize(Arsenal.WEAPONS.size())
	for i in range(Arsenal.WEAPONS.size()): owned[i] = actor.bag.count(ItemBag.WEAPON_IDS[i])>0
	var next_hand := ItemBag.WEAPON_IDS.find(actor.bag.hand())
	if next_hand!=hand_weapon: reload_left = 0
	hand_weapon = next_hand
	if hand_weapon>=0 and hand_weapon!=slot: equip(hand_weapon)
	visual_item = actor.bag.hand()
	if (last_model!=hand_weapon or last_item!=visual_item) and is_instance_valid(actor.rig): rebuild_model()

func equip(index: int) -> void:
	if index<0 or index>=Arsenal.WEAPONS.size() or actor.bag.count(ItemBag.WEAPON_IDS[index])==0: return
	for i in range(9):
		if actor.bag.slots[i].id==ItemBag.WEAPON_IDS[index]: actor.bag.selected = i; break
	slot = index
	hand_weapon = index
	reload_left = 0
	cooldown = maxf(cooldown,.15)

func _process(delta: float) -> void:
	if world.is_client: return
	cooldown = maxf(0,cooldown-delta)
	if reload_left<=0: return
	reload_left = maxf(0,reload_left-delta)
	if reload_left==0:
		var id: String = ItemBag.AMMO_IDS[slot]
		var transfer := mini(capacity()-ammo[slot],actor.bag.count(id))
		if transfer>0 and actor.bag.remove(id,transfer): ammo[slot] += transfer

func reload() -> bool:
	if actor.roll_left>0 or hand_weapon<0 or reload_left>0 or ammo[slot]>=capacity() or actor.bag.count(ItemBag.AMMO_IDS[slot])<=0: return false
	reload_total = maxf(.3,float(spec().values.reload)*reload_multiplier)
	reload_left = reload_total
	return true

func spec() -> Resource:
	return Arsenal.WEAPONS[slot]

func capacity(index: int = -1) -> int:
	var chosen := slot if index<0 else index
	return 1 if chosen==4 else maxi(1,ceili(float(Arsenal.WEAPONS[chosen].values.capacity)*capacity_multiplier))

func shoot(direction: Vector3) -> bool:
	if world.is_client or actor.roll_left>0 or hand_weapon<0 or actor.gather_target!=null or actor.health.dead: return false
	world.shot_owner = actor.peer_id
	var result := false
	if slot in [6,8]: result = special_shot(direction)
	else: result = super.shoot(direction)
	if result and slot not in [6,8]:
		var origin: Vector3 = actor.global_position+Vector3(0,1.15,0)
		var aim: Vector3 = world.air_aim(origin,direction,float(spec().values.range))
		var end := origin+aim*float(spec().values.range)
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1|4|8,[actor.get_rid()]))
		world.shot_visual(origin,hit.position if not hit.is_empty() else end,spec().color,false)
	world.shot_owner = 1
	return result

func special_shot(direction: Vector3) -> bool:
	if cooldown>0 or reload_left>0 or not owned[slot]: return false
	if ammo[slot]<=0: reload(); return false
	ammo[slot] -= 1
	cooldown = maxf(.04,float(spec().values.interval)/(rate_multiplier*(1.65 if actor.power_left("rapid")>0 else 1)))
	var origin: Vector3 = actor.global_position+Vector3(0,1.15,0)
	var aim: Vector3 = world.air_aim(origin,direction,float(spec().values.range))
	var end := origin+aim*float(spec().values.range)
	var excludes: Array[RID] = [actor.get_rid()]
	var victims: Array[Node3D] = []
	var previous := origin
	var damage: float = spec().values.damage*damage_multiplier
	for step in range(3 if slot==6 else 1):
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1|4|8,excludes))
		if hit.is_empty(): break
		end = hit.position if not hit.collider.is_in_group("enemies") else origin+aim*float(spec().values.range)
		if not hit.collider.is_in_group("enemies"): break
		var victim: Node3D = hit.collider
		victims.append(victim)
		victim.take_damage(damage*pow(.8,step))
		excludes.append(victim.get_rid())
		previous = hit.position
	if slot==8 and not victims.is_empty(): end = previous
	world.effects.tracer(origin,end,spec().color)
	world.effects.flash(origin+aim*.9)
	world.shot_visual(origin,end,spec().color,false)
	if slot==8 and not victims.is_empty():
		for chain in range(3):
			var next: Node3D
			var nearest := 5.5
			for candidate in get_tree().get_nodes_in_group("enemies"):
				if candidate in victims or candidate.health.dead: continue
				var point: Vector3 = candidate.global_position+Vector3(0,candidate.aim_height,0)
				var distance := previous.distance_to(point)
				if distance>=nearest: continue
				var trace := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(previous+Vector3.UP*.1,point,1|8))
				if trace.is_empty(): next = candidate; nearest = distance
			if next==null: break
			var point: Vector3 = next.global_position+Vector3(0,next.aim_height,0)
			next.take_damage(damage*pow(.7,chain+1))
			world.effects.tracer(previous,point,spec().color)
			world.shot_visual(previous,point,spec().color,false)
			victims.append(next)
			previous = point
	world.audio.play_tone(880 if slot==8 else 100,.09,.13)
	fired.emit()
	return true

func rebuild_model() -> void:
	last_model = hand_weapon
	last_item = visual_item
	var gun: MeshInstance3D = actor.rig.get_node("Gun")
	gun.visible = hand_weapon>=0 or visual_item in ["grenade","medkit"]
	for child in gun.get_children(): gun.remove_child(child); child.queue_free()
	gun.mesh = null
	if not gun.visible: return
	gun.scale = Vector3.ONE
	var model_path: String = "res://assets/models/weapon_"+ItemBag.WEAPON_IDS[hand_weapon]+".tscn" if hand_weapon>=0 else "res://assets/models/item_"+visual_item+".tscn"
	var model: Node3D = load(model_path).instantiate()
	gun.add_child(model)
	ClayStyle.apply_tree(model)
