extends "res://scripts/survival/survival_waves.gd"
func start() -> bool:
	if running or world.phase=="ended" or world.rescue16.phase not in ["defense","extraction"]: return false
	wave += 1; spawned = 0; to_spawn = ceili((6+wave*3)*1.25)*world.team_multiplier(); timer = .5; running = true; world.phase = "combat"
	world.rescue16.left = [60.0,75.0,90.0][mini(2,wave-1)]; wave_started.emit(wave)
	world.notify("RESGATE · HORDA %d/3 · %s" % [wave,world.rescue16.hint()]); return true
func _physics_process(delta: float) -> void:
	if not running or world.phase=="ended" or world.combat_paused(): return
	timer -= delta
	if to_spawn>0 and timer<=0 and alive()<ACTIVE_LIMIT:
		var coord: Vector2i = world.rescue16.goal_coord()
		if coord!=world.sector_coord and world.regions.enabled():
			if world.regions.has(coord): world.regions.run_in(coord,spawn_enemy)
		else: spawn_enemy()
		timer = .65
func spawn_enemy() -> Node3D:
	var angle := spawned*2.3999
	var point := Vector3(cos(angle)*24,0,sin(angle)*24)
	var enemy: Node3D = world.make_enemy(0 if spawned%3 else 1,point,world.rescue16.goal_coord()!=Vector2i.ZERO,-1)
	enemy.set_meta("rescue_wave16",true); enemy.add_to_group("wave_enemies")
	spawned += 1; to_spawn -= 1
	return enemy
func complete() -> void:
	if not running or world.rescue16.left>0 or to_spawn>0 or alive()>0: return
	super.complete(); world.rescue16.completed()
func rescale() -> void:
	if running: to_spawn = maxi(0,ceili((6+wave*3)*1.25)*world.team_multiplier()-spawned)
