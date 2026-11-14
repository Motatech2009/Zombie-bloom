class_name ItemIcons
extends RefCounted
static var textures: Dictionary = {}
static func get_icon(id: String) -> Texture2D:
	if id.is_empty(): return null
	if not textures.has(id):
		var path := "res://assets/icons/"+id+".svg"
		textures[id] = load(path) if ResourceLoader.exists(path) else null
	return textures[id]

static func image(parent: Node,id: String,size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = get_icon(id)
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon
