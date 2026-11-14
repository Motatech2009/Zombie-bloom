extends Node3D
var canvas: CanvasLayer
var root: Control
var content: VBoxContainer
var sun: DirectionalLight3D
var camera: Camera3D
var actors: Array[Node3D] = []
var clock: float = 0
var menu_panel: PanelContainer
var menu_margin: MarginContainer
var home := true

func _ready() -> void:
	var music := MusicDirector.new(); add_child(music)
	MobilePlatform.configure(get_tree().root)
	get_tree().paused = false
	Controls.setup()
	ClayStyle.prewarm()
	GameSettings.load_settings()
	MobilePlatform.configure(get_tree().root)
	sun = VisualFactory.lighting(self)
	sun.shadow_enabled = GameSettings.use_shadows()
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
	menu_panel = PanelContainer.new()
	root.add_child(menu_panel)
	menu_panel.add_theme_stylebox_override("panel",UI.style(Color(.025,.07,.09,.82),Color(.18,.28,.27,.35),18))
	menu_margin = MarginContainer.new()
	menu_panel.add_child(menu_margin)
	var margin := menu_margin
	root.resized.connect(layout_menu)
	var menu_scroll := ScrollContainer.new()
	margin.add_child(menu_scroll)
	menu_scroll.scroll_deadzone = 12
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = UI.vbox(menu_scroll,7)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_main()
	var footer := UI.label(root,"v"+str(ProjectSettings.get_setting("application/config/version","1.0.0-dev")),13,Color("c1d2c5"))
	footer.name = "VersionLabel"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -200; footer.offset_right = -18; footer.offset_top = -32; footer.offset_bottom = -10
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layout_menu()
	if "--smoke-menu" in OS.get_cmdline_user_args():
		get_tree().create_timer(1).timeout.connect(func(): get_tree().quit())

func clear_content() -> void:
	home = false
	layout_menu()
	if content.get_parent() is ScrollContainer: content.get_parent().scroll_vertical = 0
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func layout_menu() -> void:
	if not is_instance_valid(menu_panel): return
	var size := root.size
	var mobile := MobilePlatform.enabled()
	var width := minf(350 if mobile else 430,size.x*.44) if home else minf(570,size.x-40)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	menu_panel.offset_left = 20 if mobile else 42
	menu_panel.offset_right = menu_panel.offset_left+width
	menu_panel.offset_top = 12 if mobile else 42
	menu_panel.offset_bottom = -44 if mobile else -52
	for edge in ["left","right"]: menu_margin.add_theme_constant_override("margin_"+edge,18 if mobile else 28)
	for edge in ["top","bottom"]: menu_margin.add_theme_constant_override("margin_"+edge,10 if mobile else 22)
	if is_instance_valid(content): content.add_theme_constant_override("separation",5 if home and mobile else 7)

func menu_button(parent: Node,title: String,callback: Callable,primary: bool = false) -> Button:
	var button := UI.button(parent,title,callback,primary)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 46 if MobilePlatform.enabled() else 50
	button.add_theme_font_size_override("font_size",15 if MobilePlatform.enabled() else 17)
	for state in ["normal","hover","pressed"]:
		var color := UI.LIME if primary or state!="normal" else Color(.06,.13,.15,.68)
		var style := UI.style(color,UI.LIME if primary else Color(.3,.43,.4,.45),8)
		style.content_margin_top = 9; style.content_margin_bottom = 9; style.content_margin_left = 16
		button.add_theme_stylebox_override(state,style)
	return button

func show_main() -> void:
	clear_content(); home = true; layout_menu()
	UI.label(content,"MOTA TECH  /  SOBREVIVÊNCIA COOPERATIVA",10,UI.MUTED)
	UI.label(content,"ZOMBIE",26 if MobilePlatform.enabled() else 45)
	UI.label(content,"BLOOM.",32 if MobilePlatform.enabled() else 56,UI.LIME)
	if not MobilePlatform.enabled():
		UI.label(content,"O mundo acabou. Seu refúgio ainda resiste.",14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.spacer(content,4)
	menu_button(content,"JOGAR",show_play,true)
	menu_button(content,"JOGAR COM AMIGOS",show_multiplayer)
	menu_button(content,"MEU ELO / CLASSIFICAÇÃO",show_rankings)
	var progress := UI.label(content,RankProgress.summary(int(Account.local_summary.get("kills",0))) if Account.signed_in() else "Entre para conquistar seu primeiro elo: 100 abates.",12,UI.LIME)
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_button(content,"CONFIGURAÇÕES",show_settings)
	var secondary := UI.hbox(content,8)
	menu_button(secondary,"COMO JOGAR",show_help).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button(secondary,"SAIR",func(): get_tree().quit())

func show_play() -> void:
	clear_content()
	UI.label(content,"SEU PRÓXIMO REFÚGIO",26,UI.LIME)
	UI.label(content,"Escolha a campanha ou resista por quanto tempo conseguir.",16,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_button(content,"NOVA CAMPANHA / 20 HORDAS",func(): choose_mode("campaign"),true)
	menu_button(content,"NOVA DEFESA INFINITA",func(): choose_mode("endless"))
	for mode in ["campaign","endless"]:
		var selected: String = mode
		var exists := false
		for version in ["v6","v5","v4","v3","v2"]:
			if FileAccess.file_exists("user://zombie_bloom_"+mode+"_"+version+".json"): exists = true
		if mode=="campaign" and FileAccess.file_exists("user://zombie_bloom_arena_campaign.json"): exists = true
		if exists: menu_button(content,"CONTINUAR "+("CAMPANHA" if mode=="campaign" else "INFINITO"),func(): resume_mode(selected))
	menu_button(content,"VOLTAR",show_main)

func resume_mode(mode: String) -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = mode
	continue_campaign()

func choose_mode(mode: String) -> void:
	load("res://scripts/campaign/campaign_world.gd").next_mode = mode
	start_game()

func start_game() -> void:
	var campaign = load("res://scripts/campaign/campaign_world.gd")
	if FileAccess.file_exists("user://zombie_bloom_"+campaign.next_mode+"_v6.json") or FileAccess.file_exists("user://zombie_bloom_"+campaign.next_mode+"_v5.json") or FileAccess.file_exists("user://zombie_bloom_"+campaign.next_mode+"_v4.json"):
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
	var help := UI.label(content,"WASD mover · SHIFT correr · Mouse mirar\nESPAÇO rolamento · recarga de 5 segundos\nClique usar / disparar · R recarregar · 1–9 barra\nB construir · Q girar · 1–9 / 0 peças na prévia\nSegure E abrir caixas / depositar · E atravessar\nG melhorar · X desmontar · F portão\nV armeiro · C granada · H atalhos\nM mapa · I / TAB bolsa e depósito\nF5 salvar · F9 restaurar · ESC pausa\n\nAs hordas começam pelo relógio, com um chefe\nem cada rodada, mesmo quando você está longe.\nSua base continua lutando e pode ser destruída.\n\nUse E nas saídas Norte, Leste, Sul ou Oeste.\nCada entrada gera outro cenário e loot.\nHá setores tranquilos e outros infestados.\nDrops de infectados: coleta automática.\nCaixas exigem tempo. Airdrop a cada 10 minutos.\n\nO Núcleo é fixo em (0,0). M mostra seu caminho.\nDefesas limitadas por cerco. Bolsa: 18 espaços.\nCampanha: 20 cercos. Infinito: sem rodada final.",17,UI.MUTED)
	if MobilePlatform.enabled(): help.text = "Toque na metade esquerda: analógico flutuante para mover. Empurre até a borda para correr.\nToque no zumbi: escolhe o alvo. Segure ATIRAR para disparar. Toque no chão para cancelar.\nA trava pausa atrás de paredes ou fora de alcance e termina quando o alvo morre.\nSEGURE ATIRAR: escolhe um alvo visível e alcançável. Solte para parar.\nGranada e kit: um uso por toque no botão. Toque no cenário para apontar a granada.\nModo leve: menos detalhes e efeitos, com contador de FPS.\nROLAR: esquiva com recarga de 5 segundos.\nRECARREGAR: usa munição da mochila.\nCOLETAR: segure nas caixas, no Núcleo ou para ajudar um aliado. Nas saídas, toque para atravessar.\nBOLSA: organize os 18 espaços. As setas da barra alcançam os nove espaços rápidos.\nAÇÕES: mapa, construção, vendedor, melhorias e portões.\nConstrução: escolha a defesa, toque no chão, gire e confirme COLOCAR.\n\nPara jogar com PC: o computador cria a sala e o Android entra com o mesmo IP e porta UDP. Atualizem ambos para a mesma versão.\n\nHordas começam pelo relógio. Áreas e loot ficam preservados por três minutos; sair e voltar antes não renova.\nSolo: coleta e depósito levam 40% menos tempo. Chefes têm mais vida e suprimentos extras.\nTransporte os recursos ao Núcleo, limpe casas e mantenha as defesas."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(content,"VOLTAR",show_main)

func show_settings() -> void:
	clear_content()
	UI.label(content, "CONFIGURAÇÕES", 35)
	UI.spacer(content, 28)
	UI.settings(content, func(): MobilePlatform.configure(get_tree().root); ClayStyle.refresh_tree(self); sun.shadow_enabled = GameSettings.use_shadows())
	UI.spacer(content, 12)
	UI.button(content, "VOLTAR", show_main)

func _process(delta: float) -> void:
	clock += delta
	for i in range(actors.size()):
		VisualFactory.animate_human(actors[i], clock + i, .25, 0, false)

func show_multiplayer() -> void:
	clear_content()
	UI.label(content,"COOPERATIVO / ATÉ 4",28,UI.LIME)
	UI.label(content,"Conexão direta. Exploração por quadrantes independentes.
2 jogadores = x2; 3 = x4; 4 = x8 infectados.",17,UI.MUTED)
	var name_field := LineEdit.new()
	name_field.placeholder_text = "Seu nome"
	name_field.text = Account.nickname
	name_field.max_length = 16
	content.add_child(name_field)
	var address := LineEdit.new()
	address.placeholder_text = "IP, IP:porta ou endereço da rede virtual"
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
	var internet_check := CheckButton.new()
	internet_check.text = "Tentar abrir a porta no roteador (UPnP / internet)"
	content.add_child(internet_check)
	UI.label(content,"Em casas diferentes: use IP público com porta aberta ou o IP do Tailscale. Veja CONEXÃO no menu da sala.",14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		if coop.host_session(int(port.value))==OK:
			if internet_check.button_pressed: coop.internet.enable(int(port.value))
			get_tree().change_scene_to_file("res://scenes/survival/SurvivalWorld.tscn")
	,true)
	UI.button(content,"ENTRAR NO IP",func(): coop.join_session(address.text.strip_edges(),int(port.value),name_field.text))
	UI.button(content,"CANCELAR / VOLTAR",func(): coop.close_session(); show_main())

func _notification(what: int) -> void:
	if MobilePlatform.enabled() and what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(content): show_main()

func show_account() -> void:
	clear_content()
	menu_button(content,"‹ VOLTAR AO MENU",show_main)
	UI.label(content,"MINHA CONTA",27,UI.LIME)
	UI.label(content,"Seu progresso, seu nome no ranking.",15,UI.MUTED)
	var name_field := LineEdit.new(); name_field.text = Account.nickname; name_field.max_length = 16; name_field.placeholder_text = "Apelido público"; content.add_child(name_field)
	menu_button(content,"SALVAR APELIDO",func(): Account.save_online_profile(name_field.text))
	var email := LineEdit.new(); email.placeholder_text = "E-mail"; content.add_child(email)
	var password := LineEdit.new(); password.placeholder_text = "Senha (mínimo 8 caracteres)"; password.secret = true; content.add_child(password)
	for field in [name_field,email,password]: field.custom_minimum_size.y = 44
	var buttons: Array[Button] = []
	buttons.append(menu_button(content,"ENTRAR",func():
		var value := password.text; password.clear(); Account.authenticate(email.text,value),true))
	buttons.append(menu_button(content,"CRIAR CONTA",func():
		Account.save_nickname(name_field.text)
		var value := password.text; password.clear(); Account.authenticate(email.text,value,true)))
	buttons.append(menu_button(content,"ESQUECI MINHA SENHA",func(): Account.recover(email.text)))
	var logout := menu_button(content,"SAIR DA CONTA",func(): Account.logout())
	var status_label := UI.label(content,Account.status,15,UI.MUTED); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var summary := UI.label(content,"",15,UI.LIME); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_button(content,"VER RANKINGS",show_rankings)
	menu_button(content,"VOLTAR",show_main)
	var refresh := func():
		if not is_instance_valid(status_label): return
		status_label.text = Account.status
		for button in buttons: button.disabled = Account.busy or Account.signed_in() if button!=buttons[2] else Account.busy
		logout.visible = Account.signed_in(); logout.disabled = Account.busy
		email.visible = not Account.signed_in(); password.visible = not Account.signed_in()
		summary.text = "%s · %d abates · %d hordas · %d sucata" % [Account.nickname,Account.local_summary.get("kills",0),Account.local_summary.get("hordes",0),Account.local_summary.get("scrap",0)] if Account.signed_in() else "Jogue como convidado ou entre para registrar seus resultados."
	refresh.call(); Account.changed.connect(refresh)
	status_label.tree_exiting.connect(func(): Account.changed.disconnect(refresh))

func show_rankings() -> void:
	clear_content()
	menu_button(content,"‹ VOLTAR AO MENU",show_main)
	UI.label(content,"MURAL DOS SOBREVIVENTES",23,UI.LIME)
	var kills := int(Account.local_summary.get("kills",0))
	var personal := UI.hbox(content,16)
	var badge := RankBadge.new(); badge.level = RankProgress.tier(kills); personal.add_child(badge)
	var info := UI.vbox(personal,4); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(info,Account.nickname if Account.signed_in() else "CONVIDADO",19)
	UI.label(info,RankProgress.summary(kills),13,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bar := UI.meter(info); bar.max_value = RankProgress.next_goal(kills); bar.value = kills
	menu_button(content,"MINHA CONTA / ENTRAR",show_account)
	UI.label(content,"SEU ELO CRESCE COM ABATES · A POSIÇÃO COMPARA JOGADORES REAIS",11,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var metric := OptionButton.new(); metric.add_item("Zumbis mortos"); metric.add_item("Hordas vencidas"); metric.add_item("Sucata coletada"); metric.custom_minimum_size.y = 44; content.add_child(metric)
	var consult := menu_button(content,"CONSULTAR CLASSIFICAÇÃO",func(): Account.fetch_ranking(["kills","hordes","scrap"][metric.selected]),true)
	var status_label := UI.label(content,Account.status,13,UI.MUTED); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var results := UI.vbox(content,8)
	UI.label(results,"Consulte para ver jogadores reais. Nenhum perfil fictício é adicionado.",14,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var refresh := func():
		if not is_instance_valid(status_label): return
		consult.disabled = Account.busy; status_label.text = Account.status
		for child in results.get_children(): results.remove_child(child); child.queue_free()
		if Account.rows.is_empty(): UI.label(results,"Ainda não há resultados nesta consulta.",15,UI.MUTED)
		for row in Account.rows:
			var card := UI.panel(results)
			card.add_theme_stylebox_override("panel",UI.style(Color("203c3b"),Color("7d9170") if int(row.position)<=3 else Color("3c5654"),14))
			var line := UI.hbox(card,10)
			UI.label(line,"#%02d" % row.position,20,UI.LIME)
			var emblem := RankBadge.new(); emblem.level = RankProgress.tier(int(row.get("kills",0))); emblem.custom_minimum_size = Vector2(48,54); line.add_child(emblem)
			var player_info := UI.vbox(line,2); player_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UI.label(player_info,str(row.nickname),17).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UI.label(player_info,RankProgress.TITLES[emblem.level],12,UI.MUTED)
			UI.label(line,str(row.score),19,UI.LIME)
	Account.changed.connect(refresh)
	status_label.tree_exiting.connect(func(): Account.changed.disconnect(refresh))
	UI.label(content,"ELOS POR ABATES",16,UI.LIME)
	var gallery := GridContainer.new(); gallery.columns = 5; content.add_child(gallery)
	for i in range(10):
		var column := UI.vbox(gallery,2); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := RankBadge.new(); icon.level = i+1; icon.custom_minimum_size = Vector2(65,68); column.add_child(icon)
		UI.label(column,str(RankProgress.THRESHOLDS[i]),12,UI.MUTED)
