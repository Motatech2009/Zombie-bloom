extends "res://scripts/campaign/campaign_build.gd"

func can_place(pos: Vector3,check_access: bool = true) -> bool:
	if world.built_this_round>=world.build_quota():
		reason = "Limite desta preparação: %d/%d peças. Vença a horda para renovar." % [world.built_this_round,world.build_quota()]
		return false
	return super.can_place(pos,check_access)

func place() -> Node3D:
	if world.is_client:
		world.send_action("build",{"pos":location,"angle":angle,"piece":selected})
		return null
	var result := super.place()
	if result!=null: world.built_this_round += 1
	return result

func piece_specs() -> Array: return FortressData.pieces()
func structure_script() -> Script: return load("res://scripts/fortress/fortress_structure.gd")
