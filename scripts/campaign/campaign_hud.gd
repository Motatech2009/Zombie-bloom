extends "res://scripts/ui/hud.gd"
var material_text: Label
var location_text: Label

var update_left: float = 0
var hints: Control
var next_button: Button

func compact_style() -> StyleBoxFlat:
	var style := UI.style(Color(.035,.08,.095,.9),Color("354b4e"),8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func create_top() -> void:
	var panel := UI.panel(root)
	panel.add_theme_stylebox_override("panel",compact_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = 8
	panel.offset_bottom = 68
	var row := UI.hbox(panel,16)
	var brand := UI.vbox(row,2)
	UI.label(brand,"ZOMBIE BLOOM",16,UI.LIME)
	phase_text = UI.label(brand,"",11,UI.MUTED)
	var life := UI.vbox(row,3)
	life.custom_minimum_size.x = 145
	health_text = UI.label(life,"",13)
	health_bar = UI.meter(life)
	var base := UI.vbox(row,3)
	base.custom_minimum_size.x = 180
	core_text = UI.label(base,"",13)
	core_bar = UI.meter(base,Color("75cdd0"))
	var wave := UI.vbox(row,2)
	wave.custom_minimum_size.x = 145
	wave_text = UI.label(wave,"",16)
	wave_detail = UI.label(wave,"",12,UI.MUTED)
	var stock := UI.vbox(row,2)
	stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrap_text = UI.label(stock,"",16,UI.LIME)
	material_text = UI.label(stock,"",12,UI.MUTED)
	xp_text = UI.label(row,"",13,UI.MUTED)
	var pause := UI.button(row,"Ⅱ",show_pause)
	pause.custom_minimum_size = Vector2(36,36)

func create_bottom() -> void:
	hints = UI.vbox(root,4)
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hints.offset_left = 16
	hints.offset_right = 500
	hints.offset_top = -74
	hints.offset_bottom = -10
	location_text = UI.label(hints,"",12,UI.MUTED)
	var row := UI.hbox(hints,5)
	for entry in [{"label":"M ÁREAS","callback":show_routes},{"label":"V LOJA","callback":func():
		if mode.is_empty(): world.open_shop()
	},{"label":"ESPAÇO / HORDA","callback":func():
		if mode.is_empty(): world.waves.start()
	}]:
		var button := UI.button(row,entry.label,entry.callback)
		button.custom_minimum_size.y = 32
		button.add_theme_font_size_override("font_size",13)
		next_button = button
	var panel := UI.panel(root)
	panel.add_theme_stylebox_override("panel",compact_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -340
	panel.offset_right = -16
	panel.offset_top = -83
	panel.offset_bottom = -10
	var box := UI.vbox(panel,3)
	var stats := UI.hbox(box,12)
	weapon_text = UI.label(stats,"",16)
	weapon_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_text = UI.label(stats,"",16,UI.LIME)
	reload_bar = UI.meter(box,Color("edbf7b"))
	power_text = UI.label(box,"",12,UI.MUTED)
	notice_text = UI.label(root,"",14,UI.LIME)
	notice_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_text.offset_left = -410
	notice_text.offset_right = 410
	notice_text.offset_top = 83
	notice_text.offset_bottom = 130
	notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_text = UI.label(root,"",14,UI.LIME)
	build_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	build_text.offset_left = -360
	build_text.offset_right = 360
	build_text.offset_top = -145
	build_text.offset_bottom = -92
	build_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _process(delta: float) -> void:
	if not is_instance_valid(world.player): return
	crosshair.position = root.get_local_mouse_position()+Vector2(-9,-20)
	crosshair.visible = mode.is_empty() and not world.builder.active
	if world.resources.pending>0 and mode.is_empty() and world.phase!="ended": request_upgrade()
	update_left -= delta
	if update_left>0: return
	update_left = .1
	var player: CharacterBody3D = world.player
	var gun: WeaponSystem = player.weapons
	health_text.text = "VIDA %d/%d" % [ceili(player.health.current),ceili(player.health.maximum)]
	health_bar.max_value = player.health.maximum
	health_bar.value = player.health.current
	core_text.text = "NÚCLEO N%d · %d/%d" % [world.core_tier,ceili(world.core.health.current),ceili(world.core.health.maximum)]
	core_bar.max_value = world.core.health.maximum
	core_bar.value = world.core.health.current
	wave_text.text = "HORDA %02d%s" % [world.waves.wave," / 20" if world.game_mode=="campaign" else " / ∞"]
	phase_text.text = ("CAMPANHA" if world.game_mode=="campaign" else "INFINITO")+" · "+("DEFESA" if world.phase=="combat" else "PREPARAÇÃO" if world.area_index==-1 else "EXPEDIÇÃO")
	wave_detail.text = "%d restantes" % world.waves.remaining() if world.phase=="combat" else "Prepare sua defesa"
	if world.area_index>=0:
		var remaining: int = int(CampaignData.AREAS[world.area_index].count)-world.areas[world.area_index].dead.size()
		wave_detail.text = "%d hostis na área" % remaining if remaining>0 else "Área limpa"
	scrap_text.text = "%d SUCATA" % world.resources.scrap
	material_text.text = "%d madeira · %d componentes" % [world.stock.wood,world.stock.parts]
	xp_text.text = "N%d · %d XP" % [world.resources.level,world.resources.xp]
	weapon_text.text = gun.spec().title.to_upper()
	ammo_text.text = "RECARGA" if gun.reload_left>0 else "%d/%d" % [gun.ammo[gun.slot],gun.capacity()]
	reload_bar.max_value = gun.reload_total if gun.reload_left>0 else float(gun.capacity())
	reload_bar.value = gun.reload_total-gun.reload_left if gun.reload_left>0 else float(gun.ammo[gun.slot])
	power_text.text = "C granadas: %d · foguetes: %d · TAB arsenal" % [world.grenades,world.rockets]
	if not player.powers.is_empty(): power_text.text = " · ".join(player.powers.keys())+" · C %d" % world.grenades
	location_text.text = ("REFÚGIO" if world.area_index==-1 else CampaignData.AREAS[world.area_index].title)+" · B construir · H atalhos"
	next_button.disabled = world.phase!="prep" or world.area_index!=-1
	notice_text.text = world.notice if world.notice_left>0 and mode.is_empty() else ""
	build_text.text = ""
	if world.builder.active:
		build_text.text = "Q girar · 1–6 peça · Clique instalar · B sair\n"+world.builder.reason
		build_text.modulate = UI.LIME if world.builder.valid else Color("f5a18d")
	elif world.area_index==-1 and world.phase=="prep":
		var target: Node3D = world.nearest_structure()
		if target!=null and target.position.distance_to(player.position)<3:
			build_text.text = "G melhorar Núcleo · E reparar" if target==world.core else "G melhorar · E reparar · X desmontar · F portão"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hud_hints"):
		hints.visible = not hints.visible
		get_viewport().set_input_as_handled()
		return
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
		var heading := UI.hbox(card,8)
		ItemIcons.image(heading,data.id,Vector2(42,42))
		UI.label(heading,"%d / %s" % [i+1,data.title.to_upper()],17,data.color.lightened(.3))
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
	UI.label(box,"BENTO / ARMEIRO",28,UI.LIME)
	UI.label(box,"%d sucata · Foguetes e granadas usam munição finita." % world.resources.scrap,16,UI.MUTED)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := UI.vbox(scroll,10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in [1,2,3,4]:
		var index: int = i
		var owned: bool = world.player.weapons.owned[i]
		var price: int = CampaignData.PRICES[i]
		var row := UI.hbox(list,15)
		var label := UI.label(row,CampaignData.WEAPONS[i].title.to_upper()+" · "+("COMPRADA" if owned else "%d sucata" % price),19)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := UI.button(row,"COMPRADA" if owned else "COMPRAR",func():
			world.buy_weapon(index)
			show_shop()
		)
		button.disabled = owned or world.resources.scrap<price
	UI.label(list,"MUNIÇÃO E SUPRIMENTOS",14,UI.LIME)
	for entry in [{"id":"grenades","text":"3 GRANADAS · 45 sucata","cost":45},{"id":"rockets","text":"5 FOGUETES · 60 sucata","cost":60},{"id":"heal","text":"TRATAMENTO · +60 vida · 25 sucata","cost":25},{"id":"wood","text":"10 MADEIRAS · 30 sucata","cost":30},{"id":"parts","text":"4 COMPONENTES · 45 sucata","cost":45}]:
		var service: String = entry.id
		var button := UI.button(list,entry.text,func():
			world.shop_service(service)
			show_shop()
		)
		button.disabled = world.resources.scrap<int(entry.cost) or (service=="heal" and world.player.health.current>=world.player.health.maximum) or (service=="rockets" and not world.player.weapons.owned[4])
	UI.button(box,"VOLTAR AO REFÚGIO",close_modal,true)

func show_equipment() -> void:
	var box := open_modal("equipment",850)
	UI.label(box,"ARSENAL DO SOBREVIVENTE",32,UI.LIME)
	var gun: WeaponSystem = world.player.weapons
	for i in range(5):
		UI.label(box,"%d / %s / %s" % [i+1,CampaignData.WEAPONS[i].title,"COMPRADA" if gun.owned[i] else "COMPRE COM BENTO"],22)
		UI.label(box,"%.1f dano × %d · %d no pente · %.2fs recarga" % [float(CampaignData.WEAPONS[i].values.damage)*gun.damage_multiplier,int(CampaignData.WEAPONS[i].values.pellets),gun.capacity(i),float(CampaignData.WEAPONS[i].values.reload)*gun.reload_multiplier],16,UI.MUTED)
	UI.label(box,"%d eliminações · nível %d · %d sucata\nBalas comuns livres. Explosivos finitos: C lança granada até a mira.\nExplosões próximas ferem você; paredes protegem inimigos do impacto." % [world.kills,world.resources.level,world.resources.scrap],17)
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
	restore.disabled = world.area_index!=-1 or world.phase!="prep" or not FileAccess.file_exists(world.checkpoint_path())
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
	UI.label(box,"HORDA %d · %s · %d eliminações · Núcleo N%d" % [world.waves.wave,world.game_mode.to_upper(),world.kills,world.core_tier],22)
	if FileAccess.file_exists(world.checkpoint_path()):
		UI.button(box,"RETOMAR ÚLTIMO CHECKPOINT",func():
			load("res://scripts/campaign/campaign_world.gd").resume_requested = true
			restart()
		,true)
	UI.button(box,"NOVA CAMPANHA",func():
		load("res://scripts/campaign/campaign_world.gd").resume_requested = false
		restart()
	)
	UI.button(box,"MENU",menu)
