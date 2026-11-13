class_name MobilePlatform
extends RefCounted
static var force_touch: bool = false
static func enabled() -> bool:
	return force_touch or OS.has_feature("android") or OS.has_feature("ios") or "--touch" in OS.get_cmdline_user_args()
static func configure(window: Window) -> void:
	if not enabled(): return
	window.get_tree().auto_accept_quit = false
	window.content_scale_size = Vector2i(960,540)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if OS.has_feature("mobile"): Engine.max_fps = 30
