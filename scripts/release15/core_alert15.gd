extends Control
var world: Node3D
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if world.v15.alert_left<=0: return
	var color = Color(1,.4,.15,.2+.15*sin(Time.get_ticks_msec()*.007))
	draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),color,false,6)
	if world.coord_at(world.player.global_position)==Vector2i.ZERO: return
	var origin = world.camera.unproject_position(world.player.global_position)
	var projected = world.camera.unproject_position(Vector3.ZERO)
	var direction = (projected-origin).normalized()
	var point = size*.5+direction*minf(size.x,size.y)*.33
	var side = direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([point+direction*20,point-direction*12+side*12,point-direction*12-side*12]),Color(1,.7,.2,.85))
