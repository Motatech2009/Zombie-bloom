class_name BetaInteraction
extends WorldInteraction

func _ready() -> void:
	super._ready()
	if kind == "record":
		VisualFactory.box(model, Vector3(.55, .08, .4), Vector3(0, .45, 0), Color("e6c48d"), true)
	elif kind == "window":
		window_visual()
	elif kind in ["container", "salvage"]:
		world.container_for(id, str(data.get("context", world.current_house.get("kind", "field"))))

func available() -> bool:
	return true if kind in ["container", "salvage", "record", "window"] else super.available()

func prompt() -> String:
	match kind:
		"entry": return "E · Entrar em " + str(data.get("title", "edifício"))
		"exit": return "E · Voltar ao mundo"
		"door": return "E · Fechar porta" if opened else "E · Abrir porta"
		"container", "salvage": return "E · Vasculhar recipiente"
		"record": return "E · Ler registro recuperado"
		"window": return "E · " + ("Quebrar janela" if window_state() == "intact" else "Barricar (2 madeira + 1 sucata)" if window_state() == "broken" else "Retirar barricada")
	if kind == "tree" and world.inventory.count("axe") == 0:
		return "Madeira · Requer machado na mochila"
	return "SEGURE E · Extrair %s%s" % ["madeira" if kind == "tree" else "pedra", " · %d%%" % int(progress / 1.6 * 100) if progress > 0 else ""]

func use() -> void:
	if kind in ["container", "salvage"]:
		world.hud.show_loot(world.container_for(id, str(data.get("context", world.current_house.get("kind", "field")))), id)
	elif kind == "record":
		world.read_record(str(data.get("record", "house")))
	elif kind == "window":
		var current := window_state()
		if current == "broken":
			if world.inventory.count("wood") < 2 or world.inventory.count("scrap") < 1:
				world.notify("Barricar requer 2 madeira e 1 sucata.")
				return
			world.inventory.remove("wood", 2)
			world.inventory.remove("scrap", 1)
		world.state.changes[id] = {"window": "broken" if current == "barricaded" else "barricaded" if current == "broken" else "broken"}
		window_visual()
		world.make_noise(global_position, 18 if current == "intact" else 7)
	else:
		super.use()

func extract(delta: float) -> int:
	if kind not in ["tree", "rock"] or units <= 0 or (kind == "tree" and world.inventory.count("axe") == 0):
		return 0
	progress += delta
	if progress < 1.6:
		return 0
	progress = 0
	var id_type := "wood" if kind == "tree" else "stone"
	var accepted: int = world.inventory.add(id_type, mini(3, units))
	if accepted <= 0:
		world.notify("Não cabe mais: confira peso absoluto e slots da mochila.")
		return 0
	units -= accepted
	world.state.changes[id] = {"units": units}
	world.make_noise(global_position, 12)
	world.audio.play_tone(220 if kind == "tree" else 470, .07, .1)
	refresh()
	world.outdoor.navigation_dirty = true
	return accepted

func window_state() -> String:
	return str(world.state.changes.get(id, {}).get("window", "intact"))

func window_visual() -> void:
	for child in model.get_children():
		child.queue_free()
	var current := window_state()
	if current == "intact":
		VisualFactory.box(model, Vector3(1.7, 1, .08), Vector3(0, 1.6, 0), Color("80bec6"))
	elif current == "broken":
		VisualFactory.box(model, Vector3(.4, .35, .1), Vector3(-.6, 1.8, 0), Color("6b98a0"))
	else:
		for y in [1.2, 1.6, 2.0]:
			VisualFactory.box(model, Vector3(1.8, .24, .15), Vector3(0, y, 0), Color("a08b60"))
