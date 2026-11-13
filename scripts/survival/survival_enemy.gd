extends "res://scripts/campaign/campaign_enemy.gd"
var enemy_kind: int = 0
var net_id: int = 0
var proxy: bool = false
var ability_left: float = 5
var windup: float = 0
var cast_point := Vector3.ZERO
var warning: Node3D
var summon_casts: int = 0
var enraged: bool = false
var shield_left: float = 0
var rush_left: float = 0
var rush_direction := Vector3.ZERO
var rush_hits: Dictionary = {}
var special_clock: float = 1

func _ready() -> void:
	super._ready()
	label.hide()
	if spec.id not in ["hound","flyer"]:
		var old_rig: Node3D = rig
		var scale_before: Vector3 = rig.scale
		rig = load("res://assets/models/infected_"+str(enemy_kind if not is_boss else 3 if spec.id=="armored" else 5 if spec.id=="spitter" else 8)+".tscn").instantiate()
		rig.scale = scale_before
		add_child(rig)
		remove_child(old_rig); old_rig.queue_free()
	else:
		for x in [-.2,.2]: ModelFactory.part(rig,Vector3(.12,.15,.7),Vector3(x,.85,0),Color("aab9a0"))
	var bar := Node3D.new()
	bar.set_script(load("res://scripts/survival/enemy_bar.gd"))
	bar.actor = self
	add_child(bar)
	if is_boss:
		health.setup(health.maximum*1.6*(1+.3*(world.party_count()-1)))
		VisualFactory.ring(self,.9,Vector3(0,.08,0),Color("df7a5b"))
	else: health.setup(health.maximum*(1+.04*maxi(0,world.waves.wave-1)))
	ability_left = 5+fmod(float(net_id),3)

func _physics_process(delta: float) -> void:
	if proxy or health.dead or world.phase=="ended": return
	shield_left = maxf(0,shield_left-delta)
	if rush_left>0:
		rush_left -= delta
		velocity = rush_direction*16
		velocity.y = -1
		move_and_slide()
		rig.rotation.y = atan2(-rush_direction.x,-rush_direction.z)
		var blocked := false
		for i in range(get_slide_collision_count()):
			if absf(get_slide_collision(i).get_normal().y)<.5: blocked = true
			var body = get_slide_collision(i).get_collider()
			if is_instance_valid(body) and body.has_method("take_damage") and not body.is_in_group("enemies") and not rush_hits.has(body.get_instance_id()):
				rush_hits[body.get_instance_id()] = true
				body.take_damage(float(spec.values.damage)*1.5)
		if blocked: rush_left = 0
		return
	if is_boss and not enraged and health.current<health.maximum*.4:
		enraged = true
		spec.values.speed *= 1.25
		spec.values.damage *= 1.3
		world.notify("FÚRIA · "+spec.title+" acelerou e aumentou o dano.")
	if windup>0:
		windup -= delta
		velocity = Vector3.ZERO
		if windup<=0:
			if is_instance_valid(warning): warning.queue_free()
			if enemy_kind==12:
				rush_direction = (cast_point-global_position)*Vector3(1,0,1)
				rush_direction = rush_direction.normalized()
				rush_left = .85
				rush_hits.clear()
			elif enemy_kind==13: world.frost_blast(cast_point)
			elif enemy_kind==14: world.emp_blast(cast_point)
			elif enemy_kind==10:
				for i in range(2): world.spawn_minion(self,6,i)
			elif is_boss:
				world.hostile_blast(cast_point,6,28+world.waves.wave*2)
				shield_left = 2
				if summon_casts<3:
					summon_casts += 1
					world.spawn_minion(self,6,0)
			return
		return
	ability_left -= delta
	if (is_boss or enemy_kind in [10,12,13,14]) and ability_left<=0:
		choose_target()
		if enemy_kind in [12,13] and target.global_position.distance_to(global_position)>13:
			super._physics_process(delta)
			return
		cast_point = global_position if enemy_kind==14 else target.global_position
		windup = 1.1
		ability_left = 8 if is_boss else 9 if enemy_kind in [12,13,14] else 12
		warning = VisualFactory.ring(world.effects,warning_radius(),cast_point+Vector3(0,.12,0),warning_color())
		return
	if enemy_kind==11:
		special_clock -= delta
		if special_clock<=0:
			special_clock = 3
			for ally in get_tree().get_nodes_in_group("enemies"):
				if ally!=self and ally.global_position.distance_to(global_position)<7: ally.health.heal(12+world.waves.wave)
	super._physics_process(delta)
	label.hide()

func choose_target() -> void:
	super.choose_target()
	if not field_enemy and world.area_index!=-1: return
	var closest := 18.0 if spec.id in ["hound","runner"] else 11.0
	for survivor in world.avatars.values():
		if survivor.health.dead: continue
		var distance := global_position.distance_to(survivor.global_position)
		if distance<closest: target = survivor; closest = distance
	if field_enemy and (not is_instance_valid(target) or target.health.dead):
		for survivor in world.avatars.values():
			if not survivor.health.dead: target = survivor; break

func take_damage(amount: float) -> void:
	super.take_damage(amount*.35 if shield_left>0 else amount)

func die() -> void:
	if is_instance_valid(warning): warning.queue_free()
	if enemy_kind==9: world.hostile_blast(global_position,3.2,22+world.waves.wave)
	super.die()

func _exit_tree() -> void:
	if is_instance_valid(warning): warning.queue_free()

func warning_radius() -> float:
	return 6.0 if is_boss else 8.0 if enemy_kind==14 else 4.5 if enemy_kind==13 else 1.7 if enemy_kind==12 else 2.5

func warning_color() -> Color:
	return Color("85d9f2") if enemy_kind==13 else Color("9aabf0") if enemy_kind==14 else Color("e67f5f")
