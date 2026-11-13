extends Node3D
var world: Node3D
var data: Dictionary
var dead: Array[int] = []
var activated: bool = false
var contents: Dictionary = {}
var crate: Node3D
var roof: Node3D
var lid: Node3D
var wall_visuals: Array[Node3D] = []
var label: Label3D
var spawn_left: float = .4
var guard_total: int = 0
var cutaway: float = 1

func wall(size: Vector3,pos: Vector3,color: Color) -> void:
	var body := StaticBody3D.new(); add_child(body); body.position = pos; body.collision_layer = 1
	VisualFactory.collider(body,size,Vector3(0,size.y/2,0))
	var pivot := Node3D.new(); body.add_child(pivot); wall_visuals.append(pivot)
	ClayScenery.box(pivot,size,Vector3(0,size.y/2,0),color,"brick" if data.style==1 else "clay")
	# Mark only physical walls; the interior and 3.6 m doorway remain walkable.
	var arena: Node3D = get_parent()
	var point := position+pos.rotated(Vector3.UP,rotation.y)
	var footprint := Vector2(size.x+.5,size.z+.5)
	arena.mark_solid(point,footprint)

func _ready() -> void:
	add_to_group("raid_houses")
	contents = data.reward.duplicate()
	guard_total = int(data.guards)*world.team_multiplier()
	var color: Color = [Color("c4a082"),Color("c58d75"),Color("89a49c")][int(data.style)]
	ClayScenery.box(self,Vector3(10,.12,10),Vector3(0,-.01,0),Color("a69373"),"wood")
	wall(Vector3(.45,3.1,10),Vector3(-5,0,0),color)
	wall(Vector3(.45,3.1,10),Vector3(5,0,0),color)
	wall(Vector3(10,3.1,.45),Vector3(0,0,5),color)
	wall(Vector3(3.2,3.1,.45),Vector3(-3.4,0,-5),color)
	wall(Vector3(3.2,3.1,.45),Vector3(3.4,0,-5),color)
	# Open doorway; lintel and roof are visual only, avoiding an invisible ceiling.
	ClayScenery.box(self,Vector3(3.5,.12,3),Vector3(0,.01,-6.4),Color("ae9e82"))
	roof = Node3D.new(); add_child(roof); roof.name = "Roof"
	ClayScenery.box(roof,Vector3(3.6,.35,.5),Vector3(0,2.95,-5),color)
	for side in [-1,1]:
		var slope := ClayScenery.box(roof,Vector3(5.8,.28,10.8),Vector3(side*2.55,3.6,0),Color("997965") if data.style!=2 else Color("697b80"),"wood")
		slope.rotation.z = -side*.22
	ClayScenery.box(roof,Vector3(1,.9,1),Vector3(3.2,4.1,2.4),Color("ac8b78"),"brick")
	for side in [-1,1]:
		ClayScenery.box(roof,Vector3(.08,1.1,1.8),Vector3(side*5.25,1.7,0),Color("73a6ab"))
		for z in [-.85,.85]: ClayScenery.box(roof,Vector3(.12,1.3,.12),Vector3(side*5.31,1.7,z),Color("dfc5a0"),"wood")
	# Low furniture does not obstruct the central firing/escape route.
	ClayScenery.box(self,Vector3(2,.55,1.1),Vector3(-3,.3,2.8),Color("86977c"))
	ClayScenery.box(self,Vector3(1.8,.15,1),Vector3(-3,.65,2.8),Color("d2baa0"))
	ClayScenery.box(self,Vector3(1.6,1.2,.65),Vector3(3,.6,3.8),Color("8f7358"),"wood")
	var banner := Node3D.new(); banner.set_script(load("res://scripts/clay/scenery_motion.gd")); roof.add_child(banner)
	banner.position = Vector3(2.4,2.5,-5.35); banner.phase = data.id; banner.amplitude = .08
	ClayScenery.box(banner,Vector3(.65,1.1,.06),Vector3(0,-.5,0),Color("b6bd80"))
	crate = Node3D.new(); crate.name = "Supplies"; add_child(crate); crate.position = Vector3(0,0,2.4)
	ClayScenery.box(crate,Vector3(1.5,.9,1.2),Vector3(0,.45,0),Color("bb975e"),"wood")
	for x in [-.5,.5]: ClayScenery.box(crate,Vector3(.1,1,1.25),Vector3(x,.5,0),Color("627c78"))
	lid = Node3D.new(); crate.add_child(lid); lid.position = Vector3(0,.9,.6)
	ClayScenery.box(lid,Vector3(1.56,.15,1.25),Vector3(0,.04,-.6),Color("d0ac70"),"wood")
	crate.set_meta("contents",contents); crate.set_meta("house_id",int(data.id)); crate.set_meta("uid",world.next_id())
	if not world.is_client: crate.add_to_group("survival_sources")
	label = VisualFactory.health_label(self,2.7); label.position = Vector3(0,2.7,-5.5); label.font_size = 21

func active_guards() -> Array[Node]:
	return get_tree().get_nodes_in_group("house_guards").filter(func(enemy): return not enemy.health.dead and int(enemy.get_meta("house_id",-1))==int(data.id))

func remaining() -> int:
	if not world.is_client: guard_total = int(data.guards)*world.team_multiplier()
	return maxi(0,guard_total-dead.filter(func(index): return index<guard_total).size())
func can_open() -> bool: return activated and remaining()==0 and active_guards().is_empty()
func defeated(index: int) -> void:
	if not index in dead: dead.append(index)
	if remaining()==0: world.notify("CASA %d LIMPA · Caixa de suprimentos liberada. Segure E no interior." % (int(data.id)+1))

func _physics_process(delta: float) -> void:
	if world.is_client or world.phase=="ended": return
	guard_total = int(data.guards)*world.team_multiplier()
	if not activated:
		for actor in world.avatars.values():
			if not actor.health.dead and actor.position.distance_to(global_position)<22: activated = true; break
	if not activated or remaining()==0: return
	spawn_left -= delta
	if spawn_left>0 or active_guards().size()>=6 or world.field_alive()>=24 or get_tree().get_nodes_in_group("enemies").size()>=60: return
	spawn_left = .6
	var alive := active_guards().map(func(enemy): return int(enemy.get_meta("house_guard")))
	for index in range(guard_total):
		if index in dead or index in alive: continue
		var point := Vector3((index%3-1)*2.6,0,-1.6+(index/3)%2*2.3)
		var global_point := to_global(point)
		if world.avatars.values().any(func(actor): return not actor.health.dead and actor.position.distance_to(global_point)<2.2): continue
		var query := PhysicsShapeQueryParameters3D.new(); var shape := SphereShape3D.new(); shape.radius = .65
		query.shape = shape; query.transform.origin = global_point+Vector3.UP; query.collision_mask = 2|4|8
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		var kind: int = [0,1,3,5,12,13][(index+int(world.descriptor.risk))%6]
		var enemy: Node3D = world.make_enemy(kind,world.field_root.to_local(global_point),true,-3)
		enemy.set_meta("house_id",int(data.id)); enemy.set_meta("house_guard",index); enemy.add_to_group("house_guards")
		enemy.health.setup(enemy.health.maximum*1.25); enemy.spec.values.damage *= 1.15
		return

func _process(delta: float) -> void:
	var near: float = world.player.position.distance_to(global_position)
	cutaway = move_toward(cutaway,.20 if near<12 else 1.0,delta*4)
	roof.visible = near>=12
	for pivot in wall_visuals: pivot.scale.y = cutaway
	label.visible = near<18
	label.text = "CASA %d · %s" % [int(data.id)+1,"SAQUE RECUPERADO" if contents.is_empty() else "SEGURE E · SUPRIMENTOS" if can_open() else "%d INFECTADOS" % remaining()]
	var opening: float = 0
	for actor in world.avatars.values():
		if actor.gather_kind=="loot" and actor.gather_progress>0 and actor.position.distance_to(crate.global_position)<3: opening = maxf(opening,actor.gather_progress/maxf(.01,actor.gather_duration))
	lid.rotation.x = lerp_angle(lid.rotation.x,opening*1.1,minf(1,delta*8))
	crate.visible = not contents.is_empty()

func dump() -> Dictionary:
	return {"id":int(data.id),"dead":dead.duplicate(),"activated":activated,"total":guard_total,"contents":contents.duplicate()}
func apply_state(state: Dictionary) -> void:
	dead.assign(state.dead); activated = state.activated; guard_total = int(state.total)
	contents = state.contents.duplicate(); crate.set_meta("contents",contents)
