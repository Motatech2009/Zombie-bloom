extends "res://scripts/survival/survival_hud.gd"
var belt: HBoxContainer
var page: int = 0
var refresh_elapsed: float = 0
var performance_text: Label
var performance_elapsed: float = 0
func _ready() -> void:
	super._ready()
	var controls := TouchControls.new(); controls.world = world; root.add_child(controls)
	world.touch_controls = controls
	if MobilePlatform.lightweight():
		var bars := MobileEnemyBars.new(); bars.world = world; root.add_child(bars); root.move_child(bars,0)
	performance_text = UI.label(root,"",11,UI.MUTED)
	performance_text.position = Vector2(14,108)

func place_panel(panel: Control,preset: int,rect: Rect2) -> void:
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = rect.position.x; panel.offset_top = rect.position.y; panel.offset_right = rect.end.x; panel.offset_bottom = rect.end.y

func create_top() -> void:
	super.create_top()
	place_panel(root.get_child(0),Control.PRESET_TOP_LEFT,Rect2(10,8,236,96))
	place_panel(root.get_child(1),Control.PRESET_CENTER_TOP,Rect2(-120,8,240,80))
	place_panel(root.get_child(2),Control.PRESET_TOP_RIGHT,Rect2(-246,8,236,96))
	for button in root.get_child(2).find_children("*","Button",true,false): button.hide()
	for text in [health_text,core_text,scrap_text,wood_count,parts_count]: text.add_theme_font_size_override("font_size",14)
	wave_text.add_theme_font_size_override("font_size",18)
	wave_detail.add_theme_font_size_override("font_size",12)
	airdrop_text.offset_left = -245; airdrop_text.offset_right = -88; airdrop_text.offset_top = 108; airdrop_text.offset_bottom = 128
	airdrop_text.add_theme_font_size_override("font_size",11)

func create_bottom() -> void:
	super.create_bottom()
	var held: Control = held_icon.get_parent().get_parent()
	place_panel(held,Control.PRESET_CENTER_BOTTOM,Rect2(-172,-144,344,68))
	var style := compact_style(); style.content_margin_top = 6; style.content_margin_bottom = 6
	held.add_theme_stylebox_override("panel",style)
	held_icon.custom_minimum_size = Vector2(36,36)
	weapon_text.hide(); ammo_text.add_theme_font_size_override("font_size",19); power_text.add_theme_font_size_override("font_size",11)
	belt = hotbar[0].get_parent()
	place_panel(belt,Control.PRESET_CENTER_BOTTOM,Rect2(-225,-70,450,62))
	belt.add_theme_constant_override("separation",4)
	for button in hotbar: button.custom_minimum_size = Vector2(66,62)
	var previous := UI.button(belt,"‹",func(): page = 0; update_page()); previous.custom_minimum_size = Vector2(48,62)
	belt.move_child(previous,0)
	var next := UI.button(belt,"›",func(): page = 1; update_page()); next.custom_minimum_size = Vector2(48,62)
	update_page()
	location_text.reparent(root)
	place_panel(location_text,Control.PRESET_CENTER_TOP,Rect2(-205,92,410,20))
	location_text.add_theme_font_size_override("font_size",11); location_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.hide(); quota_text.hide()
	status_text.position = Vector2(14,128)
	place_panel(build_text,Control.PRESET_CENTER_TOP,Rect2(-290,115,580,30)); build_text.add_theme_font_size_override("font_size",12)
	place_panel(notice_text,Control.PRESET_CENTER_TOP,Rect2(-320,148,640,38)); notice_text.add_theme_font_size_override("font_size",12)
	gather_bar.offset_top = 40; gather_bar.offset_bottom = 47
	gather_label.offset_top = 49; gather_label.offset_bottom = 71; gather_label.add_theme_font_size_override("font_size",13)

func update_page() -> void:
	for i in range(hotbar.size()): hotbar[i].visible = i>=page*5 and i<page*5+5

func _process(delta: float) -> void:
	if mode=="upgrade" and world.resources.pending==0: close_modal()
	refresh_elapsed += delta
	performance_elapsed += delta
	if refresh_elapsed<.1: return
	delta = refresh_elapsed; refresh_elapsed = 0
	super._process(delta)
	if not is_instance_valid(world.touch_controls): return
	performance_text.visible = mode.is_empty()
	var seconds := ceili(world.airdrops.left)
	airdrop_text.text = "AIRDROP %02d:%02d" % [seconds/60,seconds%60] if world.airdrops.state.is_empty() or world.airdrops.state.get("collected",false) else "DROP (%d,%d)" % [world.airdrops.coord().x,world.airdrops.coord().y]
	crosshair.visible = mode.is_empty() and world.player.bag.hand()=="grenade" and not world.builder.active
	if crosshair.visible: crosshair.position = world.camera.unproject_position(world.player.position+world.touch_controls.free_aim*8+Vector3.UP)-Vector2(10,12)
	if performance_elapsed>=.5:
		performance_elapsed = 0
		performance_text.text = "%d FPS · %s" % [Engine.get_frames_per_second(),"LEVE" if MobilePlatform.lightweight() else "DETALHADO"]
	notice_text.text = notice_text.text.replace("G melhora a estrutura próxima","AÇÕES melhora a estrutura próxima")
	if mode=="depot":
		for id in depot_buttons: depot_buttons[id].text = "%s ×%d / retirar" % [ItemBag.TITLES[id],world.depot_count(id)]
	if gather_label.visible: gather_label.text = gather_label.text.replace("SEGURE E","SEGURE COLETAR")
	if world.builder.active: build_text.text = "Toque no chão para posicionar · GIRAR · COLOCAR\n"+world.builder.reason
	elif world.area_index==-1 and world.player.position.distance_to(world.core.position)<4: build_text.text = "Segure COLETAR para guardar materiais · BOLSA abre o depósito"
	else: build_text.text = build_text.text.replace("SEGURE E","Segure COLETAR").replace("E /","COLETAR /").replace("I /","BOLSA /")
	location_text.text = location_text.text.replace("M mapa","AÇÕES / mapa").replace("E nas saídas","COLETAR nas saídas")

func open_modal(next_mode: String,width: float = 800) -> VBoxContainer:
	if is_instance_valid(world.touch_controls): world.touch_controls.reset_fingers()
	var box := super.open_modal(next_mode,minf(width,880))
	box.get_parent().remove_child(box)
	for child in modal.get_children():
		if child is CenterContainer: modal.remove_child(child); child.queue_free()
	var panel := UI.panel(modal); UI.fill(panel)
	panel.offset_left = 12; panel.offset_right = -12; panel.offset_top = 8; panel.offset_bottom = -8
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var scroll := ScrollContainer.new(); panel.add_child(scroll); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(box); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",8)
	var close := UI.button(modal,"×",func():
		if world.phase=="ended": menu()
		else: close_modal()
	)
	place_panel(close,Control.PRESET_TOP_RIGHT,Rect2(-86,16,62,48))
	var close_style := compact_style(); close_style.content_margin_top = 2; close_style.content_margin_bottom = 2
	close.add_theme_stylebox_override("normal",close_style); close.add_theme_font_size_override("font_size",24)
	call_deferred("adapt_modal",box)
	return box

func adapt_modal(node: Node) -> void:
	if not is_instance_valid(node): return
	if node is Label and not node.get_parent() is ItemSlot:
		node.text = node.text.replace("Clique","Toque").replace("clique","toque").replace("G reforça:","Melhorias:").replace("F abre","AÇÕES abre").replace("pressione E","toque em COLETAR")
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if node.get_theme_font_size("font_size")>25: node.add_theme_font_size_override("font_size",24)
	if node is Button and not node is ItemSlot:
		node.text = node.text.replace(" / I","").replace(" / ESC","")
		node.custom_minimum_size.y = maxf(48,node.custom_minimum_size.y)
	for child in node.get_children(): adapt_modal(child)

func show_inventory() -> void:
	var box := open_modal("inventory",880)
	UI.label(box,"BOLSA / BARRA RÁPIDA",24,UI.LIME)
	UI.label(box,"Toque dois espaços para trocar. Os espaços 1–9 ficam na barra rápida.",15,UI.MUTED)
	inventory_status = UI.label(box,"",14,UI.MUTED); inventory_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var grid := GridContainer.new(); grid.columns = 6; grid.add_theme_constant_override("h_separation",6); grid.add_theme_constant_override("v_separation",6)
	box.add_child(grid); inventory_buttons.clear(); depot_buttons.clear()
	for i in range(18):
		var index := i; var button := ItemSlot.new(); button.key_number = i+1
		button.pressed.connect(func():
			if inventory_selected<0: inventory_selected = index
			else: world.send_action("swap",{"a":inventory_selected,"b":index}); inventory_selected = -1
		)
		grid.add_child(button); button.custom_minimum_size = Vector2(100,74); inventory_buttons.append(button)
	var row := UI.hbox(box,8)
	UI.button(row,"GUARDAR SELEÇÃO",func():
		if inventory_selected>=0: world.send_action("store",{"slot":inventory_selected}); inventory_selected = -1
	)
	UI.button(row,"DESCARTAR SELEÇÃO",func():
		if inventory_selected>=0: world.send_action("drop",{"slot":inventory_selected}); inventory_selected = -1
	)
	UI.button(row,"DEPÓSITO",func(): close_modal(); show_depot())
	UI.button(box,"VOLTAR AO JOGO",close_modal,true)
	refresh_inventory()

func show_depot() -> void:
	var box := open_modal("depot",880)
	UI.label(box,"DEPÓSITO DO NÚCLEO",24,UI.LIME)
	UI.label(box,"Aproxime-se do Núcleo para retirar. Para guardar, selecione o item na bolsa ou segure COLETAR junto ao Núcleo.",16,UI.MUTED)
	depot_buttons.clear()
	for id in ItemBag.IDS:
		var chosen: String = id
		depot_buttons[id] = UI.button(box,ItemBag.TITLES[id]+" / retirar",func(): world.send_action("withdraw",{"id":chosen,"qty":20}))
	UI.button(box,"VOLTAR À BOLSA",func(): close_modal(); show_inventory(),true)

func find_grids(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node is GridContainer: result.append(node)
	for child in node.get_children(): result.append_array(find_grids(child))
	return result

func show_build_catalog() -> void:
	super.show_build_catalog()
	for grid in find_grids(overlay_box):
		grid.columns = 2
		var inner: Control = grid.get_parent()
		var order := inner.get_index()
		inner.remove_child(grid); overlay_box.add_child(grid); overlay_box.move_child(grid,order)
		inner.get_parent().remove_child(inner); inner.queue_free()
		for card in grid.get_children(): card.custom_minimum_size = Vector2(360,190)

func show_routes() -> void:
	super.show_routes()
	for grid in find_grids(overlay_box):
		for button in grid.get_children():
			button.custom_minimum_size = Vector2(54,44)
			for name in ["normal","hover","pressed"]:
				var style: StyleBox = button.get_theme_stylebox(name).duplicate()
				style.content_margin_left = 4; style.content_margin_right = 4; style.content_margin_top = 4; style.content_margin_bottom = 4
				button.add_theme_stylebox_override(name,style)
		grid.get_parent().get_child(1).custom_minimum_size.x = 300

func show_actions() -> void:
	if not mode.is_empty() or world.phase=="ended": return
	var box := open_modal("actions",880)
	UI.label(box,"AÇÕES DO REFÚGIO",24,UI.LIME)
	var actions := [["MAPA",show_routes],["MOCHILA / DEPÓSITO",show_inventory],["CONSTRUIR",show_build_catalog],["VENDEDOR",func(): world.open_shop()],["MELHORAR DEFESA PRÓXIMA",func(): world.send_action("upgrade",{})],["ABRIR / FECHAR PORTÃO",func(): world.send_action("gate",{})],["DESMONTAR DEFESA",confirm_dismantle]]
	for action in actions:
		var callback: Callable = action[1]
		UI.button(box,action[0],func(): close_modal(); callback.call())
	if not world.is_client:
		UI.button(box,"SALVAR NO NÚCLEO",func(): close_modal(); world.save_checkpoint())
		UI.button(box,"RESTAURAR REFÚGIO SALVO",func(): close_modal(); world.load_checkpoint())
	UI.button(box,"VOLTAR",close_modal,true)
