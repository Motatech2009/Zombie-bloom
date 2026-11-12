extends WaveManager

func start() -> bool:
	if running or world.phase != "prep" or world.area_index != -1 or wave >= CampaignData.WAVES.size() or not world.hud.mode.is_empty():
		return false
	wave += 1
	to_spawn = CampaignData.WAVES[wave-1]
	spawned = 0
	timer = .7
	running = true
	world.phase = "combat"
	world.builder.set_active(false)
	wave_started.emit(wave)
	world.notify("HORDA %02d · Defenda o Núcleo. %d infectados a caminho." % [wave,to_spawn])
	return true

func enemy_type(index: int) -> int:
	if wave >= 6 and index % 12 == 0: return 4
	if wave >= 4 and index % 6 == 0: return 3
	if wave >= 3 and index % 8 == 0: return 2
	if wave >= 2 and index % 4 == 0: return 1
	return 0

func spawn_enemy() -> Node3D:
	var side := randi_range(0,3)
	var offset := randf_range(-23,23)
	var pos := Vector3(offset,0,-27.5 if side == 0 else 27.5) if side < 2 else Vector3(-27.5 if side == 2 else 27.5,0,offset)
	var enemy: Node3D = world.make_enemy(enemy_type(spawned),pos,false,spawned)
	spawned += 1
	to_spawn -= 1
	return enemy

func complete() -> void:
	if not running: return
	running = false
	world.resources.add_loot(0,35 + wave * 10)
	world.stock.wood += 8
	world.stock.parts += 2
	world.player.health.heal(20)
	wave_completed.emit(wave)
	if wave >= CampaignData.WAVES.size():
		world.finish(true,"Oito hordas vencidas. O Núcleo e sua fortaleza resistiram.")
	else:
		world.phase = "prep"
		world.notify("HORDA VENCIDA · Reforce a base, compre equipamento e explore pelo mapa M.")
		world.save_checkpoint(false)
