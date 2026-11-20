class_name Menu16
extends RefCounted
static func account() -> Node: return Engine.get_main_loop().root.get_node("Account")
static func meta() -> Node: return Engine.get_main_loop().root.get_node("Meta16")
static func account_card(menu: Node,compact: bool = false) -> void:
	var box := UI.vbox(UI.panel(menu.content),4)
	var header := UI.hbox(box,8)
	var badge := RankBadge.new(); badge.level = RankProgress.tier(int(account().local_summary.get("kills",0))) if account().signed_in() else 0
	badge.custom_minimum_size = Vector2(40,46); header.add_child(badge)
	var details := UI.vbox(header,3); details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(details,account().nickname if account().signed_in() else "CONVIDADO",16,UI.LIME)
	var label := UI.label(details,"",12,UI.MUTED); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bar := UI.meter(box); bar.custom_minimum_size.y = 5
	var refresh := func():
		if not is_instance_valid(label): return
		var kills := int(account().local_summary.get("kills",0))
		badge.level = RankProgress.tier(kills) if account().signed_in() else 0
		bar.min_value = 0 if badge.level in [0,10] else RankProgress.THRESHOLDS[badge.level-1]
		bar.max_value = RankProgress.next_goal(kills); bar.value = kills
		label.text = (RankProgress.summary(kills) if account().signed_in() else "Ranking online disponível com conta")+"\n"+PlayClock16.display(meta().clock.total)+" · "+str(meta().balance())+" "+str(Catalog16.data().currency.name)
	refresh.call(); account().changed.connect(refresh); meta().changed.connect(refresh)
	label.tree_exiting.connect(func(): account().changed.disconnect(refresh); meta().changed.disconnect(refresh))
	if compact:
		var enter: Button = UI.button(header,"›",menu.show_account); enter.custom_minimum_size = Vector2(40,44)
	else: menu.menu_button(box,"MINHA CONTA" if account().signed_in() else "ENTRAR / CRIAR CONTA",menu.show_account)
static func profile(menu: Node) -> void:
	menu.clear_content()
	menu.menu_button(menu.content,"‹ VOLTAR",menu.show_main)
	UI.label(menu.content,"SEU SOBREVIVENTE",25,UI.LIME)
	account_card(menu)
	var label := UI.label(menu.content,"",16,UI.MUTED); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var refresh := func():
		if not is_instance_valid(label): return
		label.text = "TEMPO ATIVO NESTE APARELHO\n%s\nSessão: %s · Maior sessão: %s\n\nCONFIRMADO NA CONTA\n%s\n\n%d abates · %d hordas · %d sucata\n\n%s" % [PlayClock16.display(meta().clock.total),PlayClock16.display(meta().clock.session),PlayClock16.display(meta().clock.longest),PlayClock16.display(float(meta().confirmed.get("active_seconds",0))),int(account().local_summary.get("kills",0)),int(account().local_summary.get("hordes",0)),int(account().local_summary.get("scrap",0)),meta().status]
	refresh.call(); meta().changed.connect(refresh); label.tree_exiting.connect(func(): meta().changed.disconnect(refresh))
	menu.menu_button(menu.content,"CLASSE E ACESSÓRIOS DE ELO",func(): menu.show_loadout15("",false))
	menu.menu_button(menu.content,"ATELIÊ DE COSMÉTICOS",func(): shop(menu))
	menu.menu_button(menu.content,"ELOS E RECOMPENSAS",func(): ranks(menu,"elos"))
static func rank_tabs(menu: Node,current: String) -> void:
	var row := UI.hbox(menu.content,5)
	for entry in [["ranking","Classificação"],["elos","Meus elos"],["rewards","Recompensas"]]:
		var id: String = entry[0]
		var button: Button = menu.menu_button(row,entry[1],func(): ranks(menu,id),id==current)
		button.add_theme_font_size_override("font_size",12); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
static func ranks(menu: Node,tab: String = "ranking") -> void:
	if tab=="ranking": menu.show_rankings(); return
	menu.clear_content(); menu.menu_button(menu.content,"‹ VOLTAR",menu.show_main); rank_tabs(menu,tab)
	var kills := int(account().local_summary.get("kills",0)) if account().signed_in() else 0
	var level := RankProgress.tier(kills)
	UI.label(menu.content,"MEUS ELOS" if tab=="elos" else "RECOMPENSAS POR ELO",23,UI.LIME)
	var grid := GridContainer.new(); grid.columns = 2 if MobilePlatform.enabled() else 3; menu.content.add_child(grid)
	for i in range(1,11):
		var card := UI.vbox(UI.panel(grid),4)
		var badge := RankBadge.new(); badge.level = i; badge.custom_minimum_size = Vector2(72,78); card.add_child(badge)
		UI.label(card,RankProgress.TITLES[i],14,UI.LIME if level>=i else UI.MUTED)
		UI.label(card,"%d abates" % RankProgress.THRESHOLDS[i-1],13,UI.MUTED)
		if tab=="rewards": UI.label(card,("Cabeça" if i<=3 else "Mochila visual" if i<=7 else "Aura")+" · Origem: Elo",11,UI.MUTED)
		UI.label(card,"ATUAL" if level==i else "CONQUISTADO" if level>i else "PRÓXIMO" if level+1==i else "BLOQUEADO",11,UI.LIME if level>=i else UI.MUTED)

static func equipment_button(parent: Node, item: Dictionary, class_id: String, preview: Node3D = null) -> void:
	var service := meta()
	var button := UI.button(parent, "", Callable())
	var refresh := func():
		var equipped: bool = service.outfit(class_id).get(item.slot, "") == item.id
		button.text = "RETIRAR · EQUIPADO" if equipped else "EQUIPAR"
		button.disabled = not service.shop_ready()
	button.pressed.connect(func():
		var equipped: bool = service.outfit(class_id).get(item.slot, "") == item.id
		button.disabled = true
		await service.equip(class_id, item.slot, "" if equipped else item.id)
		if is_instance_valid(button):
			refresh.call()
			if is_instance_valid(preview): Cosmetics16.decorate(preview, service.outfit(class_id))
	)
	refresh.call()
	service.changed.connect(refresh)
	button.tree_exiting.connect(func(): service.changed.disconnect(refresh))

static func wardrobe(box: VBoxContainer, class_id: String, height: float) -> void:
	var title := {"engineer": "Engenheiro", "scout": "Batedor", "shooter": "Atirador"}
	UI.label(box, ("MEUS COSMÉTICOS · " if height > 0 else "Classe · ") + title[class_id], 23, UI.LIME)
	var container: Control = box
	if height > 0:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size.y = height
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		container = scroll
	var list := UI.vbox(container, 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slots := {"head": "Cabeça", "outfit": "Roupa", "backpack": "Mochila visual", "effect": "Efeito"}
	for item in Catalog16.data().cosmetics:
		if item.class_id not in ["all", class_id] or not meta().has_cosmetic(item.id): continue
		var card := UI.vbox(UI.panel(list), 3)
		UI.label(card, item.title, 17).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.label(card, slots[item.slot], 12, UI.MUTED)
		equipment_button(card, item, class_id)
	if list.get_child_count() == 0:
		UI.label(list, "Você ainda não tem cosméticos para esta classe. Visite o Ateliê no menu principal.", 15, UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func shop(menu: Node,filter_class: String = "engineer") -> void:
	menu.clear_content(); menu.menu_button(menu.content,"‹ VOLTAR",menu.show_main)
	UI.label(menu.content,"ATELIÊ DOS SOBREVIVENTES",23,UI.LIME)
	UI.label(menu.content,"%d %s · somente aparência" % [meta().balance(),str(Catalog16.data().currency.name)],16,UI.LIME)
	UI.label(menu.content,meta().status,13,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(menu.content,"%d Brotos por horda vencida. Saldo e compras ficam salvos neste aparelho." % int(Catalog16.data().currency.horde_reward),12,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var filter := OptionButton.new(); menu.content.add_child(filter); filter.custom_minimum_size.y = 44
	var filters := ["engineer","scout","shooter","all","owned"]
	for title in ["Engenheiro","Batedor","Atirador","Universais","Obtidos"]: filter.add_item(title)
	filter.select(filters.find(filter_class)); filter.item_selected.connect(func(i): shop(menu,filters[i]))
	# A live, clay model preview uses the same cosmetic renderer as gameplay.
	var preview := SubViewportContainer.new(); preview.custom_minimum_size = Vector2(260,170); preview.stretch = true; menu.content.add_child(preview)
	var viewport := SubViewport.new(); viewport.size = Vector2i(340,200); viewport.transparent_bg = false; viewport.own_world_3d = true; preview.add_child(viewport)
	var model_root := Node3D.new(); viewport.add_child(model_root)
	VisualFactory.lighting(model_root)
	VisualFactory.cylinder(model_root,1.0,.12,Vector3(0,-.08,0),Color("263e42"))
	var actor := Node3D.new(); actor.name = "Preview"; model_root.add_child(actor)
	var rig := VisualFactory.human(actor,Color("849b6b"),true)
	var preview_class := filter_class if filter_class in filters.slice(0, 3) else str(Director15.selected_class)
	Cosmetics16.decorate(rig,meta().outfit(preview_class))
	var camera := Camera3D.new(); viewport.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 2.7; camera.position = Vector3(3,2.1,-4); camera.look_at(Vector3(0,1,0)); camera.current = true
	menu.menu_button(menu.content,"GIRAR PRÉVIA",func(): actor.rotation.y += PI/4)
	for item in Catalog16.data().cosmetics:
		var owned: bool = meta().has_cosmetic(item.id)
		if (filter_class=="owned" and not owned) or (filter_class!="owned" and item.class_id!=filter_class): continue
		var id: String = item.id
		var card := UI.vbox(UI.panel(menu.content),4)
		UI.label(card,item.title,17,UI.LIME)
		UI.label(card,item.description,13,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		menu.menu_button(card,"PRÉVIA",func(): Cosmetics16.decorate(rig,{item.slot:id}))
		if owned:
			var cls: String = Director15.selected_class if item.class_id=="all" else item.class_id
			equipment_button(card, item, cls, rig)
		elif item.get("unlock","")=="titan16":
			UI.label(card,"EXCLUSIVO · participe da derrota do Titã",13,UI.LIME).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			var buy: Button = menu.menu_button(card,"COMPRAR · %d" % int(item.price),func(): confirm_purchase(menu,id,filter_class))
			buy.disabled = not meta().shop_ready() or meta().balance()<int(item.price)
static func confirm_purchase(menu: Node,id: String,filter_class: String) -> void:
	menu.clear_content(); var item := Catalog16.cosmetic(id)
	if item.has("unlock"): shop(menu,filter_class); return
	UI.label(menu.content,"CONFIRMAR COMPRA",25,UI.LIME)
	UI.label(menu.content,"%s · %d %s" % [item.title,int(item.price),str(Catalog16.data().currency.name)],18)
	menu.menu_button(menu.content,"CONFIRMAR",func(): await meta().purchase(id); shop(menu,filter_class),true)
	menu.menu_button(menu.content,"CANCELAR",func(): shop(menu,filter_class))
