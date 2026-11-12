extends "res://scripts/ui/hud.gd"
var material_text: Label
var location_text: Label

func create_bottom() -> void:
	var left := UI.panel(root)
	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 24
	left.offset_right = 550
	left.offset_top = -200
	left.offset_bottom = -24
	var box := UI.vbox(left,6)
	location_text = UI.label(box,"REFÚGIO / PREPARAÇÃO",14,UI.LIME)
	material_text = UI.label(box,"",15)
	UI.label(box,"B construir · G melhorar · E reparar · F portão",14,UI.MUTED)
	var row := UI.hbox(box,6)
	UI.button(row,"M / ÁREAS",show_routes)
	UI.button(row,"V / ARMEIRO",func():
		if mode.is_empty(): world.open_shop()
	)
	UI.button(row,"ESPAÇO / HORDA",func():
		if mode.is_empty(): world.waves.start()
	)
	var right := UI.panel(root)
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_left = -645
	right.offset_right = -24
	right.offset_top = -176
	right.offset_bottom = -24
	var column := UI.vbox(right,6)
	var stats := UI.hbox(column,16)
	weapon_text = UI.label(stats,"PISTOLA",21)
	weapon_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_text = UI.label(stats,"12 / 12",24,UI.LIME)
	reload_bar = UI.meter(column,Color("edbf7b"))
	var guns := UI.hbox(column,8)
	for i in range(3):
		var index := i
		var button := UI.button(guns,"%d %s" % [i+1,Catalog.WEAPONS[i].title],func():
			if mode.is_empty() and not world.builder.active: world.player.weapons.equip(index)
		)
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.append(button)
	notice_text = UI.label(root,"",18,UI.LIME)
	notice_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_text.offset_left = -560
	notice_text.offset_right = 560
	notice_text.offset_top = 132
	notice_text.offset_bottom = 225
	notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power_text = UI.label(root,"",16,Color("cab8f8"))
	power_text.position = Vector2(28,245)
	build_text = UI.label(root,"",16,UI.LIME)
	build_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	build_text.offset_left = -610
	build_text.offset_right = 610
	build_text.offset_top = -270
	build_text.offset_bottom = -215
	build_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _process(delta: float) -> void:
	super._process(delta)
	wave_text.text = "HORDA %02d / 08" % world.waves.wave
	core_text.text = "NÚCLEO N%d  %d / %d" % [world.core_tier,ceili(world.core.health.current),ceili(world.core.health.maximum)]
	material_text.text = "%d madeira   ·   %d componentes   ·   %d/80 defesas" % [world.stock.wood,world.stock.parts,get_tree().get_nodes_in_group("campaign_structure").size()]
	location_text.text = "REFÚGIO / FORTALEÇA SUA BASE" if world.area_index==-1 else CampaignData.AREAS[world.area_index].title
	if world.area_index>=0:
		var remaining: int = int(CampaignData.AREAS[world.area_index].count)-world.areas[world.area_index].dead.size()
		phase_text.text = "EXPEDIÇÃO"
		wave_detail.text = "%d hostis na área" % remaining if remaining>0 else "Área limpa · recolha reservas"
	for i in range(3):
		slots[i].disabled = not world.player.weapons.owned[i]
		slots[i].text = "%d %s%s" % [i+1,Catalog.WEAPONS[i].title,"" if world.player.weapons.owned[i] else " / loja"]
	if world.builder.active:
		build_text.text = "1 Barricada · 2 Torreta · 3 Muro · 4 Portão · 5 Estacas · 6 Apoio · Q gira\n"+world.builder.reason
	elif world.area_index>=0:
		build_text.text = "E recolhe reservas após limpar a área · Retorno pela zona ao sul · M detalhes"
	elif world.phase=="prep":
		var target: Node3D = world.nearest_structure()
		if target==world.core:
			build_text.text = "G melhora o Núcleo · "+CampaignData.cost_text({"scrap":75*world.core_tier,"wood":10*world.core_tier,"parts":5*world.core_tier}) if world.core_tier<4 else "NÚCLEO N4 / capacidade máxima"
		elif target!=null:
			build_text.text = "G melhorar · "+CampaignData.cost_text(target.upgrade_cost())+" · X desmontar" if target.tier<3 else "DEFESA N3 · E reparar · X desmontar"
		else: build_text.text = "ESPAÇO inicia a horda · B catálogo de construção · M áreas · V armeiro próximo"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build") and mode.is_empty() and not world.builder.active and world.phase=="prep" and world.area_index==-1:
		get_viewport().set_input_as_handled()
		show_build_catalog()
		return
	super._unhandled_input(event)

func show_build_catalog() -> void:
	if not mode.is_empty() or world.phase!="prep" or world.area_index!=-1: return
	var box := open_modal("catalog",1050)
	UI.label(box,"CONSTRUA SEU REFÚGIO",32,UI.LIME)
	UI.label(box,"Rotacione com Q. Melhorias N1 → N3 com G perto da peça; Núcleo até N4.",16,UI.MUTED)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	box.add_child(grid)
	var descriptions := ["Barreira barata para as primeiras camadas.","Dispara automaticamente na horda; precisa de visão.","Mais integridade para as linhas externas.","F abre/fecha. Preserve rotas de passagem.","Causam dano em infectados que pisam nelas.","Cura você e repara a base próxima na preparação."]
	for i in range(6):
		var index := i
		var data: Dictionary = CampaignData.PIECES[i]
		var panel := UI.panel(grid)
		panel.custom_minimum_size = Vector2(320,190)
		var card := UI.vbox(panel,8)
		UI.label(card,"%d / %s" % [i+1,data.title.to_upper()],19,data.color.lightened(.3))
		UI.label(card,descriptions[i],15,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.label(card,CampaignData.cost_text(data.cost),14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var button := UI.button(card,"SELECIONAR",func():
			close_modal()
			world.builder.selected = index
			world.builder.set_active(true)
		)
		button.disabled = not world.can_pay(data.cost)
	UI.button(box,"VOLTAR",close_modal)

func show_routes() -> void:
	if not mode.is_empty() or world.phase=="ended": return
	if world.phase=="combat": world.notify("Termine a horda antes de sair do refúgio."); return
	world.builder.set_active(false)
	var box := open_modal("routes",980)
	UI.label(box,"ROTAS DE COLETA",32,UI.LIME)
	if world.area_index>=0:
		UI.label(box,"O refúgio aguarda sua volta. Nenhuma horda começa durante uma expedição.",17,UI.MUTED)
		UI.label(box,"Elimine todos os hostis e recolha as três reservas com E.\nA extração fica ao sul. Você pode recuar antes de terminar;\nos inimigos eliminados e as reservas recolhidas não reaparecem.",19)
		var exit_button := UI.button(box,"RETORNAR AO REFÚGIO",func():
			close_modal()
			world.return_to_base()
		,true)
		exit_button.disabled = world.player.position.distance_to(Vector3(0,0,24))>=4
		UI.label(box,"Aproxime-se do círculo de extração para retornar.",15,UI.MUTED)
	else:
		UI.label(box,"Escolha uma rota de coleta. Suas defesas aguardam no refúgio.",16,UI.MUTED)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation",14)
		grid.add_theme_constant_override("v_separation",14)
		box.add_child(grid)
		for i in range(4):
			var index := i
			var data: Dictionary = CampaignData.AREAS[i]
			var state: Dictionary = world.areas[i]
			var card := UI.panel(grid)
			card.custom_minimum_size = Vector2(460,220)
			var column := UI.vbox(card,7)
			UI.label(column,data.title,21,UI.LIME)
			UI.label(column,data.description,16,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UI.label(column,"Reservas: "+CampaignData.cost_text(data.reward),14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UI.label(column,"%d/%d eliminados · %d/3 reservas" % [state.dead.size(),data.count,state.caches.size()],15)
			var unlocked: bool = world.waves.wave>=int(data.wave)
			var button := UI.button(column,"VISITAR ÁREA" if unlocked else "LIBERA APÓS HORDA %d" % data.wave,func(): world.travel(index))
			button.disabled = not unlocked
	UI.button(box,"CONTINUAR",close_modal)

func show_shop() -> void:
	var box := open_modal("shop",830)
	UI.label(box,"BENTO / ARMEIRO DO REFÚGIO",30,UI.LIME)
	UI.label(box,"%d sucata · Armas são compras permanentes nesta campanha.\nReserva de munição ilimitada: recarregue com R." % world.resources.scrap,17,UI.MUTED)
	for i in [1,2]:
		var index: int = i
		var owned: bool = world.player.weapons.owned[i]
		var price := 110 if i==1 else 220
		var row := UI.hbox(box,15)
		var label := UI.label(row,Catalog.WEAPONS[i].title.to_upper()+" · "+("COMPRADA" if owned else "%d sucata" % price),22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := UI.button(row,"COMPRADA" if owned else "COMPRAR",func():
			world.buy_weapon(index)
			show_shop()
		)
		button.disabled = owned or world.resources.scrap<price
	UI.label(box,"SUPRIMENTOS",15,UI.LIME)
	for entry in [{"id":"heal","text":"TRATAMENTO · +60 vida · 25 sucata","cost":25},{"id":"wood","text":"10 MADEIRAS · 30 sucata","cost":30},{"id":"parts","text":"4 COMPONENTES · 45 sucata","cost":45}]:
		var service: String = entry.id
		var button := UI.button(box,entry.text,func():
			world.shop_service(service)
			show_shop()
		)
		button.disabled = world.resources.scrap<int(entry.cost) or (service=="heal" and world.player.health.current>=world.player.health.maximum)
	UI.button(box,"VOLTAR AO REFÚGIO",close_modal,true)

func show_equipment() -> void:
	var box := open_modal("equipment",850)
	UI.label(box,"ARSENAL DO SOBREVIVENTE",32,UI.LIME)
	var gun: WeaponSystem = world.player.weapons
	for i in range(3):
		UI.label(box,"%d / %s / %s" % [i+1,Catalog.WEAPONS[i].title,"COMPRADA" if gun.owned[i] else "COMPRE COM BENTO"],22)
		UI.label(box,"%.1f dano × %d · %d no pente · %.2fs recarga" % [float(Catalog.WEAPONS[i].values.damage)*gun.damage_multiplier,int(Catalog.WEAPONS[i].values.pellets),gun.capacity(i),float(Catalog.WEAPONS[i].values.reload)*gun.reload_multiplier],16,UI.MUTED)
	UI.label(box,"%d eliminações · nível %d · %d sucata\nReserva de munição ilimitada. XP evolui o personagem; sucata compra e constrói." % [world.kills,world.resources.level,world.resources.scrap],17)
	UI.button(box,"CONTINUAR",close_modal,true)

func show_pause() -> void:
	if not mode.is_empty() or world.phase=="ended": return
	var box := open_modal("pause",640)
	UI.label(box,"REFÚGIO EM PAUSA",35,UI.LIME)
	UI.label(box,"Checkpoint automático após hordas e retorno sem melhorias pendentes.\nF5 salva; F9 restaura. Ambos apenas no refúgio, na preparação.",17,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"CONTINUAR",close_modal,true)
	var save := UI.button(box,"SALVAR REFÚGIO",func(): world.save_checkpoint(); close_modal())
	save.disabled = world.area_index!=-1 or world.phase!="prep" or world.resources.pending>0
	var restore := UI.button(box,"RESTAURAR CHECKPOINT",func(): world.load_checkpoint())
	restore.disabled = world.area_index!=-1 or world.phase!="prep" or not FileAccess.file_exists(world.CHECKPOINT)
	UI.button(box,"CONFIGURAÇÕES",show_settings)
	UI.button(box,"VOLTAR AO MENU",menu)

func confirm_dismantle() -> void:
	if not mode.is_empty() or world.phase!="prep" or world.area_index!=-1: return
	var target: Node3D = world.nearest_structure()
	if target==null or target==world.core: world.notify("Aproxime-se da defesa para desmontar. O Núcleo é permanente."); return
	var box := open_modal("dismantle",650)
	UI.label(box,"DESMONTAR "+target.spec.title.to_upper()+"?",29,UI.LIME)
	UI.label(box,"Recupera 50% dos materiais investidos. Melhorias também entram no cálculo.",17,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"DESMONTAR",func():
		if is_instance_valid(target) and target.position.distance_to(world.player.position)<4.5: target.dismantle()
		close_modal()
	)
	UI.button(box,"CANCELAR",close_modal,true)

func show_result() -> void:
	var box := open_modal("result",740)
	UI.label(box,"A FORTALEZA RESISTIU" if world.won else "O REFÚGIO CAIU",38,UI.LIME)
	UI.label(box,world.ending_reason,20,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(box,"HORDA %d / 8 · %d eliminações · Núcleo N%d" % [world.waves.wave,world.kills,world.core_tier],22)
	if FileAccess.file_exists(world.CHECKPOINT):
		UI.button(box,"RETOMAR ÚLTIMO CHECKPOINT",func():
			load("res://scripts/campaign/campaign_world.gd").resume_requested = true
			restart()
		,true)
	UI.button(box,"NOVA CAMPANHA",func():
		load("res://scripts/campaign/campaign_world.gd").resume_requested = false
		restart()
	)
	UI.button(box,"MENU",menu)
