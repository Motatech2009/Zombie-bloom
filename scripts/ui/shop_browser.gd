class_name ShopBrowser
extends RefCounted
## Desktop vendor: categories, a browsable catalogue and one explicit purchase.
var hud: Node
var category := 0
var selection := 0
var entries: Array[Dictionary] = []
var tabs: Array[Button] = []
var buttons: Array[Button] = []
var list: VBoxContainer
var detail: VBoxContainer
var balance: Label
var price: Label
var buy: Button
var feedback: Label

func show_in(owner: Node) -> void:
	hud = owner
	var box: VBoxContainer = hud.open_modal("shop",1060)
	var header := UI.hbox(box,18)
	var brand := UI.vbox(header,3); brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(brand,"BENTO",32,UI.LIME)
	UI.label(brand,"ARMAS, MUNIÇÃO E MAIS UMA CHANCE.",12,UI.MUTED)
	balance = UI.label(header,"",20,Color("edcf95"))
	UI.button(box,"OFICINA / MELHORAR ARMA EQUIPADA",hud.show_weapon_workshop)
	var nav := UI.hbox(box,8)
	for i in range(3):
		var index := i
		var tab := UI.button(nav,["ARMAS","MUNIÇÃO","SUPRIMENTOS"][i],func(): category = index; populate())
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.append(tab)
	var body := UI.hbox(box,18)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(410,330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(scroll)
	list = UI.vbox(scroll,7); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card := UI.panel(body); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel",UI.style(Color("0f232a"),Color("3b5654"),12))
	detail = UI.vbox(card,14); detail.custom_minimum_size.x = 330
	var footer := UI.hbox(box,12)
	UI.label(footer,"Compras vão para a mochila. Materiais do Núcleo pagam a conta.",13,UI.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(footer,"FECHAR / ESC",hud.close_modal)
	populate()

func populate() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	entries.clear(); buttons.clear()
	for i in range(tabs.size()): tabs[i].modulate = UI.LIME if i==category else Color.WHITE
	if category==0:
		for i in range(1,Arsenal.WEAPONS.size()):
			entries.append({"id":ItemBag.WEAPON_IDS[i],"title":Arsenal.WEAPONS[i].title,"description":Arsenal.DESCRIPTIONS[i],"qty":1,"cost":Arsenal.PRICES[i],"weapon":i})
	else:
		for id in Arsenal.PACKS:
			if (id in ItemBag.AMMO_IDS)!=(category==1): continue
			entries.append({"id":id,"title":ItemBag.TITLES[id],"description":"Suprimentos para continuar explorando e defender seu refúgio.","qty":Arsenal.PACKS[id][0],"cost":Arsenal.PACKS[id][1],"weapon":-1})
	for i in range(entries.size()):
		var index := i; var entry: Dictionary = entries[i]
		var button := UI.button(list,"%s\n%d sucata%s" % [entry.title,entry.cost," · ×%d" % entry.qty if entry.qty>1 else ""],func(): select_item(index))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.icon = ItemIcons.get_icon(entry.id); button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",42); button.add_theme_constant_override("h_separation",14)
		button.add_theme_font_size_override("font_size",16); button.custom_minimum_size.y = 76
		buttons.append(button)
	select_item(0)

func select_item(index: int) -> void:
	selection = index
	for child in detail.get_children(): detail.remove_child(child); child.queue_free()
	if entries.is_empty(): return
	var entry: Dictionary = entries[index]
	var image := ItemIcons.image(detail,entry.id,Vector2(112,100)); image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.label(detail,entry.title.to_upper(),23,UI.LIME).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(detail,entry.description,15,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if entry.weapon>=0:
		var spec: Resource = Arsenal.WEAPONS[entry.weapon]
		UI.label(detail,"DANO %s   /   ALCANCE %s" % [spec.values.damage,spec.values.range],14)
	else: UI.label(detail,"PACOTE COM %d UNIDADES" % entry.qty,14)
	price = UI.label(detail,"%d SUCATA" % entry.cost,25,Color("edcf95"))
	feedback = UI.label(detail,"",13,UI.MUTED); feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buy = UI.button(detail,"COMPRAR",purchase,true)
	for i in range(buttons.size()): buttons[i].modulate = UI.LIME if i==index else Color.WHITE
	refresh()

func refresh() -> void:
	if not is_instance_valid(balance) or not is_instance_valid(buy) or entries.is_empty(): return
	balance.text = "%d SUCATA" % hud.world.resources.scrap
	var entry: Dictionary = entries[selection]
	var reason := ""
	if not hud.world.local_mobile_context().get("shop",false): reason = "Aproxime-se do Bento entre hordas."
	elif hud.world.resources.scrap<int(entry.cost): reason = "Sucata insuficiente."
	elif entry.weapon>=0 and hud.world.player.bag.count(entry.id)>0: reason = "Você já tem esta arma."
	else:
		var bag := ItemBag.new(); bag.restore(hud.world.player.bag.dump())
		if bag.add(entry.id,entry.qty)!=entry.qty: reason = "Sem espaço na mochila para este item."
	feedback.text = reason if not reason.is_empty() else "Pronto para levar."
	buy.disabled = not reason.is_empty()

func purchase() -> void:
	refresh()
	if buy.disabled: return
	var entry: Dictionary = entries[selection]
	hud.world.send_action("buy",{"weapon":entry.weapon}) if entry.weapon>=0 else hud.world.send_action("service",{"id":entry.id})
	refresh()
