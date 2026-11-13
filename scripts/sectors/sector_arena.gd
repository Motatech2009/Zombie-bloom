extends "res://scripts/campaign/defense_arena.gd"
var descriptor: Dictionary
var world: Node3D

func ground() -> void:
	var colors := [Color("485d5f"),Color("60625b"),Color("3e5947"),Color("696954"),Color("566153")]
	VisualFactory.box(self,Vector3(110,.3,110),Vector3(0,-.2,0),colors[descriptor.biome])
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	floor_body.collision_layer = 1
	VisualFactory.collider(floor_body,Vector3(110,.3,110),Vector3(0,-.2,0))
	VisualFactory.box(self,Vector3(12,.04,108),Vector3(0,-.025,0),Color("3a494d"))
	VisualFactory.box(self,Vector3(108,.04,10),Vector3(0,-.02,0),Color("3a494d"))
	for side in [-1,1]:
		for horizontal in [true,false]:
			var border := StaticBody3D.new()
			add_child(border)
			border.position = Vector3(0,0,side*54) if horizontal else Vector3(side*54,0,0)
			var size := Vector3(110,2,.6) if horizontal else Vector3(.6,2,110)
			VisualFactory.collider(border,size,Vector3(0,1,0))
			VisualFactory.box(border,size,Vector3(0,1,0),Color("293d40"))

func props() -> void:
	for block in descriptor.blocks:
		var body := StaticBody3D.new()
		add_child(body)
		body.position = block.pos
		VisualFactory.box(body,block.size,Vector3(0,block.size.y/2,0),Color("5b6963") if block.style==0 else Color("6f6b58"))
		if descriptor.biome==2:
			VisualFactory.cylinder(body,.28,block.size.y+1,Vector3(0,(block.size.y+1)/2,0),Color("403f35"))
		else:
			VisualFactory.box(body,Vector3(block.size.x+.3,.2,block.size.z+.3),Vector3(0,block.size.y+.1,0),Color("2b4247"))
		VisualFactory.collider(body,block.size,Vector3(0,block.size.y/2,0))
		mark_solid(block.pos,Vector2(block.size.x+1.2,block.size.z+1.2))
