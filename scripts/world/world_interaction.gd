class_name WorldInteraction
extends Node3D
var world: Node3D
var id: String
var kind: String
var data: Dictionary
var model: Node3D
var obstacle: StaticBody3D
var label: Label3D
var progress: float = 0
var units: int = 0
var opened: bool = false
var door_leaf: Node3D
var door_shape: CollisionShape3D

func _ready() -> void:
	add_to_group("world_interactions")
	var change: Dictionary = world.state.changes.get(id, {})
	units = int(change.get("units", data.get("units", 9)))
	opened = bool(change.get("open", false))
	model = Node3D.new()
	add_child(model)
	label = VisualFactory.health_label(self, 2.4)
	label.font_size = 20
	label.visible = false
	match kind:
		"tree":
			VisualFactory.cylinder(model, .3, 2.2, Vector3(0, 1.1, 0), Color("6a5740"))
			for y in [2.8, 3.7, 4.5]:
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0
				mesh.bottom_radius = 1.8 - (y - 2.8) * .35
				mesh.height = 2.2
				mesh.radial_segments = 7
				VisualFactory.mesh_node(model, mesh, Vector3(0, y, 0), Color("38563e") if y < 4 else Color("52704a"), false)
			make_obstacle(Vector3(.65, 2.4, .65))
		"rock":
			var rock := VisualFactory.box(model, Vector3(1.6, 1, 1.4), Vector3(0, .4, 0), Color("849184"))
			rock.rotation.y = float(id.hash() % 10)
			VisualFactory.box(model, Vector3(.7, .45, .7), Vector3(.55, .25, .3), Color("687b73"))
			make_obstacle(Vector3(1.5, 1, 1.4))
		"salvage", "container":
			VisualFactory.box(model, Vector3(1.1, .85, .8), Vector3(0, .43, 0), Color("866f50"))
			for x in [-.35, .35]:
				VisualFactory.box(model, Vector3(.08, .9, .84), Vector3(x, .44, 0), Color("3d5557"))
			make_obstacle(Vector3(1.1, .85, .8))
		"entry", "exit":
			VisualFactory.box(model, Vector3(1.5, .04, 1.2), Vector3(0, .04, 0), Color("b9d880"), true)
		"door":
			door_leaf = Node3D.new()
			model.add_child(door_leaf)
			VisualFactory.box(door_leaf, Vector3(1.6, 2.2, .15), Vector3(0, 1.1, 0), Color("7a6245"))
			obstacle = StaticBody3D.new()
			add_child(obstacle)
			door_shape = VisualFactory.collider(obstacle, Vector3(1.6, 2.3, .2), Vector3(0, 1.15, 0))
			apply_door()
	refresh()

func make_obstacle(size: Vector3) -> void:
	obstacle = StaticBody3D.new()
	add_child(obstacle)
	VisualFactory.collider(obstacle, size, Vector3(0, size.y * .5, 0))

func refresh() -> void:
	if kind in ["tree", "rock", "salvage", "container"]:
		var depleted := units <= 0
		model.visible = not depleted
		if is_instance_valid(obstacle):
			obstacle.process_mode = Node.PROCESS_MODE_DISABLED if depleted else Node.PROCESS_MODE_INHERIT
		if depleted:
			label.visible = false

func available() -> bool:
	return units > 0 or kind in ["entry", "exit", "door"]

func prompt() -> String:
	match kind:
		"entry": return "F · Entrar em " + str(data.get("title", "edifício"))
		"exit": return "F · Voltar ao mundo"
		"door": return "F · Fechar porta" if opened else "F · Abrir porta"
	var title := "madeira" if kind == "tree" else "pedra" if kind == "rock" else "metal"
	if world.state.cargo_total() >= WorldState.CAPACITY:
		return "MOCHILA CHEIA · Volte ao núcleo e deposite com F"
	return "SEGURE F · Extrair %s · %d restantes%s" % [title, units, " · %d%%" % int(progress / 1.6 * 100) if progress > 0 else ""]

func use() -> void:
	match kind:
		"entry": world.enter_building(data)
		"exit": world.leave_building()
		"door":
			opened = not opened
			world.state.changes[id] = {"open": opened}
			apply_door()

func apply_door() -> void:
	door_leaf.rotation.y = PI * .48 if opened else 0
	door_shape.set_deferred("disabled", opened)

func extract(delta: float) -> int:
	if kind in ["entry", "exit", "door"] or units <= 0 or world.state.cargo_total() >= WorldState.CAPACITY:
		progress = 0
		return 0
	progress += delta
	if progress < 1.6:
		return 0
	progress = 0
	var material := "wood" if kind == "tree" else "stone" if kind == "rock" else "metal"
	var accepted: int = world.state.put_cargo(material, mini(3, units))
	units -= accepted
	world.state.changes[id] = {"units": units}
	refresh()
	if units == 0:
		world.outdoor.navigation_dirty = true
	world.audio.play_tone(270 if material == "wood" else 530, .06, .06)
	return accepted
