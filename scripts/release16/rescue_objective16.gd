extends StaticBody3D
var director: RefCounted
var health := Health.new()
func _ready() -> void:
	collision_layer = 8; collision_mask = 0
	VisualFactory.collider(self,Vector3(2,2,2),Vector3(0,1,0))
	add_child(health); health.setup(director.goal_hp); add_to_group("damageable")
	health.died.connect(func(): director.world.finish(false,"A estação foi destruída antes da extração."))
func take_damage(amount: float) -> void:
	if director.world.is_client or not director.defending(): return
	health.take_damage(amount); director.goal_hp = maxf(0,health.current)
