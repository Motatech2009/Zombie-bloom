class_name BetaStructure
extends StaticBody3D
var world: Node3D
var kind: String = "wall"
var uid: String = ""
var health := Health.new()
var spec: Resource
var opened: bool = false
var leaf: Node3D
var solid: CollisionShape3D
var label: Label3D

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("beta_structures")
	collision_layer = 8
	var data: Dictionary = BetaCatalog.DATA.values.structures[kind]
	spec = GameSpec.new()
	spec.id = kind
	add_child(health)
	health.setup(data.health)
	health.died.connect(die)
	var size := Vector3(data.size[0], data.size[1], data.size[2])
	leaf = Node3D.new()
	add_child(leaf)
	VisualFactory.box(leaf, size, Vector3(0, size.y * .5, 0), Color(data.color))
	if kind == "workbench":
		VisualFactory.box(leaf, Vector3(2.2, .1, 1.4), Vector3(0, 1, 0), Color("b09b72"))
		VisualFactory.box(leaf, Vector3(.45, .3, .4), Vector3(.5, 1.2, 0), Color("738c8c"))
	solid = VisualFactory.collider(self, size, Vector3(0, size.y * .5, 0))
	if kind == "foundation":
		solid.position.y = -.04
	if kind == "crate":
		world.container_for(uid, "empty")
	label = VisualFactory.health_label(self, size.y + .6)
	label.font_size = 19
	label.visible = false
	apply_gate()

func _process(_delta: float) -> void:
	label.visible = health.current < health.maximum
	label.text = "%d / %d" % [ceili(health.current), ceili(health.maximum)]

func apply_gate() -> void:
	if kind == "gate":
		leaf.rotation.y = PI * .48 if opened else 0
		solid.set_deferred("disabled", opened)

func use() -> void:
	if kind == "gate":
		opened = not opened
		apply_gate()
		world.outdoor.navigation_dirty = true
	elif kind == "crate":
		world.hud.show_loot(world.container_for(uid, "empty"), uid)
	elif kind == "workbench":
		world.hud.show_crafting()

func take_damage(amount: float) -> void:
	if health.dead or world.phase == "ended":
		return
	health.take_damage(amount)
	world.effects.burst(global_position + Vector3.UP, Color("c2a56e"), 2)

func die() -> void:
	if kind == "crate":
		world.drop_container(uid, global_position)
	remove_from_group("buildings")
	remove_from_group("beta_structures")
	collision_layer = 0
	world.outdoor.navigation_dirty = true
	queue_free()
