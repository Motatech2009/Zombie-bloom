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
	var menu_scroll := ScrollContainer.new()
	margin.add_child(menu_scroll)
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = UI.vbox(menu_scroll,7)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_main()
	var footer := UI.label(root, "GODOT 4.6   /   SOLO + COOPERATIVO", 13, Color("c1d2c5"))
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
	UI.label(content, "ZOMBIE", 50)
	var bloom := UI.label(content, "BLOOM.", 62, UI.LIME)
	bloom.add_theme_constant_override("outline_size", 0)
	UI.label(content, "O mundo acabou.\nSeu refúgio ainda resiste.", 24)
	UI.spacer(content, 4)
	var description := UI.label(content, "Construa sua fortaleza e resista ao cerco.\nSetores imprevisíveis. Cercos automáticos.", 17, UI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.spacer(content, 6)
	UI.button(content,"CAMPANHA / 20 HORDAS",func(): choose_mode("campaign"),true)
	UI.button(content,"DEFESA INFINITA / ∞",func(): choose_mode("endless"))
	if FileAccess.file_exists("user://zombie_bloom_campaign_v4.json") or FileAccess.file_exists("user://zombie_bloom_campaign_v3.json") or FileAccess.file_exists("user://zombie_bloom_campaign_v2.json") or FileAccess.file_exists("user://zombie_bloom_arena_campaign.json"):
		UI.button(content,"CONTINUAR CAMPANHA",func(): resume_mode("campaign"))
	if FileAccess.file_exists("user://zombie_bloom_endless_v4.json") or FileAccess.file_exists("user://zombie_bloom_endless_v3.json") or FileAccess.file_exists("user://zombie_bloom_endless_v2.json"):
		UI.button(content,"CONTINUAR INFINITO",func(): resume_mode("endless"))
	UI.button(content,"JOGAR COM AMIGOS",show_multiplayer)
	UI.button(content, "COMO JOGAR", show_help)
	UI.button(content, "CONFIGURAÇÕES", show_settings)
	UI.button(content, "SAIR", func(): get_tree().quit())
	UI.spacer(content, 4)
	UI.label(content, "SOBREVIVÊNCIA 0.7   ·   ÚLTIMO REFÚGIO", 12, UI.MUTED)

func resume_mode(mode: String) -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = mode
	continue_campaign()

func choose_mode(mode: String) -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = mode
	start_game()

func start_game() -> void:
	var campaign = load("res://scripts/campaign/campaign_world.gd")
	if FileAccess.file_exists("user://zombie_bloom_"+campaign.next_mode+"_v4.json"):
		clear_content()
		UI.label(content,"NOVO REFÚGIO",35,UI.LIME)
		UI.label(content,"O próximo checkpoint substituirá a campanha atual.
Quer começar outro refúgio?",20,UI.MUTED)
		UI.button(content,"COMEÇAR NOVO REFÚGIO",begin_campaign,true)
		UI.button(content,"CONTINUAR O SALVO",continue_campaign)
		UI.button(content,"VOLTAR",show_main)
	else:
		begin_campaign()

func begin_campaign() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = false
	get_tree().change_scene_to_file("res://scenes/survival/SurvivalWorld.tscn")

func continue_campaign() -> void:
	load("res://scripts/campaign/campaign_world.gd").resume_requested = true
	get_tree().change_scene_to_file("res://scenes/survival/SurvivalWorld.tscn")

func show_help() -> void:
	clear_content()
	UI.label(content,"DEFENDA. EXPLORE. CONSTRUA.",27,UI.LIME)
	var help := UI.label(content,"WASD mover · SHIFT correr · Mouse mirar\nClique usar / disparar · R recarregar · 1–9 barra\nB construir · Q girar · 1–6 peças na prévia\nSegure E coletar / depositar · E atravessar\nG melhorar · X desmontar · F portão\nV armeiro · C granada · H atalhos\nM mapa · I / TAB bolsa e depósito\nF5 salvar · F9 restaurar · ESC pausa\n\nAs hordas começam pelo relógio, com um chefe\nem cada rodada, mesmo quando você está longe.\nSua base continua lutando e pode ser destruída.\n\nUse E nas saídas Norte, Leste, Sul ou Oeste.\nCada entrada gera outro cenário e loot.\nHá setores tranquilos e outros infestados.\nColetar leva tempo. Leve materiais ao Núcleo.\n\nO Núcleo é fixo em (0,0). M mostra seu caminho.\nDefesas limitadas por cerco. Bolsa: 18 espaços.\nCampanha: 20 cercos. Infinito: sem rodada final.",17,UI.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(content,"VOLTAR",show_main)

func show_settings() -> void:
	clear_content()
	UI.label(content, "CONFIGURAÇÕES", 35)
	UI.spacer(content, 28)
	UI.settings(content, func(): sun.shadow_enabled = GameSettings.shadows)
	UI.spacer(content, 12)
	UI.button(content, "VOLTAR", show_main)

func _process(delta: float) -> void:
	clock += delta
	for i in range(actors.size()):
		VisualFactory.animate_human(actors[i], clock + i, .25, 0, false)

func show_multiplayer() -> void:
	clear_content()
	UI.label(content,"COOPERATIVO / ATÉ 4",28,UI.LIME)
	UI.label(content,"Conexão direta. O grupo viaja junto.
2 jogadores = x2; 3 = x4; 4 = x8 infectados.",17,UI.MUTED)
	var name_field := LineEdit.new()
	name_field.placeholder_text = "Seu nome"
	name_field.text = "Sobrevivente"
	name_field.max_length = 16
	content.add_child(name_field)
	var address := LineEdit.new()
	address.placeholder_text = "IP do anfitrião"
	address.text = "127.0.0.1"
	content.add_child(address)
	var port := SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = 24567
	content.add_child(port)
	var mode_picker := OptionButton.new()
	mode_picker.add_item("Defesa infinita")
	mode_picker.add_item("Campanha de 20 cercos")
	content.add_child(mode_picker)
	var resume_check := CheckButton.new()
	resume_check.text = "Continuar o refúgio salvo deste modo"
	content.add_child(resume_check)
	var status := UI.label(content,"LAN: use o IP local. Internet: o anfitrião precisa receber UDP na porta escolhida.",15,UI.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var coop := get_node("/root/Coop")
	var on_status := func(message: String):
		if is_instance_valid(status): status.text = message
	if not coop.status_changed.is_connected(on_status): coop.status_changed.connect(on_status)
	UI.button(content,"CRIAR SALA",func():
		load("res://scripts/campaign/campaign_world.gd").next_mode = "endless" if mode_picker.selected==0 else "campaign"
		load("res://scripts/campaign/campaign_world.gd").resume_requested = resume_check.button_pressed
		coop.nickname = name_field.text.strip_edges().left(16)
		if coop.host_session(int(port.value))==OK: get_tree().change_scene_to_file("res://scenes/survival/SurvivalWorld.tscn")
	,true)
	UI.button(content,"ENTRAR NO IP",func(): coop.join_session(address.text.strip_edges(),int(port.value),name_field.text))
	UI.button(content,"CANCELAR / VOLTAR",func(): coop.close_session(); show_main())
