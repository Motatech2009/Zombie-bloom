extends CanvasLayer
var world: Node3D
var root: Control
var modal: Control
var mode: String = ""
var health_text: Label
var health_bar: ProgressBar
var core_text: Label
var core_bar: ProgressBar
var wave_text: Label
var wave_detail: Label
var scrap_text: Label
var xp_text: Label
var xp_bar: ProgressBar
var weapon_text: Label
var ammo_text: Label
var reload_bar: ProgressBar
var notice_text: Label
var power_text: Label
var build_text: Label
var phase_text: Label
var slots: Array[Button] = []
var crosshair: Label
var overlay_box: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	UI.fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	create_top()
	create_bottom()
	crosshair = UI.label(root, "+", 27, UI.LIME)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal = Control.new()
	root.add_child(modal)
	UI.fill(modal)
	modal.hide()

func create_top() -> void:
	var panel := UI.panel(root)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 24
	panel.offset_top = 20
	panel.offset_right = -24
	panel.offset_bottom = 108
	var row := UI.hbox(panel, 24)
	var brand := UI.vbox(row, 0)
	brand.custom_minimum_size.x = 180
	UI.label(brand, "ZOMBIE BLOOM.", 22, UI.LIME)
	phase_text = UI.label(brand, "PREPARAÇÃO", 12, UI.MUTED)
	var player_box := UI.vbox(row, 5)
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_text = UI.label(player_box, "SOBREVIVENTE", 14)
	health_bar = UI.meter(player_box)
	var core_box := UI.vbox(row, 5)
	core_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_text = UI.label(core_box, "NÚCLEO", 14)
	core_bar = UI.meter(core_box, Color("75cdd0"))
	var waves_box := UI.vbox(row, 1)
	waves_box.custom_minimum_size.x = 175
	wave_text = UI.label(waves_box, "HORDA 00 / 05", 20)
	wave_detail = UI.label(waves_box, "Prepare suas defesas", 13, UI.MUTED)
	var resource_box := UI.vbox(row, 0)
	resource_box.custom_minimum_size.x = 115
	UI.label(resource_box, "SUCATA", 12, UI.MUTED)
	scrap_text = UI.label(resource_box, "140", 25, UI.LIME)
	var level_box := UI.vbox(row, 4)
	level_box.custom_minimum_size.x = 120
	xp_text = UI.label(level_box, "NÍVEL 01", 14)
	xp_bar = UI.meter(level_box, Color("bfabf2"))
	UI.button(row, "Ⅱ", func(): show_pause())

func create_bottom() -> void:
	var left := UI.panel(root)
	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 24
	left.offset_right = 545
	left.offset_top = -176
	left.offset_bottom = -24
	var box := UI.vbox(left, 7)
	UI.label(box, "SEU REFÚGIO. SUAS REGRAS.", 12, UI.LIME)
	UI.label(box, "WASD mover · SHIFT correr · R recarregar\nB construir · E reparar · TAB equipamentos", 14, UI.MUTED)
	UI.button(box, "ESPAÇO   /   INICIAR HORDA", func():
		if mode.is_empty():
			world.waves.start()
	)
	var right := UI.panel(root)
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_left = -645
	right.offset_right = -24
	right.offset_top = -176
	right.offset_bottom = -24
	var column := UI.vbox(right, 6)
	var stats := UI.hbox(column, 16)
	weapon_text = UI.label(stats, "PISTOLA", 21)
	weapon_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_text = UI.label(stats, "12 / 12", 24, UI.LIME)
	reload_bar = UI.meter(column, Color("edbf7b"))
	var row := UI.hbox(column, 8)
	for i in range(3):
		var index := i
		var button := UI.button(row, "%d  %s" % [i + 1, Catalog.WEAPONS[i].title], func():
			if mode.is_empty() and not world.builder.active:
				world.player.weapons.equip(index)
		)
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.append(button)
	notice_text = UI.label(root, "", 18, UI.LIME)
	notice_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_text.offset_left = -590
	notice_text.offset_right = 590
	notice_text.offset_top = 132
	notice_text.offset_bottom = 200
	notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power_text = UI.label(root, "", 16, Color("cab8f8"))
	power_text.position = Vector2(28, 225)
	build_text = UI.label(root, "", 17, UI.LIME)
	build_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	build_text.offset_left = -600
	build_text.offset_right = 600
	build_text.offset_top = -235
	build_text.offset_bottom = -190
	build_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _process(_delta: float) -> void:
	if not is_instance_valid(world.player):
		return
	var player: CharacterBody3D = world.player
	var gun: WeaponSystem = player.weapons
	health_text.text = "VIDA  %d / %d" % [ceili(player.health.current), ceili(player.health.maximum)]
	health_bar.max_value = player.health.maximum
	health_bar.value = player.health.current
	core_text.text = "NÚCLEO  %d / %d" % [ceili(world.core.health.current), ceili(world.core.health.maximum)]
	core_bar.max_value = world.core.health.maximum
	core_bar.value = world.core.health.current
	wave_text.text = "HORDA %02d / 05" % world.waves.wave
	wave_detail.text = "%d hostis restantes" % world.waves.remaining() if world.phase == "combat" else "Prepare suas defesas"
	phase_text.text = "EM COMBATE" if world.phase == "combat" else "PREPARAÇÃO" if world.phase == "prep" else "PARTIDA ENCERRADA"
	scrap_text.text = str(world.resources.scrap)
	xp_text.text = "NÍVEL %02d · %d XP" % [world.resources.level, world.resources.xp]
	xp_bar.max_value = world.resources.threshold()
	xp_bar.value = world.resources.xp
	weapon_text.text = gun.spec().title.to_upper() + "   /   NV. %02d" % gun.level
	ammo_text.text = "RECARREGANDO" if gun.reload_left > 0 else "%02d / %02d" % [gun.ammo[gun.slot], gun.capacity()]
	reload_bar.max_value = gun.reload_total if gun.reload_left > 0 else float(gun.capacity())
	reload_bar.value = gun.reload_total - gun.reload_left if gun.reload_left > 0 else float(gun.ammo[gun.slot])
	for i in range(slots.size()):
		slots[i].modulate = UI.LIME if i == gun.slot else Color.WHITE
	notice_text.text = world.notice if world.notice_left > 0 else ""
	power_text.text = ""
	for id in player.powers:
		power_text.text += "%s  %02ds%s\n" % [Catalog.POWER_NAMES[id], ceili(player.power_left(id)), " · %d proteção" % ceili(player.shield) if id == "shield" else ""]
	if world.builder.active:
		build_text.text = "1 BARRICADA · 25     /     2 TORRETA · 75     |     " + world.builder.reason
		build_text.modulate = UI.LIME if world.builder.valid else Color("f5a18d")
	else:
		build_text.text = "ESPAÇO inicia a horda  ·  B constrói  ·  E repara" if world.phase == "prep" else ""
	crosshair.position = root.get_local_mouse_position() + Vector2(-9, -20)
	crosshair.visible = mode.is_empty() and not world.builder.active
	if world.resources.pending > 0 and mode.is_empty() and world.phase != "ended":
		request_upgrade()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if mode == "upgrade" or mode == "result":
			return
		if not mode.is_empty():
			close_modal()
		elif world.builder.active:
			world.builder.set_active(false)
		else:
			show_pause()
	if event.is_action_pressed("equipment") and world.phase != "ended":
		get_viewport().set_input_as_handled()
		if mode == "equipment":
			close_modal()
		elif mode.is_empty():
			show_equipment()

func open_modal(next_mode: String, width: float = 800) -> VBoxContainer:
	mode = next_mode
	get_tree().paused = true
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	modal.show()
	var dim := ColorRect.new()
	modal.add_child(dim)
	UI.fill(dim)
	dim.color = Color(.015, .035, .05, .88)
	var center := CenterContainer.new()
	modal.add_child(center)
	UI.fill(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UI.panel(center)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", UI.style(UI.CARD, Color("6b8460"), 16))
	overlay_box = UI.vbox(panel, 18)
	return overlay_box

func close_modal() -> void:
	if world.phase == "ended":
		return
	mode = ""
	modal.hide()
	world.player.weapons.cooldown = maxf(world.player.weapons.cooldown, .2)
	get_tree().paused = false

func show_pause() -> void:
	if not mode.is_empty() or world.phase == "ended":
		return
	var box := open_modal("pause", 520)
	UI.label(box, "RESPIRE. O MUNDO PODE ESPERAR.", 13, UI.LIME)
	UI.label(box, "PAUSADO", 44)
	UI.button(box, "CONTINUAR", close_modal, true)
	UI.button(box, "CONFIGURAÇÕES", show_settings)
	UI.button(box, "REINICIAR PARTIDA", restart)
	UI.button(box, "VOLTAR AO MENU", menu)

func show_settings() -> void:
	var box := open_modal("settings", 560)
	UI.label(box, "CONFIGURAÇÕES", 32)
	UI.settings(box, func():
		if world.has_method("apply_mobile_quality"): world.apply_mobile_quality()
		else: world.sunlight.shadow_enabled = GameSettings.use_shadows()
	)
	UI.button(box, "CONTINUAR", close_modal, true)

func show_equipment() -> void:
	var box := open_modal("equipment", 850)
	UI.label(box, "EQUIPAMENTOS", 35)
	UI.label(box, "Munição de reserva ilimitada · recarregue com R · equipe com 1, 2 ou 3", 16, UI.MUTED)
	var gun: WeaponSystem = world.player.weapons
	for i in range(3):
		var spec: Resource = Catalog.WEAPONS[i]
		UI.label(box, "%d   %s" % [i + 1, spec.title.to_upper()], 22, spec.color)
		UI.label(box, "%.1f dano × %d   /   %.1f tiros/s   /   %d no pente   /   %.2fs recarga" % [float(spec.values.damage) * gun.damage_multiplier, int(spec.values.pellets), gun.rate_multiplier / float(spec.values.interval), gun.capacity(i), float(spec.values.reload) * gun.reload_multiplier], 17)
	UI.label(box, "XP  %d / %d   ·   %d sucata   ·   %d eliminações\nDeslocamento +%d%%   ·   Vida máxima %d" % [world.resources.xp, world.resources.threshold(), world.resources.scrap, world.kills, roundi((world.player.speed_multiplier - 1) * 100), ceili(world.player.health.maximum)], 16, UI.MUTED)
	UI.button(box, "CONTINUAR", close_modal, true)

func request_upgrade() -> void:
	if world.phase == "ended" or world.resources.pending <= 0 or not mode.is_empty():
		return
	show_upgrade()

func show_upgrade() -> void:
	var box := open_modal("upgrade", 1060)
	UI.label(box, "EVOLUÇÃO  /  NÍVEL %02d" % world.resources.level, 14, UI.LIME)
	UI.label(box, "Mais uma chance de resistir.", 38)
	UI.label(box, "Escolha uma melhoria. A partida está pausada.", 17, UI.MUTED)
	var row := UI.hbox(box, 18)
	var offers: Array = world.upgrades.roll()
	for i in range(offers.size()):
		var index := i
		var offer: Dictionary = offers[i]
		var card := UI.panel(row)
		card.custom_minimum_size = Vector2(320, 220)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := UI.vbox(card, 16)
		UI.label(column, offer.tag, 12, UI.LIME)
		UI.label(column, offer.title, 22)
		var detail := UI.label(column, offer.text, 17, UI.MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UI.button(column, "ESCOLHER   →", func(): choose_upgrade(index), true)

func choose_upgrade(index: int) -> void:
	if mode != "upgrade" or not world.upgrades.choose(index):
		return
	if world.resources.pending > 0:
		# Build the next offer on a later frame; old button signals cannot select it.
		mode = "transition"
		call_deferred("show_upgrade")
	else:
		close_modal()

func show_result() -> void:
	var box := open_modal("result", 700)
	UI.label(box, "O AMANHECER CHEGOU" if world.won else "O SILÊNCIO TOMOU O REFÚGIO", 13, UI.LIME)
	UI.label(box, "VOCÊ RESISTIU." if world.won else "FIM DA LINHA.", 47)
	UI.label(box, world.ending_reason, 20, UI.MUTED)
	UI.spacer(box, 12)
	UI.label(box, "HORDA %02d   /   %d ELIMINAÇÕES   /   %02d:%02d" % [world.waves.wave, world.kills, int(world.elapsed) / 60, int(world.elapsed) % 60], 22)
	UI.label(box, "Nível %d   ·   %d sucata restante" % [world.resources.level, world.resources.scrap], 17, UI.MUTED)
	UI.spacer(box, 12)
	UI.button(box, "JOGAR NOVAMENTE", restart, true)
	UI.button(box, "VOLTAR AO MENU", menu)

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
