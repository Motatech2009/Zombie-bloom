extends Node
signal changed
var uid := ""
var clock := PlayClock16.new()
var world: Node3D
var session_id := ""
var sessions: Dictionary = {}
var pending: Array = []
var titan_pending: Array = []
var titan_earned: Dictionary = {}
var trophy_equipped: Dictionary = {}
var registered: Dictionary = {}
var observed_hordes: Dictionary = {}
var confirmed: Dictionary = {"balance":0,"owned":[],"equipped":{},"active_seconds":0,"longest_seconds":0}
var busy := false
var dirty := false
var disk_left := 5.0
var sync_left := 120.0
var api_url := ""
var backend := "firestore"
var local_economy := false
var wallet := LocalWallet16.new()
var status := "Entre para sincronizar horas e cosméticos."
var activity := false
var last_horde := 0
var bound_run := ""
var profile_loaded := false
func path() -> String: return "user://meta16_"+(uid if not uid.is_empty() else "guest").sha256_text().left(24)+".json"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load("res://online.cfg")==OK:
		api_url = str(cfg.get_value("services16","url",""))
		backend = str(cfg.get_value("services16","backend","firestore"))
	local_economy = bool(cfg.get_value("services16", "offline_wallet", true))
	if local_economy:
		wallet.load_wallet()
		status = "Carteira salva neste aparelho."
	Account.changed.connect(identity_changed)
	identity_changed()
func identity_changed() -> void:
	if uid==Account.user_id and not session_id.is_empty(): return
	persist(); uid = Account.user_id; profile_loaded = false; clock = PlayClock16.new(); sessions = {}; pending = []; registered = {}; observed_hordes = {}; titan_pending = []; titan_earned = {}; trophy_equipped = {}
	confirmed = {"balance":0,"owned":[],"equipped":{},"active_seconds":0,"longest_seconds":0}
	if FileAccess.file_exists(path()):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path()))
		if data is Dictionary:
			observed_hordes = data.get("observed_hordes",{}); sessions = data.get("sessions",{}); pending = data.get("pending",[]); registered = data.get("registered",{}); confirmed = data.get("confirmed",confirmed)
			titan_pending = data.get("titan_pending",[]); titan_earned = data.get("titan_earned",{}); trophy_equipped = data.get("trophy_equipped",{})
			if str(data.get("economy_backend","service"))!=backend:
				registered = {}; confirmed = {"balance":0,"owned":[],"equipped":{},"active_seconds":0,"longest_seconds":0}
			clock.total = maxf(0,float(data.get("total",0))); clock.longest = maxf(0,float(data.get("longest",0)))
	if local_economy: wallet.import_legacy(confirmed)
	session_id = Crypto.new().generate_random_bytes(16).hex_encode(); clock.last_ms = Time.get_ticks_msec(); sync_left = 2
	changed.emit()
func has_live_world() -> bool:
	return is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and is_instance_valid(world.player)
func observe_progress() -> void:
	if world.is_client and not world.client_scene_ready: return
	if bound_run!=world.account_run_id: bound_run = world.account_run_id; registered.erase(bound_run)
	if str(world.player.get_meta("titan_owner16","!"))==uid:
		titan_victory(bound_run,str(world.player.get_meta("titan_victory16","")))
	var reward_wave: int = int(world.upgrades.state(world.player).get("through",world.waves.wave))
	var prior := int(observed_hordes.get(bound_run,reward_wave))
	for wave in range(prior+1,reward_wave+1):
		if not horde(bound_run,wave): break
		prior = wave
	observed_hordes[bound_run] = prior
func release_world(previous: Node3D) -> void:
	if world!=previous: return
	# Capture the final reward watermark before the old scene's children are freed.
	if is_instance_valid(world) and is_instance_valid(world.player): observe_progress()
	world = null; activity = false
	clock.step(Time.get_ticks_msec(),false)
	persist()
	if not sessions.is_empty(): sync_left = minf(sync_left, 2.0)
func _input(event: InputEvent) -> void:
	if not has_live_world(): return
	if event is InputEventKey or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventJoypadButton: activity = true
	if event is InputEventMouseMotion and event.relative.length()>2: activity = true
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: clock.focused = false; persist()
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]: clock.focused = true; clock.last_ms = Time.get_ticks_msec()
	if what==NOTIFICATION_WM_CLOSE_REQUEST: persist()
func _process(delta: float) -> void:
	if has_live_world(): observe_progress()
	var eligible: bool = has_live_world() and world.phase!="ended" and not get_tree().paused and not world.combat_paused() and (not world.is_client or world.client_scene_ready)
	if eligible and world.network!=null and world.network.mode not in ["offline","host","client"]: eligible = false
	if eligible and world.hud.mode in ["pause","wardrobe","settings","connection"]: eligible = false
	if eligible:
		var frame: Dictionary = world.local_input(world.player)
		activity = activity or frame.get("move",Vector2.ZERO).length_squared()>.01 or bool(frame.get("fire",false)) or bool(frame.get("interact",false))
	var previous_seconds := int(clock.session)
	if clock.step(Time.get_ticks_msec(),eligible,activity)>0:
		if int(clock.session) > previous_seconds: sessions[session_id] = int(clock.session)
		dirty = true
	activity = false; disk_left -= delta; sync_left -= delta
	if dirty and disk_left<=0: persist(); disk_left = 5
	if sync_left<=0 and not busy: sync()
func persist() -> void:
	if session_id.is_empty(): return
	var file := FileAccess.open(path()+".tmp",FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify({"economy_backend":backend,"titan_pending":titan_pending,"titan_earned":titan_earned,"trophy_equipped":trophy_equipped,"observed_hordes":observed_hordes,"sessions":sessions,"total":clock.total,"longest":clock.longest,"pending":pending,"registered":registered,"confirmed":confirmed})); file.close()
	DirAccess.rename_absolute(path()+".tmp",path()); dirty = false
func available() -> bool: return backend=="firestore" or not api_url.is_empty()
func request(action: String,data: Dictionary = {}) -> Dictionary:
	if backend=="firestore": return await FirestoreEconomy16.new(Account).request(action,data)
	if api_url.is_empty() or not Account.signed_in(): return {"ok":false,"error":"Serviço 1.6 ainda não publicado."}
	if not await Account.ensure_token(): return {"ok":false,"error":"Entre novamente para sincronizar."}
	var req := HTTPRequest.new(); req.timeout = 15; add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+Account.token])
	var result := {"ok":false,"error":"Sem conexão. Progresso pendente preservado."}
	var owner := uid
	if req.request(api_url,headers,HTTPClient.METHOD_POST,JSON.stringify({"action":action,"data":data}))==OK:
		var response: Array = await req.request_completed
		var body = JSON.parse_string(response[3].get_string_from_utf8())
		if owner==uid and body is Dictionary: result = body; result.ok = response[0]==HTTPRequest.RESULT_SUCCESS and response[1]==200
		elif response[1]==404: result.error = "Serviço 1.6 ainda não publicado. Créditos permanecem pendentes."
	req.queue_free(); return result
func sync() -> void:
	sync_left = 120
	if busy or not available() or uid.is_empty(): return
	var needs_registration: bool = not local_economy and has_live_world() and not registered.has(world.account_run_id)
	var wallet_pending := not local_economy and (not pending.is_empty() or not titan_pending.is_empty() or trophy_sync_pending())
	var should_publish := backend == "firestore" and int(confirmed.get("active_seconds",0)) > int(Account.local_summary.get("active_seconds",-1))
	if sessions.is_empty() and profile_loaded and not needs_registration and not wallet_pending:
		if should_publish:
			busy = true
			await Account.publish_playtime(int(confirmed.get("active_seconds",0)))
			busy = false
		return
	busy = true; var owner := uid
	var submitted := session_batch()
	var reply := await request("sync",{"sessions":submitted}) if not submitted.is_empty() else await request("profile")
	if owner!=uid: busy = false; return
	if reply.ok:
		confirmed = reply.profile; profile_loaded = true
		for id in reply.get("ack_sessions",[]):
			if submitted.has(id) and int(sessions.get(id,0)) <= int(submitted[id]): sessions.erase(id)
		if backend == "firestore": await Account.publish_playtime(int(confirmed.get("active_seconds",0)))
		if owner!=uid: busy = false; return
	if local_economy:
		busy = false; persist(); changed.emit()
		return
	status = "Perfil sincronizado." if reply.ok else str(reply.get("error","Sincronização pendente."))
	if reply.ok and has_live_world():
		var run: String = world.account_run_id
		if not registered.has(run) or str(confirmed.get("active_match",run))!=run:
			var registration := await request("start",{"match_id":run,"mode":world.game_mode,"baseline":int(world.upgrades.state(world.player).get("through",0))})
			if owner!=uid: busy = false; return
			if registration.ok:
				registered[run] = true
				if registration.get("new_registration",false):
					var baseline := int(registration.get("confirmed_wave",0))
					var removed := pending.size()
					pending = pending.filter(func(item): return item.match_id!=run or int(item.wave)>baseline)
					if removed>pending.size(): status = "Partida registrada. Hordas anteriores ao registro online não geram moeda."
			else: status = str(registration.get("error","Registro da partida pendente."))
	if owner==uid and reply.ok:
		var sent := 0
		for item in pending.duplicate(true):
			if not registered.has(item.match_id) or item.match_id!=bound_run: continue
			if sent>=8: break
			sent += 1
			var reward := await request("horde",item)
			if owner!=uid: break
			if reward.ok: confirmed = reward.profile; pending.erase(item); status = "Crédito já confirmado." if reward.get("duplicate",false) else "+100 "+str(Catalog16.data().currency.name)+" confirmado."
			else:
				status = str(reward.get("error","Crédito pendente.")); break
	if owner==uid and reply.ok and not titan_pending.is_empty():
		for item in titan_pending.duplicate(true):
			if item.match_id!=bound_run or not registered.has(item.match_id): continue
			var grant := await request("titan",item)
			if owner!=uid: break
			if grant.ok: confirmed = grant.profile; titan_pending.erase(item); status = "Coroa do Enraizado confirmada."
			else: status = str(grant.get("error","Troféu pendente.")); break
	if owner==uid and reply.ok and trophy_sync_pending():
		for cls in trophy_equipped:
			if confirmed.get("equipped",{}).get(cls,{}).get("head","")=="COS-TITAN-01": continue
			var equipment := await request("equip",{"class_id":cls,"slot":"head","item_id":"COS-TITAN-01"})
			if owner!=uid: break
			if equipment.ok: confirmed = equipment.profile
			else: status = str(equipment.get("error","Equipamento pendente.")); break
	busy = false; persist(); changed.emit()
func balance() -> int:
	return int(wallet.data.balance if local_economy else confirmed.get("balance", 0))

func shop_ready() -> bool:
	return local_economy or (not busy and Account.signed_in() and available())

func horde(run: String,wave: int) -> bool:
	if clock.afk: return true
	if local_economy:
		var credited := wallet.credit(run, wave)
		if credited > 0:
			status = "+%d %s nesta horda." % [credited, Catalog16.data().currency.name]
			changed.emit()
		return credited >= 0
	if uid.is_empty(): return true
	var item := {"match_id":run,"wave":wave}
	if not item in pending: pending.append(item); dirty = true; persist(); sync_left = 0
	return true
func purchase(id: String) -> void:
	if local_economy:
		status = wallet.purchase(id)
		changed.emit()
		return
	if Catalog16.cosmetic(id).has("unlock"): status = "Exclusivo por derrotar o Titã."; changed.emit(); return
	if busy: return
	busy = true; var owner := uid
	var reply := await request("purchase",{"item_id":id,"operation_id":Crypto.new().generate_random_bytes(16).hex_encode()})
	if owner==uid:
		if reply.ok: confirmed = reply.profile; status = "Cosmético adquirido."
		else: status = str(reply.get("error","Compra não confirmada."))
	busy = false; persist(); changed.emit()
func equip(class_id: String,slot: String,id: String) -> void:
	if class_id not in ["engineer","scout","shooter"] or slot not in ["head","outfit","backpack","effect"]: return
	if id=="COS-TITAN-01" and slot=="head" and has_cosmetic(id):
		trophy_equipped[class_id] = id; persist(); changed.emit()
		if local_economy or uid.is_empty() or id not in confirmed.get("owned",[]) or busy: return
	if local_economy:
		if wallet.equip(class_id, slot, id):
			if slot=="head": trophy_equipped.erase(class_id); persist()
			status = "Cosmético retirado." if id.is_empty() else "Cosmético equipado."
		else:
			status = "Não foi possível equipar este cosmético."
		changed.emit()
		return
	elif slot=="head" and id!="COS-TITAN-01": trophy_equipped.erase(class_id); persist()
	if uid.is_empty() and id.is_empty(): changed.emit(); return
	if busy: return
	busy = true; var owner := uid
	var reply := await request("equip",{"class_id":class_id,"slot":slot,"item_id":id})
	if owner==uid:
		if reply.ok: confirmed = reply.profile
		else: status = str(reply.get("error","Não foi possível equipar."))
	busy = false; persist(); changed.emit()
func outfit(class_id: String) -> Dictionary:
	var equipped: Dictionary = wallet.data.equipped if local_economy else confirmed.get("equipped", {})
	var value: Dictionary = equipped.get(class_id,{}).duplicate()
	if trophy_equipped.get(class_id,"")=="COS-TITAN-01" and has_cosmetic("COS-TITAN-01"): value.head = "COS-TITAN-01"
	return value

func session_batch() -> Dictionary:
	var result := {}
	for key in sessions:
		if result.size()>=16: break
		result[key] = sessions[key]
	return result

func has_cosmetic(id: String) -> bool:
	var owned: Array = wallet.data.owned if local_economy else confirmed.get("owned", [])
	return id in owned or (id=="COS-TITAN-01" and not titan_earned.is_empty())

func titan_victory(run: String,encounter: String) -> void:
	if encounter.is_empty() or has_cosmetic("COS-TITAN-01"): return
	titan_earned[encounter] = true
	if not local_economy and not uid.is_empty():
		titan_pending.append({"match_id":run,"encounter_id":encounter}); sync_left = 0
	status = "Coroa do Enraizado conquistada." if local_economy or uid.is_empty() else "Coroa conquistada · confirmação online pendente."
	dirty = true; persist(); changed.emit()

func trophy_sync_pending() -> bool:
	if uid.is_empty() or "COS-TITAN-01" not in confirmed.get("owned",[]): return false
	for cls in trophy_equipped:
		if confirmed.get("equipped",{}).get(cls,{}).get("head","")!="COS-TITAN-01": return true
	return false
