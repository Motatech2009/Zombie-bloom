extends CanvasLayer
var world: Node3D
var root: Control
var modal: Control
var mode: String = ""
var box: VBoxContainer
var status: Label
var context: Label
var selected: int = -1
var external_selected: int = -1
var loot: BetaInventory
var loot_id: String = ""
var craft_filter: String = ""
var waiting_bind: String = ""
var bar: Array[Button] = []
var crosshair: Label
var instructions: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	UI.fill(root)
	root.theme = UI.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UI.panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 20
	panel.offset_bottom = 110
	var row := UI.hbox(panel, 16)
	status = UI.label(row, "ÚLTIMO REFÚGIO", 19)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button(row, "PAUSA", show_pause)
	var contextual := UI.panel(root)
	contextual.position = Vector2(24, 140)
	contextual.custom_minimum_size = Vector2(520, 85)
	context = UI.label(contextual, "", 16, UI.LIME)
	context.custom_minimum_size.x = 490
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bottom := UI.panel(root)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -135
	bottom.offset_bottom = -20
	var column := UI.vbox(bottom, 8)
	instructions = UI.label(column, "E interagir/extrair · I mochila · C fabricar · B construir · Q girar · F reparar · Espaço rolar · M mapa · L lanterna", 14, UI.MUTED)
	var hotbar := UI.hbox(column, 8)
	for i in range(6):
		var index := i
		var button := UI.button(hotbar, str(i + 1), func(): world.player.select_hotbar(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		bar.append(button)
	crosshair = UI.label(root, "+", 24, UI.LIME)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal = Control.new()
	root.add_child(modal)
	UI.fill(modal)
	modal.hide()
	apply_text_scale(root)

func _process(_delta: float) -> void:
	if not is_instance_valid(world.player):
		return
	crosshair.position = root.get_local_mouse_position() + Vector2(-7, -15)
	crosshair.visible = mode.is_empty() and not world.builder.active
	var player: Node3D = world.player
	var gun: BetaWeapons = player.weapons
	var ammo := "MACHADO" if player.tool == "axe" else "%d / %d · Reserva %d" % [gun.ammo[gun.slot], gun.capacity(), world.inventory.count(BetaWeapons.AMMO_TYPES[gun.slot])]
	instructions.text = "%s interagir · %s mochila · %s fabricar · %s construir · %s girar · %s reparar · %s rolar · %s mapa · %s lanterna" % [BetaOptions.key_hint("beta_interact"), BetaOptions.key_hint("beta_inventory"), BetaOptions.key_hint("beta_craft"), BetaOptions.key_hint("beta_build"), BetaOptions.key_hint("beta_rotate"), BetaOptions.key_hint("beta_repair"), BetaOptions.key_hint("roll"), BetaOptions.key_hint("world_map"), BetaOptions.key_hint("beta_light")]
	status.text = "ÚLTIMO REFÚGIO    VIDA %d    NÚCLEO %d\nDIA %d · %02d:%02d · %s    |    %.1f / %.0f kg    |    %s" % [ceili(player.health.current), ceili(world.core.health.current), world.time.day(), floori(world.time.hour()), floori(fmod(world.time.hour() * 60, 60)), world.time.weather_name(), world.inventory.weight(), world.inventory.nominal, ammo]
	context.text = world.notice if world.notice_left > 0 else world.interaction_text
	if world.builder.active:
		context.text = "CONSTRUÇÃO · %s\n%s" % [BetaCatalog.title(BetaCatalog.STRUCTURES[world.builder.selected]), world.builder.reason]
	elif world.inventory.ratio() > 1:
		context.text += "\nSOBRECARGA %s · Movimento %d%%" % ["II · corrida e rolamento bloqueados" if world.inventory.ratio() > 1.25 else "I", roundi(world.inventory.move_factor() * 100)]
	for i in range(6):
		var slot: int = world.inventory.hotbar[i]
		bar[i].text = "%d · %s" % [i + 1, BetaCatalog.title(world.inventory.slots[slot].id) if slot >= 0 and slot < world.inventory.slots.size() and not world.inventory.slots[slot].is_empty() else "Vazio"]
		bar[i].modulate = UI.LIME if player.hotbar_slot == i else Color.WHITE

func _input(event: InputEvent) -> void:
	if not waiting_bind.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode != KEY_ESCAPE:
			var success := BetaOptions.rebind(waiting_bind, event.physical_keycode)
			world.notify("Controle atualizado." if success else "Tecla reservada ou em uso; escolha outra.")
		waiting_bind = ""
		show_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if not mode.is_empty():
			close_modal()
		elif world.builder.active:
			world.builder.set_active(false)
		else:
			show_pause()
	elif event.is_action_pressed("beta_inventory"):
		get_viewport().set_input_as_handled()
		if mode == "inventory": close_modal()
		elif mode.is_empty(): show_inventory()
	elif event.is_action_pressed("beta_craft"):
		get_viewport().set_input_as_handled()
		if mode.is_empty(): show_crafting()
	elif event.is_action_pressed("world_map"):
		get_viewport().set_input_as_handled()
		if mode == "map": close_modal()
		elif mode.is_empty(): show_map()

func open_modal(next: String, width: float = 1000) -> VBoxContainer:
	mode = next
	get_tree().paused = true
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	modal.show()
	var dim := ColorRect.new()
	modal.add_child(dim)
	UI.fill(dim)
	dim.color = Color(.01, .025, .03, .9)
	var center := CenterContainer.new()
	modal.add_child(center)
	UI.fill(center)
	var panel := UI.panel(center)
	panel.custom_minimum_size.x = width
	box = UI.vbox(panel, 12)
	return box

func close_modal() -> void:
	if world.phase == "ended":
		return
	mode = ""
	waiting_bind = ""
	modal.hide()
	get_tree().paused = false
	world.player.weapons.cooldown = maxf(.25, world.player.weapons.cooldown)

func heading(title: String) -> void:
	UI.label(box, title, 29, UI.LIME)

func footer() -> void:
	UI.button(box, "CONTINUAR · ESC", close_modal, true)
	apply_text_scale(modal)

func inventory_grid(parent: Node, inventory: BetaInventory, external: bool) -> void:
	var scroll := ScrollContainer.new()
	parent.add_child(scroll)
	scroll.custom_minimum_size = Vector2(465, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 4
	scroll.add_child(grid)
	for i in range(inventory.slots.size()):
		var index := i
		var stack: Dictionary = inventory.slots[i]
		var text := "—" if stack.is_empty() else BetaCatalog.title(stack.id) + "\n×%d · %.1f kg" % [int(stack.qty), float(BetaCatalog.item(stack.id).weight) * int(stack.qty)]
		var button := UI.button(grid, "", func():
			if external: external_selected = index
			else: selected = index
			if mode == "loot": show_loot(loot, loot_id)
			else: show_inventory()
		)
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size = Vector2(109, 68)
		button.tooltip_text = text
		var caption := UI.label(button, text, 14)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.offset_left = 4
		caption.offset_right = -4
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.modulate = UI.LIME if (index == external_selected if external else index == selected) else Color.WHITE

func show_inventory() -> void:
	open_modal("inventory", 1040)
	heading("MOCHILA E EQUIPAMENTOS")
	UI.label(box, "%.1f / %.0f kg · Limite absoluto %.0f kg · %d slots · Movimento %d%%" % [world.inventory.weight(), world.inventory.nominal, world.inventory.nominal * 1.5, world.inventory.slots.size(), roundi(world.inventory.move_factor() * 100)], 17)
	var row := UI.hbox(box, 20)
	inventory_grid(row, world.inventory, false)
	var action_scroll := ScrollContainer.new()
	row.add_child(action_scroll)
	action_scroll.custom_minimum_size = Vector2(450, 330)
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var actions := UI.vbox(action_scroll, 10)
	UI.label(actions, "Selecione um slot e vincule à barra.\nA barra referencia a mochila; não cria itens.", 16, UI.MUTED)
	var links := UI.hbox(actions, 5)
	for i in range(6):
		var index := i
		UI.button(links, str(i + 1), func():
			if selected >= 0 and not world.inventory.slots[selected].is_empty():
				world.inventory.hotbar[index] = selected
				show_inventory()
		)
	var gear_buttons := UI.hbox(actions, 5)
	for category in ["primary", "secondary", "tool"]:
		var key: String = category
		UI.button(gear_buttons, {"primary": "Principal", "secondary": "Secundária", "tool": "Ferramenta"}[key], func(): world.inventory.equip_slot(selected, key); show_inventory())
	UI.label(actions, "Principal: " + world.inventory.equipment_name("primary") + "\nSecundária: " + world.inventory.equipment_name("secondary") + "\nFerramenta: " + world.inventory.equipment_name("tool"), 15)
	UI.button(actions, "USAR / EQUIPAR SLOT", func(): world.use_item(selected); show_inventory())
	UI.label(actions, "Proteção: " + ("equipada · -20% dano" if world.inventory.armor else "sem proteção") + "\nMochila: " + ("expedição" if world.inventory.backpack else "básica"), 16)
	UI.button(actions, "DEIXAR 1 ITEM NO CHÃO", func(): world.discard_item(selected); show_inventory())
	UI.button(actions, "REGISTROS RECUPERADOS", show_journal)
	footer()

func show_loot(container: BetaInventory, id: String) -> void:
	loot = container
	loot_id = id
	open_modal("loot", 1060)
	heading("RECIPIENTE E MOCHILA")
	UI.label(box, "Selecione um slot. Leve ou guarde uma unidade ou a pilha; o que não couber permanece na origem.", 15, UI.MUTED)
	var row := UI.hbox(box, 20)
	var left := UI.vbox(row, 6)
	var right := UI.vbox(row, 6)
	UI.label(left, "MOCHILA · %.1f / %.0f kg" % [world.inventory.weight(), world.inventory.nominal], 18)
	UI.label(right, "RECIPIENTE · %d slots" % container.slots.size(), 18)
	inventory_grid(left, world.inventory, false)
	inventory_grid(right, container, true)
	var transfer := UI.hbox(box, 8)
	for amount in [1, 100000]:
		var quantity: int = amount
		UI.button(transfer, "LEVAR " + ("1" if amount == 1 else "PILHA"), func(): container.transfer_to(world.inventory, external_selected, quantity); show_loot(container, id))
		UI.button(transfer, "GUARDAR " + ("1" if amount == 1 else "PILHA"), func(): world.store_items(container, selected, quantity); show_loot(container, id))
	if id == "base:storage":
		UI.button(box, "LER REGISTRO DO NÚCLEO", func(): world.read_record("core"))
	footer()

func show_crafting() -> void:
	open_modal("crafting", 980)
	heading("FABRICAÇÃO")
	UI.label(box, "Receitas iniciais conhecidas · Fabricação instantânea · Consumo somente se a saída couber", 15, UI.MUTED)
	var filter := LineEdit.new()
	filter.placeholder_text = "Filtrar receita"
	filter.text = craft_filter
	box.add_child(filter)
	var scroll := ScrollContainer.new()
	box.add_child(scroll)
	scroll.custom_minimum_size.y = 410
	var list := UI.vbox(scroll, 9)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var populate := func():
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
		for recipe: Dictionary in BetaCatalog.DATA.values.recipes:
			if not craft_filter.is_empty() and not str(recipe.title).to_lower().contains(craft_filter.to_lower()):
				continue
			var id: String = recipe.id
			var valid: bool = world.crafting.can_craft(id)
			var reason: String = world.crafting.reason
			var costs := ""
			for material: String in recipe.cost:
				costs += "%d %s · " % [recipe.cost[material], BetaCatalog.title(material)]
			UI.label(list, "%s ×%d  /  %s" % [recipe.title, recipe.amount, "Bancada" if recipe.station == "bench" else "Manual"], 19, UI.LIME)
			UI.label(list, costs + "\n" + reason, 15, UI.MUTED)
			var button := UI.button(list, "FABRICAR", func():
				var crafted: bool = world.crafting.craft(id)
				world.notify("Fabricado: " + BetaCatalog.title(recipe.output) if crafted else world.crafting.reason)
				show_crafting()
			)
			button.disabled = not valid
	populate.call()
	filter.text_changed.connect(func(value: String): craft_filter = value; populate.call())
	footer()

func show_building() -> void:
	open_modal("building", 700)
	heading("CONSTRUÇÃO DO REFÚGIO")
	UI.label(box, "Fabrique as peças primeiro. Q gira a prévia. Clique instala; botão direito cancela.\nA colocação não consome uma peça se houver colisão, água ou acesso bloqueado.", 15, UI.MUTED)
	for i in range(BetaCatalog.STRUCTURES.size()):
		var index := i
		var id: String = BetaCatalog.STRUCTURES[i]
		var button := UI.button(box, "%s · Na mochila: %d" % [BetaCatalog.title(id), world.inventory.count(id)], func():
			world.builder.selected = index
			close_modal()
			world.builder.set_active(true)
		)
		button.disabled = world.inventory.count(id) <= 0
	footer()

func show_map() -> void:
	open_modal("map", 780)
	heading("MAPA DO VALE")
	UI.label(box, "Trecho regional · Áreas claras visitadas · Azul: posição aproximada · Verde: refúgio", 14)
	var viewport := Control.new()
	viewport.custom_minimum_size = Vector2(680, 430)
	viewport.clip_contents = true
	box.add_child(viewport)
	var map := WorldMap.new()
	map.world = world
	viewport.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.label(box, "Seed %d · Sem teleporte. Siga as vias e use travessias sobre o rio." % world.state.world_seed, 15, UI.MUTED)
	footer()

func show_record(id: String) -> void:
	open_modal("record", 760)
	heading(world.LORE[id][0])
	var text := UI.label(box, world.LORE[id][1], 22)
	text.custom_minimum_size = Vector2(700, 180)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(box, "Documento recuperado · Relato sem confirmação independente", 14, UI.MUTED)
	footer()

func show_journal() -> void:
	open_modal("journal", 760)
	heading("REGISTROS RECUPERADOS")
	for id: String in world.notes:
		var key := id
		UI.button(box, world.LORE[id][0], func(): show_record(key))
	if world.notes.is_empty():
		UI.label(box, "Procure registros no Núcleo e em diferentes edifícios.", 18)
	footer()

func show_pause() -> void:
	open_modal("pause", 640)
	heading("PAUSADO")
	UI.label(box, "O relógio e os eventos estão pausados. Interiores mantêm o tempo do mundo em movimento.", 16, UI.MUTED)
	UI.button(box, "SALVAR CAMPANHA", func(): world.save_beta())
	UI.button(box, "RESTAURAR SALVAMENTO", func():
		if world.load_beta(): close_modal()
	)
	UI.button(box, "CONFIGURAÇÕES", show_settings)
	UI.button(box, "VOLTAR AO MENU · sem salvar automaticamente", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
	)
	footer()

func show_settings() -> void:
	open_modal("settings", 800)
	heading("CONFIGURAÇÕES")
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = .05
	volume.value = GameSettings.volume
	UI.label(box, "Volume", 16)
	box.add_child(volume)
	volume.value_changed.connect(func(value): GameSettings.volume = value; GameSettings.save_settings())
	var fog := HSlider.new()
	fog.min_value = 0
	fog.max_value = 1
	fog.step = .1
	fog.value = BetaOptions.fog_strength
	UI.label(box, "Intensidade da neblina · zero desativa", 16)
	box.add_child(fog)
	fog.value_changed.connect(func(value): BetaOptions.fog_strength = value; BetaOptions.save(); world.time.apply())
	var size := OptionButton.new()
	for text in ["1280 × 800", "1600 × 900", "1920 × 1080"]: size.add_item(text)
	size.select(BetaOptions.resolution_index)
	box.add_child(size)
	size.item_selected.connect(func(index): BetaOptions.resolution_index = index; BetaOptions.save(); DisplayServer.window_set_size([Vector2i(1280, 800), Vector2i(1600, 900), Vector2i(1920, 1080)][index]))
	var shadow := CheckButton.new()
	shadow.text = "Sombras"
	shadow.button_pressed = BetaOptions.shadows
	box.add_child(shadow)
	shadow.toggled.connect(func(value): BetaOptions.shadows = value; BetaOptions.save(); world.time.apply())
	var text_size := OptionButton.new()
	text_size.add_item("Texto 100%")
	text_size.add_item("Texto 125%")
	text_size.select(1 if BetaOptions.text_scale > 1 else 0)
	box.add_child(text_size)
	text_size.item_selected.connect(func(index): BetaOptions.text_scale = 1.25 if index == 1 else 1.0; BetaOptions.save(); show_settings())
	UI.button(box, "MODO LEVE · 3D 50%, sem sombras", func(): BetaOptions.render_scale = .5; BetaOptions.shadows = false; BetaOptions.fog_strength = .3; BetaOptions.save(); world.time.apply(); show_settings())
	UI.button(box, "QUALIDADE PADRÃO · 3D 100%", func(): BetaOptions.render_scale = 1; BetaOptions.shadows = true; BetaOptions.save(); world.time.apply(); show_settings())
	var keys := OptionButton.new()
	for action: String in BetaOptions.bindings:
		keys.add_item(BetaOptions.action_title(action) + " · " + OS.get_keycode_string(BetaOptions.bindings[action]))
	box.add_child(keys)
	UI.button(box, "REDEFINIR CONTROLE SELECIONADO", func():
		waiting_bind = BetaOptions.bindings.keys()[keys.selected]
		UI.label(box, "Pressione uma tecla livre. ESC cancela.", 16, UI.LIME)
	)
	footer()

func apply_text_scale(node: Node) -> void:
	if node is Label or node is Button:
		if not node.has_meta("base_font"):
			node.set_meta("base_font", node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", roundi(int(node.get_meta("base_font")) * BetaOptions.text_scale))
	for child in node.get_children():
		apply_text_scale(child)

func show_result() -> void:
	open_modal("result", 720)
	heading("O REFÚGIO SILENCIOU")
	UI.label(box, world.ending_reason, 22)
	UI.label(box, "Esta expedição terminou. O último salvamento pode ser retomado; não há permadeath na Beta.", 17, UI.MUTED)
	UI.button(box, "RETOMAR SALVAMENTO", func():
		if world.load_beta():
			world.phase = "prep"
			close_modal()
	)
	UI.button(box, "MENU", func(): get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn"))
	apply_text_scale(modal)
