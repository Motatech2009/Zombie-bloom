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

func create_bottom() -> void:
	super.create_bottom()
	var belt := HBoxContainer.new()
	root.add_child(belt)
	belt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	belt.offset_left = -292
	belt.offset_right = 292
	belt.offset_top = -69
	belt.offset_bottom = -10
	belt.add_theme_constant_override("separation",3)
	for i in range(9):
		var index := i
		var button := UI.button(belt,"%d\n—" % (i+1),func(): world.player.bag.selected = index)
		button.custom_minimum_size = Vector2(61,58)
		button.add_theme_font_size_override("font_size",12)
		var style := compact_style()
		style.content_margin_left = 4
		style.content_margin_right = 4
		button.add_theme_stylebox_override("normal",style)
		hotbar.append(button)
	quota_text = UI.label(root,"",13,UI.MUTED)
	quota_text.position = Vector2(18,81)
	quota_text.add_theme_color_override("font_color",Color("d8e5d4"))
	quota_text.add_theme_color_override("font_shadow_color",Color("122b33"))
	quota_text.add_theme_constant_override("shadow_offset_y",1)
	gather_bar = UI.meter(root,UI.LIME)
	gather_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gather_bar.offset_left = -130
	gather_bar.offset_right = 130
	gather_bar.offset_top = 90
	gather_bar.offset_bottom = 98
	gather_label = UI.label(root,"",15,UI.LIME)
	gather_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gather_label.offset_left = -210
	gather_label.offset_right = 210
	gather_label.offset_top = 102
	gather_label.offset_bottom = 135
	gather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _process(delta: float) -> void:
	choice_cooldown = maxf(0,choice_cooldown-delta)
	super._process(delta)
	var actor: Node3D = world.player
	for i in range(9):
		var item: Dictionary = actor.bag.slots[i]
		hotbar[i].text = "%d\n%s%s" % [i+1,ItemBag.SHORT.get(item.id,"—")," ×%d" % item.qty if item.qty>1 else ""]
		hotbar[i].modulate = UI.LIME if actor.bag.selected==i else Color.WHITE
	var hand: String = actor.bag.hand()
	weapon_text.text = ItemBag.TITLES.get(hand,"MÃOS LIVRES").to_upper()
	if hand in ItemBag.WEAPON_IDS:
		var index := ItemBag.WEAPON_IDS.find(hand)
		ammo_text.text = "%d | %d" % [actor.weapons.ammo[index],actor.bag.count(ItemBag.AMMO_IDS[index])]
	else: ammo_text.text = "%d/18" % (18-actor.bag.free_slots())
	power_text.text = "I mochila · %d espaços livres" % actor.bag.free_slots()
	quota_text.text = "DEFESAS %d/%d nesta horda · %d jogador(es) · zumbis x%d" % [world.built_this_round,world.build_quota(),world.party_count(),world.team_multiplier()]
	gather_bar.visible = actor.gather_target!=null or actor.gather_progress>0
	gather_label.visible = gather_bar.visible
	if gather_bar.visible:
		gather_bar.max_value = actor.gather_duration
		gather_bar.value = actor.gather_progress
		gather_label.text = "SEGURE E · "+{"loot":"coletando para a bolsa","deposit":"guardando no Núcleo","revive":"reanimando aliado","repair":"reparando defesa"}.get(actor.gather_kind,"coletando")
	if mode=="inventory": refresh_inventory()
	if world.area_index==-1 and actor.position.distance_to(world.core.position)<4: build_text.text = "SEGURE E / GUARDAR MATERIAIS · I / DEPÓSITO"
	elif world.area_index!=-1 and not world.builder.active: build_text.text = "SEGURE E nas caixas · Carga na bolsa: leve ao Núcleo"

func open_modal(next_mode: String,width: float = 800) -> VBoxContainer:
	var box := super.open_modal(next_mode,width)
	if world.connected_game() or next_mode in ["inventory","equipment"]: get_tree().paused = false
	return box

func show_inventory() -> void:
	var box := open_modal("inventory",1100)
	UI.label(box,"BOLSA / BARRA RÁPIDA",29,UI.LIME)
	UI.label(box,"Clique dois espaços para trocar. Os espaços 1–9 ficam na barra rápida.",15,UI.MUTED)
	inventory_status = UI.label(box,"Primeiros nove espaços = barra rápida. Clique dois espaços para trocar.",15,UI.MUTED)
	var row := UI.hbox(box,20)
	var left := UI.vbox(row,8)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation",5)
	grid.add_theme_constant_override("v_separation",5)
	left.add_child(grid)
	inventory_buttons.clear()
	for i in range(18):
		var index := i
		var button := UI.button(grid,"",func():
			if inventory_selected<0: inventory_selected = index
			else:
				world.send_action("swap",{"a":inventory_selected,"b":index})
				inventory_selected = -1
		)
		button.custom_minimum_size = Vector2(94,72)
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
	for i in range(inventory_buttons.size()):
		var item: Dictionary = world.player.bag.slots[i]
		inventory_buttons[i].text = "%d%s\n%s\n%d" % [i+1," [barra]" if i<9 else "",ItemBag.SHORT.get(item.id,"—"),item.qty]
		inventory_buttons[i].modulate = UI.LIME if inventory_selected==i else Color.WHITE

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
	for i in range(1,5):
		var index := i
		var button := UI.button(list,"%s / %d sucata" % [CampaignData.WEAPONS[i].title,CampaignData.PRICES[i]],func(): world.send_action("buy",{"weapon":index}))
		button.disabled = world.player.bag.count(ItemBag.WEAPON_IDS[i])>0
	for entry in [["light",24,12],["shell",8,18],["rifle_ammo",30,25],["rocket",3,60],["grenade",2,45],["medkit",1,30],["wood",8,35],["parts",3,45]]:
		var id: String = entry[0]
		UI.button(list,"%d %s / %d sucata" % [entry[1],ItemBag.TITLES[id],entry[2]],func(): world.send_action("service",{"id":id}))
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
