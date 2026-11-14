class_name GameSettings
extends RefCounted
static var volume: float = .65
static var shadows: bool = true
static var mobile_performance: bool = true
static var fullscreen: bool = true
static var windowed_rect := Rect2i()

static func load_settings() -> void:
	shadows = not MobilePlatform.enabled()
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		volume = clampf(float(config.get_value("audio", "volume", .65)), 0, 1)
		shadows = bool(config.get_value("graphics", "shadows", shadows))
		mobile_performance = bool(config.get_value("graphics", "mobile_performance", true))
		fullscreen = bool(config.get_value("graphics", "fullscreen", true))
	apply_audio()

static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("graphics", "shadows", shadows)
	config.set_value("graphics", "mobile_performance", mobile_performance)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.save("user://settings.cfg")
	apply_audio()

static func use_shadows() -> bool:
	return shadows and not MobilePlatform.lightweight()

static func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(.0001, volume)))

static func apply_display(window: Window) -> void:
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if DisplayServer.get_name()=="headless": return
	if OS.has_feature("mobile"):
		window.mode = Window.MODE_FULLSCREEN
	elif fullscreen:
		if window.mode==Window.MODE_WINDOWED: windowed_rect = Rect2i(window.position,window.size)
		# Size the drawable area as well, including desktops without a window manager.
		window.size = DisplayServer.screen_get_size(window.current_screen)
		window.position = DisplayServer.screen_get_position(window.current_screen)
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		if windowed_rect.has_area(): window.position = windowed_rect.position; window.size = windowed_rect.size
