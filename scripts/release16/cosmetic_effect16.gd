extends Node3D
var actor: Node3D
var class_id := ""
var clock := 0.0
var flash := 0.0
var reloading := false
func _process(delta: float) -> void:
	clock += delta; flash = maxf(0,flash-delta)
	var moving := false
	if is_instance_valid(actor):
		moving = actor.velocity.length()>2
		if reloading and actor.weapons.reload_left<=0: flash = .5
		reloading = actor.weapons.reload_left>0
	visible = not moving if class_id=="engineer" else moving if class_id=="scout" else flash>0 if is_instance_valid(actor) else true
	rotation.y += delta*.4
	for i in range(get_child_count()): get_child(i).scale = Vector3.ONE*(.65+.3*sin(clock*4+i))
