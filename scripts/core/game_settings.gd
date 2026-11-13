class_name GameSettings
extends RefCounted
static var volume: float = .65
static var shadows: bool = true

static func load_settings() -> void:
	shadows = not MobilePlatform.enabled()
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		volume = clampf(float(config.get_value("audio", "volume", .65)), 0, 1)
		shadows = bool(config.get_value("graphics", "shadows", shadows))
	apply_audio()

static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("graphics", "shadows", shadows)
	config.save("user://settings.cfg")
	apply_audio()

static func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(.0001, volume)))
