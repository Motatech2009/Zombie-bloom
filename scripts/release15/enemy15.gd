extends "res://scripts/survival/survival_enemy.gd"
var leap_left = 0.0
var landing18 := 0.0
var leap_start = Vector3.ZERO
var leap_end = Vector3.ZERO
var linked: Array = []
var swarm_threshold = .85
var growth = 0.0
var brood_clock = 1.0
var extra_motion = ""
var bridge_mask = false
var boss18: BossCombat18
var hunt_target18: Node3D
var hunt_left18 := 0.0
var hunt_boost18 := false
var temporary_left18 := 0.0
var stride_boss := false
var ground_motion := 0.0
var stride_phase := 0.0
var stride_blend := 0.0

func _ready() -> void:
	super._ready()
	if is_boss:
		boss18 = BossCombat18.new(self)
		stride_boss = spec.id in ["hound","hive"] and rig.has_method("stride_pose")

func force_hunt(actor: Node3D, duration: float, boost: bool) -> void:
	hunt_target18 = actor
	hunt_left18 = duration
	hunt_boost18 = boost
	target = actor
	path.clear()
	think_left = 0.0

func tick_hunt(delta: float) -> bool:
	if temporary_left18 > 0.0:
		temporary_left18 = maxf(0, temporary_left18 - delta)
		if temporary_left18 <= 0.0:
			queue_free()
			return false
	if hunt_left18 > 0.0:
		hunt_left18 = maxf(0, hunt_left18 - delta)
		if hunt_left18 <= 0.0 or not prey_available():
			hunt_left18 = 0.0
			hunt_target18 = null
			hunt_boost18 = false
			target = null
			path.clear()
			think_left = 0.0
	return true

func prey_available() -> bool:
	return (is_instance_valid(hunt_target18) and not hunt_target18.health.dead
		and world.coord_at(hunt_target18.global_position) == world.coord_at(global_position))

func movement_boost() -> float:
	return 1.15 if hunt_boost18 and prey_available() else 1.0
func create_model(factor: float) -> void:
	var imported: Node3D = preload("res://scripts/presentation/enemy_models16.gd").create(self,factor)
	if imported!=null: rig = imported; return
	if spec.id=="parasite": dog_model(); rig.scale = Vector3.ONE*.45; return
	super.create_model(factor)
	if spec.id=="shieldbearer": ModelFactory.part(rig,Vector3(.95,1.3,.22),Vector3(0,1.1,-.5),Color("b39375"))
	if spec.id=="hive":
		for i in range(4): VisualFactory.cylinder(rig,.3,.65,Vector3((i%2-.5)*.65,1+i/2*.4,.55),Color("b6b871"))
	if spec.id=="potter": rig.scale *= Vector3(.85,1.4,.85)
func _physics_process(delta: float) -> void:
	if proxy or health.dead or world.phase=="ended" or world.combat_paused(): return
	if not tick_hunt(delta): return
	ground_motion = 0.0
	landing18 = maxf(0.0, landing18 - delta)
	if boss18 != null and boss18.tick(delta):
		shield_left = maxf(0, shield_left - delta)
		snare_left = maxf(0, snare_left - delta)
		stun_left = maxf(0, stun_left - delta)
		return
	if leap_left>0:
		leap_left = maxf(0,leap_left-delta)
		var t = 1-leap_left/.85
		global_position = leap_start.lerp(leap_end,t)+Vector3.UP*sin(t*PI)*(3.0 if extra_motion=="leap" else 2.0)
		if extra_motion=="rain":
			var step = mini(4,int(t*4))
			var done: int = get_meta("rain_step",0)
			if step>done:
				set_meta("rain_step",step)
				var point := BossCombat18.flat(global_position)
				world.boss_sound(BossSoundBank.Cue.SPORES,point)
				world.hostile_blast(point,2.3,18+world.waves.wave)
		if leap_left==0:
			global_position.y = leap_end.y
			if extra_motion=="leap":
				landing18 = .36
				world.boss_sound(BossSoundBank.Cue.LAND,global_position)
				BossFx18.spawn(world, "quakes", global_position, Vector3.FORWARD, 2.2, 0, .48)
				for actor in world.avatars.values():
					if not actor.health.dead and actor.roll_left<=0 and actor.global_position.distance_to(global_position)<2.2:
						actor.take_damage(float(spec.values.damage)); actor.pinned_left = 1.5; actor.pin_owner = self
		return
	if spec.id=="parasite" and temporary_left18 <= 0.0:
		choose_target()
		if is_instance_valid(target) and target.is_in_group("campaign_structure") and global_position.distance_to(target.global_position)<2:
			growth += delta; target.disabled_left = maxf(target.disabled_left,.5)
			target.take_damage(delta*2*world.v15.day.damage_factor()); rig.scale = Vector3.ONE*(.45+growth*.035)
			if growth>=10:
				enemy_kind = 2; spec = CampaignData.enemy_spec(2).duplicate(true)
				spec.values.speed *= minf(1.75,1+.012*maxi(0,world.waves.wave-1))
				spec.values.damage *= 1+.055*maxi(0,world.waves.wave-1)
				health.setup(1.25*float(spec.values.health)*CampaignData.health_scale(maxi(1,world.waves.wave))*(1+.04*maxi(0,world.waves.wave-1)))
				set_meta("night_hp",1.0); set_meta("night_damage",1.0); set_meta("nest_speed",false)
				refresh_quality(); world.v15.day.apply_enemy(self)
			return
	if spec.id=="broodmother":
		brood_clock -= delta
		if brood_clock<=0:
			brood_clock = 1
			for dog in world.get_tree().get_nodes_in_group("enemies"):
				if str(dog.get_meta("summoner_token",""))==str(get_meta("summon_token",net_id)) and not dog.health.dead:
					health.heal(health.maximum*.01); world.shot_visual(global_position+Vector3.UP,dog.global_position+Vector3.UP,Color("b4d775")); break
	if spec.id=="hive" and health.current/health.maximum<=swarm_threshold and swarm_threshold>0:
		world.boss_sound(BossSoundBank.Cue.FLOCK,global_position)
		while health.current/health.maximum<=swarm_threshold and swarm_threshold>0:
			swarm_threshold -= .15
			for i in range(3): world.spawn_minion(self,7,i)
	if spec.id in ["walker","runner"]:
		var crossing = false
		for ramp in world.get_tree().get_nodes_in_group("clay_ramps"):
			if ramp.global_position.distance_to(global_position)<4: crossing = true; break
		collision_mask = 1|2 if crossing else 1|2|8
		bridge_mask = crossing
		if crossing and is_instance_valid(target): path.clear(); rig.position.y = 1.7
		elif not crossing: rig.position.y = 0
	if spec.id == "hive": ability_left = 999
	if spec.id == "potter" and windup <= 0.0: ability_left = 999
	super._physics_process(delta)
	if boss18 != null and windup > 0.0:
		var direction := BossCombat18.flat(cast_point - global_position)
		if direction.length_squared() > .01:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 13.0))


func create_cast_warning() -> Node3D:
	if boss18 == null: return super.create_cast_warning()
	var origin := BossCombat18.flat(global_position)
	var aim := BossCombat18.flat(cast_point)
	var direction := (aim - origin).normalized()
	match spec.id:
		"mauler", "flyer":
			var distance := 13.6 if spec.id == "mauler" else origin.distance_to(aim)
			return BossFx18.spawn(world, "line", origin, direction, maxf(1.0, distance), 1.35 if spec.id == "mauler" else 2.3, windup)
		"hound":
			return BossFx18.spawn(world, "thorn", aim, direction, 2.2, 0.0, windup + .85)
		"mortar":
			return BossFx18.spawn(world, "acid", aim, direction, 3.2, 0.0, windup)
		_:
			return BossFx18.spawn(world, "thorn", origin, direction, 3.2, 0.0, windup)

func normal_step(delta: float, update_pose: bool = true) -> void:
	super.normal_step(delta, update_pose and not stride_boss)
	if stride_boss and velocity.length_squared() > 1.01:
		ground_motion = Vector2(get_real_velocity().x,get_real_velocity().z).length() / maxf(.1,float(spec.values.speed))

func _process(delta: float) -> void:
	super._process(delta)
	if not proxy and not health.dead and rig.visible and not world.combat_paused():
		animate_special(delta, ground_motion)

func animate_replica(delta: float) -> void:
	if not stride_boss:
		super.animate_replica(delta)
	if not health.dead and rig.is_visible_in_tree() and not world.combat_paused():
		if boss18 != null:
			boss18.elapsed += delta
			leap_left = maxf(0, leap_left - delta)
			landing18 = maxf(0, landing18 - delta)
		animate_special(delta, replica_motion)

func animate_special(delta: float, motion: float) -> void:
	if boss18 == null: return
	if stride_boss: rig.striding = false
	if boss18.pose():
		stride_blend = 0.0
		return
	if stride_boss:
		var weight := clampf(motion, 0.0, 1.2)
		stride_blend = lerpf(stride_blend, weight, 1.0 - exp(-delta * 11.0))
		var pace := (1.55 if spec.id == "hound" else .82) + .17 * stride_blend
		stride_phase = fposmod(stride_phase + delta * pace * stride_blend, 1.0)
		rig.stride_pose(stride_phase, minf(1.0, stride_blend))
		if spec.id == "hive":
			var sway := sin(stride_phase*TAU)*stride_blend
			pose_arms(.24 - .15*sway,.24 + .15*sway)
			animate_melee()
		return
	rig.rotation.z = 0.0
	if spec.id != "flyer": rig.position.y = 0.0
	if spec.id == "flyer":
		for wing in wings: wing.rotation.x = 0.0

func choose_target() -> void:
	if hunt_left18 > 0.0 and prey_available():
		target = hunt_target18
		return
	if temporary_left18 > 0.0:
		var candidate: Node3D
		var best := INF
		for actor in world.avatars.values():
			var distance := global_position.distance_to(actor.global_position)
			if not actor.health.dead and world.coord_at(actor.global_position) == world.coord_at(global_position) and distance < best:
				candidate = actor
				best = distance
		target = candidate
		return
	if is_boss and spec.id=="hound":
		target = self
		var nearest: float = 24
		for actor in world.avatars.values():
			if actor.health.dead or world.coord_at(actor.global_position)!=world.coord_at(global_position): continue
			var d: float = actor.global_position.distance_to(global_position)
			if d<nearest: nearest = d; target = actor
		if target!=self: return
	if spec.id=="parasite":
		target = world.core
		var distance = 100000.0
		for tower in world.get_tree().get_nodes_in_group("campaign_structure"):
			if not FortressData.turret(tower.spec.id) or tower.health.dead: continue
			var d = global_position.distance_to(tower.global_position)
			if d<distance: target = tower; distance = d
		return
	super.choose_target()
func boss_cast() -> void:
	match spec.id:
		"mauler":
			world.boss_sound(BossSoundBank.Cue.CHARGE,global_position)
			rush_direction = (cast_point-global_position)*Vector3(1,0,1); rush_direction = rush_direction.normalized(); rush_left = .85; rush_hits.clear()
			for actor in world.avatars.values():
				var flat: Vector3 = (actor.global_position-global_position)*Vector3(1,0,1)
				if flat.length()<7 and flat.normalized().dot(rush_direction)>.6:
					actor.velocity += rush_direction*12; actor.move_and_collide(rush_direction*1.5); actor.take_damage((12+world.waves.wave)*world.v15.day.damage_factor())
		"mortar":
			world.boss_sound(BossSoundBank.Cue.ACID_LAUNCH,global_position)
			var projectile: Node3D = world.projectile("acid",global_position+Vector3(0,1.6,0),cast_point,(22+world.waves.wave)*world.v15.day.damage_factor(),3.2,1.25,false)
			if projectile!=null:
				projectile.set_meta("toxic15",true)
				BossFx18.spawn(world,"acid",BossCombat18.flat(cast_point),Vector3.FORWARD,3.2,0.0,1.25)
		"broodmother":
			world.boss_sound(BossSoundBank.Cue.SUMMON,global_position)
			BossFx18.spawn(world, "brood", global_position, Vector3.FORWARD, 3.0, 0.0, .62)
			if summon_casts<3:
				summon_casts += 1
				for i in range(2): world.spawn_minion(self,6,i)
			shield_left = 2
		"flyer":
			world.boss_sound(BossSoundBank.Cue.DIVE,global_position)
			extra_motion = "rain"; leap_start = global_position; leap_end = cast_point+Vector3.UP*2.8; leap_left = .85; set_meta("rain_step",0)
		"hound":
			world.boss_sound(BossSoundBank.Cue.LEAP,global_position)
			extra_motion = "leap"; leap_start = global_position; leap_end = cast_point*Vector3(1,0,1); leap_left = .85
			BossFx18.spawn(world, "thorn", leap_end, Vector3.FORWARD, 2.2, 0, .85)
		"hive":
			world.boss_sound(BossSoundBank.Cue.FLOCK,global_position)
			for i in range(2): world.spawn_minion(self,7,i)
func take_damage(amount: float) -> void:
	if spec.id=="shieldbearer" and not world.explosive15:
		var origin: Vector3 = world.damage_origin15
		if not origin.is_finite() and world.avatars.has(world.shot_owner): origin = world.avatars[world.shot_owner].global_position
		if origin.is_finite():
			var direction: Vector3 = (origin-global_position)*Vector3(1,0,1)
			if direction.normalized().dot(-rig.global_basis.z)>.45: amount *= .2
	if amount>0:
		for actor in world.avatars.values():
			if actor.pin_owner==self and actor.peer_id!=world.shot_owner: actor.pinned_left = 0; actor.pin_owner = null
	super.take_damage(amount)
func die() -> void:
	if boss18 != null: boss18.finish()
	if spec.id=="bridge": world.v15.make_ramp(global_position)
	if world.explosive15 or world.critical15: world.v15.clay_fragments(global_position,spec.color)
	super.die()

func _exit_tree() -> void:
	if boss18 != null: boss18.finish()
	super._exit_tree()
