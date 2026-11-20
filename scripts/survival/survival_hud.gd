extends "res://scripts/sectors/roaming_hud.gd"
var hotbar: Array[Button] = []
var inventory_buttons: Array[Button] = []
var inventory_selected: int = -1
var inventory_status: Label
var quota_text: Label
var gather_bar: ProgressBar
var gather_label: Label
var depot_buttons: Dictionary = {}
var choice_cooldown: float = 0
var post_info16: Label
var post_buttons16: Array[Button] = []
var systems15_button: Button
var alert15_label: Label
var day15_label: Label

var held_icon: TextureRect
var wood_count: Label
var parts_count: Label
var status_text: Label
var airdrop_text: Label
var airdrop_map_info: Label
var party_map_info: Label
var map_focus: Variant = null
var drop_map_stamp: String = ""
var desktop_shop: ShopBrowser
var roll_text: Label
var roll_bar: ProgressBar
var heal_action: Button
var heal_status: Label
var heal_hint_left := 0.0
var inventory_meter: ProgressBar
var inventory_selection: Label
var inventory_selection_icon: TextureRect
var inventory_depot_hint: Label
var inventory_store: Button
var inventory_drop: Button

func make_panel(left: float,top: float,right: float,bottom: float,preset: int) -> PanelContainer:
	var panel := UI.panel(root)
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = left; panel.offset_top = top; panel.offset_right = right; panel.offset_bottom = bottom
	var frame := UI.style(Color("132122ed"),Color("536157"),12)
	frame.border_width_left = 3
	frame.shadow_color = Color(0,0,0,.4)
	frame.shadow_size = 7
	frame.shadow_offset = Vector2(0,3)
	frame.content_margin_left = 14; frame.content_margin_right = 14
	frame.content_margin_top = 10; frame.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",frame)
	return panel

func create_top() -> void:
	var vitals := make_panel(20,18,334,125,Control.PRESET_TOP_LEFT)
	var vitals_box := UI.vbox(vitals,5)
	var hp_row := UI.hbox(vitals_box,9)
	ItemIcons.image(hp_row,"health",Vector2(23,23))
	health_text = UI.label(hp_row,"",19)
	health_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_text = UI.label(hp_row,"",11,UI.MUTED)
	health_bar = UI.meter(vitals_box,Color("e99b84"))
	health_bar.custom_minimum_size.y = 7
	var core_row := UI.hbox(vitals_box,9)
	ItemIcons.image(core_row,"core",Vector2(23,23))
	core_text = UI.label(core_row,"",14,Color("9ddde0"))
	core_bar = UI.meter(vitals_box,Color("70c9d5"))
	core_bar.custom_minimum_size.y = 5
	var siege := make_panel(-178,18,178,112,Control.PRESET_CENTER_TOP)
	var row := UI.hbox(siege,10)
	ItemIcons.image(row,"wave",Vector2(43,43))
	var wave_box := UI.vbox(row,1)
	wave_text = UI.label(wave_box,"",25,Color("ebeed6"))
	wave_detail = UI.label(wave_box,"",14,Color("edbd72"))
	phase_text = UI.label(wave_box,"",10,UI.MUTED)
	quota_text = UI.label(wave_box,"",10,Color("d9c79c"))
	var depot := make_panel(-351,18,-20,109,Control.PRESET_TOP_RIGHT)
	var box := UI.vbox(depot,7)
	var header := UI.hbox(box,10)
	UI.label(header,"ESTOQUE DO NÚCLEO",11,UI.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pause := UI.button(header,"Ⅱ",show_pause)
	pause.custom_minimum_size = Vector2(25,22)
	var pause_style := UI.style(Color(0,0,0,0),Color("344d5a"),4)
	pause_style.content_margin_left = 4; pause_style.content_margin_right = 4
	pause_style.content_margin_top = 1; pause_style.content_margin_bottom = 1
	pause.add_theme_stylebox_override("normal",pause_style)
	pause.add_theme_font_size_override("font_size",12)
	var materials := UI.hbox(box,12)
	for id in ["scrap","wood","parts"]:
		var pair := UI.hbox(materials,4)
		ItemIcons.image(pair,id,Vector2(30,30))
		var count := UI.label(pair,"",18,Color("edcf95") if id=="scrap" else UI.TEXT)
		if id=="scrap": scrap_text = count
		elif id=="wood": wood_count = count
		else: parts_count = count
	material_text = UI.label(box,"",1)
	material_text.hide()
	airdrop_text = UI.label(root,"",13,Color("e8bc77"))
	airdrop_text.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	airdrop_text.offset_left = -348; airdrop_text.offset_right = -18
	airdrop_text.offset_top = 117; airdrop_text.offset_bottom = 140
	airdrop_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func create_bottom() -> void:
	var held_panel := make_panel(18,-119,299,-16,Control.PRESET_BOTTOM_LEFT)
	var held_row := UI.hbox(held_panel,10)
	held_icon = ItemIcons.image(held_row,"pistol",Vector2(66,66))
	var held_info := UI.vbox(held_row,3)
	held_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_text = UI.label(held_info,"",13,Color("e2e8d8"))
	ammo_text = UI.label(held_info,"",25,Color("edcf95"))
	reload_bar = UI.meter(held_info,Color("edbd72"))
	power_text = UI.label(held_info,"",11,UI.MUTED)
	var belt_frame := make_panel(-372,-112,372,-16,Control.PRESET_CENTER_BOTTOM)
	var belt_style := UI.style(Color("10191cdb"),Color("556053"),11)
	belt_style.content_margin_left = 7; belt_style.content_margin_right = 7
	belt_style.content_margin_top = 6; belt_style.content_margin_bottom = 6
	belt_frame.add_theme_stylebox_override("panel",belt_style)
	var belt := UI.hbox(belt_frame,6)
	belt.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(9):
		var index := i
		var button := ItemSlot.new()
		button.key_number = i+1
		button.pressed.connect(func(): world.select_hotbar(index))
		belt.add_child(button)
		hotbar.append(button)
	hints = make_panel(-300,-119,-18,-16,Control.PRESET_BOTTOM_RIGHT)
	var hint_box := UI.vbox(hints,3)
	var actions := UI.hbox(hint_box,5)
	for entry in [["map","M",show_routes,"Mapa dos setores"],["bag","I",show_inventory,"Bolsa"],["build","B",show_build_catalog,"Construir"]]:
		var button := UI.button(actions,entry[1],entry[2])
		button.tooltip_text = entry[3]
		button.icon = ItemIcons.get_icon(entry[0])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",27)
		button.custom_minimum_size = Vector2(76,38)
		var style := compact_style(); style.content_margin_top = 3; style.content_margin_bottom = 3
		button.add_theme_stylebox_override("normal",style)
	var roll_row := UI.hbox(hint_box,8)
	roll_text = UI.label(roll_row,"",11,UI.LIME)
	roll_bar = UI.meter(roll_row,UI.LIME)
	roll_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	roll_bar.max_value = 5
	roll_bar.custom_minimum_size.y = 3
	location_text = UI.label(hint_box,"",11,UI.MUTED)
	location_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heal_action = UI.button(root,"CURAR ALIADO · E",func(): world.send_action("heal",{}),true)
	heal_action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	heal_action.offset_left = -300; heal_action.offset_right = -18
	heal_action.offset_top = -240; heal_action.offset_bottom = -196
	heal_action.hide()
	next_button = Button.new(); root.add_child(next_button); next_button.hide()
	status_text = UI.label(root,"",14,Color("98d9f1"))
	status_text.position = Vector2(30,151)
	heal_status = UI.label(root,"",13,Color("b6e0aa"))
	heal_status.position = Vector2(30,174)
	notice_text = UI.label(root,"",15,Color("ead4a7"))
	notice_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_text.offset_left = -355; notice_text.offset_right = 355
	notice_text.offset_top = 132; notice_text.offset_bottom = 178
	notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_text = UI.label(root,"",14,UI.LIME)
	build_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	build_text.offset_left = -370; build_text.offset_right = 370; build_text.offset_top = -166; build_text.offset_bottom = -118
	build_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gather_bar = UI.meter(root,Color("edbd72"))
	gather_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gather_bar.offset_left = -130; gather_bar.offset_right = 130; gather_bar.offset_top = 85; gather_bar.offset_bottom = 94
	gather_label = UI.label(root,"",14,Color("edcf95"))
	gather_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gather_label.offset_left = -220; gather_label.offset_right = 220; gather_label.offset_top = 99; gather_label.offset_bottom = 125
	gather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for text in [quota_text,notice_text,build_text,airdrop_text,gather_label]:
		text.add_theme_color_override("font_outline_color",Color(0,0,0,.8))
		text.add_theme_constant_override("outline_size",3)

func _process(delta: float) -> void:
	if systems15_button==null:
		var overlay := Control.new(); overlay.set_script(load("res://scripts/release15/core_alert15.gd")); overlay.world = world; root.add_child(overlay)
		systems15_button = UI.button(root,"BASE" if MobilePlatform.enabled() else "REFÚGIO",show_systems15)
		systems15_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT); systems15_button.offset_left = -195; systems15_button.offset_right = -14; systems15_button.offset_top = -195; systems15_button.offset_bottom = -151
		alert15_label = UI.label(root,"",14,Color("ffa276")); alert15_label.position = Vector2(30,218)
		day15_label = UI.label(root,"",12,UI.LIME); day15_label.position = Vector2(30,195)
	if world.game_mode=="rescue":
		status_text.text = world.rescue16.hint()
	day15_label.text = ("NOITE VERMELHA" if world.v15.day.blood and world.v15.day.night() else "NOITE" if world.v15.day.night() else "DIA")+" · %02d:%02d" % [int(fposmod(world.v15.day.clock,900))/60,int(world.v15.day.clock)%60]
	alert15_label.text = "⚠ NÚCLEO SOB ATAQUE · (0,0) "+world.return_hint() if world.v15.alert_left>0 else ""
	alert15_label.modulate.a = .65+.35*sin(Time.get_ticks_msec()*.008)
	systems15_button.visible = mode.is_empty() and world.phase!="ended"; day15_label.visible = mode.is_empty(); alert15_label.visible = mode.is_empty()
	if MobilePlatform.enabled():
		systems15_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); systems15_button.offset_left = 253; systems15_button.offset_right = 348; systems15_button.offset_top = 15; systems15_button.offset_bottom = 62
		day15_label.position = Vector2(365,112); alert15_label.position = Vector2(255,137)
		alert15_label.add_theme_font_size_override("font_size",11)
	if mode=="shop" and desktop_shop!=null: desktop_shop.refresh()
	if mode=="post16" and is_instance_valid(post_info16):
		post_info16.text = "Vendedores se abrigaram — volte após a horda." if world.waves.running else "Materiais da sua mochila. O relógio e a defesa do Núcleo continuam."
		for button in post_buttons16:
			var id: String = button.get_meta("trade_id","")
			var state: Dictionary = world.exp16.sectors.get(SectorGenerator.key(world.player.region_coord),{})
			var used := int(state.get("stocks",{}).get(str(world.waves.wave)+":"+id,0))
			button.disabled = world.waves.running
			if id in ["medkit","light"]:
				var cost := int(Catalog16.data().post.medkit_scrap if id=="medkit" else Catalog16.data().post.light_scrap)
				button.text = str(button.get_meta("base_text"))+" · estoque %d" % maxi(0,int(Catalog16.data().post.stock_per_horde)-used)
				button.disabled = button.disabled or used>=int(Catalog16.data().post.stock_per_horde) or world.player.bag.count("scrap")<cost
			elif id=="bag": button.disabled = button.disabled or world.player.bag.bag_level!=1 or world.player.bag.count("scrap")<int(Catalog16.data().bag.upgrade_scrap) or world.player.bag.count("parts")<int(Catalog16.data().bag.upgrade_parts)
			elif id=="exchange": button.disabled = button.disabled or world.player.bag.count("wood")<20
	choice_cooldown = maxf(0,choice_cooldown-delta)
	if mode=="upgrade" and world.resources.pending==0: close_modal()
	super._process(delta)
	var actor: Node3D = world.player
	xp_text.text = "CARTAS %d" % world.resources.pending if world.resources.pending>0 else "EVOLUÇÃO %d" % (actor.weapons.level-1)
	notice_text.text = world.notice_for(actor.peer_id); notice_text.visible = not notice_text.text.is_empty()
	if world.game_mode=="rescue": wave_detail.text = world.rescue16.hint()
	if world.combat_paused(): wave_detail.text = "ALIADOS ESCOLHENDO · COMBATE PAUSADO"
	for i in range(9):
		var item: Dictionary = actor.bag.slots[i]
		hotbar[i].set_item(item.id,int(item.qty),actor.bag.selected==i)
	scrap_text.text = str(world.resources.scrap)
	wood_count.text = str(world.stock.wood)
	parts_count.text = str(world.stock.parts)
	status_text.text = "CONGELADO · %.1f s" % actor.slow_left if actor.slow_left>0 else "CAÍDO · Aguarde um aliado" if actor.health.dead else ""
	if is_instance_valid(heal_action) and not MobilePlatform.enabled():
		heal_hint_left -= delta
		if mode!="": heal_action.hide()
		elif heal_hint_left<=0:
			heal_hint_left = .12
			heal_action.visible = world.local_heal_available()
	if is_instance_valid(heal_status):
		heal_status.text = "CURA · RECARGA %ds" % ceili(actor.heal_cooldown) if actor.heal_cooldown>0 else ""
	if not world.truce16.hint().is_empty(): wave_detail.text = world.truce16.hint()
	roll_text.text = "ESPAÇO · ROLANDO" if actor.roll_left>0 else "ESPAÇO · %.1f s" % actor.roll_cooldown if actor.roll_cooldown>0 else "ESPAÇO · ROLAMENTO PRONTO"
	roll_text.modulate = UI.MUTED if actor.health.dead else UI.TEXT if actor.roll_cooldown>0 else UI.LIME
	roll_bar.value = 5-actor.roll_cooldown
	var hand: String = actor.bag.hand()
	weapon_text.text = ItemBag.TITLES.get(hand,"MÃOS LIVRES").to_upper()
	held_icon.texture = ItemIcons.get_icon(hand)
	if hand in ItemBag.WEAPON_IDS:
		var index := ItemBag.WEAPON_IDS.find(hand)
		ammo_text.text = "%d / %d" % [actor.weapons.ammo[index],actor.bag.count(ItemBag.AMMO_IDS[index])]
	else: ammo_text.text = "CORPO A CORPO" if hand=="bat" else "%d/%d" % [actor.bag.slots.size()-actor.bag.free_slots(),actor.bag.slots.size()]
	power_text.text = "BOLSA · %d espaços livres" % actor.bag.free_slots()
	quota_text.text = "CONSTRUÇÕES %d/%d   ·   EQUIPE %d   ·   HOSTIS ×%d" % [world.built_this_round,world.build_quota(),world.party_count(),world.team_multiplier()]
	gather_bar.visible = actor.gather_target!=null or actor.gather_progress>0
	gather_label.visible = gather_bar.visible
	if gather_bar.visible:
		gather_bar.max_value = actor.gather_duration
		gather_bar.value = actor.gather_progress
		gather_label.text = "CURANDO ALIADO · %.1f s" % maxf(0.0,actor.gather_duration-actor.gather_progress) if actor.gather_kind=="heal" else "SEGURE E · "+{"build":"construindo (dano cancela)","upgrade":"melhorando defesa","extract":"retornando ao Núcleo","loot":"coletando para a bolsa","deposit":"guardando no Núcleo","revive":"reanimando aliado","repair":"reparando defesa"}.get(actor.gather_kind,"coletando")
	airdrop_text.text = airdrop_summary()
	if mode=="routes":
		var stamp := str(world.airdrops.serial)+str(world.airdrops.state.get("collected",true))
		if stamp!=drop_map_stamp: close_modal(); show_routes()
		if is_instance_valid(airdrop_map_info): airdrop_map_info.text = airdrop_summary()+"\n"+airdrop_route()
		if is_instance_valid(party_map_info): party_map_info.text = party_locations()
	if world.builder.active: build_text.text = "1–9 / 0 peça · Q gira · clique instala · B sai\n"+world.builder.reason
	if mode=="inventory": refresh_inventory()
	if world.area_index==-1 and actor.position.distance_to(world.core.position)<4: build_text.text = "SEGURE E / GUARDAR MATERIAIS · I / DEPÓSITO"
	elif world.area_index!=-1 and not world.builder.active: build_text.text = "SEGURE E nas caixas · Carga na bolsa: leve ao Núcleo"

func open_modal(next_mode: String,width: float = 800) -> VBoxContainer:
	var box := super.open_modal(next_mode,width)
	if world.connected_game() or next_mode in ["inventory","equipment","post16"]: get_tree().paused = false
	return box

func show_inventory() -> void:
	var box := open_modal("inventory",1120)
	inventory_selected = -1
	var header := UI.hbox(box,16)
	ItemIcons.image(header,"bag",Vector2(43,43))
	var title := UI.vbox(header,3)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(title,"BOLSA DE CAMPO",27,UI.LIME)
	inventory_status = UI.label(title,"",13,UI.MUTED)
	inventory_meter = UI.meter(title,Color("c7d98a"))
	inventory_meter.custom_minimum_size.y = 5
	var close := UI.button(header,"VOLTAR AO JOGO · I",close_modal,true)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := UI.hbox(box,14)
	var left := UI.vbox(UI.panel(row),8)
	left.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(left,"BARRA RÁPIDA · TECLAS 1–9",13,Color("e7c38b"))
	var quick := inventory_grid(left)
	UI.label(left,"COMPARTIMENTOS DA BOLSA",13,UI.MUTED)
	var storage := inventory_grid(left)
	inventory_buttons.clear()
	for i in range(world.player.bag.slots.size()):
		var index := i
		var button := ItemSlot.new()
		button.key_number = i+1 if i<9 else 0
		button.pressed.connect(func():
			if inventory_selected<0: inventory_selected = index
			else:
				if inventory_selected!=index: world.send_action("swap",{"a":inventory_selected,"b":index})
				inventory_selected = -1
			refresh_inventory()
		)
		var grid := quick if i<9 else storage
		grid.add_child(button)
		button.custom_minimum_size = Vector2(65,69)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory_buttons.append(button)

	var selected := UI.hbox(left,9)
	inventory_selection_icon = ItemIcons.image(selected,"",Vector2(32,32))
	inventory_selection = UI.label(selected,"",15)
	inventory_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := UI.hbox(left,8)
	inventory_store = UI.button(actions,"GUARDAR NO NÚCLEO",func():
		world.send_action("store",{"slot":inventory_selected})
		inventory_selected = -1
	)
	inventory_drop = UI.button(actions,"LARGAR ITEM",func():
		world.send_action("drop",{"slot":inventory_selected})
		inventory_selected = -1
	)
	add_decoy16_button(left)
	if world.player.bag.count("field_bag")>0 and world.player.bag.bag_level==0:
		UI.button(left,"EQUIPAR BOLSA DE CAMPO · +3 ESPAÇOS",func(): world.send_action("equip_bag",{}); close_modal())

	var right := UI.vbox(UI.panel(row),8)
	right.custom_minimum_size.x = 295
	UI.label(right,"DEPÓSITO DO NÚCLEO",17,UI.LIME)
	inventory_depot_hint = UI.label(right,"",13,UI.MUTED)
	inventory_depot_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 290
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := UI.vbox(scroll,5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depot_buttons.clear()
	for id in ItemBag.IDS:
		var chosen: String = id
		var button := UI.button(list,ItemBag.TITLES[id],func(): world.send_action("withdraw",{"id":chosen,"qty":20}))
		button.icon = ItemIcons.get_icon(id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",24)
		button.add_theme_font_size_override("font_size",14)
		depot_buttons[id] = button
	refresh_inventory()

func inventory_grid(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation",5)
	grid.add_theme_constant_override("v_separation",5)
	parent.add_child(grid)
	return grid

func refresh_inventory() -> void:
	if not is_instance_valid(inventory_status): return
	var bag: ItemBag = world.player.bag
	var used := bag.slots.size()-bag.free_slots()
	if is_instance_valid(inventory_meter):
		inventory_status.text = "%d de %d espaços usados · Mochila nível %d" % [used,bag.slots.size(),bag.bag_level]
		inventory_meter.max_value = bag.slots.size()
		inventory_meter.value = used
		var at_depot: bool = world.area_index==-1 and world.player.position.distance_to(world.core.position)<=4
		var item: Dictionary = bag.slots[inventory_selected] if inventory_selected>=0 and inventory_selected<bag.slots.size() else {}
		var id := str(item.get("id",""))
		inventory_selection.text = "%s ×%d" % [ItemBag.TITLES[id],item.qty] if not id.is_empty() else "Clique em dois espaços para mover um item."
		inventory_selection_icon.texture = ItemIcons.get_icon(id)
		inventory_store.disabled = id.is_empty() or not at_depot
		inventory_drop.disabled = id.is_empty()
		inventory_depot_hint.text = "Itens disponíveis para retirar." if at_depot else "Aproxime-se do Núcleo para guardar ou retirar."
		for depot_id in depot_buttons:
			var amount: int = world.depot_count(depot_id)
			var button: Button = depot_buttons[depot_id]
			button.visible = amount>0
			button.disabled = not at_depot or amount<=0
			button.text = "%s ×%d" % [ItemBag.TITLES[depot_id],amount]
	else:
		inventory_status.text = "%d/%d espaços · Núcleo: %d sucata, %d madeira, %d componentes · Seleção %s" % [used,bag.slots.size(),world.resources.scrap,world.stock.wood,world.stock.parts,str(inventory_selected+1) if inventory_selected>=0 else "—"]
	for i in range(mini(inventory_buttons.size(),bag.slots.size())):
		var item: Dictionary = bag.slots[i]
		inventory_buttons[i].set_item(item.id,int(item.qty),inventory_selected==i)

func show_equipment() -> void:
	show_inventory()

func show_shop() -> void:
	desktop_shop = ShopBrowser.new()
	desktop_shop.show_in(self)

func request_upgrade() -> void:
	if choice_cooldown>0: return
	if world.upgrades.state(world.player).deferred or world.waves.running: return
	super.request_upgrade()

func show_upgrade() -> void:
	var offers: Array = world.upgrades.offers
	if offers.is_empty():
		if world.is_client: return
		offers = world.upgrades.roll()
	if offers.is_empty() or world.waves.running: return
	var choice_id: String = world.upgrades.current(world.player).get("id","")
	var box := open_modal("upgrade",900)
	var tint: Color = {"engineer":Color("edbd72"),"scout":UI.LIME,"shooter":Color("92c9ef")}.get(world.player.specialization,UI.LIME)
	UI.label(box,"SUA EVOLUÇÃO",28,tint)
	UI.label(box,"Escolha 1 carta para seu sobrevivente. Cada aliado tem sua própria escolha.",16,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(offers.size()):
		var index := i
		var card := UI.panel(box)
		var body := UI.vbox(card,6)
		var entry: Dictionary = offers[i]
		var heading := UI.hbox(body,10)
		var icon_id: String = {"damage":"pistol","rate":"smg","capacity":"light","reload":"rifle_ammo","speed":"map","health":"health","gather":"wood","engineering":"build","efficiency":"parts","cargo":"bag"}.get(entry.id,"wave")
		ItemIcons.image(heading,icon_id,Vector2(30,30))
		UI.label(heading,str(entry.get("tag","SOBREVIVÊNCIA"))+" · NÍVEL %d → %d / %d" % [int(entry.get("level",0)),int(entry.get("level",0))+1,int(entry.get("maximum",2))],13,tint)
		UI.label(body,entry.title,21)
		UI.label(body,entry.text,16,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.button(body,"ESCOLHER "+entry.title,func(): world.send_action("choice",{"index":index,"choice_id":choice_id}); choice_cooldown = .5; close_modal())
	UI.label(box,"O combate aguarda as escolhas ativas. Você pode guardar a sua para a preparação.",14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"ESCOLHER DEPOIS",func(): world.send_action("defer_choice",{"choice_id":choice_id}); choice_cooldown = .5; close_modal(),true)

func show_story17(page_index: int = -1) -> void:
	if world.game_mode != "campaign" or world.phase == "ended": return
	var completed := int(world.waves.wave) - int(world.waves.running)
	var pages := CampaignStory17.available(maxi(0, completed))
	var index := pages.size() - 1 if page_index < 0 else clampi(page_index, 0, pages.size() - 1)
	var page: Dictionary = pages[index]
	var box := open_modal("story17", 720)
	UI.label(box, "O ÚLTIMO FAROL · DIÁRIO DE CAIO VALE", 15, UI.LIME)
	UI.label(box, page.title, 30)
	var entry := UI.label(box, page.text, 18, UI.TEXT)
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := UI.hbox(box, 8)
	var previous := UI.button(row, "ANTERIOR", func(): show_story17(index - 1))
	previous.disabled = index == 0
	var next := UI.button(row, "PRÓXIMA", func(): show_story17(index + 1))
	next.disabled = index + 1 >= pages.size()
	UI.button(row, "CONTINUAR", close_modal, true)

func show_result() -> void:
	if world.won and world.game_mode=="campaign": world.v15.unlock_campaign()
	var box := open_modal("result",760)
	UI.label(box,"REFÚGIO DEFENDIDO" if world.won else "O GRUPO CAIU",34,UI.LIME)
	UI.label(box,world.ending_reason,19,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if world.won and world.game_mode == "campaign":
		var epilogue: Dictionary = CampaignStory17.PAGES.back()
		UI.label(box, epilogue.title, 22, UI.LIME)
		UI.label(box, epilogue.text, 17, UI.TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(box,"Horda %d · %d eliminações" % [world.waves.wave,world.kills],20)
	if not world.connected_game(): UI.button(box,"RETOMAR CHECKPOINT",func(): load("res://scripts/campaign/campaign_world.gd").resume_requested = true; restart())
	UI.button(box,"VOLTAR AO MENU",menu,true)

func menu() -> void:
	if scene_transition_pending: return
	if world.network!=null: world.network.close_session()
	super.menu()

func confirm_dismantle() -> void:
	if not mode.is_empty() or world.phase!="prep" or world.area_index!=-1: return
	var target: Node3D = world.nearest_structure()
	if target==null or target==world.core: world.notify("Aproxime-se da defesa para desmontar."); return
	var box := open_modal("dismantle",650)
	UI.label(box,"DESMONTAR "+target.spec.title.to_upper()+"?",27,UI.LIME)
	UI.label(box,"Recupera 50% dos materiais. Não devolve a cota desta horda.",17,UI.MUTED)
	UI.button(box,"DESMONTAR",func(): world.send_action("dismantle",{}); close_modal())
	UI.button(box,"CANCELAR",close_modal,true)

func show_pause() -> void:
	if not world.connected_game():
		super.show_pause()
		if mode == "pause":
			var actions := UI.hbox(overlay_box, 8)
			overlay_box.move_child(actions, overlay_box.get_child_count() - 3)
			UI.button(actions, "COSMÉTICOS", show_wardrobe)
			if world.game_mode == "campaign":
				UI.button(actions, "DIÁRIO DA CAMPANHA", show_story17)
		return
	if not mode.is_empty() or world.phase=="ended": return
	var box := open_modal("pause",640)
	UI.label(box,"SALA EM ANDAMENTO",32,UI.LIME)
	UI.label(box,"O relógio e os inimigos continuam enquanto este menu está aberto.",18,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"CONTINUAR",close_modal,true)
	if not world.is_client:
		var save := UI.button(box,"SALVAR REFÚGIO",func(): world.save_checkpoint(); close_modal())
		save.disabled = world.area_index!=-1 or world.phase!="prep"
	UI.button(box,"CONEXÃO / AMIGOS",func(): close_modal(); show_connection())
	UI.button(box,"ESTATÍSTICAS DO SAVE",func(): close_modal(); show_run_records())
	var actions := UI.hbox(box, 8)
	UI.button(actions, "COSMÉTICOS", show_wardrobe)
	if world.game_mode == "campaign":
		UI.button(actions, "DIÁRIO DA CAMPANHA", show_story17)
	UI.button(box,"CONFIGURAÇÕES",show_settings)
	UI.button(box,"ENCERRAR SALA" if not world.is_client else "SAIR DA SALA",menu)

func show_wardrobe() -> void:
	var mobile := MobilePlatform.enabled()
	var box := open_modal("wardrobe", 510 if mobile else 600)
	Menu16.wardrobe(box, world.player.specialization, 0 if mobile else 328)
	var actions := UI.hbox(box, 8)
	UI.button(actions, "VOLTAR", func(): close_modal(); show_pause())
	UI.button(actions, "CONTINUAR", close_modal, true)

func show_build_catalog() -> void:
	if not mode.is_empty() or world.phase!="prep" or world.area_index!=-1: return
	var box := open_modal("catalog",1200)
	UI.label(box,"FORTIFIQUE O REFÚGIO",30,UI.LIME)
	UI.label(box,"G reforça: madeira → aço → concreto / blindagem. Cota %d/%d · Núcleo até N4." % [world.built_this_round,world.build_quota()],15,UI.MUTED)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.y = 432
	box.add_child(scroll)
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation",9); grid.add_theme_constant_override("v_separation",9)
	scroll.add_child(grid)
	for i in range(FortressData.pieces().size()):
		var index := i
		var data: Dictionary = FortressData.pieces()[i]
		var panel := UI.panel(grid); panel.custom_minimum_size = Vector2(370,200)
		var card := UI.vbox(panel,6)
		var heading := UI.hbox(card,6)
		ItemIcons.image(heading,data.id,Vector2(40,40))
		UI.label(heading,"%s · %s" % [str(i+1) if i<9 else "0",data.title.to_upper()],16,data.color.lightened(.3))
		UI.label(card,FortressData.DESCRIPTIONS[i],14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.label(card,CampaignData.cost_text(data.cost),12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var usage: Vector2i = world.builder.piece_usage(data.id)
		if usage.y > 0: UI.label(card, "%d/%d na base · até vencer a horda %d" % [usage.x, usage.y, FortressData.BUILD_LIMIT_UNLOCK_WAVE], 12, UI.MUTED)
		var capped := usage.y > 0 and usage.x >= usage.y
		var select := UI.button(card,"LIMITE ATINGIDO" if capped else "CONSTRUIR",func(): close_modal(); world.builder.selected = index; world.builder.set_active(true))
		select.disabled = capped or not world.can_pay(data.cost) or world.built_this_round>=world.build_quota()
	UI.button(box,"VOLTAR",close_modal)

func airdrop_summary() -> String:
	var seconds := ceili(world.airdrops.left)
	if world.airdrops.state.is_empty() or world.airdrops.state.collected: return "PRÓXIMO AIRDROP %02d:%02d" % [seconds/60,seconds%60]
	var point: Vector2i = world.airdrops.coord()
	return "AIRDROP (%d,%d) · %d guardas · M mapa" % [point.x,point.y,world.airdrops.remaining()]

func airdrop_route() -> String:
	if world.airdrops.state.is_empty() or world.airdrops.state.collected: return "Uma queda a cada dez minutos de partida. O cerco continua."
	var delta: Vector2i = world.airdrops.coord()-world.sector_coord
	var parts: Array[String] = []
	if delta.x!=0: parts.append("%d %s" % [absi(delta.x),"Leste" if delta.x>0 else "Oeste"])
	if delta.y!=0: parts.append("%d %s" % [absi(delta.y),"Sul" if delta.y>0 else "Norte"])
	return "VOCÊ ESTÁ NA ÁREA DA QUEDA" if parts.is_empty() else "Rota: "+" · ".join(parts)

func map_center() -> Vector2i:
	return map_focus if map_focus is Vector2i else world.sector_coord

func show_routes() -> void:
	drop_map_stamp = str(world.airdrops.serial)+str(world.airdrops.state.get("collected",true))
	super.show_routes()
	if mode!="routes": return
	var side: Node = map_detail.get_parent()
	airdrop_map_info = UI.label(side,airdrop_summary()+"\n"+airdrop_route(),14,Color("e8bc77"))
	airdrop_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	party_map_info = UI.label(side,party_locations(),14,UI.LIME)
	party_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not world.airdrops.state.is_empty() and not world.airdrops.state.collected:
		mark_drop_cells(overlay_box,world.airdrops.coord())
		UI.button(side,"VER AIRDROP",func(): map_focus = world.airdrops.coord(); close_modal(); show_routes()).custom_minimum_size.y = 34
	if map_focus!=null: UI.button(side,"VER MINHA POSIÇÃO",func(): map_focus = null; close_modal(); show_routes()).custom_minimum_size.y = 34

func mark_drop_cells(node: Node,point: Vector2i) -> void:
	if node is Button and node.get_meta("coord",Vector2i(9999,9999))==point:
		node.text = "%d,%d\nDROP" % [point.x,point.y]
		node.add_theme_stylebox_override("normal",UI.style(Color("72563a"),Color("efc581"),6))
	for child in node.get_children(): mark_drop_cells(child,point)

func select_sector(coord: Vector2i) -> void:
	if not world.airdrops.state.is_empty() and coord==world.airdrops.coord() and not world.airdrops.state.collected:
		world.waypoint = coord
		map_detail.text = "AIRDROP · (%d,%d)\n%d guardas restantes. Uma escolta forte e um chefe. Elimine a escolta e segure E junto à caixa para recuperar lotes de suprimentos." % [coord.x,coord.y,world.airdrops.remaining()]
	else: super.select_sector(coord)

func show_connection() -> void:
	if not mode.is_empty() or not world.connected_game(): return
	var box := open_modal("connection",760)
	UI.label(box,"JOGAR DE CASAS DIFERENTES",27,UI.LIME)
	UI.label(box,"Use um endereço alcançável do anfitrião. Não use 127.0.0.1 no PC do amigo.",16,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not world.is_client:
		var service: InternetRoom = world.network.internet
		var info := UI.label(box,"",16,UI.TEXT); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.button(box,"CONFIGURAR PORTA AUTOMÁTICA",func(): service.enable(world.network.server_port))
		var copy_address := UI.button(box,"COPIAR ENDEREÇO EXTERNO",func():
			if not service.public_address.is_empty(): DisplayServer.clipboard_set(service.public_address)
		)
		UI.button(box,"DESATIVAR PORTA AUTOMÁTICA",func(): service.disable())
		var update_info := func():
			if not is_instance_valid(info): return
			info.text = "LAN / VPN: "+", ".join(InternetRoom.local_endpoints(world.network.server_port))+"\n\n"+service.status+"\n"+("Endereço externo: "+service.public_address if not service.public_address.is_empty() else "")
			copy_address.disabled = service.public_address.is_empty()
		update_info.call(); service.changed.connect(update_info)
		info.tree_exiting.connect(func():
			if service.changed.is_connected(update_info): service.changed.disconnect(update_info)
		)
	UI.label(box,"Se UPnP não funcionar ou houver CGNAT: ambos instalam Tailscale, o anfitrião compartilha seu computador com o amigo e o convidado entra pelo IP 100.x do anfitrião. Usem a mesma porta UDP da sala.",16,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"GUIA OFICIAL DE CONEXÃO",func(): OS.shell_open("https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server"))
	UI.button(box,"VOLTAR",func(): close_modal(); show_pause(),true)

func party_locations() -> String:
	var lines: Array[String] = ["EQUIPE / QUADRANTES"]
	for actor in world.avatars.values():
		var point: Vector2i = actor.region_coord if world.connected_game() else world.sector_coord
		lines.append("%s: (%d,%d)%s" % [actor.display_name,point.x,point.y," · CAÍDO" if actor.health.dead else ""])
	return "\n".join(lines)

func show_run_records() -> void:
	if not mode.is_empty(): return
	var box := open_modal("records",700)
	UI.label(box,"ESTATÍSTICAS DESTE REFÚGIO",20,UI.LIME)
	for identity in world.records.totals:
		var row: Dictionary = world.records.totals[identity]
		UI.label(box,"%s: %d abates · %d hordas · %d sucata" % [identity,row.kills,row.hordes,row.scrap],16)
	UI.button(box,"FECHAR",close_modal)

func show_weapon_workshop() -> void:
	close_modal()
	var box := open_modal("workshop",650)
	UI.label(box,"OFICINA DO BENTO",26,UI.LIME)
	var index: int = world.player.weapons.hand_weapon
	if index<0:
		UI.label(box,"Equipe uma arma de fogo para aprimorá-la.",17)
	else:
		var tier: int = world.player.weapons.tuning[index]
		UI.label(box,Arsenal.WEAPONS[index].title+" · "+["Original","Reforçada","Especialista","Obra-prima"][tier],21)
		UI.label(box,"Cada nível: +15% dano, +8% cadência, +10% capacidade e recarga 8% mais rápida.
A melhoria pertence a esta arma e fica salva neste refúgio.",16,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if tier<3:
			var cost := {"scrap":[80,180,360][tier],"parts":[2,5,10][tier]}
			var buy := UI.button(box,"MELHORAR · "+CampaignData.cost_text(cost),func(): world.send_action("tune",{}); close_modal())
			buy.disabled = not world.can_pay(cost) or not world.local_mobile_context().get("shop",false)
		else: UI.label(box,"MELHORIA MÁXIMA",18,UI.LIME)
	UI.button(box,"FECHAR",close_modal)

func show_systems15() -> void:
	if world.exp16.safe(world.player.global_position): show_post16(); return
	if not mode.is_empty(): return
	var box := open_modal("systems15",700)
	UI.label(box,"REFÚGIO E EXPLORAÇÃO",24,UI.LIME)
	if world.game_mode=="rescue":
		UI.label(box,world.rescue16.hint(),16,UI.LIME).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.button(box,"MISSÃO · INTERAGIR COM OBJETIVO",func(): world.send_action("mission16",{}); close_modal())
	if world.resources.pending>0 and not world.waves.running:
		UI.button(box,"SUAS EVOLUÇÕES PENDENTES · %d" % world.resources.pending,func(): close_modal(); show_upgrade())
	UI.label(box,"Classe "+Director15.CLASSES.get(world.player.specialization,"Engenheiro")+" · obras interrompidas por dano ou movimento.",14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"FUNDIR DUAS TORRES IDÊNTICAS PRÓXIMAS",func(): world.send_action("fuse",{}); close_modal())
	UI.button(box,"RECICLAR ARMA SELECIONADA / 20 MADEIRA",func(): world.send_action("recycle",{}); close_modal())
	UI.button(box,"BENTO: SINALIZADOR / 140 SUCATA + 6 COMPONENTES",func(): world.send_action("beacon",{}); close_modal())
	UI.button(box,"USAR EXTRAÇÃO / 4 s",func(): world.send_action("extract",{}); close_modal())
	UI.label(box,"Eventos: segure COLETAR/E junto ao comboio ou sobrevivente. Ninhos roxos podem ser destruídos a tiros.",14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"VOLTAR",close_modal,true)

func show_post16() -> void:
	if not mode.is_empty(): return
	var box := open_modal("post16",740)
	post_buttons16.clear()
	UI.label(box,"POSTO DO FAROL",26,UI.LIME)
	post_info16 = UI.label(box,"Materiais da sua mochila. O relógio e a defesa do Núcleo continuam.",15,UI.MUTED); post_info16.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for entry in [["bag","MARA · REFORÇAR BOLSA · 120 sucata + 8 componentes"],["medkit","DAVI · KIT MÉDICO · 45 sucata"],["light","FERRUGEM · 30 MUNIÇÃO LEVE · 40 sucata"],["exchange","FERRUGEM · 20 madeira → 1 componente"]]:
		var id: String = entry[0]
		var button := UI.button(box,entry[1],func(): world.send_action("post_trade",{"id":id}); close_modal()); button.set_meta("trade_id",id); button.set_meta("base_text",entry[1]); post_buttons16.append(button)
	UI.button(box,"VOLTAR",close_modal,true)

func add_decoy16_button(box: Node) -> void:
	if world.player.bag.count("decoy16")==0: return
	UI.label(box,"Isca: +10 minutos. Próxima horda +20% infectados. Uma por preparação.",14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button := UI.button(box,"USAR ISCA DE DESVIO · 10 MIN",func(): world.send_action("decoy16",{}); close_modal())
	button.disabled = world.waves.running or world.truce16.left>0 or world.truce16.pending or world.truce16.used_after==world.waves.wave or world.game_mode=="rescue"
