extends "res://scripts/campaign/campaign_projectile.gd"
func _physics_process(delta: float) -> void:
	if world.phase=="ended" or not world.region_active(region_key): queue_free(); return
	elapsed += delta
	var t := minf(1,elapsed/life)
	position = start.lerp(destination,t)+Vector3.UP*sin(t*PI)*2.5
	model.rotation.x += delta*5
	if t>=1:
		world.defense_blast(destination,radius,damage)
		queue_free()
