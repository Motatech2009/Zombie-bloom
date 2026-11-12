extends "res://scripts/ui/hud.gd"
var cargo_text: Label
var place_text: Label
var prompt_text: Label

func _ready() -> void:
	super._ready()
	var panel := UI.panel(root)
	panel.position = Vector2(24, 210)
	panel.custom_minimum_size = Vector2(465, 118)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UI.vbox(panel, 5)
	place_text = UI.label(box, "VALE DO CEDRO", 15, UI.LIME)
	cargo_text = UI.label(box, "MOCHILA", 14)
	prompt_text = UI.label(box, "F · Interagir", 14, UI.MUTED)
	prompt_text.custom_minimum_size.x = 440
	prompt_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.move_to_front()

func create_bottom() -> void:
	super.create_bottom()
	# Reuse the existing combat layout and update its actual instructions.
	for child in root.get_children():
		update_help(child)

func update_help(node: Node) -> void:
	if node is Label and node.text.begins_with("WASD mover"):
		node.text = "WASD mover · SHIFT correr · R recarregar\nF extrair/interagir · B construir · E reparar · U melhorar\nM mapa · F5 salvar na base · F9 restaurar"
	for child in node.get_children():
		update_help(child)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(world.player):
		return
	wave_text.text = "HORDA %02d" % world.waves.wave
	wave_detail.text = "%d invasores" % world.waves.remaining() if world.phase == "combat" else "Explore e fortaleça a base"
	phase_text.text = "INTERIOR" if world.inside else "DEFENDENDO" if world.phase == "combat" else "EXPLORAÇÃO"
	if not world.builder.active:
		build_text.text = "F interage · M mapa · Volte ao refúgio para depositar a carga" if world.phase == "prep" else "DEFENDA O NÚCLEO · Construção disponível após conter a horda"
	var pos: Vector3 = world.return_position if world.inside else world.player.global_position
	var region: String = world.outdoor.generator.region_at(Vector2(pos.x, pos.z))
	var biome: String = world.outdoor.generator.biome_at(Vector2(pos.x, pos.z))
	place_text.text = "INTERIOR · " + WorldGenerator.building_title(world.current_house.kind).to_upper() if world.inside else "%s · %s" % [region.to_upper(), biome]
	cargo_text.text = "MOCHILA %02d / %d · Madeira %d · Pedra %d · Metal %d" % [world.state.cargo_total(), WorldState.CAPACITY, world.state.cargo.wood, world.state.cargo.stone, world.state.cargo.metal]
	prompt_text.text = world.interaction_text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("world_map"):
		get_viewport().set_input_as_handled()
		if mode == "map":
			close_modal()
		elif mode.is_empty():
			show_map()
	else:
		super._unhandled_input(event)

func show_map() -> void:
	var box := open_modal("map", 780)
	UI.label(box, "MAPA REGIONAL", 28)
	UI.label(box, "Áreas claras foram carregadas · Azul: você · Verde: refúgio", 15, UI.MUTED)
	var viewport := Control.new()
	viewport.custom_minimum_size = Vector2(680, 450)
	viewport.clip_contents = true
	box.add_child(viewport)
	var map := WorldMap.new()
	map.world = world
	viewport.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.label(box, "Seed %d · M ou ESC para fechar\nEstradas levam aos assentamentos. Atravesse o rio pela ponte ao sul." % world.state.world_seed, 14, UI.MUTED)
	UI.button(box, "VOLTAR À EXPEDIÇÃO", close_modal, true)

func show_pause() -> void:
	super.show_pause()
	if mode == "pause":
		UI.label(overlay_box, "F5 salva na base, sem hostis próximos.\nVoltar ao menu descarta o progresso desde o último salvamento.", 14, UI.MUTED)
