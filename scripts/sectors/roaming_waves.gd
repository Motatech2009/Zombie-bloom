extends "res://scripts/campaign/campaign_waves.gd"
var alarm_level: int = 0

func start() -> bool:
	# Manual Space/UI calls cannot bypass the countdown.
	if running or world.phase=="ended" or world.horde_left>0 or (world.game_mode=="campaign" and wave>=CampaignData.WAVES.size()): return false
	wave += 1
	to_spawn = CampaignData.wave_count(wave)
	spawned = 0
	timer = .8
	running = true
	world.phase = "combat"
	world.builder.set_active(false)
	if world.hud.mode=="routes": world.hud.close_modal()
	wave_started.emit(wave)
	world.notify("ALARME · HORDA %d + CHEFE NO REFÚGIO%s" % [wave," · VOLTE AO NÚCLEO!" if world.area_index!=-1 else ""])
	world.audio.play_tone(180,.5,.18)
	return true

func _physics_process(delta: float) -> void:
	if world.phase=="ended" or (world.has_method("combat_paused") and world.combat_paused()): return
	if not running:
		world.horde_left = maxf(0,world.horde_left-delta)
		var level := 3 if world.horde_left<=10 else 2 if world.horde_left<=30 else 1 if world.horde_left<=60 else 0
		if level>alarm_level:
			alarm_level = level
			world.notify("NÚCLEO · Horda em %d s. %s" % [ceili(world.horde_left),"Abra o mapa e retorne ao Núcleo (0,0)."])
			world.audio.play_tone(240,.25,.12)
		if world.horde_left<=0: start()
		return
	# Combat continues physically at the base even if the active exploration sector is elsewhere.
	timer -= delta
	if to_spawn>0 and timer<=0 and alive()<ACTIVE_LIMIT:
		spawn_enemy()
		timer = maxf(.12,.65-wave*.025)
	if to_spawn==0 and alive()==0: complete()

func enemy_type(index: int) -> int:
	if index==0: return 8
	return super.enemy_type(index)

func alive() -> int:
	return get_tree().get_nodes_in_group("wave_enemies").size()

func complete() -> void:
	if not running: return
	running = false
	world.clear_base_hazards()
	world.resources.add_loot(0,30+mini(wave,40)*7)
	world.stock.wood += 8+mini(wave,20)/4
	world.stock.parts += 2+mini(wave,30)/6
	if world.area_index==-1: world.player.health.heal(8)
	wave_completed.emit(wave)
	if world.game_mode=="campaign" and wave>=CampaignData.WAVES.size():
		world.finish(true,"Vinte cercos e seus chefes vencidos. O Núcleo resistiu.")
	else:
		world.phase = "prep" if world.area_index==-1 else "expedition"
		world.horde_left = world.preparation_seconds(wave+1)
		alarm_level = 0
		world.notify("REFÚGIO DEFENDIDO · Próximo cerco em %d s." % ceili(world.horde_left))
		if world.area_index==-1: world.save_checkpoint(false)
