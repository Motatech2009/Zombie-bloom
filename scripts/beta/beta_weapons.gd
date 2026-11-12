class_name BetaWeapons
extends WeaponSystem
const AMMO_TYPES := ["ammo9", "shell", "ammo9"]

func _process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if reload_left > 0:
		reload_left = maxf(0, reload_left - delta)
		if reload_left == 0:
			var amount: int = mini(capacity() - ammo[slot], world.inventory.count(AMMO_TYPES[slot]))
			if amount > 0 and world.inventory.remove(AMMO_TYPES[slot], amount):
				ammo[slot] += amount
	sync_mass()

func reload() -> bool:
	if actor.tool == "axe" or reload_left > 0 or ammo[slot] >= capacity() or world.inventory.count(AMMO_TYPES[slot]) <= 0:
		world.notify("Sem munição compatível para recarregar." if actor.tool != "axe" else "Machado não precisa de munição.")
		return false
	reload_total = maxf(.2, float(spec().values.reload) * reload_multiplier)
	reload_left = reload_total
	return true

func shoot(direction: Vector3) -> bool:
	if actor.tool == "axe":
		return melee(direction)
	if world.inventory.count(actor.tool) <= 0:
		world.notify("Equipe uma arma pela barra rápida.")
		return false
	var result := super.shoot(direction)
	if result:
		sync_mass()
		world.make_noise(actor.global_position, 48 if slot == 1 else 38)
	return result

func melee(direction: Vector3) -> bool:
	if cooldown > 0 or world.inventory.count("axe") <= 0:
		return false
	cooldown = .65
	var hit_any := false
	for enemy in world.get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - actor.global_position
		offset.y = 0
		if offset.length() > 2.35 or offset.normalized().dot(direction) < .55:
			continue
		var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP, enemy.global_position + Vector3.UP, 1 | 4 | 8, [actor.get_rid()])
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == enemy:
			enemy.take_damage(32)
			hit_any = true
	world.make_noise(actor.global_position, 9)
	world.effects.burst(actor.global_position + direction * 1.3 + Vector3.UP, Color("d8c5a1"), 3)
	world.audio.play_tone(130, .08, .08)
	fired.emit()
	return hit_any

func sync_mass() -> void:
	world.inventory.loaded_mass = (ammo[0] + ammo[2]) * float(BetaCatalog.item("ammo9").weight) + ammo[1] * float(BetaCatalog.item("shell").weight)
