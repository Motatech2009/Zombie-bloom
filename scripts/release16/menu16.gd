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
		label.text = (RankProgress.summary(kills) if account().signed_in() else "Entre para registrar seu progresso")+"\n"+PlayClock16.display(meta().clock.total)+" · "+str(meta().confirmed.get("balance",0))+" "+str(Catalog16.data().currency.name)
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
static func shop(menu: Node,filter_class: String = "engineer") -> void:
	menu.clear_content(); menu.menu_button(menu.content,"‹ VOLTAR",menu.show_main)
	UI.label(menu.content,"ATELIÊ DOS SOBREVIVENTES",23,UI.LIME)
	UI.label(menu.content,"%d %s · somente aparência" % [int(meta().confirmed.get("balance",0)),str(Catalog16.data().currency.name)],16,UI.LIME)
	UI.label(menu.content,meta().status,13,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(menu.content,"100 moedas por horda elegível. A partida precisa de registro online; pendências offline dependem de validação. Compras exigem conexão.",12,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	Cosmetics16.decorate(rig,meta().outfit(Director15.selected_class))
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
			menu.menu_button(card,"EQUIPAR",func(): await meta().equip(cls,item.slot,id); shop(menu,filter_class))
			menu.menu_button(card,"RETIRAR",func(): await meta().equip(cls,item.slot,""); shop(menu,filter_class))
		elif item.get("unlock","")=="titan16":
			UI.label(card,"EXCLUSIVO · participe da derrota do Titã",13,UI.LIME).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			var buy: Button = menu.menu_button(card,"COMPRAR · %d" % int(item.price),func(): confirm_purchase(menu,id,filter_class))
			buy.disabled = meta().busy or not account().signed_in() or meta().api_url.is_empty() or int(meta().confirmed.get("balance",0))<int(item.price)
static func confirm_purchase(menu: Node,id: String,filter_class: String) -> void:
	menu.clear_content(); var item := Catalog16.cosmetic(id)
	if item.has("unlock"): shop(menu,filter_class); return
	UI.label(menu.content,"CONFIRMAR COMPRA",25,UI.LIME)
	UI.label(menu.content,"%s · %d %s" % [item.title,int(item.price),str(Catalog16.data().currency.name)],18)
	menu.menu_button(menu.content,"CONFIRMAR",func(): await meta().purchase(id); shop(menu,filter_class),true)
	menu.menu_button(menu.content,"CANCELAR",func(): shop(menu,filter_class))
