extends "res://scripts/entities/zombie.gd"
var field_enemy: bool = false
var is_boss: bool = false
var encounter_index: int = -1
var aim_height: float = 1.15
var acid_left: float = 2.5
var pounce_left: float = 0
var wings: Array[Node3D] = []

func _ready() -> void:
	spec = spec.duplicate(true)
	var w: int = maxi(1,world.waves.wave)
	spec.values.speed = float(spec.values.speed)*minf(1.75,1+.012*(w-1))
	spec.values.damage = float(spec.values.damage)*(1+.055*(w-1))
	add_to_group("enemies")
	add_to_group("damageable")
	collision_layer = 4
	collision_mask = 0 if spec.id=="flyer" else 1|2|8
	var factor: float = spec.values.scale
	var shape := CapsuleShape3D.new()
	shape.radius = .36*factor
	shape.height = 1.8*factor
	if spec.id=="hound": shape.height = .9; shape.radius = .32; aim_height = .55
	if spec.id=="flyer": shape.height = 1; shape.radius = .4; position.y = 2.8; aim_height = .6
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.height/2
	add_child(collision)
	add_child(health)
	health.setup(float(spec.values.health)*CampaignData.health_scale(w))
	health.died.connect(die)
	create_model(factor)
	label = VisualFactory.health_label(self,shape.height+.25)
	label.font_size = 22
	label.pixel_size = .012
	label.visible = false
	think_left = randf_range(0,.8)
	clock = randf()*10
	state = "seek"

func create_model(factor: float) -> void:
	if spec.id=="hound": dog_model()
	elif spec.id=="flyer": flying_model()
	else:
		rig = VisualFactory.human(self,spec.color,false)
		rig.scale = Vector3.ONE*factor
		if spec.id=="armored": VisualFactory.box(rig,Vector3(.7,.65,.42),Vector3(0,1.25,0),Color("3f5261"))
		if spec.id in ["demolisher","alpha"]: VisualFactory.box(rig,Vector3(.95,.35,.5),Vector3(0,1.5,0),Color("8a3e32"))
		if spec.id=="spitter": VisualFactory.cylinder(rig,.42,.55,Vector3(0,1.0,.25),Color("a5d45f"),true)

func dog_model() -> void:
	rig = Node3D.new()
	add_child(rig)
	VisualFactory.box(rig,Vector3(.5,.45,1.05),Vector3(0,.6,0),spec.color)
	VisualFactory.box(rig,Vector3(.42,.38,.5),Vector3(0,.7,-.6),spec.color.lightened(.12))
	VisualFactory.box(rig,Vector3(.25,.18,.4),Vector3(0,.6,-.85),Color("523c36"))
	for x in [-.16,.16]:
		VisualFactory.box(rig,Vector3(.06,.06,.04),Vector3(x,.8,-.87),Color("ee694b"),true)
		VisualFactory.box(rig,Vector3(.13,.24,.15),Vector3(x,.99,-.57),spec.color.darkened(.2))
	var tail := VisualFactory.box(rig,Vector3(.12,.14,.65),Vector3(0,.7,.7),spec.color)
	tail.rotation.x = -.5
	for x in [-.25,.25]:
		for z in [-.35,.35]:
			var leg := Node3D.new()
			rig.add_child(leg)
			leg.position = Vector3(x,.45,z)
			VisualFactory.box(leg,Vector3(.13,.45,.16),Vector3(0,-.22,0),Color("4d483d"))
			wings.append(leg)

func flying_model() -> void:
	rig = Node3D.new()
	add_child(rig)
	VisualFactory.box(rig,Vector3(.4,.55,.7),Vector3(0,.6,0),spec.color)
	VisualFactory.box(rig,Vector3(.3,.3,.35),Vector3(0,.8,-.4),Color("b79bad"))
	for side in [-1,1]:
		var wing := Node3D.new()
		rig.add_child(wing)
		wing.position = Vector3(side*.2,.7,0)
		VisualFactory.box(wing,Vector3(1.4,.09,.65),Vector3(side*.65,0,0),spec.color.darkened(.2))
		wings.append(wing)
	VisualFactory.ring(rig,.5,Vector3(0,-2.72,0),Color("9d84a8"))

func _physics_process(delta: float) -> void:
	if health.dead or world.phase=="ended": return
	if spec.id not in ["hound","flyer","spitter"]:
		super._physics_process(delta)
		return
	clock += delta
	think_left -= delta
	attack_left = maxf(0,attack_left-delta)
	acid_left -= delta
	pounce_left -= delta
	if (think_left<=0 or not is_instance_valid(target)) and (not world.has_method("allow_enemy_think") or world.allow_enemy_think(self)):
		choose_target()
		think_left = .6+fmod(float(encounter_index)*.13,.35)
		if spec.id!="flyer":
			path = world.route_for_enemy(self,target.global_position) if world.has_method("route_for_enemy") else world.arena.route(global_position,target.global_position)
			path_index = 1 if path.size()>1 else 0
	if not is_instance_valid(target): choose_target()
	var goal: Vector3 = target.global_position
	var flat := goal-global_position
	flat.y = 0
	var distance := flat.length()
	var direction := flat.normalized()
	if spec.id!="flyer" and path_index<path.size():
		var next := Vector3(path[path_index].x,global_position.y,path[path_index].y)
		if global_position.distance_to(next)<1: path_index += 1
		direction = (next-global_position).normalized()
	var speed: float = spec.values.speed
	if spec.id=="spitter" and distance<22 and line_of_sight():
		if distance<8: direction = -flat.normalized()
		else: speed = 0
		if acid_left<=0:
			acid_left = 3.8
			world.projectile("acid",global_position+Vector3(0,1.4,0),target.global_position+Vector3(0,.1,0),8*(1+.025*maxi(0,world.waves.wave-1)),2.5,1.15)
	if spec.id=="hound" and distance<9 and distance>3 and pounce_left<=0: pounce_left = 4
	if spec.id=="hound" and pounce_left>3.5: speed *= 1.65
	velocity = direction*speed
	velocity.y = 0 if spec.id=="flyer" else -1
	if spec.id=="flyer":
		if distance<1.5:
			velocity = Vector3.ZERO
			if attack_left<=0 and line_of_sight():
				target.take_damage(float(spec.values.damage))
				attack_left = spec.values.interval
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var body := get_slide_collision(i).get_collider()
		if is_instance_valid(body) and body.has_method("take_damage") and not body.is_in_group("enemies") and attack_left<=0:
			body.take_damage(float(spec.values.damage))
			attack_left = spec.values.interval
	rig.rotation.y = lerp_angle(rig.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*10))
	if rig.is_visible_in_tree() and spec.id=="hound":
		for i in range(wings.size()): wings[i].rotation.x = sin(clock*17+i*PI)*.7
	elif rig.is_visible_in_tree() and spec.id=="flyer":
		for i in range(wings.size()): wings[i].rotation.z = sin(clock*12)*.55*(1 if i==0 else -1)
		rig.position.y = sin(clock*4)*.12
	else: VisualFactory.animate_human(rig,clock,.5 if speed>0 else 0,0,false)
	if not label.has_meta("suppressed"):
		label.visible = health.current<health.maximum
		label.text = "%d" % ceili(health.current)

func line_of_sight() -> bool:
	var from := global_position+Vector3(0,aim_height,0)
	var ray := PhysicsRayQueryParameters3D.create(from,target.global_position+Vector3(0,1,0),1|2|8,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider==target

func choose_target() -> void:
	if not field_enemy and world.area_index!=-1:
		target = world.core
		return
	if field_enemy or spec.id=="hound": target = world.player
	else:
		super.choose_target()
		if spec.id in ["demolisher","alpha","flyer"]: target = world.core

func take_damage(amount: float) -> void:
	super.take_damage(amount*.6 if spec.id=="armored" else amount)
