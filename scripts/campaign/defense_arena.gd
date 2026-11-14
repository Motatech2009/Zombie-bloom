extends Arena
const HALF_SIZE := 54

func _ready() -> void:
	navigation.region = Rect2i(0,0,55,55)
	navigation.cell_size = Vector2(2,2)
	navigation.offset = Vector2(-54,-54)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	ground()
	props()

func ground() -> void:
	VisualFactory.box(self,Vector3(110,.3,110),Vector3(0,-.2,0),Color("334843"))
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	floor_body.collision_layer = 1
	VisualFactory.collider(floor_body,Vector3(110,.3,110),Vector3(0,-.2,0))
	VisualFactory.box(self,Vector3(12,.04,108),Vector3(0,-.025,0),Color("35434a"))
	VisualFactory.box(self,Vector3(108,.04,8),Vector3(0,-.02,0),Color("35434a"))
	VisualFactory.box(self,Vector3(10,.07,10),Vector3(0,.005,0),Color("4c5c59"))
	for z in range(-12,13):
		if absi(z)>1: VisualFactory.box(self,Vector3(.11,.03,1.4),Vector3(0,.015,z*4),Color("b1a774"))
	for side in [-1,1]:
		for horizontal in [true,false]:
			var border := StaticBody3D.new()
			add_child(border)
			border.position = Vector3(0,0,side*54) if horizontal else Vector3(side*54,0,0)
			var size := Vector3(110,2,.6) if horizontal else Vector3(.6,2,110)
			VisualFactory.collider(border,size,Vector3(0,1,0))
			VisualFactory.box(border,size,Vector3(0,1,0),Color("23353b"))
	VisualFactory.ring(self,4.6,Vector3(0,.09,0),Color("8c9e64"))

func props() -> void:
	for pos in [Vector3(-11,0,-9),Vector3(10,0,9),Vector3(14,0,-12),Vector3(-13,0,12)]:
		var car := StaticBody3D.new()
		add_child(car)
		car.position = pos
		VisualFactory.box(car,Vector3(2.4,.8,4.5),Vector3(0,.7,0),Color("627176"))
		VisualFactory.box(car,Vector3(2.1,.65,2),Vector3(0,1.4,.2),Color("344b54"))
		for side in [-1,1]:
			for z in [-1.4,1.4]: VisualFactory.box(car,Vector3(.35,.6,.7),Vector3(side*1.15,.3,z),Color("1d2c31"))
		VisualFactory.collider(car,Vector3(2.7,1.7,4.8),Vector3(0,.85,0))
		mark_solid(pos,Vector2(4,6))
	for x in [-36,36]:
		for z in [-30,0,30]:
			var ruin := StaticBody3D.new()
			add_child(ruin)
			ruin.position = Vector3(x,0,z)
			VisualFactory.box(ruin,Vector3(9,2.4,7),Vector3(0,1.2,0),Color("52615d"))
			VisualFactory.box(ruin,Vector3(9.5,.2,7.5),Vector3(0,2.5,0),Color("243c43"))
			VisualFactory.collider(ruin,Vector3(9,2.4,7),Vector3(0,1.2,0))
			mark_solid(ruin.position,Vector2(10,8))

func mark_solid(pos: Vector3,size: Vector2) -> void:
	for x in range(55):
		for y in range(55):
			var point := navigation.get_point_position(Vector2i(x,y))
			if absf(point.x-pos.x)<size.x/2 and absf(point.y-pos.z)<size.y/2: navigation.set_point_solid(Vector2i(x,y))

func route(from: Vector3,to: Vector3) -> PackedVector2Array:
	var start := Vector2i(roundi((from.x+54)/2),roundi((from.z+54)/2)).clamp(Vector2i.ZERO,Vector2i(54,54))
	var end := Vector2i(roundi((to.x+54)/2),roundi((to.z+54)/2)).clamp(Vector2i.ZERO,Vector2i(54,54))
	if navigation.is_point_solid(start) or navigation.is_point_solid(end): return PackedVector2Array()
	return navigation.get_point_path(start,end)
