class_name Controls
extends RefCounted

static func setup() -> void:
	var bindings := {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "reload": KEY_R, "interact": KEY_E, "build": KEY_B, "equipment": KEY_TAB, "pause": KEY_ESCAPE, "slot_1": KEY_1, "slot_2": KEY_2, "slot_3": KEY_3, "start_wave": KEY_SPACE, "sprint": KEY_SHIFT, "field_use": KEY_F, "world_map": KEY_M, "save_world": KEY_F5, "load_world": KEY_F9, "upgrade_defense": KEY_U}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mouse)
