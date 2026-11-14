class_name MobilePlatform
extends RefCounted
static var force_touch: bool = false
static var active_performance: bool = true
static func lightweight() -> bool:
	return enabled() and active_performance
static func enabled() -> bool:
	return force_touch or OS.has_feature("android") or OS.has_feature("ios") or "--touch" in OS.get_cmdline_user_args()
static func configure(window: Window) -> void:
	if not enabled(): return
	active_performance = GameSettings.mobile_performance
	window.get_tree().auto_accept_quit = false
	window.content_scale_size = Vector2i(960,540)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.scaling_3d_scale = .85 if lightweight() else 1.0
	if OS.has_feature("mobile"): Engine.max_fps = 30

static func apply_quality(world: Node3D) -> void:
	configure(world.get_tree().root)
	ClayStyle.refresh_tree(world)
	for enemy in world.get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("refresh_quality"): enemy.refresh_quality()
	world.sunlight.shadow_enabled = GameSettings.use_shadows()
