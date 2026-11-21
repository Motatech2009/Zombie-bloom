extends CharacterBody3D
var world: Node3D
var health := Health.new()
var weapons := WeaponSystem.new()
var rig: Node3D
var shield_ring: Node3D
var aim: Vector3 = Vector3.FORWARD
var speed_multiplier: float = 1.0
var powers: Dictionary = {}
var shield: float = 0.0
var invulnerable: float = 0.0
var clock: float = 0.0
var recoil: float = 0.0

func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	collision_layer = 2
	collision_mask = 1 | 8
	var shape := CapsuleShape3D.new()
	shape.radius = .36
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = .9
	add_child(collision)
	add_child(health)
	health.setup(100)
	health.died.connect(die)
	add_child(weapons)
	weapons.actor = self
	weapons.world = world
	weapons.fired.connect(func(): recoil = .25)
	rig = VisualFactory.human(self, Color("718b66"), true)
	shield_ring = VisualFactory.ring(self, .8, Vector3(0, .15, 0), Color("a4a1ff"))
	VisualFactory.ring(self, .52, Vector3(0, .05, 0), Color("bfe96e"))

func _physics_process(delta: float) -> void:
	if health.dead or world.phase == "ended":
		return
	clock += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	recoil = move_toward(recoil, 0, delta * 2)
	for id in powers.keys():
		powers[id] = maxf(0.0, float(powers[id]) - delta)
		if powers[id] == 0:
			powers.erase(id)
			if id == "shield":
				shield = 0
	shield_ring.visible = shield > 0 and power_left("shield") > 0
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Align movement with the fixed camera's screen axes.
	var forward := Vector3(-1, 0, -1).normalized()
	var right := Vector3(1, 0, -1).normalized()
	var direction := right * input.x + forward * -input.y
	var sprint := 1.3 if Input.is_action_pressed("sprint") else 1.0
	var boost := 1.45 if power_left("speed") > 0 else 1.0
	var target_velocity := direction * 6.3 * speed_multiplier * sprint * boost
	velocity.x = move_toward(velocity.x, target_velocity.x, delta * 35)
	velocity.z = move_toward(velocity.z, target_velocity.z, delta * 35)
	velocity.y = -1.0
	move_and_slide()
	var point: Vector3 = world.mouse_ground(1.15)
	var delta_aim := point - global_position
	delta_aim.y = 0
	if delta_aim.length_squared() > .1:
		aim = delta_aim.normalized()
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-aim.x, -aim.z), minf(1, delta * 24))
	VisualFactory.animate_human(rig, clock * sprint, input.length(), recoil, true)
	if weapons.reload_left > 0:
		rig.get_node("ArmL").rotation.z = sin(clock * 12) * .4
	else:
		rig.get_node("ArmL").rotation.z = 0
	if not world.builder.active and Input.is_action_pressed("fire"):
		weapons.shoot(aim)
	if Input.is_action_just_pressed("reload"):
		weapons.reload()
	for i in range(3):
		if not world.builder.active and Input.is_action_just_pressed("slot_" + str(i + 1)):
			weapons.equip(i)
	# A subtle blink communicates the invulnerability window without swapping shared materials.
	rig.visible = invulnerable <= 0 or sin(clock * 60) > -.3

func take_damage(amount: float) -> void:
	if health.dead or invulnerable > 0 or world.phase == "ended":
		return
	invulnerable = .35
	var absorbed := minf(shield, amount)
	shield -= absorbed
	health.take_damage(amount - absorbed)
	world.effects.burst(global_position + Vector3.UP, Color("ff8567"), 3)

func grant_power(id: String) -> void:
	# Refresh duration; never stack intensity or create permanent multipliers.
	powers[id] = 10.0
	if id == "shield":
		shield = 45.0
	world.notify(Catalog.POWER_NAMES[id] + " · 10 SEGUNDOS")

func power_left(id: String) -> float:
	return float(powers.get(id, 0.0))

func die() -> void:
	var tween := create_tween()
	tween.tween_property(rig, "rotation:z", PI * .5, .3)
	world.finish(false, "O sobrevivente caiu.")
