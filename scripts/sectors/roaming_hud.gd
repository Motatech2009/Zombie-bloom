extends "res://scripts/campaign/campaign_hud.gd"
var map_clock: Label
var map_detail: Label

func create_bottom() -> void:
	super.create_bottom()
	for child in hints.get_children():
		if child is HBoxContainer: child.get_child(0).text = "M MAPA"

func clock_text() -> String:
	var seconds := ceili(world.horde_left)
	return "%02d:%02d" % [seconds/60,seconds%60]

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(world.player): return
	next_button.visible = false
	if world.waves.running:
		wave_detail.text = "%d hostis no Núcleo" % world.waves.remaining()
		for boss in get_tree().get_nodes_in_group("boss_enemies"):
			if not boss.field_enemy:
				wave_detail.text = "CHEFE %d%% · %d hostis" % [ceili(100*boss.health.current/boss.health.maximum),world.waves.remaining()]
				break
	else: wave_detail.text = "PRÓXIMA "+clock_text()
	wave_detail.add_theme_color_override("font_color",Color("ef9274") if world.waves.running or world.horde_left<=60 else UI.LIME)
	location_text.text = "NÚCLEO (0,0) · M mapa · E nas saídas" if world.area_index==-1 else "SETOR (%d,%d) · %s · M mapa" % [world.sector_coord.x,world.sector_coord.y,SectorGenerator.RISKS[world.descriptor.risk]]
	if world.area_index!=-1 and world.waves.running:
		build_text.text = "NÚCLEO SOB ATAQUE · "+world.return_hint()
		build_text.modulate = Color("ef9274")
	elif not world.builder.active:
		for i in range(4):
			if world.local_player().distance_to(SectorGenerator.EXITS[i])<7:
				var next: Vector2i = world.sector_coord+SectorGenerator.DIRECTIONS[i]
				build_text.text = "E / %s → (%d,%d)%s" % [SectorGenerator.NAMES[i].to_upper(),next.x,next.y," · NÚCLEO" if next==Vector2i.ZERO else ""]
				build_text.modulate = UI.LIME
				break
	if world.area_index!=-1 and not world.builder.active:
		for cache in world.caches:
			if cache.visible and world.player.position.distance_to(cache.global_position)<4:
				build_text.text = "E / ARSENAL ESCONDIDO" if cache.has_meta("weapon") else "E / CAIXA DE SUPRIMENTOS"
				break
	if mode=="routes" and is_instance_valid(map_clock):
		map_clock.text = "NÚCLEO SOB ATAQUE · VOLTE!" if world.waves.running else "PRÓXIMA HORDA EM "+clock_text()+" · o relógio continua neste mapa"
		map_clock.add_theme_color_override("font_color",Color("ef9274") if world.waves.running or world.horde_left<=60 else UI.LIME)

func show_routes() -> void:
	if not mode.is_empty() or world.phase=="ended": return
	world.builder.set_active(false)
	var box := open_modal("routes",1000)
	# A map is orientation, not an escape from an approaching horde.
	get_tree().paused = false
	UI.label(box,"MAPA DOS SETORES",29,UI.LIME)
	map_clock = UI.label(box,"",17,UI.LIME)
	var row := UI.hbox(box,24)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	row.add_child(grid)
	for y in range(map_center().y-3,map_center().y+4):
		for x in range(map_center().x-3,map_center().x+4):
			var coord := Vector2i(x,y)
			var key := SectorGenerator.key(coord)
			var known: bool = world.discovered.has(key)
			var text := "%d,%d\n?" % [x,y]
			if known: text = "%d,%d\n%s" % [x,y,"!" if int(world.discovered[key].risk)>=3 else "·"]
			if coord==Vector2i.ZERO: text = "0,0\nNÚCLEO"
			if coord==world.sector_coord: text = "%d,%d\nVOCÊ" % [x,y]
			var chosen := coord
			var button := UI.button(grid,text,func(): select_sector(chosen))
			button.set_meta("coord",coord)
			button.custom_minimum_size = Vector2(68,48)
			button.add_theme_font_size_override("font_size",12)
			button.add_theme_stylebox_override("normal",UI.style(Color("375750") if coord==world.sector_coord else Color("384849") if known else Color("182d33"),UI.LIME if coord==Vector2i.ZERO else Color("354b4e"),6))
	var side := UI.vbox(row,12)
	side.custom_minimum_size.x = 390
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(side,"POSIÇÃO: (%d,%d)" % [world.sector_coord.x,world.sector_coord.y],22)
	UI.label(side,world.return_hint(),17,UI.LIME).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(side,"Saídas nas quatro bordas. Aproxime-se e pressione E para cruzar. Clicar no mapa apenas consulta o setor.",16,UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(side,"? desconhecido · ! alto risco\nNorte = y−1 · Leste = x+1\nSul = y+1 · Oeste = x−1",15)
	map_detail = UI.label(side,"Ao sair de um setor, ele muda. O risco visto em uma visita não garante o próximo. Só o Núcleo permanece fixo.",16,UI.MUTED)
	map_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(box,"FECHAR MAPA / ESC",close_modal,true)

func select_sector(coord: Vector2i) -> void:
	world.waypoint = coord
	var key := SectorGenerator.key(coord)
	if coord==Vector2i.ZERO:
		map_detail.text = "NÚCLEO FIXO · Sua base, vendedor e defesas. "+world.return_hint()
	elif world.discovered.has(key):
		var info: Dictionary = world.discovered[key]
		map_detail.text = "(%d,%d) · %d visita(s)\nÚltimo risco: %s\nA próxima entrada gera outro cenário e loot." % [coord.x,coord.y,int(info.visits),SectorGenerator.RISKS[int(info.risk)]]
	else: map_detail.text = "(%d,%d) · NÃO EXPLORADO\nPode conter poucos infectados, uma multidão ou chefe. Veja o relógio antes de avançar." % [coord.x,coord.y]

func map_center() -> Vector2i: return world.sector_coord
