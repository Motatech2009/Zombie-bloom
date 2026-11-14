extends "res://scripts/survival/survival_hud.gd"
var belt: HBoxContainer
var page: int = 0
var refresh_elapsed: float = 0
var performance_text: Label
var performance_elapsed: float = 0
var browser_list: VBoxContainer
var browser_detail: VBoxContainer
var browser_status: Label
var browser_title: Label
var browser_price: Label
var browser_buy: Button
var browser_tab: int = 0
var browser_selection: int = -1
var browser_entries: Array[Dictionary] = []
var browser_buttons: Array[Button] = []
var browser_tabs: Array[Button] = []
var upgrade_info: Label
var upgrade_buy: Button
func _ready() -> void:
	super._ready()
	var controls := TouchControls.new(); controls.world = world; root.add_child(controls)
	world.touch_controls = controls
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
	place_panel(held,Control.PRESET_BOTTOM_RIGHT,Rect2(-390,-122,236,50))
	var style := UI.style(Color(.03,.07,.09,.25),Color(1,1,1,.25),8); style.content_margin_top = 2; style.content_margin_bottom = 2; style.content_margin_left = 8; style.content_margin_right = 8
	held.add_theme_stylebox_override("panel",style)
	held_icon.custom_minimum_size = Vector2(28,28)
	weapon_text.add_theme_font_size_override("font_size",12)
	weapon_text.clip_text = true; weapon_text.custom_minimum_size.x = 150
	ammo_text.add_theme_font_size_override("font_size",18); power_text.hide()
	belt = hotbar[0].get_parent()
	place_panel(belt,Control.PRESET_BOTTOM_RIGHT,Rect2(-392,-66,346,56))
	belt.add_theme_constant_override("separation",4)
	for button in hotbar:
		button.custom_minimum_size = Vector2(54,54)
		button.normal_frame.bg_color = Color(.03,.08,.1,.22)
		button.selected_frame.bg_color = Color(.2,.3,.22,.5)
	var previous := UI.button(belt,"‹",func(): page = maxi(0,page-1); update_page()); previous.custom_minimum_size = Vector2(36,54)
	belt.move_child(previous,0)
	var next := UI.button(belt,"›",func(): page = mini(2,page+1); update_page()); next.custom_minimum_size = Vector2(36,54)
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
	for i in range(hotbar.size()): hotbar[i].visible = i>=page*4 and i<page*4+4

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
	notice_text.text = notice_text.text.replace("G melhora a estrutura próxima","MELHORAR reforça a estrutura próxima")
	if mode in ["shop","catalog"]: refresh_browser()
	if mode=="structure": refresh_structure_upgrade()
	if mode=="depot":
		for id in depot_buttons: depot_buttons[id].text = "%s ×%d / retirar" % [ItemBag.TITLES[id],world.depot_count(id)]
	if gather_label.visible: gather_label.text = gather_label.text.replace("SEGURE E","SEGURE COLETAR")
	if world.builder.active: build_text.text = "Toque no chão para posicionar · GIRAR · COLOCAR\n"+world.builder.reason
	else:
		var collect: String = world.local_mobile_context().get("collect","")
		build_text.text = "Segure GUARDAR para transferir materiais ao Núcleo" if collect=="GUARDAR" else "Segure COLETAR para abrir a caixa" if collect=="COLETAR" else ""
	location_text.text = location_text.text.replace("M mapa","MAPA").replace("E nas saídas","VIAJAR nas saídas")

func open_modal(next_mode: String,width: float = 800) -> VBoxContainer:
	if is_instance_valid(world.touch_controls): world.touch_controls.reset_fingers()
	var box := super.open_modal(next_mode,minf(width,880))
	box.get_parent().remove_child(box)
	for child in modal.get_children():
		if child is CenterContainer: modal.remove_child(child); child.queue_free()
	var panel := UI.panel(modal); UI.fill(panel)
	UI.label(modal,"",1)
	panel.offset_left = 12; panel.offset_right = -12; panel.offset_top = 66; panel.offset_bottom = -10
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	box.custom_minimum_size.x = 0
	if next_mode in ["shop","catalog"]:
		panel.add_child(box)
	else:
		var scroll := ScrollContainer.new(); scroll.scroll_deadzone = 12; panel.add_child(scroll); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(box)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",8)
	var close := UI.button(modal,"FECHAR",func():
		if world.phase=="ended": menu()
		else: close_modal()
	)
	place_panel(close,Control.PRESET_TOP_RIGHT,Rect2(-140,10,116,48))
	var close_style := compact_style(); close_style.content_margin_top = 2; close_style.content_margin_bottom = 2
	close.add_theme_stylebox_override("normal",close_style); close.add_theme_font_size_override("font_size",17)
	var heading := UI.label(modal,{"inventory":"MOCHILA","depot":"DEPÓSITO","catalog":"CONSTRUÇÃO","routes":"MAPA","settings":"CONFIGURAÇÕES","pause":"PAUSA","shop":"BENTO / VENDEDOR","structure":"MELHORAR CONSTRUÇÃO"}.get(next_mode,"REFÚGIO"),22,UI.LIME)
	heading.position = Vector2(26,21)
	call_deferred("adapt_modal",box)
	return box

func adapt_modal(node: Node) -> void:
	if not is_instance_valid(node): return
	if node==overlay_box and node.get_child_count()>0 and node.get_child(0) is Label: node.get_child(0).hide()
	if node is Label and not node.get_parent() is ItemSlot:
		node.text = node.text.replace("Clique","Toque").replace("clique","toque").replace("G reforça:","Melhorias:").replace("F abre","PORTÃO abre").replace("pressione E","toque em COLETAR").replace("F5 salva; F9 restaura. Ambos apenas no refúgio, na preparação.","Salve e restaure junto ao Núcleo, durante a preparação.")
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if node.get_theme_font_size("font_size")>25: node.add_theme_font_size_override("font_size",24)
	if node is Button and not node is ItemSlot:
		node.text = node.text.replace(" / I","").replace(" / ESC","")
		node.custom_minimum_size.y = maxf(52,node.custom_minimum_size.y)
		node.add_theme_font_size_override("font_size",17)
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
	if not mode.is_empty() or not world.local_mobile_context().get("build",false): return
	show_browser("catalog")

func show_shop() -> void:
	if not mode.is_empty() or not world.local_mobile_context().get("shop",false): return
	show_browser("shop")

func show_browser(kind: String) -> void:
	var box := open_modal(kind,880)
	UI.label(box,"BENTO" if kind=="shop" else "CONSTRUÇÃO",24,UI.LIME)
	browser_status = UI.label(box,"",14,UI.MUTED)
	var tabs := UI.hbox(box,8); browser_tabs.clear()
	var titles: Array = ["ARMAS","MUNIÇÃO","SUPRIMENTOS"] if kind=="shop" else ["TODAS","MUROS","TORRES","ARMADILHAS"]
	for i in range(titles.size()):
		var index := i
		var tab := UI.button(tabs,titles[i],func(): browser_tab = index; populate_browser())
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL; browser_tabs.append(tab)
	var row := UI.hbox(box,12); row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new(); scroll.scroll_deadzone = 12; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = 370; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; row.add_child(scroll)
	browser_list = UI.vbox(scroll,6); browser_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := UI.panel(row); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_detail = UI.vbox(panel,6)
	browser_tab = 0; populate_browser()

func populate_browser() -> void:
	for i in range(browser_tabs.size()): browser_tabs[i].modulate = UI.LIME if i==browser_tab else Color.WHITE
	for child in browser_list.get_children(): browser_list.remove_child(child); child.queue_free()
	browser_entries.clear(); browser_buttons.clear()
	if mode=="catalog":
		for i in range(FortressData.pieces().size()):
			var data: Dictionary = FortressData.pieces()[i]
			var category := 2 if FortressData.turret(data.id) else 3 if data.id in ["wire","spikes","station"] else 1
			if browser_tab!=0 and browser_tab!=category: continue
			browser_entries.append({"id":data.id,"title":data.title,"description":FortressData.DESCRIPTIONS[i],"cost":data.cost,"index":i,"qty":1,"health":data.health})
	elif browser_tab==0:
		for i in range(1,Arsenal.WEAPONS.size()):
			browser_entries.append({"id":ItemBag.WEAPON_IDS[i],"title":Arsenal.WEAPONS[i].title,"description":Arsenal.DESCRIPTIONS[i],"cost":{"scrap":Arsenal.PRICES[i]},"index":i,"qty":1})
	else:
		for id in Arsenal.PACKS:
			var ammunition: bool = id in ItemBag.AMMO_IDS
			if ammunition!=(browser_tab==1): continue
			browser_entries.append({"id":id,"title":ItemBag.TITLES[id],"description":"Vai para sua bolsa. Leve materiais ao Núcleo para usar na base.","cost":{"scrap":Arsenal.PACKS[id][1]},"index":-1,"qty":Arsenal.PACKS[id][0]})
	for i in range(browser_entries.size()):
		var index := i; var entry: Dictionary = browser_entries[i]
		var button := UI.button(browser_list,entry.title,func(): select_browser_item(index))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.clip_text = true
		button.icon = ItemIcons.get_icon(entry.id); button.expand_icon = true; button.add_theme_constant_override("icon_max_width",34)
		button.custom_minimum_size = Vector2(350,56); browser_buttons.append(button)
	select_browser_item(0)

func select_browser_item(index: int) -> void:
	browser_selection = index
	for child in browser_detail.get_children(): browser_detail.remove_child(child); child.queue_free()
	if browser_entries.is_empty(): return
	var entry: Dictionary = browser_entries[index]
	var top := UI.hbox(browser_detail,10)
	ItemIcons.image(top,entry.id,Vector2(54,54))
	browser_title = UI.label(top,entry.title.to_upper(),20,UI.LIME); browser_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; browser_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var description := UI.label(browser_detail,entry.description,14,UI.MUTED); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mode=="catalog": UI.label(browser_detail,"Integridade inicial: %d · até N3" % entry.health,14)
	elif entry.index>=0:
		var spec: Resource = Arsenal.WEAPONS[entry.index]
		UI.label(browser_detail,"Dano: %s · alcance: %s" % [spec.values.damage,spec.values.range],14)
	else: UI.label(browser_detail,"Pacote com %d unidades" % entry.qty,16)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; browser_detail.add_child(spacer)
	browser_price = UI.label(browser_detail,CampaignData.cost_text(entry.cost) if mode=="catalog" else "%d sucata" % entry.cost.scrap,15,Color("edcf95")); browser_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	browser_buy = UI.button(browser_detail,"",purchase_browser_item,true)
	for i in range(browser_buttons.size()): browser_buttons[i].modulate = UI.LIME if i==index else Color.WHITE
	refresh_browser()

func refresh_browser() -> void:
	if not is_instance_valid(browser_status) or browser_entries.is_empty(): return
	var available: bool = world.local_mobile_context().get("shop" if mode=="shop" else "build",false)
	if not available: close_modal(); return
	browser_status.text = "NÚCLEO: %d sucata · %d madeira · %d componentes" % [world.resources.scrap,world.stock.wood,world.stock.parts]
	if mode=="catalog": browser_status.text += "  /  COTA %d/%d" % [world.built_this_round,world.build_quota()]
	var entry: Dictionary = browser_entries[browser_selection]
	var reason := ""
	if mode=="catalog":
		if world.built_this_round>=world.build_quota(): reason = "COTA DESTA HORDA ESGOTADA"
	else:
		var copy := ItemBag.new(); copy.restore(world.player.bag.dump())
		if entry.index>=0 and copy.count(entry.id)>0: reason = "VOCÊ JÁ TEM ESTA ARMA"
		elif copy.add(entry.id,entry.qty)!=entry.qty: reason = "SEM ESPAÇO NA BOLSA"
	if reason.is_empty() and not world.can_pay(entry.cost): reason = "MATERIAIS INSUFICIENTES" if mode=="catalog" else "SUCATA INSUFICIENTE"
	browser_buy.disabled = not reason.is_empty()
	browser_buy.text = reason if not reason.is_empty() else "POSICIONAR" if mode=="catalog" else "COMPRAR"

func purchase_browser_item() -> void:
	if browser_buy.disabled: return
	var entry: Dictionary = browser_entries[browser_selection]
	if mode=="catalog":
		close_modal(); world.builder.selected = entry.index; world.builder.set_active(true)
	elif entry.index>=0: world.send_action("buy",{"weapon":entry.index}); refresh_browser()
	else: world.send_action("service",{"id":entry.id}); refresh_browser()

func show_structure_upgrade() -> void:
	if not mode.is_empty() or world.local_mobile_context().get("upgrade",{}).is_empty(): return
	var box := open_modal("structure",650)
	UI.label(box,"MELHORAR CONSTRUÇÃO",24,UI.LIME)
	upgrade_info = UI.label(box,"",20); upgrade_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_buy = UI.button(box,"MELHORAR",func(): world.send_action("upgrade",{}); close_modal(),true)
	UI.button(box,"DESMONTAR DEFESA",func(): close_modal(); confirm_dismantle())
	refresh_structure_upgrade()

func refresh_structure_upgrade() -> void:
	var info: Dictionary = world.local_mobile_context().get("upgrade",{})
	if info.is_empty(): close_modal(); return
	upgrade_info.text = "%s · N%d → N%d\n%s" % [info.title,info.tier,info.tier+1,CampaignData.cost_text(info.cost)]
	upgrade_buy.disabled = not world.can_pay(info.cost)
	upgrade_buy.text = "MELHORAR" if not upgrade_buy.disabled else "MATERIAIS INSUFICIENTES"

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
	show_build_catalog()
