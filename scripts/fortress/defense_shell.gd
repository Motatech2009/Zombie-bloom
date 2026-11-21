extends "res://scripts/campaign/campaign_projectile.gd"
func _ready() -> void:
	super._ready()
	model.scale = Vector3(1.65,1.65,2.1)
	if start.distance_squared_to(destination)>.001: look_at(destination)
func _physics_process(delta: float) -> void:
	if world.phase=="ended" or not world.region_active(region_key): queue_free(); return
	if world.combat_paused(): return
	elapsed += delta
	var t := minf(1,elapsed/life)
	position = start.lerp(destination,t)
	if t>=1:
		world.defense_blast(destination,radius,damage)
		queue_free()
