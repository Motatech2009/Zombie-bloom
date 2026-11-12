class_name FrontierWaves
extends WaveManager

func start() -> bool:
	if running or world.phase != "prep" or world.inside or world.player.global_position.length() > 20:
		world.notify("Volte ao refúgio para iniciar uma horda.")
		return false
	wave += 1
	to_spawn = mini(50, 10 + wave * 3)
	spawned = 0
	timer = .25
	running = true
	world.phase = "combat"
	world.builder.set_active(false)
	wave_started.emit(wave)
	world.notify("HORDA %02d · Defenda o refúgio." % wave)
	return true

func alive() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("raid_enemies"):
		if not enemy.health.dead:
			count += 1
	return count

func spawn_enemy() -> Node3D:
	var enemy := super.spawn_enemy()
	enemy.add_to_group("raid_enemies")
	return enemy

func complete() -> void:
	if not running:
		return
	running = false
	world.phase = "prep"
	wave_completed.emit(wave)
	world.notify("HORDA CONTIDA · Explore, traga recursos e repare suas defesas.")
