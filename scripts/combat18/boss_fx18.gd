class_name BossFx18
extends Node3D

const COLORS := {
	"area": Color("e9a269"), "line": Color("ffd98b"), "acid": Color("a9e558"),
	"thorn": Color("e8b774"), "snare": Color("a7e383"), "wind": Color("c7f1dc"),
	"quakes": Color("e49f72"), "stakes": Color("ae7451"), "vines": Color("639b43"),
	"howl": Color("f2cb82"), "howl_wave": Color("e8d4a0"), "brood": Color("ae9a71"), "claw": Color("f5ab88"),
	"clay": Color("d38c69"), "square": Color("df9979"), "mold": Color("a77c60"), "clay_cage": Color("ba8767"),
}

var world: Node3D
var data: Dictionary
var elapsed := 0.0
var region_key := ""
var pieces: Array[Node3D] = []

static func spawn(owner_world: Node3D, kind: String, point: Vector3, heading: Vector3, size: float, width: float, duration: float) -> Node3D:
	var row := {
		"id": owner_world.next_id(), "fx18": kind, "p": point, "dir": heading,
		"s": size, "w": width, "life": duration,
		"warning": kind in ["line", "square", "area", "acid", "thorn", "snare"],
	}
	var node := from_state(owner_world, row)
	owner_world.effects.add_child(node)
	node.add_to_group("boss_fx18")
	return node

static func from_state(owner_world: Node3D, row: Dictionary) -> BossFx18:
	var node := BossFx18.new()
	node.world = owner_world
	node.data = row.duplicate()
	node.position = row.p
	node.elapsed = float(row.get("age", 0.0))
	node.region_key = owner_world.region_at(row.p)
	return node

func _ready() -> void:
	var direction: Vector3 = data.dir
	if direction.length_squared() > .01:
		rotation.y = atan2(-direction.x, -direction.z)
	var color: Color = COLORS[data.fx18]
	var extent: float = data.s
	var width: float = data.w
	match data.fx18:
		"line":
			floor_box(Vector3(width * 2, .02, extent), Vector3(0,.035,-extent*.5), color)
			for side in [-1.0, 1.0]:
				VisualFactory.box(self, Vector3(.075,.055,extent), Vector3(side*width,.085,-extent*.5), color, true)
			for i in range(1, 5):
				var z := -extent * float(i) / 5.0
				for side in [-1.0, 1.0]:
					var tip := VisualFactory.box(self, Vector3(.095,.055,width*.74), Vector3(side*width*.28,.085,z), color, true)
					tip.rotation.y = side * .85
		"square":
			floor_box(Vector3(extent*2,.02,extent*2),Vector3(0,.045,0),color)
			for side in [-1.0,1.0]:
				VisualFactory.box(self, Vector3(extent*2,.06,.083),Vector3(0,.075,side*extent),color,true)
				VisualFactory.box(self, Vector3(.083,.06,extent*2),Vector3(side*extent,.075,0),color,true)
		"area", "acid", "thorn", "snare":
			var circle := VisualFactory.cylinder(self, extent, .02, Vector3(0,.035,0), color, true)
			tint_floor(circle, color)
			VisualFactory.ring(self, extent, Vector3(0,.09,0), color)
			for i in range(8):
				var angle := float(i)*TAU/8.0
				var marker := VisualFactory.box(self, Vector3(.10,.05,.65), Vector3(sin(angle),0,cos(angle))*(extent-.38)+Vector3.UP*.09, color,true)
				marker.rotation.y = angle
		"wind", "clay":
			for i in range(7 if MobilePlatform.lightweight() else 13):
				var spread := float(i % 5) / 4.0 * 2.0 - 1.0
				var dust: bool = data.fx18 == "wind" and i % 3 == 1
				var tone := Color("c69872") if dust else color
				var piece := VisualFactory.box(self, Vector3(.19,.16,.7 if data.fx18=="wind" and not dust else .39), Vector3(spread*width*.85,.4,0), tone, not dust)
				pieces.append(piece)
		"mold":
			for i in range(4):
				pieces.append(VisualFactory.box(self, Vector3(extent,2.58,extent),Vector3((i%2-.5)*extent,0,(floorf(i/2.0)-.5)*extent),color))
		"quakes", "stakes", "vines", "brood", "clay_cage":
			for i in range(8 if MobilePlatform.lightweight() else 12):
				var angle := float(i) * 2.39996
				var radius := extent * (.4 + float(i % 5) * .13)
				var point := Vector3(cos(angle)*radius,0,sin(angle)*radius)
				var shard := VisualFactory.box(self, Vector3(.22,1.1 if data.fx18=="stakes" else .73,.22),point,color)
				shard.rotation = Vector3(cos(angle)*.34,angle,sin(angle)*.34)
				pieces.append(shard)
		"claw":
			for i in range(3):
				var cut := VisualFactory.box(self, Vector3(.095,.085,extent*.94), Vector3((i-1)*.33,.68,-extent*.55),color,true)
				cut.rotation.z = -.25
				pieces.append(cut)
		"howl", "howl_wave":
			pieces.append(VisualFactory.ring(self,extent,Vector3(0,.25,0),color))
			pieces.append(VisualFactory.ring(self,extent,Vector3(0,.63,0),color.lightened(.28)))
			if data.fx18 == "howl" and world.player.global_position.distance_to(global_position) <= extent + 12:
				world.audio.play_cue(GameAudio.Cue.HOWL)
	update_visual()

func floor_box(size: Vector3, point: Vector3, color: Color) -> void:
	tint_floor(VisualFactory.box(self,size,point,color,true),color)

func tint_floor(mesh: MeshInstance3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, .21)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_visual() -> void:
	var progress := clampf(elapsed / float(data.life),0.0,1.0)
	for i in range(pieces.size()):
		var piece := pieces[i]
		match data.fx18:
			"wind", "clay":
				var flow := clampf(progress*1.25 - float(i % 4)*.072,0.0,1.0) if data.fx18 == "wind" else maxf(0, progress - float(i%4)*.034)
				piece.position.z = -data.s*flow
				piece.position.y = .29 + float(i % 5)*.16 + sin(progress*TAU+i)*.2
				piece.rotation.x = progress*4.0+i
				piece.scale = Vector3.ONE * (1.0 - smoothstep(.72,1.0,progress))
			"mold":
				var rise := smoothstep(float(i)*.055, .48, progress)
				piece.position.y = 1.29*rise
				piece.scale.y = maxf(.02, rise*(1.0-smoothstep(.78,1.0,progress)))
			"stakes", "vines", "quakes", "brood", "clay_cage":
				var rise := smoothstep(0.0,.24,progress) if data.fx18 not in ["vines", "clay_cage"] else smoothstep(0.0,.055,progress)
				piece.position.y = (.13 + float(i % 3)*.17) * rise
				piece.scale.y = maxf(.03, rise * (1.0-smoothstep(.73,1.0,progress)))
			"howl", "howl_wave":
				var reach := maxf(.06, progress*1.17-float(i)*.16)
				piece.scale = Vector3(reach,1,reach)
			"claw":
				piece.scale = Vector3.ONE * (1.0 - smoothstep(.25,1.0,progress))

func _process(delta: float) -> void:
	if world.combat_paused(): return
	elapsed += delta
	if elapsed >= float(data.life):
		if world.is_client: hide()
		else: queue_free()
		return
	update_visual()

func state() -> Dictionary:
	var row := data.duplicate()
	row.age = elapsed
	return row
