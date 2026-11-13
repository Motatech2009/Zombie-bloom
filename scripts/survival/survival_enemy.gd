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
var special_clock: float = 1

func _ready() -> void:
	super._ready()
	label.hide()
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
			if enemy_kind==10:
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
	if (is_boss or enemy_kind==10) and ability_left<=0:
		choose_target()
		cast_point = target.global_position
		windup = 1.1
		ability_left = 8 if is_boss else 12
		warning = VisualFactory.ring(world.effects,6 if is_boss else 2.5,cast_point+Vector3(0,.12,0),Color("e67f5f"))
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
