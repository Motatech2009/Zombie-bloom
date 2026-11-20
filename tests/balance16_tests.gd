extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)
func run() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w: Node3D = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	w.v15.day.clock = 0
	var damage := float(Catalog.WEAPONS[0].values.damage)
	for kind in [0,1]:
		var enemy: Node3D = w.make_enemy(kind,Vector3(12+kind*3,0,12),false,kind); enemy.set_physics_process(false)
		check(enemy.health.maximum>=70 if kind==0 else enemy.health.maximum>=48,"starter infected has increased base health")
		var shots := 4 if kind==0 else 3
		for i in range(shots-1): enemy.take_damage(damage)
		check(not enemy.health.dead,"infected survives all but final ordinary pistol hit")
		enemy.take_damage(damage); check(enemy.health.dead,"final ordinary pistol hit kills at intended threshold")
	check(CampaignData.wave_count(1)==23 and CampaignData.wave_count(5)==60 and CampaignData.wave_count(20)==300,"horde totals increase by 25 percent with rounding")
	check(CampaignData.wave_count(21)==320,"endless scaling continues past campaign")
	w.horde_left = 0; w.waves.start(); check(w.waves.to_spawn==23,"actual solo horde uses larger total")
	check(w.waves.ACTIVE_LIMIT==36,"simultaneous enemy limit remains bounded for mobile")
	w.queue_free(); await create_timer(.3).timeout
	print("BALANCE16 RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
