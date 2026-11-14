extends Node3D
var world: Node3D
var kind: String = "grenade"
var start := Vector3.ZERO
var destination := Vector3.ZERO
var damage: float = 90
var radius: float = 4
var life: float = .85
var elapsed: float = 0
var model: Node3D
var area_id: int = -1
var region_key: String = ""
var owner_peer: int = 1

func _ready() -> void:
	add_to_group("campaign_projectiles")
	area_id = world.area_index
	if world.has_method("region_at"): region_key = world.region_at(start)
	position = start
	model = VisualFactory.box(self,Vector3(.23,.23,.4),Vector3.ZERO,Color("a8d95e") if kind=="acid" else Color("f2b563"),true)
	if kind=="acid":
		var warning := VisualFactory.ring(self,radius,Vector3.ZERO,Color("8bdf57"))
		warning.set_as_top_level(true)
		warning.global_position = destination*Vector3(1,0,1)+Vector3(0,.08,0)

func _physics_process(delta: float) -> void:
	if world.has_method("combat_paused") and world.combat_paused(): return
	if world.phase=="ended": queue_free(); return
	if world.has_method("region_active"):
		if not world.region_active(region_key): queue_free(); return
	elif world.area_index!=area_id: queue_free(); return
	var old := position
	elapsed += delta
	var t := minf(1,elapsed/life)
	position = start.lerp(destination,t)
	if kind in ["grenade","acid"]: position.y += sin(t*PI)*(3.5 if kind=="grenade" else 1.3)
	model.rotation.x += delta*8
	var hit := {}
	if kind=="rocket":
		var ray := PhysicsRayQueryParameters3D.create(old,position,1|4|8)
		hit = get_world_3d().direct_space_state.intersect_ray(ray)
	if t>=1 or not hit.is_empty():
		if not hit.is_empty(): position = hit.position
		if kind=="acid": world.spawn_acid(position,radius,damage)
		elif world.has_method("explode_from"): world.explode_from(position,radius,damage,owner_peer)
		else: world.explode(position,radius,damage)
		queue_free()
