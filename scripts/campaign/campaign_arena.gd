extends Arena
var area: int = 0

func ground() -> void:
	super.ground()
	VisualFactory.box(self,Vector3(61,.02,61),Vector3(0,-.03,0),CampaignData.AREAS[area].color)

func props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + area
	var spots: Array[Vector3] = []
	match area:
		0: spots = [Vector3(-12,0,-8),Vector3(11,0,-8),Vector3(-12,0,9),Vector3(12,0,9)]
		1: spots = [Vector3(-14,0,-13),Vector3(14,0,-13),Vector3(-14,0,9),Vector3(14,0,9)]
		2: spots = [Vector3(-12,0,-8),Vector3(12,0,-8),Vector3(-12,0,11),Vector3(12,0,11)]
		3: spots = [Vector3(-14,0,-10),Vector3(14,0,-10),Vector3(-12,0,10),Vector3(12,0,10)]
	for i in range(spots.size()):
		var body := StaticBody3D.new()
		add_child(body)
		body.position = spots[i]
		var size := Vector3(7,2.4,5) if area == 0 else Vector3(9,3.2,8) if area == 1 else Vector3(6,2.8,7)
		VisualFactory.box(body,size,Vector3(0,size.y/2,0),Color("665f4c") if area == 0 else Color("536369") if area == 1 else Color("646e64"))
		VisualFactory.box(body,Vector3(size.x+.3,.22,size.z+.3),Vector3(0,size.y+.1,0),Color("2a4248"))
		if area == 1:
			for x in [-2,2]: VisualFactory.box(body,Vector3(1,1,.06),Vector3(x,1.8,size.z/2+.04),Color("a3b29a"))
		elif area >= 2:
			for x in [-2,2]: VisualFactory.cylinder(body,.6,3,Vector3(x,2,0),Color("8b8170"))
		VisualFactory.collider(body,size,Vector3(0,size.y/2,0))
		mark_solid(spots[i],Vector2(size.x+1,size.z+1))
	var sign := VisualFactory.health_label(self,2)
	sign.position = Vector3(0,2,23)
	sign.text = "EXTRAÇÃO\nE / VOLTAR AO REFÚGIO"
	VisualFactory.ring(self,3,Vector3(0,.08,24),Color("b6e78a"))
