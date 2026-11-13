extends Node3D
var world: Node3D
var uid: int = 0
var contents: Dictionary = {}
var experience: int = 0
var power: String = ""
var loaded: int = 0
var model: Node3D
var shown_item: String = ""
var pickup_left: float = .12
var rare: bool = false

func _ready() -> void:
	add_to_group("survival_loot")
	refresh_model()

func refresh_model() -> void:
	var next: String = str(contents.keys()[0]) if not contents.is_empty() else "cells"
	if next==shown_item: return
	shown_item = next
	if is_instance_valid(model): remove_child(model); model.queue_free()
	model = load("res://assets/models/"+("weapon_" if next in ItemBag.WEAPON_IDS else "item_")+next+".tscn").instantiate()
	add_child(model)
	model.position.y = .12

func _process(delta: float) -> void:
	refresh_model()
	model.rotation.y += delta*.4
	if not world.is_client and get_meta("auto",true) and world.phase!="ended":
		pickup_left -= delta
		if pickup_left<=0:
			pickup_left = .12
			var nearby: Array = world.avatars.values().filter(func(actor): return not actor.health.dead and actor.global_position.distance_to(global_position)<1.65)
			nearby.sort_custom(func(a,b): return a.global_position.distance_squared_to(global_position)<b.global_position.distance_squared_to(global_position))
			for actor in nearby:
				if world.collect_ground(actor,self): break
	if contents.is_empty() and int(get_meta("xp",0))==0 and str(get_meta("power","")).is_empty() and not world.is_client: queue_free()
