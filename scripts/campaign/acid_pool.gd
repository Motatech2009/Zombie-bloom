extends Node3D
var world: Node3D
var radius: float = 2.5
var damage: float = 8
var life: float = 5
var tick: float = .2
var area_id: int = -1
var region_key: String = ""

func _ready() -> void:
	add_to_group("acid_pools")
	area_id = world.area_index
	if world.has_method("region_at"): region_key = world.region_at(global_position)
	position.y = .05
	var disk := VisualFactory.cylinder(self,radius,.03,Vector3.ZERO,Color("719d3c"))
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	VisualFactory.ring(self,radius,Vector3(0,.04,0),Color("b5ee64"))

func _physics_process(delta: float) -> void:
	if world.phase=="ended": queue_free(); return
	if world.has_method("region_active"):
		if not world.region_active(region_key): queue_free(); return
	elif world.area_index!=area_id: queue_free(); return
	life -= delta
	if life<=0: queue_free(); return
	tick -= delta
	if tick>0: return
	tick = 1
	for body in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(body) or not body.is_inside_tree() or body.is_in_group("enemies") or body.health.dead: continue
		var offset: Vector3 = body.global_position-global_position
		offset.y = 0
		if offset.length()<radius+.35: body.take_damage(damage)
