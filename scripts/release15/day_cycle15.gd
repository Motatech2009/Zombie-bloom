class_name DayCycle15
extends RefCounted
const HALF := 900.0
var clock = 0.0
var blood = false
var cycle = 0
var world: Node3D
var visual_clock = 0.0
func night() -> bool: return fposmod(clock,HALF*2)>=HALF
func hp_factor() -> float: return 1.5 if blood and night() else 1.3 if night() else 1.0
func damage_factor() -> float: return 1.3 if blood and night() else 1.0
func tick(delta: float) -> void:
	var was = night(); clock += delta
	if not was and night():
		blood = world.world_rng.randf()<.25; cycle += 1
		world.notify("NOITE VERMELHA · vida +50%, dano +30%!" if blood else "ANOITECEU · infectados com +30% de vida e maior percepção.")
		if blood: world.audio.play_tone(110,.8,.2)
	elif was and not night(): blood = false; world.notify("AMANHECEU · modificadores noturnos encerrados.")
	visual_clock -= delta
	if visual_clock<=0:
		visual_clock = .25
		for enemy in world.get_tree().get_nodes_in_group("enemies"): apply_enemy(enemy)
		apply_light()
func apply_enemy(enemy: Node3D) -> void:
	var old: float = enemy.get_meta("night_hp",1.0)
	var desired = hp_factor()
	if not is_equal_approx(old,desired):
		var fraction: float = enemy.health.current/maxf(1,enemy.health.maximum)
		enemy.health.maximum = enemy.health.maximum/old*desired; enemy.health.current = enemy.health.maximum*fraction
		enemy.set_meta("night_hp",desired)
	var previous: float = enemy.get_meta("night_damage",1.0)
	enemy.spec.values.damage = float(enemy.spec.values.damage)/previous*damage_factor()
	enemy.set_meta("night_damage",damage_factor())
func apply_light() -> void:
	if not is_instance_valid(world.sunlight): return
	var phase = fposmod(clock,1800.0)
	var darkness = smoothstep(840,960,phase)*(1-smoothstep(1740,1800,phase))
	if "darkness" in world.v15.mutators: darkness = 1
	world.sunlight.light_energy = lerpf(1.0,.23,darkness)
	for child in world.get_children():
		if child is WorldEnvironment:
			child.environment.background_color = Color("091a22").lerp(Color("49151e") if blood else Color("070d22"),darkness)
	world.sunlight.light_color = Color("f4edd6").lerp(Color("f15d59") if blood else Color("839bc9"),darkness)
func dump() -> Dictionary: return {"clock":clock,"blood":blood,"cycle":cycle}
func restore(data: Dictionary) -> void:
	clock = float(data.get("clock",0)); blood = bool(data.get("blood",false)); cycle = int(data.get("cycle",0)); apply_light()
static func valid(data: Variant) -> bool:
	return data is Dictionary and SectorMemory.number(data.get("clock"),0,1e9) and data.get("blood") is bool and SectorMemory.number(data.get("cycle"),0,1e7,true)
