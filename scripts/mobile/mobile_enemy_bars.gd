class_name MobileEnemyBars
extends Control
var world: Node3D
var rows: Array = []
var refresh_left: float = 0
const LIMIT := 12
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(self)
func _process(delta: float) -> void:
	refresh_left -= delta
	if refresh_left>0: return
	refresh_left = .1; rows.clear()
	if not world.hud.mode.is_empty(): queue_redraw(); return
	var selected = world.touch_controls.locked_target
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not MobileTargeting.alive(enemy): continue
		var distance: float = enemy.position.distance_squared_to(world.player.position)
		if enemy!=selected and not enemy.is_boss and (distance>324 or enemy.health.current>=enemy.health.maximum): continue
		var point: Vector3 = enemy.global_position+Vector3(0,3.3 if enemy.is_boss else 2.4 if enemy.spec.id!="hound" else 1.45,0)
		if world.camera.is_position_behind(point): continue
		var screen: Vector2 = world.camera.unproject_position(point)
		if not Rect2(Vector2.ZERO,size).has_point(screen): continue
		candidates.append({"pos":screen,"fraction":clampf(enemy.health.current/enemy.health.maximum,0,1),"boss":enemy.is_boss,"priority":-20000 if enemy==selected else -10000 if enemy.is_boss else distance,"text":enemy.spec.title+" · %d/%d" % [ceili(enemy.health.current),ceili(enemy.health.maximum)] if enemy.is_boss else "%d/%d" % [ceili(enemy.health.current),ceili(enemy.health.maximum)] if enemy==selected else ""})
	candidates.sort_custom(func(a,b): return a.priority<b.priority)
	rows = candidates.slice(0,LIMIT)
	queue_redraw()
func _draw() -> void:
	for row in rows:
		var width := 150.0 if row.boss else 64.0
		var rect := Rect2(row.pos-Vector2(width/2,0),Vector2(width,7 if row.boss else 5))
		draw_rect(rect.grow(1),Color("10232a"))
		draw_rect(Rect2(rect.position,Vector2(width*row.fraction,rect.size.y)),Color("e8ac62") if row.boss else UI.LIME)
		if not row.text.is_empty():
			var pos: Vector2 = row.pos-Vector2(150,8)
			draw_string_outline(ThemeDB.fallback_font,pos,row.text,HORIZONTAL_ALIGNMENT_CENTER,300,12,3,Color("10232a"))
			draw_string(ThemeDB.fallback_font,pos,row.text,HORIZONTAL_ALIGNMENT_CENTER,300,12,UI.TEXT)
