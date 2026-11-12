class_name BetaCrafting
extends RefCounted
var world: Node3D
var last_craft: int = -1000
var reason: String = ""

func can_craft(id: String) -> bool:
	var recipe := BetaCatalog.recipe(id)
	if recipe.is_empty():
		reason = "Receita inexistente."
		return false
	if recipe.station == "bench" and not world.near_station("workbench"):
		reason = "Requer bancada próxima (4 m)."
		return false
	var inventory: BetaInventory = world.inventory.copy()
	for material: String in recipe.cost:
		if not inventory.remove(material, int(recipe.cost[material])):
			reason = "Falta " + BetaCatalog.title(material)
			return false
	if inventory.add(recipe.output, int(recipe.amount)) != int(recipe.amount):
		reason = "Saída não cabe na mochila. Libere slots ou peso."
		return false
	reason = "Pronto para fabricar."
	return true

func craft(id: String, guard_double_click: bool = true) -> bool:
	if guard_double_click and Time.get_ticks_msec() - last_craft < 250:
		reason = "Aguarde a fabricação anterior."
		return false
	if not can_craft(id):
		return false
	var recipe := BetaCatalog.recipe(id)
	var next: BetaInventory = world.inventory.copy()
	for material: String in recipe.cost:
		next.remove(material, int(recipe.cost[material]))
	next.add(recipe.output, int(recipe.amount))
	world.inventory.assign(next)
	last_craft = Time.get_ticks_msec()
	world.make_noise(world.player.global_position, 7)
	return true
