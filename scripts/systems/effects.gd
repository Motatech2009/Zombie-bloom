class_name Effects
extends Node3D
var active: int = 0
const LIMIT := 80

func tracer(from: Vector3, to: Vector3, color: Color = Color("eaf4a5")) -> void:
	if active >= LIMIT or from.distance_to(to) < .01:
		return
	active += 1
	var beam := VisualFactory.box(self, Vector3(.035, .035, from.distance_to(to)), (from + to) * .5, color, true)
	beam.look_at(to)
	var tween := create_tween()
	tween.tween_property(beam, "scale", Vector3(.1, .1, 1), .085)
	tween.tween_callback(func(): beam.queue_free(); active -= 1)

func burst(pos: Vector3, color: Color, count: int = 5) -> void:
	for i in range(mini(count, LIMIT - active)):
		active += 1
		var bit := VisualFactory.box(self, Vector3.ONE * randf_range(.07, .16), pos, color, true)
		var target := pos + Vector3(randf_range(-.9, .9), randf_range(.2, .9), randf_range(-.9, .9))
		var tween := create_tween().set_parallel(true)
		tween.tween_property(bit, "position", target, .3)
		tween.tween_property(bit, "scale", Vector3.ZERO, .32)
		tween.chain().tween_callback(func(): bit.queue_free(); active -= 1)

func flash(pos: Vector3) -> void:
	burst(pos, Color("fff3a4"), 2)
