class_name ClientPrediction
extends RefCounted
const STEP := 1.0/60.0
const MAX_HISTORY := 120
var world: Node3D
var ready: bool = false
var sequence: int = 0
var history: Array[Dictionary] = []
var pending_roll: Variant
var visual_shots: Array[Dictionary] = []
var fire_left: float = 0
var hard_corrections: int = 0

func enabled() -> bool:
	return world.is_client and world.network!=null

func reset() -> void:
	ready = false; history.clear(); visual_shots.clear(); pending_roll = null
	fire_left = 0
	world.player.presentation_offset = Vector3.ZERO

func roll(direction: Vector3) -> bool:
	if not ready or world.player.health.dead or world.player.roll_cooldown>0 or pending_roll!=null: return false
	pending_roll = direction.normalized()
	return true

func begin_roll(actor: Node3D,direction: Vector3) -> void:
	if actor.roll_cooldown>0: return
	actor.roll_direction = direction.normalized(); actor.roll_left = actor.ROLL_DURATION; actor.roll_cooldown = actor.ROLL_RECHARGE

func simulate(frame: Dictionary) -> void:
	var actor: Node3D = world.player
	actor.roll_cooldown = maxf(0,actor.roll_cooldown-STEP)
	if frame.get("roll") is Vector3: begin_roll(actor,frame.roll)
	actor.simulate_motion(frame,STEP)
	var point: Vector3 = frame.get("aim",actor.aim)
	if point.length_squared()>.01: actor.aim = point.normalized()
	actor.rig.rotation.y = lerp_angle(actor.rig.rotation.y,atan2(-actor.aim.x,-actor.aim.z),.4)

func tick() -> void:
	if not enabled() or not ready or world.phase=="ended" or world.player.health.dead: return
	# Bounded backlog: never let a stalled connection invent more than two seconds of motion.
	if history.size()>=MAX_HISTORY: return
	var frame: Dictionary = world.network.test_input.duplicate(true) if not world.network.test_input.is_empty() else world.local_input(world.player).duplicate(true)
	sequence += 1; frame.seq = sequence
	if pending_roll!=null: frame.roll = pending_roll; pending_roll = null
	history.append(frame)
	simulate(frame)
	world.player.replica_motion = Vector2(world.player.velocity.x,world.player.velocity.z).length()/6.3
	preview_fire(frame)

func reconcile(state: Dictionary) -> void:
	if not enabled(): return
	var actor: Node3D = world.player
	var old_position: Vector3 = actor.position
	var first := not ready
	var ack: int = state.get("ack",0)
	history = history.filter(func(frame): return int(frame.seq)>ack)
	visual_shots = visual_shots.filter(func(shot): return int(shot.seq)>ack)
	actor.position = state.p; actor.velocity = state.get("velocity",Vector3.ZERO)
	actor.roll_left = float(state.get("roll",0)); actor.roll_cooldown = float(state.get("roll_cd",0)); actor.roll_direction = state.get("roll_dir",Vector3.FORWARD)
	ready = true
	if not state.down:
		for frame in history: simulate(frame)
	else: history.clear(); visual_shots.clear(); pending_roll = null
	var error: Vector3 = old_position-actor.position
	if first or error.length()>3 or state.down:
		actor.presentation_offset = Vector3.ZERO
		if not first and error.length()>3: hard_corrections += 1
	else: actor.presentation_offset += error

func preview_fire(frame: Dictionary) -> void:
	fire_left = maxf(0,fire_left-STEP)
	var actor: Node3D = world.player
	var slot: int = ItemBag.WEAPON_IDS.find(actor.bag.hand())
	if not frame.get("fire",false) or slot<0  or fire_left>0 or actor.roll_left>0 or actor.weapons.reload_left>0 or frame.get("interact",false): return
	var pending := 0
	for shot in visual_shots:
		if shot.slot==slot: pending += 1
	if actor.weapons.ammo[slot]<=pending: return
	if frame.has("target") and not MobileTargeting.can_fire(actor,world.target_enemy(int(frame.target.id))): return
	var spec: Resource = Arsenal.WEAPONS[slot]
	fire_left = maxf(.04,float(spec.values.interval)/actor.weapons.rate_multiplier)
	var origin: Vector3 = actor.global_position+Vector3(0,1.15,0)
	var direction: Vector3 = frame.aim
	var end := origin+direction*float(spec.values.range)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1|4|8,[actor.get_rid()]))
	world.effects.tracer(origin,hit.position if not hit.is_empty() else end,spec.color)
	world.effects.flash(origin); world.audio.play_tone(230,.07,.10); actor.recoil = .25
	visual_shots.append({"seq":frame.seq,"slot":slot})
