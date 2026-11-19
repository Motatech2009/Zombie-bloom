extends SceneTree

var checks := 0
var failures := 0
var w: Node3D
var player: Node3D
const ORIGIN := Vector3(22,0,18)

class SoundProbe extends GameAudio:
	var emitted: Array[int] = []

	func play_boss(cue: int, _point: Vector3, _listener: Vector3) -> void:
		emitted.append(cue)

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func boss(stage: int, at := ORIGIN) -> Node3D:
	w.restoring_boss_stage = stage
	var enemy: Node3D = w.make_enemy(20 if stage == 8 else 8, at, false, -1)
	enemy.set_physics_process(false)
	w.restoring_boss_stage = 0
	return enemy

func reset_player(at: Vector3) -> void:
	player.position = at
	player.health.setup(500)
	player.invulnerable = 0.0
	player.rooted_left18 = 0.0
	player.shield = 0.0
	player.stop_roll()

func state_matches(packet: Dictionary, kind: String) -> bool:
	return packet.hazards.any(func(row): return row.get("fx18") == kind)

func run() -> void:
	MobilePlatform.force_touch = "--mobile" in OS.get_cmdline_user_args()
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	w = load("res://scenes/survival/SurvivalWorld.tscn").instantiate()
	w.checkpoint_enabled = false
	root.add_child(w)
	current_scene = w
	preload("res://tests/legacy_sector_fixture16.gd").normal(w)
	w.set_process(false)
	w.waves.set_physics_process(false)
	player = w.player
	player.set_physics_process(false)
	var sound := SoundProbe.new()
	w.audio = sound
	w.add_child(sound)

	reset_player(Vector3(0,0,5))
	var mauler := boss(1,Vector3(0,0,3))
	mauler.boss18.begin("quake",player)
	var packet: Dictionary = w.net_state(1)
	var core_hp: float = w.core.health.current
	var marker: Node3D = mauler.boss18.warnings[0]
	var same := BossFx18.spawn(w, "area", Vector3(0,0,8), Vector3.FORWARD, 5.1, 0.0, 1.0)
	check(marker.get_child_count() == 1 and same.get_child_count() == 1
		and marker.get_child(0).mesh == same.get_child(0).mesh
		and marker.get_child(0).material_override == same.get_child(0).material_override,
		"warning effects share a prebuilt mesh and material even at different sizes")
	same.queue_free()
	check(state_matches(packet,"area") and packet.enemies[0].attack18 == "quake", "quake warning and pose state replicate")
	for i in range(3):
		player.invulnerable = 0.0
		mauler.boss18.tick(1.13 if i==0 else .68)
	check(is_equal_approx(player.health.current,500-39*w.v15.day.damage_factor()), "all three separate slams damage the player")
	check(is_equal_approx(w.core.health.current,core_hp-9*w.v15.day.damage_factor()), "three slams do reduced damage to the core")
	check(sound.emitted.count(BossSoundBank.Cue.QUAKE)==3, "Quake plays once per impact")
	mauler.queue_free()

	reset_player(ORIGIN+Vector3.FORWARD*9)
	var mortar := boss(2)
	mortar.boss18.begin("volley",player)
	check(mortar.boss18.spots.size()==5 and mortar.boss18.spots.all(func(p): return p.distance_to(ORIGIN)<=15.01), "volley marks five impacts within range")
	mortar.boss18.tick(1.13)
	var shots := get_nodes_in_group("campaign_projectiles")
	check(shots.size()==5,"volley launches five actual projectiles")
	check(shots.all(func(shot): return not shot.show_landing and shot.get_child_count() == 1),
		"volley uses the five existing landing markers without generating duplicate geometry")
	for shot in get_nodes_in_group("campaign_projectiles"): shot.queue_free()
	mortar.boss18.finish()
	mortar.boss18.cooldowns.volley = 30.0
	reset_player(ORIGIN+Vector3.FORWARD*3)
	mortar.boss18.tick(5.9)
	check(mortar.boss18.attack.is_empty(),"mortar slap waits for six uninterrupted seconds")
	player.position += Vector3.FORWARD*5
	mortar.boss18.tick(.15)
	player.position = ORIGIN+Vector3.FORWARD*3
	mortar.boss18.tick(.3)
	check(mortar.boss18.attack.is_empty(),"leaving the range resets the slap")
	mortar.boss18.tick(5.75)
	check(mortar.boss18.attack=="slap","mortar slaps after staying close")
	mortar.queue_free()

	reset_player(ORIGIN+Vector3.FORWARD*4)
	var mother := boss(3)
	mother.boss18.begin("scratches",player)
	mother.boss18.tick(.67)
	player.invulnerable = 0.0
	mother.boss18.tick(.45)
	check(is_equal_approx(player.health.current,500-26*w.v15.day.damage_factor()),"the two claws can hit independently")
	mother.boss18.begin("scream",player)
	player.invulnerable = 0.0
	mother.boss18.tick(1.01)
	check(player.health.current<480 and player.position.z<ORIGIN.z-6,"scream deals light damage and pushes outward")
	mother.queue_free()

	reset_player(ORIGIN+Vector3.FORWARD*10)
	var flyer := boss(4)
	flyer.boss18.begin("gust",player)
	player.position.x += 2.2
	flyer.boss18.tick(1.15)
	check(player.health.current==500,"wind leaves players outside the lane unharmed")
	reset_player(ORIGIN+Vector3.FORWARD*10)
	flyer.boss18.begin("gust",player)
	flyer.boss18.tick(1.15)
	check(player.health.current<500 and player.position.z<ORIGIN.z-12,"wind damages and pushes inside the lane")
	flyer.queue_free()

	reset_player(ORIGIN+Vector3.FORWARD*8)
	var hound := boss(5)
	var ally: Node3D = w.make_enemy(1,ORIGIN+Vector3.RIGHT*3,false,-1)
	var dog: Node3D = w.make_enemy(6,ORIGIN+Vector3.RIGHT*4,false,-1)
	var bird: Node3D = w.make_enemy(7,ORIGIN+Vector3.RIGHT*5,false,-1)
	for infected in [ally,dog,bird]: infected.set_physics_process(false)
	hound.boss18.begin("howl",player)
	hound.boss18.tick(1.23)
	for infected in [ally,dog,bird]:
		check(infected.hunt_target18==player and infected.movement_boost()==1.15, "howl redirects and boosts "+infected.spec.id)
		infected.tick_hunt(7.01)
		check(infected.movement_boost()==1.0, "howl speed expires")
		infected.queue_free()
	hound.queue_free()

	reset_player(ORIGIN+Vector3.FORWARD*10)
	var potter := boss(6)
	potter.boss18.begin("block",player)
	var square: Vector3 = player.position
	player.position += Vector3(2.4,0,2.4)
	potter.boss18.tick(1.11)
	check(player.health.current<500,"the square hits the corner of the telegraphed area")
	var blocks := get_nodes_in_group("boss_fx18").filter(func(effect): return effect.data.fx18 == "mold")
	check(blocks.size()==1 and blocks[0].global_position.is_equal_approx(square) and blocks[0].data.s==2.75, "the only block rises from the exact 5.5 m warning")
	check(get_nodes_in_group("clay_temp_walls").is_empty() and blocks[0].find_children("*","CollisionObject3D").is_empty(),"the strike leaves no solid wall behind")
	var block: Node3D = blocks[0]
	block._process(.32)
	var raised := BossFx18.mold_height(0, block.elapsed/block.lifetime)
	block._process(.35)
	check(raised > .9 and BossFx18.mold_height(0, block.elapsed/block.lifetime) < raised*.35,
		"the block descends again during the same effect")
	packet = w.net_state(1)
	var row: Dictionary = packet.hazards.filter(func(state): return state.get("fx18") == "mold")[0]
	var replica := BossFx18.from_state(w,row)
	w.add_child(replica)
	check(is_equal_approx(replica.elapsed, block.elapsed) and replica.lifetime == block.lifetime,
		"co-op replicates the remaining visible lifetime instead of starting a new solid wall")
	replica.queue_free()
	block._process(.06)
	check(block.is_queued_for_deletion() and not state_matches(w.net_state(1),"mold"),
		"the block despawns before a second passes and leaves no network hazard")
	reset_player(ORIGIN+Vector3.FORWARD*11)
	potter.boss18.begin("clay",player)
	potter.boss18.tick(.93)
	check(player.rooted_left18==0.0,"the clay has flight time before reaching a distant player")
	for i in range(31): potter.boss18.tick(.016)
	check(is_equal_approx(player.rooted_left18,2.3),"thin clay bolt immobilizes the player once")
	potter.boss18.finish()
	reset_player(ORIGIN+Vector3.FORWARD*3)
	potter.boss18.cooldowns = {"block":30.0,"clay":30.0,"slap":0.0}
	potter.boss18.tick(7.99)
	check(potter.boss18.attack.is_empty(),"potter needs eight seconds in range")
	potter.boss18.tick(.02)
	check(potter.boss18.attack=="slap","potter has a close-range slap")
	potter.queue_free()

	reset_player(ORIGIN+Vector3.FORWARD*9)
	var hive := boss(7)
	hive.boss18.begin("brood",player)
	hive.boss18.tick(1.26)
	var batch := get_nodes_in_group("enemies").filter(func(enemy): return enemy.temporary_left18>0)
	check(batch.size()==8, "hive throws off eight temporary parasites")
	for parasite in batch:
		parasite.set_physics_process(false)
		check(parasite.spec.id=="parasite" and parasite.target==player and parasite.movement_boost()==1.0,"parasite pursues the survivor with its ordinary speed")
		check(parasite.tick_hunt(5.99) and not parasite.tick_hunt(.02) and parasite.is_queued_for_deletion(),"parasite despawns after six seconds")
	hive.queue_free()

	reset_player(ORIGIN+Vector3.FORWARD*5)
	var titan := boss(8)
	titan.boss18.begin("slam",player)
	titan.boss18.tick(1.34)
	check(titan.exposed>0 and player.health.current<500,"titan slam hits and exposes its heart")
	reset_player(ORIGIN+Vector3.FORWARD*9)
	titan.boss18.begin("stakes",player)
	check(titan.boss18.spots.size()==3,"titan telegraphs three stake eruptions")
	titan.boss18.tick(1.29)
	check(player.health.current<500 and player.slow_left==2.0,"wooden stakes deal damage and slow")
	reset_player(ORIGIN+Vector3.FORWARD*9)
	titan.boss18.begin("vines",player)
	titan.boss18.tick(1.44)
	var at: Vector3 = player.position
	check(player.rooted_left18==2.3 and not player.start_roll(Vector3.FORWARD),"vines stop movement and rolling for the same 2.3 seconds as the clay bolt")
	packet = w.net_state(1)
	var vines: Array = packet.hazards.filter(func(row): return row.get("fx18") == "vines")
	check(packet.players[0].root18==2.3 and vines.size()==1 and vines[0].life==2.3,
		"the root visualization, status and cooperative snapshot have the same duration")
	player.simulate_motion({"move":Vector2.ONE},2.29)
	check(BossCombat18.flat(player.position).is_equal_approx(BossCombat18.flat(at)) and player.rooted_left18>0,"roots lock horizontal motion for their full duration")
	player.simulate_motion({"move":Vector2.ONE},.02)
	check(player.rooted_left18==0.0 and player.start_roll(Vector3.FORWARD),"normal movement returns after the roots expire")
	var signature_cues := [
		BossSoundBank.Cue.QUAKE, BossSoundBank.Cue.ACID_VOLLEY, BossSoundBank.Cue.SCREAM,
		BossSoundBank.Cue.GUST, BossSoundBank.Cue.HOWL, BossSoundBank.Cue.MOLD,
		BossSoundBank.Cue.BROOD, BossSoundBank.Cue.VINES,
	]
	check(signature_cues.all(func(cue): return sound.emitted.has(cue)),
		"every boss signature attack emits its own cue through the world")
	check(sound.emitted.count(BossSoundBank.Cue.HOWL)==1,"the visual effect adds no duplicate howl")
	w.queue_free()
	await process_frame
	await process_frame
	print("BOSS COMBAT RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
