extends "res://scripts/entities/player.gd"
var tool: String = "axe"
var axe_model: Node3D
var death_tween: Tween
var hotbar_slot: int = 0
var roll_left: float = 0
var roll_recovery: float = 0
var roll_direction := Vector3.FORWARD

func _ready() -> void:
	weapons.free()
	weapons = BetaWeapons.new()
	super._ready()
	weapons.ammo = [0, 0, 0]
	axe_model = Node3D.new()
	rig.add_child(axe_model)
	axe_model.position = Vector3(.36, 1.05, -.48)
	VisualFactory.box(axe_model, Vector3(.09, .75, .09), Vector3.ZERO, Color("9d8352"))
	VisualFactory.box(axe_model, Vector3(.42, .24, .12), Vector3(.13, .29, 0), Color("b1bcb6"))

func _physics_process(delta: float) -> void:
	if health.dead or world.phase == "ended":
		return
	clock += delta
	invulnerable = maxf(0, invulnerable - delta)
	recoil = move_toward(recoil, 0, delta * 2)
	roll_recovery = maxf(0, roll_recovery - delta)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward := Vector3(-1, 0, -1).normalized()
	var right := Vector3(1, 0, -1).normalized()
	var direction := right * input.x + forward * -input.y
	var point: Vector3 = world.mouse_ground(global_position.y + 1.15)
	var delta_aim := point - global_position
	delta_aim.y = 0
	if delta_aim.length_squared() > .1:
		aim = delta_aim.normalized()
	if Input.is_action_just_pressed("roll"):
		world.extracting = false
		if is_instance_valid(world.focused): world.focused.progress = 0
		begin_roll(direction)
	var factor: float = world.inventory.move_factor()
	var sprint := 1.3 if Input.is_action_pressed("sprint") and world.inventory.agile() else 1.0
	if roll_left > 0:
		roll_left = maxf(0, roll_left - delta)
		velocity = roll_direction * (2.5 / .55)
		if roll_left == 0:
			roll_recovery = .5
	else:
		var target := direction * 6.3 * factor * sprint
		velocity.x = move_toward(velocity.x, target.x, delta * 35)
		velocity.z = move_toward(velocity.z, target.z, delta * 35)
	velocity.y = -2
	move_and_slide()
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-aim.x, -aim.z), minf(1, delta * 24))
	VisualFactory.animate_human(rig, clock * sprint, input.length(), recoil, true)
	rig.rotation.x = -sin((.55 - roll_left) / .55 * PI) * 1.2 if roll_left > 0 else 0
	axe_model.visible = tool == "axe" and world.inventory.count("axe") > 0
	rig.get_node("Gun").visible = tool != "axe" and world.inventory.count(tool) > 0
	axe_model.rotation.z = sin(clock * 10) * .4 if world.extracting else recoil * 3
	if roll_left <= 0 and not world.builder.active and not world.extracting:
		if Input.is_action_pressed("fire"):
			weapons.shoot(aim)
		if Input.is_action_just_pressed("reload"):
			weapons.reload()
		for i in range(6):
			if Input.is_action_just_pressed("beta_slot_%d" % (i + 1)):
				select_hotbar(i)
	rig.visible = invulnerable <= 0 or sin(clock * 60) > -.3

func begin_roll(direction: Vector3) -> bool:
	if roll_left > 0 or roll_recovery > 0 or not world.inventory.agile() or world.builder.active:
		return false
	roll_direction = direction.normalized() if direction.length_squared() > .01 else aim
	roll_left = .55
	# Deliberately does not modify invulnerable: rolling never grants immunity.
	world.make_noise(global_position, 5)
	return true

func select_hotbar(index: int) -> bool:
	if index < 0 or index >= 6:
		return false
	var reference: int = world.inventory.hotbar[index]
	if reference < 0 or reference >= world.inventory.slots.size() or world.inventory.slots[reference].is_empty():
		world.notify("Atalho vazio. Vincule um slot no inventário.")
		return false
	var id: String = world.inventory.slots[reference].id
	if id in ["axe", "pistol", "shotgun"]:
		var category := "tool" if id == "axe" else "primary" if world.inventory.equipment.primary < 0 or world.inventory.equipment.primary == reference else "secondary"
		world.inventory.equip_slot(reference, category)
		tool = id
		hotbar_slot = index
		weapons.reload_left = 0
		if id != "axe":
			weapons.equip(0 if id == "pistol" else 1)
		return true
	return world.use_item(reference)

func take_damage(amount: float) -> void:
	super.take_damage(amount * (.8 if world.inventory.armor else 1.0))

func die() -> void:
	death_tween = create_tween()
	death_tween.tween_property(rig, "rotation:z", PI * .5, .3)
	world.finish(false, "O sobrevivente caiu.")

func reset_life_pose() -> void:
	if death_tween != null and death_tween.is_valid():
		death_tween.kill()
	rig.rotation = Vector3.ZERO
	invulnerable = 0
