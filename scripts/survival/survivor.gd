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
var slow_left: float = 0
var previous_reload: bool = false
var target_position := Vector3.ZERO
const ROLL_DURATION: float = .42
const ROLL_RECHARGE: float = 5.0
const ROLL_SPEED: float = 13.0
var roll_left: float = 0
var roll_cooldown: float = 0
var roll_direction := Vector3.FORWARD
var replica_motion: float = 0

static func movement_direction(input: Vector2) -> Vector3:
	return Vector3(1,0,-1).normalized()*input.x+Vector3(-1,0,-1).normalized()*-input.y

func start_roll(direction: Vector3) -> bool:
	if proxy or world.is_client or health.dead or world.phase=="ended" or roll_cooldown>0 or not direction.is_finite(): return false
	direction.y = 0
	if direction.length_squared()>1.01: return false
	if direction.length_squared()<.01: direction = aim
	if direction.length_squared()<.01: direction = Vector3.FORWARD
	roll_direction = direction.normalized()
	roll_left = ROLL_DURATION
	roll_cooldown = ROLL_RECHARGE
	invulnerable = maxf(invulnerable,.20)
	weapons.reload_left = 0
	cancel_gather()
	return true

func stop_roll() -> void:
	roll_left = 0
	rig.rotation.x = 0
	rig.position = Vector3.ZERO

func animate_pose(moving: float) -> void:
	rig.position = Vector3.ZERO
	VisualFactory.animate_human(rig,clock*(1.35 if moving>1.1 else 1.0),moving,recoil,true)
	var gun: Node3D = rig.get_node("Gun")
	gun.position = Vector3(.34,1.1,-.64+recoil*.12)
	gun.rotation = Vector3.ZERO
	if weapons.reload_left>0:
		var progress := 1-weapons.reload_left/maxf(.01,weapons.reload_total)
		gun.rotation.z = -.4*sin(progress*PI)
		rig.get_node("ArmL").rotation = Vector3(.5+sin(progress*TAU)*.25,0,.65)
	elif gather_progress>0:
		rig.get_node("ArmL").rotation.x = .65+sin(clock*8)*.15
		gun.rotation.x = .5
	if roll_left>0:
		rig.get_node("LegL").rotation.x = 1.0
		rig.get_node("LegR").rotation.x = 1.0
		rig.get_node("ArmL").rotation = Vector3(.4,0,.2)
		rig.get_node("ArmR").rotation = Vector3(.4,0,-.2)
		rig.rotation.y = atan2(-roll_direction.x,-roll_direction.z)
		rig.rotation.x = -TAU*(1-roll_left/ROLL_DURATION)
		# Rotate around the torso instead of the feet, keeping the tumble above ground.
		rig.position = Vector3.UP*.85-rig.basis*(Vector3.UP*.85)
	else:
		rig.rotation.x = 0

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
	if proxy or world.phase=="ended": return
	roll_cooldown = maxf(0,roll_cooldown-delta)
	if health.dead: return
	var frame := read_input()
	clock += delta
	slow_left = maxf(0,slow_left-delta)
	invulnerable = maxf(0,invulnerable-delta)
	recoil = move_toward(recoil,0,delta*2)
	for id in powers.keys():
		powers[id] = maxf(0,float(powers[id])-delta)
		if powers[id]<=0: powers.erase(id)
	shield_ring.visible = shield>0 and power_left("shield")>0
	var input: Vector2 = frame.get("move",Vector2.ZERO)
	var direction := movement_direction(input)
	var speed := (0.55 if slow_left>0 else 1.0)*6.3*speed_multiplier*(1.3 if frame.get("sprint",false) else 1.0)*(1.45 if power_left("speed")>0 else 1.0)
	if gather_target!=null: speed *= .25
	var rolling := roll_left>0
	if rolling:
		velocity = roll_direction*ROLL_SPEED*(.55 if slow_left>0 else 1.0)
	else:
		velocity.x = move_toward(velocity.x,direction.x*speed,delta*35)
		velocity.z = move_toward(velocity.z,direction.z*speed,delta*35)
	velocity.y = -1
	move_and_slide()
	bag.selected = clampi(int(frame.get("slot",bag.selected)),0,8)
	weapons.sync_hand()
	frame = MobileTargeting.resolve(world,self,frame)
	var point: Vector3 = frame.get("aim",Vector3.FORWARD)
	if point.length_squared()>.01: aim = point.normalized()
	rig.rotation.y = lerp_angle(rig.rotation.y,atan2(-aim.x,-aim.z),minf(1,delta*24))
	animate_pose(Vector2(velocity.x,velocity.z).length()/6.3)
	if rolling:
		roll_left = maxf(0,roll_left-delta)
		if roll_left==0: stop_roll(); velocity = Vector3.ZERO
		previous_reload = frame.get("reload",false)
		return
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
	stop_roll()
	cancel_gather()
	rig.rotation.z = PI*.5
	world.survivor_down(self)

func revive(hp: float = 40) -> void:
	stop_roll()
	var maximum := health.maximum
	health.setup(maximum)
	health.current = minf(hp,maximum)
	downed = false
	rig.rotation.z = 0
	invulnerable = 2
