extends "res://scripts/release15/enemy15.gd"
var encounter_key := ""
var exposed := 0.0
var root_cooldown := 7.0
var slam_cooldown := 4.0
var cast16 := ""
var roots16: Array = []
var heart: Node3D
var gait_phase := 0.0
var gait_weight := 0.0
var titan_arms: Array[Node3D] = []
var titan_legs: Array[Node3D] = []
func create_model(_factor: float) -> void:
	rig = preload("res://scripts/presentation/enemy_models16.gd").create(self,2.8)
	if rig==null: rig = VisualFactory.human(self,Color("68503e"),false); rig.scale = Vector3.ONE*2.8
	if not rig.get_meta("imported_enemy16",false):
		for side in [-1,1]:
			VisualFactory.box(rig,Vector3(.38,1.1,.4),Vector3(side*.54,.9,.04),Color("594d3a"))
			for i in range(2): VisualFactory.cylinder(rig,.12,.55,Vector3(side*(.28+i*.18),.2,.1),Color("6c7446"))
	heart = VisualFactory.cylinder(rig,.19,.24,rig.get_meta("heart_origin16",Vector3(0,1.22,-.28)),Color("8fc34c"),true)
	heart.rotation.x = PI/2; heart.scale = Vector3.ONE*.7
	rig.set_process(false)
	titan_arms = [rig.get_node("ArmL"), rig.get_node("ArmR")]
	titan_legs = [rig.get_node("LegL"), rig.get_node("LegR")]
func choose_target() -> void:
	target = self; var distance := 40.0
	for actor in world.avatars.values():
		if actor.health.dead or actor.region_coord!=world.coord_at(global_position) or world.exp16.safe(actor.global_position): continue
		var d: float = actor.global_position.distance_to(global_position)
		if d<distance: distance = d; target = actor
func warning_radius() -> float: return 5.2 if cast16=="slam" else 2.4
func _physics_process(delta: float) -> void:
	if proxy or health.dead or world.phase=="ended" or world.combat_paused(): return
	exposed = maxf(0,exposed-delta)
	if health.current<health.maximum*.25: enraged = true
	if windup>0:
		windup = maxf(0,windup-delta); velocity = Vector3.ZERO
		if windup<=0:
			if cast16=="slam": world.hostile_blast(cast_point,5.2,30); exposed = 3
			else:
				for point in roots16:
					world.hostile_blast(point,2.4,12)
					for actor in world.avatars.values():
						if actor.global_position.distance_to(point)<2.4 and actor.roll_left<=0: actor.slow_left = maxf(actor.slow_left,2)
			clear_roots(); if is_instance_valid(warning): warning.queue_free()
		return
	slam_cooldown -= delta; root_cooldown -= delta
	choose_target()
	if target==self: velocity = Vector3.ZERO; return
	var distance: float = target.global_position.distance_to(global_position)
	if slam_cooldown<=0 and distance<9:
		cast16 = "slam"; cast_point = global_position; windup = 1.4; slam_cooldown = 9*(.85 if enraged else 1.0)
		warning = VisualFactory.ring(world.effects,5.2,cast_point+Vector3.UP*.12,Color("d6a66d")); return
	if root_cooldown<=0 and distance<24:
		cast16 = "roots"; cast_point = target.global_position; windup = 1.2; root_cooldown = 13*(.85 if enraged else 1.0)
		roots16 = [cast_point,cast_point+Vector3(4,0,1),cast_point+Vector3(-3,0,3)]
		for point in roots16:
			var ring := VisualFactory.ring(world.effects,2.4,point+Vector3.UP*.12,Color("94b86b")); ring.add_to_group("titan_root_warnings"); ring.set_meta("owner16",net_id)
		return
	normal_step(delta, false)
	if not encounter_key.is_empty():
		var edge := Exploration16.TITAN_SECTOR_EDGE
		position.x = clampf(position.x, -edge, edge)
		position.z = clampf(position.z, -edge, edge)
	label.visible = MobilePlatform.enabled(); label.text = "TITÃ ENRAIZADO · %d/%d%s" % [ceili(health.current),ceili(health.maximum)," · CORAÇÃO EXPOSTO" if exposed>0 else ""]
func _process(delta: float) -> void:
	update_visibility(delta)
	if proxy or health.dead or not rig.visible or world.combat_paused() or world.phase == "ended":
		return
	var expected_speed := maxf(.1, float(spec.values.speed))
	var actual_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	var requested_speed := Vector2(velocity.x, velocity.z).length()
	update_titan_pose(delta, minf(actual_speed, requested_speed) / expected_speed)

func animate_replica(delta: float) -> void:
	if not health.dead and rig.is_visible_in_tree() and not world.combat_paused() and world.phase != "ended":
		update_titan_pose(delta, replica_motion)

func update_titan_pose(delta: float, motion: float) -> void:
	var moving := clampf(motion, 0.0, 1.0) if windup <= 0.0 and melee_left <= 0.0 else 0.0
	var follow := 1.0 - exp(-delta * 12.0)
	gait_weight = lerpf(gait_weight, moving, 1.0 - exp(-delta * 7.0))
	gait_phase = fposmod(gait_phase + delta * 4.7 * gait_weight, TAU)
	var step := sin(gait_phase) * gait_weight
	var pitch := .04 * gait_weight
	var arms := Vector2(.32 - step * .22, .32 + step * .22)
	var arm_spread := Vector2(.12, -.12)
	if windup > 0.0 and cast16 == "slam":
		var progress := 1.0 - clampf(windup / 1.4, 0.0, 1.0)
		var lift := smoothstep(0.0, .66, progress)
		var strike := smoothstep(.76, 1.0, progress)
		arms = Vector2.ONE * lerpf(.32 + .82 * lift, .25, strike)
		pitch = lerpf(-.20 * lift, .23, strike)
		arm_spread *= 1.0 + lift * .4
	elif windup > 0.0 and cast16 == "roots":
		var progress := 1.0 - clampf(windup / 1.2, 0.0, 1.0)
		var reach := smoothstep(0.0, .7, progress)
		arms += Vector2(.54, .75) * reach
		arm_spread += Vector2(.14, -.25) * reach
		pitch = .09 * reach
	elif melee_left > 0.0:
		var reach := smoothstep(.45, .0, melee_left)
		arms += Vector2(.65, .41) * reach
		pitch = .10 * reach
	rig.rotation.x = lerpf(rig.rotation.x, pitch, follow)
	rig.rotation.z = lerpf(rig.rotation.z, .045 * step, follow)
	rig.position.y = lerpf(rig.position.y, (1.0 - cos(gait_phase * 2.0)) * .038 * gait_weight, follow)
	heart.scale = heart.scale.lerp(Vector3.ONE * (1.3 if exposed > 0.0 else .7), follow)

	for i in range(2):
		var stride := step * (1.0 if i == 0 else -1.0)
		titan_legs[i].rotation.x = lerpf(titan_legs[i].rotation.x, stride * .28, follow)
		titan_arms[i].rotation.x = lerpf(titan_arms[i].rotation.x, arms[i], follow)
		titan_arms[i].rotation.z = lerpf(titan_arms[i].rotation.z, arm_spread[i], follow)
	if rig.has_method("sync_pose"):
		rig.sync_pose()
		var skeleton: Skeleton3D = rig.sk
		for i in range(2):
			var thigh := titan_legs[i].rotation.x
			var knee := minf(thigh, 0.0) * .86
			skeleton.set_bone_pose_rotation(rig.lower_joints[i], Quaternion(Vector3.RIGHT, knee))
			skeleton.set_bone_pose_rotation(rig.feet[i], Quaternion(Vector3.RIGHT, -(thigh + knee) * .64))

func take_damage(amount: float) -> void:
	var point: Vector3 = world.damage_point16
	if exposed>0 and point.is_finite() and not world.explosive15:
		var local := rig.to_local(point)
		if absf(local.x)<.26 and absf(local.y-1.22)<.28 and local.z<-.12: amount *= 1.5
	if amount>0 and not health.dead and world.avatars.has(world.shot_owner):
		var actor: Node3D = world.avatars[world.shot_owner]
		if actor.region_coord==world.coord_at(global_position):
			var state: Dictionary = world.exp16.sectors.get(encounter_key,{})
			var contributors: Array = state.get("contributors",[])
			if actor.profile_id not in contributors: contributors.append(actor.profile_id)
			state.contributors = contributors
	super.take_damage(amount)
func clear_roots() -> void:
	for node in world.get_tree().get_nodes_in_group("titan_root_warnings"):
		if int(node.get_meta("owner16",0))==net_id: node.queue_free()
	roots16.clear()
func die() -> void:
	clear_roots(); set_meta("boss_rewarded",true); world.exp16.defeated(self); super.die()
func _exit_tree() -> void:
	if is_instance_valid(world) and is_inside_tree(): clear_roots()
	super._exit_tree()
