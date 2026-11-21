extends SceneTree

const STEP := 1.0 / 60.0
const ORIGIN := Vector3(0, 0, 180)
const FORWARD_INPUT := Vector2(.70710678, -.70710678)
var checks := 0
var failures := 0
var world: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func enemy(kind: int, stage: int = 1) -> CharacterBody3D:
	world.restoring_boss_stage = stage
	var body: CharacterBody3D = world.make_enemy(kind, ORIGIN, false, -1)
	body.set_physics_process(false)
	return body

func rest_at(point: Vector3) -> void:
	player.position = point
	player.stop_roll()
	player.velocity = Vector3.ZERO
	player.roll_cooldown = 0

func radius(body: CharacterBody3D) -> float:
	return (body.get_children().filter(func(node): return node is CollisionShape3D)[0].shape as CapsuleShape3D).radius

func move_into(body: CharacterBody3D, frames: int, predict: bool = false, let_boss_recover: bool = true) -> bool:
	var touched := false
	for i in range(frames):
		await physics_frame
		var input := {"move": FORWARD_INPUT}
		if predict:
			world.prediction.simulate(input)
		else:
			player.simulate_motion(input, STEP)
		for j in range(player.get_slide_collision_count()):
			if player.get_slide_collision(j).get_collider() == body: touched = true
		# A ground boss normally calls this after the player moves. This isolates
		# penetration recovery so AI pursuit doesn't hide positional drift.
		if let_boss_recover:
			body.velocity = Vector3.DOWN
			body.move_and_slide()
	return touched

func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	world = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	world.checkpoint_enabled = false
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.waves.set_physics_process(false)
	player = world.player
	player.set_physics_process(false)
	var test_floor := StaticBody3D.new()
	test_floor.collision_layer = 1
	test_floor.position = ORIGIN - Vector3.UP*.5
	VisualFactory.collider(test_floor, Vector3(20,1,20), Vector3.ZERO)
	world.add_child(test_floor)

	for stage in [1, 2, 3, 5, 6, 7, 8]:
		rest_at(ORIGIN + Vector3.BACK * 5.0)
		await physics_frame
		await physics_frame
		var boss := enemy(20 if stage == 8 else 8, stage)
		var separation := radius(boss) + radius(player)
		rest_at(ORIGIN + Vector3.BACK * (separation + 1.25))
		var state := await move_into(boss, 33)
		check(state and player.position.z >= ORIGIN.z + separation - .08, boss.spec.title + " blocks an approaching survivor")
		check(Vector2(boss.position.x, boss.position.z).distance_to(Vector2(ORIGIN.x, ORIGIN.z)) < .035,
			boss.spec.title + " stays in place while the survivor holds movement")
		boss.queue_free()
		await process_frame

	rest_at(ORIGIN + Vector3.BACK * 5.0)
	await physics_frame
	await physics_frame
	var mauler := enemy(8)
	var separation := radius(mauler) + radius(player)
	rest_at(ORIGIN + Vector3.BACK * (separation + 1.4))
	check(player.start_roll(Vector3.FORWARD), "roll can start in front of the boss")
	var rolled := await move_into(mauler, 26)
	check(rolled and player.position.z >= ORIGIN.z + separation - .08, "rolling cannot tunnel through a ground boss")

	var state: Dictionary = world.net_state(1)
	mauler.queue_free()
	await process_frame
	rest_at(ORIGIN + Vector3.BACK * 5.0)
	await physics_frame
	await physics_frame
	world.is_client = true
	world.last_scene_revision = state.rev
	world.apply_net_state(state, 1)
	var proxy: CharacterBody3D = world.client_enemies.values()[0]
	rest_at(ORIGIN + Vector3.BACK * (separation + 1.25))
	await move_into(proxy, 33, true, false)
	var gap := player.position.z - proxy.position.z
	check(absf(gap - separation) < .08, "co-op prediction stops at the same boss hitbox")
	proxy.queue_free()
	world.client_enemies.clear()
	world.is_client = false
	await process_frame

	for kind in [0, 8]:
		var passer := enemy(kind, 4)
		rest_at(ORIGIN + Vector3.BACK * 1.8)
		var collided := await move_into(passer, 37, false, false)
		check(not collided and player.position.z < ORIGIN.z - .25,
			"The survivor can still pass " + ("under the airborne Tempestade" if kind == 8 else "a regular infected"))
		passer.queue_free()
		await process_frame

	world.queue_free()
	await process_frame
	await process_frame
	print("BOSS COLLISION RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
