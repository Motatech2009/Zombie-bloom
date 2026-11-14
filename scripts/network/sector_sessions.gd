class_name SectorSessions
extends RefCounted
var world: Node3D
var sessions: Dictionary = {}
var depth := 0
const FIELDS := ["sector_coord","area_index","descriptor","field_root","arena","caches","claimed","field_queue","field_dead","field_spawn_left","exit_labels","sector_deadline","field_defeated"]

func enabled() -> bool: return not world.is_client and world.connected_game()
func capture() -> Dictionary:
	var state := {}
	for key in FIELDS: state[key] = world.get(key)
	return state
func initialize() -> void:
	if sessions.is_empty():
		sessions[world.sector_coord] = capture()
		world.avatars[1].region_coord = world.sector_coord
func load_state(state: Dictionary) -> void:
	for key in FIELDS: world.set(key,state[key])
	if world.phase!="ended": world.phase = "combat" if world.waves.running else "prep" if world.area_index==-1 else "expedition"
func has(coord: Vector2i) -> bool:
	return coord==world.sector_coord or sessions.has(coord)
func run_in(coord: Vector2i,callback: Callable) -> Variant:
	if not enabled() or coord==world.sector_coord: return callback.call()
	initialize()
	if not sessions.has(coord): return null
	var saved := capture(); var saved_player: Node3D = world.player
	sessions[world.sector_coord] = saved
	load_state(sessions[coord]); depth += 1
	var result = callback.call()
	sessions[world.sector_coord] = capture(); depth -= 1
	load_state(saved); world.player = saved_player
	return result
func root_at(coord: Vector2i) -> Node3D:
	if coord==Vector2i.ZERO: return world.base_root
	if coord==world.sector_coord: return world.field_root
	return sessions.get(coord,{}).get("field_root")
func tick(delta: float) -> void:
	if not enabled(): return
	initialize(); sessions[world.sector_coord] = capture()
	for coord in sessions.keys():
		if coord!=Vector2i.ZERO and not world.avatars.values().any(func(a): return a.region_coord==coord):
			run_in(coord,world.remember_sector)
			var old: Node3D = root_at(coord)
			world.clear_region_hazards(SectorGenerator.key(coord))
			if is_instance_valid(old): world.remove_child(old); old.queue_free()
			sessions.erase(coord); continue
		if coord!=world.sector_coord and coord!=Vector2i.ZERO: run_in(coord,func(): world.tick_exploration(delta))
func travel(actor: Node3D,direction: int) -> bool:
	if direction<0 or direction>3 or actor.health.dead or actor.region_travel_left>0 or world.combat_paused() or world.phase=="ended": return false
	initialize(); sessions[world.sector_coord] = capture()
	var source: Vector2i = actor.region_coord
	var next: Vector2i = source+SectorGenerator.DIRECTIONS[direction]
	if absi(next.x)>4096 or absi(next.y)>4096: return false
	if (actor.position-world.sector_offset(source)).distance_to(SectorGenerator.EXITS[direction])>=3.7: return false
	if world.waves.running and SectorGenerator.distance(next)>=SectorGenerator.distance(source): return false
	var saved_camera: Transform3D = world.camera.transform
	var saved_notice: String = world.notice
	var saved_notice_left: float = world.notice_left
	var original_player: Node3D = world.player
	load_state(sessions[source]); world.player = actor
	if sessions.has(next):
		load_state(sessions[next])
		var count: int = world.avatars.values().filter(func(a): return a!=actor and a.region_coord==next).size()
		actor.position = world.sector_offset(next)+SectorGenerator.EXITS[(direction+2)%4]*.94+(Vector3.FORWARD if direction%2==1 else Vector3.RIGHT)*count*.9
	else:
		# Preserve the source scene for peers still inside it. The parent loader owns only the new scene.
		world.field_root = null
		for key in ["caches","claimed","field_queue","field_defeated","exit_labels"]:
			var fresh: Array = world.get(key).duplicate(); fresh.clear(); world.set(key,fresh)
		world.descriptor = {}
		world.travel_cooldown = 0
		var checkpoints: bool = world.checkpoint_enabled; world.checkpoint_enabled = false
		var ok: bool = world.load_individual_sector(direction)
		world.checkpoint_enabled = checkpoints
		if not ok:
			load_state(sessions[world.avatars[1].region_coord]); world.player = original_player; return false
		if world.area_index!=-1: world.scale_field_population()
		sessions[next] = capture()
	actor.region_coord = next; actor.region_revision += 1; actor.region_travel_left = 1
	actor.velocity = Vector3.ZERO; actor.cancel_gather(); actor.stop_roll(); actor.invulnerable = maxf(actor.invulnerable,.7)
	actor.input_queue.clear(); actor.roll_intents.clear()
	sessions[next] = capture()
	if source!=Vector2i.ZERO and not world.avatars.values().any(func(a): return a.region_coord==source):
		load_state(sessions[source]); world.remember_sector(); world.clear_region_hazards(SectorGenerator.key(source))
		var old: Node3D = world.field_root
		if is_instance_valid(old): world.remove_child(old); old.queue_free()
		sessions.erase(source)
	load_state(sessions[world.avatars[1].region_coord]); world.player = original_player
	world.scene_revision = world.avatars[1].region_revision
	if actor.peer_id==1:
		var focus: Vector3 = world.sector_offset(next)+(actor.position-world.sector_offset(next))*.82
		world.camera.position = focus+world.camera_offset; world.camera.look_at(focus)
	else: world.camera.transform = saved_camera
	world.notice = saved_notice; world.notice_left = saved_notice_left
	world.private_notice(actor.peer_id,"NÚCLEO (0,0)" if next==Vector2i.ZERO else "SETOR (%d,%d) · Mapa mostra sua equipe e o caminho de volta" % [next.x,next.y])
	world.airdrops.ensure_crate()
	return true
