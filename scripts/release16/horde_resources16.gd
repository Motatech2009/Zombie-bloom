class_name HordeResources16
extends ResourceManager

# Keep historical XP/level and loot accounting, but only a completed horde
# grants a character choice in 1.6. No XP signal may open a shared modal.
func add_loot(experience: int, metal: int) -> void:
	xp += maxi(0,experience)
	scrap += maxi(0,metal)
	while xp>=threshold():
		xp -= threshold()
		level += 1
