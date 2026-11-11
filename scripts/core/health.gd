class_name Health
extends Node
## Single damage contract used by player, enemies and buildings.
signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal died
var maximum: float = 100.0
var current: float = 100.0
var dead: bool = false

func setup(value: float) -> void:
	maximum = value
	current = value
	dead = false
	changed.emit(current, maximum)

func take_damage(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	current = maxf(0.0, current - amount)
	damaged.emit(amount)
	changed.emit(current, maximum)
	if current == 0.0:
		dead = true
		died.emit()

func heal(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var recovered := minf(amount, maximum - current)
	current += recovered
	changed.emit(current, maximum)
	return recovered
