class_name SporePatch
extends Node

const RADIUS := 3.1
const GERMINATION := .9
const LIFETIME := 7.0
const LINGER_SLOW := 1.25
const MAX_PATCHES := 12

var world: Node3D
var effect: BossFx18
var damage := 0.0
var damage_left := 0.0

static func plant(owner_world: Node3D, point: Vector3, radius: float, power: float) -> void:
	if owner_world.is_client or owner_world.get_tree().get_nodes_in_group("spore_patches").size() >= MAX_PATCHES: return
	var patch := SporePatch.new()
	patch.world = owner_world
	patch.damage = power
	patch.effect = BossFx18.spawn(owner_world, "mushrooms", Vector3(point.x,0,point.z),
		Vector3.ZERO, radius, GERMINATION, LIFETIME)
	patch.effect.add_child(patch)
	patch.add_to_group("spore_patches")

func _physics_process(delta: float) -> void:
	if world.phase == "ended":
		effect.queue_free()
		return
	if world.combat_paused() or effect.elapsed < GERMINATION or effect.elapsed >= LIFETIME: return
	damage_left -= delta
	var pulse := damage_left <= 0.0
	if pulse: damage_left += 1.0
	var point := effect.global_position
	for actor in world.avatars.values():
		if actor.health.dead or actor.roll_left > 0.0: continue
		var offset: Vector3 = actor.global_position - point
		if Vector2(offset.x,offset.z).length_squared() > effect.extent*effect.extent: continue
		if world.exp16.safe(actor.global_position): continue
		actor.slow_left = maxf(actor.slow_left, LINGER_SLOW)
		if pulse: actor.take_damage(damage)
