extends Node3D
var world: Node3D
var director: AirdropDirector
var cargo: Node3D
var label: Label3D
func _ready() -> void:
	if not world.is_client: add_to_group("survival_sources")
	cargo = load("res://assets/fortress/airdrop.tscn").instantiate(); add_child(cargo)
	ClayStyle.apply_tree(cargo)
	cargo.position.y = 24*pow(float(director.state.land)/AirdropDirector.LANDING,1.5)
	VisualFactory.ring(self,2,Vector3(0,.12,0),Color("e8b565"))
	label = VisualFactory.health_label(self,3)
	label.font_size = 32; label.pixel_size = .021
func _process(delta: float) -> void:
	if director.state.is_empty(): hide(); return
	var land: float = director.state.land
	var altitude := 24*pow(land/AirdropDirector.LANDING,1.5)
	cargo.position.y = lerpf(cargo.position.y,altitude,minf(1,delta*12)) if world.is_client else altitude
	cargo.get_node("Parachute").visible = land>0
	label.text = "AIRDROP DESCENDO" if land>0 else "AIRDROP · %d GUARDAS" % director.remaining() if director.remaining()>0 else "SEGURE E · SUPRIMENTOS"
	label.visible = global_position.distance_to(world.player.position)<28
	visible = not director.state.collected
