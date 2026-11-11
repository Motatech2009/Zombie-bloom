class_name UpgradeManager
extends Node
var world: Node3D
var levels: Dictionary = {}
var offers: Array = []

func roll() -> Array:
	offers = Catalog.UPGRADES.duplicate()
	offers.shuffle()
	offers = offers.slice(0, 3)
	return offers

func choose(index: int) -> bool:
	if world.resources.pending <= 0 or index < 0 or index >= offers.size():
		return false
	var id: String = offers[index].id
	# Consume the offer before applying it. Duplicate clicks cannot buy two upgrades.
	offers.clear()
	world.resources.pending -= 1
	levels[id] = int(levels.get(id, 0)) + 1
	var weapon: WeaponSystem = world.player.weapons
	match id:
		"damage": weapon.damage_multiplier *= 1.2
		"rate": weapon.rate_multiplier *= 1.15
		"capacity": weapon.capacity_multiplier *= 1.25
		"reload": weapon.reload_multiplier *= .85
		"speed": world.player.speed_multiplier *= 1.1
		"health":
			world.player.health.maximum += 25
			world.player.health.heal(25)
	weapon.level += 1
	world.audio.play_tone(740, .18, .12)
	return true
