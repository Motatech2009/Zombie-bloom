extends "res://scripts/survival/survival_enemy.gd"
var leap_left = 0.0
var leap_start = Vector3.ZERO
var leap_end = Vector3.ZERO
var linked: Array = []
var swarm_threshold = .85
var growth = 0.0
var brood_clock = 1.0
var extra_motion = ""
var bridge_mask = false
var cast_visual: Node3D
func create_model(factor: float) -> void:
	if spec.id=="parasite": dog_model(); rig.scale = Vector3.ONE*.45; return
	super.create_model(factor)
	if spec.id=="shieldbearer": ModelFactory.part(rig,Vector3(.95,1.3,.22),Vector3(0,1.1,-.5),Color("b39375"))
	if spec.id=="hive":
		for i in range(4): VisualFactory.cylinder(rig,.3,.65,Vector3((i%2-.5)*.65,1+i/2*.4,.55),Color("b6b871"))
	if spec.id=="potter": rig.scale *= Vector3(.85,1.4,.85)
func _physics_process(delta: float) -> void:
	if proxy or health.dead or world.phase=="ended" or world.combat_paused(): return
	if leap_left>0:
		leap_left = maxf(0,leap_left-delta)
		var t = 1-leap_left/.85
		global_position = leap_start.lerp(leap_end,t)+Vector3.UP*sin(t*PI)*(3.0 if extra_motion=="leap" else 2.0)
		if extra_motion=="rain":
			var step = mini(4,int(t*4))
			var done: int = get_meta("rain_step",0)
			if step>done:
				set_meta("rain_step",step); world.hostile_blast(global_position*Vector3(1,0,1),2.3,18+world.waves.wave)
		if leap_left==0:
			global_position.y = leap_end.y
			if extra_motion=="leap":
				for actor in world.avatars.values():
					if not actor.health.dead and actor.roll_left<=0 and actor.global_position.distance_to(global_position)<2.2:
						actor.take_damage(float(spec.values.damage)); actor.pinned_left = 1.5; actor.pin_owner = self
		return
	if spec.id=="parasite":
		choose_target()
		if is_instance_valid(target) and target.is_in_group("campaign_structure") and global_position.distance_to(target.global_position)<2:
			growth += delta; target.disabled_left = maxf(target.disabled_left,.5)
			target.take_damage(delta*2*world.v15.day.damage_factor()); rig.scale = Vector3.ONE*(.45+growth*.035)
			if growth>=10:
				enemy_kind = 2; spec = CampaignData.enemy_spec(2).duplicate(true)
				spec.values.speed *= minf(1.75,1+.012*maxi(0,world.waves.wave-1))
				spec.values.damage *= 1+.055*maxi(0,world.waves.wave-1)
				health.setup(float(spec.values.health)*CampaignData.health_scale(maxi(1,world.waves.wave))*(1+.04*maxi(0,world.waves.wave-1)))
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
	if spec.id=="hive":
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
	if spec.id=="hive": ability_left = 999
	var casting_before: float = windup
	super._physics_process(delta)
	if windup>0 and casting_before<=0 and is_boss and spec.id in ["mauler","flyer"]:
		var offset: Vector3 = (cast_point-global_position)*Vector3(1,0,1)
		cast_visual = VisualFactory.box(world.effects,Vector3(1.5,.04,maxf(1,offset.length())),(global_position+cast_point)*.5*Vector3(1,0,1)+Vector3.UP*.08,Color("cc965c"),true)
		if offset.length_squared()>.01: cast_visual.look_at(cast_point*Vector3(1,0,1)+Vector3.UP*.08)
	if windup<=0 and is_instance_valid(cast_visual): cast_visual.queue_free()
func choose_target() -> void:
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
			rush_direction = (cast_point-global_position)*Vector3(1,0,1); rush_direction = rush_direction.normalized(); rush_left = .85; rush_hits.clear()
			for actor in world.avatars.values():
				var flat: Vector3 = (actor.global_position-global_position)*Vector3(1,0,1)
				if flat.length()<7 and flat.normalized().dot(rush_direction)>.6:
					actor.velocity += rush_direction*12; actor.move_and_collide(rush_direction*1.5); actor.take_damage((12+world.waves.wave)*world.v15.day.damage_factor())
		"mortar":
			var projectile: Node3D = world.projectile("acid",global_position+Vector3(0,1.6,0),cast_point,(22+world.waves.wave)*world.v15.day.damage_factor(),3.2,1.25)
			if projectile!=null: projectile.set_meta("toxic15",true)
		"broodmother":
			if summon_casts<3:
				summon_casts += 1
				for i in range(2): world.spawn_minion(self,6,i)
			shield_left = 2
		"flyer":
			extra_motion = "rain"; leap_start = global_position; leap_end = cast_point+Vector3.UP*2.8; leap_left = .85; set_meta("rain_step",0)
		"hound":
			extra_motion = "leap"; leap_start = global_position; leap_end = cast_point*Vector3(1,0,1); leap_left = .85
		"potter":
			var direction: Vector3 = (cast_point-global_position).normalized()
			var point = global_position+direction*5
			world.v15.temporary_wall(point)
		"hive":
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
	if is_instance_valid(cast_visual): cast_visual.queue_free()
	if spec.id=="bridge": world.v15.make_ramp(global_position)
	if world.explosive15 or world.critical15: world.v15.clay_fragments(global_position,spec.color)
	super.die()

func _exit_tree() -> void:
	if is_instance_valid(cast_visual): cast_visual.queue_free()
	super._exit_tree()
