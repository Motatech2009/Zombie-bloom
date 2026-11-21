extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.load_settings()
	GameSettings.apply_display(get_tree().root)

func _input(event: InputEvent) -> void:
	if OS.has_feature("mobile") or not event is InputEventKey: return
	if event.pressed and not event.echo and event.physical_keycode==KEY_F11:
		GameSettings.fullscreen = not GameSettings.fullscreen
		GameSettings.save_settings(); GameSettings.apply_display(get_tree().root)
		get_viewport().set_input_as_handled()
