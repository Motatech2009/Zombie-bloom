class_name BetaOptions
extends RefCounted
static var fog_strength: float = .7
static var shadows: bool = true
static var text_scale: float = 1
static var last_seed: int = 8417
static var resolution_index: int = 0
static var render_scale: float = 1
static var bindings: Dictionary = {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "sprint": KEY_SHIFT, "reload": KEY_R, "beta_interact": KEY_E, "roll": KEY_SPACE, "beta_inventory": KEY_I, "beta_craft": KEY_C, "beta_build": KEY_B, "beta_repair": KEY_F, "beta_rotate": KEY_Q, "beta_light": KEY_L, "world_map": KEY_M, "save_world": KEY_F5, "load_world": KEY_F9}

static func setup() -> void:
	var config := ConfigFile.new()
	if config.load("user://beta_options.cfg") == OK:
		render_scale = clampf(float(config.get_value("graphics", "render_scale", 1)), .5, 1)
		resolution_index = clampi(int(config.get_value("graphics", "resolution", 0)), 0, 2)
		last_seed = int(config.get_value("world", "last_seed", 8417))
		fog_strength = clampf(config.get_value("graphics", "fog", .7), 0, 1)
		shadows = bool(config.get_value("graphics", "shadows", true))
		text_scale = clampf(config.get_value("ui", "text_scale", 1), 1, 1.25)
		for action in bindings:
			bindings[action] = int(config.get_value("keys", action, bindings[action]))
	apply_keys()

static func apply_keys() -> void:
	Controls.setup()
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = int(bindings[action])
		InputMap.action_add_event(action, event)
	for i in range(1, 7):
		var action := "beta_slot_%d" % i
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = KEY_0 + i
			InputMap.action_add_event(action, event)

static func rebind(action: String, key: int) -> bool:
	if not bindings.has(action) or key < 32 or key == KEY_ESCAPE or (key >= KEY_1 and key <= KEY_6):
		return false
	for other in bindings:
		if other != action and bindings[other] == key:
			return false
	bindings[action] = key
	apply_keys()
	save()
	return true

static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "resolution", resolution_index)
	config.set_value("world", "last_seed", last_seed)
	config.set_value("graphics", "fog", fog_strength)
	config.set_value("graphics", "shadows", shadows)
	config.set_value("ui", "text_scale", text_scale)
	for action in bindings:
		config.set_value("keys", action, bindings[action])
	config.save("user://beta_options.cfg")

static func action_title(action: String) -> String:
	return {"move_up": "Avançar", "move_down": "Descer", "move_left": "Esquerda", "move_right": "Direita", "sprint": "Correr", "reload": "Recarregar", "beta_interact": "Interagir", "roll": "Rolar", "beta_inventory": "Inventário", "beta_craft": "Fabricação", "beta_build": "Construção", "beta_repair": "Reparar", "beta_rotate": "Girar peça", "beta_light": "Lanterna", "world_map": "Mapa", "save_world": "Salvar", "load_world": "Restaurar"}.get(action, action)

static func key_hint(action: String) -> String:
	return "Espaço" if bindings[action] == KEY_SPACE else OS.get_keycode_string(bindings[action])
