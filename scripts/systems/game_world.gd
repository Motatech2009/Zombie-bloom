extends Node3D
const PLAYER_SCENE = preload("res://scenes/player/Player.tscn")
const CORE_SCENE = preload("res://scenes/buildings/BaseCore.tscn")
const HUD_SCENE = preload("res://scenes/ui/HUD.tscn")
const PICKUP_SCRIPT = preload("res://scripts/entities/pickup.gd")
var player: CharacterBody3D
var core: StaticBody3D
var arena := Arena.new()
var effects := Effects.new()
var resources := ResourceManager.new()
var upgrades := UpgradeManager.new()
var waves := WaveManager.new()
var builder := BuildManager.new()
var audio := GameAudio.new()
var camera := Camera3D.new()
var hud: CanvasLayer
var sunlight: DirectionalLight3D
var phase: String = "prep"
var kills: int = 0
var elapsed: float = 0
var won: bool = false
var ending_reason: String = ""
var notice: String = "B constrói defesas · ESPAÇO inicia a primeira horda."
var notice_left: float = 9
var camera_offset := Vector3(20, 26, 20)

func _ready() -> void:
	Controls.setup()
	GameSettings.load_settings()
	sunlight = VisualFactory.lighting(self)
	sunlight.shadow_enabled = GameSettings.shadows
	add_child(arena)
	add_child(effects)
	add_child(resources)
	add_child(audio)
	upgrades.world = self
	add_child(upgrades)
	waves.world = self
	add_child(waves)
	core = CORE_SCENE.instantiate()
	core.world = self
	add_child(core)
	player = PLAYER_SCENE.instantiate()
	player.world = self
	player.position = Vector3(3.8, 0, 4)
	add_child(player)
	builder.world = self
	add_child(builder)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32
	camera.far = 150
	camera.position = player.position + camera_offset
	camera.look_at(player.position)
	camera.current = true
	hud = HUD_SCENE.instantiate()
	hud.world = self
	add_child(hud)
	resources.level_earned.connect(func(): hud.request_upgrade())
	# Small finite salvage caches encourage moving beyond the core.
	for pos in [Vector3(7, 0, -4), Vector3(-7, 0, 4), Vector3(-5, 0, -7), Vector3(7, 0, 7)]:
		spawn_pickup(pos, 0, 15)

func _process(delta: float) -> void:
	if phase == "ended":
		return
	elapsed += delta
	notice_left = maxf(0, notice_left - delta)
	var target := player.global_position * .82
	camera.global_position = camera.global_position.lerp(target + camera_offset, 1.0 - exp(-delta * 5))
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if phase == "ended":
		return
	if event.is_action_pressed("build"):
		if phase == "prep":
			builder.set_active(not builder.active)
		else:
			notify("Construa durante a preparação entre hordas.")
	if event.is_action_pressed("start_wave"):
		waves.start()
	if event.is_action_pressed("interact"):
		repair_nearby()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and builder.active:
			var cursor := mouse_ground(0)
			builder.location = Vector3(snappedf(cursor.x, 1), 0, snappedf(cursor.z, 1))
			builder.place()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			builder.set_active(false)

func mouse_ground(height: float) -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var point = Plane(Vector3.UP, height).intersects_ray(origin, direction)
	return point if point != null else player.global_position + Vector3.FORWARD

func repair_nearby() -> void:
	if phase != "prep":
		notify("Repare as estruturas entre as hordas.")
		return
	var best: Node3D = null
	var distance := 4.5
	for building in get_tree().get_nodes_in_group("buildings"):
		var d := player.global_position.distance_to(building.global_position)
		if d < distance and building.health.current < building.health.maximum:
			best = building
			distance = d
	if best != null:
		best.repair()
	else:
		notify("Aproxime-se de uma estrutura danificada e pressione E.")

func enemy_defeated(enemy: Node3D) -> void:
	kills += 1
	spawn_pickup(enemy.global_position, int(enemy.spec.values.xp), int(enemy.spec.values.scrap))
	if randf() < .22:
		spawn_pickup(enemy.global_position + Vector3(.5, 0, .4), 0, 0, ["speed", "rapid", "shield"].pick_random())

func spawn_pickup(pos: Vector3, experience: int, metal: int, power: String = "") -> Node3D:
	var pickup := Node3D.new()
	pickup.set_script(PICKUP_SCRIPT)
	pickup.world = self
	pickup.position = pos
	pickup.xp = experience
	pickup.scrap = metal
	pickup.power = power
	add_child(pickup)
	return pickup

func notify(message: String) -> void:
	notice = message
	notice_left = 6

func finish(victory: bool, reason: String) -> void:
	if phase == "ended":
		return
	phase = "ended"
	won = victory
	ending_reason = reason
	waves.running = false
	builder.set_active(false)
	# Clear pending choices; a terminal state must never reopen the upgrade menu.
	resources.pending = 0
	upgrades.offers.clear()
	hud.show_result()
