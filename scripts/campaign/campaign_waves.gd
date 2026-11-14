extends WaveManager
const ACTIVE_LIMIT := 36

func start() -> bool:
	if running or world.phase!="prep" or world.area_index!=-1 or (world.game_mode=="campaign" and wave>=CampaignData.WAVES.size()) or not world.hud.mode.is_empty(): return false
	wave += 1
	to_spawn = CampaignData.wave_count(wave)
	spawned = 0
	timer = .8
	running = true
	world.phase = "combat"
	world.builder.set_active(false)
	wave_started.emit(wave)
	world.notify("HORDA %02d · %d infectados · %s" % [wave,to_spawn,"Colosso Alfa detectado" if wave%5==0 else "Defenda todos os acessos"])
	return true

func _physics_process(delta: float) -> void:
	if not running or world.phase!="combat": return
	timer -= delta
	if to_spawn>0 and timer<=0 and alive()<ACTIVE_LIMIT:
		spawn_enemy()
		timer = maxf(.12,.65-wave*.025)
	if to_spawn==0 and alive()==0: complete()

func enemy_type(index: int) -> int:
	if wave%5==0 and index==0: return 8
	if wave>=6 and index%13==0: return 4
	if wave>=4 and index%9==0: return 5
	if wave>=3 and index%8==0: return 7
	if wave>=2 and index%5==0: return 6
	if wave>=4 and index%6==0: return 3
	if wave>=3 and index%7==0: return 2
	if index%4==0: return 1
	return 0

func spawn_enemy() -> Node3D:
	var side := randi_range(0,3)
	var offset := randf_range(-44,44)
	var pos := Vector3(offset,0,-51 if side==0 else 51) if side<2 else Vector3(-51 if side==2 else 51,0,offset)
	var enemy: Node3D = world.make_enemy(enemy_type(spawned),pos,false,spawned)
	spawned += 1
	to_spawn -= 1
	return enemy

func complete() -> void:
	if not running: return
	running = false
	world.clear_hazards()
	world.resources.add_loot(0,30+mini(wave,40)*7)
	world.stock.wood += 8+mini(wave,20)/4
	world.stock.parts += 2+mini(wave,30)/6
	world.player.health.heal(8)
	wave_completed.emit(wave)
	if world.game_mode=="campaign" and wave>=CampaignData.WAVES.size():
		world.finish(true,"Vinte hordas vencidas. O Refúgio resistiu ao cerco.")
	else:
		world.phase = "prep"
		world.notify("HORDA VENCIDA · Reforce a base. A próxima traz mais pressão.")
		world.save_checkpoint(false)
