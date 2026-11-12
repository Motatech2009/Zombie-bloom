extends "res://scripts/entities/zombie.gd"
var field_enemy: bool = false
var encounter_index: int = -1

func _ready() -> void:
	super._ready()
	if spec.id == "armored":
		VisualFactory.box(rig, Vector3(.7,.65,.42), Vector3(0,1.25,0), Color("3f5261"))
	if spec.id == "demolisher":
		VisualFactory.box(rig, Vector3(.95,.35,.5), Vector3(0,1.5,0), Color("8a3e32"))
		VisualFactory.ring(self, .8, Vector3(0,.07,0), Color("df9974"))

func choose_target() -> void:
	if field_enemy:
		target = world.player
	else:
		super.choose_target()
		if spec.id == "demolisher":
			target = world.core

func take_damage(amount: float) -> void:
	super.take_damage(amount * .6 if spec.id == "armored" else amount)
