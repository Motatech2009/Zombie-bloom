extends Node3D
var world: Node3D
var uid: int = 0
var contents: Dictionary = {}
var experience: int = 0
var power: String = ""
var loaded: int = 0
var model: Node3D
var rare: bool = false

func _ready() -> void:
	add_to_group("survival_loot")
	model = VisualFactory.box(self,Vector3(.55,.4,.55),Vector3(0,.3,0),Color("d6bc6e") if rare else Color("9db57b"))

func _process(delta: float) -> void:
	model.rotation.y += delta*.4
	if contents.is_empty() and int(get_meta("xp",0))==0 and str(get_meta("power","")).is_empty() and not world.is_client: queue_free()
