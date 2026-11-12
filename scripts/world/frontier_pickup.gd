extends "res://scripts/entities/pickup.gd"

func collect() -> void:
	if collected:
		return
	if scrap > 0:
		var accepted: int = world.state.put_cargo("metal", scrap)
		if accepted <= 0:
			return
		scrap -= accepted
		if scrap > 0:
			return
	collected = true
	world.resources.add_loot(xp, 0)
	if not power.is_empty():
		world.player.grant_power(power)
	queue_free()
