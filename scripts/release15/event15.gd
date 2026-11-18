extends StaticBody3D
var world: Node3D
var event_key = ""
var kind = "nest"
var health = Health.new()
var label: Label3D
var net_id := 0
var aim_height := 1.15
func _ready() -> void:
	add_child(health); health.setup(240 if kind=="nest" else 100)
	if kind=="nest":
		add_to_group("enemy_nests")
		if not world.is_client:
			net_id = world.next_id(); set_meta("uid",net_id)
			health.current = clampf(float(world.v15.event_states.get(event_key,{}).get("hp",240.0)),.001,240)
		collision_layer = 4; add_to_group("damageable"); health.died.connect(func(): world.v15.destroy_nest(event_key))
		VisualFactory.collider(self,Vector3(2.4,2.2,2.4),Vector3(0,1,0))
		for i in range(4): VisualFactory.cylinder(self,.6,1.5,Vector3((i%2-.5)*1.1,.7,(i/2-.5)*1.1),Color("a278c5"))
	elif kind=="convoy":
		collision_layer = 1; VisualFactory.collider(self,Vector3(3,2,5),Vector3(0,1,0))
		add_child(preload("res://assets/scenery/tripo16/comboio/convoy.tscn").instantiate())
	else:
		collision_layer = 0
		VisualFactory.human(self,Color("a5b897"),true)
	label = VisualFactory.health_label(self,2.8); label.text = {"nest":"NINHO DE ESPOROS · destrua","convoy":"COMBOIO · E inicia defesa de 45 s","escort":"SOBREVIVENTE · E para escoltar"}.get(kind,kind)
func take_damage(amount: float) -> void:
	if kind=="nest" and not world.is_client and not health.dead:
		health.take_damage(amount)
		if world.v15.event_states.has(event_key): world.v15.event_states[event_key].hp = health.current
