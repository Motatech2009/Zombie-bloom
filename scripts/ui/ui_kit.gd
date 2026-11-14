class_name UI
extends RefCounted
const INK := Color("0b1921")
const CARD := Color("15282e")
const LIME := Color("d4f889")
const TEXT := Color("edf2e8")
const MUTED := Color("90aaa7")

static func style(color: Color = CARD, border: Color = Color("354b4e"), radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

static func theme() -> Theme:
	var data := Theme.new()
	data.default_font_size = 17
	data.set_color("font_color", "Label", TEXT)
	data.set_color("font_color", "Button", TEXT)
	data.set_color("font_hover_color", "Button", INK)
	data.set_color("font_pressed_color", "Button", INK)
	data.set_stylebox("normal", "Button", style(Color("21383e")))
	data.set_stylebox("hover", "Button", style(LIME, LIME))
	data.set_stylebox("pressed", "Button", style(Color("a8d05f"), LIME))
	data.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), LIME))
	data.set_stylebox("panel", "PanelContainer", style())
	data.set_stylebox("background", "ProgressBar", style(Color("293f43"), Color("293f43"), 3))
	data.set_stylebox("fill", "ProgressBar", style(LIME, LIME, 3))
	return data

static func label(parent: Node, text: String, size: int = 17, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 48
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		node.add_theme_stylebox_override("normal", style(LIME, LIME))
		node.add_theme_color_override("font_color", INK)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

static func vbox(parent: Node, separation: int = 12) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func hbox(parent: Node, separation: int = 12) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func panel(parent: Node) -> PanelContainer:
	var node := PanelContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func meter(parent: Node, color: Color = LIME) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(100, 6)
	var background := style(Color("293f43"), Color("293f43"), 3)
	var fill_style := style(color, color, 3)
	for resource in [background, fill_style]:
		resource.content_margin_left = 0
		resource.content_margin_right = 0
		resource.content_margin_top = 0
		resource.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(bar)
	return bar

static func spacer(parent: Node, height: float = 10) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func settings(parent: Node, on_change: Callable) -> void:
	label(parent, "ÁUDIO", 13, MUTED)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = .05
	slider.value = GameSettings.volume
	slider.custom_minimum_size = Vector2(360, 40)
	parent.add_child(slider)
	slider.value_changed.connect(func(value: float): GameSettings.volume = value; GameSettings.save_settings())
	label(parent,"TRILHA SONORA",13,MUTED)
	var music := HSlider.new(); music.min_value = 0; music.max_value = 1; music.step = .05; music.value = GameSettings.music_volume; music.custom_minimum_size = Vector2(360,40); parent.add_child(music)
	music.value_changed.connect(func(value: float): GameSettings.music_volume = value; GameSettings.save_settings())
	var check := CheckButton.new()
	check.text = "Sombras dinâmicas"
	check.button_pressed = GameSettings.shadows
	parent.add_child(check)
	check.toggled.connect(func(value: bool): GameSettings.shadows = value; GameSettings.save_settings(); on_change.call())
	label(parent, "Desative sombras para reduzir o custo gráfico.", 14, MUTED)
	if not MobilePlatform.enabled():
		var screen := CheckButton.new()
		screen.text = "Tela cheia / F11"
		screen.button_pressed = GameSettings.fullscreen
		parent.add_child(screen)
		screen.toggled.connect(func(value: bool): GameSettings.fullscreen = value; GameSettings.save_settings(); GameSettings.apply_display(parent.get_tree().root))
	if MobilePlatform.enabled():
		var lean := CheckButton.new()
		lean.text = "Modo leve / celular"
		lean.button_pressed = GameSettings.mobile_performance
		parent.add_child(lean)
		lean.toggled.connect(func(value: bool): GameSettings.mobile_performance = value; GameSettings.save_settings(); on_change.call())
		label(parent,"Modo leve reduz detalhes, efeitos e resolução 3D. Sombras ficam desligadas.\nA qualidade muda agora, sem reiniciar. Detalhado restaura texturas e resolução.",14,MUTED)
