extends Node3D
var phase: float = 0
var speed: float = 1
var amplitude: float = .06
var spin: bool = false
var clock: float = 0
func _process(delta: float) -> void:
	clock += delta
	if spin: rotation.z = fposmod(clock*speed+phase,TAU)
	else: rotation.z = sin(clock*speed+phase)*amplitude
