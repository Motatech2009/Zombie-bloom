class_name GameSettings
extends RefCounted
static var volume: float = .65
static var shadows: bool = true
static var mobile_performance: bool = true

static func load_settings() -> void:
	shadows = not MobilePlatform.enabled()
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		volume = clampf(float(config.get_value("audio", "volume", .65)), 0, 1)
		shadows = bool(config.get_value("graphics", "shadows", shadows))
		mobile_performance = bool(config.get_value("graphics", "mobile_performance", true))
	apply_audio()

static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("graphics", "shadows", shadows)
	config.set_value("graphics", "mobile_performance", mobile_performance)
	config.save("user://settings.cfg")
	apply_audio()

static func use_shadows() -> bool:
	return shadows and not MobilePlatform.lightweight()

static func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(.0001, volume)))
