extends Node3D
var world: Node3D
var xp: int = 0
var scrap: int = 0
var power: String = ""
var model: Node3D
var clock: float = 0
var collected: bool = false

func _ready() -> void:
	add_to_group("pickups")
	model = VisualFactory.box(self, Vector3(.32, .32, .32) if power.is_empty() else Vector3(.55, .55, .55), Vector3(0, .4, 0), Color("c4e887") if power.is_empty() else Catalog.POWER_COLORS[power], true)
	clock = randf() * TAU
	if not power.is_empty():
		var tag := VisualFactory.health_label(self, 1.2)
		tag.font_size = 22
		tag.text = Catalog.POWER_NAMES[power]

func _physics_process(delta: float) -> void:
	if collected or world.phase == "ended":
		return
	clock += delta * 3
	model.position.y = .45 + sin(clock) * .12
	model.rotation.y += delta * 1.8
	var distance := global_position.distance_to(world.player.global_position)
	if distance < 4.0:
		global_position = global_position.move_toward(world.player.global_position, delta * 10)
	if distance < .85:
		collect()

func collect() -> void:
	if collected:
		return
	collected = true
	world.resources.add_loot(xp, scrap)
	if not power.is_empty():
		world.player.grant_power(power)
	queue_free()
