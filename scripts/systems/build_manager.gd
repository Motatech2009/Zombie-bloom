class_name BuildManager
extends Node3D
var world: Node3D
var active: bool = false
var selected: int = 0
var preview: Node3D
var marker: MeshInstance3D
var location := Vector3.ZERO
var valid: bool = false
var reason: String = ""
const SCENES = [preload("res://scenes/buildings/Barricade.tscn"), preload("res://scenes/buildings/Turret.tscn")]
const MAX_STRUCTURES := 24

func _ready() -> void:
	preview = Node3D.new()
	add_child(preview)
	marker = VisualFactory.box(preview, Vector3(2.1, .12, 2.1), Vector3(0, .12, 0), Color("a4e886"))
	preview.visible = false

func set_active(value: bool) -> void:
	active = value and world.phase == "prep"
	preview.visible = active
	if active:
		world.notify("CONSTRUÇÃO · 1 Barricada / 2 Torreta · Clique para instalar · B cancela")

func _physics_process(_delta: float) -> void:
	if not active:
		return
	for i in range(2):
		if Input.is_action_just_pressed("slot_" + str(i + 1)):
			selected = i
	var point: Vector3 = world.mouse_ground(0)
	location = Vector3(snappedf(point.x, 1.0), 0, snappedf(point.z, 1.0))
	preview.global_position = location
	valid = can_place(location)
	var radius: float = Catalog.BUILDINGS[selected].values.radius
	marker.scale = Vector3(radius / 1.05, 1, radius / 1.05)
	marker.material_override = VisualFactory.material(Color("a4e886") if valid else Color("e47b68"), false)

func can_place(pos: Vector3) -> bool:
	var spec: Resource = Catalog.BUILDINGS[selected]
	if world.phase != "prep":
		reason = "Construa entre as hordas."
		return false
	if absf(pos.x) > 24 or absf(pos.z) > 24:
		reason = "Fora da área de construção."
		return false
	if pos.distance_to(world.player.global_position) > 12:
		reason = "Aproxime-se do local (máximo 12 m)."
		return false
	if get_tree().get_nodes_in_group("buildings").size() - 1 >= MAX_STRUCTURES:
		reason = "Limite de 24 defesas atingido."
		return false
	if world.resources.scrap < int(spec.values.cost):
		reason = "Sucata insuficiente."
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	var radius: float = spec.values.radius
	shape.size = Vector3(radius * 2 + .2, 1.7, radius * 2 + .2)
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 1.0, 0))
	query.collision_mask = 1 | 2 | 4 | 8
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		reason = "Local ocupado."
		return false
	reason = "Clique para construir · %d sucata" % spec.values.cost
	return true

func place() -> Node3D:
	if not active or not can_place(location):
		world.notify(reason)
		return null
	var cost: int = Catalog.BUILDINGS[selected].values.cost
	if not world.resources.spend(cost):
		return null
	var building: Node3D = SCENES[selected].instantiate()
	building.world = world
	building.position = location
	world.add_child(building)
	world.effects.burst(location + Vector3.UP, Color("c8df9a"), 8)
	world.audio.play_tone(330, .12, .10)
	world.notify("%s instalada · −%d sucata" % [Catalog.BUILDINGS[selected].title, cost])
	return building
