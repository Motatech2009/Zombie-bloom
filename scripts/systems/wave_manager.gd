class_name WaveManager
extends Node
signal wave_started(number: int)
signal wave_completed(number: int)
var world: Node3D
var wave: int = 0
var to_spawn: int = 0
var spawned: int = 0
var timer: float = 0
var running: bool = false
const ENEMY_SCENES = [preload("res://scenes/enemies/ZombieBasic.tscn"), preload("res://scenes/enemies/ZombieRunner.tscn"), preload("res://scenes/enemies/ZombieBrute.tscn")]

func start() -> bool:
	if running or world.phase != "prep" or wave >= Catalog.WAVES.size():
		return false
	wave += 1
	to_spawn = Catalog.WAVES[wave - 1]
	spawned = 0
	timer = .25
	running = true
	world.phase = "combat"
	world.builder.set_active(false)
	wave_started.emit(wave)
	world.notify("HORDA %02d · Mantenha o núcleo vivo." % wave)
	world.audio.play_tone(180, .45, .15)
	return true

func _physics_process(delta: float) -> void:
	if not running or world.phase != "combat":
		return
	timer -= delta
	if to_spawn > 0 and timer <= 0 and alive() < 55:
		spawn_enemy()
		timer = maxf(.22, .85 - wave * .09)
	if to_spawn == 0 and alive() == 0:
		complete()

func enemy_type(index: int) -> int:
	if wave >= 5 and index % 8 == 0:
		return 2
	if wave >= 3 and index % 4 == 0:
		return 1
	return 0

func spawn_enemy() -> Node3D:
	var enemy: Node3D = ENEMY_SCENES[enemy_type(spawned)].instantiate()
	enemy.world = world
	var side := randi_range(0, 3)
	var offset := randf_range(-24, 24)
	enemy.position = Vector3(offset, 0, -27.5 if side == 0 else 27.5) if side < 2 else Vector3(-27.5 if side == 2 else 27.5, 0, offset)
	world.add_child(enemy)
	spawned += 1
	to_spawn -= 1
	return enemy

func alive() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func remaining() -> int:
	return to_spawn + alive()

func complete() -> void:
	if not running:
		return
	running = false
	world.resources.add_loot(0, 35 + wave * 10)
	world.player.health.heal(15)
	wave_completed.emit(wave)
	if wave == Catalog.WAVES.size():
		world.finish(true, "Você resistiu às cinco hordas.")
	else:
		world.phase = "prep"
		world.notify("HORDA CONCLUÍDA · +%d sucata · +15 vida\nRepare suas defesas. ESPAÇO inicia a próxima." % (35 + wave * 10))
