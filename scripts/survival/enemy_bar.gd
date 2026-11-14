extends Node3D
var actor: Node3D
var panel: Control
var fill: ProgressBar
var title: Label

func _ready() -> void:
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.world.hud.root.add_child(panel)
	actor.world.hud.root.move_child(panel,0)
	var width := 150.0 if actor.is_boss else 64.0
	fill = UI.meter(panel,Color("e8ac62") if actor.is_boss else Color("b3e979"))
	fill.custom_minimum_size = Vector2.ZERO
	fill.position = Vector2(-width/2,0)
	fill.size = Vector2(width,8 if actor.is_boss else 5)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = UI.label(panel,"",14 if actor.is_boss else 12,Color("f0f6e9"))
	title.position = Vector2(-150,-23 if actor.is_boss else -21)
	title.size = Vector2(300,20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_shadow_color",Color("10232a"))
	title.add_theme_constant_override("shadow_offset_x",1)
	title.add_theme_constant_override("shadow_offset_y",1)

func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or actor.health.dead: panel.hide(); return
	var camera: Camera3D = actor.world.camera
	var point: Vector3 = actor.global_position+Vector3(0,3.3 if actor.is_boss else 2.4 if actor.spec.id!="hound" else 1.45,0)
	panel.visible = not camera.is_position_behind(point) and point.distance_to(camera.global_position)<70 and (actor.is_boss or actor.global_position.distance_to(actor.world.player.global_position)<24 or actor.health.current<actor.health.maximum)
	if not panel.visible: return
	panel.position = camera.unproject_position(point)
	fill.max_value = actor.health.maximum
	fill.value = actor.health.current
	title.text = (actor.spec.title+" · " if actor.is_boss else "")+"%d/%d" % [ceili(actor.health.current),ceili(actor.health.maximum)]

func _exit_tree() -> void:
	if is_instance_valid(panel): panel.queue_free()
