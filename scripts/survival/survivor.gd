extends "res://scripts/entities/player.gd"
var bag := ItemBag.new()
var peer_id: int = 1
var profile_id: String = "host"
var display_name: String = "Sobrevivente"
var proxy: bool = false
var net_input: Dictionary = {}
var last_damage: int = 0
var gather_target: Node3D
var gather_progress: float = 0
var gather_damage_mark: int = 0
var gather_start := Vector3.ZERO
var gather_kind: String = ""
var gather_duration: float = 2.8
var downed: bool = false
var previous_reload: bool = false
var target_position := Vector3.ZERO

func _ready() -> void:
	super._ready()
	if peer_id!=1:
		var tag := VisualFactory.health_label(self,2.4)
		tag.text = display_name
		tag.font_size = 20
	health.damaged.connect(func(_amount: float): last_damage += 1; cancel_gather())

func read_input() -> Dictionary:
	if peer_id!=1:
		if Time.get_ticks_msec()-int(net_input.get("time",0))>400: return {}
		return net_input
	return world.local_input(self)

func _physics_process(delta: float) -> void:
	if proxy or health.dead or world.phase=="ended": return
	var frame := read_input()
	clock += delta
	invulnerable = maxf(0,invulnerable-delta)
	recoil = move_toward(recoil,0,delta*2)
	for id in powers.keys():
		powers[id] = maxf(0,float(powers[id])-delta)
		if powers[id]<=0: powers.erase(id)
	shield_ring.visible = shield>0 and power_left("shield")>0
	var input: Vector2 = frame.get("move",Vector2.ZERO)
	var direction := Vector3(1,0,-1).normalized()*input.x+Vector3(-1,0,-1).normalized()*-input.y
	var speed := 6.3*speed_multiplier*(1.3 if frame.get("sprint",false) else 1.0)*(1.45 if power_left("speed")>0 else 1.0)
	if gather_target!=null: speed *= .25
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*35)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*35)
	velocity.y = -1
	move_and_slide()
	var point: Vector3 = frame.get("aim",Vector3.FORWARD)
	if point.length_squared()>.01: aim = point.normalized()
	bag.selected = clampi(int(frame.get("slot",bag.selected)),0,8)
	weapons.sync_hand()
	rig.rotation.y = lerp_angle(rig.rotation.y,atan2(-aim.x,-aim.z),minf(1,delta*24))
	VisualFactory.animate_human(rig,clock,input.length(),recoil,true)
	if frame.get("fire",false) and not (world.builder.active and peer_id==1):
		cancel_gather()
		if bag.hand()=="grenade": world.throw_for(self)
		elif bag.hand()=="medkit": world.use_medkit(self)
		else: weapons.shoot(aim)
	var reload_pressed: bool = frame.get("reload",false)
	if reload_pressed and not previous_reload: weapons.reload()
	previous_reload = reload_pressed
	if frame.get("interact",false): world.tick_gather(self,delta)
	else: cancel_gather()
	rig.visible = true

func cancel_gather() -> void:
	gather_target = null
	gather_progress = 0
	gather_kind = ""

func die() -> void:
	downed = true
	cancel_gather()
	rig.rotation.z = PI*.5
	world.survivor_down(self)

func revive(hp: float = 40) -> void:
	var maximum := health.maximum
	health.setup(maximum)
	health.current = minf(hp,maximum)
	downed = false
	rig.rotation.z = 0
	invulnerable = 2
