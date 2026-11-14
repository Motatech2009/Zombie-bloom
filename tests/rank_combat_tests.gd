extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
	else: print("PASS: "+message)
func run() -> void:
	check(RankProgress.tier(0)==0 and RankProgress.tier(99)==0,"no rank below 100 kills")
	for i in range(10):
		check(RankProgress.tier(RankProgress.THRESHOLDS[i])==i+1,"exact threshold promotes rank %d" % (i+1))
		check(RankProgress.tier(RankProgress.THRESHOLDS[i]-1)==i,"one fewer kill keeps previous rank")
	check(RankProgress.tier(100000)==10,"rank caps at ten")
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	var w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate(); w.checkpoint_enabled = false; root.add_child(w); current_scene = w
	w.set_process(false); w.waves.set_physics_process(false); w.player.set_physics_process(false)
	var player = w.player; player.invulnerable = 0; player.health.setup(500)
	player.position = Vector3(0,0,12)
	var charger = w.make_enemy(12,w.vendor_pos,false,0); charger.set_physics_process(false)
	await physics_frame; await physics_frame
	charger.position.y = -2; charger.last_ground = charger.global_position; charger.last_ground.y = 0; charger.stuck_left = 2
	var hp: float = charger.health.current; charger.recover_ground(.01)
	check(charger.position.y>=0 and charger.position.distance_to(w.vendor_pos)>=3.5,"charger embedded under vendor recovers to a clear ground position")
	check(charger.health.current==hp and charger.is_in_group("wave_enemies"),"recovery preserves enemy health and wave accounting")
	var enemy = w.make_enemy(16,Vector3(0,0,10),false,-1); enemy.set_physics_process(false)
	enemy.melee_target = player; enemy.melee_left = .1; enemy.attack_left = 2; enemy.target = player
	player.position = Vector3(0,0,20); hp = player.health.current; enemy.normal_step(.2)
	check(player.health.current==hp,"dodging away during melee windup avoids damage")
	var ranged = w.make_enemy(15,Vector3(2,0,20),false,-1); ranged.set_physics_process(false)
	check(ranged.ranged_only() and not enemy.ranged_only(),"new infected have distinct ranged-only and melee roles")
	w.restoring_boss_stage = 1; var boss = w.make_enemy(8,Vector3(0,0,-15),false,-1); w.restoring_boss_stage = 0; boss.set_physics_process(false)
	boss.ability_left = 0; boss._physics_process(.01)
	check(boss.windup==0,"melee boss cannot cast a slam on a distant player")
	w.restoring_boss_stage = 3; var mother = w.make_enemy(8,Vector3(6,0,20),false,-1); w.restoring_boss_stage = 0; mother.set_physics_process(false)
	mother.ability_left = 0; mother._physics_process(.01); mother._physics_process(1.2)
	check(mother.summon_casts==1 and mother.shield_left>0,"Matriarch summons allies and gains temporary armor")
	w.attach_peer(222,"2".repeat(32),"Guest"); w.avatars[222].set_physics_process(false)
	var before := int(w.records.totals.get("host",{}).get("kills",0)); var guest_before := int(w.records.totals.get("2".repeat(32),{}).get("kills",0))
	enemy.set_meta("killer_peer",0); w.enemy_defeated(enemy); w.enemy_defeated(enemy)
	check(w.records.totals.host.kills==before+1 and w.records.totals["2".repeat(32)].kills==guest_before+1,"defense kill credits each connected account once")
	player.position = w.vendor_pos+Vector3(0,0,2); w.resources.scrap = 1000; w.stock.parts = 50; player.bag.selected = 0; player.weapons.sync_hand()
	check(w.tune_weapon() and player.weapons.tuning[0]==1 and w.resources.scrap==920 and w.stock.parts==48,"workshop upgrades selected weapon and spends exact materials")
	var profile: Dictionary = w.actor_profile(player); check(w.valid_profile(profile),"tuned weapon profile is valid")
	player.weapons.tuning[0] = 0; w.restore_profile(player,profile)
	check(player.weapons.tuning[0]==1,"weapon tuning survives profile restore")
	w.resources.scrap = 0; check(not w.tune_weapon() and player.weapons.tuning[0]==1,"insufficient resources cannot upgrade weapon")
	profile.tuning[0] = 99; check(not w.valid_profile(profile),"invalid tuning tier rejected")
	w.queue_free(); await create_timer(.2).timeout
	print("RANK COMBAT RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
