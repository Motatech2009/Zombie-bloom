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

var held_icon: TextureRect
var wood_count: Label
var parts_count: Label
var status_text: Label
var airdrop_text: Label
var airdrop_map_info: Label
var map_focus: Variant = null
var drop_map_stamp: String = ""

func make_panel(left: float,top: float,right: float,bottom: float,preset: int) -> PanelContainer:
	var panel := UI.panel(root)
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = left; panel.offset_top = top; panel.offset_right = right; panel.offset_bottom = bottom
	var frame := UI.style(Color(.035,.075,.1,.94),Color("344d5a"),10)
	frame.content_margin_left = 14; frame.content_margin_right = 14
	frame.content_margin_top = 10; frame.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",frame)
	return panel

func create_top() -> void:
	var vitals := make_panel(18,14,326,112,Control.PRESET_TOP_LEFT)
	var vitals_box := UI.vbox(vitals,5)
	var hp_row := UI.hbox(vitals_box,9)
	ItemIcons.image(hp_row,"health",Vector2(23,23))
	health_text = UI.label(hp_row,"",16)
	health_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_text = UI.label(hp_row,"",11,UI.MUTED)
	health_bar = UI.meter(vitals_box,Color("e99b84"))
	var core_row := UI.hbox(vitals_box,9)
	ItemIcons.image(core_row,"core",Vector2(23,23))
	core_text = UI.label(core_row,"",14,Color("9ddde0"))
	core_bar = UI.meter(vitals_box,Color("70c9d5"))
	var siege := make_panel(-158,14,158,91,Control.PRESET_CENTER_TOP)
	var row := UI.hbox(siege,10)
	ItemIcons.image(row,"wave",Vector2(43,43))
	var wave_box := UI.vbox(row,1)
	wave_text = UI.label(wave_box,"",21)
	wave_detail = UI.label(wave_box,"",14,Color("edbd72"))
	phase_text = UI.label(wave_box,"",10,UI.MUTED)
	var depot := make_panel(-350,14,-18,99,Control.PRESET_TOP_RIGHT)
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
	airdrop_text.offset_top = 106; airdrop_text.offset_bottom = 129
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
	var belt := HBoxContainer.new()
	root.add_child(belt)
	belt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	belt.offset_left = -357; belt.offset_right = 357
	belt.offset_top = -100; belt.offset_bottom = -16
	belt.add_theme_constant_override("separation",6)
	for i in range(9):
		var index := i
		var button := ItemSlot.new()
		button.key_number = i+1
		button.pressed.connect(func(): world.player.bag.selected = index)
		belt.add_child(button)
		hotbar.append(button)
	hints = make_panel(-300,-119,-18,-16,Control.PRESET_BOTTOM_RIGHT)
	var hint_box := UI.vbox(hints,6)
	var actions := UI.hbox(hint_box,5)
	for entry in [["map","M",show_routes],["bag","I",show_inventory],["build","B",show_build_catalog]]:
		var button := UI.button(actions,entry[1],entry[2])
		button.icon = ItemIcons.get_icon(entry[0])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",27)
		button.custom_minimum_size = Vector2(76,38)
		var style := compact_style(); style.content_margin_top = 3; style.content_margin_bottom = 3
		button.add_theme_stylebox_override("normal",style)
	location_text = UI.label(hint_box,"",11,UI.MUTED)
	location_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_button = Button.new(); root.add_child(next_button); next_button.hide()
	quota_text = UI.label(root,"",12,Color("d9c79c"))
	quota_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	quota_text.offset_left = -320; quota_text.offset_right = 320; quota_text.offset_top = 99; quota_text.offset_bottom = 119
	quota_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_text = UI.label(root,"",14,Color("98d9f1"))
	status_text.position = Vector2(30,119)
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

func _process(delta: float) -> void:
	choice_cooldown = maxf(0,choice_cooldown-delta)
	super._process(delta)
	var actor: Node3D = world.player
	for i in range(9):
		var item: Dictionary = actor.bag.slots[i]
		hotbar[i].set_item(item.id,int(item.qty),actor.bag.selected==i)
	scrap_text.text = str(world.resources.scrap)
	wood_count.text = str(world.stock.wood)
	parts_count.text = str(world.stock.parts)
	status_text.text = "CONGELADO · %.1f s" % actor.slow_left if actor.slow_left>0 else "CAÍDO · Aguarde um aliado" if actor.health.dead else ""
	var hand: String = actor.bag.hand()
	weapon_text.text = ItemBag.TITLES.get(hand,"MÃOS LIVRES").to_upper()
	held_icon.texture = ItemIcons.get_icon(hand)
	if hand in ItemBag.WEAPON_IDS:
		var index := ItemBag.WEAPON_IDS.find(hand)
		ammo_text.text = "%d / %d" % [actor.weapons.ammo[index],actor.bag.count(ItemBag.AMMO_IDS[index])]
	else: ammo_text.text = "%d/18" % (18-actor.bag.free_slots())
	power_text.text = "BOLSA · %d espaços livres" % actor.bag.free_slots()
	quota_text.text = "CONSTRUÇÕES %d/%d   ·   EQUIPE %d   ·   HOSTIS ×%d" % [world.built_this_round,world.build_quota(),world.party_count(),world.team_multiplier()]
	gather_bar.visible = actor.gather_target!=null or actor.gather_progress>0
	gather_label.visible = gather_bar.visible
	if gather_bar.visible:
		gather_bar.max_value = actor.gather_duration
		gather_bar.value = actor.gather_progress
		gather_label.text = "SEGURE E · "+{"loot":"coletando para a bolsa","deposit":"guardando no Núcleo","revive":"reanimando aliado","repair":"reparando defesa"}.get(actor.gather_kind,"coletando")
	airdrop_text.text = airdrop_summary()
	if mode=="routes":
		var stamp := str(world.airdrops.serial)+str(world.airdrops.state.get("collected",true))
		if stamp!=drop_map_stamp: close_modal(); show_routes()
		if is_instance_valid(airdrop_map_info): airdrop_map_info.text = airdrop_summary()+"\n"+airdrop_route()
	if world.builder.active: build_text.text = "1–9 / 0 peça · Q gira · clique instala · B sai\n"+world.builder.reason
	if mode=="inventory": refresh_inventory()
	if world.area_index==-1 and actor.position.distance_to(world.core.position)<4: build_text.text = "SEGURE E / GUARDAR MATERIAIS · I / DEPÓSITO"
	elif world.area_index!=-1 and not world.builder.active: build_text.text = "SEGURE E nas caixas · Carga na bolsa: leve ao Núcleo"

func open_modal(next_mode: String,width: float = 800) -> VBoxContainer:
	var box := super.open_modal(next_mode,width)
	if world.connected_game() or next_mode in ["inventory","equipment"]: get_tree().paused = false
	return box

func show_inventory() -> void:
	var box := open_modal("inventory",1210)
	UI.label(box,"BOLSA / BARRA RÁPIDA",29,UI.LIME)
	UI.label(box,"Clique dois espaços para trocar. Os espaços 1–9 ficam na barra rápida.",15,UI.MUTED)
	inventory_status = UI.label(box,"Primeiros nove espaços = barra rápida. Clique dois espaços para trocar.",15,UI.MUTED)
	var row := UI.hbox(box,20)
	var left := UI.vbox(row,8)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation",5)
	grid.add_theme_constant_override("v_separation",5)
	left.add_child(grid)
	inventory_buttons.clear()
	for i in range(18):
		var index := i
		var button := ItemSlot.new()
		button.key_number = index+1
		button.pressed.connect(func():
			if inventory_selected<0: inventory_selected = index
			else:
				world.send_action("swap",{"a":inventory_selected,"b":index})
				inventory_selected = -1
		)
		grid.add_child(button)
		button.custom_minimum_size = Vector2(78,88)
		button.add_theme_font_size_override("font_size",12)
		inventory_buttons.append(button)
	var controls := UI.hbox(left,8)
	UI.button(controls,"GUARDAR SELEÇÃO",func():
		if inventory_selected>=0: world.send_action("store",{"slot":inventory_selected}); inventory_selected = -1
	)
	UI.button(controls,"DESCARTAR SELEÇÃO",func():
		if inventory_selected>=0: world.send_action("drop",{"slot":inventory_selected}); inventory_selected = -1
	)
	var right := UI.vbox(row,7)
	right.custom_minimum_size.x = 350
	UI.label(right,"DEPÓSITO DO NÚCLEO",21,UI.LIME)
	UI.label(right,"Guardar/retirar exige estar junto ao Núcleo. Materiais guardados pagam construções.",14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 260
	right.add_child(scroll)
	var list := UI.vbox(scroll,5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depot_buttons.clear()
	for id in ItemBag.IDS:
		var chosen: String = id
		depot_buttons[id] = UI.button(list,ItemBag.TITLES[id]+" / retirar",func(): world.send_action("withdraw",{"id":chosen,"qty":20}))
	UI.button(box,"CONTINUAR / I",close_modal,true)
	refresh_inventory()

func refresh_inventory() -> void:
	if not is_instance_valid(inventory_status): return
	inventory_status.text = "%d/18 espaços · Núcleo: %d sucata, %d madeira, %d componentes · Seleção %s" % [18-world.player.bag.free_slots(),world.resources.scrap,world.stock.wood,world.stock.parts,str(inventory_selected+1) if inventory_selected>=0 else "—"]
	for id in depot_buttons:
		depot_buttons[id].text = "%s ×%d / retirar" % [ItemBag.TITLES[id],world.depot_count(id)]
		depot_buttons[id].disabled = world.depot_count(id)<=0
		depot_buttons[id].icon = ItemIcons.get_icon(id)
		depot_buttons[id].expand_icon = true
		depot_buttons[id].add_theme_constant_override("icon_max_width",28)
	for i in range(inventory_buttons.size()):
		var item: Dictionary = world.player.bag.slots[i]
		inventory_buttons[i].set_item(item.id,int(item.qty),inventory_selected==i)

func show_equipment() -> void:
	show_inventory()

func show_shop() -> void:
	var box := open_modal("shop",860)
	UI.label(box,"BENTO / EQUIPAMENTOS E MUNIÇÃO",27,UI.LIME)
	UI.label(box,"Estoque do Núcleo: %d sucata · compras entram na bolsa se couberem." % world.resources.scrap,16,UI.MUTED)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 380
	box.add_child(scroll)
	var list := UI.vbox(scroll,7)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(1,Arsenal.WEAPONS.size()):
		var index := i
		var button := UI.button(list,"%s / %d sucata" % [Arsenal.WEAPONS[i].title,Arsenal.PRICES[i]],func(): world.send_action("buy",{"weapon":index}))
		button.icon = ItemIcons.get_icon(ItemBag.WEAPON_IDS[i])
		button.expand_icon = true; button.add_theme_constant_override("icon_max_width",48)
		button.tooltip_text = Arsenal.DESCRIPTIONS[i]
		UI.label(list,Arsenal.DESCRIPTIONS[i],12,UI.MUTED)
		button.disabled = world.player.bag.count(ItemBag.WEAPON_IDS[i])>0
	for item in Arsenal.PACKS:
		var id: String = item
		var entry: Array = Arsenal.PACKS[id]
		var button := UI.button(list,"%d %s / %d sucata" % [entry[0],ItemBag.TITLES[id],entry[1]],func(): world.send_action("service",{"id":id}))
		button.icon = ItemIcons.get_icon(id); button.expand_icon = true; button.add_theme_constant_override("icon_max_width",38)

	UI.button(box,"VOLTAR",close_modal,true)

func request_upgrade() -> void:
	if choice_cooldown>0: return
	super.request_upgrade()

func show_upgrade() -> void:
	var offers: Array = world.upgrades.offers
	if offers.is_empty():
		if world.is_client: return
		offers = world.upgrades.roll()
	var box := open_modal("upgrade",1000)
	UI.label(box,"EVOLUÇÃO DO GRUPO",30,UI.LIME)
	UI.label(box,"A primeira escolha válida beneficia todos. No cooperativo, a simulação continua.",16,UI.MUTED)
	for i in range(offers.size()):
		var index := i
		UI.button(box,offers[i].title+" · "+offers[i].text,func(): world.send_action("choice",{"index":index}); choice_cooldown = .5; close_modal())

func show_result() -> void:
	var box := open_modal("result",760)
	UI.label(box,"REFÚGIO DEFENDIDO" if world.won else "O GRUPO CAIU",34,UI.LIME)
	UI.label(box,world.ending_reason,19,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(box,"Horda %d · %d eliminações" % [world.waves.wave,world.kills],20)
	if not world.connected_game(): UI.button(box,"RETOMAR CHECKPOINT",func(): load("res://scripts/campaign/campaign_world.gd").resume_requested = true; restart())
	UI.button(box,"VOLTAR AO MENU",menu,true)

func menu() -> void:
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
	if not world.connected_game(): super.show_pause(); return
	if not mode.is_empty() or world.phase=="ended": return
	var box := open_modal("pause",640)
	UI.label(box,"SALA EM ANDAMENTO",32,UI.LIME)
	UI.label(box,"O relógio e os inimigos continuam enquanto este menu está aberto.",18,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"CONTINUAR",close_modal,true)
	if not world.is_client:
		var save := UI.button(box,"SALVAR REFÚGIO",func(): world.save_checkpoint(); close_modal())
		save.disabled = world.area_index!=-1 or world.phase!="prep" or world.resources.pending>0
	UI.button(box,"CONFIGURAÇÕES",show_settings)
	UI.button(box,"ENCERRAR SALA" if not world.is_client else "SAIR DA SALA",menu)

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
		var select := UI.button(card,"CONSTRUIR",func(): close_modal(); world.builder.selected = index; world.builder.set_active(true))
		select.disabled = not world.can_pay(data.cost) or world.built_this_round>=world.build_quota()
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
