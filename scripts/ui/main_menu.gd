extends Node3D
var canvas: CanvasLayer
var root: Control
var content: VBoxContainer
var sun: DirectionalLight3D
var camera: Camera3D
var actors: Array[Node3D] = []
var clock: float = 0

func _ready() -> void:
	get_tree().paused = false
	Controls.setup()
	BetaOptions.setup()
	WorldState.next_seed = BetaOptions.last_seed
	GameSettings.load_settings()
	sun = VisualFactory.lighting(self)
	sun.shadow_enabled = GameSettings.shadows
	add_child(Arena.new())
	var display := Node3D.new()
	add_child(display)
	display.position = Vector3(2, 0, 1)
	VisualFactory.cylinder(display, 2, .5, Vector3(0, .25, 0), Color("243f43"))
	VisualFactory.box(display, Vector3(2.6, 1.8, 2.6), Vector3(0, 1.3, 0), Color("49615b"))
	VisualFactory.cylinder(display, .5, 1, Vector3(0, 2.6, 0), UI.LIME, true)
	VisualFactory.ring(display, 1.7, Vector3(0, 2.0, 0), UI.LIME)
	for i in range(8):
		var parent := Node3D.new()
		add_child(parent)
		parent.position = Vector3(cos(i * .8) * 8 + 2, 0, sin(i * .8) * 9)
		parent.rotation.y = -i * .8 + PI * .5
		actors.append(VisualFactory.human(parent, Color("627653"), false))
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23
	camera.position = Vector3(22, 26, 23)
	camera.look_at(Vector3(-3, 0, 1))
	canvas = CanvasLayer.new()
	add_child(canvas)
	root = Control.new()
	canvas.add_child(root)
	UI.fill(root)
	root.theme = UI.theme()
	var dim := ColorRect.new()
	root.add_child(dim)
	UI.fill(dim)
	dim.color = Color(.018, .045, .06, .35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := PanelContainer.new()
	root.add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 610
	left.add_theme_stylebox_override("panel", UI.style(Color(.025, .07, .09, .94), Color("263c41"), 0))
	var margin := MarginContainer.new()
	left.add_child(margin)
	margin.add_theme_constant_override("margin_left", 58)
	margin.add_theme_constant_override("margin_right", 58)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 24)
	content = UI.vbox(margin, 7)
	show_main()
	var footer := UI.label(root, "GODOT 4.6   /   SINGLE-PLAYER   /   OFFLINE", 13, Color("c1d2c5"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.position += Vector2(-440, -35)
	if "--smoke-menu" in OS.get_cmdline_user_args():
		get_tree().create_timer(1).timeout.connect(func(): get_tree().quit())

func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func show_main() -> void:
	clear_content()
	UI.label(content, "MOTA TECH   /   PROJETO 001", 13, UI.LIME)
	UI.spacer(content, 12)
	UI.label(content, "ÚLTIMO", 56)
	var bloom := UI.label(content, "REFÚGIO.", 68, UI.LIME)
	bloom.add_theme_constant_override("outline_size", 0)
	UI.label(content, "O mundo acabou.\nSeu refúgio ainda resiste.", 24)
	UI.spacer(content, 4)
	var description := UI.label(content, "Um refúgio. Um mundo para explorar.\nExtraia recursos, volte à base e construa sua sobrevivência.", 17, UI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.spacer(content, 6)
	UI.button(content, "EXPLORAR O MUNDO   →", start_game, true)
	if FileAccess.file_exists(BetaPersistence.path(WorldState.next_seed)):
		UI.button(content, "CONTINUAR REFÚGIO", continue_world)
	UI.label(content, "BETA 1 · Hordas migratórias, sem ondas agendadas", 13, UI.MUTED)
	UI.button(content, "COMO JOGAR", show_help)
	UI.button(content, "CONFIGURAÇÕES", show_settings)
	UI.button(content, "SAIR", func(): get_tree().quit())
	UI.spacer(content, 4)
	UI.label(content, "BETA 1   ·   ÚLTIMO REFÚGIO", 12, UI.MUTED)

func start_game() -> void:
	if FileAccess.file_exists(BetaPersistence.path(WorldState.next_seed)):
		clear_content()
		UI.label(content, "JÁ EXISTE UM REFÚGIO", 28, UI.LIME)
		UI.label(content, "Esta seed possui um salvamento. Uma nova campanha só substituirá esse arquivo quando você salvar. Para manter ambos, escolha outra seed nas configurações.", 18, UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.button(content, "CONTINUAR CAMPANHA SALVA", continue_world, true)
		UI.button(content, "INICIAR NOVA NESTA SEED", begin_beta)
		UI.button(content, "VOLTAR", show_main)
		return
	begin_beta()

func begin_beta() -> void:
	WorldState.resume_requested = false
	get_tree().change_scene_to_file("res://scenes/beta/BetaWorld.tscn")

func continue_world() -> void:
	WorldState.resume_requested = true
	get_tree().change_scene_to_file("res://scenes/beta/BetaWorld.tscn")

func show_help() -> void:
	clear_content()
	UI.label(content, "MANUAL DO REFÚGIO", 28, UI.LIME)
	var text := UI.label(content, "WASD mover · mouse mirar · clique atacar\nShift correr · Espaço rolar (sem imunidade)\nE interagir / segurar para extrair\nI mochila · C fabricar · B construir · Q girar\nF reparar · L lanterna · M mapa\nR recarregar · 1–6 barra rápida\nF5 salvar · F9 restaurar · Esc pausar\n\nSaia para buscar materiais e leve-os ao depósito.\nAs armas de fogo usam munição da mochila.\nSlots e peso limitam o transporte: acima de\n125% da carga, corrida e rolamento param.\n\nConstrua bancada, paredes, portão e caixas.\nHordas são grupos que migram pelo mundo: podem\npassar longe da base ou investigar luz e ruído.\nNão há cronômetro de ataques nem vitória por ondas.\n\nSalve antes de sair. Voltar ao menu não salva\na campanha automaticamente.", 17, UI.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(content, "VOLTAR", show_main)

func show_settings() -> void:
	clear_content()
	UI.label(content, "CONFIGURAÇÕES", 35)
	UI.spacer(content, 28)
	UI.label(content, "SEED DO NOVO MUNDO", 14, UI.LIME)
	var seed_input := SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 2147483647
	seed_input.value = WorldState.next_seed
	seed_input.value_changed.connect(func(value: float): WorldState.next_seed = int(value); BetaOptions.last_seed = int(value); BetaOptions.save())
	content.add_child(seed_input)
	UI.label(content, "A mesma seed repete o mapa. Continuar usa a seed salva.", 13, UI.MUTED)
	UI.settings(content, func(): sun.shadow_enabled = GameSettings.shadows)
	UI.spacer(content, 12)
	UI.button(content, "VOLTAR", show_main)

func _process(delta: float) -> void:
	clock += delta
	for i in range(actors.size()):
		VisualFactory.animate_human(actors[i], clock + i, .25, 0, false)
