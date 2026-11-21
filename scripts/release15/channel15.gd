class_name Channel15
extends RefCounted
var jobs: Dictionary = {}
var world: Node3D
func start(actor: Node3D,kind: String,target: Node3D,data: Dictionary = {}) -> bool:
	if jobs.has(actor.peer_id) or actor.health.dead or actor.roll_left>0: return false
	var point: Vector3 = data.get("pos",target.global_position if is_instance_valid(target) else actor.position)
	if actor.global_position.distance_to(point)> (12.0 if kind=="build" else 4.0): return false
	var level = world.upgrades.level_for(actor,"engineering")
	var duration = 4.0 if kind=="extract" else (1.5+.5*int(data.get("tier",1)))*(1-.4*level/12.0)
	if kind!="extract": duration = maxf(.7,duration*(1-Catalog16.bonus(actor,"eng_hands")))
	jobs[actor.peer_id] = {"actor":actor,"kind":kind,"target":target,"point":point,"start":actor.position,"damage":actor.last_damage,"data":data.duplicate(true),"left":duration,"duration":duration}
	actor.gather_kind = kind; actor.gather_progress = .001; actor.gather_duration = duration
	return true
func tick(delta: float) -> void:
	for id in jobs.keys():
		var j: Dictionary = jobs[id]; var actor: Node3D = j.actor
		if not is_instance_valid(actor) or actor.health.dead or actor.last_damage!=j.damage or actor.position.distance_to(j.start)>.65 or actor.roll_left>0 or (j.kind!="build" and j.kind!="extract" and not is_instance_valid(j.target)) or (j.kind!="extract" and not world.base_preparing()): cancel(id); continue
		j.left -= delta
		actor.gather_kind = j.kind; actor.gather_duration = j.duration; actor.gather_progress = j.duration-j.left
		if j.left>0: continue
		jobs.erase(id); actor.cancel_gather()
		var saved: CharacterBody3D = world.player; world.player = actor
		match j.kind:
			"build": world.builder.commit_channel(j.data)
			"upgrade":
				if is_instance_valid(j.target) and world.nearest_structure()==j.target: world.commit_upgrade()
			"extract": world.v15.extract(actor)
		world.player = saved
func cancel(id: int) -> void:
	if jobs.has(id) and is_instance_valid(jobs[id].actor): jobs[id].actor.cancel_gather()
	jobs.erase(id)
