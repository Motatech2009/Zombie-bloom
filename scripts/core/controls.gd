class_name Controls
extends RefCounted

static func setup() -> void:
	if not InputMap.has_action("roll"):
		InputMap.add_action("roll")
		var roll_key := InputEventKey.new()
		roll_key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("roll",roll_key)
	var bindings := {"melee": KEY_T, "move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "reload": KEY_R, "interact": KEY_E, "build": KEY_B, "equipment": KEY_TAB, "pause": KEY_ESCAPE, "slot_1": KEY_1, "slot_2": KEY_2, "slot_3": KEY_3, "start_wave": KEY_SPACE, "sprint": KEY_SHIFT, "sector_map": KEY_M, "vendor": KEY_V, "rotate_piece": KEY_Q, "upgrade_piece": KEY_G, "remove_piece": KEY_X, "use_gate": KEY_F, "save_campaign": KEY_F5, "load_campaign": KEY_F9, "slot_4": KEY_4, "slot_5": KEY_5, "slot_6": KEY_6, "grenade": KEY_C, "hud_hints": KEY_H, "inventory": KEY_I, "slot_7": KEY_7, "slot_8": KEY_8, "slot_9": KEY_9, "slot_10": KEY_0}
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
