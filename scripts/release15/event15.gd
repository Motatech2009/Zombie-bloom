extends StaticBody3D
var world: Node3D
var event_key = ""
var kind = "nest"
var health = Health.new()
var label: Label3D
func _ready() -> void:
	add_child(health); health.setup(240 if kind=="nest" else 100)
	if kind=="nest":
		collision_layer = 4; add_to_group("damageable"); health.died.connect(func(): world.v15.destroy_nest(event_key))
		VisualFactory.collider(self,Vector3(2.4,2.2,2.4),Vector3(0,1,0))
		for i in range(4): VisualFactory.cylinder(self,.6,1.5,Vector3((i%2-.5)*1.1,.7,(i/2-.5)*1.1),Color("a278c5"))
	elif kind=="convoy":
		collision_layer = 1; VisualFactory.collider(self,Vector3(3,2,5),Vector3(0,1,0))
		VisualFactory.box(self,Vector3(3,2,5),Vector3(0,1,0),Color("697c81")); VisualFactory.box(self,Vector3(2.8,1.2,1.2),Vector3(0,1,-3),Color("9eab7b"))
	else:
		collision_layer = 0
		VisualFactory.human(self,Color("a5b897"),true)
	label = VisualFactory.health_label(self,2.8); label.text = {"nest":"NINHO DE ESPOROS · destrua","convoy":"COMBOIO · E inicia defesa de 45 s","escort":"SOBREVIVENTE · E para escoltar"}.get(kind,kind)
func take_damage(amount: float) -> void:
	if kind=="nest": health.take_damage(amount)
