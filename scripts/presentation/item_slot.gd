class_name ItemSlot
extends Button
var item_icon: TextureRect
var key_label: Label
var quantity_label: Label
var shown: String = "?"
var shown_qty: int = -1
var highlighted: bool = false
var key_number: int = 0
var normal_frame: StyleBoxFlat
var selected_frame: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(74,84)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item_icon = ItemIcons.image(self,"",Vector2.ZERO)
	UI.fill(item_icon)
	item_icon.offset_left = 11; item_icon.offset_right = -11
	item_icon.offset_top = 14; item_icon.offset_bottom = -13
	key_label = UI.label(self,str(key_number) if key_number>0 else "",11,UI.MUTED)
	key_label.position = Vector2(7,3)
	quantity_label = UI.label(self,"",14,Color("f2e9cf"))
	quantity_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	quantity_label.offset_left = -42; quantity_label.offset_right = -6
	quantity_label.offset_top = -22; quantity_label.offset_bottom = -3
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	normal_frame = UI.style(Color("10232d"),Color("3a505a"),8)
	selected_frame = UI.style(Color("2d3b35"),Color("edbd72"),8)
	selected_frame.set_border_width_all(2)
	for style in [normal_frame,selected_frame]:
		style.content_margin_left = 2; style.content_margin_right = 2
		style.content_margin_top = 2; style.content_margin_bottom = 2
	add_theme_stylebox_override("normal",normal_frame)
	add_theme_stylebox_override("hover",UI.style(Color("304a50"),Color("d2dda5"),8))
	add_theme_stylebox_override("pressed",selected_frame)
	add_theme_stylebox_override("focus",UI.style(Color(0,0,0,0),Color("6c9aa3"),8))
	set_item("",0,false)

func set_item(id: String,quantity: int,selected: bool) -> void:
	if not is_instance_valid(item_icon): return
	if shown!=id:
		shown = id
		item_icon.texture = ItemIcons.get_icon(id)
		tooltip_text = ItemBag.TITLES.get(id,"Espaço livre")
	if shown_qty!=quantity:
		shown_qty = quantity
		quantity_label.text = str(quantity) if quantity>1 else ""
	if highlighted!=selected:
		highlighted = selected
		add_theme_stylebox_override("normal",selected_frame if selected else normal_frame)
