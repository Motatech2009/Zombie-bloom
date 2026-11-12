class_name WorldMap
extends Control
var world: Node3D
const MAP_EXTENT := 215.0

func _ready() -> void:
	custom_minimum_size = Vector2(680, 450)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func project(pos: Vector2) -> Vector2:
	return Vector2(size.x * .5, size.y * .5) + pos * minf(size.x, size.y) / (MAP_EXTENT * 2)

func _draw() -> void:
	if world == null:
		return
	var generator: WorldGenerator = world.outdoor.generator
	var scale_factor := minf(size.x, size.y) / (MAP_EXTENT * 2)
	draw_rect(Rect2(Vector2.ZERO, size), Color("263e36"))
	for key: String in world.state.explored:
		var parts := key.split(":")
		var corner := Vector2(int(parts[0]), int(parts[1])) * WorldGenerator.SECTOR_SIZE
		draw_rect(Rect2(project(corner), Vector2.ONE * WorldGenerator.SECTOR_SIZE * scale_factor), Color("405b45"))
	var river := PackedVector2Array()
	for x in range(-320, 321, 4):
		river.append(project(Vector2(x, generator.river_z(x))))
	draw_polyline(river, Color("55969b"), 9)
	for road: Dictionary in generator.roads:
		draw_line(project(road.a), project(road.b), Color("a99c79"), maxf(1, road.width * scale_factor))
	for house: Dictionary in generator.houses:
		draw_rect(Rect2(project(house.pos) - Vector2(3, 3), Vector2(6, 6)), Color("d7c59a"))
	for settlement: Dictionary in generator.settlements:
		var point := project(settlement.pos)
		draw_string(ThemeDB.fallback_font, point + Vector2(-45, -12), settlement.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e1dfca"))
	draw_circle(project(Vector2.ZERO), 6, Color("d5f286"))
	draw_string(ThemeDB.fallback_font, project(Vector2.ZERO) + Vector2(10, 4), "REFÚGIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d5f286"))
	var pos: Vector3 = world.return_position if world.inside else world.player.global_position
	draw_circle(project(Vector2(pos.x, pos.z)), 4, Color("86dce4"))
	draw_string(ThemeDB.fallback_font, Vector2(16, 23), "N ↑     VALE DO CEDRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e5e7cf"))
	clip_contents = true
