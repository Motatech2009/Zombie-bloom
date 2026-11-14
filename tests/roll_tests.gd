extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func run() -> void:
	var world: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world); current_scene = world
	world.waves.set_physics_process(false)
	world.set_process(false)
	var actor: CharacterBody3D = world.player
	actor.position = Vector3(10,0,10)
	await create_timer(.1).timeout
	var key := InputEventKey.new(); key.physical_keycode = KEY_SPACE; key.pressed = true
	check(key.is_action_pressed("roll"),"Space binds to the roll action")
	check(actor.movement_direction(Vector2(1,0)).is_equal_approx(Vector3(1,0,-1).normalized()),"roll uses the same screen axes as walking")
	var wave_clock: float = world.horde_left
	key.echo = true; world._unhandled_input(key)
	check(actor.roll_cooldown==0,"keyboard auto-repeat does not trigger a roll")
	key.echo = false
	world.hud.show_inventory(); world._unhandled_input(key)
	check(actor.roll_cooldown==0,"inventory blocks Space from rolling")
	world.hud.close_modal(); world.builder.set_active(true); world._unhandled_input(key)
	check(actor.roll_cooldown==0,"construction preview blocks Space from rolling")
	world.builder.set_active(false)
	world.begin_gather(actor,world.core,"deposit",1.8)
	actor.weapons.reload_left = 2
	actor.aim = Vector3.RIGHT
	var expected_aim: Vector3 = world.local_input(actor).aim
	world._unhandled_input(key)
	check(actor.roll_left==.42 and actor.roll_cooldown==5,"a real Space press starts the roll and exactly five seconds of recharge")
	check(actor.roll_direction.is_equal_approx(expected_aim),"standing still rolls toward the aim")
	check(world.horde_left==wave_clock and not world.waves.running,"Space never starts or advances a timed horde")
	check(actor.gather_target==null and actor.weapons.reload_left==0,"rolling interrupts gathering and reloading")
	check(not world.perform_action(1,"roll",{"direction":Vector3.LEFT}) and actor.roll_direction.is_equal_approx(expected_aim),"repeated commands cannot redirect or restart the active roll")
	check(not actor.weapons.shoot(Vector3.FORWARD) and not actor.weapons.reload(),"weapons cannot fire or reload during a tumble")
	world.phase = "combat"
	check(not world.throw_for(actor) and not world.use_medkit(actor),"grenades and medkits are blocked while rolling")
	world.phase = "prep"
	var hp: float = actor.health.current
	actor.take_damage(10)
	check(actor.health.current==hp,"the initial 0.20 seconds provide a brief dodge window")
	var start: Vector3 = actor.position
	await create_timer(.12).timeout
	check(actor.position.distance_to(start)>.7 and actor.position.distance_to(start)<3,"roll traverses the world through physics rather than teleporting")
	check(actor.rig.rotation.x<-.1,"the character performs a visible forward somersault")
	await create_timer(.14).timeout
	actor.take_damage(10)
	check(actor.health.current==hp-10,"damage returns before the roll animation ends")
	await create_timer(.23).timeout
	check(actor.roll_left==0 and actor.rig.rotation.x==0 and actor.rig.position.length()<.1,"roll ends upright without a residual visual offset")
	check(actor.roll_cooldown>4.3 and actor.roll_cooldown<4.6,"cooldown counts down from the initial key press")
	check(not actor.start_roll(Vector3.LEFT),"roll remains locked after the animation until recharge finishes")
	actor.set_physics_process(false)
	actor._physics_process(actor.roll_cooldown-.01)
	check(not actor.start_roll(Vector3.RIGHT),"a roll is still rejected immediately before the five-second boundary")
	actor._physics_process(.02)
	check(not actor.start_roll(Vector3(INF,0,0)) and not actor.start_roll(Vector3(100,0,0)),"invalid or oversized network directions are rejected")
	check(actor.start_roll(Vector3.ZERO) and actor.roll_direction==actor.aim,"recharged roll accepts a second activation with safe aim fallback")
	var saved: Dictionary = world.actor_profile(actor)
	check(world.valid_profile(saved) and saved.roll_cd==5,"saved player profile preserves the roll recharge")
	actor.roll_cooldown = 0; world.restore_profile(actor,saved)
	check(actor.roll_cooldown==5 and actor.roll_left==0,"restoring preserves recharge and clears transient tumble animation")
	saved.erase("roll_cd")
	check(world.valid_profile(saved),"existing version-six saves remain compatible")
	world.restore_profile(actor,saved)
	saved.roll_cd = 50
	check(not world.valid_profile(saved),"profile validation rejects an out-of-range recharge")
	var wall := StaticBody3D.new(); wall.collision_layer = 8
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(1,3,6)
	shape.shape = box; shape.position.y = 1.5; wall.add_child(shape)
	wall.position = Vector3(12.5,0,10); world.add_child(wall)
	actor.position = Vector3(10,0,10); actor.invulnerable = 0
	await physics_frame; await physics_frame
	check(actor.start_roll(Vector3.RIGHT),"roll starts in front of a solid wall")
	actor.set_physics_process(true)
	await create_timer(.5).timeout
	check(actor.position.x<11.7 and actor.position.x>10.5,"solid walls block the complete roll without tunneling")
	actor.roll_cooldown = 0; actor.slow_left = 3
	wall.queue_free(); actor.position = Vector3(10,0,10)
	start = actor.position
	actor.start_roll(Vector3.RIGHT)
	await create_timer(.5).timeout
	check(actor.position.x-start.x<3.5 and actor.position.x-start.x>2,"cryo slow also reduces roll travel")
	actor.roll_cooldown = 0; actor.start_roll(Vector3.LEFT); actor.health.take_damage(10000)
	check(actor.roll_left==0 and actor.downed and not actor.start_roll(Vector3.RIGHT),"downing stops a roll and prevents rolling while down")
	actor.revive()
	check(actor.rig.rotation.x==0 and actor.rig.rotation.z==0,"revive restores an upright character")
	world.hud._process(0)
	check(world.hud.roll_text.text.contains("s") and world.hud.roll_bar.value<5,"HUD shows recharge text and a compact progress bar")
	world.phase = "ended"; actor.roll_cooldown = 0
	check(not actor.start_roll(Vector3.RIGHT),"ended sessions reject roll commands")
	world.queue_free(); await create_timer(.15).timeout
	print("ROLL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
