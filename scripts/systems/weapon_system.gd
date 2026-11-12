class_name WeaponSystem
extends Node
signal fired
var actor: Node3D
var world: Node3D
var owned: Array[bool] = [true, true, true]
var slot: int = 0
var ammo: Array[int] = [12, 6, 30]
var cooldown: float = 0.0
var reload_left: float = 0.0
var reload_total: float = 0.0
var damage_multiplier: float = 1.0
var rate_multiplier: float = 1.0
var capacity_multiplier: float = 1.0
var reload_multiplier: float = 1.0
var level: int = 1

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if reload_left > 0:
		reload_left = maxf(0.0, reload_left - delta)
		if reload_left == 0:
			ammo[slot] = capacity()

func spec() -> Resource:
	return Catalog.WEAPONS[slot]

func capacity(index: int = -1) -> int:
	return maxi(1, ceili(float(Catalog.WEAPONS[slot if index < 0 else index].values.capacity) * capacity_multiplier))

func equip(index: int) -> void:
	if index < 0 or index >= Catalog.WEAPONS.size() or not owned[index] or index == slot:
		return
	slot = index
	reload_left = 0.0
	# Switching cannot bypass the previous gun's cooldown.
	cooldown = maxf(cooldown, .12)

func reload() -> bool:
	if reload_left > 0 or ammo[slot] == capacity():
		return false
	reload_total = maxf(.2, float(spec().values.reload) * reload_multiplier)
	reload_left = reload_total
	return true

func shoot(direction: Vector3) -> bool:
	if cooldown > 0 or reload_left > 0 or not is_instance_valid(actor) or not owned[slot]:
		return false
	if ammo[slot] <= 0:
		reload()
		return false
	var data: Dictionary = spec().values
	ammo[slot] -= 1
	var rapid: float = 1.65 if actor.power_left("rapid") > 0 else 1.0
	cooldown = maxf(.04, float(data.interval) / (rate_multiplier * rapid))
	var origin := actor.global_position + Vector3(0, 1.15, 0)
	for i in range(int(data.pellets)):
		var spread := direction.rotated(Vector3.UP, randf_range(-float(data.spread), float(data.spread)))
		var end := origin + spread * float(data.range)
		var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 4 | 8, [actor.get_rid()])
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit.position
			if hit.collider.is_in_group("enemies"):
				hit.collider.take_damage(float(data.damage) * damage_multiplier)
			world.effects.burst(end, Color("b4cd8c"), 2)
		world.effects.tracer(origin + direction * .65, end, spec().color)
	world.effects.flash(origin + direction * .9)
	world.audio.play_tone(230 if slot == 0 else 120 if slot == 1 else 340, .07, .12)
	fired.emit()
	return true
