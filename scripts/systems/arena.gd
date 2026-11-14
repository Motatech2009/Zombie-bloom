class_name Arena
extends Node3D
var navigation := AStarGrid2D.new()

func _ready() -> void:
	navigation.region = Rect2i(0, 0, 31, 31)
	navigation.cell_size = Vector2(2, 2)
	navigation.offset = Vector2(-30, -30)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	ground()
	props()

func ground() -> void:
	VisualFactory.box(self, Vector3(62, .3, 62), Vector3(0, -.2, 0), Color("334843"))
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	floor_body.collision_layer = 1
	VisualFactory.collider(floor_body, Vector3(62, .3, 62), Vector3(0, -.2, 0))
	VisualFactory.box(self, Vector3(12, .04, 60), Vector3(0, -.025, 0), Color("35434a"))
	VisualFactory.box(self, Vector3(60, .04, 8), Vector3(0, -.02, 0), Color("35434a"))
	VisualFactory.box(self, Vector3(10, .07, 10), Vector3(0, .005, 0), Color("4c5c59"))
	for i in range(-7, 8):
		if absi(i) > 1:
			VisualFactory.box(self, Vector3(.11, .03, 1.4), Vector3(0, .015, i * 4), Color("b1a774"))
	for x in [-5.9, 5.9]:
		VisualFactory.box(self, Vector3(.1, .035, 60), Vector3(x, .01, 0), Color("839286"))
	for i in range(4):
		var border := StaticBody3D.new()
		add_child(border)
		var horizontal := i < 2
		border.position = Vector3(0, 0, -30 if i == 0 else 30) if horizontal else Vector3(-30 if i == 2 else 30, 0, 0)
		var size := Vector3(62, 2, .6) if horizontal else Vector3(.6, 2, 62)
		VisualFactory.collider(border, size, Vector3(0, 1, 0))
		VisualFactory.box(border, size, Vector3(0, 1, 0), Color("23353b"))
	VisualFactory.ring(self, 4.6, Vector3(0, .09, 0), Color("8c9e64"))

func props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8417
	for pos in [Vector3(-11, 0, -9), Vector3(10, 0, 9), Vector3(14, 0, -12), Vector3(-13, 0, 12)]:
		var body := StaticBody3D.new()
		add_child(body)
		body.position = pos
		VisualFactory.box(body, Vector3(2.4, .8, 4.5), Vector3(0, .7, 0), Color("627176"))
		VisualFactory.box(body, Vector3(2.1, .65, 2.0), Vector3(0, 1.4, .2), Color("344b54"))
		for side in [-1, 1]:
			for z in [-1.4, 1.4]:
				VisualFactory.box(body, Vector3(.35, .6, .7), Vector3(side * 1.15, .3, z), Color("1d2c31"))
		VisualFactory.collider(body, Vector3(2.7, 1.7, 4.8), Vector3(0, .85, 0))
		mark_solid(pos, Vector2(4.2, 6.2))
	for i in range(32):
		var pos := Vector3(rng.randf_range(-28, 28), 0, rng.randf_range(-28, 28))
		if absf(pos.x) < 8 or pos.length() < 9:
			continue
		VisualFactory.box(self, Vector3(rng.randf_range(.3, 1.1), .1, rng.randf_range(.2, .8)), pos, Color("687469"))
	for side in [-1, 1]:
		for i in range(5):
			var x: float = side * rng.randf_range(32, 37)
			var pos := Vector3(x, 2, i * 13 - 26)
			VisualFactory.box(self, Vector3(8, 4, 8), pos, Color("25383c"))
			VisualFactory.box(self, Vector3(8.4, .3, 8.4), pos + Vector3(0, 2, 0), Color("172b32"))
			for z in [-2, 1]:
				VisualFactory.box(self, Vector3(.08, .8, 1.4), pos + Vector3(-side * 4.02, .4, z), Color("9d8e54"), true)
	var sign := VisualFactory.health_label(self, 3.3)
	sign.position = Vector3(-6, 3.3, -7)
	sign.text = "POSTO 07\nÚLTIMO REFÚGIO"
	sign.modulate = Color("acbfaa")

func mark_solid(pos: Vector3, size: Vector2) -> void:
	for x in range(31):
		for y in range(31):
			var point: Vector2 = navigation.get_point_position(Vector2i(x, y))
			if absf(point.x - pos.x) < size.x * .5 and absf(point.y - pos.z) < size.y * .5:
				navigation.set_point_solid(Vector2i(x, y))

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	var start := Vector2i(roundi((from.x + 30) / 2), roundi((from.z + 30) / 2)).clamp(Vector2i.ZERO, Vector2i(30, 30))
	var end := Vector2i(roundi((to.x + 30) / 2), roundi((to.z + 30) / 2)).clamp(Vector2i.ZERO, Vector2i(30, 30))
	if navigation.is_point_solid(start) or navigation.is_point_solid(end):
		return PackedVector2Array()
	return navigation.get_point_path(start, end)
