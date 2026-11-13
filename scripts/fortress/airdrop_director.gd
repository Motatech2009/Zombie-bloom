class_name AirdropDirector
extends RefCounted
const INTERVAL := 600.0
const LANDING := 8.0
var world: Node3D
var left: float = INTERVAL
var serial: int = 0
var state: Dictionary = {}
var crate: Node3D
var spawn_left: float = 0

func coord() -> Vector2i:
	return Vector2i(int(state.coord[0]),int(state.coord[1])) if not state.is_empty() else Vector2i.ZERO
func at_sector() -> bool:
	return not state.is_empty() and not state.collected and coord()==world.sector_coord and world.field_root!=null
func total_guards() -> int:
	return int(state.get("base_guards",0))*world.team_multiplier()
func remaining() -> int:
	if state.is_empty(): return 0
	var total := total_guards()
	var dead := 0
	for index in state.dead:
		if int(index)<total: dead += 1
	return maxi(0,total-dead)
func active_guards() -> Array:
	return world.get_tree().get_nodes_in_group("airdrop_guards").filter(func(enemy): return int(enemy.get_meta("supply_event",-1))==int(state.get("serial",-2)) and not enemy.health.dead)
func can_open() -> bool:
	return at_sector() and state.land<=0 and remaining()==0 and active_guards().is_empty()

func tick(delta: float) -> void:
	if world.is_client or world.phase=="ended": return
	left -= delta
	if left<=0:
		var overdue := -left
		var count := floori(overdue/INTERVAL)+1
		serial += count
		left += count*INTERVAL
		start_drop()
		state.land = maxf(0,LANDING-fmod(overdue,INTERVAL))
	elif not state.is_empty(): state.land = maxf(0,float(state.land)-delta)
	ensure_crate()
	spawn_left = maxf(0,spawn_left-delta)
	if at_sector() and state.land<=0 and spawn_left<=0:
		spawn_guard()
		spawn_left = .45

func start_drop() -> void:
	if is_instance_valid(crate): crate.queue_free()
	crate = null
	var target := Vector2i.ZERO
	while target==Vector2i.ZERO:
		target = Vector2i(world.world_rng.randi_range(-3,3),world.world_rng.randi_range(-3,3))
		if SectorGenerator.distance(target)>3: target = Vector2i.ZERO
	var weapon: String = ItemBag.WEAPON_IDS[world.world_rng.randi_range(1,Arsenal.WEAPONS.size()-1)]
	var contents := {"scrap":160,"wood":60,"parts":24,"rifle_ammo":60,"heavy":18,"cells":24,"grenade":4,"medkit":2}
	contents[weapon] = 1
	state = {"serial":serial,"coord":[target.x,target.y],"land":LANDING,"seed":world.world_rng.randi_range(1,2147483647),"base_guards":20+mini(20,world.waves.wave)*2,"dead":[],"contents":contents,"collected":false}
	world.notify("AIRDROP · Setor (%d,%d). Escolta pesada e um chefe. M mostra a queda." % [target.x,target.y])
	if at_sector():
		world.descriptor = decorate(world.descriptor)
		world.scale_field_population()
		world.scene_revision += 1

func decorate(data: Dictionary) -> Dictionary:
	if state.is_empty() or state.collected or data.coord!=coord(): return data
	data.risk = 4; data.supply = int(state.serial)
	var population := maxi(int(data.count),48+mini(20,world.waves.wave)*3)
	data.count = population
	data.roster.clear()
	for i in range(population): data.roster.append([3,12,5,14,4,13,7,6,11,2][i%10])
	data.base_count = population; data.base_roster = data.roster.duplicate()
	return data

func ensure_crate() -> void:
	if not at_sector():
		if is_instance_valid(crate): crate.queue_free()
		crate = null; return
	if is_instance_valid(crate) and not crate.is_queued_for_deletion() and int(crate.get_meta("event",-1))==int(state.serial): return
	crate = Node3D.new(); crate.set_script(load("res://scripts/fortress/airdrop_crate.gd"))
	crate.world = world; crate.director = self
	crate.set_meta("event",int(state.serial)); crate.set_meta("airdrop",true)
	crate.set_meta("contents",state.contents); crate.set_meta("uid",world.next_id())
	crate.position = Vector3.ZERO
	world.field_root.add_child(crate)

func spawn_guard() -> bool:
	if not at_sector() or world.field_alive()>=24 or world.get_tree().get_nodes_in_group("enemies").size()>=60 or active_guards().size()>=12: return false
	var alive := {}
	for enemy in active_guards(): alive[int(enemy.get_meta("supply_index"))] = true
	var index := -1
	for i in range(total_guards()):
		if not i in state.dead and not alive.has(i): index = i; break
	if index<0: return false
	var angle := float(index)*2.399963+float(int(state.seed)%628)/100.0
	var pos := Vector3(cos(angle)*10,0,sin(angle)*10)
	var kind: int = 8 if index==0 else [3,12,5,14,4,13,7,6,11][index%9]
	var enemy: Node3D = world.make_enemy(kind,pos,true,-2)
	enemy.health.setup(enemy.health.maximum*1.65)
	enemy.spec.values.damage *= 1.25
	enemy.add_to_group("airdrop_guards"); enemy.set_meta("supply_event",int(state.serial)); enemy.set_meta("supply_index",index)
	return true

func defeated(enemy: Node3D) -> void:
	if state.is_empty() or int(enemy.get_meta("supply_event",-1))!=int(state.serial): return
	var index: int = enemy.get_meta("supply_index")
	if not index in state.dead: state.dead.append(index)
	if remaining()==0: world.notify("ESCOLTA VENCIDA · O airdrop pode ser aberto. Segure COLETAR junto à caixa.")

func mark_collected() -> void:
	if not state.is_empty() and state.contents.is_empty():
		state.collected = true
		world.notify("AIRDROP RECUPERADO · Leve os materiais ao Núcleo.")

func dump() -> Dictionary:
	return {"left":left,"serial":serial,"state":state.duplicate(true)}
func restore(data: Dictionary) -> void:
	left = float(data.left); serial = int(data.serial); state = data.state.duplicate(true)
	if is_instance_valid(crate): crate.queue_free()
	crate = null

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("left") is float and not data.get("left") is int or not data.get("serial") is float and not data.get("serial") is int or not data.get("state") is Dictionary: return false
	if not is_finite(float(data.left)) or data.left<0 or data.left>INTERVAL or data.serial<0 or data.serial>100000000 or int(data.serial)!=data.serial: return false
	var s: Dictionary = data.state
	if s.is_empty(): return true
	for key in ["serial","coord","land","seed","base_guards","dead","contents","collected"]:
		if not s.has(key): return false
	if not s.coord is Array or s.coord.size()!=2 or not s.dead is Array or not s.contents is Dictionary or not s.collected is bool: return false
	for value in s.coord:
		if not (value is int or value is float) or not is_finite(float(value)) or int(value)!=value or absf(value)>3: return false
	var point := Vector2i(s.coord[0],s.coord[1])
	if point==Vector2i.ZERO or SectorGenerator.distance(point)>3: return false
	for value in [s.serial,s.land,s.seed,s.base_guards]:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	if int(s.serial)!=s.serial or int(s.seed)!=s.seed or s.serial<1 or s.serial!=data.serial or s.seed<1 or s.seed>2147483647 or s.land<0 or s.land>LANDING or s.base_guards<20 or s.base_guards>60 or int(s.base_guards)!=s.base_guards: return false
	var seen := {}
	for index in s.dead:
		if not (index is int or index is float) or not is_finite(float(index)) or int(index)!=index or index<0 or index>=int(s.base_guards)*8 or seen.has(int(index)): return false
		seen[int(index)] = true
	for id in s.contents:
		var quantity = s.contents[id]
		if id not in ItemBag.IDS or not (quantity is int or quantity is float) or not is_finite(float(quantity)) or int(quantity)!=quantity or quantity<1 or quantity>10000: return false
	return s.collected==s.contents.is_empty()
