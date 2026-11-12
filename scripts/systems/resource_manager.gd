class_name ResourceManager
extends Node
signal level_earned
var scrap: int = 140
var xp: int = 0
var level: int = 1
var pending: int = 0

func threshold() -> int:
	return 28 + (level - 1) * 18

func spend(amount: int) -> bool:
	if amount < 0 or scrap < amount:
		return false
	scrap -= amount
	return true

func add_loot(experience: int, metal: int) -> void:
	xp += maxi(0, experience)
	scrap += maxi(0, metal)
	while xp >= threshold():
		xp -= threshold()
		level += 1
		pending += 1
	if pending > 0:
		level_earned.emit()
